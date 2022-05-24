use chrono::Duration;

use serde::Deserialize;

use crate::error::Error;

fn default_updates_per_request() -> usize {
    256
}

fn default_max_wait_time_in_msecs() -> u64 {
    5000
}

#[derive(Deserialize)]
struct ConfigFlat {
    host: String,
    port: u32,
    #[serde(default = "default_updates_per_request")]
    max_batch_size: usize,
    #[serde(default = "default_max_wait_time_in_msecs")]
    max_batch_wait_time_ms: u64,
}

#[derive(Debug, Clone)]
pub struct Config {
    pub host: String,
    pub port: u32,
    pub updates_per_request: usize,
    pub max_wait_time: Duration,
}

pub fn load() -> Result<Config, Error> {
    let config_flat = envy::prefixed("NODE_").from_env::<ConfigFlat>()?;

    Ok(Config {
        host: config_flat.host,
        port: config_flat.port,
        updates_per_request: config_flat.max_batch_size,
        max_wait_time: Duration::milliseconds(config_flat.max_batch_wait_time_ms as i64),
    })
}
