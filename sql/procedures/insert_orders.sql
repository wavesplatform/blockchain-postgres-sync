CREATE OR REPLACE FUNCTION insert_orders (b jsonb)
  RETURNS void
AS $$
begin
	insert into orders
	select
		o->>'id',
		o->>'senderPublicKey',
		o->>'matcherPublicKey',
		o->>'orderType',
		get_asset_id(o->'assetPair'->>'priceAsset'),
		get_asset_id(o->'assetPair'->>'amountAsset'),
		(o->>'price')::bigint,
		(o->>'amount')::bigint,
		to_timestamp( trunc( cast( o->>'timestamp' as bigint  ) / 1000 ) ),
		to_timestamp( trunc( cast( o->>'expiration' as bigint  ) / 1000 ) ),
		(o->>'matcherFee')::bigint,
		o->>'signature'
	from (
		with t7 as (
			select * from (
				select jsonb_array_elements(b->'transactions') tx
			) as txs
			where tx->>'type' = '7'
		)
		select tx->'order1' o from t7
		union all
		select tx->'order2' o from t7
	) as os
	on conflict do nothing;
END 
$$
LANGUAGE plpgsql;
			