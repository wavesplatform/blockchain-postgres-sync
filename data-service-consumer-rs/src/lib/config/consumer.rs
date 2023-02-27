use crate::error::Error;
use serde::Deserialize;

fn default_assets_only() -> bool {
    false
}

#[derive(Deserialize)]
struct ConfigFlat {
    #[serde(default = "default_assets_only")]
    assets_only: bool,
}

#[derive(Debug, Clone)]
pub struct Config {
    pub assets_only: bool,
}

pub fn load() -> Result<Config, Error> {
    let config_flat = envy::from_env::<ConfigFlat>()?;

    Ok(Config {
        assets_only: config_flat.assets_only,
    })
}
