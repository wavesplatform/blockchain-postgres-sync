use anyhow::{Error, Result};
use diesel::pg::PgConnection;
use diesel::prelude::*;
use diesel::result::Error as DslError;
use diesel::sql_types::{Array, BigInt, Integer, Numeric, VarChar};
use diesel::Table;

use super::super::PrevHandledHeight;
use super::Repo;
use crate::consumer::models::{
    assets::{AssetOrigin, AssetOverride, AssetUpdate, DeletedAsset},
    block_microblock::BlockMicroblock,
    txs::*,
    waves_data::WavesData,
};
use crate::error::Error as AppError;
use crate::schema::*;
use crate::tuple_len::TupleLen;

const MAX_UID: i64 = std::i64::MAX - 1;
const PG_MAX_INSERT_FIELDS_COUNT: usize = 65535;

pub struct PgRepoImpl {
    conn: PgConnection,
}

pub fn new(conn: PgConnection) -> PgRepoImpl {
    PgRepoImpl { conn }
}

#[async_trait::async_trait]
impl Repo for PgRepoImpl {
    //
    // COMMON
    //

    fn transaction(&self, f: impl FnOnce() -> Result<()>) -> Result<()> {
        self.conn.transaction(|| f())
    }

    fn get_prev_handled_height(&self) -> Result<Option<PrevHandledHeight>> {
        blocks_microblocks::table
            .select((blocks_microblocks::uid, blocks_microblocks::height))
            .filter(
                blocks_microblocks::height.eq(diesel::expression::sql_literal::sql(
                    "(select max(height) - 1 from blocks_microblocks)",
                )),
            )
            .order(blocks_microblocks::uid.asc())
            .first(&self.conn)
            .optional()
            .map_err(|err| Error::new(AppError::DbDieselError(err)))
    }

    fn get_block_uid(&self, block_id: &str) -> Result<i64> {
        blocks_microblocks::table
            .select(blocks_microblocks::uid)
            .filter(blocks_microblocks::id.eq(block_id))
            .get_result(&self.conn)
            .map_err(|err| {
                let context = format!("Cannot get block_uid by block id {}: {}", block_id, err);
                Error::new(AppError::DbDieselError(err)).context(context)
            })
    }

    fn get_key_block_uid(&self) -> Result<i64> {
        blocks_microblocks::table
            .select(diesel::expression::sql_literal::sql("max(uid)"))
            .filter(blocks_microblocks::time_stamp.is_not_null())
            .get_result(&self.conn)
            .map_err(|err| {
                let context = format!("Cannot get key block uid: {}", err);
                Error::new(AppError::DbDieselError(err)).context(context)
            })
    }

    fn get_total_block_id(&self) -> Result<Option<String>> {
        blocks_microblocks::table
            .select(blocks_microblocks::id)
            .filter(blocks_microblocks::time_stamp.is_null())
            .order(blocks_microblocks::uid.desc())
            .first(&self.conn)
            .optional()
            .map_err(|err| {
                let context = format!("Cannot get total block id: {}", err);
                Error::new(AppError::DbDieselError(err)).context(context)
            })
    }

    fn insert_blocks_or_microblocks(&self, blocks: &Vec<BlockMicroblock>) -> Result<Vec<i64>> {
        diesel::insert_into(blocks_microblocks::table)
            .values(blocks)
            .returning(blocks_microblocks::uid)
            .get_results(&self.conn)
            .map_err(|err| {
                let context = format!("Cannot insert blocks/microblocks: {}", err);
                Error::new(AppError::DbDieselError(err)).context(context)
            })
    }

    fn change_block_id(&self, block_uid: &i64, new_block_id: &str) -> Result<()> {
        diesel::update(blocks_microblocks::table)
            .set(blocks_microblocks::id.eq(new_block_id))
            .filter(blocks_microblocks::uid.eq(block_uid))
            .execute(&self.conn)
            .map(|_| ())
            .map_err(|err| {
                let context = format!("Cannot change block id: {}", err);
                Error::new(AppError::DbDieselError(err)).context(context)
            })
    }

    fn delete_microblocks(&self) -> Result<()> {
        diesel::delete(blocks_microblocks::table)
            .filter(blocks_microblocks::time_stamp.is_null())
            .execute(&self.conn)
            .map(|_| ())
            .map_err(|err| {
                let context = format!("Cannot delete microblocks: {}", err);
                Error::new(AppError::DbDieselError(err)).context(context)
            })
    }

