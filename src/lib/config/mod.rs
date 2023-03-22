pub mod consumer;
pub mod postgres;
pub mod rollback;

use crate::error::Error;

#[derive(Debug, Clone)]
pub struct Config {
    pub postgres: postgres::Config,
    pub consumer: consumer::Config,
}

#[derive(Debug, Clone)]
pub struct MigrationConfig {
    pub postgres: postgres::Config,
}

pub fn load_consumer_config() -> Result<Config, Error> {
    Ok(Config {
        postgres: postgres::load()?,
        consumer: consumer::load()?,
    })
}

pub fn load_migration_config() -> Result<MigrationConfig, Error> {
    Ok(MigrationConfig {
        postgres: postgres::load()?,
    })
}
