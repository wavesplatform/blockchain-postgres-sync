pub mod pg;

use anyhow::Result;

use super::models::assets::{AssetOrigin, AssetOverride, AssetUpdate, DeletedAsset};
use super::models::block_microblock::BlockMicroblock;
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
}
