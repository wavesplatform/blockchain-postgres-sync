TRUNCATE candles;
ALTER TABLE candles DROP CONSTRAINT candles_pkey;
ALTER TABLE candles DROP COLUMN interval;
ALTER TABLE candles DROP COLUMN matcher;
ALTER TABLE candles ADD COLUMN interval varchar NOT NULL;
ALTER TABLE candles ADD COLUMN matcher varchar NOT NULL;
ALTER TABLE candles ADD CONSTRAINT candles_pkey PRIMARY KEY ("interval", time_start, amount_asset_id, price_asset_id, matcher);
