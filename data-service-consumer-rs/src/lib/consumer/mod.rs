pub mod function_call;
pub mod models;
pub mod repo;
pub mod updates;

use anyhow::{Error, Result};
use chrono::{DateTime, Duration, NaiveDateTime, Utc};
use itertools::Itertools;
use std::collections::HashMap;
use std::str;
use std::sync::Arc;
use std::time::Instant;
use tokio::sync::mpsc::Receiver;
use waves_protobuf_schemas::waves::{
    events::{StateUpdate, TransactionMetadata},
    signed_transaction::Transaction,
    SignedTransaction, Transaction as WavesTx,
};
use wavesexchange_log::{debug, info, timer};

use self::models::assets::{AssetOrigin, AssetOverride, AssetUpdate, DeletedAsset};
use self::models::block_microblock::BlockMicroblock;
use crate::consumer::models::txs::{Tx as ConvertedTx, TxUidGenerator};
use crate::error::Error as AppError;
use crate::models::BaseAssetInfoUpdate;
use crate::waves::{get_asset_id, Address};

#[derive(Clone, Debug)]
pub enum BlockchainUpdate {
    Block(BlockMicroblockAppend),
    Microblock(BlockMicroblockAppend),
    Rollback(String),
}

#[derive(Clone, Debug)]
pub struct BlockMicroblockAppend {
    id: String,
    time_stamp: Option<NaiveDateTime>,
    height: i32,
    updated_waves_amount: Option<i64>,
    txs: Vec<Tx>,
}

#[derive(Clone, Debug)]
pub struct Tx {
    pub id: String,
    pub data: SignedTransaction,
    pub meta: TransactionMetadata,
    pub state_update: StateUpdate,
}

#[derive(Debug)]
pub struct BlockchainUpdatesWithLastHeight {
    pub last_height: u32,
    pub updates: Vec<BlockchainUpdate>,
}

#[derive(Debug, Queryable)]
pub struct PrevHandledHeight {
    pub uid: i64,
    pub height: i32,
}

#[derive(Debug)]
enum UpdatesItem {
    Blocks(Vec<BlockMicroblockAppend>),
    Microblock(BlockMicroblockAppend),
    Rollback(String),
}

#[async_trait::async_trait]
pub trait UpdatesSource {
    async fn stream(
        self,
        from_height: u32,
        batch_max_size: usize,
        batch_max_time: Duration,
    ) -> Result<Receiver<BlockchainUpdatesWithLastHeight>, AppError>;
}

// TODO: handle shutdown signals -> rollback current transaction
pub async fn start<T, R>(
    starting_height: u32,
    updates_src: T,
    repo: Arc<R>,
    updates_per_request: usize,
    max_duration: Duration,
    chain_id: u8,
) -> Result<()>
where
    T: UpdatesSource + Send + Sync + 'static,
    R: repo::Repo,
{
    let starting_from_height = match repo.get_prev_handled_height()? {
        Some(prev_handled_height) => {
            repo.transaction(|| rollback(repo.clone(), prev_handled_height.uid))?;
            prev_handled_height.height as u32 + 1
        }
        None => starting_height,
    };

    info!(
        "Start fetching updates from height {}",
        starting_from_height
    );

    let mut rx = updates_src
        .stream(starting_from_height, updates_per_request, max_duration)
        .await?;

    loop {
        let mut start = Instant::now();

        let updates_with_height = rx.recv().await.ok_or(Error::new(AppError::StreamClosed(
            "GRPC Stream was closed by the server".to_string(),
        )))?;

        let updates_count = updates_with_height.updates.len();
        info!(
            "{} updates were received in {:?}",
            updates_count,
            start.elapsed()
        );

        let last_height = updates_with_height.last_height;

        start = Instant::now();

        repo.transaction(|| {
            handle_updates(updates_with_height, repo.clone(), chain_id)?;

            info!(
                "{} updates were handled in {:?} ms. Last updated height is {}.",
                updates_count,
                start.elapsed().as_millis(),
                last_height
            );

            Ok(())
        })?;
    }
}

