use anyhow::{Error, Result};
use diesel::pg::PgConnection;
use diesel::prelude::*;
use diesel::sql_types::{Array, BigInt, VarChar};

use super::super::PrevHandledHeight;
use super::Repo;
use crate::consumer::models::{
    assets::{AssetOrigin, AssetOverride, AssetUpdate, DeletedAsset},
    block_microblock::BlockMicroblock,
    txs::Tx,
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
        let columns_count = asset_updates::table::all_columns().len();
        let chunk_size = (PG_MAX_INSERT_FIELDS_COUNT / columns_count) / 10 * 10;
        updates
            .to_owned()
            .chunks(chunk_size)
            .into_iter()
            .try_fold((), |_, chunk| {
                diesel::insert_into(asset_updates::table)
                    .values(chunk)
                    .execute(&self.conn)
                    .map(|_| ())
            })
            .map_err(|err| {
                let context = format!("Cannot insert new asset updates: {}", err);
                Error::new(AppError::DbDieselError(err)).context(context)
            })
    }

    fn insert_asset_origins(&self, origins: &Vec<AssetOrigin>) -> Result<()> {
        let columns_count = asset_origins::table::all_columns().len();
        let chunk_size = (PG_MAX_INSERT_FIELDS_COUNT / columns_count) / 10 * 10;
        origins
            .to_owned()
            .chunks(chunk_size)
            .into_iter()
            .try_fold((), |_, chunk| {
                diesel::insert_into(asset_origins::table)
                    .values(chunk)
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

    fn insert_txs(&self, txs: &Vec<Tx>) -> Result<()> {
        for tx in txs {
            match tx {
                Tx::Genesis(t) => diesel::insert_into(txs_1::table)
                    .values(t)
                    .execute(&self.conn)
                    .map(|_| ())
                    .map_err(|err| {
                        let context = format!("Cannot insert Genesis transaction {t:?}: {err}",);
                        Error::new(AppError::DbDieselError(err)).context(context)
                    })?,
                Tx::Payment(t) => diesel::insert_into(txs_2::table)
                    .values(t)
                    .execute(&self.conn)
                    .map(|_| ())
                    .map_err(|err| {
                        let context = format!("Cannot insert Payment transaction {t:?}: {err}",);
                        Error::new(AppError::DbDieselError(err)).context(context)
                    })?,
                Tx::Issue(t) => diesel::insert_into(txs_3::table)
                    .values(t)
                    .execute(&self.conn)
                    .map(|_| ())
                    .map_err(|err| {
                        let context = format!("Cannot insert Issue transaction {t:?}: {err}",);
                        Error::new(AppError::DbDieselError(err)).context(context)
                    })?,
                Tx::Transfer(t) => diesel::insert_into(txs_4::table)
                    .values(t)
                    .execute(&self.conn)
                    .map(|_| ())
                    .map_err(|err| {
                        let context = format!("Cannot insert Transfer transaction {t:?}: {err}",);
                        Error::new(AppError::DbDieselError(err)).context(context)
                    })?,
                Tx::Reissue(t) => diesel::insert_into(txs_5::table)
                    .values(t)
                    .execute(&self.conn)
                    .map(|_| ())
                    .map_err(|err| {
                        let context = format!("Cannot insert Reissue transaction {t:?}: {err}",);
                        Error::new(AppError::DbDieselError(err)).context(context)
                    })?,
                Tx::Burn(t) => diesel::insert_into(txs_6::table)
                    .values(t)
                    .execute(&self.conn)
                    .map(|_| ())
                    .map_err(|err| {
                        let context = format!("Cannot insert Burn transaction {t:?}: {err}",);
                        Error::new(AppError::DbDieselError(err)).context(context)
                    })?,
                Tx::Exchange(t) => diesel::insert_into(txs_7::table)
                    .values(t)
                    .execute(&self.conn)
                    .map(|_| ())
                    .map_err(|err| {
                        let context = format!("Cannot insert Exchange transaction {t:?}: {err}",);
                        Error::new(AppError::DbDieselError(err)).context(context)
                    })?,
                Tx::Lease(t) => diesel::insert_into(txs_8::table)
                    .values(t)
                    .execute(&self.conn)
                    .map(|_| ())
                    .map_err(|err| {
                        let context = format!("Cannot insert Lease transaction {t:?}: {err}",);
                        Error::new(AppError::DbDieselError(err)).context(context)
                    })?,
                Tx::LeaseCancel(t) => diesel::insert_into(txs_9::table)
                    .values(t)
                    .execute(&self.conn)
                    .map(|_| ())
                    .map_err(|err| {
                        let context =
                            format!("Cannot insert LeaseCancel transaction {t:?}: {err}",);
                        Error::new(AppError::DbDieselError(err)).context(context)
                    })?,
                Tx::CreateAlias(t) => diesel::insert_into(txs_10::table)
                    .values(t)
                    .execute(&self.conn)
                    .map(|_| ())
                    .map_err(|err| {
                        let context =
                            format!("Cannot insert CreateAlias transaction {t:?}: {err}",);
                        Error::new(AppError::DbDieselError(err)).context(context)
                    })?,
                Tx::MassTransfer(t) => {
                    let (tx11, transfers) = t;
                    diesel::insert_into(txs_11::table)
                        .values(tx11)
                        .execute(&self.conn)
                        .map(|_| ())
                        .map_err(|err| {
                            let context =
                                format!("Cannot insert MassTransfer transaction {tx11:?}: {err}",);
                            Error::new(AppError::DbDieselError(err)).context(context)
                        })?;
                    diesel::insert_into(txs_11_transfers::table)
                        .values(transfers)
                        .execute(&self.conn)
                        .map(|_| ())
                        .map_err(|err| {
                            let context = format!(
                                "Cannot insert MassTransfer transfers {transfers:?}: {err}",
                            );
                            Error::new(AppError::DbDieselError(err)).context(context)
                        })?;
                }
                Tx::DataTransaction(t) => {
                    let (tx12, data) = t;
                    diesel::insert_into(txs_12::table)
                        .values(tx12)
                        .execute(&self.conn)
                        .map(|_| ())
                        .map_err(|err| {
                            let context = format!(
                                "Cannot insert DataTransaction transaction {tx12:?}: {err}",
                            );
                            Error::new(AppError::DbDieselError(err)).context(context)
                        })?;
                    diesel::insert_into(txs_12_data::table)
                        .values(data)
                        .execute(&self.conn)
                        .map(|_| ())
                        .map_err(|err| {
                            let context =
                                format!("Cannot insert DataTransaction data {data:?}: {err}",);
                            Error::new(AppError::DbDieselError(err)).context(context)
                        })?;
                }
                Tx::SetScript(t) => diesel::insert_into(txs_13::table)
                    .values(t)
                    .execute(&self.conn)
                    .map(|_| ())
                    .map_err(|err| {
                        let context = format!("Cannot insert SetScript transaction {t:?}: {err}",);
                        Error::new(AppError::DbDieselError(err)).context(context)
                    })?,
                Tx::SponsorFee(t) => diesel::insert_into(txs_14::table)
                    .values(t)
                    .execute(&self.conn)
                    .map(|_| ())
                    .map_err(|err| {
                        let context = format!("Cannot insert SponsorFee transaction {t:?}: {err}",);
                        Error::new(AppError::DbDieselError(err)).context(context)
                    })?,
                Tx::SetAssetScript(t) => diesel::insert_into(txs_15::table)
                    .values(t)
                    .execute(&self.conn)
                    .map(|_| ())
                    .map_err(|err| {
                        let context =
                            format!("Cannot insert SetAssetScript transaction {t:?}: {err}",);
                        Error::new(AppError::DbDieselError(err)).context(context)
                    })?,
                Tx::InvokeScript(t) => {
                    let (tx16, args, payments) = t;
                    diesel::insert_into(txs_16::table)
                        .values(tx16)
                        .execute(&self.conn)
                        .map(|_| ())
                        .map_err(|err| {
                            let context =
                                format!("Cannot insert InvokeScript transaction {tx16:?}: {err}",);
                            Error::new(AppError::DbDieselError(err)).context(context)
                        })?;
                    diesel::insert_into(txs_16_args::table)
                        .values(args)
                        .execute(&self.conn)
                        .map(|_| ())
                        .map_err(|err| {
                            let context =
                                format!("Cannot insert InvokeScript args {args:?}: {err}",);
                            Error::new(AppError::DbDieselError(err)).context(context)
                        })?;
                    diesel::insert_into(txs_16_payment::table)
                        .values(payments)
                        .execute(&self.conn)
                        .map(|_| ())
                        .map_err(|err| {
                            let context =
                                format!("Cannot insert InvokeScript payments {payments:?}: {err}",);
                            Error::new(AppError::DbDieselError(err)).context(context)
                        })?
                }
                Tx::UpdateAssetInfo(t) => diesel::insert_into(txs_17::table)
                    .values(t)
                    .execute(&self.conn)
                    .map(|_| ())
                    .map_err(|err| {
                        let context =
                            format!("Cannot insert UpdateAssetInfo transaction {t:?}: {err}",);
                        Error::new(AppError::DbDieselError(err)).context(context)
                    })?,
                Tx::InvokeExpression => todo!(),
            };
        }
        Ok(())
    }
}
