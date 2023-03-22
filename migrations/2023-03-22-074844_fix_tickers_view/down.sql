CREATE OR REPLACE VIEW tickers(
    asset_id,
    ticker
) AS SELECT DISTINCT ON (ticker) asset_id, ticker FROM asset_tickers ORDER BY ticker, uid DESC;