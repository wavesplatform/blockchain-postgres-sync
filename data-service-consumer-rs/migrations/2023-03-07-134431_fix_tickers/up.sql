DROP INDEX IF EXISTS asset_tickers_ticker_idx; -- remove uniqness from index
CREATE INDEX IF NOT EXISTS asset_tickers_ticker_idx ON asset_tickers (ticker);

CREATE INDEX IF NOT EXISTS asset_tickers_block_uid_idx ON asset_updates (block_uid);

CREATE OR REPLACE VIEW tickers(
    asset_id,
    ticker
) AS SELECT DISTINCT ON (ticker) asset_id, ticker FROM asset_tickers ORDER BY ticker, uid DESC;