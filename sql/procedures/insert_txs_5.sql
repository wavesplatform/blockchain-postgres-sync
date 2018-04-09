CREATE OR REPLACE FUNCTION insert_txs_5 (b jsonb)
  RETURNS void
AS $$
begin
	insert into txs_5 (
		height,
		tx_type,
		id,
		time_stamp,
		signature,
		proofs,
		tx_version,
		fee,
		sender,
		sender_public_key,
		asset_id,
		quantity,
		reissuable
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
		-- with sender
		t->>'sender',
		t->>'senderPublicKey',
		-- type specific
		get_asset_id(t->>'assetId'),
		(t->>'quantity')::bigint,
		(t->>'reissuable')::bool		
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '5'
	on conflict do nothing;
END 
$$
LANGUAGE plpgsql;