fn handle_updates<'a, R>(
    updates_with_height: BlockchainUpdatesWithLastHeight,
    repo: Arc<R>,
    chain_id: u8,
) -> Result<()>
where
    R: repo::Repo,
{
    updates_with_height
        .updates
        .into_iter()
        .fold::<&mut Vec<UpdatesItem>, _>(&mut vec![], |acc, cur| match cur {
            BlockchainUpdate::Block(b) => {
                info!("Handle block {}, height = {}", b.id, b.height);
                let len = acc.len();
                if acc.len() > 0 {
                    match acc.iter_mut().nth(len as usize - 1).unwrap() {
                        UpdatesItem::Blocks(v) => {
                            v.push(b);
                            acc
                        }
                        UpdatesItem::Microblock(_) | UpdatesItem::Rollback(_) => {
                            acc.push(UpdatesItem::Blocks(vec![b]));
                            acc
                        }
                    }
                } else {
                    acc.push(UpdatesItem::Blocks(vec![b]));
                    acc
                }
            }
            BlockchainUpdate::Microblock(mba) => {
                info!("Handle microblock {}, height = {}", mba.id, mba.height);
                acc.push(UpdatesItem::Microblock(mba));
                acc
            }
            BlockchainUpdate::Rollback(sig) => {
                info!("Handle rollback to {}", sig);
                acc.push(UpdatesItem::Rollback(sig));
                acc
            }
        })
        .into_iter()
        .try_fold((), |_, update_item| match update_item {
            UpdatesItem::Blocks(ba) => {
                squash_microblocks(repo.clone())?;
                handle_appends(repo.clone(), chain_id, ba.as_ref())
            }
            UpdatesItem::Microblock(mba) => {
                handle_appends(repo.clone(), chain_id, &vec![mba.to_owned()])
            }
            UpdatesItem::Rollback(sig) => {
                let block_uid = repo.clone().get_block_uid(&sig)?;
                rollback(repo.clone(), block_uid)
            }
        })?;

    Ok(())
}

fn handle_appends<R>(repo: Arc<R>, chain_id: u8, appends: &Vec<BlockMicroblockAppend>) -> Result<()>
where
    R: repo::Repo,
{
    let block_uids = repo.insert_blocks_or_microblocks(
        &appends
            .into_iter()
            .map(|append| BlockMicroblock {
                id: append.id.clone(),
                height: append.height as i32,
                time_stamp: append.time_stamp,
            })
            .collect_vec(),
    )?;

    let block_uids_with_appends = block_uids.into_iter().zip(appends).collect_vec();

    timer!("assets updates handling");

    let base_asset_info_updates_with_block_uids: Vec<(&i64, BaseAssetInfoUpdate)> =
        block_uids_with_appends
            .iter()
            .flat_map(|(block_uid, append)| {
                extract_base_asset_info_updates(chain_id, append)
                    .into_iter()
                    .map(|au| (block_uid, au))
                    .collect_vec()
            })
            .collect();

    let inserted_uids =
        handle_base_asset_info_updates(repo.clone(), &base_asset_info_updates_with_block_uids)?;

    let updates_amount = base_asset_info_updates_with_block_uids.len();

    if let Some(uids) = inserted_uids {
        let asset_origins = uids
            .into_iter()
            .zip(base_asset_info_updates_with_block_uids)
            .map(|(uid, (_, au))| AssetOrigin {
                asset_id: au.id,
                first_asset_update_uid: uid,
                origin_transaction_id: au.tx_id,
                issuer: au.issuer,
                issue_height: au.update_height,
                issue_time_stamp: au.updated_at.naive_utc(),
            })
            .collect_vec();

        repo.insert_asset_origins(&asset_origins)?;
    }

    info!("handled {} assets updates", updates_amount);

    handle_txs(repo.clone(), appends)?;

    Ok(())
}

