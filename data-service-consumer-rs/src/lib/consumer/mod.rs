pub mod models;
pub mod repo;
pub mod updates;

use anyhow::{Error, Result};
use bigdecimal::BigDecimal;
use chrono::{DateTime, Duration, NaiveDateTime, Utc};
use itertools::Itertools;
use std::collections::HashMap;
use std::sync::Mutex;
use std::time::Instant;
use tokio::sync::mpsc::Receiver;
use waves_protobuf_schemas::waves::{
    data_transaction_data::data_entry::Value,
    events::{transaction_metadata::Metadata, StateUpdate, TransactionMetadata},
    signed_transaction::Transaction,
    SignedTransaction, Transaction as WavesTx,
};
use wavesexchange_log::{debug, info, timer};

use self::models::{asset_tickers::InsertableAssetTicker, block_microblock::BlockMicroblock};
use self::models::{
    asset_tickers::{AssetTickerOverride, DeletedAssetTicker},
    assets::{AssetOrigin, AssetOverride, AssetUpdate, DeletedAsset},
};
use self::repo::RepoOperations;
use crate::error::Error as AppError;
use crate::models::BaseAssetInfoUpdate;
use crate::waves::{extract_asset_id, Address};
use crate::{config::consumer::Config, utils::into_base58};
use crate::{
    consumer::models::{
        txs::convert::{Tx as ConvertedTx, TxUidGenerator},
        waves_data::WavesData,
    },
    utils::{epoch_ms_to_naivedatetime, escape_unicode_null},
    waves::WAVES_ID,
};
use fragstrings::frag_parse;

static UID_GENERATOR: Mutex<TxUidGenerator> = Mutex::new(TxUidGenerator::new(100000));

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

