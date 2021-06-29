SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE OR REPLACE FUNCTION public.count_affected_rows() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    x integer := -1;
BEGIN
    GET DIAGNOSTICS x = ROW_COUNT;
    RETURN x;
END;
$$;


CREATE OR REPLACE FUNCTION public.get_address(_address_or_alias varchar) RETURNS varchar
    LANGUAGE plpgsql
    AS $$
	declare 
		alias_regex varchar := '^alias:\w{1}:(.*)';
		address varchar;
		_alias_query varchar;
	begin
		-- addr is null at genesis txs
		if _address_or_alias is null then 
			return null;
		end if;

        if _address_or_alias like 'alias:_:%' then
            _alias_query := substring(_address_or_alias from alias_regex);
            select sender from txs_10 where alias = _alias_query into address;
            return address;
        end if;

        return _address_or_alias;
	END;
$$;


CREATE OR REPLACE FUNCTION public.get_alias(_raw_alias varchar) RETURNS varchar
    LANGUAGE plpgsql
    AS $$
	declare
		alias_regex varchar := '^alias:\w{1}:(.*)';
		_alias_query varchar;
		_alias varchar;
	begin
		_alias_query := substring(_raw_alias from alias_regex);
		select alias from txs_10 where alias = _alias_query into _alias;
		return _alias;
	END;
$$;


CREATE OR REPLACE FUNCTION public.get_tuid_by_tx_id(_tx_id varchar) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	declare
		tuid bigint;
	begin
		select uid from txs where id = _tx_id into tuid;
		return tuid;
	end;
$$;


CREATE OR REPLACE FUNCTION public.get_tuid_by_tx_height_and_position_in_block(_height int4, _position_in_block int4) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	begin
		return _height::bigint * 100000::bigint + _position_in_block::bigint;
	end;
$$;


