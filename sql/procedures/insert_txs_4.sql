CREATE OR REPLACE FUNCTION insert_txs_4 (b jsonb)
  RETURNS void
AS $$
begin
	insert into txs_4
	(height, tx_type, id, time_stamp, fee, amount, asset_id, fee_asset, sender, sender_public_key, recipient, attachment, signature, proofs, tx_version)
	select
		(t->>'height')::int4,
		(t->>'type')::smallint,
		t->>'id',
		to_timestamp( trunc( cast( t->>'timestamp' as bigint  ) / 1000 ) ),
		(t->>'fee')::bigint,
		(t->>'amount')::bigint,
		coalesce(t->>'assetId', 'WAVES'),
		coalesce(t->>'feeAsset', 'WAVES'),
		t->>'sender',
		t->>'senderPublicKey',
		t->>'recipient',
		t->>'attachment',
		t->>'signature',
		jsonb_array_cast_text(t->'proofs'),
		(t->>'version')::smallint
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '4'
	on conflict do nothing;
END 
$$
LANGUAGE plpgsql;