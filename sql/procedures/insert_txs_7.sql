CREATE OR REPLACE FUNCTION insert_txs_7 (b jsonb)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
begin
	insert into txs_7 (
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
		order1,
		order2,
		amount_asset,
		price_asset,
		amount,
		price,
		buy_matcher_fee,
		sell_matcher_fee
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
		t->'order1'->>'id',
		t->'order2'->>'id',
		get_asset_id(t->'order1'->'assetPair'->>'amountAsset'),
		get_asset_id(t->'order1'->'assetPair'->>'priceAsset'),
		(t->>'amount')::bigint,
		(t->>'price')::bigint,
		(t->>'buyMatcherFee')::bigint,
		(t->>'sellMatcherFee')::bigint		
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '7'
	on conflict do nothing;
END 
$function$