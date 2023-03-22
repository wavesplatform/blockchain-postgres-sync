DROP INDEX IF EXISTS asset_tickers_ticker_idx;
CREATE UNIQUE INDEX IF NOT EXISTS asset_tickers_ticker_idx    ON asset_tickers (ticker);

DROP INDEX IF EXISTS asset_tickers_block_uid_idx;

CREATE OR REPLACE VIEW tickers(
    asset_id,
    ticker
) as SELECT asset_id, ticker FROM asset_tickers;