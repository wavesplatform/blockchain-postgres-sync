use anyhow::{bail, Error, Result};
use async_trait::async_trait;
use chrono::{Datelike, Duration, NaiveDateTime, Timelike as _};
use diesel::{
    dsl::sql,
    pg::PgConnection,
    prelude::*,
    result::Error as DslError,
    sql_query,
    sql_types::{Array, BigInt, Int8, Timestamp, VarChar},
    Table,
};
use std::mem::drop;
use std::{collections::HashMap, num::NonZeroU32};

use super::super::UidHeight;
use super::{Repo, RepoOperations};
use crate::consumer::models::candles::interval_in_seconds;
use crate::consumer::models::{
    asset_tickers::{AssetTickerOverride, DeletedAssetTicker, InsertableAssetTicker},
    assets::{AssetOrigin, AssetOverride, AssetUpdate, DeletedAsset},
    block_microblock::BlockMicroblock,
    candles::intervals::{self, CANDLE_INTERVALS},
    txs::*,
    waves_data::WavesData,
};
use crate::db::PgAsyncPool;
use crate::error::Error as AppError;
use crate::schema::*;
use crate::tuple_len::TupleLen;

const MAX_UID: i64 = std::i64::MAX - 1;
const PG_MAX_INSERT_FIELDS_COUNT: usize = 65535;

#[derive(Clone)]
pub struct PgRepo {
    pool: PgAsyncPool,
}

pub fn new(pool: PgAsyncPool) -> PgRepo {
    PgRepo { pool }
}

pub struct PgRepoOperations<'c> {
    pub conn: &'c mut PgConnection,
}

#[async_trait]
impl Repo for PgRepo {
    type Operations<'c> = PgRepoOperations<'c>;

    async fn transaction<F, R>(&self, f: F) -> Result<R>
    where
        F: for<'conn> FnOnce(&mut Self::Operations<'conn>) -> Result<R>,
        F: Send + 'static,
        R: Send + 'static,
    {
        let connection = self.pool.get().await?;
        connection
            .interact(|conn| conn.transaction(|conn| f(&mut PgRepoOperations { conn })))
            .await
            .map_err(AppError::from)?
    }
}