#[derive(Debug)]
pub struct AssetTickerUpdate {
    pub asset_id: String,
    pub ticker: String,
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
pub async fn start<T, R>(updates_src: T, repo: R, config: Config) -> Result<()>
where
    T: UpdatesSource + Send + 'static,
    R: repo::Repo + Clone + Send + 'static,
{
    let Config {
        assets_only,
        chain_id,
        max_wait_time,
        starting_height,
        updates_per_request,
        asset_storage_address,
        ..
    } = config;

    let asset_storage_address: Option<&'static str> =
        asset_storage_address.map(|a| &*Box::leak(a.into_boxed_str()));
    let starting_from_height = {
        repo.transaction(move |ops| match ops.get_prev_handled_height() {
            Ok(Some(prev_handled_height)) => {
                rollback(ops, prev_handled_height.uid, assets_only)?;
                Ok(prev_handled_height.height as u32 + 1)
            }
            Ok(None) => Ok(starting_height),
            Err(e) => Err(e),
        })
        .await?
    };

    info!(
        "Start fetching updates from height {}",
        starting_from_height
    );

    let mut rx = updates_src
        .stream(starting_from_height, updates_per_request, max_wait_time)
        .await?;

    loop {
        let mut start = Instant::now();

        let updates_with_height = rx.recv().await.ok_or_else(|| {
            Error::new(AppError::StreamClosed(
                "GRPC Stream was closed by the server".to_string(),
            ))
        })?;

        let updates_count = updates_with_height.updates.len();
        info!(
            "{} updates were received in {:?}",
            updates_count,
            start.elapsed()
        );

        let last_height = updates_with_height.last_height;

        start = Instant::now();

        repo.transaction(move |ops| {
            handle_updates(
                updates_with_height,
                ops,
                chain_id,
                assets_only,
                asset_storage_address,
            )?;

            info!(
                "{} updates were saved to database in {:?}. Last height is {}.",
                updates_count,
                start.elapsed(),
                last_height,
            );

            Ok(())
        })
        .await?;
    }
}

fn handle_updates<R: RepoOperations>(
    updates_with_height: BlockchainUpdatesWithLastHeight,
    repo: &mut R,
    chain_id: u8,
    assets_only: bool,
    asset_storage_address: Option<&str>,
) -> Result<()> {
    updates_with_height
        .updates
        .into_iter()
        .fold(&mut Vec::<UpdatesItem>::new(), |acc, cur| match cur {
            BlockchainUpdate::Block(b) => {
                info!("Handle block {}, height = {}", b.id, b.height);
                let len = acc.len();
                if len > 0 {
                    match acc.get_mut(len as usize - 1).unwrap() {
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
                squash_microblocks(repo, assets_only)?;
                handle_appends(repo, chain_id, ba, assets_only, asset_storage_address)
            }
            UpdatesItem::Microblock(mba) => handle_appends(
                repo,
                chain_id,
                &vec![mba.to_owned()],
                assets_only,
                asset_storage_address,
            ),
            UpdatesItem::Rollback(sig) => {
                let block_uid = repo.get_block_uid(sig)?;
                rollback(repo, block_uid, assets_only)
            }
        })?;

    Ok(())
}

fn handle_appends<R>(
    repo: &mut R,
    chain_id: u8,
    appends: &Vec<BlockMicroblockAppend>,
    assets_only: bool,
    asset_storage_address: Option<&str>,
) -> Result<()>
where
    R: RepoOperations,
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

    timer!("blockchain updates handling");

    let base_asset_info_updates_with_block_uids: Vec<(i64, BaseAssetInfoUpdate)> =
        block_uids_with_appends
            .iter()
            .flat_map(|(block_uid, append)| {
                extract_base_asset_info_updates(chain_id, append)
                    .into_iter()
                    .map(|au| (*block_uid, au))
                    .collect_vec()
            })
            .collect();

    let inserted_uids =
        handle_base_asset_info_updates(repo, &base_asset_info_updates_with_block_uids)?;

    let updates_amount = base_asset_info_updates_with_block_uids.len();

    if let Some(uids) = inserted_uids {
        assert_eq!(uids.len(), base_asset_info_updates_with_block_uids.len());
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

        assert_eq!(asset_origins.len(), updates_amount);
        repo.insert_asset_origins(&asset_origins)?;
    }

    info!("handled {} assets updates", updates_amount);

    if !assets_only {
        handle_txs(repo, &block_uids_with_appends, chain_id)?;

        let waves_data = appends
            .into_iter()
            .filter_map(|append| {
                append.updated_waves_amount.map(|reward| WavesData {
                    height: append.height,
                    quantity: BigDecimal::from(reward),
                })
            })
            .collect_vec();

        if waves_data.len() > 0 {
            repo.insert_waves_data(&waves_data)?;
        }
    }

    timer!("asset tickers updates handling");

    if let Some(storage_addr) = asset_storage_address {
        let asset_tickers_updates_with_block_uids: Vec<(&i64, AssetTickerUpdate)> =
            block_uids_with_appends
                .iter()
                .flat_map(|(block_uid, append)| {
                    append
                        .txs
                        .iter()
                        .flat_map(|tx| extract_asset_tickers_updates(tx, storage_addr))
                        .map(|u| (block_uid, u))
                        .collect_vec()
                })
                .collect();

        handle_asset_tickers_updates(repo, &asset_tickers_updates_with_block_uids)?;

        info!(
            "handled {} asset tickers updates",
            asset_tickers_updates_with_block_uids.len()
        );
    }

    Ok(())
}

fn handle_txs<R: RepoOperations>(
    repo: &mut R,
    block_uid_data: &Vec<(i64, &BlockMicroblockAppend)>,
    chain_id: u8,
) -> Result<(), Error> {
    let mut txs_1 = vec![];
    let mut txs_2 = vec![];
    let mut txs_3 = vec![];
    let mut txs_4 = vec![];
    let mut txs_5 = vec![];
    let mut txs_6 = vec![];
    let mut txs_7 = vec![];
    let mut txs_8 = vec![];
    let mut txs_9 = vec![];
    let mut txs_10 = vec![];
    let mut txs_11 = vec![];
    let mut txs_12 = vec![];
    let mut txs_13 = vec![];
    let mut txs_14 = vec![];
    let mut txs_15 = vec![];
    let mut txs_16 = vec![];
    let mut txs_17 = vec![];
    let mut txs_18 = vec![];

    let txs_count = block_uid_data
        .iter()
        .fold(0usize, |txs, (_, block)| txs + block.txs.len());
    info!("handling {} transactions", txs_count);

    let mut ugen = UID_GENERATOR.lock().unwrap();
    for (block_uid, bm) in block_uid_data {
        ugen.maybe_update_height(bm.height);

        for tx in &bm.txs {
            let tx_uid = ugen.next();
            let result_tx = ConvertedTx::try_from((
                &tx.data, &tx.id, bm.height, &tx.meta, tx_uid, *block_uid, chain_id,
            ))?;
            match result_tx {
                ConvertedTx::Genesis(t) => txs_1.push(t),
                ConvertedTx::Payment(t) => txs_2.push(t),
                ConvertedTx::Issue(t) => txs_3.push(t),
                ConvertedTx::Transfer(t) => txs_4.push(t),
                ConvertedTx::Reissue(t) => txs_5.push(t),
                ConvertedTx::Burn(t) => txs_6.push(t),
                ConvertedTx::Exchange(t) => txs_7.push(t),
                ConvertedTx::Lease(t) => txs_8.push(t),
                ConvertedTx::LeaseCancel(t) => txs_9.push(t),
                ConvertedTx::CreateAlias(t) => txs_10.push(t),
                ConvertedTx::MassTransfer(t) => txs_11.push(t),
                ConvertedTx::DataTransaction(t) => txs_12.push(t),
                ConvertedTx::SetScript(t) => txs_13.push(t),
                ConvertedTx::SponsorFee(t) => txs_14.push(t),
                ConvertedTx::SetAssetScript(t) => txs_15.push(t),
                ConvertedTx::InvokeScript(t) => txs_16.push(t),
                ConvertedTx::UpdateAssetInfo(t) => txs_17.push(t),
                ConvertedTx::Ethereum(t) => txs_18.push(t),
            }
        }
    }

    #[inline]
    fn insert_txs<T, F>(txs: Vec<T>, mut inserter: F) -> Result<()>
    where
        T: 'static,
        F: FnMut(Vec<T>) -> Result<()>,
    {
        if !txs.is_empty() {
            inserter(txs)?;
        }
        Ok(())
    }

    insert_txs(txs_1, |txs| repo.insert_txs_1(txs))?;
    insert_txs(txs_2, |txs| repo.insert_txs_2(txs))?;
    insert_txs(txs_3, |txs| repo.insert_txs_3(txs))?;
    insert_txs(txs_4, |txs| repo.insert_txs_4(txs))?;
    insert_txs(txs_5, |txs| repo.insert_txs_5(txs))?;
    insert_txs(txs_6, |txs| repo.insert_txs_6(txs))?;
    insert_txs(txs_7, |txs| repo.insert_txs_7(txs))?;
    insert_txs(txs_8, |txs| repo.insert_txs_8(txs))?;
    insert_txs(txs_9, |txs| repo.insert_txs_9(txs))?;
    insert_txs(txs_10, |txs| repo.insert_txs_10(txs))?;
    insert_txs(txs_11, |txs| repo.insert_txs_11(txs))?;
    insert_txs(txs_12, |txs| repo.insert_txs_12(txs))?;
    insert_txs(txs_13, |txs| repo.insert_txs_13(txs))?;
    insert_txs(txs_14, |txs| repo.insert_txs_14(txs))?;
    insert_txs(txs_15, |txs| repo.insert_txs_15(txs))?;
    insert_txs(txs_16, |txs| repo.insert_txs_16(txs))?;
    insert_txs(txs_17, |txs| repo.insert_txs_17(txs))?;
    insert_txs(txs_18, |txs| repo.insert_txs_18(txs))?;

    info!("{} transactions handled", txs_count);

    Ok(())
}

fn extract_base_asset_info_updates(
    chain_id: u8,
    append: &BlockMicroblockAppend,
) -> Vec<BaseAssetInfoUpdate> {
    let mut asset_updates = vec![];

    let mut updates_from_txs = append
        .txs
        .iter()
        .flat_map(|tx: &Tx| {
            tx.state_update
                .assets
                .iter()
                .filter_map(|asset_update| {
                    if let Some(asset_details) = &asset_update.after {
                        let asset_id = extract_asset_id(&asset_details.asset_id);

                        if asset_id == WAVES_ID {
                            return None;
                        }

                        let time_stamp = match tx.data.transaction.as_ref() {
                            Some(stx) => match stx {
                                Transaction::WavesTransaction(WavesTx { timestamp, .. }) => {
                                    DateTime::from_utc(epoch_ms_to_naivedatetime(*timestamp), Utc)
                                }
                                Transaction::EthereumTransaction(_) => {
                                    if let Some(Metadata::Ethereum(meta)) = &tx.meta.metadata {
                                        DateTime::from_utc(
                                            epoch_ms_to_naivedatetime(meta.timestamp),
                                            Utc,
                                        )
                                    } else {
                                        unreachable!("wrong meta variant")
                                    }
                                }
                            },
                            _ => Utc::now(),
                        };

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

fn extract_asset_tickers_updates(tx: &Tx, asset_storage_address: &str) -> Vec<AssetTickerUpdate> {
    tx.state_update
        .data_entries
        .iter()
        .filter_map(|data_entry_update| {
            data_entry_update.data_entry.as_ref().and_then(|de| {
                if asset_storage_address == into_base58(&data_entry_update.address)
                    && de.key.starts_with("%s%s__assetId2ticker__")
                {
                    match de.value.as_ref() {
                        Some(value) => match value {
                            Value::StringValue(value) => {
                                frag_parse!("%s%s", de.key).map(|(_, asset_id)| AssetTickerUpdate {
                                    asset_id: asset_id,
                                    ticker: value.clone(),
                                })
                            }
                            _ => None,
                        },
                        // key was deleted -> drop asset ticker
                        None => {
                            frag_parse!("%s%s", de.key).map(|(_, asset_id)| AssetTickerUpdate {
                                asset_id,
                                ticker: "".into(),
                            })
                        }
                    }
                } else {
                    None
                }
            })
        })
        .collect_vec()
}

fn handle_base_asset_info_updates<R: RepoOperations>(
    repo: &mut R,
    updates: &[(i64, BaseAssetInfoUpdate)],
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
            block_uid: *block_uid,
            asset_id: update.id.clone(),
            name: update.name.clone(),
            description: update.description.clone(),
            nft: update.nft,
            reissuable: update.reissuable,
            decimals: update.precision as i16,
            script: update.script.clone().map(base64::encode),
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

fn handle_asset_tickers_updates<R: RepoOperations>(
    repo: &mut R,
    updates: &[(&i64, AssetTickerUpdate)],
) -> Result<()> {
    if updates.is_empty() {
        return Ok(());
    }

    let updates_count = updates.len();

    let asset_tickers_next_uid = repo.get_next_asset_tickers_uid()?;

    let asset_tickers_updates = updates
        .iter()
        .enumerate()
        .map(
            |(update_idx, (block_uid, tickers_update))| InsertableAssetTicker {
                uid: asset_tickers_next_uid + update_idx as i64,
                superseded_by: -1,
                block_uid: *block_uid.clone(),
                asset_id: tickers_update.asset_id.clone(),
                ticker: tickers_update.ticker.clone(),
            },
        )
        .collect_vec();

    let mut asset_tickers_grouped: HashMap<InsertableAssetTicker, Vec<InsertableAssetTicker>> =
        HashMap::new();

    asset_tickers_updates.into_iter().for_each(|update| {
        let group = asset_tickers_grouped
            .entry(update.clone())
            .or_insert(vec![]);
        group.push(update);
    });

    let asset_tickers_grouped = asset_tickers_grouped.into_iter().collect_vec();

    let asset_tickers_grouped_with_uids_superseded_by = asset_tickers_grouped
        .into_iter()
        .map(|(group_key, group)| {
            let mut updates = group
                .into_iter()
                .sorted_by_key(|item| item.uid)
                .collect::<Vec<InsertableAssetTicker>>();

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
        .collect::<Vec<(InsertableAssetTicker, Vec<InsertableAssetTicker>)>>();

    let asset_tickers_first_uids: Vec<AssetTickerOverride> =
        asset_tickers_grouped_with_uids_superseded_by
            .iter()
            .map(|(_, group)| {
                let first = group.iter().next().unwrap().clone();
                AssetTickerOverride {
                    superseded_by: first.uid,
                    asset_id: first.asset_id,
                }
            })
            .collect();

    repo.close_asset_tickers_superseded_by(&asset_tickers_first_uids)?;

    let asset_tickers_with_uids_superseded_by = &asset_tickers_grouped_with_uids_superseded_by
        .clone()
        .into_iter()
        .flat_map(|(_, v)| v)
        .sorted_by_key(|asset_tickers| asset_tickers.uid)
        .collect_vec();

    repo.insert_asset_tickers(asset_tickers_with_uids_superseded_by)?;

    repo.set_asset_tickers_next_update_uid(asset_tickers_next_uid + updates_count as i64)
}

fn squash_microblocks<R: RepoOperations>(repo: &mut R, assets_only: bool) -> Result<()> {
    let last_microblock_id = repo.get_total_block_id()?;

    if let Some(lmid) = last_microblock_id {
        let last_block_uid = repo.get_key_block_uid()?;

        debug!(
            "squashing into block_uid = {}, new block_id = {}",
            last_block_uid, lmid
        );

        repo.update_assets_block_references(last_block_uid)?;
        repo.update_asset_tickers_block_references(last_block_uid)?;

        if !assets_only {
            repo.update_transactions_references(last_block_uid)?;
        }

        repo.delete_microblocks()?;
        repo.change_block_id(last_block_uid, &lmid)?;
    }

    Ok(())
}

pub fn rollback<R: RepoOperations>(repo: &mut R, block_uid: i64, assets_only: bool) -> Result<()> {
    debug!("rolling back to block_uid = {}", block_uid);

    rollback_assets(repo, block_uid)?;
    rollback_asset_tickers(repo, block_uid)?;

    if !assets_only {
        repo.rollback_transactions(block_uid)?;
    }

    repo.rollback_blocks_microblocks(block_uid)?;

    Ok(())
}

fn rollback_assets<R: RepoOperations>(repo: &mut R, block_uid: i64) -> Result<()> {
    let deleted = repo.rollback_assets(block_uid)?;

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

fn rollback_asset_tickers<R: RepoOperations>(repo: &mut R, block_uid: i64) -> Result<()> {
    let deleted = repo.rollback_asset_tickers(&block_uid)?;

    let mut grouped_deleted: HashMap<DeletedAssetTicker, Vec<DeletedAssetTicker>> = HashMap::new();

    deleted.into_iter().for_each(|item| {
        let group = grouped_deleted.entry(item.clone()).or_insert(vec![]);
        group.push(item);
    });

    let lowest_deleted_uids: Vec<i64> = grouped_deleted
        .into_iter()
        .filter_map(|(_, group)| group.into_iter().min_by_key(|i| i.uid).map(|i| i.uid))
        .collect();

    repo.reopen_asset_tickers_superseded_by(&lowest_deleted_uids)
}