fn handle_txs<R: repo::Repo>(repo: Arc<R>, bma: &Vec<BlockMicroblockAppend>) -> Result<(), Error> {
    //TODO: optimize this
    let mut txs = vec![];
    let mut ugen = TxUidGenerator::new(Some(100000));
    for bm in bma {
        for tx in &bm.txs {
            ugen.maybe_update_height(bm.height as usize);
            let result_tx = ConvertedTx::try_from((
                &tx.data,
                &tx.id,
                bm.height,
                &tx.meta.sender_address,
                &mut ugen,
            ))?;
            txs.push(result_tx);
        }
    }
    repo.insert_txs(&txs)?;

    info!("handled {} transactions", txs.len());

    Ok(())
}

fn extract_base_asset_info_updates(
    chain_id: u8,
    append: &BlockMicroblockAppend,
) -> Vec<BaseAssetInfoUpdate> {
    let mut asset_updates = vec![];

    let update_time_stamp = match append.time_stamp {
        Some(time_stamp) => DateTime::from_utc(time_stamp, Utc),
        None => Utc::now(),
    };

    if let Some(updated_waves_amount) = append.updated_waves_amount {
        asset_updates.push(BaseAssetInfoUpdate::waves_update(
            append.height as i32,
            update_time_stamp,
            updated_waves_amount,
        ));
    }

    let mut updates_from_txs = append
        .txs
        .iter()
        .flat_map(|tx| {
            tx.state_update
                .assets
                .iter()
                .filter_map(|asset_update| {
                    if let Some(asset_details) = &asset_update.after {
                        let time_stamp = match tx.data.transaction.as_ref() {
                            Some(stx) => match stx {
                                Transaction::WavesTransaction(WavesTx { timestamp, .. }) => {
                                    DateTime::from_utc(
                                        NaiveDateTime::from_timestamp(
                                            timestamp / 1000,
                                            *timestamp as u32 % 1000 * 1000,
                                        ),
                                        Utc,
                                    )
                                }
                                Transaction::EthereumTransaction(_) => return None,
                            },
                            _ => Utc::now(),
                        };

                        let asset_id = get_asset_id(&asset_details.asset_id);
                        let issuer =
                            Address::from((asset_details.issuer.as_slice(), chain_id)).into();
                        Some(BaseAssetInfoUpdate {
                            update_height: append.height as i32,
                            updated_at: time_stamp,
                            id: asset_id,
                            name: escape_unicode_null(&asset_details.name),
                            description: escape_unicode_null(&asset_details.description),
                            issuer,
                            precision: asset_details.decimals,
                            script: asset_details.script_info.clone().map(|s| s.script),
                            nft: asset_details.nft,
                            reissuable: asset_details.reissuable,
                            min_sponsored_fee: if asset_details.sponsorship > 0 {
                                Some(asset_details.sponsorship)
                            } else {
                                None
                            },
                            quantity: asset_details.volume.to_owned(),
                            tx_id: tx.id.clone(),
                        })
                    } else {
                        None
                    }
                })
                .collect_vec()
        })
        .collect_vec();

    asset_updates.append(&mut updates_from_txs);
    asset_updates
}