CREATE OR REPLACE FUNCTION public.insert_all(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	raise notice 'insert block % at %', b->>'height', clock_timestamp();
	PERFORM insert_block (b);
    -- alias can be used in txs at the same height
	-- so it have to be already inserted
	PERFORM insert_txs_10 (b);
	PERFORM insert_txs_1 (b);
	PERFORM insert_txs_2 (b);
	PERFORM insert_txs_3 (b);
	PERFORM insert_txs_4 (b);
	PERFORM insert_txs_5 (b);
	PERFORM insert_txs_6 (b);
	PERFORM insert_txs_7 (b);
	PERFORM insert_txs_8 (b);
	PERFORM insert_txs_9 (b);
	PERFORM insert_txs_11 (b);
	PERFORM insert_txs_12 (b);
 	PERFORM insert_txs_13 (b);
	PERFORM insert_txs_14 (b);
	PERFORM insert_txs_15 (b);
	PERFORM insert_txs_16 (b);
	PERFORM insert_txs_17 (b);
END
$$;


CREATE OR REPLACE FUNCTION public.insert_block(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into blocks
	values (
		(b->>'version')::smallint,
		to_timestamp((b ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		b->>'reference',
        (b->'nxt-consensus'->>'base-target')::bigint,
        b->'nxt-consensus'->>'generation-signature',
		b->>'generator',
		b->>'signature',
		(b->>'fee')::bigint,
		(b->>'blocksize')::integer,
		(b->>'height')::integer,
		jsonb_array_cast_int(b->'features')::smallint[ ]
	)
	on conflict do nothing;

    if b->>'reward' is not null then
    	-- height has to be more then current height (microblock rollback protection) or null (for clean db)
		-- condition height is null - height=null is for correct work of foreign key (rollbacks)
		insert into waves_data (height, quantity) 
		values ((b->>'height')::integer, (select quantity from waves_data where height < (b->>'height')::integer or height is null order by height desc nulls last limit 1) + (b->>'reward')::bigint) 
		on conflict do nothing;
	end if;
END
$$;


CREATE OR REPLACE FUNCTION public.insert_txs_1(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    insert into txs_1 (
        uid,
        id, 
        time_stamp, 
        height, 
        tx_type, 
        signature,
        proofs, 
        tx_version,
        fee,
        status,
        sender,
        sender_public_key,
        recipient_address,
        recipient_alias,
        amount
    )
    select
        -- common
        (t->>'uid')::bigint,
        t->>'id',
        to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
        (b->>'height')::int4,
        (t ->> 'type')::smallint,
        t ->> 'signature',
        jsonb_array_cast_text(t -> 'proofs'),
        (t->>'version')::smallint,
        (t->>'fee')::bigint,
        coalesce(t->>'applicationStatus', 'succeeded'),
        -- with sender
        t->>'sender',
        t->>'senderPublicKey',
        -- type specific
        get_address(t->>'recipient'),
        get_alias(t->>'recipient'),
        (t->>'amount')::bigint
    from (
        select t || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as t
        from (
            select jsonb_array_elements(b -> 'transactions') as t
        ) as txs
    ) as txs
    where (t ->> 'type') = '1'
    on conflict do nothing;
END
$$;


CREATE OR REPLACE FUNCTION public.insert_txs_10(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_10 (
		uid,
        id, 
        time_stamp, 
        height, 
        tx_type, 
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
		(t->>'uid')::bigint,
        t->>'id',
        to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
		(b->>'height')::int4,
        (t ->> 'type')::smallint,
        t ->> 'signature',
        jsonb_array_cast_text(t -> 'proofs'),
        (t->>'version')::smallint,
        (t->>'fee')::bigint,
        coalesce(t->>'applicationStatus', 'succeeded'),
		-- with sender	
        t->>'sender',
        t->>'senderPublicKey',
		-- type specific
		t->>'alias'
	from (
        select t || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as t
        from (
            select jsonb_array_elements(b->'transactions') as t
        ) as txs
    ) as txs
	where (t->>'type') = '10'
	on conflict do nothing;
END
$$;


CREATE OR REPLACE FUNCTION public.insert_txs_11(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    insert into txs_11 (
        uid,
        id, 
        time_stamp, 
        height, 
        tx_type, 
        signature,
        proofs, 
        tx_version,
        fee,
        status,
        sender,
        sender_public_key,
        asset_id,
        attachment
    )
    select
        -- common
        (t->>'uid')::bigint,
        t->>'id',
        to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
        (b->>'height')::int4,
        (t ->> 'type')::smallint,
        t ->> 'signature',
        jsonb_array_cast_text(t -> 'proofs'),
        (t->>'version')::smallint,
        (t->>'fee')::bigint,
        coalesce(t->>'applicationStatus', 'succeeded'),
        -- with sender
        t->>'sender',
        t->>'senderPublicKey',
        -- type specific
        get_asset_id(t->>'assetId'),
        t->>'attachment'
    from (
        select t || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as t
        from (
        select jsonb_array_elements(b -> 'transactions') as t
        ) as txs
    ) as t 
    where (t ->> 'type') = '11'
    on conflict do nothing;
 
  -- transfers
  insert into txs_11_transfers (tx_uid,
                                recipient_address,
                                recipient_alias,
                                amount,
                                position_in_tx,
                                height)
  select 
	(t->>'tx_uid')::bigint,
    get_address(t->>'recipient'),
    get_alias(t->>'recipient'),
    (t->>'amount')::bigint,
    row_number() over (partition by t->>'tx_id') - 1,
    (b->>'height')::int4
  from (
      select jsonb_array_elements(tx->'transfers') || jsonb_build_object('tx_uid', tx->'uid') as t
      from (
          select tx || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as tx
          from (
            select jsonb_array_elements(b->'transactions') as tx
          ) as txs
      ) as txs
  ) as transfers
  on conflict do nothing;
END
$$;


CREATE OR REPLACE FUNCTION public.insert_txs_12(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_12 (
		uid,
        id, 
        time_stamp, 
        height, 
        tx_type, 
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
		(t->>'uid')::bigint,
        t->>'id',
        to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
		(b->>'height')::int4,
        (t ->> 'type')::smallint,
        t ->> 'signature',
        jsonb_array_cast_text(t -> 'proofs'),
        (t->>'version')::smallint,
        (t->>'fee')::bigint,
        coalesce(t->>'applicationStatus', 'succeeded'),
		-- with sender	
        t->>'sender',
        t->>'senderPublicKey'
	from (
        select t || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as t
        from (
          select jsonb_array_elements(b->'transactions') as t
	    ) as txs
    ) as txs
	where (t->>'type') = '12'
	on conflict do nothing;

	insert into txs_12_data (
		tx_uid,
		data_key,
		data_type,
		data_value_integer,
		data_value_boolean,
		data_value_binary,
		data_value_string,
		position_in_tx,
		height
	)
	select
		(d->>'tx_uid')::bigint as tuid,
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
		row_number() over (PARTITION BY d->>'tx_id') - 1 as position_in_tx,
		(b->>'height')::int4
	from (
		select jsonb_array_elements(tx->'data') || jsonb_build_object('tx_uid', tx->'uid') as d
        from (
            select tx || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as tx
			from (
				select jsonb_array_elements(b->'transactions') as tx
			) as txs
        ) as txs
	) as data
	on conflict do nothing;
END
$$;


CREATE OR REPLACE FUNCTION public.insert_txs_13(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_13 (
		uid,
        id, 
        time_stamp, 
        height, 
        tx_type, 
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
		(t->>'uid')::bigint,
        t ->> 'id',
        to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
		(b->>'height')::int4,
        (t ->> 'type')::smallint,
        t ->> 'signature',
        jsonb_array_cast_text(t -> 'proofs'),
        (t->>'version')::smallint,
        (t->>'fee')::bigint,
        coalesce(t->>'applicationStatus', 'succeeded'),
		-- with sender	
        t->>'sender',
        t->>'senderPublicKey',
		-- type specific
    	t->>'script'
	from (
        select t || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as t
        from (
		  select jsonb_array_elements(b->'transactions') as t
	    ) as txs
    ) as txs
	where (t->>'type') = '13'
	on conflict do nothing;
END
$$;


CREATE OR REPLACE FUNCTION public.insert_txs_14(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_14 (
		uid,
        id, 
        time_stamp, 
        height, 
        tx_type, 
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
		(t->>'uid')::bigint,
        t->>'id',
        to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
		(b->>'height')::int4,
        (t->>'type')::smallint,
        t->>'signature',
        jsonb_array_cast_text(t -> 'proofs'),
        (t->>'version')::smallint,
        (t->>'fee')::bigint,
        coalesce(t->>'applicationStatus', 'succeeded'),
		-- with sender	
        t->>'sender',
        t->>'senderPublicKey',
		-- type specific
	    get_asset_id(t->>'assetId'),
	    (t->>'minSponsoredAssetFee')::bigint
	from (
        select t || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as t
		from (
            select jsonb_array_elements(b->'transactions') as t
	    ) as txs
    ) as txs
	where (t->>'type') = '14'
	on conflict do nothing;
END
$$;


CREATE OR REPLACE FUNCTION public.insert_txs_15(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_15 (
		uid,
        id, 
        time_stamp, 
        height, 
        tx_type, 
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
		(t->>'uid')::bigint,
        t->>'id',
        to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
		(b->>'height')::int4,
        (t->>'type')::smallint,
        t->>'signature',
        jsonb_array_cast_text(t -> 'proofs'),
        (t->>'version')::smallint,
        (t->>'fee')::bigint,
        coalesce(t->>'applicationStatus', 'succeeded'),
		-- with sender
		t->>'sender',
        t->>'senderPublicKey',
		-- type specific
		get_asset_id(t->>'assetId'),
	    t->>'script'
	from (
        select t || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as t
		from (
            select jsonb_array_elements(b->'transactions') as t
	    ) as txs
    ) as txs
	where (t->>'type') = '15'
	on conflict do nothing;
END
$$;


CREATE OR REPLACE FUNCTION public.insert_txs_16(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_16 (
		uid,
        id, 
        time_stamp, 
        height, 
        tx_type, 
        signature,
        proofs, 
        tx_version,
        fee,
        status,
		sender,
        sender_public_key,
		dapp_address,
        dapp_alias,
	    function_name
	)
	select
		-- common
		(t->>'uid')::bigint,
        t->>'id',
        to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
		(b->>'height')::int4,
        (t->>'type')::smallint,
        t->>'signature',
        jsonb_array_cast_text(t -> 'proofs'),
        (t->>'version')::smallint,
        (t->>'fee')::bigint,
        coalesce(t->>'applicationStatus', 'succeeded'),
		-- with sender
		t->>'sender',
        t->>'senderPublicKey',
		-- type specific
		get_address(t->>'dApp'),
        get_alias(t->>'dApp'),
	    t->'call'->>'function'
	from (
        select t || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as t
		from (
            select jsonb_array_elements(b->'transactions') as t
	    ) as txs
    ) as txs
	where (t->>'type') = '16'
	on conflict do nothing;

	insert into txs_16_args (
		tx_uid,
		arg_type,
		arg_value_integer,
		arg_value_boolean,
		arg_value_binary,
		arg_value_string,
		arg_value_list,
		position_in_args,
		height
	)
	select
		(arg->>'tx_uid')::bigint,
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
			then (arg->>'value')::jsonb
			else null
		end as arg_value_list,
		row_number() over (PARTITION BY arg->>'tx_uid') - 1 as position_in_args,
		(b->>'height')::int4
	from (
        select jsonb_array_elements(tx->'call'->'args') || jsonb_build_object('tx_uid', tx->'uid') as arg
        from (
            select tx || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as tx
            from (
                select jsonb_array_elements(b->'transactions') as tx
            ) as txs
        ) as txs
        where (tx->>'type') = '16'
	) as data
	on conflict do nothing;

	insert into txs_16_payment (
		tx_uid,
		amount,
		asset_id,
		position_in_payment,
		height
	)
	select
		(p->>'tx_uid')::bigint,
		(p->>'amount')::bigint as amount,
		get_asset_id(p->>'assetId') as asset_id,
		row_number() over (PARTITION BY p->'tx_uid') - 1 as position_in_payment,
		(b->>'height')::int4
	from (
        select jsonb_array_elements(tx->'payment') || jsonb_build_object('tx_uid', tx->'uid') as p
        from (
            select tx || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as tx
            from (
                select jsonb_array_elements(b->'transactions') as tx
            ) as txs
        ) as txs
        where (tx->>'type') = '16'
	) as data
	on conflict do nothing;
END
$$;


CREATE OR REPLACE FUNCTION insert_txs_17(b jsonb) RETURNS void
	language plpgsql
AS $$
BEGIN
	insert into txs_17 (
        uid,
        id, 
        time_stamp, 
        height, 
        tx_type, 
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
        (t->>'uid')::bigint,
		t->>'id',
		to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		(b->>'height')::int4,
        (t->>'type')::smallint,
        t->>'signature',
        jsonb_array_cast_text(t -> 'proofs'),
        (t->>'version')::smallint,
        (t->>'fee')::bigint,
        coalesce(t->>'applicationStatus', 'succeeded'),
		-- with sender
		t->>'sender',
		t->>'senderPublicKey',
		-- type specific
		get_asset_id(t->>'assetId'),
		t->>'name',
		t->>'description'
	from (
        select t || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as t
        from (
		    select jsonb_array_elements(b->'transactions') as t
        ) as txs
	) as txs
	where (t->>'type') = '17'
	on conflict do nothing;
END
$$;


CREATE OR REPLACE FUNCTION public.insert_txs_2(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_2 (
		uid,
        id, 
        time_stamp, 
        height, 
        tx_type, 
        signature,
        proofs, 
        tx_version,
        fee,
        status,
		sender,
        sender_public_key,
		recipient_address,
		recipient_alias,
		amount
	)
	select
		-- common
		(t->>'uid')::bigint,
        t->>'id',
        to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
		(b->>'height')::int4,
        (t->>'type')::smallint,
        t->>'signature',
        jsonb_array_cast_text(t -> 'proofs'),
        (t->>'version')::smallint,
        (t->>'fee')::bigint,
        coalesce(t->>'applicationStatus', 'succeeded'),
		-- with sender
		t->>'sender',
        t->>'senderPublicKey',
		-- type specific
    	get_address(t->>'recipient'),
    	get_alias(t->>'recipient'),
		(t->>'amount')::bigint
	from (
        select t || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as t
		from (
            select jsonb_array_elements(b->'transactions') as t
        ) as txs
	) as txs
	where (t->>'type') = '2'
	on conflict do nothing;
END
$$;


CREATE OR REPLACE FUNCTION public.insert_txs_3(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_3 (
		uid,
        id, 
        time_stamp, 
        height, 
        tx_type, 
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
		(t->>'uid')::bigint,
        t->>'id',
        to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
		(b->>'height')::int4,
        (t->>'type')::smallint,
        t->>'signature',
        jsonb_array_cast_text(t -> 'proofs'),
        (t->>'version')::smallint,
        (t->>'fee')::bigint,
        coalesce(t->>'applicationStatus', 'succeeded'),
		-- with sender
		t->>'sender',
        t->>'senderPublicKey',
		-- type specific
		t->>'assetId',
		t->>'name',
		t->>'description',
		(t->>'quantity')::bigint,
		(t->>'decimals')::smallint,
		(t->>'reissuable')::bool,
		t->>'script'
	from (
        select t || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as t
        from (
            select jsonb_array_elements(b->'transactions') as t
        ) as txs
	) as txs
	where (t->>'type') = '3'
	on conflict do nothing;
END
$$;


CREATE OR REPLACE FUNCTION public.insert_txs_4(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_4 (
		uid,
        id, 
        time_stamp, 
        height, 
        tx_type, 
        signature,
        proofs, 
        tx_version,
        fee,
        status,
		sender,
        sender_public_key,
		fee_asset_id,
		recipient_address,
		recipient_alias,
		attachment, 
		amount, 
		asset_id
	)
	select
		(t->>'uid')::bigint,
        t->>'id',
        to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
		(b->>'height')::int4,
        (t->>'type')::smallint,
        t->>'signature',
        jsonb_array_cast_text(t -> 'proofs'),
        (t->>'version')::smallint,
        (t->>'fee')::bigint,
        coalesce(t->>'applicationStatus', 'succeeded'),
		-- with sender
		t->>'sender',
        t->>'senderPublicKey',
		-- type-specific
		get_asset_id(coalesce(t->>'feeAsset', t->>'feeAssetId')),
		get_address(t->>'recipient'),
		get_alias(t->>'recipient'),
		t->>'attachment',
		(t->>'amount')::bigint,
		get_asset_id(t->>'assetId')
	from (
        select t || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as t
        from (
            select jsonb_array_elements(b->'transactions') as t
        ) as txs
    ) as txs
	where (t->>'type') = '4'
	on conflict do nothing;
END
$$;


CREATE OR REPLACE FUNCTION public.insert_txs_5(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_5 (
		uid,
        id, 
        time_stamp, 
        height, 
        tx_type, 
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
		(t->>'uid')::bigint,
        t ->> 'id',
        to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
		(b->>'height')::int4,
        (t->>'type')::smallint,
        t->>'signature',
        jsonb_array_cast_text(t -> 'proofs'),
        (t->>'version')::smallint,
        (t->>'fee')::bigint,
        coalesce(t->>'applicationStatus', 'succeeded'),
		-- with sender
		t->>'sender',
        t->>'senderPublicKey',
		-- type specific
		get_asset_id(t->>'assetId'),
		(t->>'quantity')::bigint,
		(t->>'reissuable')::bool
	from (
        select t || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as t
        from (
            select jsonb_array_elements(b->'transactions') as t
	    ) as txs
    ) as txs
	where (t->>'type') = '5'
	on conflict do nothing;
END
$$;


CREATE OR REPLACE FUNCTION public.insert_txs_6(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_6 (
		uid,
        id, 
        time_stamp, 
        height, 
        tx_type, 
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
		(t->>'uid')::bigint,
        t ->> 'id',
        to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
		(b->>'height')::int4,
        (t->>'type')::smallint,
        t->>'signature',
        jsonb_array_cast_text(t -> 'proofs'),
        (t->>'version')::smallint,
        (t->>'fee')::bigint,
        coalesce(t->>'applicationStatus', 'succeeded'),
		-- with sender
		t->>'sender',
        t->>'senderPublicKey',
		-- type specific
		get_asset_id(t->>'assetId'),
		(t->>'amount')::bigint
	from (
        select t || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as t
        from (
            select jsonb_array_elements(b->'transactions') as t
	    ) as txs
    ) as txs
	where (t->>'type') = '6'
	on conflict do nothing;
END
$$;


CREATE OR REPLACE FUNCTION public.insert_txs_7(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    insert into txs_7 (
        uid,
        id,
        time_stamp,
        height,
        tx_type, 
        signature,
        proofs, 
        tx_version,
        fee,
        status,
        sender,
        sender_public_key,
        fee_asset_id,
        order1,
        order2,
        amount,
        price,
        buy_matcher_fee,
        sell_matcher_fee,
        amount_asset_id,
        price_asset_id
    )
    select
        -- common
        (t->>'uid')::bigint,
        t->>'id',
        to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000),
        (b->>'height')::int4,
        (t->>'type')::smallint,
        t->>'signature',
        jsonb_array_cast_text(t -> 'proofs'),
        (t->>'version')::smallint,
        (t->>'fee')::bigint,
        coalesce(t->>'applicationStatus', 'succeeded'),
        -- with sender
        t->>'sender',
        t->>'senderPublicKey',
        -- type specific
        get_asset_id(t->>'feeAssetId'),
        t->'order1',
        t->'order2',
        (t ->> 'amount')::bigint,
        (t ->> 'price')::bigint,
        (t ->> 'buyMatcherFee')::bigint,
        (t ->> 'sellMatcherFee')::bigint,
        get_asset_id(t->'order1'->'assetPair'->>'amountAsset'),
        get_asset_id(t->'order1'->'assetPair'->>'priceAsset')
    from (
        select t || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as t
        from (
            select jsonb_array_elements(b -> 'transactions') as t
        ) as txs
    ) as txs
    where (t ->> 'type') = '7'
    on conflict do nothing;
END
$$;


CREATE OR REPLACE FUNCTION public.insert_txs_8(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_8 (
		uid,
        id, 
        time_stamp, 
        height, 
        tx_type, 
        signature,
        proofs, 
        tx_version,
        fee,
        status,
		sender,
        sender_public_key,
		recipient_address,
		recipient_alias,
		amount
	)
	select
		-- common
		(t->>'uid')::bigint,
        t->>'id',
        to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
		(b->>'height')::int4,
        (t->>'type')::smallint,
        t->>'signature',
        jsonb_array_cast_text(t -> 'proofs'),
        (t->>'version')::smallint,
        (t->>'fee')::bigint,
        coalesce(t->>'applicationStatus', 'succeeded'),
		-- with sender
		t->>'sender',
        t->>'senderPublicKey',
		-- type specific
    	get_address(t->>'recipient'),
	    get_alias(t->>'recipient'),
		(t->>'amount')::bigint
	from (
        select t || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as t
        from (
            select jsonb_array_elements(b->'transactions') as t
        ) as txs
	) as txs
	where (t->>'type') = '8'
	on conflict do nothing;
END
$$;


CREATE OR REPLACE FUNCTION public.insert_txs_9(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_9 (
		uid,
        id, 
        time_stamp, 
        height, 
        tx_type, 
        signature,
        proofs, 
        tx_version,
        fee,
        status,
		sender,
        sender_public_key,
		lease_tx_uid
	)
	select
		-- common
		(t->>'uid')::bigint,
        t->>'id',
        to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
		(b->>'height')::int4,
        (t->>'type')::smallint,
        t->>'signature',
        jsonb_array_cast_text(t -> 'proofs'),
        (t->>'version')::smallint,
        (t->>'fee')::bigint,
        coalesce(t->>'applicationStatus', 'succeeded'),
		-- with sender
		t->>'sender',
        t->>'senderPublicKey',
		-- type specific
		get_tuid_by_tx_id(t->>'leaseId')
	from (
        select t || jsonb_build_object('uid', get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (row_number() over ())::int4 - 1)) as t
        from (
            select jsonb_array_elements(b->'transactions') as t
        ) as txs
	) as txs
	where (t->>'type') = '9'
	on conflict do nothing;
END
$$;


CREATE TABLE public.assets_metadata (
    asset_id varchar,
    asset_name varchar,
    ticker varchar,
    height integer
);


CREATE TABLE public.blocks (
    schema_version smallint NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    reference varchar NOT NULL,
    nxt_consensus_base_target bigint NOT NULL,
    nxt_consensus_generation_signature varchar NOT NULL,
    generator varchar NOT NULL,
    signature varchar NOT NULL,
    fee bigint NOT NULL,
    blocksize integer,
    height integer NOT NULL,
    features smallint[]
);


CREATE TABLE public.blocks_raw (
    height integer NOT NULL,
    b jsonb NOT NULL
);


TRUNCATE publoc.candles;
ALTER TABLE public.candles ALTER COLUMN time_start TYPE timestamp with time zone;
ALTER TABLE public.candles DROP COLUMN interval_in_secs;
ALTER TABLE public.candles ADD COLUMN interval varchar NOT NULL;
ALTER TABLE public.candles RENAME COLUMN matcher TO matcher_address;


TRUNCATE public.pairs;
ALTER TABLE public.pairs RENAME COLUMN matcher TO matcher_address;


ALTER TABLE public.txs ADD COLUMN uid bigint;
ALTER TABLE public.txs ALTER COLUMN time_stamp TYPE timestamp with time zone;
ALTER TABLE public.txs ADD COLUMN fee bigint NOT NULL;


ALTER TABLE public.txs_1 ADD COLUMN recipient_address varchar;
ALTER TABLE public.txs_1 ADD COLUMN recipient_alias varchar;
-- @todo: set recipient_address, recipient_alias from recipient
ALTER TABLE public.txs_1 ALTER COLUMN recipient_address SET NOT NULL;
ALTER TABLE public.txs_1 DROP COLUMN recipient;


ALTER TABLE public.txs_11_transfers ADD COLUMN tx_uid bigint;
-- @todo: set tx_uid from txs.uid according to tx_id
ALTER TABLE public.txs_1 ALTER COLUMN tx_uid SET NOT NULL;
ALTER TABLE public.txs_11_transfers DROP COLUMN tx_id;
ALTER TABLE public.txs_11_transfers ADD COLUMN recipient_address varchar;
ALTER TABLE public.txs_11_transfers ADD COLUMN recipient_alias varchar;
-- @todo: set recipient_address, recipient_alias from recipient
ALTER TABLE public.txs_11_transfers ALTER COLUMN recipient_address SET NOT NULL;
ALTER TABLE public.txs_11_transfers DROP COLUMN recipient;


ALTER TABLE public.txs_12_data ADD COLUMN tx_uid bigint NOT NULL;
-- @todo: set tx_uid from txs.uid according to tx_id
ALTER TABLE public.txs_11_transfers DROP COLUMN tx_id;


ALTER TABLE public.txs_16 ADD COLUMN dapp_address varchar NOT NULL;
ALTER TABLE public.txs_16 ADD COLUMN dapp_alias varchar;
-- @todo: set dapp_address, dapp_alias from dapp
ALTER TABLE public.txs_16 DROP COLUMN dapp;


ALTER TABLE public.txs_16_args ADD COLUMN tx_uid bigint NOT NULL;
-- @todo: set tx_uid from txs.uid according to tx_id
ALTER TABLE public.txs_16_args DROP COLUMN tx_id;


ALTER TABLE public.txs_16_payment ADD COLUMN tx_uid bigint NOT NULL;
-- @todo: set tx_uid from txs.uid according to tx_id
ALTER TABLE public.txs_16_payment DROP COLUMN tx_id;


ALTER TABLE public.txs_2 ADD COLUMN recipient_address varchar;
ALTER TABLE public.txs_2 ADD COLUMN recipient_alias varchar;
-- @todo: set recipient_address, recipient_alias from recipient
ALTER TABLE public.txs_2 ALTER COLUMN recipient_address SET NOT NULL;
ALTER TABLE public.txs_2 DROP COLUMN recipient;


ALTER TABLE public.txs_4 ADD COLUMN recipient_address varchar;
ALTER TABLE public.txs_4 ADD COLUMN recipient_alias varchar;
-- @todo: set recipient_address, recipient_alias from recipient
ALTER TABLE public.txs_4 ALTER COLUMN recipient_address SET NOT NULL;
ALTER TABLE public.txs_4 DROP COLUMN recipient;


CREATE TABLE public.txs_7 (
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    order1 jsonb NOT NULL,
    order2 jsonb NOT NULL,
    amount bigint NOT NULL,
    price bigint NOT NULL,
    amount_asset_id varchar NOT NULL,
    price_asset_id varchar NOT NULL,
    buy_matcher_fee bigint NOT NULL,
    sell_matcher_fee bigint NOT NULL,
    fee_asset_id varchar NOT NULL
) INHERITS (public.txs);


ALTER TABLE public.txs_8 ADD COLUMN recipient_address varchar;
ALTER TABLE public.txs_8 ADD COLUMN recipient_alias varchar;
-- @todo: set recipient_address, recipient_alias from recipient
ALTER TABLE public.txs_8 ALTER COLUMN recipient_address SET NOT NULL;
ALTER TABLE public.txs_8 DROP COLUMN recipient;


ALTER TABLE public.txs_9 ADD COLUMN lease_tx_uid bigint;
-- @todo: set tx_uid from txs.uid according to tx_id
ALTER TABLE public.txs_9 ALTER COLUMN lease_tx_uid SET NOT NULL;
ALTER TABLE public.txs_9 DROP COLUMN tx_id;


CREATE TABLE public.waves_data (
	height int4 NULL,
	quantity numeric NOT NULL
);


INSERT INTO waves_data (height, quantity) VALUES (null, 10000000000000000);


CREATE VIEW assets(asset_id, ticker, asset_name, description, sender, issue_height, issue_timestamp, total_quantity, decimals, reissuable, has_script, min_sponsored_asset_fee) AS
	SELECT au.asset_id,
       t.ticker,
       au.name             AS asset_name,
       au.description,
       ao.issuer           AS sender,
       ao.issue_height,
       ao.issue_time_stamp AS issue_timestamp,
       au.volume           AS total_quantity,
       au.decimals,
       au.reissuable,
       CASE
           WHEN au.script IS NOT NULL THEN true
           ELSE false
           END             AS has_script,
       au.sponsorship      AS min_sponsored_asset_fee
FROM asset_updates au
         LEFT JOIN (SELECT tickers.asset_id,
                           tickers.ticker
                    FROM tickers) t ON au.asset_id::text = t.asset_id
         LEFT JOIN asset_origins ao ON au.asset_id::text = ao.asset_id::text
WHERE au.superseded_by = '9223372036854775806'::bigint
UNION ALL
SELECT 'WAVES'::character varying                         AS asset_id,
       'WAVES'::text                                      AS ticker,
       'Waves'::character varying                         AS asset_name,
       ''::character varying                              AS description,
       ''::character varying                              AS sender,
       0                                                  AS issue_height,
       '2016-04-11 21:00:00+00'::timestamp with time zone AS issue_timestamp,
       ((SELECT waves_data.quantity
         FROM waves_data
         ORDER BY waves_data.height DESC NULLS LAST
         LIMIT 1))::bigint::numeric                       AS total_quantity,
       8                                                  AS decimals,
       false                                              AS reissuable,
       false                                              AS has_script,
       NULL::bigint                                       AS min_sponsored_asset_fee;


ALTER TABLE public.blocks ADD CONSTRAINT blocks_pkey PRIMARY KEY (height);


ALTER TABLE public.blocks_raw ADD CONSTRAINT blocks_raw_pkey PRIMARY KEY (height);


ALTER TABLE public.candles ADD CONSTRAINT candles_pkey PRIMARY KEY (interval, time_start, amount_asset_id, price_asset_id, matcher_address);


ALTER TABLE public.pairs ADD CONSTRAINT pairs_pk PRIMARY KEY (amount_asset_id, price_asset_id, matcher_address);


ALTER TABLE public.txs_1 ADD CONSTRAINT txs_1_pk PRIMARY KEY (uid);


ALTER TABLE public.txs_2 ADD CONSTRAINT txs_2_pk PRIMARY KEY (uid);


ALTER TABLE public.txs_3 ADD CONSTRAINT txs_3_pk PRIMARY KEY (uid);


ALTER TABLE public.txs_4 ADD CONSTRAINT txs_4_pk PRIMARY KEY (uid);


ALTER TABLE public.txs_5 ADD CONSTRAINT txs_5_pk PRIMARY KEY (uid);


ALTER TABLE public.txs_6 ADD CONSTRAINT txs_6_pk PRIMARY KEY (uid);


ALTER TABLE public.txs_7 ADD CONSTRAINT txs_7_pk PRIMARY KEY (uid);


ALTER TABLE public.txs_8 ADD CONSTRAINT txs_8_pk PRIMARY KEY (uid);


ALTER TABLE public.txs_9 ADD CONSTRAINT txs_9_pk PRIMARY KEY (uid);


ALTER TABLE public.txs_10 ADD CONSTRAINT txs_10_pk PRIMARY KEY (uid);


ALTER TABLE public.txs_11 ADD CONSTRAINT txs_11_pk PRIMARY KEY (uid);


ALTER TABLE public.txs_11_transfers ADD CONSTRAINT txs_11_transfers_pkey PRIMARY KEY (tx_uid, position_in_tx);


ALTER TABLE public.txs_12 ADD CONSTRAINT txs_12_pk PRIMARY KEY (uid);


ALTER TABLE public.txs_12_data ADD CONSTRAINT txs_12_data_pkey PRIMARY KEY (tx_uid, position_in_tx);


ALTER TABLE public.txs_13 ADD CONSTRAINT txs_13_pk PRIMARY KEY (uid);


ALTER TABLE public.txs_14 ADD CONSTRAINT txs_14_pk PRIMARY KEY (uid);


ALTER TABLE public.txs_15 ADD CONSTRAINT txs_15_pk PRIMARY KEY (uid);


ALTER TABLE public.txs_16 ADD CONSTRAINT txs_16_pk PRIMARY KEY (uid);


ALTER TABLE public.txs_16_args ADD CONSTRAINT txs_16_args_pk PRIMARY KEY (tx_uid, position_in_args);


ALTER TABLE public.txs_16_payment ADD CONSTRAINT txs_16_payment_pk PRIMARY KEY (tx_uid, position_in_payment);


ALTER TABLE public.txs_17 ADD CONSTRAINT txs_17_pk PRIMARY KEY (uid);


ALTER TABLE public.txs ADD CONSTRAINT txs_pk PRIMARY KEY (uid, id, time_stamp);


ALTER TABLE public.txs_9 ADD CONSTRAINT txs_9_un UNIQUE (uid, lease_tx_uid);


ALTER TABLE public.waves_data ADD CONSTRAINT waves_data_un UNIQUE (height);


CREATE INDEX candles_max_height_index ON public.candles USING btree (max_height);


CREATE INDEX candles_amount_price_ids_matcher_time_start_partial_1m_idx ON candles (amount_asset_id, price_asset_id, matcher_address, time_start) WHERE (("interval")::text = '1m'::text);


CREATE UNIQUE INDEX tickers_ticker_idx ON tickers (ticker);


CREATE INDEX txs_height_idx ON public.txs USING btree (height);


CREATE INDEX txs_id_idx ON public.txs USING hash (id);


CREATE INDEX txs_sender_uid_idx ON public.txs USING btree (sender, uid);


CREATE INDEX txs_time_stamp_uid_idx ON public.txs USING btree (time_stamp, uid);


CREATE INDEX txs_tx_type_idx ON public.txs USING btree (tx_type);


CREATE INDEX txs_10_alias_sender_idx ON public.txs_10 USING btree (alias, sender);


CREATE INDEX txs_10_alias_uid_idx ON public.txs_10 USING btree (alias, uid);


CREATE INDEX txs_10_time_stamp_uid_idx ON public.txs_10 USING btree (time_stamp, uid);


CREATE INDEX txs_10_height_idx ON public.txs_10 USING btree (height);


CREATE INDEX txs_10_sender_uid_idx ON public.txs_10 USING btree (sender, uid);


CREATE INDEX txs_10_id_idx ON public.txs_10 USING hash (id);


CREATE INDEX txs_11_asset_id_uid_idx ON public.txs_11 USING btree (asset_id, uid);


CREATE INDEX txs_11_time_stamp_uid_idx ON public.txs_11 USING btree (time_stamp, uid);


CREATE INDEX txs_11_height_idx ON public.txs_11 USING btree (height);


CREATE INDEX txs_11_sender_uid_idx ON public.txs_11 USING btree (sender, uid);


CREATE INDEX txs_11_id_idx ON public.txs_11 USING hash (id);


CREATE INDEX txs_11_transfers_height_idx ON public.txs_11_transfers USING btree (height);


CREATE INDEX txs_11_transfers_recipient_address_idx ON public.txs_11_transfers USING btree (recipient_address);


CREATE INDEX txs_12_data_data_value_binary_tx_uid_partial_idx ON public.txs_12_data USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


CREATE INDEX txs_12_data_data_value_boolean_tx_uid_partial_idx ON public.txs_12_data USING btree (data_value_boolean, tx_uid) WHERE (data_type = 'boolean'::text);


CREATE INDEX txs_12_data_data_value_integer_tx_uid_partial_idx ON public.txs_12_data USING btree (data_value_integer, tx_uid) WHERE (data_type = 'integer'::text);


CREATE INDEX txs_12_data_data_value_string_tx_uid_partial_idx ON public.txs_12_data USING hash (data_value_string) WHERE (data_type = 'string'::text);


CREATE INDEX txs_12_data_height_idx ON public.txs_12_data USING btree (height);


CREATE INDEX txs_12_data_tx_uid_idx ON public.txs_12_data USING btree (tx_uid);


CREATE INDEX txs_12_time_stamp_uid_idx ON public.txs_12 USING btree (time_stamp, uid);


CREATE INDEX txs_12_height_idx ON public.txs_12 USING btree (height);


CREATE INDEX txs_12_sender_uid_idx ON public.txs_12 USING btree (sender, uid);


CREATE INDEX txs_12_id_idx ON public.txs_12 USING hash (id);


CREATE INDEX txs_12_data_data_key_tx_uid_idx ON txs_12_data USING btree (data_key, tx_uid);


CREATE INDEX txs_12_data_data_type_tx_uid_idx ON txs_12_data USING btree (data_type, tx_uid);


CREATE INDEX txs_13_time_stamp_uid_idx ON public.txs_13 USING btree (time_stamp, uid);


CREATE INDEX txs_13_height_idx ON public.txs_13 USING btree (height);


CREATE INDEX txs_13_md5_script_idx ON public.txs_13 USING btree (md5((script)::text));


CREATE INDEX txs_13_sender_uid_idx ON public.txs_13 USING btree (sender, uid);


CREATE INDEX txs_13_id_idx ON public.txs_13 USING hash (id);


CREATE INDEX txs_14_time_stamp_uid_idx ON public.txs_14 USING btree (time_stamp, uid);


CREATE INDEX txs_14_height_idx ON public.txs_14 USING btree (height);


CREATE INDEX txs_14_sender_uid_idx ON public.txs_14 USING btree (sender, uid);


CREATE INDEX txs_14_id_idx ON public.txs_14 USING hash (id);


CREATE INDEX txs_15_time_stamp_uid_idx ON public.txs_15 USING btree (time_stamp, uid);


CREATE INDEX txs_15_height_idx ON public.txs_15 USING btree (height);


CREATE INDEX txs_15_md5_script_idx ON public.txs_15 USING btree (md5((script)::text));


CREATE INDEX txs_15_sender_uid_idx ON public.txs_15 USING btree (sender, uid);


CREATE INDEX txs_15_id_idx ON public.txs_15 USING hash (id);


CREATE INDEX txs_16_dapp_address_uid_idx ON public.txs_16 USING btree (dapp_address, uid);


CREATE INDEX txs_16_time_stamp_uid_idx ON public.txs_16 USING btree (time_stamp, uid);


CREATE INDEX txs_16_height_idx ON public.txs_16 USING btree (height);


CREATE INDEX txs_16_sender_uid_idx ON public.txs_16 USING btree (sender, uid);


CREATE INDEX txs_16_id_idx ON public.txs_16 USING hash (id);


CREATE INDEX txs_16_function_name_uid_idx ON txs_16 (function_name, uid);


CREATE INDEX txs_16_args_height_idx ON public.txs_16_args USING btree (height);


CREATE INDEX txs_16_payment_asset_id_idx ON public.txs_16_payment USING btree (asset_id);


CREATE INDEX txs_16_payment_height_idx ON public.txs_16_payment USING btree (height);


CREATE INDEX txs_16_dapp_address_function_name_uid_idx ON public.txs_16 (dapp_address, function_name, uid);


CREATE INDEX txs_16_sender_time_stamp_uid_idx ON public.txs_16 (sender, time_stamp, uid);


CREATE INDEX txs_17_height_idx on txs_17 USING btree (height);


CREATE INDEX txs_17_sender_time_stamp_id_idx on txs_17 (sender, time_stamp, uid);


CREATE INDEX txs_17_asset_id_uid_idx on txs_17 (asset_id, uid);


CREATE INDEX txs_1_time_stamp_uid_idx ON public.txs_1 USING btree (time_stamp, uid);


CREATE INDEX txs_1_height_idx ON public.txs_1 USING btree (height);


CREATE INDEX txs_1_sender_uid_idx ON public.txs_1 USING btree (sender, uid);


CREATE INDEX txs_1_id_idx ON public.txs_1 USING hash (id);


CREATE INDEX txs_2_time_stamp_uid_idx ON public.txs_2 USING btree (time_stamp, uid);


CREATE INDEX txs_2_height_idx ON public.txs_2 USING btree (height);


CREATE INDEX txs_2_sender_uid_idx ON public.txs_2 USING btree (sender, uid);


CREATE INDEX txs_2_id_idx ON public.txs_2 USING hash (id);


CREATE INDEX txs_3_asset_id_uid_idx ON public.txs_3 USING btree (asset_id, uid);


CREATE INDEX txs_3_time_stamp_uid_idx ON public.txs_3 USING btree (time_stamp, uid);


CREATE INDEX txs_3_height_idx ON public.txs_3 USING btree (height);


CREATE INDEX txs_3_md5_script_idx ON public.txs_3 USING btree (md5((script)::text));


CREATE INDEX txs_3_sender_uid_idx ON public.txs_3 USING btree (sender, uid);


CREATE INDEX txs_3_id_idx ON public.txs_3 USING hash (id);


CREATE INDEX txs_4_asset_id_uid_idx ON public.txs_4 USING btree (asset_id, uid);


CREATE INDEX txs_4_time_stamp_uid_idx ON public.txs_4 USING btree (time_stamp, uid);


CREATE INDEX txs_4_height_uid_idx ON public.txs_4 USING btree (height, uid);


CREATE INDEX txs_4_id_idx ON public.txs_4 USING hash (id);


CREATE INDEX txs_4_recipient_address_uid_idx ON txs_4 (recipient_address, uid);


CREATE INDEX txs_4_sender_uid_idx ON txs_4 (sender, uid);


CREATE INDEX txs_5_asset_id_uid_idx ON public.txs_5 USING btree (asset_id, uid);


CREATE INDEX txs_5_time_stamp_uid_idx ON public.txs_5 USING btree (time_stamp, uid);


CREATE INDEX txs_5_height_idx ON public.txs_5 USING btree (height);


CREATE INDEX txs_5_sender_uid_idx ON public.txs_5 USING btree (sender, uid);


CREATE INDEX txs_5_id_idx ON public.txs_5 USING hash (id);


CREATE INDEX txs_6_asset_id_uid_idx ON public.txs_6 USING btree (asset_id, uid);


CREATE INDEX txs_6_uid_time_stamp_idx ON public.txs_6 USING btree (time_stamp, uid);


CREATE INDEX txs_6_height_idx ON public.txs_6 USING btree (height);


CREATE INDEX txs_6_sender_uid_idx ON public.txs_6 USING btree (sender, uid);


CREATE INDEX txs_6_id_idx ON public.txs_6 USING hash (id);


CREATE INDEX txs_7_uid_time_stamp_idx ON public.txs_7 USING btree (time_stamp, uid);


CREATE INDEX txs_7_height_idx ON public.txs_7 USING btree (height);


CREATE INDEX txs_7_sender_uid_idx ON public.txs_7 USING btree (sender, uid);


CREATE INDEX txs_7_order_ids_uid_idx ON public.txs_7 USING gin ((ARRAY[order1->>'id', order2->>'id']), uid);


CREATE INDEX txs_7_id_idx ON public.txs_7 USING hash (id);


CREATE INDEX txs_7_order_senders_uid_idx ON txs_7 USING gin ((ARRAY[order1->>'sender', order2->>'sender']), uid);


CREATE INDEX txs_7_amount_asset_id_price_asset_id_uid_idx ON txs_7 (amount_asset_id, price_asset_id, uid);


CREATE INDEX txs_8_uid_time_stamp_idx ON public.txs_8 USING btree (time_stamp, uid);


CREATE INDEX txs_8_height_idx ON public.txs_8 USING btree (height);


CREATE INDEX txs_8_recipient_idx ON public.txs_8 USING btree (recipient_address);


CREATE INDEX txs_8_recipient_address_uid_idx ON public.txs_8 USING btree (recipient_address, uid);


CREATE INDEX txs_8_sender_uid_idx ON public.txs_8 USING btree (sender, uid);


CREATE INDEX txs_8_id_idx ON public.txs_8 USING hash (id);


CREATE INDEX txs_9_uid_time_stamp_idx ON public.txs_9 USING btree (time_stamp, uid);


CREATE INDEX txs_9_height_idx ON public.txs_9 USING btree (height);


CREATE INDEX txs_9_sender_uid_idx ON public.txs_9 USING btree (sender, uid);


CREATE index txs_9_id_idx ON public.txs_9 USING hash (id);


CREATE INDEX waves_data_height_desc_quantity_idx ON public.waves_data (height DESC NULLS LAST, quantity);


CREATE RULE block_delete AS
    ON DELETE TO public.blocks_raw DO DELETE FROM public.blocks
  WHERE (blocks.height = old.height);


CREATE TRIGGER block_insert_trigger BEFORE INSERT ON public.blocks_raw FOR EACH ROW EXECUTE PROCEDURE public.on_block_insert();


CREATE TRIGGER block_update_trigger BEFORE UPDATE ON public.blocks_raw FOR EACH ROW EXECUTE PROCEDURE public.on_block_update();


ALTER TABLE public.txs_1
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_2
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_3
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_4
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_5
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_6
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_7
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_8
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_9
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_10
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_11
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_11_transfers
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_12
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_12_data
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_13
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_14
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_15
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_16
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_16_args
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_16_payment
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_17
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.waves_data
	ADD CONSTRAINT fk_waves_data FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
