use crate::error::Error;
use chrono::Duration;
use serde::Deserialize;

fn default_assets_only() -> bool {
    false
}

fn default_updates_per_request() -> usize {
    256
}

fn default_max_wait_time_in_msecs() -> u64 {
    5000
}

#[derive(Deserialize)]
struct ConfigFlat {
    asset_storage_address: Option<String>,
    #[serde(default = "default_assets_only")]
    assets_only: bool,
    blockchain_updates_url: String,
    chain_id: u8,
    #[serde(default = "default_max_wait_time_in_msecs")]
    max_wait_time_in_msecs: u64,
    starting_height: u32,
    #[serde(default = "default_updates_per_request")]
    updates_per_request: usize,
}

#[derive(Debug, Clone)]
pub struct Config {
    pub asset_storage_address: Option<String>,
    pub assets_only: bool,
    pub blockchain_updates_url: String,
    pub chain_id: u8,
    pub max_wait_time: Duration,
    pub starting_height: u32,
    pub updates_per_request: usize,
}

pub fn load() -> Result<Config, Error> {
    let config_flat = envy::from_env::<ConfigFlat>()?;

    Ok(Config {
        asset_storage_address: config_flat.asset_storage_address,
        assets_only: config_flat.assets_only,
        blockchain_updates_url: config_flat.blockchain_updates_url,
        chain_id: config_flat.chain_id,
        max_wait_time: Duration::milliseconds(config_flat.max_wait_time_in_msecs as i64),
        starting_height: config_flat.starting_height,
        updates_per_request: config_flat.updates_per_request,
    })
}
