ALTER TABLE txs ADD COLUMN status varchar DEFAULT 'succeeded';

create or replace function insert_txs_1(b jsonb) returns void
    language plpgsql
as
$$
begin
  insert into txs_1 (height,
                     tx_type,
                     id,
                     time_stamp,
                     signature,
                     proofs,
                     tx_version,
                     fee,
                     status,
                     recipient,
                     amount)
  select
    -- common
    (t ->> 'height')::int4,
    (t ->> 'type')::smallint,
    t ->> 'id',
    to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
    t ->> 'signature',
    jsonb_array_cast_text(t -> 'proofs'),
    (t ->> 'version')::smallint,
    (t ->> 'fee')::bigint,
    t->>'applicationStatus',
    -- type specific
    t ->> 'recipient',
    (t ->> 'amount')::bigint
  from (
         select jsonb_array_elements(b -> 'transactions') || jsonb_build_object('height', b -> 'height') as t
       ) as txs
  where (t ->> 'type') = '1'
  on conflict do nothing;
END
$$;

alter function insert_txs_1(jsonb) owner to dba;


create or replace function insert_txs_10(b jsonb) returns void
    language plpgsql
as
$$
begin
	insert into txs_10 (
		height,
		tx_type,
		id,
		time_stamp,
		signature,
		proofs,
		tx_version,
		fee,
        status,
		sender,
		sender_public_key,
		alias
	)
	select
		-- common
		(t->>'height')::int4,
		(t->>'type')::smallint,
		t->>'id',
		to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		t->>'signature',
		jsonb_array_cast_text(t->'proofs'),
		(t->>'version')::smallint,
		(t->>'fee')::bigint,
        t->>'applicationStatus',
		-- with sender
		t->>'sender',
		t->>'senderPublicKey',
		-- type specific
		t->>'alias'
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '10'
	on conflict do nothing;
END
$$;

alter function insert_txs_10(jsonb) owner to dba;


create or replace function insert_txs_11(b jsonb) returns void
    language plpgsql
as
$$
BEGIN
  INSERT INTO txs_11 (height,
                      tx_type,
                      id,
                      time_stamp,
                      signature,
                      proofs,
                      tx_version,
                      fee,
                      status,
                      sender,
                      sender_public_key,
                      asset_id,
                      attachment)
  SELECT
    -- common
    (t ->> 'height') :: INT4,
    (t ->> 'type') :: SMALLINT,
    t ->> 'id',
    to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
    t ->> 'signature',
    jsonb_array_cast_text(t -> 'proofs'),
    (t ->> 'version') :: SMALLINT,
    (t ->> 'fee') :: BIGINT,
    t->>'applicationStatus',
    -- with sender
    t ->> 'sender',
    t ->> 'senderPublicKey',
    -- type specific
    get_asset_id(t ->> 'assetId'),
    t ->> 'attachment'
  FROM (
         SELECT jsonb_array_elements(b -> 'transactions') || jsonb_build_object('height', b -> 'height') AS t
       ) AS txs
  WHERE (t ->> 'type') = '11'
  ON CONFLICT DO NOTHING;
  -- transfers
  INSERT INTO txs_11_transfers (tx_id,
                                recipient,
                                amount,
                                position_in_tx)
  SELECT t ->> 'tx_id',
         t ->> 'recipient',
         (t ->> 'amount') :: BIGINT,
         row_number()
             OVER (
               PARTITION BY t ->> 'tx_id' ) - 1
  FROM (
         SELECT jsonb_array_elements(tx -> 'transfers') || jsonb_build_object('tx_id', tx ->> 'id') AS t
         FROM (
                SELECT jsonb_array_elements(b -> 'transactions') AS tx
              ) AS txs
       ) AS transfers
  ON CONFLICT DO NOTHING;
END
$$;

alter function insert_txs_11(jsonb) owner to dba;


create or replace function insert_txs_12(b jsonb) returns void
    language plpgsql
