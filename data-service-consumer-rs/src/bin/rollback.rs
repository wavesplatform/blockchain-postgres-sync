use anyhow::{Error, Result};
use app_lib::{
    config,
    consumer::{repo::pg::PgRepoOperations, rollback},
    db::generate_postgres_url,
};
use diesel::Connection;
use diesel::{dsl::sql_query, pg::PgConnection, RunQueryDsl};

fn main() -> Result<()> {
    let db_config = config::postgres::load()?;
    let rollback_config = config::rollback::load()?;
    let mut conn = PgConnection::establish(&generate_postgres_url(&db_config))?;

    conn.transaction(|conn| {
        sql_query("SET enable_seqscan = OFF;").execute(conn)?;
        rollback(
            &mut PgRepoOperations { conn },
            rollback_config.rollback_to,
            rollback_config.assets_only,
        )
    })
    .map_err(Error::from)
}
