use crate::error::Error;
use chrono::Duration;
use serde::Deserialize;

fn default_updates_per_request() -> usize {
    256
}

fn default_max_wait_time_in_msecs() -> u64 {
    5000
}

#[derive(Deserialize)]
struct ConfigFlat {
    blockchain_updates_url: String,
    starting_height: u32,
    #[serde(default = "default_updates_per_request")]
    updates_per_request: usize,
    #[serde(default = "default_max_wait_time_in_msecs")]
    max_wait_time_in_msecs: u64,
    chain_id: u8,
}

#[derive(Debug, Clone)]
pub struct Config {
    pub blockchain_updates_url: String,
    pub starting_height: u32,
    pub updates_per_request: usize,
    pub max_wait_time: Duration,
    pub chain_id: u8,
}

pub fn load() -> Result<Config, Error> {
    let config_flat = envy::from_env::<ConfigFlat>()?;

    Ok(Config {
        blockchain_updates_url: config_flat.blockchain_updates_url,
        starting_height: config_flat.starting_height,
        updates_per_request: config_flat.updates_per_request,
        max_wait_time: Duration::milliseconds(config_flat.max_wait_time_in_msecs as i64),
        chain_id: config_flat.chain_id,
    })
}
