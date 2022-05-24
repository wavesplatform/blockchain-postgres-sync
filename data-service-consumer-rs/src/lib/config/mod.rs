pub mod node;
pub mod postgres;

use crate::error::Error;

#[derive(Debug, Clone)]
pub struct ConsumerConfig {
    pub node: node::Config,
    pub postgres: postgres::Config,
}

#[derive(Debug, Clone)]
pub struct MigrationConfig {
    pub postgres: postgres::Config,
}

pub async fn load_consumer_config() -> Result<ConsumerConfig, Error> {
    let node_config = node::load()?;
    let postgres_config = postgres::load()?;

    Ok(ConsumerConfig {
        node: node_config,
        postgres: postgres_config,
    })
}

pub fn load_migration_config() -> Result<MigrationConfig, Error> {
    let postgres_config = postgres::load()?;

    Ok(MigrationConfig {
        postgres: postgres_config,
    })
}
