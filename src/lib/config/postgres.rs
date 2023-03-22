use crate::error::Error;
use serde::Deserialize;

fn default_port() -> u16 {
    5432
}

fn default_poolsize() -> u32 {
    1
}

#[derive(Deserialize)]
struct ConfigFlat {
    host: String,
    #[serde(default = "default_port")]
    port: u16,
    database: String,
    user: String,
    password: String,
    #[serde(default = "default_poolsize")]
    poolsize: u32,
}

#[derive(Debug, Clone)]
pub struct Config {
    pub host: String,
    pub port: u16,
    pub database: String,
    pub user: String,
    pub password: String,
    pub poolsize: u32,
}

pub fn load() -> Result<Config, Error> {
    let config_flat = envy::prefixed("POSTGRES__").from_env::<ConfigFlat>()?;

    Ok(Config {
        host: config_flat.host,
        port: config_flat.port,
        database: config_flat.database,
        user: config_flat.user,
        password: config_flat.password,
        poolsize: config_flat.poolsize,
    })
}
