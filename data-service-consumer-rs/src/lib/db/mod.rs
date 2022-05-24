use anyhow::{Error, Result};
use diesel::pg::PgConnection;
use diesel::r2d2::{ConnectionManager, Pool};
use diesel::Connection;
use std::time::Duration;

use crate::config::postgres::Config;
use crate::error::Error as AppError;

pub type PgPool = Pool<ConnectionManager<PgConnection>>;

fn generate_postgres_url(
    user: &str,
    password: &str,
    host: &str,
    port: &u16,
    database: &str,
) -> String {
    format!(
        "postgres://{}:{}@{}:{}/{}",
        user, password, host, port, database
    )
}

pub fn pool(config: &Config) -> Result<PgPool, AppError> {
    let db_url = generate_postgres_url(
        &config.user,
        &config.password,
        &config.host,
        &config.port,
        &config.database,
    );

    let manager = ConnectionManager::<PgConnection>::new(db_url);
    Ok(Pool::builder()
        .min_idle(Some(1))
        .max_size(config.poolsize as u32)
        .idle_timeout(Some(Duration::from_secs(5 * 60)))
        .connection_timeout(Duration::from_secs(5))
        .build(manager)?)
}

pub fn unpooled(config: &Config) -> Result<PgConnection> {
    let db_url = generate_postgres_url(
        &config.user,
        &config.password,
        &config.host,
        &config.port,
        &config.database,
    );

    PgConnection::establish(&db_url).map_err(|err| Error::new(AppError::ConnectionError(err)))
}