as
$$
begin
	insert into txs_12 (
		height,
		tx_type,
		id,
		time_stamp,
		signature,
		proofs,
		tx_version,
		fee,
        status,
		sender,
		sender_public_key
	)
	select
		-- common
		(t->>'height')::int4,
		(t->>'type')::smallint,
		t->>'id',
        to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		t->>'signature',
		jsonb_array_cast_text(t->'proofs'),
		(t->>'version')::smallint,
		(t->>'fee')::bigint,
        t->>'applicationStatus',
		-- with sender
		t->>'sender',
		t->>'senderPublicKey'
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '12'
	on conflict do nothing;

	insert into txs_12_data (
		tx_id,
		data_key,
		data_type,
		data_value_integer,
		data_value_boolean,
		data_value_binary,
		data_value_string,
		position_in_tx
	)
	select
		d->>'tx_id' as tx_id,
		d->>'key' as data_key,
		d->>'type' as data_type,
		case when d->>'type' = 'integer'
			then (d->>'value')::bigint
			else null
		end as data_value_integer,
		case when d->>'type' = 'boolean'
			then (d->>'value')::boolean
			else null
		end as data_value_boolean,
		case when d->>'type' = 'binary'
			then d->>'value'
			else null
		end as data_value_binary,
		case when d->>'type' = 'string'
			then d->>'value'
			else null
		end as data_value_string,
		row_number() over (PARTITION BY d->>'tx_id') - 1 as position_in_tx
	from (
		select jsonb_array_elements(tx->'data') || jsonb_build_object('tx_id', tx->>'id') as d
			from (
				select jsonb_array_elements(b->'transactions') as tx
			) as txs
	) as data
	on conflict do nothing;
END
$$;

alter function insert_txs_12(jsonb) owner to dba;


create or replace function insert_txs_13(b jsonb) returns void
    language plpgsql
as
$$
begin
	insert into txs_13 (
		height,
		tx_type,
		id,
		time_stamp,
		signature,
		proofs,
		tx_version,
		fee,
        status,
		sender,
		sender_public_key,
        script
	)
	select
		-- common
		(t->>'height')::int4,
		(t->>'type')::smallint,
		t->>'id',
        to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		t->>'signature',
		jsonb_array_cast_text(t->'proofs'),
		(t->>'version')::smallint,
		(t->>'fee')::bigint,
        t->>'applicationStatus',
		-- with sender
		t->>'sender',
		t->>'senderPublicKey',
		-- type specific
        t->>'script'
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '13'
	on conflict do nothing;
END
$$;

alter function insert_txs_13(jsonb) owner to dba;


create or replace function insert_txs_14(b jsonb) returns void
    language plpgsql
as
$$
begin
	insert into txs_14 (
		height,
		tx_type,
		id,
		time_stamp,
		signature,
		proofs,
		tx_version,
		fee,
        status,
		sender,
		sender_public_key,
        asset_id,
        min_sponsored_asset_fee
	)
	select
		-- common
		(t->>'height')::int4,
		(t->>'type')::smallint,
		t->>'id',
		to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		t->>'signature',
		jsonb_array_cast_text(t->'proofs'),
		(t->>'version')::smallint,
		(t->>'fee')::bigint,
        t->>'applicationStatus',
		-- with sender
		t->>'sender',
		t->>'senderPublicKey',
		-- type specific
        get_asset_id(t->>'assetId'),
        (t->>'minSponsoredAssetFee')::bigint
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '14'
	on conflict do nothing;
END
$$;

alter function insert_txs_14(jsonb) owner to dba;


create or replace function insert_txs_15(b jsonb) returns void
    language plpgsql
as
$$
begin
	insert into txs_15 (
		height,
		tx_type,
		id,
		time_stamp,
		signature,
		proofs,
		tx_version,
		fee,
        status,
		sender,
		sender_public_key,
		asset_id,
	    script
	)
	select
		-- common
		(t->>'height')::int4,
		(t->>'type')::smallint,
		t->>'id',
        to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		t->>'signature',
		jsonb_array_cast_text(t->'proofs'),
		(t->>'version')::smallint,
		(t->>'fee')::bigint,
        t->>'applicationStatus',
		-- with sender
		t->>'sender',
		t->>'senderPublicKey',
		-- type specific
		t->>'assetId',
	    t->>'script'
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '15'
	on conflict do nothing;
