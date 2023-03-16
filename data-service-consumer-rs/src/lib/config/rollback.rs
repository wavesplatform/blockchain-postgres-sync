use anyhow::{Error, Result};
use serde::Deserialize;

fn default_assets_only() -> bool {
    false
}

#[derive(Deserialize)]
pub struct Config {
    #[serde(default = "default_assets_only")]
    pub assets_only: bool,
    pub rollback_to: i64,
}

pub fn load() -> Result<Config> {
    envy::from_env().map_err(Error::from)
}
