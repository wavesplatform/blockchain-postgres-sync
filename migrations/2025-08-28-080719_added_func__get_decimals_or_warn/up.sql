CREATE OR REPLACE FUNCTION get_decimals_or_exception(id text)
    RETURNS integer AS $$
DECLARE
    dec integer;
BEGIN
    SELECT decimals INTO dec
    FROM decimals
    WHERE asset_id = id;

    IF dec IS NULL THEN
        RAISE EXCEPTION 'Missing decimals for asset_id=%. Cannot calculate candle price.', id;
    END IF;

    RETURN dec;
END;
$$ LANGUAGE plpgsql;