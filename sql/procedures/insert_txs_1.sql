CREATE OR REPLACE FUNCTION insert_txs_1 (b jsonb)
  RETURNS void
AS $$
begin
	insert into txs_1 (
		height,
		tx_type,
		id,
		time_stamp,
		signature,
		proofs,
		tx_version,
		fee,
		recipient,
		amount
	)
	select
		-- common
		(t->>'height')::int4,
		(t->>'type')::smallint,
		t->>'id',
		to_timestamp( trunc( cast( t->>'timestamp' as bigint  ) / 1000 ) ),
		t->>'signature',
		jsonb_array_cast_text(t->'proofs'),
		(t->>'version')::smallint,
		(t->>'fee')::bigint,
		-- type specific
		t->>'recipient',
		(t->>'amount')::bigint
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '1'
	on conflict do nothing;
END 
$$
LANGUAGE plpgsql;