use anyhow::{Context, Result};
use app_lib::{config, consumer, db};
use std::time::Duration;
use tokio::select;
use wavesexchange_liveness::channel;
use wavesexchange_log::{error, info};
use wavesexchange_warp::MetricsWarpBuilder;

const LAST_TIMESTAMP_QUERY: &str = "SELECT (EXTRACT(EPOCH FROM time_stamp) * 1000)::BIGINT as time_stamp FROM blocks_microblocks WHERE time_stamp IS NOT NULL ORDER BY uid DESC LIMIT 1";
const POLL_INTERVAL_SECS: u64 = 60;
const MAX_BLOCK_AGE: Duration = Duration::from_secs(300);

#[tokio::main]
async fn main() -> Result<()> {
    let config = config::load_consumer_config()?;

    info!(
        "Starting data-service consumer with config: {:?}",
        config.consumer
    );

    let conn = db::async_pool(&config.postgres)
        .await
        .context("DB connection failed")?;

    let updates_src = consumer::updates::new(&config.consumer.blockchain_updates_url)
        .await
        .context("Blockchain connection failed")?;

    let pg_repo = consumer::repo::pg::new(conn);

    let db_url = config.postgres.database_url();
    let readiness_channel = channel(
        db_url,
        POLL_INTERVAL_SECS,
        MAX_BLOCK_AGE,
        Some(LAST_TIMESTAMP_QUERY.to_string()),
    );

    let metrics = tokio::spawn(async move {
        MetricsWarpBuilder::new()
            .with_metrics_port(config.consumer.metrics_port)
            .with_readiness_channel(readiness_channel)
            .run_async()
            .await
    });

    let consumer = consumer::start(updates_src, pg_repo, config.consumer);

    select! {
        Err(err) = consumer => {
            error!("{}", err);
        },
        result = metrics => {
            if let Err(err) = result {
                error!("Metrics failed: {:?}", err);
            } else {
                error!("Metrics stopped");
            }
        }
    };
    Ok(())
}
