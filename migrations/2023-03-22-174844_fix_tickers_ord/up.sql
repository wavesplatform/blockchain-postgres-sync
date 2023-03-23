
CREATE OR REPLACE VIEW tickers(
    asset_id,
    ticker
) AS SELECT DISTINCT ON (ticker) * FROM
    (SELECT DISTINCT ON (asset_id) asset_id, ticker, uid FROM asset_tickers ORDER BY asset_id, uid DESC) as uord
    ORDER BY ticker, uid DESC;