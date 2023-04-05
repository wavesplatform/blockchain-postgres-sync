CREATE OR REPLACE PROCEDURE calc_and_insert_candles_since_timestamp(since_ts TIMESTAMP WITHOUT TIME ZONE)
LANGUAGE plpgsql
AS $$
DECLARE candle_intervals TEXT[][] := '{
    {"1m", "5m"},
    {"5m", "15m"},
    {"15m", "30m"},
    {"30m", "1h"},
    {"1h", "2h"},
    {"1h", "3h"},
    {"2h", "4h"},
    {"3h", "6h"},
    {"6h", "12h"},
    {"12h", "24h"},
    {"24h", "1w"},
    {"24h", "1M"}
}';
BEGIN
    -- insert minute intervals
    INSERT INTO candles
        SELECT
            e.candle_time,
            amount_asset_id,
            price_asset_id,
            min(e.price) AS low,
            max(e.price) AS high,
            sum(e.amount) AS volume,
            sum((e.amount)::numeric * (e.price)::numeric) AS quote_volume,
            max(height) AS max_height,
            count(e.price) AS txs_count,
            floor(sum((e.amount)::numeric * (e.price)::numeric) / sum((e.amount)::numeric))::numeric
                AS weighted_average_price,
            (array_agg(e.price ORDER BY e.uid)::numeric[])[1] AS open,
            (array_agg(e.price ORDER BY e.uid DESC)::numeric[])[1] AS close,
            '1m' AS interval,
            e.sender AS matcher_address
        FROM
            (SELECT
                date_trunc('minute', time_stamp) AS candle_time,
                uid,
                amount_asset_id,
                price_asset_id,
                sender,
                height,
                amount,
                CASE WHEN tx_version > 2
                    THEN price::numeric
                        * 10^(select decimals from assets where asset_id = price_asset_id)
                        * 10^(select -decimals from assets where asset_id = amount_asset_id)
                    ELSE price::numeric
                END price
            FROM txs_7
            WHERE time_stamp >= since_ts ORDER BY uid, time_stamp <-> since_ts) AS e
        GROUP BY
            e.candle_time,
            e.amount_asset_id,
            e.price_asset_id,
            e.sender
    ON CONFLICT (time_start, amount_asset_id, price_asset_id, matcher_address, interval) DO UPDATE
        SET open = excluded.open,
            close = excluded.close,
            low = excluded.low,
            high = excluded.high,
            max_height = excluded.max_height,
            quote_volume = excluded.quote_volume,
            txs_count = excluded.txs_count,
            volume = excluded.volume,
            weighted_average_price = excluded.weighted_average_price;

    -- insert other intervals
    FOR i IN 1..array_length(candle_intervals, 1) LOOP
        INSERT INTO candles
            SELECT
                _to_raw_timestamp(time_start, candle_intervals[i][2]) AS candle_time,
                amount_asset_id,
                price_asset_id,
                min(low) AS low,
                max(high) AS high,
                sum(volume) AS volume,
                sum(quote_volume) AS quote_volume,
                max(max_height) AS max_height,
                sum(txs_count) as txs_count,
                floor(sum((weighted_average_price * volume)::numeric)::numeric / sum(volume)::numeric)::numeric
                    AS weighted_average_price,
                (array_agg(open ORDER BY time_start)::numeric[])[1] AS open,
                (array_agg(open ORDER BY time_start DESC)::numeric[])[1] AS close,
                candle_intervals[i][2] AS interval,
                matcher_address
            FROM candles
            WHERE interval = candle_intervals[i][1]
              AND time_start >= _to_raw_timestamp(since_ts, candle_intervals[i][2])
            GROUP BY candle_time, amount_asset_id, price_asset_id, matcher_address

        ON CONFLICT (time_start, amount_asset_id, price_asset_id, matcher_address, interval) DO UPDATE
            SET open = excluded.open,
                close = excluded.close,
                low = excluded.low,
                high = excluded.high,
                max_height = excluded.max_height,
                quote_volume = excluded.quote_volume,
                txs_count = excluded.txs_count,
                volume = excluded.volume,
                weighted_average_price = excluded.weighted_average_price;
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION _to_raw_timestamp(ts TIMESTAMP WITHOUT TIME ZONE, ivl TEXT)
RETURNS TIMESTAMP
LANGUAGE plpgsql
AS $$
BEGIN
    CASE
        WHEN ivl = '1m' THEN RETURN _trunc_ts_by_secs(ts, 60);
        WHEN ivl = '5m' THEN RETURN _trunc_ts_by_secs(ts, 300);
        WHEN ivl = '15m' THEN RETURN _trunc_ts_by_secs(ts, 900);
        WHEN ivl = '30m' THEN RETURN _trunc_ts_by_secs(ts, 1800);
        WHEN ivl = '1h' THEN RETURN _trunc_ts_by_secs(ts, 3600);
        WHEN ivl = '2h' THEN RETURN _trunc_ts_by_secs(ts, 7200);
        WHEN ivl = '3h' THEN RETURN _trunc_ts_by_secs(ts, 10800);
        WHEN ivl = '4h' THEN RETURN _trunc_ts_by_secs(ts, 14400);
        WHEN ivl = '6h' THEN RETURN _trunc_ts_by_secs(ts, 21600);
        WHEN ivl = '12h' THEN RETURN _trunc_ts_by_secs(ts, 43200);
        WHEN ivl = '24h' THEN RETURN date_trunc('day', ts);
        WHEN ivl = '1w' THEN RETURN date_trunc('week', ts);
        WHEN ivl = '1M' THEN RETURN date_trunc('month', ts);
    ELSE
        RETURN to_timestamp(0);
    END CASE;
END
$$;

CREATE OR REPLACE FUNCTION _trunc_ts_by_secs(ts TIMESTAMP WITHOUT TIME ZONE, secs INTEGER)
RETURNS TIMESTAMP
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN to_timestamp(floor(extract('epoch' from ts) / secs) * secs);
END;
$$;

ALTER TABLE txs_18 RENAME COLUMN payload TO bytes;