impl RepoOperations for PgRepoOperations<'_> {
    //
    // COMMON
    //

    fn get_current_height(&mut self) -> Result<i32> {
        blocks_microblocks::table
            .select(blocks_microblocks::height)
            .order(blocks_microblocks::height.desc())
            .first(self.conn)
            .optional()
            .map_err(build_err_fn(format!("Cannot get current height")))
            .map(|height| height.unwrap_or(0))
    }

    fn get_blocks_rollback_to(
        &mut self,
        depth: NonZeroU32,
        seq_step: NonZeroU32,
    ) -> Result<Option<Vec<UidHeight>>> {
        let depth = depth.into();
        let current_height = self.get_current_height()? as u32;
        let rollback_step = u32::min(seq_step.into(), depth);
        let starting_height = current_height.saturating_sub(rollback_step);
        let final_height = current_height.saturating_sub(depth);

        // intentionally made up this interval because starting_height >= final_height
        // (final_height + 1) is needed to not accidentally include final_height twice
        let mut heights_rollback_to = ((final_height + 1)..=starting_height)
            .rev()
            .step_by(rollback_step as usize)
            .map(|h| h as i32)
            .collect::<Vec<_>>();

        heights_rollback_to.push(final_height as i32);

        chunked_with_result(blocks_microblocks::table, &heights_rollback_to, |heights| {
            blocks_microblocks::table
                .select((blocks_microblocks::uid, blocks_microblocks::height))
                .filter(blocks_microblocks::height.eq_any(heights))
                .order(blocks_microblocks::uid.desc())
                .get_results(self.conn)
        })
        .optional()
        .map_err(build_err_fn(format!(
            "Cannot get prev handled_height with depth {depth}"
        )))
    }

    fn get_block_uid_height(&mut self, block_id: &str) -> Result<UidHeight> {
        blocks_microblocks::table
            .select((blocks_microblocks::uid, blocks_microblocks::height))
            .filter(blocks_microblocks::id.eq(block_id))
            .get_result(self.conn)
            .map_err(build_err_fn(format!(
                "Cannot get block_uid by block id {}",
                block_id
            )))
    }

    fn get_key_block_uid(&mut self) -> Result<i64> {
        blocks_microblocks::table
            .select(sql::<Int8>("max(uid)"))
            .filter(blocks_microblocks::time_stamp.is_not_null())
            .get_result(self.conn)
            .map_err(build_err_fn("Cannot get key block uid"))
    }

    fn get_total_block_id(&mut self) -> Result<Option<String>> {
        blocks_microblocks::table
            .select(blocks_microblocks::id)
            .filter(blocks_microblocks::time_stamp.is_null())
            .order(blocks_microblocks::uid.desc())
            .first(self.conn)
            .optional()
            .map_err(build_err_fn("Cannot get total block id"))
    }

    fn insert_blocks_or_microblocks(&mut self, blocks: &Vec<BlockMicroblock>) -> Result<Vec<i64>> {
        diesel::insert_into(blocks_microblocks::table)
            .values(blocks)
            .returning(blocks_microblocks::uid)
            .get_results(self.conn)
            .map_err(build_err_fn("Cannot insert blocks/microblocks"))
    }

    fn change_block_id(&mut self, block_uid: i64, new_block_id: &str) -> Result<()> {
        diesel::update(blocks_microblocks::table)
            .set(blocks_microblocks::id.eq(new_block_id))
            .filter(blocks_microblocks::uid.eq(block_uid))
            .execute(self.conn)
            .map(drop)
            .map_err(build_err_fn("Cannot change block id"))
    }

    fn delete_microblocks(&mut self) -> Result<()> {
        diesel::delete(blocks_microblocks::table)
            .filter(blocks_microblocks::time_stamp.is_null())
            .execute(self.conn)
            .map(drop)
            .map_err(build_err_fn("Cannot delete microblocks"))
    }

    fn rollback_blocks_microblocks(&mut self, block_uid: i64) -> Result<()> {
        diesel::delete(blocks_microblocks::table)
            .filter(blocks_microblocks::uid.gt(block_uid))
            .execute(self.conn)
            .map(drop)
            .map_err(build_err_fn("Cannot rollback blocks/microblocks"))
    }

    fn insert_waves_data(&mut self, waves_data: &Vec<WavesData>) -> Result<()> {
        diesel::insert_into(waves_data::table)
            .values(waves_data)
            .on_conflict(waves_data::quantity)
            .do_nothing() // its ok to skip same quantity on historical sync
            .execute(self.conn)
            .map(drop)
            .map_err(build_err_fn("Cannot insert waves data"))
    }

    //
    // ASSETS
    //

    fn get_next_assets_uid(&mut self) -> Result<i64> {
        asset_updates_uid_seq::table
            .select(asset_updates_uid_seq::last_value)
            .first(self.conn)
            .map_err(build_err_fn("Cannot get next assets update uid"))
    }

    fn insert_asset_updates(&mut self, updates: &Vec<AssetUpdate>) -> Result<()> {
        chunked(asset_updates::table, updates, |chunk| {
            diesel::insert_into(asset_updates::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert new asset updates"))
    }

    fn insert_asset_origins(&mut self, origins: &Vec<AssetOrigin>) -> Result<()> {
        chunked(asset_origins::table, origins, |chunk| {
            diesel::insert_into(asset_origins::table)
                .values(chunk)
                .on_conflict(asset_origins::asset_id)
                .do_nothing()
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert new assets"))
    }

    fn update_assets_block_references(&mut self, block_uid: i64) -> Result<()> {
        diesel::update(asset_updates::table)
            .set((asset_updates::block_uid.eq(block_uid),))
            .filter(asset_updates::block_uid.gt(block_uid))
            .execute(self.conn)
            .map(drop)
            .map_err(build_err_fn("Cannot update assets block references"))
    }

    fn close_assets_superseded_by(&mut self, updates: &Vec<AssetOverride>) -> Result<()> {
        let (ids, superseded_by_uids): (Vec<&String>, Vec<i64>) =
            updates.iter().map(|u| (&u.id, u.superseded_by)).unzip();

        let q = sql_query(
            "UPDATE asset_updates
            SET superseded_by = updates.superseded_by
            FROM (SELECT UNNEST($1::text[]) as id, UNNEST($2::int8[]) as superseded_by) AS updates
            WHERE asset_updates.asset_id = updates.id AND asset_updates.superseded_by = $3;",
        )
        .bind::<Array<VarChar>, _>(ids)
        .bind::<Array<BigInt>, _>(superseded_by_uids)
        .bind::<BigInt, _>(MAX_UID);

        q.execute(self.conn)
            .map(drop)
            .map_err(build_err_fn("Cannot close assets superseded_by"))
    }

    fn reopen_assets_superseded_by(&mut self, current_superseded_by: &Vec<i64>) -> Result<()> {
        sql_query(
            "UPDATE asset_updates
            SET superseded_by = $1
            FROM (SELECT UNNEST($2) AS superseded_by) AS current
            WHERE asset_updates.superseded_by = current.superseded_by;",
        )
        .bind::<BigInt, _>(MAX_UID)
        .bind::<Array<BigInt>, _>(current_superseded_by)
        .execute(self.conn)
        .map(drop)
        .map_err(build_err_fn("Cannot reopen assets superseded_by"))
    }

    fn set_assets_next_update_uid(&mut self, new_uid: i64) -> Result<()> {
        // 3rd param - is called; in case of true, value'll be incremented before returning
        sql_query(format!(
            "select setval('asset_updates_uid_seq', {}, false);",
            new_uid
        ))
        .execute(self.conn)
        .map(drop)
        .map_err(build_err_fn("Cannot set assets next update uid"))
    }

    fn rollback_assets(&mut self, block_uid: i64) -> Result<Vec<DeletedAsset>> {
        diesel::delete(asset_updates::table)
            .filter(asset_updates::block_uid.gt(block_uid))
            .returning((asset_updates::uid, asset_updates::asset_id))
            .get_results(self.conn)
            .map(|bs| {
                bs.into_iter()
                    .map(|(uid, id)| DeletedAsset { uid, id })
                    .collect()
            })
            .map_err(build_err_fn("Cannot rollback assets"))
    }

    fn assets_gt_block_uid(&mut self, block_uid: i64) -> Result<Vec<i64>> {
        asset_updates::table
            .select(asset_updates::uid)
            .filter(asset_updates::block_uid.gt(block_uid))
            .get_results(self.conn)
            .map_err(build_err_fn(format!(
                "Cannot get assets greater then block_uid {}",
                block_uid
            )))
    }

    fn insert_asset_tickers(&mut self, tickers: &Vec<InsertableAssetTicker>) -> Result<()> {
        chunked(asset_tickers::table, tickers, |chunk| {
            diesel::insert_into(asset_tickers::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert new asset tickers"))
    }

    fn rollback_asset_tickers(&mut self, block_uid: &i64) -> Result<Vec<DeletedAssetTicker>> {
        diesel::delete(asset_tickers::table)
            .filter(asset_tickers::block_uid.gt(block_uid))
            .returning((asset_tickers::uid, asset_tickers::asset_id))
            .get_results(self.conn)
            .map(|bs| {
                bs.into_iter()
                    .map(|(uid, asset_id)| DeletedAssetTicker { uid, asset_id })
                    .collect()
            })
            .map_err(build_err_fn("Cannot rollback asset_tickers"))
    }

    fn update_asset_tickers_block_references(&mut self, block_uid: i64) -> Result<()> {
        diesel::update(asset_tickers::table)
            .set((asset_tickers::block_uid.eq(block_uid),))
            .filter(asset_tickers::block_uid.gt(block_uid))
            .execute(self.conn)
            .map(drop)
            .map_err(build_err_fn("Cannot update asset tickers block references"))
    }

    fn reopen_asset_tickers_superseded_by(
        &mut self,
        current_superseded_by: &Vec<i64>,
    ) -> Result<()> {
        sql_query(
            "UPDATE asset_tickers SET superseded_by = $1 FROM (SELECT UNNEST($2) AS superseded_by) AS current
            WHERE asset_tickers.superseded_by = current.superseded_by;")
            .bind::<BigInt, _>(MAX_UID)
            .bind::<Array<BigInt>, _>(current_superseded_by)
            .execute(self.conn)
            .map(drop)
            .map_err(build_err_fn("Cannot reopen asset_tickers superseded_by"))
    }

    fn close_asset_tickers_superseded_by(
        &mut self,
        updates: &Vec<AssetTickerOverride>,
    ) -> Result<()> {
        let (ids, superseded_by_uids): (Vec<&String>, Vec<i64>) = updates
            .iter()
            .map(|u| (&u.asset_id, u.superseded_by))
            .unzip();

        let q = sql_query(
            "UPDATE asset_tickers
            SET superseded_by = updates.superseded_by
            FROM (SELECT UNNEST($1::text[]) as id, UNNEST($2::int8[]) as superseded_by) AS updates
            WHERE asset_tickers.asset_id = updates.id AND asset_tickers.superseded_by = $3;",
        )
        .bind::<Array<VarChar>, _>(ids)
        .bind::<Array<BigInt>, _>(superseded_by_uids)
        .bind::<BigInt, _>(MAX_UID);

        q.execute(self.conn)
            .map(drop)
            .map_err(build_err_fn("Cannot close asset_tickers superseded_by"))
    }

    fn set_asset_tickers_next_update_uid(&mut self, new_uid: i64) -> Result<()> {
        // 3rd param - is called; in case of true, value'll be incremented before returning
        sql_query(format!(
            "select setval('asset_tickers_uid_seq', {}, false);",
            new_uid
        ))
        .execute(self.conn)
        .map(drop)
        .map_err(build_err_fn("Cannot set asset_tickers next update uid"))
    }

    fn get_next_asset_tickers_uid(&mut self) -> Result<i64> {
        asset_tickers_uid_seq::table
            .select(asset_tickers_uid_seq::last_value)
            .first(self.conn)
            .map_err(build_err_fn("Cannot get next asset tickers update uid"))
    }

    //
    // TRANSACTIONS
    //

    fn update_transactions_references(&mut self, block_uid: i64) -> Result<()> {
        diesel::update(txs::table)
            .set((txs::block_uid.eq(block_uid),))
            .filter(txs::block_uid.gt(block_uid))
            .execute(self.conn)
            .map(drop)
            .map_err(build_err_fn("Cannot update transactions references"))
    }

    fn rollback_transactions(&mut self, block_uid: i64) -> Result<()> {
        diesel::delete(txs::table)
            .filter(txs::block_uid.gt(block_uid))
            .execute(self.conn)
            .map(drop)
            .map_err(build_err_fn("Cannot rollback transactions"))
    }

    fn insert_txs_1(&mut self, txs: Vec<Tx1>) -> Result<()> {
        chunked(txs_1::table, &txs, |chunk| {
            diesel::insert_into(txs_1::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert Genesis transactions"))
    }

    fn insert_txs_2(&mut self, txs: Vec<Tx2>) -> Result<()> {
        chunked(txs_2::table, &txs, |chunk| {
            diesel::insert_into(txs_2::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert Payment transactions"))
    }

    fn insert_txs_3(&mut self, txs: Vec<Tx3>) -> Result<()> {
        chunked(txs_3::table, &txs, |chunk| {
            diesel::insert_into(txs_3::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert Issue transactions"))
    }

    fn insert_txs_4(&mut self, txs: Vec<Tx4>) -> Result<()> {
        chunked(txs_4::table, &txs, |chunk| {
            diesel::insert_into(txs_4::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert Transfer transactions"))
    }

    fn insert_txs_5(&mut self, txs: Vec<Tx5>) -> Result<()> {
        chunked(txs_5::table, &txs, |chunk| {
            diesel::insert_into(txs_5::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert Reissue transactions"))
    }

    fn insert_txs_6(&mut self, txs: Vec<Tx6>) -> Result<()> {
        chunked(txs_6::table, &txs, |chunk| {
            diesel::insert_into(txs_6::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert Burn transactions"))
    }

    fn insert_txs_7(&mut self, txs: Vec<Tx7>) -> Result<()> {
        chunked(txs_7::table, &txs, |chunk| {
            diesel::insert_into(txs_7::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert Exchange transactions"))
    }

    fn insert_txs_8(&mut self, txs: Vec<Tx8>) -> Result<()> {
        chunked(txs_8::table, &txs, |chunk| {
            diesel::insert_into(txs_8::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert Lease transactions"))
    }

    fn insert_txs_9(&mut self, txs: Vec<Tx9Partial>) -> Result<()> {
        let lease_ids = txs
            .iter()
            .filter_map(|tx| tx.lease_id.as_ref())
            .collect::<Vec<_>>();
        let tx_id_uid = chunked_with_result(txs::table, &lease_ids, |ids| {
            txs::table
                .select((txs::id, txs::uid))
                .filter(txs::id.eq_any(ids))
                .get_results(self.conn)
        })
        .map_err(build_err_fn("Cannot find uids for lease_ids"))?;

        let tx_id_uid_map = HashMap::<String, i64>::from_iter(tx_id_uid);
        let txs9 = txs
            .into_iter()
            .map(|tx| {
                Tx9::from((
                    &tx,
                    tx.lease_id
                        .as_ref()
                        .and_then(|lease_id| tx_id_uid_map.get(lease_id))
                        .cloned(),
                ))
            })
            .collect::<Vec<_>>();

        chunked(txs_9::table, &txs9, |chunk| {
            diesel::insert_into(txs_9::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert LeaseCancel transactions"))
    }

    fn insert_txs_10(&mut self, txs: Vec<Tx10>) -> Result<()> {
        chunked(txs_10::table, &txs, |chunk| {
            diesel::insert_into(txs_10::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert CreateAlias transactions"))
    }

    fn insert_txs_11(&mut self, txs: Vec<Tx11Combined>) -> Result<()> {
        let (txs11, transfers): (Vec<Tx11>, Vec<Vec<Tx11Transfers>>) =
            txs.into_iter().map(|t| (t.tx, t.transfers)).unzip();
        let transfers = transfers.into_iter().flatten().collect::<Vec<_>>();

        chunked(txs_11::table, &txs11, |chunk| {
            diesel::insert_into(txs_11::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert MassTransfer transactions"))?;

        chunked(txs_11_transfers::table, &transfers, |chunk| {
            diesel::insert_into(txs_11_transfers::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert MassTransfer transfers"))
    }

    fn insert_txs_12(&mut self, txs: Vec<Tx12Combined>) -> Result<()> {
        let (txs12, data): (Vec<Tx12>, Vec<Vec<Tx12Data>>) =
            txs.into_iter().map(|t| (t.tx, t.data)).unzip();
        let data = data.into_iter().flatten().collect::<Vec<_>>();

        chunked(txs_12::table, &txs12, |chunk| {
            diesel::insert_into(txs_12::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert DataTransaction transaction"))?;

        chunked(txs_12_data::table, &data, |chunk| {
            diesel::insert_into(txs_12_data::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert DataTransaction data"))
    }

    fn insert_txs_13(&mut self, txs: Vec<Tx13>) -> Result<()> {
        chunked(txs_13::table, &txs, |chunk| {
            diesel::insert_into(txs_13::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert SetScript transactions"))
    }

    fn insert_txs_14(&mut self, txs: Vec<Tx14>) -> Result<()> {
        chunked(txs_14::table, &txs, |chunk| {
            diesel::insert_into(txs_14::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert SponsorFee transactions"))
    }

    fn insert_txs_15(&mut self, txs: Vec<Tx15>) -> Result<()> {
        chunked(txs_15::table, &txs, |chunk| {
            diesel::insert_into(txs_15::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert SetAssetScript transactions"))
    }

    fn insert_txs_16(&mut self, txs: Vec<Tx16Combined>) -> Result<()> {
        let (txs16, data): (Vec<Tx16>, Vec<(Vec<Tx16Args>, Vec<Tx16Payment>)>) = txs
            .into_iter()
            .map(|t| (t.tx, (t.args, t.payments)))
            .unzip();
        let (args, payments): (Vec<Vec<Tx16Args>>, Vec<Vec<Tx16Payment>>) =
            data.into_iter().unzip();
        let args = args.into_iter().flatten().collect::<Vec<_>>();
        let payments = payments.into_iter().flatten().collect::<Vec<_>>();

        chunked(txs_16::table, &txs16, |chunk| {
            diesel::insert_into(txs_16::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert InvokeScript transactions"))?;

        chunked(txs_16_args::table, &args, |chunk| {
            diesel::insert_into(txs_16_args::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert InvokeScript args"))?;

        chunked(txs_16_payment::table, &payments, |chunk| {
            diesel::insert_into(txs_16_payment::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert InvokeScript payments"))
    }

    fn insert_txs_17(&mut self, txs: Vec<Tx17>) -> Result<()> {
        chunked(txs_17::table, &txs, |chunk| {
            diesel::insert_into(txs_17::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert UpdateAssetInfo transactions"))
    }

    fn insert_txs_18(&mut self, txs: Vec<Tx18Combined>) -> Result<()> {
        let (txs18, data): (Vec<Tx18>, Vec<(Vec<Tx18Args>, Vec<Tx18Payment>)>) = txs
            .into_iter()
            .map(|t| (t.tx, (t.args, t.payments)))
            .unzip();
        let (args, payments): (Vec<Vec<Tx18Args>>, Vec<Vec<Tx18Payment>>) =
            data.into_iter().unzip();
        let args = args.into_iter().flatten().collect::<Vec<_>>();
        let payments = payments.into_iter().flatten().collect::<Vec<_>>();

        chunked(txs_18::table, &txs18, |chunk| {
            diesel::insert_into(txs_18::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert Ethereum transactions"))?;

        chunked(txs_18_args::table, &args, |chunk| {
            diesel::insert_into(txs_18_args::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert Ethereum InvokeScript args"))?;

        chunked(txs_18_payment::table, &payments, |chunk| {
            diesel::insert_into(txs_18_payment::table)
                .values(chunk)
                .execute(self.conn)
        })
        .map_err(build_err_fn("Cannot insert Ethereum InvokeScript payments"))
    }

    //
    // CANDLES
    //

    fn calculate_candles_since_block_uid(&mut self, block_uid: i64) -> Result<()> {
        let first_tx7_in_block_ts = match txs_7::table
            .select(txs_7::time_stamp)
            .filter(txs_7::block_uid.eq(block_uid))
            .order(txs_7::time_stamp.asc())
            .first::<NaiveDateTime>(self.conn)
            .optional()
            .map_err(build_err_fn("Cannot find exchange txs"))?
        {
            Some(ts) => ts
                .with_second(0)
                .and_then(|ts| ts.with_nanosecond(0))
                .unwrap(),
            None => return Ok(()),
        };

        self.calculate_minute_candles(first_tx7_in_block_ts)?;
        self.calculate_non_minute_candles(first_tx7_in_block_ts)
    }

    fn calculate_minute_candles(&mut self, since_timestamp: NaiveDateTime) -> Result<()> {
        let insert_candles_query = r#"
            INSERT INTO candles
                SELECT
                    e.candle_time,
                    amount_asset_id,
                    price_asset_id,
                    min(e.price) AS low,
                    max(e.price) AS high,
                    sum(e.amount) AS volume,
                    sum((e.amount)::numeric * (e.price)::numeric) AS quote_volume,
                    max(height) AS max_height,
                    count(e.price) AS txs_count,
                    floor(sum((e.amount)::numeric * (e.price)::numeric) / sum((e.amount)::numeric))::numeric
                        AS weighted_average_price,
                    (array_agg(e.price ORDER BY e.uid)::numeric[])[1] AS open,
                    (array_agg(e.price ORDER BY e.uid DESC)::numeric[])[1] AS close,
                    '1m' AS interval,
                    e.sender AS matcher_address
                FROM
                    (SELECT
                        date_trunc('minute', time_stamp) AS candle_time,
                        uid,
                        amount_asset_id,
                        price_asset_id,
                        sender,
                        height,
                        amount,
                        CASE WHEN tx_version > 2
                            THEN price::numeric
                                * 10^(select decimals from decimals where asset_id = price_asset_id)
                                * 10^(select -decimals from decimals where asset_id = amount_asset_id)
                            ELSE price::numeric
                        END price
                    FROM txs_7
                    WHERE time_stamp >= $1 ORDER BY uid, time_stamp <-> $1) AS e
                GROUP BY
                    e.candle_time,
                    e.amount_asset_id,
                    e.price_asset_id,
                    e.sender
            ON CONFLICT (time_start, amount_asset_id, price_asset_id, matcher_address, interval) DO UPDATE
                SET open = excluded.open,
                    close = excluded.close,
                    low = excluded.low,
                    high = excluded.high,
                    max_height = excluded.max_height,
                    quote_volume = excluded.quote_volume,
                    txs_count = excluded.txs_count,
                    volume = excluded.volume,
                    weighted_average_price = excluded.weighted_average_price;
        "#;
        sql_query(insert_candles_query)
            .bind::<Timestamp, _>(since_timestamp)
            .execute(self.conn)
            .map(drop)
            .map_err(build_err_fn("Cannot calculate minute candles"))
    }

    fn calculate_non_minute_candles(&mut self, since_timestamp: NaiveDateTime) -> Result<()> {
        let insert_candles_query = r#"
            INSERT INTO candles
            SELECT
                _to_raw_timestamp(time_start, $2) AS candle_time,
                amount_asset_id,
                price_asset_id,
                min(low) AS low,
                max(high) AS high,
                sum(volume) AS volume,
                sum(quote_volume) AS quote_volume,
                max(max_height) AS max_height,
                sum(txs_count) as txs_count,
                floor(sum((weighted_average_price * volume)::numeric)::numeric / sum(volume)::numeric)::numeric
                    AS weighted_average_price,
                (array_agg(open ORDER BY time_start)::numeric[])[1] AS open,
                (array_agg(close ORDER BY time_start DESC)::numeric[])[1] AS close,
                $2 AS interval,
                matcher_address
            FROM candles
            WHERE interval = $1
            AND time_start >= $3
            GROUP BY candle_time, amount_asset_id, price_asset_id, matcher_address

            ON CONFLICT (time_start, amount_asset_id, price_asset_id, matcher_address, interval) DO UPDATE
                SET open = excluded.open,
                    close = excluded.close,
                    low = excluded.low,
                    high = excluded.high,
                    max_height = excluded.max_height,
                    quote_volume = excluded.quote_volume,
                    txs_count = excluded.txs_count,
                    volume = excluded.volume,
                    weighted_average_price = excluded.weighted_average_price;
        "#;

        for interval in CANDLE_INTERVALS {
            let [interval_start, interval_end] = interval;

            let interval_start_time_stamp =
                if let Some(interval_secs) = interval_in_seconds(&interval_end) {
                    NaiveDateTime::from_timestamp_opt(
                        (since_timestamp.timestamp() / interval_secs) * interval_secs,
                        0,
                    )
                    .unwrap()
                } else {
                    match *interval_end {
                        intervals::WEEK1 => {
                            let weekday = since_timestamp.weekday().num_days_from_monday() as i64;
                            (since_timestamp - Duration::days(weekday))
                                .date()
                                .and_hms_opt(0, 0, 0)
                                .unwrap()
                        }
                        intervals::MONTH1 => since_timestamp
                            .with_day(1)
                            .unwrap()
                            .date()
                            .and_hms_opt(0, 0, 0)
                            .unwrap(),
                        _ => bail!("unknown interval {interval_end}"),
                    }
                };

            sql_query(insert_candles_query)
                .bind::<VarChar, _>(interval_start)
                .bind::<VarChar, _>(interval_end)
                .bind::<Timestamp, _>(interval_start_time_stamp)
                .execute(self.conn)
                .map_err(build_err_fn(format!(
                    "Cannot insert candles with [{interval_start}; {interval_end}] interval"
                )))?;
        }
        Ok(())
    }

    fn rollback_candles(&mut self, block_uid: i64) -> Result<()> {
        let first_tx7_in_block_ts = match txs_7::table
            .select(txs_7::time_stamp)
            .filter(txs_7::block_uid.eq(block_uid))
            .order(txs_7::time_stamp.asc())
            .first::<NaiveDateTime>(self.conn)
            .optional()
            .map_err(build_err_fn("Cannot find exchange txs in rollback"))?
        {
            Some(ts) => ts
                .with_second(0)
                .and_then(|ts| ts.with_nanosecond(0))
                .unwrap(),
            None => return Ok(()),
        };

        diesel::delete(candles::table)
            .filter(candles::time_start.gt(first_tx7_in_block_ts))
            .execute(self.conn)
            .map(drop)
            .map_err(build_err_fn("Cannot rollback candles"))
    }
}

fn chunked_with_result<T, F, V, R>(
    _: T,
    values: &Vec<V>,
    mut query_fn: F,
) -> Result<Vec<R>, DslError>
where
    T: Table,
    T::AllColumns: TupleLen,
    F: FnMut(&[V]) -> Result<Vec<R>, DslError>,
{
    let columns_count = T::all_columns().len();
    let chunk_size = (PG_MAX_INSERT_FIELDS_COUNT / columns_count) / 10 * 10;
    let mut result = vec![];
    values
        .chunks(chunk_size)
        .into_iter()
        .try_fold((), |_, chunk| {
            result.extend(query_fn(chunk)?);
            Ok::<_, DslError>(())
        })?;
    Ok(result)
}

#[inline]
fn chunked<T, F, V>(table: T, values: &Vec<V>, mut query_fn: F) -> Result<(), DslError>
where
    T: Table,
    T::AllColumns: TupleLen,
    F: FnMut(&[V]) -> Result<usize, DslError>, //allows only dsl_query.execute()
{
    chunked_with_result(table, values, |v| query_fn(v).map(|_| Vec::<()>::new())).map(drop)
}

fn build_err_fn(msg: impl AsRef<str>) -> impl Fn(DslError) -> Error {
    move |err| {
        let ctx = format!("{}", msg.as_ref());
        Error::new(AppError::DbDieselError(err)).context(ctx)
    }
}
