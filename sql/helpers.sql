CREATE OR REPLACE FUNCTION jsonb_array_cast_int(jsonb) RETURNS int[] AS $f$
    SELECT array_agg(x)::int[] || ARRAY[]::int[] FROM jsonb_array_elements_text($1) t(x);
$f$ LANGUAGE sql IMMUTABLE;


CREATE OR REPLACE FUNCTION jsonb_array_cast_text(jsonb) RETURNS text[] AS $f$
    SELECT array_agg(x) || ARRAY[]::text[] FROM jsonb_array_elements_text($1) t(x);
$f$ LANGUAGE sql IMMUTABLE;


CREATE OR REPLACE FUNCTION get_asset_id(text) RETURNS text AS $f$
    SELECT COALESCE($1, 'WAVES');
$f$ LANGUAGE sql IMMUTABLE;