fn handle_base_asset_info_updates<R: repo::Repo>(
    repo: Arc<R>,
    updates: &[(&i64, BaseAssetInfoUpdate)],
) -> Result<Option<Vec<i64>>> {
    if updates.is_empty() {
        return Ok(None);
    }

    let updates_count = updates.len();

    let assets_next_uid = repo.get_next_assets_uid()?;

    let asset_updates = updates
        .iter()
        .enumerate()
        .map(|(update_idx, (block_uid, update))| AssetUpdate {
            uid: assets_next_uid + update_idx as i64,
            superseded_by: -1,
            block_uid: *block_uid.clone(),
            asset_id: update.id.clone(),
            name: update.name.clone(),
            description: update.description.clone(),
            nft: update.nft,
            reissuable: update.reissuable,
            decimals: update.precision as i16,
            script: update.script.clone().map(|s| base64::encode(s)),
            sponsorship: update.min_sponsored_fee,
            volume: update.quantity,
        })
        .collect_vec();

    let mut assets_grouped: HashMap<AssetUpdate, Vec<AssetUpdate>> = HashMap::new();

    asset_updates.into_iter().for_each(|update| {
        let group = assets_grouped.entry(update.clone()).or_insert(vec![]);
        group.push(update);
    });

    let assets_grouped = assets_grouped.into_iter().collect_vec();

    let assets_grouped_with_uids_superseded_by = assets_grouped
        .into_iter()
        .map(|(group_key, group)| {
            let mut updates = group
                .into_iter()
                .sorted_by_key(|item| item.uid)
                .collect::<Vec<AssetUpdate>>();

            let mut last_uid = std::i64::MAX - 1;
            (
                group_key,
                updates
                    .as_mut_slice()
                    .iter_mut()
                    .rev()
                    .map(|cur| {
                        cur.superseded_by = last_uid;
                        last_uid = cur.uid;
                        cur.to_owned()
                    })
                    .sorted_by_key(|item| item.uid)
                    .collect(),
            )
        })
        .collect::<Vec<(AssetUpdate, Vec<AssetUpdate>)>>();

    let assets_first_uids: Vec<AssetOverride> = assets_grouped_with_uids_superseded_by
        .iter()
        .map(|(_, group)| {
            let first = group.iter().next().unwrap().clone();
            AssetOverride {
                superseded_by: first.uid,
                id: first.asset_id,
            }
        })
        .collect();

    repo.close_assets_superseded_by(&assets_first_uids)?;

    let assets_with_uids_superseded_by = &assets_grouped_with_uids_superseded_by
        .clone()
        .into_iter()
        .flat_map(|(_, v)| v)
        .sorted_by_key(|asset| asset.uid)
        .collect_vec();

    repo.insert_asset_updates(assets_with_uids_superseded_by)?;
    repo.set_assets_next_update_uid(assets_next_uid + updates_count as i64)?;

    Ok(Some(
        assets_with_uids_superseded_by
            .into_iter()
            .map(|a| a.uid)
            .collect_vec(),
    ))
}

fn squash_microblocks<R: repo::Repo>(storage: Arc<R>) -> Result<()> {
    let total_block_id = storage.get_total_block_id()?;

    if let Some(tbid) = total_block_id {
        let key_block_uid = storage.get_key_block_uid()?;
        storage.update_assets_block_references(&key_block_uid)?;
        storage.delete_microblocks()?;
        storage.change_block_id(&key_block_uid, &tbid)?;
    }

    Ok(())
}

fn rollback<R>(repo: Arc<R>, block_uid: i64) -> Result<()>
where
    R: repo::Repo,
{
    debug!("rollbacking to block_uid = {}", block_uid);

    rollback_assets(repo.clone(), block_uid)?;

    repo.rollback_blocks_microblocks(&block_uid)?;

    Ok(())
}

fn rollback_assets<R: repo::Repo>(repo: Arc<R>, block_uid: i64) -> Result<()> {
    let deleted = repo.rollback_assets(&block_uid)?;

    let mut grouped_deleted: HashMap<DeletedAsset, Vec<DeletedAsset>> = HashMap::new();

    deleted.into_iter().for_each(|item| {
        let group = grouped_deleted.entry(item.clone()).or_insert(vec![]);
        group.push(item);
    });

    let lowest_deleted_uids: Vec<i64> = grouped_deleted
        .into_iter()
        .filter_map(|(_, group)| group.into_iter().min_by_key(|i| i.uid).map(|i| i.uid))
        .collect();

    repo.reopen_assets_superseded_by(&lowest_deleted_uids)
}

fn escape_unicode_null(s: &str) -> String {
    s.replace("\0", "\\0")
}