END
$$;

alter function insert_txs_15(jsonb) owner to dba;


create or replace function insert_txs_16(b jsonb) returns void
    language plpgsql
as
$$
begin
	insert into txs_16 (
		height,
		tx_type,
		id,
		time_stamp,
		signature,
		proofs,
		tx_version,
		fee,
        status,
		sender,
		sender_public_key,
		dapp,
	    function_name
	)
	select
		-- common
		(t->>'height')::int4,
		(t->>'type')::smallint,
		t->>'id',
        to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		t->>'signature',
		jsonb_array_cast_text(t->'proofs'),
		(t->>'version')::smallint,
		(t->>'fee')::bigint,
        t->>'applicationStatus',
		-- with sender
		t->>'sender',
		t->>'senderPublicKey',
		-- type specific
		t->>'dApp',
	    t->'call'->>'function'
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '16'
	on conflict do nothing;

	insert into txs_16_args (
		tx_id,
		arg_type,
		arg_value_integer,
		arg_value_boolean,
		arg_value_binary,
		arg_value_string,
	    arg_value_list,
		position_in_args
	)
	select
		arg->>'tx_id' as tx_id,
		arg->>'type' as arg_type,
		case when arg->>'type' = 'integer'
			then (arg->>'value')::bigint
			else null
		end as arg_value_integer,
		case when arg->>'type' = 'boolean'
			then (arg->>'value')::boolean
			else null
		end as arg_value_boolean,
		case when arg->>'type' = 'binary'
			then arg->>'value'
			else null
		end as arg_value_binary,
		case when arg->>'type' = 'string'
			then arg->>'value'
			else null
		end as arg_value_string,
		case when arg->>'type' = 'list'
			then arg->'value'
			else null
		end as arg_value_list,
		row_number() over (PARTITION BY arg->>'tx_id') - 1 as position_in_args
	from (
		select jsonb_array_elements(tx->'call'->'args') || jsonb_build_object('tx_id', tx->>'id') as arg
			from (
				select jsonb_array_elements(b->'transactions') as tx
			) as txs
			where (tx->>'type') = '16'
	) as data
	on conflict do nothing;

	insert into txs_16_payment (
		tx_id,
		amount,
		asset_id,
		position_in_payment
	)
	select
		p->>'tx_id' as tx_id,
		(p->>'amount')::bigint as amount,
		p->>'assetId' as asset_id,
		row_number() over (PARTITION BY p->>'tx_id') - 1 as position_in_payment
	from (
		select jsonb_array_elements(tx->'payment') || jsonb_build_object('tx_id', tx->>'id') as p
			from (
				select jsonb_array_elements(b->'transactions') as tx
			) as txs
			where (tx->>'type') = '16'
	) as data
	on conflict do nothing;
END
$$;

alter function insert_txs_16(jsonb) owner to dba;


create or replace function insert_txs_17(b jsonb) returns void
    language plpgsql
as
$$
begin
	insert into txs_17 (
		height,
		tx_type,
		id,
		time_stamp,
		signature,
		proofs,
		tx_version,
		fee,
        status,
		sender,
		sender_public_key,
		asset_id,
		asset_name,
		description
	)
	select
		-- common
		(t->>'height')::int4,
		(t->>'type')::smallint,
		t->>'id',
		to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		t->>'signature',
		jsonb_array_cast_text(t->'proofs'),
		(t->>'version')::smallint,
		(t->>'fee')::bigint,
        t->>'applicationStatus',
		-- with sender
		t->>'sender',
		t->>'senderPublicKey',
		-- type specific
		get_asset_id(t->>'assetId'),
		t->>'name',
		t->>'description'
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '17'
	on conflict do nothing;

    -- delete old asset name
    delete from assets_names_map where array[asset_id, asset_name] in (
        select 
            array[get_asset_id(t->>'assetId')::varchar, t->>'name'::varchar]
        from (
            select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
        ) as txs
        where (t->>'type') = '17'
    );

	-- add new asset name
	insert into assets_names_map (
		asset_id,
		asset_name,
		searchable_asset_name
	)
	select
		get_asset_id(t->>'assetId'),
		t->>'name',
		to_tsvector(t->>'name')
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '17'
	on conflict do nothing;
