use anyhow::{Context, Result};
use app_lib::{config, consumer, db};
use std::sync::Arc;
use wavesexchange_log::{error, info};

#[tokio::main]
async fn main() -> Result<()> {
    let config = config::load_consumer_config()?;

    info!(
        "Starting asset-search consumer with config: {:?}",
        config.node
    );

    let conn = db::unpooled(&config.postgres).context("DB connection failed")?;

    let updates_src = consumer::updates::new(&config.node.blockchain_updates_url)
        .await
        .context("Consumer connection failed")?;

    let pg_repo = Arc::new(consumer::repo::pg::new(conn));

    if let Err(err) = consumer::start(
        config.node.starting_height,
        updates_src,
        pg_repo,
        config.node.updates_per_request,
        config.node.max_wait_time,
        config.node.chain_id,
    )
    .await
    {
        error!("{}", err);
        panic!("asset-search consumer panic: {}", err);
    }
    Ok(())
}
