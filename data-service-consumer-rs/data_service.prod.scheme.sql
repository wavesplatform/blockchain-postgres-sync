--
-- PostgreSQL database dump
--

-- Dumped from database version 13.3 (Ubuntu 13.3-1.pgdg20.04+1)
-- Dumped by pg_dump version 13.3 (Ubuntu 13.3-1.pgdg20.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gin; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gin WITH SCHEMA public;


--
-- Name: EXTENSION btree_gin; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION btree_gin IS 'support for indexing common datatypes in GIN';


--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: count_affected_rows(); Type: FUNCTION; Schema: public; Owner: dba
--

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

--
-- Name: find_missing_blocks(); Type: FUNCTION; Schema: public; Owner: dba
--

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

--
-- Name: get_address(character varying); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.get_address(_address_or_alias character varying) RETURNS character varying
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


ALTER FUNCTION public.get_address(_address_or_alias character varying) OWNER TO dba;

--
-- Name: get_alias(character varying); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.get_alias(_raw_alias character varying) RETURNS character varying
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


ALTER FUNCTION public.get_alias(_raw_alias character varying) OWNER TO dba;

--
-- Name: get_asset_id(text); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.get_asset_id(text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT COALESCE($1, 'WAVES');
$_$;


ALTER FUNCTION public.get_asset_id(text) OWNER TO dba;

--
-- Name: get_tuid_by_tx_height_and_position_in_block(integer, integer); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.get_tuid_by_tx_height_and_position_in_block(_height integer, _position_in_block integer) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	begin
		return _height::bigint * 100000::bigint + _position_in_block::bigint;
	end;
$$;


ALTER FUNCTION public.get_tuid_by_tx_height_and_position_in_block(_height integer, _position_in_block integer) OWNER TO dba;

--
-- Name: get_tuid_by_tx_id(character varying); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.get_tuid_by_tx_id(_tx_id character varying) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	declare
		tuid bigint;
	begin
		select uid from txs where id = _tx_id into tuid;
		return tuid;
	end;
$$;


ALTER FUNCTION public.get_tuid_by_tx_id(_tx_id character varying) OWNER TO dba;

--
-- Name: insert_all(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_all(b jsonb) RETURNS void
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


ALTER FUNCTION public.insert_all(b jsonb) OWNER TO dba;

--
-- Name: insert_block(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

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

--
-- Name: insert_txs_1(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_1(b jsonb) RETURNS void
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


ALTER FUNCTION public.insert_txs_1(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_10(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_10(b jsonb) RETURNS void
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


ALTER FUNCTION public.insert_txs_10(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_11(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_11(b jsonb) RETURNS void
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


ALTER FUNCTION public.insert_txs_11(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_12(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_12(b jsonb) RETURNS void
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


ALTER FUNCTION public.insert_txs_12(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_13(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_13(b jsonb) RETURNS void
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


ALTER FUNCTION public.insert_txs_13(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_14(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_14(b jsonb) RETURNS void
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


ALTER FUNCTION public.insert_txs_14(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_15(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_15(b jsonb) RETURNS void
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


ALTER FUNCTION public.insert_txs_15(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_16(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_16(b jsonb) RETURNS void
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
        fee_asset_id,
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
		coalesce(t->>'feeAssetId', 'WAVES'),
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


ALTER FUNCTION public.insert_txs_16(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_17(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_17(b jsonb) RETURNS void
    LANGUAGE plpgsql
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


ALTER FUNCTION public.insert_txs_17(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_2(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_2(b jsonb) RETURNS void
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


ALTER FUNCTION public.insert_txs_2(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_3(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_3(b jsonb) RETURNS void
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


ALTER FUNCTION public.insert_txs_3(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_4(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_4(b jsonb) RETURNS void
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


ALTER FUNCTION public.insert_txs_4(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_5(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_5(b jsonb) RETURNS void
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


ALTER FUNCTION public.insert_txs_5(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_6(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_6(b jsonb) RETURNS void
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


ALTER FUNCTION public.insert_txs_6(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_7(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_7(b jsonb) RETURNS void
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


ALTER FUNCTION public.insert_txs_7(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_8(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_8(b jsonb) RETURNS void
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


ALTER FUNCTION public.insert_txs_8(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_9(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_9(b jsonb) RETURNS void
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


ALTER FUNCTION public.insert_txs_9(b jsonb) OWNER TO dba;

--
-- Name: jsonb_array_cast_int(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.jsonb_array_cast_int(jsonb) RETURNS integer[]
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT array_agg(x)::int[] || ARRAY[]::int[] FROM jsonb_array_elements_text($1) t(x);
$_$;


ALTER FUNCTION public.jsonb_array_cast_int(jsonb) OWNER TO dba;

--
-- Name: jsonb_array_cast_text(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.jsonb_array_cast_text(jsonb) RETURNS text[]
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT array_agg(x) || ARRAY[]::text[] FROM jsonb_array_elements_text($1) t(x);
$_$;


ALTER FUNCTION public.jsonb_array_cast_text(jsonb) OWNER TO dba;

--
-- Name: on_block_insert(); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.on_block_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  	PERFORM insert_all (new.b);
	return new;
END
$$;


ALTER FUNCTION public.on_block_insert() OWNER TO dba;

--
-- Name: on_block_update(); Type: FUNCTION; Schema: public; Owner: dba
--

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

--
-- Name: reinsert_range(integer, integer); Type: FUNCTION; Schema: public; Owner: dba
--

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

--
-- Name: reinsert_range(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dba
--

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

--
-- Name: text_timestamp_cast(text); Type: FUNCTION; Schema: public; Owner: dba
--

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

SET default_table_access_method = heap;

--
-- Name: asset_origins; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.asset_origins (
    asset_id character varying NOT NULL,
    first_asset_update_uid bigint NOT NULL,
    origin_transaction_id character varying NOT NULL,
    issuer character varying NOT NULL,
    issue_height integer NOT NULL,
    issue_time_stamp timestamp with time zone NOT NULL
);


ALTER TABLE public.asset_origins OWNER TO dba;

--
-- Name: asset_updates; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.asset_updates (
    block_uid bigint NOT NULL,
    uid bigint NOT NULL,
    superseded_by bigint NOT NULL,
    asset_id character varying NOT NULL,
    decimals smallint NOT NULL,
    name character varying NOT NULL,
    description character varying NOT NULL,
    reissuable boolean NOT NULL,
    volume numeric NOT NULL,
    script character varying,
    sponsorship bigint,
    nft boolean NOT NULL
);


ALTER TABLE public.asset_updates OWNER TO dba;

--
-- Name: asset_updates_uid_seq; Type: SEQUENCE; Schema: public; Owner: dba
--

ALTER TABLE public.asset_updates ALTER COLUMN uid ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.asset_updates_uid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tickers; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.tickers (
    asset_id text NOT NULL,
    ticker text NOT NULL
);


ALTER TABLE public.tickers OWNER TO dba;

--
-- Name: waves_data; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.waves_data (
    height integer,
    quantity numeric NOT NULL
);


ALTER TABLE public.waves_data OWNER TO dba;

--
-- Name: assets; Type: VIEW; Schema: public; Owner: dba
--

CREATE VIEW public.assets AS
 SELECT au.asset_id,
    t.ticker,
    au.name AS asset_name,
    au.description,
    ao.issuer AS sender,
    ao.issue_height,
    ao.issue_time_stamp AS issue_timestamp,
    au.volume AS total_quantity,
    au.decimals,
    au.reissuable,
        CASE
            WHEN (au.script IS NOT NULL) THEN true
            ELSE false
        END AS has_script,
    au.sponsorship AS min_sponsored_asset_fee
   FROM ((public.asset_updates au
     LEFT JOIN ( SELECT tickers.asset_id,
            tickers.ticker
           FROM public.tickers) t ON (((au.asset_id)::text = t.asset_id)))
     LEFT JOIN public.asset_origins ao ON (((au.asset_id)::text = (ao.asset_id)::text)))
  WHERE (au.superseded_by = '9223372036854775806'::bigint)
UNION ALL
 SELECT 'WAVES'::character varying AS asset_id,
    'WAVES'::text AS ticker,
    'Waves'::character varying AS asset_name,
    ''::character varying AS description,
    ''::character varying AS sender,
    0 AS issue_height,
    '2016-04-11 21:00:00+00'::timestamp with time zone AS issue_timestamp,
    ((( SELECT waves_data.quantity
           FROM public.waves_data
          ORDER BY waves_data.height DESC NULLS LAST
         LIMIT 1))::bigint)::numeric AS total_quantity,
    8 AS decimals,
    false AS reissuable,
    false AS has_script,
    NULL::bigint AS min_sponsored_asset_fee;


ALTER TABLE public.assets OWNER TO dba;

--
-- Name: assets_metadata; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.assets_metadata (
    asset_id character varying,
    asset_name character varying,
    ticker character varying,
    height integer
);


ALTER TABLE public.assets_metadata OWNER TO dba;

--
-- Name: blocks; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.blocks (
    schema_version smallint NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    reference character varying NOT NULL,
    nxt_consensus_base_target bigint NOT NULL,
    nxt_consensus_generation_signature character varying NOT NULL,
    generator character varying NOT NULL,
    signature character varying NOT NULL,
    fee bigint NOT NULL,
    blocksize integer,
    height integer NOT NULL,
    features smallint[]
);


ALTER TABLE public.blocks OWNER TO dba;

--
-- Name: blocks_microblocks; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.blocks_microblocks (
    uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    time_stamp timestamp with time zone
);


ALTER TABLE public.blocks_microblocks OWNER TO dba;

--
-- Name: blocks_microblocks_uid_seq; Type: SEQUENCE; Schema: public; Owner: dba
--

ALTER TABLE public.blocks_microblocks ALTER COLUMN uid ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.blocks_microblocks_uid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: blocks_raw; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.blocks_raw (
    height integer NOT NULL,
    b jsonb NOT NULL
);


ALTER TABLE public.blocks_raw OWNER TO dba;

--
-- Name: candles; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.candles (
    time_start timestamp with time zone NOT NULL,
    amount_asset_id character varying NOT NULL,
    price_asset_id character varying NOT NULL,
    low numeric NOT NULL,
    high numeric NOT NULL,
    volume numeric NOT NULL,
    quote_volume numeric NOT NULL,
    max_height integer NOT NULL,
    txs_count integer NOT NULL,
    weighted_average_price numeric NOT NULL,
    open numeric NOT NULL,
    close numeric NOT NULL,
    "interval" character varying NOT NULL,
    matcher_address character varying NOT NULL
);


ALTER TABLE public.candles OWNER TO dba;

--
-- Name: pairs; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.pairs (
    amount_asset_id character varying NOT NULL,
    price_asset_id character varying NOT NULL,
    first_price numeric NOT NULL,
    last_price numeric NOT NULL,
    volume numeric NOT NULL,
    volume_waves numeric,
    quote_volume numeric NOT NULL,
    high numeric NOT NULL,
    low numeric NOT NULL,
    weighted_average_price numeric NOT NULL,
    txs_count integer NOT NULL,
    matcher_address character varying NOT NULL
);


ALTER TABLE public.pairs OWNER TO dba;

--
-- Name: txs; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs (
    uid bigint NOT NULL,
    tx_type smallint NOT NULL,
    sender character varying,
    sender_public_key character varying,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint NOT NULL,
    status character varying DEFAULT 'succeeded'::character varying NOT NULL
);


ALTER TABLE public.txs OWNER TO dba;

--
-- Name: txs_1; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_1 (
    recipient_address character varying NOT NULL,
    recipient_alias character varying,
    amount bigint NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_1 OWNER TO dba;

--
-- Name: txs_10; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_10 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    alias character varying NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_10 OWNER TO dba;

--
-- Name: txs_11; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_11 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    asset_id character varying NOT NULL,
    attachment character varying NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_11 OWNER TO dba;

--
-- Name: txs_11_transfers; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_11_transfers (
    tx_uid bigint NOT NULL,
    recipient_address character varying NOT NULL,
    recipient_alias character varying,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL
);


ALTER TABLE public.txs_11_transfers OWNER TO dba;

--
-- Name: txs_12; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_12 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_12 OWNER TO dba;

--
-- Name: txs_12_data; Type: TABLE; Schema: public; Owner: dba
--

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
);


ALTER TABLE public.txs_12_data OWNER TO dba;

--
-- Name: txs_13; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_13 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    script character varying
)
INHERITS (public.txs);


ALTER TABLE public.txs_13 OWNER TO dba;

--
-- Name: txs_14; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_14 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    asset_id character varying NOT NULL,
    min_sponsored_asset_fee bigint
)
INHERITS (public.txs);


ALTER TABLE public.txs_14 OWNER TO dba;

--
-- Name: txs_15; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_15 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    asset_id character varying NOT NULL,
    script character varying
)
INHERITS (public.txs);


ALTER TABLE public.txs_15 OWNER TO dba;

--
-- Name: txs_16; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_16 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    dapp_address character varying NOT NULL,
    dapp_alias character varying,
    function_name character varying,
    fee_asset_id character varying NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_16 OWNER TO dba;

--
-- Name: txs_16_args; Type: TABLE; Schema: public; Owner: dba
--

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
);


ALTER TABLE public.txs_16_args OWNER TO dba;

--
-- Name: txs_16_payment; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_16_payment (
    tx_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_payment smallint NOT NULL,
    height integer,
    asset_id character varying NOT NULL
);


ALTER TABLE public.txs_16_payment OWNER TO dba;

--
-- Name: txs_17; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_17 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    asset_id character varying NOT NULL,
    asset_name character varying NOT NULL,
    description character varying NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_17 OWNER TO dba;

--
-- Name: txs_2; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_2 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    recipient_address character varying NOT NULL,
    recipient_alias character varying,
    amount bigint NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_2 OWNER TO dba;

--
-- Name: txs_3; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_3 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    asset_id character varying NOT NULL,
    asset_name character varying NOT NULL,
    description character varying NOT NULL,
    quantity bigint NOT NULL,
    decimals smallint NOT NULL,
    reissuable boolean NOT NULL,
    script character varying
)
INHERITS (public.txs);


ALTER TABLE public.txs_3 OWNER TO dba;

--
-- Name: txs_4; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_4 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    asset_id character varying NOT NULL,
    amount bigint NOT NULL,
    recipient_address character varying NOT NULL,
    recipient_alias character varying,
    fee_asset_id character varying NOT NULL,
    attachment character varying NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_4 OWNER TO dba;

--
-- Name: txs_5; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_5 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    asset_id character varying NOT NULL,
    quantity bigint NOT NULL,
    reissuable boolean NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_5 OWNER TO dba;

--
-- Name: txs_6; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_6 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    asset_id character varying NOT NULL,
    amount bigint NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_6 OWNER TO dba;

--
-- Name: txs_7; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_7 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    order1 jsonb NOT NULL,
    order2 jsonb NOT NULL,
    amount bigint NOT NULL,
    price bigint NOT NULL,
    amount_asset_id character varying NOT NULL,
    price_asset_id character varying NOT NULL,
    buy_matcher_fee bigint NOT NULL,
    sell_matcher_fee bigint NOT NULL,
    fee_asset_id character varying NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_7 OWNER TO dba;

--
-- Name: txs_8; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_8 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    recipient_address character varying NOT NULL,
    recipient_alias character varying,
    amount bigint NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_8 OWNER TO dba;

--
-- Name: txs_9; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_9 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    lease_tx_uid bigint
)
INHERITS (public.txs);


ALTER TABLE public.txs_9 OWNER TO dba;

--
-- Name: txs_1 status; Type: DEFAULT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_1 ALTER COLUMN status SET DEFAULT 'succeeded'::character varying;


--
-- Name: txs_10 status; Type: DEFAULT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_10 ALTER COLUMN status SET DEFAULT 'succeeded'::character varying;


--
-- Name: txs_11 status; Type: DEFAULT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_11 ALTER COLUMN status SET DEFAULT 'succeeded'::character varying;


--
-- Name: txs_12 status; Type: DEFAULT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_12 ALTER COLUMN status SET DEFAULT 'succeeded'::character varying;


--
-- Name: txs_13 status; Type: DEFAULT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_13 ALTER COLUMN status SET DEFAULT 'succeeded'::character varying;


--
-- Name: txs_14 status; Type: DEFAULT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_14 ALTER COLUMN status SET DEFAULT 'succeeded'::character varying;


--
-- Name: txs_15 status; Type: DEFAULT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_15 ALTER COLUMN status SET DEFAULT 'succeeded'::character varying;


--
-- Name: txs_16 status; Type: DEFAULT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_16 ALTER COLUMN status SET DEFAULT 'succeeded'::character varying;


--
-- Name: txs_17 status; Type: DEFAULT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_17 ALTER COLUMN status SET DEFAULT 'succeeded'::character varying;


--
-- Name: txs_2 status; Type: DEFAULT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_2 ALTER COLUMN status SET DEFAULT 'succeeded'::character varying;


--
-- Name: txs_3 status; Type: DEFAULT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_3 ALTER COLUMN status SET DEFAULT 'succeeded'::character varying;


--
-- Name: txs_4 status; Type: DEFAULT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_4 ALTER COLUMN status SET DEFAULT 'succeeded'::character varying;


--
-- Name: txs_5 status; Type: DEFAULT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_5 ALTER COLUMN status SET DEFAULT 'succeeded'::character varying;


--
-- Name: txs_6 status; Type: DEFAULT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_6 ALTER COLUMN status SET DEFAULT 'succeeded'::character varying;


--
-- Name: txs_7 status; Type: DEFAULT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_7 ALTER COLUMN status SET DEFAULT 'succeeded'::character varying;


--
-- Name: txs_8 status; Type: DEFAULT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_8 ALTER COLUMN status SET DEFAULT 'succeeded'::character varying;


--
-- Name: txs_9 status; Type: DEFAULT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_9 ALTER COLUMN status SET DEFAULT 'succeeded'::character varying;


--
-- Name: asset_origins asset_origins_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.asset_origins
    ADD CONSTRAINT asset_origins_pkey PRIMARY KEY (asset_id);


--
-- Name: asset_updates asset_updates_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.asset_updates
    ADD CONSTRAINT asset_updates_pkey PRIMARY KEY (superseded_by, asset_id);


--
-- Name: asset_updates asset_updates_uid_key; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.asset_updates
    ADD CONSTRAINT asset_updates_uid_key UNIQUE (uid);


--
-- Name: blocks_microblocks blocks_microblocks_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.blocks_microblocks
    ADD CONSTRAINT blocks_microblocks_pkey PRIMARY KEY (id);


--
-- Name: blocks_microblocks blocks_microblocks_uid_key; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.blocks_microblocks
    ADD CONSTRAINT blocks_microblocks_uid_key UNIQUE (uid);


--
-- Name: blocks blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_pkey PRIMARY KEY (height);


--
-- Name: blocks_raw blocks_raw_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.blocks_raw
    ADD CONSTRAINT blocks_raw_pkey PRIMARY KEY (height);


--
-- Name: candles candles_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.candles
    ADD CONSTRAINT candles_pkey PRIMARY KEY ("interval", time_start, amount_asset_id, price_asset_id, matcher_address);


--
-- Name: pairs pairs_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.pairs
    ADD CONSTRAINT pairs_pk PRIMARY KEY (amount_asset_id, price_asset_id, matcher_address);


--
-- Name: tickers tickers_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.tickers
    ADD CONSTRAINT tickers_pkey PRIMARY KEY (asset_id);


--
-- Name: txs_10 txs_10_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_10
    ADD CONSTRAINT txs_10_pk PRIMARY KEY (uid);


--
-- Name: txs_11 txs_11_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_11
    ADD CONSTRAINT txs_11_pk PRIMARY KEY (uid);


--
-- Name: txs_11_transfers txs_11_transfers_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_11_transfers
    ADD CONSTRAINT txs_11_transfers_pkey PRIMARY KEY (tx_uid, position_in_tx);


--
-- Name: txs_12_data txs_12_data_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_12_data
    ADD CONSTRAINT txs_12_data_pkey PRIMARY KEY (tx_uid, position_in_tx);


--
-- Name: txs_12 txs_12_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_12
    ADD CONSTRAINT txs_12_pk PRIMARY KEY (uid);


--
-- Name: txs_13 txs_13_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_13
    ADD CONSTRAINT txs_13_pk PRIMARY KEY (uid);


--
-- Name: txs_14 txs_14_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_14
    ADD CONSTRAINT txs_14_pk PRIMARY KEY (uid);


--
-- Name: txs_15 txs_15_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_15
    ADD CONSTRAINT txs_15_pk PRIMARY KEY (uid);


--
-- Name: txs_16_args txs_16_args_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_16_args
    ADD CONSTRAINT txs_16_args_pk PRIMARY KEY (tx_uid, position_in_args);


--
-- Name: txs_16_payment txs_16_payment_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_16_payment
    ADD CONSTRAINT txs_16_payment_pk PRIMARY KEY (tx_uid, position_in_payment);


--
-- Name: txs_16 txs_16_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_16
    ADD CONSTRAINT txs_16_pk PRIMARY KEY (uid);


--
-- Name: txs_17 txs_17_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_17
    ADD CONSTRAINT txs_17_pk PRIMARY KEY (uid);


--
-- Name: txs_1 txs_1_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_1
    ADD CONSTRAINT txs_1_pk PRIMARY KEY (uid);


--
-- Name: txs_2 txs_2_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_2
    ADD CONSTRAINT txs_2_pk PRIMARY KEY (uid);


--
-- Name: txs_3 txs_3_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_3
    ADD CONSTRAINT txs_3_pk PRIMARY KEY (uid);


--
-- Name: txs_4 txs_4_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_4
    ADD CONSTRAINT txs_4_pk PRIMARY KEY (uid);


--
-- Name: txs_5 txs_5_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_5
    ADD CONSTRAINT txs_5_pk PRIMARY KEY (uid);


--
-- Name: txs_6 txs_6_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_6
    ADD CONSTRAINT txs_6_pk PRIMARY KEY (uid);


--
-- Name: txs_7 txs_7_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_7
    ADD CONSTRAINT txs_7_pk PRIMARY KEY (uid);


--
-- Name: txs_8 txs_8_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_8
    ADD CONSTRAINT txs_8_pk PRIMARY KEY (uid);


--
-- Name: txs_9 txs_9_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_9
    ADD CONSTRAINT txs_9_pk PRIMARY KEY (uid);


--
-- Name: txs_9 txs_9_un; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_9
    ADD CONSTRAINT txs_9_un UNIQUE (uid, lease_tx_uid);


--
-- Name: txs txs_pk; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs
    ADD CONSTRAINT txs_pk PRIMARY KEY (uid, id, time_stamp);


--
-- Name: waves_data waves_data_un; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.waves_data
    ADD CONSTRAINT waves_data_un UNIQUE (height);


--
-- Name: asset_updates_block_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX asset_updates_block_uid_idx ON public.asset_updates USING btree (block_uid);


--
-- Name: asset_updates_to_tsvector_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX asset_updates_to_tsvector_idx ON public.asset_updates USING gin (to_tsvector('simple'::regconfig, (name)::text)) WHERE (superseded_by = '9223372036854775806'::bigint);


--
-- Name: blocks_microblocks_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX blocks_microblocks_id_idx ON public.blocks_microblocks USING btree (id);


--
-- Name: blocks_microblocks_time_stamp_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX blocks_microblocks_time_stamp_uid_idx ON public.blocks_microblocks USING btree (time_stamp DESC, uid DESC);


--
-- Name: blocks_time_stamp_height_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX blocks_time_stamp_height_gist_idx ON public.blocks USING gist (time_stamp, height);


--
-- Name: candles_amount_price_ids_matcher_time_start_partial_1m_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX candles_amount_price_ids_matcher_time_start_partial_1m_idx ON public.candles USING btree (amount_asset_id, price_asset_id, matcher_address, time_start) WHERE (("interval")::text = '1m'::text);


--
-- Name: candles_assets_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX candles_assets_id_idx ON public.candles USING btree (amount_asset_id, price_asset_id) WHERE ((("interval")::text = '1d'::text) AND ((matcher_address)::text = '3PEjHv3JGjcWNpYEEkif2w8NXV4kbhnoGgu'::text));


--
-- Name: candles_max_height_index; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX candles_max_height_index ON public.candles USING btree (max_height);


--
-- Name: tickers_ticker_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX tickers_ticker_idx ON public.tickers USING btree (ticker);


--
-- Name: txs_10_alias_sender_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_10_alias_sender_idx ON public.txs_10 USING btree (alias, sender);


--
-- Name: txs_10_alias_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_10_alias_uid_idx ON public.txs_10 USING btree (alias, uid);


--
-- Name: txs_10_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_10_height_idx ON public.txs_10 USING btree (height);


--
-- Name: txs_10_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_10_id_idx ON public.txs_10 USING hash (id);


--
-- Name: txs_10_sender_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_10_sender_uid_idx ON public.txs_10 USING btree (sender, uid);


--
-- Name: txs_10_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_10_time_stamp_uid_gist_idx ON public.txs_10 USING gist (time_stamp, uid);


--
-- Name: txs_10_uid_time_stamp_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_10_uid_time_stamp_unique_idx ON public.txs_10 USING btree (uid, time_stamp);


--
-- Name: txs_11_asset_id_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_11_asset_id_uid_idx ON public.txs_11 USING btree (asset_id, uid);


--
-- Name: txs_11_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_11_height_idx ON public.txs_11 USING btree (height);


--
-- Name: txs_11_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_11_id_idx ON public.txs_11 USING hash (id);


--
-- Name: txs_11_sender_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_11_sender_uid_idx ON public.txs_11 USING btree (sender, uid);


--
-- Name: txs_11_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_11_time_stamp_uid_gist_idx ON public.txs_11 USING gist (time_stamp, uid);


--
-- Name: txs_11_transfers_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_11_transfers_height_idx ON public.txs_11_transfers USING btree (height);


--
-- Name: txs_11_transfers_recipient_address_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_11_transfers_recipient_address_idx ON public.txs_11_transfers USING btree (recipient_address);


--
-- Name: txs_11_uid_time_stamp_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_11_uid_time_stamp_unique_idx ON public.txs_11 USING btree (uid, time_stamp);


--
-- Name: txs_12_data_data_key_tx_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_data_data_key_tx_uid_idx ON public.txs_12_data USING btree (data_key, tx_uid);


--
-- Name: txs_12_data_data_type_tx_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_data_data_type_tx_uid_idx ON public.txs_12_data USING btree (data_type, tx_uid);


--
-- Name: txs_12_data_data_value_binary_tx_uid_partial_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_data_data_value_binary_tx_uid_partial_idx ON public.txs_12_data USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


--
-- Name: txs_12_data_data_value_boolean_tx_uid_partial_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_data_data_value_boolean_tx_uid_partial_idx ON public.txs_12_data USING btree (data_value_boolean, tx_uid) WHERE (data_type = 'boolean'::text);


--
-- Name: txs_12_data_data_value_integer_tx_uid_partial_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_data_data_value_integer_tx_uid_partial_idx ON public.txs_12_data USING btree (data_value_integer, tx_uid) WHERE (data_type = 'integer'::text);


--
-- Name: txs_12_data_data_value_string_tx_uid_partial_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_data_data_value_string_tx_uid_partial_idx ON public.txs_12_data USING hash (data_value_string) WHERE (data_type = 'string'::text);


--
-- Name: txs_12_data_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_data_height_idx ON public.txs_12_data USING btree (height);


--
-- Name: txs_12_data_tx_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_data_tx_uid_idx ON public.txs_12_data USING btree (tx_uid);


--
-- Name: txs_12_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_height_idx ON public.txs_12 USING btree (height);


--
-- Name: txs_12_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_id_idx ON public.txs_12 USING hash (id);


--
-- Name: txs_12_sender_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_sender_uid_idx ON public.txs_12 USING btree (sender, uid);


--
-- Name: txs_12_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_time_stamp_uid_gist_idx ON public.txs_12 USING gist (time_stamp, uid);


--
-- Name: txs_12_uid_time_stamp_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_12_uid_time_stamp_unique_idx ON public.txs_12 USING btree (uid, time_stamp);


--
-- Name: txs_13_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_13_height_idx ON public.txs_13 USING btree (height);


--
-- Name: txs_13_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_13_id_idx ON public.txs_13 USING hash (id);


--
-- Name: txs_13_md5_script_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_13_md5_script_idx ON public.txs_13 USING btree (md5((script)::text));


--
-- Name: txs_13_sender_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_13_sender_uid_idx ON public.txs_13 USING btree (sender, uid);


--
-- Name: txs_13_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_13_time_stamp_uid_gist_idx ON public.txs_13 USING gist (time_stamp, uid);


--
-- Name: txs_13_uid_time_stamp_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_13_uid_time_stamp_unique_idx ON public.txs_13 USING btree (uid, time_stamp);


--
-- Name: txs_14_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_14_height_idx ON public.txs_14 USING btree (height);


--
-- Name: txs_14_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_14_id_idx ON public.txs_14 USING hash (id);


--
-- Name: txs_14_sender_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_14_sender_uid_idx ON public.txs_14 USING btree (sender, uid);


--
-- Name: txs_14_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_14_time_stamp_uid_gist_idx ON public.txs_14 USING gist (time_stamp, uid);


--
-- Name: txs_14_uid_time_stamp_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_14_uid_time_stamp_unique_idx ON public.txs_14 USING btree (uid, time_stamp);


--
-- Name: txs_15_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_15_height_idx ON public.txs_15 USING btree (height);


--
-- Name: txs_15_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_15_id_idx ON public.txs_15 USING hash (id);


--
-- Name: txs_15_md5_script_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_15_md5_script_idx ON public.txs_15 USING btree (md5((script)::text));


--
-- Name: txs_15_sender_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_15_sender_uid_idx ON public.txs_15 USING btree (sender, uid);


--
-- Name: txs_15_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_15_time_stamp_uid_gist_idx ON public.txs_15 USING gist (time_stamp, uid);


--
-- Name: txs_15_uid_time_stamp_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_15_uid_time_stamp_unique_idx ON public.txs_15 USING btree (uid, time_stamp);


--
-- Name: txs_16_args_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_16_args_height_idx ON public.txs_16_args USING btree (height);


--
-- Name: txs_16_dapp_address_function_name_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_16_dapp_address_function_name_uid_idx ON public.txs_16 USING btree (dapp_address, function_name, uid);


--
-- Name: txs_16_dapp_address_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_16_dapp_address_uid_idx ON public.txs_16 USING btree (dapp_address, uid);


--
-- Name: txs_16_function_name_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_16_function_name_uid_idx ON public.txs_16 USING btree (function_name, uid);


--
-- Name: txs_16_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_16_height_idx ON public.txs_16 USING btree (height);


--
-- Name: txs_16_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_16_id_idx ON public.txs_16 USING hash (id);


--
-- Name: txs_16_payment_asset_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_16_payment_asset_id_idx ON public.txs_16_payment USING btree (asset_id);


--
-- Name: txs_16_payment_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_16_payment_height_idx ON public.txs_16_payment USING btree (height);


--
-- Name: txs_16_sender_function_name_uid_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_16_sender_function_name_uid_unique_idx ON public.txs_16 USING btree (sender, function_name, uid);


--
-- Name: txs_16_sender_time_stamp_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_16_sender_time_stamp_uid_idx ON public.txs_16 USING btree (sender, time_stamp, uid);


--
-- Name: txs_16_sender_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_16_sender_uid_idx ON public.txs_16 USING btree (sender, uid);


--
-- Name: txs_16_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_16_time_stamp_uid_gist_idx ON public.txs_16 USING gist (time_stamp, uid);


--
-- Name: txs_16_uid_time_stamp_sender_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_16_uid_time_stamp_sender_unique_idx ON public.txs_16 USING btree (uid, time_stamp, sender);


--
-- Name: txs_17_asset_id_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_17_asset_id_uid_idx ON public.txs_17 USING btree (asset_id, uid);


--
-- Name: txs_17_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_17_height_idx ON public.txs_17 USING btree (height);


--
-- Name: txs_17_sender_time_stamp_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_17_sender_time_stamp_id_idx ON public.txs_17 USING btree (sender, time_stamp, uid);


--
-- Name: txs_17_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_17_time_stamp_uid_gist_idx ON public.txs_17 USING gist (time_stamp, uid);


--
-- Name: txs_17_uid_time_stamp_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_17_uid_time_stamp_unique_idx ON public.txs_17 USING btree (uid, time_stamp);


--
-- Name: txs_1_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_1_height_idx ON public.txs_1 USING btree (height);


--
-- Name: txs_1_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_1_id_idx ON public.txs_1 USING hash (id);


--
-- Name: txs_1_sender_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_1_sender_uid_idx ON public.txs_1 USING btree (sender, uid);


--
-- Name: txs_1_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_1_time_stamp_uid_gist_idx ON public.txs_1 USING gist (time_stamp, uid);


--
-- Name: txs_1_uid_time_stamp_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_1_uid_time_stamp_unique_idx ON public.txs_1 USING btree (uid, time_stamp);


--
-- Name: txs_2_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_2_height_idx ON public.txs_2 USING btree (height);


--
-- Name: txs_2_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_2_id_idx ON public.txs_2 USING hash (id);


--
-- Name: txs_2_sender_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_2_sender_uid_idx ON public.txs_2 USING btree (sender, uid);


--
-- Name: txs_2_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_2_time_stamp_uid_gist_idx ON public.txs_2 USING gist (time_stamp, uid);


--
-- Name: txs_2_uid_time_stamp_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_2_uid_time_stamp_unique_idx ON public.txs_2 USING btree (uid, time_stamp);


--
-- Name: txs_3_asset_id_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_3_asset_id_uid_idx ON public.txs_3 USING btree (asset_id, uid);


--
-- Name: txs_3_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_3_height_idx ON public.txs_3 USING btree (height);


--
-- Name: txs_3_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_3_id_idx ON public.txs_3 USING hash (id);


--
-- Name: txs_3_md5_script_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_3_md5_script_idx ON public.txs_3 USING btree (md5((script)::text));


--
-- Name: txs_3_sender_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_3_sender_uid_idx ON public.txs_3 USING btree (sender, uid);


--
-- Name: txs_3_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_3_time_stamp_uid_gist_idx ON public.txs_3 USING gist (time_stamp, uid);


--
-- Name: txs_3_uid_time_stamp_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_3_uid_time_stamp_unique_idx ON public.txs_3 USING btree (uid, time_stamp);


--
-- Name: txs_4_asset_id_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_4_asset_id_uid_idx ON public.txs_4 USING btree (asset_id, uid);


--
-- Name: txs_4_height_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_4_height_uid_idx ON public.txs_4 USING btree (height, uid);


--
-- Name: txs_4_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_4_id_idx ON public.txs_4 USING hash (id);


--
-- Name: txs_4_recipient_address_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_4_recipient_address_uid_idx ON public.txs_4 USING btree (recipient_address, uid);


--
-- Name: txs_4_sender_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_4_sender_uid_idx ON public.txs_4 USING btree (sender, uid);


--
-- Name: txs_4_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_4_time_stamp_uid_gist_idx ON public.txs_4 USING gist (time_stamp, uid);


--
-- Name: txs_4_uid_time_stamp_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_4_uid_time_stamp_unique_idx ON public.txs_4 USING btree (uid, time_stamp);


--
-- Name: txs_5_asset_id_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_5_asset_id_uid_idx ON public.txs_5 USING btree (asset_id, uid);


--
-- Name: txs_5_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_5_height_idx ON public.txs_5 USING btree (height);


--
-- Name: txs_5_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_5_id_idx ON public.txs_5 USING hash (id);


--
-- Name: txs_5_sender_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_5_sender_uid_idx ON public.txs_5 USING btree (sender, uid);


--
-- Name: txs_5_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_5_time_stamp_uid_gist_idx ON public.txs_5 USING gist (time_stamp, uid);


--
-- Name: txs_5_uid_time_stamp_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_5_uid_time_stamp_unique_idx ON public.txs_5 USING btree (uid, time_stamp);


--
-- Name: txs_6_asset_id_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_6_asset_id_uid_idx ON public.txs_6 USING btree (asset_id, uid);


--
-- Name: txs_6_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_6_height_idx ON public.txs_6 USING btree (height);


--
-- Name: txs_6_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_6_id_idx ON public.txs_6 USING hash (id);


--
-- Name: txs_6_sender_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_6_sender_uid_idx ON public.txs_6 USING btree (sender, uid);


--
-- Name: txs_6_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_6_time_stamp_uid_gist_idx ON public.txs_6 USING gist (time_stamp, uid);


--
-- Name: txs_6_uid_time_stamp_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_6_uid_time_stamp_unique_idx ON public.txs_6 USING btree (uid, time_stamp);


--
-- Name: txs_7_amount_asset_id_price_asset_id_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_amount_asset_id_price_asset_id_uid_idx ON public.txs_7 USING btree (amount_asset_id, price_asset_id, uid);


--
-- Name: txs_7_amount_asset_id_price_asset_id_uid_partial_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_amount_asset_id_price_asset_id_uid_partial_idx ON public.txs_7 USING btree (amount_asset_id, price_asset_id, uid) WHERE ((sender)::text = '3PJaDyprvekvPXPuAtxrapacuDJopgJRaU3'::text);


--
-- Name: txs_7_amount_asset_id_price_asset_id_uid_partial_new_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_amount_asset_id_price_asset_id_uid_partial_new_idx ON public.txs_7 USING btree (amount_asset_id, price_asset_id, uid) WHERE ((sender)::text = '3PEjHv3JGjcWNpYEEkif2w8NXV4kbhnoGgu'::text);


--
-- Name: txs_7_amount_asset_id_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_amount_asset_id_uid_idx ON public.txs_7 USING btree (amount_asset_id, uid);


--
-- Name: txs_7_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_height_idx ON public.txs_7 USING btree (height);


--
-- Name: txs_7_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_id_idx ON public.txs_7 USING hash (id);


--
-- Name: txs_7_order_ids_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_order_ids_uid_idx ON public.txs_7 USING gin ((ARRAY[(order1 ->> 'id'::text), (order2 ->> 'id'::text)]), uid);


--
-- Name: txs_7_order_sender_1_amount_asset_price_asset_uid_desc_part_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_order_sender_1_amount_asset_price_asset_uid_desc_part_idx ON public.txs_7 USING btree (((order1 ->> 'sender'::text)), amount_asset_id, price_asset_id, uid DESC) WHERE ((sender)::text = '3PEjHv3JGjcWNpYEEkif2w8NXV4kbhnoGgu'::text);


--
-- Name: txs_7_order_sender_1_uid_desc_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_order_sender_1_uid_desc_idx ON public.txs_7 USING btree (((order1 ->> 'sender'::text)), uid DESC);


--
-- Name: txs_7_order_sender_2_amount_asset_price_asset_uid_desc_part_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_order_sender_2_amount_asset_price_asset_uid_desc_part_idx ON public.txs_7 USING btree (((order2 ->> 'sender'::text)), amount_asset_id, price_asset_id, uid DESC) WHERE ((sender)::text = '3PEjHv3JGjcWNpYEEkif2w8NXV4kbhnoGgu'::text);


--
-- Name: txs_7_order_sender_2_uid_desc_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_order_sender_2_uid_desc_idx ON public.txs_7 USING btree (((order2 ->> 'sender'::text)), uid DESC);


--
-- Name: txs_7_order_senders_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_order_senders_uid_idx ON public.txs_7 USING gin ((ARRAY[(order1 ->> 'sender'::text), (order2 ->> 'sender'::text)]), uid);


--
-- Name: txs_7_price_asset_id_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_price_asset_id_uid_idx ON public.txs_7 USING btree (price_asset_id, uid);


--
-- Name: txs_7_sender_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_sender_uid_idx ON public.txs_7 USING btree (sender, uid);


--
-- Name: txs_7_time_stamp_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_time_stamp_gist_idx ON public.txs_7 USING gist (time_stamp);


--
-- Name: txs_7_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_time_stamp_uid_gist_idx ON public.txs_7 USING gist (time_stamp, uid);


--
-- Name: txs_7_uid_height_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_uid_height_time_stamp_idx ON public.txs_7 USING btree (uid, height, time_stamp);


--
-- Name: txs_7_uid_time_stamp_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_7_uid_time_stamp_unique_idx ON public.txs_7 USING btree (uid, time_stamp);


--
-- Name: txs_8_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_8_height_idx ON public.txs_8 USING btree (height);


--
-- Name: txs_8_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_8_id_idx ON public.txs_8 USING hash (id);


--
-- Name: txs_8_recipient_address_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_8_recipient_address_uid_idx ON public.txs_8 USING btree (recipient_address, uid);


--
-- Name: txs_8_recipient_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_8_recipient_idx ON public.txs_8 USING btree (recipient_address);


--
-- Name: txs_8_sender_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_8_sender_uid_idx ON public.txs_8 USING btree (sender, uid);


--
-- Name: txs_8_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_8_time_stamp_uid_gist_idx ON public.txs_8 USING gist (time_stamp, uid);


--
-- Name: txs_8_uid_time_stamp_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_8_uid_time_stamp_unique_idx ON public.txs_8 USING btree (uid, time_stamp);


--
-- Name: txs_9_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_9_height_idx ON public.txs_9 USING btree (height);


--
-- Name: txs_9_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_9_id_idx ON public.txs_9 USING hash (id);


--
-- Name: txs_9_sender_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_9_sender_uid_idx ON public.txs_9 USING btree (sender, uid);


--
-- Name: txs_9_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_9_time_stamp_uid_gist_idx ON public.txs_9 USING gist (time_stamp, uid);


--
-- Name: txs_9_uid_time_stamp_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_9_uid_time_stamp_unique_idx ON public.txs_9 USING btree (uid, time_stamp);


--
-- Name: txs_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_height_idx ON public.txs USING btree (height);


--
-- Name: txs_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_id_idx ON public.txs USING hash (id);


--
-- Name: txs_sender_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_sender_uid_idx ON public.txs USING btree (sender, uid);


--
-- Name: txs_time_stamp_uid_gist_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_time_stamp_uid_gist_idx ON public.txs USING gist (time_stamp, uid);


--
-- Name: txs_time_stamp_uid_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_time_stamp_uid_idx ON public.txs USING btree (time_stamp, uid);


--
-- Name: txs_tx_type_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_tx_type_idx ON public.txs USING btree (tx_type);


--
-- Name: txs_uid_time_stamp_unique_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE UNIQUE INDEX txs_uid_time_stamp_unique_idx ON public.txs USING btree (uid, time_stamp);


--
-- Name: waves_data_height_desc_quantity_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX waves_data_height_desc_quantity_idx ON public.waves_data USING btree (height DESC NULLS LAST, quantity);


--
-- Name: blocks_raw block_delete; Type: RULE; Schema: public; Owner: dba
--

CREATE RULE block_delete AS
    ON DELETE TO public.blocks_raw DO  DELETE FROM public.blocks
  WHERE (blocks.height = old.height);


--
-- Name: blocks_raw block_insert_trigger; Type: TRIGGER; Schema: public; Owner: dba
--

CREATE TRIGGER block_insert_trigger BEFORE INSERT ON public.blocks_raw FOR EACH ROW EXECUTE FUNCTION public.on_block_insert();


--
-- Name: blocks_raw block_update_trigger; Type: TRIGGER; Schema: public; Owner: dba
--

CREATE TRIGGER block_update_trigger BEFORE UPDATE ON public.blocks_raw FOR EACH ROW EXECUTE FUNCTION public.on_block_update();


--
-- Name: asset_origins asset_origins_first_asset_update_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.asset_origins
    ADD CONSTRAINT asset_origins_first_asset_update_uid_fkey FOREIGN KEY (first_asset_update_uid) REFERENCES public.asset_updates(uid) ON DELETE CASCADE;


--
-- Name: asset_updates asset_updates_block_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.asset_updates
    ADD CONSTRAINT asset_updates_block_uid_fkey FOREIGN KEY (block_uid) REFERENCES public.blocks_microblocks(uid) ON DELETE CASCADE;


--
-- Name: txs_1 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_1
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_2 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_2
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_3 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_3
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_4 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_4
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_5 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_5
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_6 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_6
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_7 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_7
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_8 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_8
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_9 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_9
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_10 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_10
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_11 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_11
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_11_transfers fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_11_transfers
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_12 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_12
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_12_data fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_12_data
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_13 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_13
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_14 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_14
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_15 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_15
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_16 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_16
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_16_args fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_16_args
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_16_payment fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_16_payment
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_17 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_17
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: waves_data fk_waves_data; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.waves_data
    ADD CONSTRAINT fk_waves_data FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA public TO skutsenko;


--
-- Name: TABLE asset_origins; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.asset_origins TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.asset_origins TO writer;
GRANT SELECT ON TABLE public.asset_origins TO apetrov;
GRANT SELECT ON TABLE public.asset_origins TO skutsenko;


--
-- Name: TABLE asset_updates; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.asset_updates TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.asset_updates TO writer;
GRANT SELECT ON TABLE public.asset_updates TO apetrov;
GRANT SELECT ON TABLE public.asset_updates TO skutsenko;


--
-- Name: SEQUENCE asset_updates_uid_seq; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON SEQUENCE public.asset_updates_uid_seq TO reader;
GRANT SELECT,UPDATE ON SEQUENCE public.asset_updates_uid_seq TO writer;
GRANT SELECT ON SEQUENCE public.asset_updates_uid_seq TO skutsenko;


--
-- Name: TABLE tickers; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.tickers TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.tickers TO writer;
GRANT SELECT ON TABLE public.tickers TO apetrov;
GRANT SELECT ON TABLE public.tickers TO skutsenko;


--
-- Name: TABLE waves_data; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.waves_data TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.waves_data TO writer;
GRANT SELECT ON TABLE public.waves_data TO apetrov;
GRANT SELECT ON TABLE public.waves_data TO skutsenko;


--
-- Name: TABLE assets; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.assets TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.assets TO writer;
GRANT SELECT ON TABLE public.assets TO apetrov;
GRANT SELECT ON TABLE public.assets TO skutsenko;


--
-- Name: TABLE assets_metadata; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.assets_metadata TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.assets_metadata TO writer;
GRANT SELECT ON TABLE public.assets_metadata TO apetrov;
GRANT SELECT ON TABLE public.assets_metadata TO skutsenko;


--
-- Name: TABLE blocks; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.blocks TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.blocks TO writer;
GRANT SELECT ON TABLE public.blocks TO apetrov;
GRANT SELECT ON TABLE public.blocks TO skutsenko;


--
-- Name: TABLE blocks_microblocks; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.blocks_microblocks TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.blocks_microblocks TO writer;
GRANT SELECT ON TABLE public.blocks_microblocks TO apetrov;
GRANT SELECT ON TABLE public.blocks_microblocks TO skutsenko;


--
-- Name: SEQUENCE blocks_microblocks_uid_seq; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON SEQUENCE public.blocks_microblocks_uid_seq TO reader;
GRANT SELECT,UPDATE ON SEQUENCE public.blocks_microblocks_uid_seq TO writer;
GRANT SELECT ON SEQUENCE public.blocks_microblocks_uid_seq TO skutsenko;


--
-- Name: TABLE blocks_raw; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.blocks_raw TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.blocks_raw TO writer;
GRANT SELECT ON TABLE public.blocks_raw TO apetrov;
GRANT SELECT ON TABLE public.blocks_raw TO skutsenko;


--
-- Name: TABLE candles; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.candles TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.candles TO writer;
GRANT SELECT ON TABLE public.candles TO apetrov;
GRANT SELECT ON TABLE public.candles TO skutsenko;


--
-- Name: TABLE pairs; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.pairs TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.pairs TO writer;
GRANT SELECT ON TABLE public.pairs TO apetrov;
GRANT SELECT ON TABLE public.pairs TO skutsenko;


--
-- Name: TABLE txs; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs TO writer;
GRANT SELECT ON TABLE public.txs TO apetrov;
GRANT SELECT ON TABLE public.txs TO skutsenko;


--
-- Name: TABLE txs_1; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_1 TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_1 TO writer;
GRANT SELECT ON TABLE public.txs_1 TO apetrov;
GRANT SELECT ON TABLE public.txs_1 TO skutsenko;


--
-- Name: TABLE txs_10; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_10 TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_10 TO writer;
GRANT SELECT ON TABLE public.txs_10 TO apetrov;
GRANT SELECT ON TABLE public.txs_10 TO skutsenko;


--
-- Name: TABLE txs_11; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_11 TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_11 TO writer;
GRANT SELECT ON TABLE public.txs_11 TO apetrov;
GRANT SELECT ON TABLE public.txs_11 TO skutsenko;


--
-- Name: TABLE txs_11_transfers; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_11_transfers TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_11_transfers TO writer;
GRANT SELECT ON TABLE public.txs_11_transfers TO apetrov;
GRANT SELECT ON TABLE public.txs_11_transfers TO skutsenko;


--
-- Name: TABLE txs_12; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_12 TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_12 TO writer;
GRANT SELECT ON TABLE public.txs_12 TO apetrov;
GRANT SELECT ON TABLE public.txs_12 TO skutsenko;


--
-- Name: TABLE txs_12_data; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_12_data TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_12_data TO writer;
GRANT SELECT ON TABLE public.txs_12_data TO apetrov;
GRANT SELECT ON TABLE public.txs_12_data TO skutsenko;


--
-- Name: TABLE txs_13; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_13 TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_13 TO writer;
GRANT SELECT ON TABLE public.txs_13 TO apetrov;
GRANT SELECT ON TABLE public.txs_13 TO skutsenko;


--
-- Name: TABLE txs_14; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_14 TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_14 TO writer;
GRANT SELECT ON TABLE public.txs_14 TO apetrov;
GRANT SELECT ON TABLE public.txs_14 TO skutsenko;


--
-- Name: TABLE txs_15; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_15 TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_15 TO writer;
GRANT SELECT ON TABLE public.txs_15 TO apetrov;
GRANT SELECT ON TABLE public.txs_15 TO skutsenko;


--
-- Name: TABLE txs_16; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_16 TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_16 TO writer;
GRANT SELECT ON TABLE public.txs_16 TO apetrov;
GRANT SELECT ON TABLE public.txs_16 TO skutsenko;


--
-- Name: TABLE txs_16_args; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_16_args TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_16_args TO writer;
GRANT SELECT ON TABLE public.txs_16_args TO apetrov;
GRANT SELECT ON TABLE public.txs_16_args TO skutsenko;


--
-- Name: TABLE txs_16_payment; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_16_payment TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_16_payment TO writer;
GRANT SELECT ON TABLE public.txs_16_payment TO apetrov;
GRANT SELECT ON TABLE public.txs_16_payment TO skutsenko;


--
-- Name: TABLE txs_17; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_17 TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_17 TO writer;
GRANT SELECT ON TABLE public.txs_17 TO apetrov;
GRANT SELECT ON TABLE public.txs_17 TO skutsenko;


--
-- Name: TABLE txs_2; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_2 TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_2 TO writer;
GRANT SELECT ON TABLE public.txs_2 TO apetrov;
GRANT SELECT ON TABLE public.txs_2 TO skutsenko;


--
-- Name: TABLE txs_3; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_3 TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_3 TO writer;
GRANT SELECT ON TABLE public.txs_3 TO apetrov;
GRANT SELECT ON TABLE public.txs_3 TO skutsenko;


--
-- Name: TABLE txs_4; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_4 TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_4 TO writer;
GRANT SELECT ON TABLE public.txs_4 TO apetrov;
GRANT SELECT ON TABLE public.txs_4 TO skutsenko;


--
-- Name: TABLE txs_5; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_5 TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_5 TO writer;
GRANT SELECT ON TABLE public.txs_5 TO apetrov;
GRANT SELECT ON TABLE public.txs_5 TO skutsenko;


--
-- Name: TABLE txs_6; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_6 TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_6 TO writer;
GRANT SELECT ON TABLE public.txs_6 TO apetrov;
GRANT SELECT ON TABLE public.txs_6 TO skutsenko;


--
-- Name: TABLE txs_7; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_7 TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_7 TO writer;
GRANT SELECT ON TABLE public.txs_7 TO apetrov;
GRANT SELECT ON TABLE public.txs_7 TO skutsenko;


--
-- Name: TABLE txs_8; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_8 TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_8 TO writer;
GRANT SELECT ON TABLE public.txs_8 TO apetrov;
GRANT SELECT ON TABLE public.txs_8 TO skutsenko;


--
-- Name: TABLE txs_9; Type: ACL; Schema: public; Owner: dba
--

GRANT SELECT ON TABLE public.txs_9 TO reader;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE public.txs_9 TO writer;
GRANT SELECT ON TABLE public.txs_9 TO apetrov;
GRANT SELECT ON TABLE public.txs_9 TO skutsenko;


--
-- PostgreSQL database dump complete
--