END
$$;

alter function insert_txs_17(jsonb) owner to dba;


create or replace function insert_txs_2(b jsonb) returns void
    language plpgsql
as
$$
begin
	insert into txs_2 (
		height,
		tx_type,
		id,
		time_stamp,
		signature,
		proofs,
		tx_version,
		fee,
        status,
		sender,
		sender_public_key,
		recipient,
		amount
	)
	select
		-- common
		(t->>'height')::int4,
		(t->>'type')::smallint,
		t->>'id',
		to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		t->>'signature',
		jsonb_array_cast_text(t->'proofs'),
		(t->>'version')::smallint,
		(t->>'fee')::bigint,
        t->>'applicationStatus',
		-- with sender
		t->>'sender',
		t->>'senderPublicKey',
		-- type specific
		t->>'recipient',
		(t->>'amount')::bigint
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '2'
	on conflict do nothing;
END
$$;

alter function insert_txs_2(jsonb) owner to dba;


create or replace function insert_txs_3(b jsonb) returns void
    language plpgsql
as
$$
begin
	insert into txs_3 (
		height,
		tx_type,
		id,
		time_stamp,
		signature,
		proofs,
		tx_version,
		fee,
        status,
		sender,
		sender_public_key,
		asset_id,
		asset_name,
		description,
		quantity,
		decimals,
		reissuable,
		script
	)
	select
		-- common
		(t->>'height')::int4,
		(t->>'type')::smallint,
		t->>'id',
		to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		t->>'signature',
		jsonb_array_cast_text(t->'proofs'),
		(t->>'version')::smallint,
		(t->>'fee')::bigint,
        t->>'applicationStatus',
		-- with sender
		t->>'sender',
		t->>'senderPublicKey',
		-- type specific
		get_asset_id(t->>'assetId'),
		t->>'name',
		t->>'description',
		(t->>'quantity')::bigint,
		(t->>'decimals')::smallint,
		(t->>'reissuable')::bool,
		t->>'script'
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '3'
	on conflict do nothing;
	-- insert into assets names map
	insert into assets_names_map (
		asset_id,
		asset_name,
		searchable_asset_name
	)
	select
		get_asset_id(t->>'assetId'),
		t->>'name',
		to_tsvector(t->>'name')
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '3'
	on conflict do nothing;
END
$$;

alter function insert_txs_3(jsonb) owner to dba;


create or replace function insert_txs_4(b jsonb) returns void
    language plpgsql
as
$$
begin
	insert into txs_4 (
        height, 
        tx_type, 
        id, 
        time_stamp, 
        fee, 
        status,
        amount, 
        asset_id, 
        fee_asset, 
        sender, 
        sender_public_key, 
        recipient, 
        attachment, 
        signature, 
        proofs, 
        tx_version
    )
	select
        -- common
		(t->>'height')::int4,
		(t->>'type')::smallint,
		t->>'id',
		to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		(t->>'fee')::bigint,
        t->>'applicationStatus',
		(t->>'amount')::bigint,
		coalesce(t->>'assetId', 'WAVES'),
		coalesce(t->>'feeAsset', 'WAVES'),
        -- with sender
		t->>'sender',
		t->>'senderPublicKey',
        -- type specific
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
$$;

alter function insert_txs_4(jsonb) owner to dba;


create or replace function insert_txs_5(b jsonb) returns void
    language plpgsql
as
$$
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
        status,
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
		to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		t->>'signature',
		jsonb_array_cast_text(t->'proofs'),
		(t->>'version')::smallint,
		(t->>'fee')::bigint,
        t->>'applicationStatus',
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
$$;

alter function insert_txs_5(jsonb) owner to dba;


create or replace function insert_txs_6(b jsonb) returns void
    language plpgsql
