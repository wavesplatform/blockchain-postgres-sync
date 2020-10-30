SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
--SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS btree_gin WITH SCHEMA public;
COMMENT ON EXTENSION btree_gin IS 'support for indexing common datatypes in GIN';


CREATE FUNCTION public.count_affected_rows() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    x integer := -1;
BEGIN
    GET DIAGNOSTICS x = ROW_COUNT;
    RETURN x;
END;
$$;


ALTER FUNCTION public.count_affected_rows() OWNER TO dba;


CREATE FUNCTION public.create_range_partitions(_tbl_name varchar, _count integer, _partition_size bigint, _since integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
	declare 
		loop_start int4;
		from_num bigint;
		to_num bigint;
		partition_name varchar;
		execution_result varchar;
	begin
		loop_start = 0;
		for i in loop_start.._count loop 
			from_num := (i + _since) * _partition_size;
			to_num := (i + 1 + _since) * _partition_size;
			partition_name = quote_ident(_tbl_name || '_' || from_num || '_' || to_num);
		
			execute 'create table ' || partition_name || ' partition of ' || quote_ident(_tbl_name) || ' for values from(' || from_num || ') to (' || to_num || ');';
		end loop;
	END;
$$;


ALTER FUNCTION public.create_range_partitions(_tbl_name varchar, _count integer, _partition_size bigint, _since integer) OWNER TO dba;


CREATE FUNCTION public.find_missing_blocks() RETURNS TABLE(missing_height integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
  last_height INT;
BEGIN
  DROP TABLE IF EXISTS __blocks_check;
  CREATE TEMP TABLE __blocks_check (
    q INT
  );

  SELECT height
  INTO last_height
  FROM blocks_raw
  ORDER BY height DESC
  LIMIT 1;

  RAISE NOTICE 'Last height is %', last_height;

  FOR i IN 1..last_height LOOP
    INSERT INTO __blocks_check VALUES (i);
  END LOOP;

  RETURN QUERY SELECT q AS missing_height
               FROM __blocks_check bc
                 LEFT JOIN blocks_raw b ON (bc.q = b.height)
               WHERE b.height IS NULL;

  DROP TABLE __blocks_check;

  RETURN;
END; $$;


ALTER FUNCTION public.find_missing_blocks() OWNER TO dba;


CREATE FUNCTION public.get_address(_address_or_alias varchar) RETURNS varchar
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


ALTER FUNCTION public.get_address(_address_or_alias varchar) OWNER TO dba;


CREATE FUNCTION public.get_alias(_raw_alias varchar) RETURNS varchar
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


ALTER FUNCTION public.get_alias(_raw_alias varchar) OWNER TO dba;


CREATE FUNCTION public.get_asset_id(text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT COALESCE($1, 'WAVES');
$_$;

CREATE FUNCTION public.get_tuid_by_tx_id(_tx_id varchar) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	declare
		tuid bigint;
	begin
		select uid from txs where id = _tx_id into tuid;
		return tuid;
	end;
$$;


ALTER FUNCTION public.get_tuid_by_tx_id(_tx_id varchar) OWNER TO dba;


CREATE FUNCTION public.get_tuid_by_tx_height_and_position_in_block(_height int4, _position_in_block int4) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	begin
		return _height::bigint * 100000::bigint + _position_in_block::bigint;
	end;
$$;


ALTER FUNCTION public.get_tuid_by_tx_height_and_position_in_block(_height int4, _position_in_block int4) OWNER TO dba;


CREATE FUNCTION public.insert_all(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	raise notice 'insert block % at %', b->>'height', clock_timestamp();
	PERFORM insert_block (b);
	PERFORM insert_txs (b);
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


ALTER FUNCTION public.insert_all(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_block(b jsonb) RETURNS void
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


ALTER FUNCTION public.insert_block(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  insert into txs (
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
    get_tuid_by_tx_height_and_position_in_block((b->>'height')::int4, (t->>'rn')::int4 - 1),
	t->>'id',
    to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
    (b->>'height')::int4,
    (t ->> 'type')::smallint,
    t ->> 'signature',
    jsonb_array_cast_text(t -> 'proofs'),
    (t->>'version')::smallint,
    (t->>'fee')::bigint,
    coalesce(t->>'applicationStatus', 'succeeded'),
    t->>'sender',
    t->>'senderPublicKey'
  from (
    select t || jsonb_build_object('rn', row_number() over ()) as t
    from (
      select jsonb_array_elements(b->'transactions') as t
    ) as txs
  ) as txs
  on conflict do nothing;
END
$$;


ALTER FUNCTION public.insert_txs(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_1(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  insert into txs_1 (tx_uid,
                     id,
                     time_stamp,
  					 height,
                     sender,
                     sender_public_key,
                     recipient_address,
                     recipient_alias,
                     amount)
  select
    -- common
    (t->>'uid')::bigint,
    t->>'id',
    to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
    (b->>'height')::int4,
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


ALTER FUNCTION public.insert_txs_1(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_10(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_10 (
		tx_uid,
        id,
        time_stamp,
		height,
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


ALTER FUNCTION public.insert_txs_10(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_11(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  insert into txs_11 (tx_uid,
                      id,
                      time_stamp,
  					  height,
                      sender,
                      sender_public_key,
                      asset_id,
                      attachment)
  select
    -- common
    (t->>'uid')::bigint,
    t->>'id',
    to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
    (b->>'height')::int4,
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


ALTER FUNCTION public.insert_txs_11(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_12(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_12 (
		tx_uid,
        id,
        time_stamp,
		height,
		sender,
        sender_public_key
	)
	select
		-- common
		(t->>'uid')::bigint,
        t->>'id',
        to_timestamp((t->>'timestamp')::DOUBLE PRECISION / 1000),
		(b->>'height')::int4,
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


ALTER FUNCTION public.insert_txs_12(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_13(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_13 (
		tx_uid,
        id,
        time_stamp,
		height,
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


ALTER FUNCTION public.insert_txs_13(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_14(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_14 (
		tx_uid,
        id,
        time_stamp,
		height,
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


ALTER FUNCTION public.insert_txs_14(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_15(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_15 (
		tx_uid,
        id,
        time_stamp,
		height,
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


ALTER FUNCTION public.insert_txs_15(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_16(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_16 (
		tx_uid,
        id,
        time_stamp,
		height,
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


ALTER FUNCTION public.insert_txs_16(b jsonb) OWNER TO dba;

CREATE FUNCTION insert_txs_17(b jsonb) RETURNS void
	language plpgsql
AS $$
BEGIN
	insert into txs_17 (
        tx_uid,
		id,
		time_stamp,
		height,
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


ALTER FUNCTION insert_txs_17(jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_2(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_2 (
		tx_uid,
        id,
        time_stamp,
		height,
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


ALTER FUNCTION public.insert_txs_2(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_3(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_3 (
		tx_uid,
        id,
        time_stamp,
		height,
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


ALTER FUNCTION public.insert_txs_3(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_4(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_4 (
		tx_uid,
        id,
        time_stamp,
		height,
		fee_asset_id,
		sender,
        sender_public_key,
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
		get_asset_id(coalesce(t->>'feeAsset', t->>'feeAssetId')),
		-- with sender
		t->>'sender',
        t->>'senderPublicKey',
		-- type-specific
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


ALTER FUNCTION public.insert_txs_4(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_5(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_5 (
		tx_uid,
        id,
        time_stamp,
		height,
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


ALTER FUNCTION public.insert_txs_5(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_6(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_6 (
		tx_uid,
        id,
        time_stamp,
		height,
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


ALTER FUNCTION public.insert_txs_6(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_7(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  insert into txs_7 (tx_uid,
                     id,
  					 height,
                     fee_asset_id,
                     time_stamp,
                     sender,
                     sender_public_key,
                     order1,
                     order2,
                     amount,
                     price,
                     buy_matcher_fee,
                     sell_matcher_fee,
                     amount_asset_id,
                     price_asset_id)
  select
    -- common
    (t->>'uid')::bigint,
    t->>'id',
    (b->>'height')::int4,
   	get_asset_id(t->>'feeAssetId'),
    to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000),
    -- with sender
	t->>'sender',
    t->>'senderPublicKey',
    -- type specific
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


ALTER FUNCTION public.insert_txs_7(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_8(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_8 (
		tx_uid,
        id,
        time_stamp,
		height,
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


ALTER FUNCTION public.insert_txs_8(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_9(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_9 (
		tx_uid,
        id,
        time_stamp,
		height,
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


ALTER FUNCTION public.insert_txs_9(b jsonb) OWNER TO dba;


CREATE FUNCTION public.jsonb_array_cast_int(jsonb) RETURNS integer[]
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT array_agg(x)::int[] || ARRAY[]::int[] FROM jsonb_array_elements_text($1) t(x);
$_$;


ALTER FUNCTION public.jsonb_array_cast_int(jsonb) OWNER TO dba;


CREATE FUNCTION public.jsonb_array_cast_text(jsonb) RETURNS text[]
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT array_agg(x) || ARRAY[]::text[] FROM jsonb_array_elements_text($1) t(x);
$_$;


ALTER FUNCTION public.jsonb_array_cast_text(jsonb) OWNER TO dba;


CREATE FUNCTION public.on_block_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  	PERFORM insert_all (new.b);
	return new;
END
$$;


ALTER FUNCTION public.on_block_insert() OWNER TO dba;


CREATE FUNCTION public.on_block_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	delete from blocks where height = new.height;
	PERFORM insert_all (new.b);
	return new;
END
$$;


ALTER FUNCTION public.on_block_update() OWNER TO dba;


CREATE FUNCTION public.reinsert_range(range_start integer, range_end integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  FOR i IN range_start..range_end LOOP
    RAISE NOTICE 'Updating block: %', i;

    DELETE FROM blocks
    WHERE height = i;

    PERFORM insert_all(b)
    FROM blocks_raw
    WHERE height = i;
  END LOOP;
END
$$;


ALTER FUNCTION public.reinsert_range(range_start integer, range_end integer) OWNER TO dba;


CREATE FUNCTION public.reinsert_range(range_start integer, range_end integer, step integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  FOR i IN 0..(range_end/step) LOOP
    RAISE NOTICE 'Updating block: %', i*step + range_start;

    DELETE FROM blocks
    WHERE height >= i*step + range_start and height <= i*(step + 1) + range_start;

    PERFORM insert_all(b)
    FROM blocks_raw
    WHERE height >= i*step + range_start and height <= i*(step + 1) + range_start;
  END LOOP;
END
$$;


ALTER FUNCTION public.reinsert_range(range_start integer, range_end integer, step integer) OWNER TO dba;


CREATE FUNCTION public.sync_partitions(_tbl_name varchar) RETURNS void
    LANGUAGE plpgsql
    AS $$
	declare 
		table_name varchar;
		tuples_count int4;
		max_tuples_count int4;
		partition_size int4;
	BEGIN

		-- get partitions stats
		select 
			t_name,
			t_count, 
			max_c::int4,
			(max_c::int4 - min_c::int4) as p_size
		from (
			select 
				t_name,
				t_count,
				coalesce((string_to_array(t_range, '_'))[1], '0') as min_c,
				coalesce((string_to_array(t_range, '_'))[2], '0') as max_c
			from (
				select
					child.relname as t_name,
					child.reltuples as t_count,
					trim(leading 'default' from trim(leading _tbl_name from child.relname)) as t_range
				FROM pg_inherits
				    JOIN pg_class parent            ON pg_inherits.inhparent = parent.oid
				    JOIN pg_class child             ON pg_inherits.inhrelid   = child.oid
				    JOIN pg_namespace nmsp_parent   ON nmsp_parent.oid  = parent.relnamespace
				    JOIN pg_namespace nmsp_child    ON nmsp_child.oid   = child.relnamespace
				WHERE parent.relname=_tbl_name
				order by inhrelid desc
				limit 1
			) as t
		) as t
		into table_name, tuples_count, max_tuples_count, partition_size;
		
		-- create additional 10 partitions, whether partition size is filled for 90+% 
		if partition_size - tuples_count < partition_size / 10 then
			perform create_range_partitions(_tbl_name, 10, partition_size, max_tuples_count / partition_size);
		end if;
		
	END;
$$;


ALTER FUNCTION public.sync_partitions(_tbl_name varchar) OWNER TO dba;


CREATE FUNCTION public.text_timestamp_cast(text) RETURNS timestamp without time zone
    LANGUAGE plpgsql
    AS $_$
begin
--   raise notice $1;
  return to_timestamp($1 :: DOUBLE PRECISION / 1000);
END
$_$;


ALTER FUNCTION public.text_timestamp_cast(text) OWNER TO dba;

SET default_tablespace = '';

SET default_with_oids = false;


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


CREATE TABLE public.candles (
    time_start timestamp with time zone NOT NULL,
    amount_asset_id varchar NOT NULL,
    price_asset_id varchar NOT NULL,
    low numeric NOT NULL,
    high numeric NOT NULL,
    volume numeric NOT NULL,
    quote_volume numeric NOT NULL,
    max_height integer NOT NULL,
    txs_count integer NOT NULL,
    weighted_average_price numeric NOT NULL,
    open numeric NOT NULL,
    close numeric NOT NULL,
    interval varchar NOT NULL,
    matcher_address varchar NOT NULL
);


CREATE TABLE public.pairs (
    amount_asset_id varchar NOT NULL,
    price_asset_id varchar NOT NULL,
    first_price numeric NOT NULL,
    last_price numeric NOT NULL,
    volume numeric NOT NULL,
    volume_waves numeric,
    quote_volume numeric NOT NULL,
    high numeric NOT NULL,
    low numeric NOT NULL,
    weighted_average_price numeric NOT NULL,
    txs_count integer NOT NULL,
    matcher_address varchar NOT NULL
);


CREATE TABLE tickers (
	asset_id TEXT NOT NULL
		CONSTRAINT tickers_pkey
			PRIMARY KEY,
	ticker TEXT NOT NULL
);


CREATE TABLE public.txs (
    uid bigint NOT NULL,
    tx_type smallint NOT NULL,
    sender varchar,
    sender_public_key varchar,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id varchar NOT NULL,
    signature varchar,
    proofs varchar[],
    tx_version smallint,
    fee bigint,
    status varchar DEFAULT 'succeeded' NOT NULL
)
PARTITION BY RANGE (uid);


SELECT create_range_partitions('txs', 10, 50000000000, 0);


CREATE TABLE public.txs_1 (
    tx_uid bigint CONSTRAINT txs_1_pk PRIMARY KEY,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar,
    sender_public_key varchar,
    recipient_address varchar NOT NULL,
    recipient_alias varchar,
    amount bigint NOT NULL
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_1_default (
    tx_uid bigint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar,
    sender_public_key varchar,
    recipient_address varchar NOT NULL,
    recipient_alias varchar,
    amount bigint NOT NULL
);
ALTER TABLE public.txs_1 ATTACH PARTITION public.txs_1_default DEFAULT;


CREATE TABLE public.txs_10 (
    tx_uid bigint CONSTRAINT txs_10_pk PRIMARY KEY,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    alias varchar NOT NULL
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_10_default (
    tx_uid bigint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    alias varchar NOT NULL
);
ALTER TABLE public.txs_10 ATTACH PARTITION public.txs_10_default DEFAULT;


CREATE TABLE public.txs_11 (
    tx_uid bigint CONSTRAINT txs_11_pk PRIMARY KEY,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id varchar NOT NULL,
    attachment varchar NOT NULL
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_11_default (
    tx_uid bigint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id varchar NOT NULL,
    attachment varchar NOT NULL
);
ALTER TABLE public.txs_11 ATTACH PARTITION public.txs_11_default DEFAULT;


CREATE TABLE public.txs_11_transfers (
    tx_uid bigint NOT NULL,
    recipient_address varchar NOT NULL,
    recipient_alias varchar,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL
)
PARTITION BY RANGE (tx_uid);


SELECT create_range_partitions('txs_11_transfers', 10, 50000000000, 0);


CREATE TABLE public.txs_11_transfers_default (
    tx_uid bigint NOT NULL,
    recipient_address varchar NOT NULL,
    recipient_alias varchar,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL
);
ALTER TABLE public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_default DEFAULT;


CREATE TABLE public.txs_12 (
    tx_uid bigint CONSTRAINT txs_12_pk PRIMARY KEY,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_12_default (
    tx_uid bigint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL
);
ALTER TABLE public.txs_12 ATTACH PARTITION public.txs_12_default DEFAULT;


CREATE TABLE public.txs_12_data (
    tx_uid bigint NOT NULL,
    data_key text NOT NULL,
    data_type text,
    data_value_integer bigint,
    data_value_boolean boolean,
    data_value_binary text,
    data_value_string text,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL
)
PARTITION BY RANGE (tx_uid);


SELECT create_range_partitions('txs_12_data', 10, 50000000000, 0);


CREATE TABLE public.txs_12_data_default (
    tx_uid bigint NOT NULL,
    data_key text NOT NULL,
    data_type text,
    data_value_integer bigint,
    data_value_boolean boolean,
    data_value_binary text,
    data_value_string text,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL
);
ALTER TABLE public.txs_12_data ATTACH PARTITION public.txs_12_data_default DEFAULT;


CREATE TABLE public.txs_13 (
    tx_uid bigint CONSTRAINT txs_13_pk PRIMARY KEY,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    script varchar
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_13_default (
    tx_uid bigint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    script varchar
);
ALTER TABLE public.txs_13 ATTACH PARTITION public.txs_13_default DEFAULT;


CREATE TABLE public.txs_14 (
    tx_uid bigint CONSTRAINT txs_14_pk PRIMARY KEY,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id varchar NOT NULL,
    min_sponsored_asset_fee bigint
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_14_default (
    tx_uid bigint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id varchar NOT NULL,
    min_sponsored_asset_fee bigint
);
ALTER TABLE public.txs_14 ATTACH PARTITION public.txs_14_default DEFAULT;


CREATE TABLE public.txs_15 (
    tx_uid bigint CONSTRAINT txs_15_pk PRIMARY KEY,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id varchar NOT NULL,
    script varchar
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_15_default (
    tx_uid bigint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id varchar NOT NULL,
    script varchar
);
ALTER TABLE public.txs_15 ATTACH PARTITION public.txs_15_default DEFAULT;


CREATE TABLE public.txs_16 (
    tx_uid bigint CONSTRAINT txs_16_pk PRIMARY KEY,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    dapp_address varchar NOT NULL,
    dapp_alias varchar,
    function_name varchar
)
PARTITION BY RANGE (tx_uid);


SELECT create_range_partitions('txs_16', 10, 50000000000, 0);


CREATE TABLE public.txs_16_default (
    tx_uid bigint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    dapp_address varchar NOT NULL,
    dapp_alias varchar,
    function_name varchar
);
ALTER TABLE public.txs_16 ATTACH PARTITION public.txs_16_default DEFAULT;


CREATE TABLE public.txs_16_args (
    arg_type text NOT NULL,
    arg_value_integer bigint,
    arg_value_boolean boolean,
    arg_value_binary text,
    arg_value_string text,
    arg_value_list jsonb,
    position_in_args smallint NOT NULL,
    tx_uid bigint NOT NULL,
    height integer
)
PARTITION BY RANGE (tx_uid);


SELECT create_range_partitions('txs_16_args', 10, 50000000000, 0);


CREATE TABLE public.txs_16_args_default (
    arg_type text NOT NULL,
    arg_value_integer bigint,
    arg_value_boolean boolean,
    arg_value_binary text,
    arg_value_string text,
    arg_value_list jsonb,
    position_in_args smallint NOT NULL,
    tx_uid bigint NOT NULL,
    height integer
);
ALTER TABLE ONLY public.txs_16_args ATTACH PARTITION public.txs_16_args_default DEFAULT;


CREATE TABLE public.txs_16_payment (
    tx_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_payment smallint NOT NULL,
    height integer,
    asset_id varchar NOT NULL
)
PARTITION BY RANGE (tx_uid);


SELECT create_range_partitions('txs_16_payment', 10, 50000000000, 0);


CREATE TABLE public.txs_16_payment_default (
    tx_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_payment smallint NOT NULL,
    height integer,
    asset_id varchar NOT NULL
);
ALTER TABLE public.txs_16_payment ATTACH PARTITION public.txs_16_payment_default DEFAULT;


CREATE TABLE  public.txs_17 (
    tx_uid BIGINT CONSTRAINT txs_17_pk PRIMARY KEY,
    id VARCHAR NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender VARCHAR NOT NULL,
    sender_public_key VARCHAR NOT NULL,
    asset_id VARCHAR NOT NULL,
    asset_name VARCHAR NOT NULL,
    description VARCHAR NOT NULL
)
PARTITION BY RANGE (tx_uid);


SELECT create_range_partitions('txs_17', 10, 50000000000, 0);


CREATE TABLE public.txs_17_default (
    tx_uid bigint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id VARCHAR NOT NULL,
    asset_name VARCHAR NOT NULL,
    description VARCHAR NOT NULL
);
ALTER TABLE public.txs_17 ATTACH PARTITION public.txs_17_default DEFAULT;


CREATE TABLE public.txs_2 (
    tx_uid bigint CONSTRAINT txs_2_pk PRIMARY KEY,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    recipient_address varchar NOT NULL,
    recipient_alias varchar,
    amount bigint NOT NULL
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_2_default (
    tx_uid bigint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    recipient_address varchar NOT NULL,
    recipient_alias varchar,
    amount bigint NOT NULL
);
ALTER TABLE public.txs_2 ATTACH PARTITION public.txs_2_default DEFAULT;


CREATE TABLE public.txs_3 (
    tx_uid bigint CONSTRAINT txs_3_pk PRIMARY KEY,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id varchar NOT NULL,
    asset_name varchar NOT NULL,
    description varchar NOT NULL,
    quantity bigint NOT NULL,
    decimals smallint NOT NULL,
    reissuable boolean NOT NULL,
    script varchar
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_3_default (
    tx_uid bigint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id varchar NOT NULL,
    asset_name varchar NOT NULL,
    description varchar NOT NULL,
    quantity bigint NOT NULL,
    decimals smallint NOT NULL,
    reissuable boolean NOT NULL,
    script varchar
);
ALTER TABLE public.txs_3 ATTACH PARTITION public.txs_3_default DEFAULT;


CREATE TABLE public.txs_4 (
    tx_uid bigint CONSTRAINT txs_4_pk PRIMARY KEY,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id varchar NOT NULL,
    amount bigint NOT NULL,
    recipient_address varchar NOT NULL,
    recipient_alias varchar,
    fee_asset_id varchar NOT NULL,
    attachment varchar NOT NULL
)
PARTITION BY RANGE (tx_uid);


SELECT create_range_partitions('txs_4', 10, 50000000000, 0);


CREATE TABLE public.txs_4_default (
    tx_uid bigint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id varchar NOT NULL,
    amount bigint NOT NULL,
    recipient_address varchar NOT NULL,
    recipient_alias varchar,
    fee_asset_id varchar NOT NULL,
    attachment varchar NOT NULL
);
ALTER TABLE public.txs_4 ATTACH PARTITION public.txs_4_default DEFAULT;


CREATE TABLE public.txs_5 (
    tx_uid bigint CONSTRAINT txs_5_pk PRIMARY KEY,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id varchar NOT NULL,
    quantity bigint NOT NULL,
    reissuable boolean NOT NULL
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_5_default (
    tx_uid bigint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id varchar NOT NULL,
    quantity bigint NOT NULL,
    reissuable boolean NOT NULL
);
ALTER TABLE public.txs_5 ATTACH PARTITION public.txs_5_default DEFAULT;


CREATE TABLE public.txs_6 (
    tx_uid bigint CONSTRAINT txs_6_pk PRIMARY KEY,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id varchar NOT NULL,
    amount bigint NOT NULL
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_6_default (
    tx_uid bigint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id varchar NOT NULL,
    amount bigint NOT NULL
);
ALTER TABLE public.txs_6 ATTACH PARTITION public.txs_6_default DEFAULT;


CREATE TABLE public.txs_7 (
    tx_uid bigint CONSTRAINT txs_7_pk PRIMARY KEY,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
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
)
PARTITION BY RANGE (tx_uid);


SELECT create_range_partitions('txs_7', 10, 50000000000, 0);


CREATE TABLE public.txs_7_default (
    tx_uid bigint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
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
);
ALTER TABLE public.txs_7 ATTACH PARTITION public.txs_7_default DEFAULT;


CREATE TABLE public.txs_8 (
    tx_uid bigint CONSTRAINT txs_8_pk PRIMARY KEY,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    recipient_address varchar NOT NULL,
    recipient_alias varchar,
    amount bigint NOT NULL
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_8_default (
    tx_uid bigint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    recipient_address varchar NOT NULL,
    recipient_alias varchar,
    amount bigint NOT NULL
);
ALTER TABLE public.txs_8 ATTACH PARTITION public.txs_8_default DEFAULT;


CREATE TABLE public.txs_9 (
    tx_uid bigint CONSTRAINT txs_9_pk PRIMARY KEY,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    lease_tx_uid bigint
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_9_default (
    tx_uid bigint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    lease_tx_uid bigint
);
ALTER TABLE public.txs_9 ATTACH PARTITION public.txs_9_default DEFAULT;


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


ALTER TABLE public.txs ADD CONSTRAINT txs_pk PRIMARY KEY (id, time_stamp, uid);


ALTER TABLE public.txs_11_transfers ADD CONSTRAINT txs_11_transfers_pkey PRIMARY KEY (tx_uid, position_in_tx);


ALTER TABLE public.txs_12_data ADD CONSTRAINT txs_12_data_pkey PRIMARY KEY (tx_uid, position_in_tx);


ALTER TABLE public.txs_16_args ADD CONSTRAINT txs_16_args_pk PRIMARY KEY (tx_uid, position_in_args);


ALTER TABLE public.txs_16_payment ADD CONSTRAINT txs_16_payment_pk PRIMARY KEY (tx_uid, position_in_payment);


ALTER TABLE public.txs_9 ADD CONSTRAINT txs_9_un UNIQUE (tx_uid, lease_tx_uid);


ALTER TABLE public.waves_data ADD CONSTRAINT waves_data_un UNIQUE (height);


CREATE INDEX candles_max_height_index ON public.candles USING btree (max_height);


CREATE UNIQUE INDEX tickers_ticker_idx ON tickers (ticker);


CREATE INDEX txs_height_idx ON public.txs USING btree (height);


CREATE INDEX txs_id_uid_idx ON public.txs USING btree (id, uid);


CREATE INDEX txs_sender_uid_idx ON public.txs USING btree (sender, uid);


CREATE INDEX txs_time_stamp_idx ON public.txs USING btree (time_stamp);


CREATE UNIQUE INDEX txs_uid_time_stamp_unique_idx ON txs (uid, time_stamp);


CREATE UNIQUE INDEX txs_uid_desc_time_stamp_unique_idx ON txs (uid desc, time_stamp);


CREATE INDEX txs_tx_type_idx ON public.txs USING btree (tx_type);


CREATE INDEX txs_uid_idx ON public.txs USING btree (uid);


CREATE INDEX txs_10_alias_sender_idx ON public.txs_10 USING btree (alias, sender);


CREATE INDEX txs_10_alias_tuid_idx ON public.txs_10 USING btree (alias, tx_uid);


CREATE INDEX txs_10_time_stamp_tx_uid_idx ON public.txs_10 USING btree (time_stamp, tx_uid);


CREATE INDEX txs_10_height_idx ON public.txs_10 USING btree (height);


CREATE INDEX txs_10_sender_idx ON public.txs_10 USING hash (sender);


CREATE INDEX txs_10_alias_tx_uid_idx ON public.txs_10 USING btree (alias, tx_uid);


CREATE INDEX txs_10_id_tx_uid_idx ON public.txs_10 (id, tx_uid);


CREATE INDEX txs_11_asset_id_idx ON public.txs_11 USING hash (asset_id);


CREATE INDEX txs_11_time_stamp_tx_uid_idx ON public.txs_11 USING btree (time_stamp, tx_uid);


CREATE INDEX txs_11_height_idx ON public.txs_11 USING btree (height);


CREATE INDEX txs_11_sender_tx_uid_idx ON public.txs_11 USING btree (sender, tx_uid);


CREATE INDEX txs_11_id_tx_uid_idx ON public.txs_11 (id, tx_uid);


CREATE INDEX txs_11_transfers_height_idx ON public.txs_11_transfers USING btree (height);


CREATE INDEX txs_11_transfers_recipient_address_idx ON public.txs_11_transfers USING btree (recipient_address);


CREATE INDEX txs_11_transfers_tuid_idx ON public.txs_11_transfers USING btree (tx_uid);


CREATE INDEX txs_12_data_data_key_idx ON public.txs_12_data USING hash (data_key);


CREATE INDEX txs_12_data_data_type_idx ON public.txs_12_data USING hash (data_type);


CREATE INDEX txs_12_data_data_value_binary_partial_idx ON public.txs_12_data USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


CREATE INDEX txs_12_data_data_value_boolean_partial_idx ON public.txs_12_data USING btree (data_value_boolean) WHERE (data_type = 'boolean'::text);


CREATE INDEX txs_12_data_data_value_integer_partial_idx ON public.txs_12_data USING btree (data_value_integer) WHERE (data_type = 'integer'::text);


CREATE INDEX txs_12_data_data_value_string_partial_idx ON public.txs_12_data USING hash (data_value_string) WHERE (data_type = 'string'::text);


CREATE INDEX txs_12_data_height_idx ON public.txs_12_data USING btree (height);


CREATE INDEX txs_12_data_tx_uid_idx ON public.txs_12_data USING btree (tx_uid);


CREATE INDEX txs_12_time_stamp_tx_uid_idx ON public.txs_12 USING btree (time_stamp, tx_uid);


CREATE INDEX txs_12_height_idx ON public.txs_12 USING btree (height);


CREATE INDEX txs_12_sender_idx ON public.txs_12 USING hash (sender);


CREATE INDEX txs_12_id_tx_uid_idx ON public.txs_12 (id, tx_uid);


CREATE INDEX txs_12_data_tx_uid_data_key_idx ON txs_12_data (tx_uid, data_key);


CREATE INDEX txs_12_data_tx_uid_data_type_idx ON txs_12_data (tx_uid, data_type);


CREATE INDEX txs_13_time_stamp_tx_uid_idx ON public.txs_13 USING btree (time_stamp, tx_uid);


CREATE INDEX txs_13_height_idx ON public.txs_13 USING btree (height);


CREATE INDEX txs_13_md5_script_idx ON public.txs_13 USING btree (md5((script)::text));


CREATE INDEX txs_13_sender_idx ON public.txs_13 USING hash (sender);


CREATE INDEX txs_13_id_tx_uid_idx ON public.txs_13 (id, tx_uid);


CREATE INDEX txs_14_time_stamp_tx_uid_idx ON public.txs_14 USING btree (time_stamp, tx_uid);


CREATE INDEX txs_14_height_idx ON public.txs_14 USING btree (height);


CREATE INDEX txs_14_sender_idx ON public.txs_14 USING hash (sender);


CREATE INDEX txs_14_id_tx_uid_idx ON public.txs_14 (id, tx_uid);


CREATE INDEX txs_15_time_stamp_tx_uid_idx ON public.txs_15 USING btree (time_stamp, tx_uid);


CREATE INDEX txs_15_height_idx ON public.txs_15 USING btree (height);


CREATE INDEX txs_15_md5_script_idx ON public.txs_15 USING btree (md5((script)::text));


CREATE INDEX txs_15_sender_idx ON public.txs_15 USING btree (sender);


CREATE INDEX txs_15_id_tx_uid_idx ON public.txs_15 (id, tx_uid);


CREATE INDEX txs_16_dapp_address_tx_uid_idx ON public.txs_16 USING btree (dapp_address, tx_uid);


CREATE INDEX txs_16_time_stamp_tx_uid_idx ON public.txs_16 USING btree (time_stamp, tx_uid);


CREATE INDEX txs_16_height_idx ON public.txs_16 USING btree (height);


CREATE INDEX txs_16_sender_idx ON public.txs_16 USING btree (sender);


CREATE INDEX txs_16_id_tx_uid_idx ON public.txs_16 (id, tx_uid);


CREATE INDEX txs_16_sender_tx_uid_idx ON public.txs_16 USING btree (sender, tx_uid);


CREATE INDEX txs_16_function_name_tx_uid_idx ON txs_16 (function_name, tx_uid);


CREATE INDEX txs_16_args_height_idx ON public.txs_16_args USING btree (height);


CREATE INDEX txs_16_payment_asset_id_idx ON public.txs_16_payment USING btree (asset_id);


CREATE INDEX txs_16_payment_height_idx ON public.txs_16_payment USING btree (height);


CREATE INDEX txs_17_height_idx on txs_17 (height);


CREATE INDEX txs_17_sender_time_stamp_id_idx on txs_17 (sender, time_stamp, id);


CREATE INDEX txs_17_asset_id_id_idx on txs_17 (asset_id, id);


CREATE INDEX txs_1_time_stamp_tx_uid_idx ON public.txs_1 USING btree (time_stamp, tx_uid);


CREATE INDEX txs_1_height_idx ON public.txs_1 USING btree (height);


CREATE INDEX txs_1_sender_idx ON public.txs_1 USING btree (sender);


CREATE INDEX txs_1_id_tx_uid_idx ON public.txs_1 (id, tx_uid);


CREATE INDEX txs_2_time_stamp_tx_uid_idx ON public.txs_2 USING btree (time_stamp, tx_uid);


CREATE INDEX txs_2_height_idx ON public.txs_2 USING btree (height);


CREATE INDEX txs_2_sender_idx ON public.txs_2 USING hash (sender);


CREATE INDEX txs_2_id_tx_uid_idx ON public.txs_2 (id, tx_uid);


CREATE INDEX txs_3_asset_id_idx ON public.txs_3 USING hash (asset_id);


CREATE INDEX txs_3_time_stamp_tx_uid_idx ON public.txs_3 USING btree (time_stamp, tx_uid);


CREATE INDEX txs_3_height_idx ON public.txs_3 USING btree (height);


CREATE INDEX txs_3_md5_script_idx ON public.txs_3 USING btree (md5((script)::text));


CREATE INDEX txs_3_sender_idx ON public.txs_3 USING hash (sender);


CREATE INDEX txs_3_id_tx_uid_idx ON public.txs_3 (id, tx_uid);


CREATE INDEX txs_4_asset_id_tx_uid_idx ON public.txs_4 USING btree (asset_id, tx_uid);


CREATE INDEX txs_4_time_stamp_tx_uid_idx ON public.txs_4 USING btree (time_stamp, tx_uid);


CREATE INDEX txs_4_height_tx_uid_idx ON public.txs_4 USING btree (height, tx_uid);


CREATE INDEX txs_4_id_tx_uid_idx ON public.txs_4 (id, tx_uid);


CREATE INDEX txs_4_recipient_address_tx_uid_idx ON txs_4 (recipient_address, tx_uid);


CREATE INDEX txs_4_sender_tx_uid_idx ON txs_4 (sender, tx_uid);


CREATE INDEX txs_5_asset_id_idx ON public.txs_5 USING hash (asset_id);


CREATE INDEX txs_5_time_stamp_tx_uid_idx ON public.txs_5 USING btree (time_stamp, tx_uid);


CREATE INDEX txs_5_height_idx ON public.txs_5 USING btree (height);


CREATE INDEX txs_5_sender_idx ON public.txs_5 USING hash (sender);


CREATE INDEX txs_5_id_tx_uid_idx ON public.txs_5 (id, tx_uid);


CREATE INDEX txs_6_asset_id_idx ON public.txs_6 USING hash (asset_id);


CREATE INDEX txs_6_tx_uid_time_stamp_idx ON public.txs_6 USING btree (tx_uid, time_stamp);


CREATE INDEX txs_6_height_idx ON public.txs_6 USING btree (height);


CREATE INDEX txs_6_sender_idx ON public.txs_6 USING hash (sender);


CREATE INDEX txs_6_id_tx_uid_idx ON public.txs_6 (id, tx_uid);


CREATE INDEX txs_7_tx_uid_time_stamp_idx ON public.txs_7 USING btree (tx_uid, time_stamp);


CREATE INDEX txs_7_height_idx ON public.txs_7 USING btree (height);


CREATE INDEX txs_7_sender_idx ON public.txs_7 USING btree (sender);


CREATE INDEX txs_7_tx_uid_height_idx ON public.txs_7 USING btree (tx_uid, height);


CREATE INDEX txs_7_order_ids_tx_uid_idx ON public.txs_7 USING gin ((ARRAY[order1->>'id', order2->>'id']), tx_uid);


CREATE INDEX txs_7_id_tx_uid_idx ON public.txs_7 (id, tx_uid);


create index txs_7_order_senders_tx_uid_idx on txs_7 USING gin ((ARRAY[order1->>'sender', order2->>'sender']), tx_uid);


CREATE INDEX txs_8_tx_uid_time_stamp_idx ON public.txs_8 USING btree (tx_uid, time_stamp);


CREATE INDEX txs_8_height_idx ON public.txs_8 USING btree (height);


CREATE INDEX txs_8_recipient_idx ON public.txs_8 USING btree (recipient_address);


CREATE INDEX txs_8_recipient_address_tx_uid_idx ON public.txs_8 USING btree (recipient_address, tx_uid);


CREATE INDEX txs_8_sender_idx ON public.txs_8 USING btree (sender);


CREATE INDEX txs_8_id_tx_uid_idx ON public.txs_8 (id, tx_uid);


CREATE INDEX txs_9_tx_uid_time_stamp_idx ON public.txs_9 USING btree (tx_uid, time_stamp);


CREATE INDEX txs_9_height_idx ON public.txs_9 USING btree (height);


CREATE INDEX txs_9_sender_idx ON public.txs_9 USING hash (sender);


CREATE index txs_9_id_tx_uid_idx ON public.txs_9 (id, tx_uid);


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
