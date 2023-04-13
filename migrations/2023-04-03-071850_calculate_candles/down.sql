DROP FUNCTION IF EXISTS calc_and_insert_candles_since_timestamp;
DROP FUNCTION IF EXISTS _to_raw_timestamp;
DROP FUNCTION IF EXISTS _trunc_ts_by_secs;

ALTER TABLE txs_18 RENAME COLUMN bytes TO payload;