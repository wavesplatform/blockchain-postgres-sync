pub mod pg;

use anyhow::Result;

use super::models::assets::{AssetOrigin, AssetOverride, AssetUpdate, DeletedAsset};
use super::models::block_microblock::BlockMicroblock;
use super::models::txs::*;
use super::models::waves_data::WavesData;
use super::PrevHandledHeight;

#[async_trait::async_trait]
pub trait Repo {
    //
    // COMMON
    //

    fn transaction(&self, f: impl FnOnce() -> Result<()>) -> Result<()>;

    fn get_prev_handled_height(&self) -> Result<Option<PrevHandledHeight>>;

    fn get_block_uid(&self, block_id: &str) -> Result<i64>;

    fn get_key_block_uid(&self) -> Result<i64>;

    fn get_total_block_id(&self) -> Result<Option<String>>;

    fn insert_blocks_or_microblocks(&self, blocks: &Vec<BlockMicroblock>) -> Result<Vec<i64>>;

    fn change_block_id(&self, block_uid: &i64, new_block_id: &str) -> Result<()>;

    fn delete_microblocks(&self) -> Result<()>;

    fn rollback_blocks_microblocks(&self, block_uid: &i64) -> Result<()>;

    fn insert_waves_data(&self, waves_data: &Vec<WavesData>) -> Result<()>;

    //
    // ASSETS
    //

    fn get_next_assets_uid(&self) -> Result<i64>;

    fn insert_asset_updates(&self, updates: &Vec<AssetUpdate>) -> Result<()>;

    fn insert_asset_origins(&self, origins: &Vec<AssetOrigin>) -> Result<()>;

    fn update_assets_block_references(&self, block_uid: &i64) -> Result<()>;

    fn close_assets_superseded_by(&self, updates: &Vec<AssetOverride>) -> Result<()>;

    fn reopen_assets_superseded_by(&self, current_superseded_by: &Vec<i64>) -> Result<()>;

    fn set_assets_next_update_uid(&self, new_uid: i64) -> Result<()>;

    fn rollback_assets(&self, block_uid: &i64) -> Result<Vec<DeletedAsset>>;

    fn assets_gt_block_uid(&self, block_uid: &i64) -> Result<Vec<i64>>;

    //
    // TRANSACTIONS
    //

    fn insert_txs_1(&self, txs: &Vec<Tx1>) -> Result<()>;

    fn insert_txs_2(&self, txs: &Vec<Tx2>) -> Result<()>;

    fn insert_txs_3(&self, txs: &Vec<Tx3>) -> Result<()>;

    fn insert_txs_4(&self, txs: &Vec<Tx4>) -> Result<()>;

    fn insert_txs_5(&self, txs: &Vec<Tx5>) -> Result<()>;

    fn insert_txs_6(&self, txs: &Vec<Tx6>) -> Result<()>;

    fn insert_txs_7(&self, txs: &Vec<Tx7>) -> Result<()>;

    fn insert_txs_8(&self, txs: &Vec<Tx8>) -> Result<()>;

    fn insert_txs_9(&self, txs: &Vec<Tx9Partial>) -> Result<()>;

    fn insert_txs_10(&self, txs: &Vec<Tx10>) -> Result<()>;

    fn insert_txs_11(&self, txs: &Vec<Tx11Combined>) -> Result<()>;

    fn insert_txs_12(&self, txs: &Vec<Tx12Combined>) -> Result<()>;

    fn insert_txs_13(&self, txs: &Vec<Tx13>) -> Result<()>;

    fn insert_txs_14(&self, txs: &Vec<Tx14>) -> Result<()>;

    fn insert_txs_15(&self, txs: &Vec<Tx15>) -> Result<()>;

    fn insert_txs_16(&self, txs: &Vec<Tx16Combined>) -> Result<()>;

    fn insert_txs_17(&self, txs: &Vec<Tx17>) -> Result<()>;
}
