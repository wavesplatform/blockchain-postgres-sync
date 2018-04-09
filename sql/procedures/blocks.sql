CREATE OR REPLACE FUNCTION insert_block (b jsonb)
  RETURNS void
AS $$
begin
	insert into blocks
	values (
		(b->>'version')::smallint,
		to_timestamp( trunc( cast( b->>'timestamp' as bigint  ) / 1000 ) ),
		b->>'reference',
		(b->'nxt-consensus'->>'base-target')::bigint,
		b->'nxt-consensus'->>'generation-signature',
		b->>'generator',
		b->>'signature',
		(b->>'fee')::bigint,
		(b->>'blocksize')::integer,
		(b->>'height')::integer,
		jsonb_array_cast_int(b->'features')::smallint[ ]
	);
END 
$$
LANGUAGE plpgsql;