    fn rollback_blocks_microblocks(&self, block_uid: &i64) -> Result<()> {
        diesel::delete(blocks_microblocks::table)
            .filter(blocks_microblocks::uid.gt(block_uid))
            .execute(&self.conn)
            .map(|_| ())
            .map_err(|err| {
                let context = format!("Cannot rollback blocks/microblocks: {}", err);
                Error::new(AppError::DbDieselError(err)).context(context)
            })
    }

    fn insert_waves_data(&self, waves_data: &Vec<WavesData>) -> Result<()> {
        for data in waves_data {
            let q = diesel::sql_query("INSERT INTO waves_data (height, quantity) 
            values (
                $1::integer, 
                (SELECT quantity FROM waves_data WHERE height < $1::integer OR height IS NULL ORDER BY height DESC NULLS LAST LIMIT 1) + $2::bigint
            )
            ON CONFLICT DO NOTHING;")
            .bind::<Integer, _>(data.height)
            .bind::<Numeric, _>(&data.quantity);

            q.execute(&self.conn).map(|_| ()).map_err(|err| {
                let context = format!("Cannot insert waves data {waves_data:?}: {err}");
                Error::new(AppError::DbDieselError(err)).context(context)
            })?;
        }
        Ok(())
    }

    //
    // ASSETS
    //

    fn get_next_assets_uid(&self) -> Result<i64> {
        asset_updates_uid_seq::table
            .select(asset_updates_uid_seq::last_value)
            .first(&self.conn)
            .map_err(|err| {
                let context = format!("Cannot get next assets update uid: {}", err);
                Error::new(AppError::DbDieselError(err)).context(context)
            })
    }

    fn insert_asset_updates(&self, updates: &Vec<AssetUpdate>) -> Result<()> {
        chunked(asset_updates::table, updates, |t| {
            diesel::insert_into(asset_updates::table)
                .values(t)
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert new asset updates: {}", err);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn insert_asset_origins(&self, origins: &Vec<AssetOrigin>) -> Result<()> {
        chunked(asset_origins::table, origins, |t| {
            diesel::insert_into(asset_origins::table)
                .values(t)
                .on_conflict(asset_origins::asset_id)
                .do_nothing() // а может и не nothing
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert new assets: {}", err);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn update_assets_block_references(&self, block_uid: &i64) -> Result<()> {
        diesel::update(asset_updates::table)
            .set((asset_updates::block_uid.eq(block_uid),))
            .filter(asset_updates::block_uid.gt(block_uid))
            .execute(&self.conn)
            .map(|_| ())
            .map_err(|err| {
                let context = format!("Cannot update assets block references: {}", err);
                Error::new(AppError::DbDieselError(err)).context(context)
            })
    }

    fn close_assets_superseded_by(&self, updates: &Vec<AssetOverride>) -> Result<()> {
        let mut ids = vec![];
        let mut superseded_by_uids = vec![];

        updates.iter().for_each(|u| {
            ids.push(&u.id);
            superseded_by_uids.push(&u.superseded_by);
        });

        let q = diesel::sql_query(
            "UPDATE asset_updates
            SET superseded_by = updates.superseded_by 
            FROM (SELECT UNNEST($1::text[]) as id, UNNEST($2::int8[]) as superseded_by) AS updates
            WHERE asset_updates.asset_id = updates.id AND asset_updates.superseded_by = $3;",
        )
        .bind::<Array<VarChar>, _>(ids)
        .bind::<Array<BigInt>, _>(superseded_by_uids)
        .bind::<BigInt, _>(MAX_UID);

        q.execute(&self.conn).map(|_| ()).map_err(|err| {
            let context = format!("Cannot close assets superseded_by: {}", err);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn reopen_assets_superseded_by(&self, current_superseded_by: &Vec<i64>) -> Result<()> {
        diesel::sql_query(
            "UPDATE asset_updates
            SET superseded_by = $1 
            FROM (SELECT UNNEST($2) AS superseded_by) AS current 
            WHERE asset_updates.superseded_by = current.superseded_by;",
        )
        .bind::<BigInt, _>(MAX_UID)
        .bind::<Array<BigInt>, _>(current_superseded_by)
        .execute(&self.conn)
        .map(|_| ())
        .map_err(|err| {
            let context = format!("Cannot reopen assets superseded_by: {}", err);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn set_assets_next_update_uid(&self, new_uid: i64) -> Result<()> {
        diesel::sql_query(format!(
            "select setval('asset_updates_uid_seq', {}, false);", // 3rd param - is called; in case of true, value'll be incremented before returning
            new_uid
        ))
        .execute(&self.conn)
        .map(|_| ())
        .map_err(|err| {
            let context = format!("Cannot set assets next update uid: {}", err);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn rollback_assets(&self, block_uid: &i64) -> Result<Vec<DeletedAsset>> {
        diesel::delete(asset_updates::table)
            .filter(asset_updates::block_uid.gt(block_uid))
            .returning((asset_updates::uid, asset_updates::asset_id))
            .get_results(&self.conn)
            .map(|bs| {
                bs.into_iter()
                    .map(|(uid, id)| DeletedAsset { uid, id })
                    .collect()
            })
            .map_err(|err| {
                let context = format!("Cannot rollback assets: {}", err);
                Error::new(AppError::DbDieselError(err)).context(context)
            })
    }

    fn assets_gt_block_uid(&self, block_uid: &i64) -> Result<Vec<i64>> {
        asset_updates::table
            .select(asset_updates::uid)
            .filter(asset_updates::block_uid.gt(block_uid))
            .get_results(&self.conn)
            .map_err(|err| {
                let context = format!(
                    "Cannot get assets greater then block_uid {}: {}",
                    block_uid, err
                );
                Error::new(AppError::DbDieselError(err)).context(context)
            })
    }

    //
    // TRANSACTIONS
    //

    fn insert_txs_1(&self, txs: &Vec<Tx1>) -> Result<()> {
        chunked(txs_1::table, txs, |t| {
            diesel::insert_into(txs_1::table)
                .values(t)
                .on_conflict(txs_1::uid)
                .do_nothing()
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert Genesis transactions: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn insert_txs_2(&self, txs: &Vec<Tx2>) -> Result<()> {
        chunked(txs_2::table, txs, |t| {
            diesel::insert_into(txs_2::table)
                .values(t)
                .on_conflict(txs_2::uid)
                .do_nothing()
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert Payment transactions: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn insert_txs_3(&self, txs: &Vec<Tx3>) -> Result<()> {
        chunked(txs_3::table, txs, |t| {
            diesel::insert_into(txs_3::table)
                .values(t)
                .on_conflict(txs_3::uid)
                .do_nothing()
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert Issue transactions: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn insert_txs_4(&self, txs: &Vec<Tx4>) -> Result<()> {
        chunked(txs_4::table, txs, |t| {
            diesel::insert_into(txs_4::table)
                .values(t)
                .on_conflict(txs_4::uid)
                .do_nothing()
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert Transfer transactions: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn insert_txs_5(&self, txs: &Vec<Tx5>) -> Result<()> {
        chunked(txs_5::table, txs, |t| {
            diesel::insert_into(txs_5::table)
                .values(t)
                .on_conflict(txs_5::uid)
                .do_nothing()
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert Reissue transactions: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn insert_txs_6(&self, txs: &Vec<Tx6>) -> Result<()> {
        chunked(txs_6::table, txs, |t| {
            diesel::insert_into(txs_6::table)
                .values(t)
                .on_conflict(txs_6::uid)
                .do_nothing()
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert Burn transactions: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn insert_txs_7(&self, txs: &Vec<Tx7>) -> Result<()> {
        chunked(txs_7::table, txs, |t| {
            diesel::insert_into(txs_7::table)
                .values(t)
                .on_conflict(txs_7::uid)
                .do_nothing()
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert Exchange transactions: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn insert_txs_8(&self, txs: &Vec<Tx8>) -> Result<()> {
        chunked(txs_8::table, txs, |t| {
            diesel::insert_into(txs_8::table)
                .values(t)
                .on_conflict(txs_8::uid)
                .do_nothing()
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert Lease transactions: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn insert_txs_9(&self, txs: &Vec<Tx9Partial>) -> Result<()> {
        //TODO: optimize selects
        let mut txs9 = vec![];
        for tx in txs.into_iter() {
            let lease_tx_uid = match tx.lease_id.as_ref() {
                Some(lid) => txs::table
                    .select(txs::uid)
                    .filter(txs::id.eq(lid))
                    .first(&self.conn)
                    .optional()
                    .map_err(|err| {
                        let context = format!("Cannot find uid for lease_id {lid}: {err}",);
                        Error::new(AppError::DbDieselError(err)).context(context)
                    })?,
                None => None,
            };
            txs9.push(Tx9::from((tx, lease_tx_uid)));
        }

        chunked(txs_9::table, &txs9, |t| {
            diesel::insert_into(txs_9::table)
                .values(t)
                .on_conflict(txs_9::uid)
                .do_nothing()
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert LeaseCancel transactions: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn insert_txs_10(&self, txs: &Vec<Tx10>) -> Result<()> {
        chunked(txs_10::table, txs, |t| {
            diesel::insert_into(txs_10::table)
                .values(t)
                .on_conflict(txs_10::uid)
                .do_nothing()
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert CreateAlias transactions: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn insert_txs_11(&self, txs: &Vec<Tx11Combined>) -> Result<()> {
        // TODO: figure out how to pass references to freaking diesel
        let txs11: Vec<Tx11> = txs.iter().map(|t| t.tx.clone()).collect();
        let transfers: Vec<Tx11Transfers> = txs.iter().flat_map(|t| t.transfers.clone()).collect();

        chunked(txs_11::table, &txs11, |t| {
            diesel::insert_into(txs_11::table)
                .values(t)
                .on_conflict(txs_11::uid)
                .do_nothing()
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert MassTransfer transactions: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })?;

        chunked(txs_11_transfers::table, &transfers, |t| {
            diesel::insert_into(txs_11_transfers::table)
                .values(t)
                .on_conflict((txs_11_transfers::tx_uid, txs_11_transfers::position_in_tx))
                .do_nothing()
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert MassTransfer transfers: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn insert_txs_12(&self, txs: &Vec<Tx12Combined>) -> Result<()> {
        let txs12: Vec<Tx12> = txs.iter().map(|t| t.tx.clone()).collect();
        let data: Vec<Tx12Data> = txs.iter().flat_map(|t| t.data.clone()).collect();

        chunked(txs_12::table, &txs12, |t| {
            diesel::insert_into(txs_12::table)
                .values(t)
                .on_conflict(txs_12::uid)
                .do_nothing()
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert DataTransaction transaction: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })?;

        chunked(txs_12_data::table, &data, |t| {
            diesel::insert_into(txs_12_data::table)
                .values(t)
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert DataTransaction data: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn insert_txs_13(&self, txs: &Vec<Tx13>) -> Result<()> {
        chunked(txs_13::table, txs, |t| {
            diesel::insert_into(txs_13::table)
                .values(t)
                .on_conflict(txs_13::uid)
                .do_nothing()
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert SetScript transactions: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn insert_txs_14(&self, txs: &Vec<Tx14>) -> Result<()> {
        chunked(txs_14::table, txs, |t| {
            diesel::insert_into(txs_14::table)
                .values(t)
                .on_conflict(txs_14::uid)
                .do_nothing()
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert SponsorFee transactions: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn insert_txs_15(&self, txs: &Vec<Tx15>) -> Result<()> {
        chunked(txs_15::table, txs, |t| {
            diesel::insert_into(txs_15::table)
                .values(t)
                .on_conflict(txs_15::uid)
                .do_nothing()
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert SetAssetScript transactions: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn insert_txs_16(&self, txs: &Vec<Tx16Combined>) -> Result<()> {
        let txs16: Vec<Tx16> = txs.into_iter().map(|t| t.tx.clone()).collect();
        let args: Vec<Tx16Args> = txs.iter().flat_map(|t| t.args.clone()).collect();
        let payments: Vec<Tx16Payment> = txs.iter().flat_map(|t| t.payments.clone()).collect();

        chunked(txs_16::table, &txs16, |t| {
            diesel::insert_into(txs_16::table)
                .values(t)
                .on_conflict(txs_16::uid)
                .do_nothing()
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert InvokeScript transactions: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })?;

        chunked(txs_16_args::table, &args, |t| {
            diesel::insert_into(txs_16_args::table)
                .values(t)
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert InvokeScript args: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })?;

        chunked(txs_16_payment::table, &payments, |t| {
            diesel::insert_into(txs_16_payment::table)
                .values(t)
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert InvokeScript payments: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }

    fn insert_txs_17(&self, txs: &Vec<Tx17>) -> Result<()> {
        chunked(txs_17::table, txs, |t| {
            diesel::insert_into(txs_17::table)
                .values(t)
                .execute(&self.conn)
                .map(|_| ())
        })
        .map_err(|err| {
            let context = format!("Cannot insert UpdateAssetInfo transactions: {err}",);
            Error::new(AppError::DbDieselError(err)).context(context)
        })
    }
}

fn chunked<T, F, V>(_: T, values: &Vec<V>, query_fn: F) -> Result<(), DslError>
where
    T: Table,
    T::AllColumns: TupleLen,
    F: Fn(&[V]) -> Result<(), DslError>,
{
    let columns_count = T::all_columns().len();
    let chunk_size = (PG_MAX_INSERT_FIELDS_COUNT / columns_count) / 10 * 10;
    values
        .chunks(chunk_size)
        .into_iter()
        .try_fold((), |_, chunk| query_fn(chunk))
}
