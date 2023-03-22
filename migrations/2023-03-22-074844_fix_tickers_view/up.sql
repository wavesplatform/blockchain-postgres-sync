
CREATE OR REPLACE VIEW tickers(
    asset_id,
    ticker
) AS SELECT DISTINCT ON (asset_id) asset_id, ticker FROM
    (SELECT DISTINCT ON (ticker) asset_id, ticker, uid FROM asset_tickers ORDER BY ticker, uid DESC) as dbt
ORDER BY asset_id, ticker, uid DESC;