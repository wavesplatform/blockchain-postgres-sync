use anyhow::{Error, Result};
use deadpool_diesel::{Manager as DManager, Pool as DPool, Runtime};
use diesel::pg::PgConnection;
use diesel::r2d2::{ConnectionManager, Pool};
use diesel::Connection;
use std::time::Duration;

use crate::config::postgres::Config;
use crate::error::Error as AppError;

pub type PgPool = Pool<ConnectionManager<PgConnection>>;
pub type PgAsyncPool = DPool<DManager<PgConnection>>;

pub fn generate_postgres_url(config: &Config) -> String {
    format!(
        "postgres://{}:{}@{}:{}/{}",
        config.user, config.password, config.host, config.port, config.database
    )
}

pub async fn async_pool(config: &Config) -> Result<PgAsyncPool> {
    let db_url = generate_postgres_url(config);

    let manager = DManager::new(db_url, Runtime::Tokio1);
    let pool = DPool::builder(manager)
        .max_size(config.poolsize as usize)
        .wait_timeout(Some(Duration::from_secs(10 * 60)))
        .runtime(Runtime::Tokio1)
        .build()?;
    Ok(pool)
}

pub fn pool(config: &Config) -> Result<PgPool, AppError> {
    let db_url = generate_postgres_url(config);

    let manager = ConnectionManager::<PgConnection>::new(db_url);
    Ok(Pool::builder()
        .min_idle(Some(1))
        .max_size(config.poolsize as u32)
        .idle_timeout(Some(Duration::from_secs(10 * 60)))
        .connection_timeout(Duration::from_secs(5))
        .build(manager)?)
}

pub fn unpooled(config: &Config) -> Result<PgConnection> {
    let db_url = generate_postgres_url(config);

    PgConnection::establish(&db_url).map_err(|err| Error::new(AppError::ConnectionError(err)))
}