as
$$
begin
	insert into txs_6 (
		height,
		tx_type,
		id,
		time_stamp,
		signature,
		proofs,
		tx_version,
		fee,
        status,
		sender,
		sender_public_key,
		asset_id,
		amount
	)
	select
		-- common
		(t->>'height')::int4,
		(t->>'type')::smallint,
		t->>'id',
		to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		t->>'signature',
		jsonb_array_cast_text(t->'proofs'),
		(t->>'version')::smallint,
		(t->>'fee')::bigint,
        t->>'applicationStatus',
		-- with sender
		t->>'sender',
		t->>'senderPublicKey',
		-- type specific
		get_asset_id(t->>'assetId'),
		(t->>'amount')::bigint
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '6'
	on conflict do nothing;
END
$$;

alter function insert_txs_6(jsonb) owner to dba;


create or replace function insert_txs_7(b jsonb) returns void
    language plpgsql
as
$$
begin
  insert into txs_7 (height,
                     tx_type,
                     id,
                     time_stamp,
                     signature,
                     proofs,
                     tx_version,
                     fee,
                     status,
                     sender,
                     sender_public_key,
                     order1,
                     order2,
                     amount_asset,
                     price_asset,
                     amount,
                     price,
                     buy_matcher_fee,
                     sell_matcher_fee)
  select
    -- common
    (t ->> 'height')::int4,
    (t ->> 'type')::smallint,
    t ->> 'id',
    to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
    t ->> 'signature',
    jsonb_array_cast_text(t -> 'proofs'),
    (t ->> 'version')::smallint,
    (t ->> 'fee')::bigint,
    t->>'applicationStatus',
    -- with sender
    t ->> 'sender',
    t ->> 'senderPublicKey',
    -- type specific
    t -> 'order1',
    t -> 'order2',
    get_asset_id(t -> 'order1' -> 'assetPair' ->> 'amountAsset'),
    get_asset_id(t -> 'order1' -> 'assetPair' ->> 'priceAsset'),
    (t ->> 'amount')::bigint,
    (t ->> 'price')::bigint,
    (t ->> 'buyMatcherFee')::bigint,
    (t ->> 'sellMatcherFee')::bigint
  from (
         select jsonb_array_elements(b -> 'transactions') || jsonb_build_object('height', b -> 'height') as t
       ) as txs
  where (t ->> 'type') = '7'
  on conflict do nothing;
END
$$;

alter function insert_txs_7(jsonb) owner to dba;


create or replace function insert_txs_8(b jsonb) returns void
    language plpgsql
as
$$
begin
	insert into txs_8 (
		height,
		tx_type,
		id,
		time_stamp,
		signature,
		proofs,
		tx_version,
		fee,
        status,
		sender,
		sender_public_key,
		recipient,
		amount
	)
	select
		-- common
		(t->>'height')::int4,
		(t->>'type')::smallint,
		t->>'id',
		to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		t->>'signature',
		jsonb_array_cast_text(t->'proofs'),
		(t->>'version')::smallint,
		(t->>'fee')::bigint,
        t->>'applicationStatus',
		-- with sender
		t->>'sender',
		t->>'senderPublicKey',
		-- type specific
		t->>'recipient',
		(t->>'amount')::bigint
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '8'
	on conflict do nothing;
END
$$;

alter function insert_txs_8(jsonb) owner to dba;


create or replace function insert_txs_9(b jsonb) returns void
    language plpgsql
as
$$
begin
	insert into txs_9 (
		height,
		tx_type,
		id,
		time_stamp,
		signature,
		proofs,
		tx_version,
		fee,
        status,
		sender,
		sender_public_key,
		lease_id
	)
	select
		-- common
		(t->>'height')::int4,
		(t->>'type')::smallint,
		t->>'id',
		to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		t->>'signature',
		jsonb_array_cast_text(t->'proofs'),
		(t->>'version')::smallint,
		(t->>'fee')::bigint,
        t->>'applicationStatus',
		-- with sender
		t->>'sender',
		t->>'senderPublicKey',
		-- type specific
		t->>'leaseId'
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '9'
	on conflict do nothing;
END
$$;

alter function insert_txs_9(jsonb) owner to dba;
