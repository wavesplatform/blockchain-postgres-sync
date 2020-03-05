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


CREATE FUNCTION public.check_tx_uid_existance(_uid bigint, _id varchar, _time_stamp timestamptz)
    RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
    return (select not exists(select * from txs where uid != _uid and id = _id and time_stamp = _time_stamp limit 1));
END
$$;


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


CREATE FUNCTION public.create_asset(_asset_id character varying, _issuer_address_uid bigint, _name character varying, _description text, _height integer, _timestamp timestamp with time zone, _quantity bigint, _decimals smallint, _reissuable boolean, _has_script boolean) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	declare
		asset_uid bigint;
	begin
		insert 
			into assets_data (asset_id, issuer_address_uid, asset_name, description, first_appeared_on_height, issue_timestamp, quantity, decimals, reissuable, has_script) 
			values (_asset_id, _issuer_address_uid, _name, _description, _height, _timestamp, _quantity, _decimals, _reissuable, _has_script) 
			on conflict (asset_id) 
			do update set 
                issuer_address_uid=EXCLUDED.issuer_address_uid,
				asset_name=EXCLUDED.asset_name, 
				description=EXCLUDED.description, 
				reissuable=EXCLUDED.reissuable, 
				has_script=EXCLUDED.has_script
			returning uid 
			into asset_uid;
		return asset_uid;
	END;
$$;


ALTER FUNCTION public.create_asset(_asset_id character varying, _issuer_address_uid bigint, _name character varying, _description text, _height integer, _timestamp timestamp with time zone, _quantity bigint, _decimals smallint, _reissuable boolean, _has_script boolean) OWNER TO dba;


CREATE FUNCTION public.create_range_partitions(_tbl_name character varying, _count integer, _partition_size integer, _since integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
	declare 
		loop_start int4;
		from_num int4;
		to_num int4;
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


ALTER FUNCTION public.create_range_partitions(_tbl_name character varying, _count integer, _partition_size integer, _since integer) OWNER TO dba;


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


CREATE FUNCTION public.get_address_or_alias_uid(address_or_alias character varying, public_key character varying, height integer) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	declare 
		alias_regex varchar := '^alias:\w{1}:(.*)';
		_alias varchar;
		address_uid bigint;
	begin
		-- 0) at genesis txs, sender is null, need to return null
		-- 1) try to get address uid by address_or_alias
		-- 2) address_or_alias is alias, try to get address uid by alias
		-- 3) insert address and return its uid
		
		-- 0
		if address_or_alias is null then
			return null;
		else
			-- 1
			select uid from addresses where address = address_or_alias into address_uid;
			if address_uid is null then
				if address_or_alias like 'alias:_:%' then
					-- 2
					_alias := substring(address_or_alias from alias_regex);
					select sender_uid from txs_10 where alias = _alias into address_uid;
				end if;
				if address_uid is null then 
					-- 3
					address_uid := insert_address(address_or_alias, public_key, height);
					return address_uid;
				end if;
			end if;
			return address_uid;
		end if;
	END;
$$;


ALTER FUNCTION public.get_address_or_alias_uid(address_or_alias character varying, public_key character varying, height integer) OWNER TO dba;


CREATE FUNCTION public.get_address_uid(_addr character varying, _public_key character varying, _height integer) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	declare 
		address_uid bigint;
		pubkey varchar;
	begin
		-- addr is null at genesis txs
		if _addr is null then 
			return null;
		end if;
	
		select uid, public_key from addresses where address = _addr into address_uid, pubkey;
	
		if address_uid is null then
			return insert_address(_addr, _public_key, _height);
		end if;
		
		-- check whether need to update public key
		if pubkey is null and _public_key is not null then
			update addresses set public_key = _public_key where address = _addr;
		end if;
		
		return address_uid;
	END;
$$;


ALTER FUNCTION public.get_address_uid(_addr character varying, _public_key character varying, _height integer) OWNER TO dba;


CREATE FUNCTION public.get_alias_uid(a character varying) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	declare
		alias_regex varchar := '^alias:\w{1}:(.*)';
		_alias varchar;
		alias_uid bigint;
	begin
		_alias := substring(a from alias_regex);
		select tx_uid from txs_10 where alias = _alias into alias_uid;
		return alias_uid;
	END;
$$;


ALTER FUNCTION public.get_alias_uid(a character varying) OWNER TO dba;


CREATE FUNCTION public.get_asset_id(text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT COALESCE($1, 'WAVES');
$_$;


ALTER FUNCTION public.get_asset_id(text) OWNER TO dba;


CREATE FUNCTION public.get_asset_uid(aid character varying) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	declare 
		asset_uid bigint;
	begin
		if aid is null then
			return null;
		else
			select uid from assets_data where asset_id=aid into asset_uid;
			return asset_uid;
		end if;
	END;
$$;


ALTER FUNCTION public.get_asset_uid(aid character varying) OWNER TO dba;


CREATE FUNCTION public.get_height_by_tx_uid(tx_uid bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	declare
		h int4;
	BEGIN
		select height from txs where uid = tx_uid into h;
		return h;
	END;
$$;


ALTER FUNCTION public.get_height_by_tx_uid(tx_uid bigint) OWNER TO dba;


CREATE FUNCTION public.get_order_uid(_o jsonb, _height integer, _tuid bigint, _sender_uid bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	declare
		order_uid bigint;
	BEGIN
		select uid from orders where id=_o->>'id' and tx_uid=_tuid into order_uid;
	
		if order_uid is null then
			insert into orders (id, tx_uid, height, "order") values(_o->>'id', _tuid, _height, _o) returning uid into order_uid;
			insert into txs_7_orders (
				height, 
				tx_uid, 
				order_uid, 
				sender_uid, 
				order_sender_uid, 
				amount_asset_uid, 
				price_asset_uid
			) values (
				_height, 
				_tuid, 
				order_uid, 
				_sender_uid, 
				get_address_or_alias_uid(_o->>'sender', _o->>'senderPublicKey', _height),
				get_asset_uid(_o->'assetPair'->>'amountAsset'),
				get_asset_uid(_o->'assetPair'->>'priceAsset')
			);
		
			return order_uid;
		else 
			return order_uid;
		end if;
	END;
$$;


ALTER FUNCTION public.get_order_uid(_o jsonb, _height integer, _tuid bigint, _sender_uid bigint) OWNER TO dba;


CREATE FUNCTION public.get_public_key_uid(pubkey character varying, address_or_alias character varying, height integer) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	declare
		alias_regex varchar := '^alias:\w{1}:(.*)';
		_alias varchar;
		address varchar;
		public_key_uid bigint;
	begin
		-- address is null at genesis txs
		if address_or_alias is null then 
			return null;
		else 
			select uid from addresses where public_key = pubkey into public_key_uid;
			if public_key_uid is null then
				_alias := substring(alias_regex from address_or_alias);
				select sender_uid from txs_10 where alias = _alias into public_key_uid;
				if public_key_uid is null then
					public_key_uid := insert_public_key(pubkey, address_or_alias, height);
					return public_key_uid;
				end if;
			end if;
			return public_key_uid;
		end if;
	END;
$$;


ALTER FUNCTION public.get_public_key_uid(pubkey character varying, address_or_alias character varying, height integer) OWNER TO dba;


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


CREATE FUNCTION public.get_tuid_by_tx_id_and_time_stamp(_tx_id character varying, _timestamp timestamp with time zone) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	declare
		tuid bigint;
	begin
		select uid from txs where id = _tx_id and time_stamp=_timestamp into tuid;
		return tuid;
	end;
$$;


ALTER FUNCTION public.get_tuid_by_tx_id_and_time_stamp(_tx_id character varying, _timestamp timestamp with time zone) OWNER TO dba;


CREATE FUNCTION public.get_tx_sender_uid_by_tx_id_and_time_stamp(_tx_id character varying, _time_stamp timestamp with time zone) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	declare
		tx_sender_uid bigint;
	begin
		select sender_uid from txs where id = _tx_id and time_stamp = _time_stamp into tx_sender_uid;
		return tx_sender_uid;
	end;
$$;


ALTER FUNCTION public.get_tx_sender_uid_by_tx_id_and_time_stamp(_tx_id character varying, _time_stamp timestamp with time zone) OWNER TO dba;


CREATE FUNCTION public.insert_address(addr character varying, public_key character varying, height integer) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	declare
		address_uid bigint;
	begin
		insert 
			into addresses (address, public_key, first_appeared_on_height) 
			values (addr, public_key, height) 
			on conflict do nothing
			returning uid
			into address_uid;
		return address_uid;
	END;
$$;


ALTER FUNCTION public.insert_address(addr character varying, public_key character varying, height integer) OWNER TO dba;


CREATE FUNCTION public.insert_all(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
    check_constraint_name varchar;
begin
	raise notice 'insert block % at %', b->>'height', clock_timestamp();
	PERFORM insert_block (b);
	PERFORM insert_txs (b);
	PERFORM insert_txs_1 (b);
	PERFORM insert_txs_2 (b);
	PERFORM insert_txs_3 (b);
	PERFORM insert_txs_4 (b);
	PERFORM insert_txs_5 (b);
	PERFORM insert_txs_6 (b);
	PERFORM insert_txs_7 (b);
	PERFORM insert_txs_8 (b);
	PERFORM insert_txs_9 (b);
	PERFORM insert_txs_10 (b);
	PERFORM insert_txs_11 (b);
	PERFORM insert_txs_12 (b);
 	PERFORM insert_txs_13 (b);
	PERFORM insert_txs_14 (b);
	PERFORM insert_txs_15 (b);
	PERFORM insert_txs_16 (b);
exception
    when check_violation then
        GET STACKED DIAGNOSTICS check_constraint_name = CONSTRAINT_NAME;
        if check_constraint_name = 'txs_uid_check' then end if;
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


CREATE FUNCTION public.insert_public_key(public_key character varying, addr character varying, height integer) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	declare 
		public_key_uid bigint;
	begin
		insert 
			into addresses_map (address, public_key, first_appeared_on_height) 
			values (addr, public_key, height) 
			on conflict (address) 
			do update set public_key=EXCLUDED.public_key 
			returning uid
			into public_key_uid;
		return public_key_uid;
	END;
$$;


ALTER FUNCTION public.insert_public_key(public_key character varying, addr character varying, height integer) OWNER TO dba;


CREATE FUNCTION public.insert_txs(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  insert into txs (
  	id, 
  	time_stamp, 
  	height, 
  	tx_type, 
  	signature,
  	proofs, 
  	tx_version,
  	fee,
  	sender_uid
  )
  select
	t->>'id',
    to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
    (t->>'height')::int4,
    (t ->> 'type')::smallint,
    t ->> 'signature',
    jsonb_array_cast_text(t -> 'proofs'),
    (t ->> 'version')::smallint,
    (t ->> 'fee')::bigint,
    get_address_uid(t ->> 'sender', t->>'senderPublicKey', (t->>'height')::int4)
  from (
    select jsonb_array_elements(b -> 'transactions') || jsonb_build_object('height', b -> 'height') as t
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
  					 height,
                     sender_uid,
                     recipient_address_uid,
                     recipient_alias_uid,
                     amount)
  select
    -- common
    get_tuid_by_tx_id_and_time_stamp(t ->> 'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
    t ->> 'id',
    (t ->> 'height')::int4,
    -- with sender
	get_tx_sender_uid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
    -- type specific
    get_address_or_alias_uid(t ->> 'recipient', null, (t->>'height')::int4),
    get_alias_uid(t->>'recipient'),
    (t ->> 'amount')::bigint
  from (
         select jsonb_array_elements(b -> 'transactions') || jsonb_build_object('height', b -> 'height') as t
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
		height,
		sender_uid,
		alias
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
        t ->> 'id',
		(t->>'height')::int4,
		-- with sender
		get_tx_sender_uid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
		-- type specific
		t->>'alias'
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
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
  INSERT INTO txs_11 (tx_uid,
                      id,
  					  height,
                      sender_uid,
                      asset_uid,
                      attachment)
  SELECT
    -- common
    get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
    t ->> 'id',
    (t ->> 'height') :: INT4,
    -- with sender
	get_tx_sender_uid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
    -- type specific
    get_asset_uid(t ->> 'assetId'),
    t ->> 'attachment'
  FROM (
         SELECT jsonb_array_elements(b -> 'transactions') || jsonb_build_object('height', b -> 'height') AS t
       ) AS txs
  WHERE (t ->> 'type') = '11'
  ON CONFLICT DO NOTHING;
 
  -- transfers
  INSERT INTO txs_11_transfers (tx_uid,
                                recipient_address_uid,
                                recipient_alias_uid,
                                amount,
                                position_in_tx,
                                height)
  SELECT 
	(t ->> 'tx_uid')::bigint,
    get_address_or_alias_uid(t ->> 'recipient', null, (t->>'height')::int4),
    get_alias_uid(t->>'recipient'),
    (t ->> 'amount') :: BIGINT,
    row_number() OVER (PARTITION BY t ->> 'tx_id' ) - 1,
    (t ->> 'height')::int4
  FROM (
         SELECT jsonb_array_elements(tx -> 'transfers') || jsonb_build_object('tx_uid', get_tuid_by_tx_id_and_time_stamp(tx->>'id', to_timestamp((tx->>'timestamp') :: DOUBLE PRECISION / 1000))) || jsonb_build_object('height', b->'height') AS t
         FROM (
                SELECT jsonb_array_elements(b -> 'transactions') AS tx
              ) AS txs
       ) AS transfers
  ON CONFLICT DO NOTHING;
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
		height,
		sender_uid
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
        t ->> 'id',
		(t->>'height')::int4,
		-- with sender
		get_tx_sender_uid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000))
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
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
		(d->>'height')::int4
	from (
		select jsonb_array_elements(tx->'data') || jsonb_build_object('tx_uid', get_tuid_by_tx_id_and_time_stamp(tx->>'id', to_timestamp((tx->>'timestamp') :: DOUBLE PRECISION / 1000))) || jsonb_build_object('height', b->'height') as d
			from (
				select jsonb_array_elements(b->'transactions') as tx
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
		height,
		sender_uid,
	    script
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
        t ->> 'id',
		(t->>'height')::int4,
		-- with sender
		get_tx_sender_uid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
		-- type specific
    	t->>'script'
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
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
		height,
		sender_uid,
	    asset_uid,
    	min_sponsored_asset_fee
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
        t ->> 'id',
		(t->>'height')::int4,
		-- with sender
		get_tx_sender_uid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
		-- type specific
	    get_asset_uid(t->>'assetId'),
	    (t->>'minSponsoredAssetFee')::bigint
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
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
		height,
		sender_uid,
		asset_uid,
	    script
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
        t ->> 'id',
		(t->>'height')::int4,
		-- with sender
		get_tx_sender_uid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
		-- type specific
		get_asset_uid(t->>'assetId'),
	    t->>'script'
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
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
		height,
		sender_uid,
		dapp_address_uid,
	    function_name
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
        t ->> 'id',
		(t->>'height')::int4,
		-- with sender
		get_tx_sender_uid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
		-- type specific
		get_address_or_alias_uid(t->>'dApp', null, (t->>'height')::int4),
	    t->'call'->>'function'
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
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
		position_in_args,
		height
	)
	select
		(arg->>'tx_uid')::int4,
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
		row_number() over (PARTITION BY arg->>'tx_uid') - 1 as position_in_args,
		(arg->>'height')::int4
	from (
		select jsonb_array_elements(tx->'call'->'args') || jsonb_build_object('tx_uid', get_tuid_by_tx_id_and_time_stamp(tx->>'id', to_timestamp((tx->>'timestamp') :: DOUBLE PRECISION / 1000))) || jsonb_build_object('height', b->'height') as arg
			from (
				select jsonb_array_elements(b->'transactions') as tx
			) as txs
			where (tx->>'type') = '16'
	) as data
	on conflict do nothing;

	insert into txs_16_payment (
		tx_uid,
		amount,
		asset_uid,
		position_in_payment,
		height
	)
	select
		(p->>'tx_uid')::bigint,
		(p->>'amount')::bigint as amount,
		get_asset_uid(p->>'assetId') as asset_uid,
		row_number() over (PARTITION BY p->'tx_uid') - 1 as position_in_payment,
		(p->>'height')::int4
	from (
		select jsonb_array_elements(tx->'payment') || jsonb_build_object('tx_uid', get_tuid_by_tx_id_and_time_stamp(tx->>'id', to_timestamp((tx->>'timestamp') :: DOUBLE PRECISION / 1000))) || jsonb_build_object('height', b->'height') as p
			from (
				select jsonb_array_elements(b->'transactions') as tx
			) as txs
			where (tx->>'type') = '16'
	) as data
	on conflict do nothing;
END
$$;


ALTER FUNCTION public.insert_txs_16(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_2(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_2 (
		tx_uid,
        id,
		height,
		sender_uid,
		recipient_address_uid,
		recipient_alias_uid,
		amount
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
        t ->> 'id',
		(t->>'height')::int4,
		-- with sender
		get_tx_sender_uid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
		-- type specific
    	get_address_or_alias_uid(t ->> 'recipient', null, (t->>'height')::int4),
    	get_alias_uid(t->>'recipient'),
		(t->>'amount')::bigint
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
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
		height,
		sender_uid,
		asset_uid,
		asset_name,
		description,
		quantity,
		decimals,
		reissuable,
		script
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
        t ->> 'id',
		(t->>'height')::int4,
		-- with sender
		(t->>'sender_uid')::bigint,
		-- type specific
		create_asset(
			t->>'assetId',
            (t->>'sender_uid')::bigint,
			t->>'name', 
			t->>'description',
			(t->>'height')::int4, 
			to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000), 
			(t->>'quantity')::bigint,
			(t->>'decimals')::smallint, 
			(t->>'reissuable')::bool, 
			t->>'script' is not null
		),
		t->>'name',
		t->>'description',
		(t->>'quantity')::bigint,
		(t->>'decimals')::smallint,
		(t->>'reissuable')::bool,
		t->>'script'
	from (
        select 
            t || jsonb_build_object('sender_uid', get_tx_sender_uid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000))) as t
        from (
            select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
        ) as t
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
		height,
		fee_asset_uid, 
		sender_uid, 
		recipient_address_uid,
		recipient_alias_uid,
		attachment, 
		amount, 
		asset_uid
	)
	select
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
        t ->> 'id',
		(t->>'height')::int4,
		get_asset_uid(coalesce(t->>'feeAsset', t->>'feeAssetId')),
		-- with sender
		get_tx_sender_uid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
		-- type-specific
		get_address_or_alias_uid(t->>'recipient', null, (t->>'height')::int4),
		get_alias_uid(t->>'recipient'),
		t->>'attachment',
		(t->>'amount')::bigint,
		get_asset_uid(t->>'assetId')
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
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
		height,
		sender_uid,
		asset_uid,
		quantity,
		reissuable
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
        t ->> 'id',
		(t->>'height')::int4,
		-- with sender
		get_tx_sender_uid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
		-- type specific
		get_asset_uid(t->>'assetId'),
		(t->>'quantity')::bigint,
		(t->>'reissuable')::bool
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
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
		height,
		sender_uid,
		asset_uid,
		amount
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
        t ->> 'id',
		(t->>'height')::int4,
		-- with sender
		get_tx_sender_uid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
		-- type specific
		get_asset_uid(t->>'assetId'),
		(t->>'amount')::bigint
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
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
                     fee_asset_uid,
                     time_stamp,
                     sender_uid,
                     order1_uid,
                     order2_uid,
                     amount,
                     price,
                     buy_matcher_fee,
                     sell_matcher_fee,
                     amount_asset_uid,
                     price_asset_uid)
  select
    -- common
    (t->>'tuid')::bigint,
    t ->> 'id',
    (t ->> 'height')::int4,
   	get_asset_uid(t->>'feeAssetId'),
    to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000),
    -- with sender
	(t->>'sender_uid')::bigint,
    -- type specific
    get_order_uid(t -> 'order1', (t->>'height')::int4, (t->>'tuid')::bigint, (t->>'sender_uid')::bigint),
    get_order_uid(t -> 'order2', (t->>'height')::int4, (t->>'tuid')::bigint, (t->>'sender_uid')::bigint),
    (t ->> 'amount')::bigint,
    (t ->> 'price')::bigint,
    (t ->> 'buyMatcherFee')::bigint,
    (t ->> 'sellMatcherFee')::bigint,
    get_asset_uid(t->'order1'->'assetPair'->>'amountAsset'),
    get_asset_uid(t->'order1'->'assetPair'->>'priceAsset')
  from (
  	select t 
  		   || jsonb_build_object('tuid', get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000))) 
  		   || jsonb_build_object('sender_uid', get_tx_sender_uid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)))
  		   as t
  		   from (
	         select jsonb_array_elements(b -> 'transactions') || jsonb_build_object('height', b -> 'height') as t
	       ) as t
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
		height,
		sender_uid,
		recipient_address_uid,
		recipient_alias_uid,
		amount
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
        t ->> 'id',
		(t->>'height')::int4,
		-- with sender
		get_tx_sender_uid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
		-- type specific
    	get_address_or_alias_uid(t ->> 'recipient', null, (t->>'height')::int4),
	    get_alias_uid(t->>'recipient'),
		(t->>'amount')::bigint
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
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
		height,
		sender_uid,
		lease_tx_uid
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
        t ->> 'id',
		(t->>'height')::int4,
		-- with sender
		get_tx_sender_uid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
		-- type specific
		get_tuid_by_tx_id(t->>'leaseId')
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
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


CREATE FUNCTION public.sync_partitions(_tbl_name character varying) RETURNS void
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


ALTER FUNCTION public.sync_partitions(_tbl_name character varying) OWNER TO dba;


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


CREATE TABLE public.addresses (
    uid bigint GENERATED BY DEFAULT AS IDENTITY,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
)
PARTITION BY RANGE (uid);


CREATE TABLE addresses_default PARTITION OF addresses DEFAULT;


CREATE TABLE public.assets_data (
    uid bigint GENERATED BY DEFAULT AS IDENTITY,
    issuer_address_uid bigint,
    asset_id character varying NOT NULL,
    first_appeared_on_height integer,
    asset_name character varying NOT NULL,
    description text,
    decimals smallint NOT NULL,
    ticker text,
    issue_timestamp timestamp with time zone,
    quantity numeric,
    reissuable boolean,
    has_script boolean
);


CREATE TABLE public.assets_metadata (
    asset_uid bigint GENERATED BY DEFAULT AS IDENTITY,
    asset_name character varying,
    ticker character varying,
    height integer
);


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


CREATE TABLE public.blocks_raw (
    height integer NOT NULL,
    b jsonb NOT NULL
);


CREATE TABLE public.candles (
    time_start timestamp with time zone NOT NULL,
    amount_asset_uid bigint NOT NULL,
    price_asset_uid bigint NOT NULL,
    low numeric NOT NULL,
    high numeric NOT NULL,
    volume numeric NOT NULL,
    quote_volume numeric NOT NULL,
    max_height integer NOT NULL,
    txs_count integer NOT NULL,
    weighted_average_price numeric NOT NULL,
    open numeric NOT NULL,
    close numeric NOT NULL,
    interval character varying NOT NULL,
    matcher_address_uid bigint NOT NULL
);


CREATE TABLE public.orders (
    uid bigint GENERATED BY DEFAULT AS IDENTITY,
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    "order" jsonb NOT NULL
)
PARTITION BY RANGE (uid);


SELECT create_range_partitions('orders', 20, 50000000, 0);


CREATE TABLE public.orders_default (
    uid bigint DEFAULT nextval('public.orders_uid_seq'::regclass) NOT NULL,
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    "order" jsonb NOT NULL
);
ALTER TABLE ONLY public.orders ATTACH PARTITION public.orders_default DEFAULT;


CREATE TABLE public.pairs (
    amount_asset_uid bigint NOT NULL,
    price_asset_uid bigint NOT NULL,
    first_price numeric NOT NULL,
    last_price numeric NOT NULL,
    volume numeric NOT NULL,
    volume_waves numeric,
    quote_volume numeric NOT NULL,
    high numeric NOT NULL,
    low numeric NOT NULL,
    weighted_average_price numeric NOT NULL,
    txs_count integer NOT NULL,
    matcher_address_uid bigint NOT NULL
);


CREATE TABLE public.txs (
    uid bigint GENERATED BY DEFAULT AS IDENTITY,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint,
    constraint txs_uid_check check ( check_tx_uid_existance(uid, id, time_stamp) )
)
PARTITION BY RANGE (uid);


SELECT create_range_partitions('txs', 20, 100000000, 0);


CREATE TABLE public.txs_1 (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    recipient_alias_uid bigint
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_1_default (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_1 ATTACH PARTITION public.txs_1_default DEFAULT;


CREATE TABLE public.txs_10 (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    alias character varying NOT NULL
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_10_default (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    alias character varying NOT NULL
);
ALTER TABLE ONLY public.txs_10 ATTACH PARTITION public.txs_10_default DEFAULT;


CREATE TABLE public.txs_11 (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint,
    attachment character varying NOT NULL
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_11_default (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint,
    attachment character varying NOT NULL
);
ALTER TABLE ONLY public.txs_11 ATTACH PARTITION public.txs_11_default DEFAULT;


CREATE TABLE public.txs_11_transfers (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
)
PARTITION BY RANGE (tx_uid);


SELECT create_range_partitions('txs_11_transfers', 20, 50000000, 0);


CREATE TABLE public.txs_11_transfers_default (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_default DEFAULT;


CREATE TABLE public.txs_12 (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_12_default (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL
);
ALTER TABLE ONLY public.txs_12 ATTACH PARTITION public.txs_12_default DEFAULT;


CREATE TABLE public.txs_12_data (
    tx_uid bigint NOT NULL,
    data_key text NOT NULL,
    data_type text NOT NULL,
    data_value_integer bigint,
    data_value_boolean boolean,
    data_value_binary text,
    data_value_string text,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL
)
PARTITION BY RANGE (tx_uid);


SELECT create_range_partitions('txs_12_data', 20, 50000000, 0);


CREATE TABLE public.txs_12_data_default (
    tx_uid bigint NOT NULL,
    data_key text NOT NULL,
    data_type text NOT NULL,
    data_value_integer bigint,
    data_value_boolean boolean,
    data_value_binary text,
    data_value_string text,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL
);
ALTER TABLE ONLY public.txs_12_data ATTACH PARTITION public.txs_12_data_default DEFAULT;


CREATE TABLE public.txs_13 (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    script character varying
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_13_default (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    script character varying
);
ALTER TABLE ONLY public.txs_13 ATTACH PARTITION public.txs_13_default DEFAULT;


CREATE TABLE public.txs_14 (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    min_sponsored_asset_fee bigint
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_14_default (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    min_sponsored_asset_fee bigint
);
ALTER TABLE ONLY public.txs_14 ATTACH PARTITION public.txs_14_default DEFAULT;


CREATE TABLE public.txs_15 (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    script character varying
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_15_default (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    script character varying
);
ALTER TABLE ONLY public.txs_15 ATTACH PARTITION public.txs_15_default DEFAULT;


CREATE TABLE public.txs_16 (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    dapp_address_uid bigint NOT NULL,
    function_name character varying,
    dapp_alias_uid bigint
)
PARTITION BY RANGE (tx_uid);


SELECT create_range_partitions('txs_16', 20, 50000000, 0);


CREATE TABLE public.txs_16_default (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    dapp_address_uid bigint NOT NULL,
    function_name character varying,
    dapp_alias_uid bigint
);
ALTER TABLE ONLY public.txs_16 ATTACH PARTITION public.txs_16_default DEFAULT;


CREATE TABLE public.txs_16_args (
    arg_type text NOT NULL,
    arg_value_integer bigint,
    arg_value_boolean boolean,
    arg_value_binary text,
    arg_value_string text,
    position_in_args smallint NOT NULL,
    tx_uid bigint NOT NULL,
    height integer
)
PARTITION BY RANGE (tx_uid);


SELECT create_range_partitions('txs_16_args', 20, 100000000, 0);


CREATE TABLE public.txs_16_args_default (
    arg_type text NOT NULL,
    arg_value_integer bigint,
    arg_value_boolean boolean,
    arg_value_binary text,
    arg_value_string text,
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
    asset_uid bigint
)
PARTITION BY RANGE (tx_uid);


SELECT create_range_partitions('txs_16_payment', 20, 100000000, 0);


CREATE TABLE public.txs_16_payment_default (
    tx_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_payment smallint NOT NULL,
    height integer,
    asset_uid bigint
);
ALTER TABLE ONLY public.txs_16_payment ATTACH PARTITION public.txs_16_payment_default DEFAULT;


CREATE TABLE public.txs_2 (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    recipient_alias_uid bigint
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_2_default (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_2 ATTACH PARTITION public.txs_2_default DEFAULT;


CREATE TABLE public.txs_3 (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    asset_name character varying NOT NULL,
    description character varying NOT NULL,
    quantity bigint NOT NULL,
    decimals smallint NOT NULL,
    reissuable boolean NOT NULL,
    script character varying
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_3_default (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    asset_name character varying NOT NULL,
    description character varying NOT NULL,
    quantity bigint NOT NULL,
    decimals smallint NOT NULL,
    reissuable boolean NOT NULL,
    script character varying
);
ALTER TABLE ONLY public.txs_3 ATTACH PARTITION public.txs_3_default DEFAULT;


CREATE TABLE public.txs_4 (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint,
    amount bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    fee_asset_uid bigint,
    attachment character varying NOT NULL,
    recipient_alias_uid bigint
)
PARTITION BY RANGE (tx_uid);


SELECT create_range_partitions('txs_4', 20, 50000000, 0);


CREATE TABLE public.txs_4_default (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint,
    amount bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    fee_asset_uid bigint,
    attachment character varying NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_4 ATTACH PARTITION public.txs_4_default DEFAULT;


CREATE TABLE public.txs_5 (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    quantity bigint NOT NULL,
    reissuable boolean NOT NULL
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_5_default (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    quantity bigint NOT NULL,
    reissuable boolean NOT NULL
);
ALTER TABLE ONLY public.txs_5 ATTACH PARTITION public.txs_5_default DEFAULT;


CREATE TABLE public.txs_6 (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    amount bigint NOT NULL
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_6_default (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    amount bigint NOT NULL
);
ALTER TABLE ONLY public.txs_6 ATTACH PARTITION public.txs_6_default DEFAULT;


CREATE TABLE public.txs_7 (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    sender_uid bigint NOT NULL,
    order1_uid bigint NOT NULL,
    order2_uid bigint NOT NULL,
    amount bigint NOT NULL,
    price bigint NOT NULL,
    amount_asset_uid bigint,
    price_asset_uid bigint,
    buy_matcher_fee bigint NOT NULL,
    sell_matcher_fee bigint NOT NULL,
    fee_asset_uid bigint
)
PARTITION BY RANGE (tx_uid);


SELECT create_range_partitions('txs_7', 20, 50000000, 0);


CREATE TABLE public.txs_7_default (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    time_stamp timestamp with time zone NOT NULL,
    sender_uid bigint NOT NULL,
    order1_uid bigint NOT NULL,
    order2_uid bigint NOT NULL,
    amount bigint NOT NULL,
    price bigint NOT NULL,
    amount_asset_uid bigint,
    price_asset_uid bigint,
    buy_matcher_fee bigint NOT NULL,
    sell_matcher_fee bigint NOT NULL,
    fee_asset_uid bigint
);
ALTER TABLE ONLY public.txs_7 ATTACH PARTITION public.txs_7_default DEFAULT;


CREATE TABLE public.txs_7_orders (
    tx_uid bigint NOT NULL,
    height integer,
    order_uid bigint NOT NULL,
    sender_uid bigint NOT NULL,
    order_sender_uid bigint NOT NULL,
    amount_asset_uid bigint,
    price_asset_uid bigint
)
PARTITION BY RANGE (tx_uid);


SELECT create_range_partitions('txs_7_orders', 20, 50000000, 0);


CREATE TABLE public.txs_7_orders_default (
    tx_uid bigint NOT NULL,
    height integer,
    order_uid bigint NOT NULL,
    sender_uid bigint NOT NULL,
    order_sender_uid bigint NOT NULL,
    amount_asset_uid bigint,
    price_asset_uid bigint
);
ALTER TABLE ONLY public.txs_7_orders ATTACH PARTITION public.txs_7_orders_default DEFAULT;


CREATE TABLE public.txs_8 (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    recipient_alias_uid bigint
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_8_default (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_8 ATTACH PARTITION public.txs_8_default DEFAULT;


CREATE TABLE public.txs_9 (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    lease_tx_uid bigint
)
PARTITION BY RANGE (tx_uid);


CREATE TABLE public.txs_9_default (
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    lease_tx_uid bigint
);
ALTER TABLE ONLY public.txs_9 ATTACH PARTITION public.txs_9_default DEFAULT;


CREATE TABLE public.waves_data (
	height int4 NULL,
	quantity numeric NOT NULL
);


INSERT INTO waves_data (height, quantity) VALUES (null, 10000000000000000);


CREATE OR REPLACE VIEW public.assets
AS SELECT a.uid,
    a.asset_id,
    a.ticker,
    a.asset_name,
    a.description,
    a.issuer_address_uid,
    a.first_appeared_on_height,
    a.issue_timestamp,
    a.quantity + COALESCE(reissue_q.reissued_total, 0::numeric) - COALESCE(burn_q.burned_total, 0::numeric) AS quantity,
    a.decimals,
        CASE
            WHEN r_after.reissuable_after IS NULL THEN a.reissuable
            ELSE a.reissuable AND r_after.reissuable_after
        END AS reissuable,
    a.has_script,
    txs_14.min_sponsored_asset_fee
   FROM assets_data a
     LEFT JOIN ( SELECT txs_5.asset_uid,
            sum(txs_5.quantity) AS reissued_total
           FROM txs_5
          GROUP BY txs_5.asset_uid) reissue_q ON a.uid = reissue_q.asset_uid
     LEFT JOIN ( SELECT txs_6.asset_uid,
            sum(txs_6.amount) AS burned_total
           FROM txs_6
          GROUP BY txs_6.asset_uid) burn_q ON a.uid = burn_q.asset_uid
     LEFT JOIN ( SELECT txs_5.asset_uid,
            bool_and(txs_5.reissuable) AS reissuable_after
           FROM txs_5
          GROUP BY txs_5.asset_uid) r_after ON a.uid = r_after.asset_uid
     LEFT JOIN ( SELECT DISTINCT ON (txs_14_1.asset_uid) txs_14_1.asset_uid,
            txs_14_1.min_sponsored_asset_fee
           FROM txs_14 txs_14_1
          ORDER BY txs_14_1.asset_uid DESC) txs_14 ON a.uid = txs_14.asset_uid
UNION ALL
 SELECT 0 AS uid,
    'WAVES'::character varying AS asset_id,
    'WAVES'::text AS ticker,
    'Waves'::character varying AS asset_name,
    ''::character varying AS description,
    NULL::bigint AS issuer_address_uid,
    NULL::integer AS first_appeared_on_height,
    '2016-04-11 21:00:00'::timestamp without time zone AS issue_timestamp,
    (( SELECT waves_data.quantity
           FROM waves_data
          ORDER BY waves_data.height DESC NULLS LAST
         LIMIT 1))::bigint::numeric AS quantity,
    8 AS decimals,
    false AS reissuable,
    false AS has_script,
    NULL::bigint AS min_sponsored_asset_fee;


ALTER TABLE public.addresses ADD CONSTRAINT addresses_pk PRIMARY KEY (address, uid);


ALTER TABLE public.assets_data ADD CONSTRAINT assets_data_un UNIQUE (uid);


ALTER TABLE public.assets_data ADD CONSTRAINT assets_data_un_asset_id UNIQUE (asset_id);


ALTER TABLE public.assets_data ADD CONSTRAINT assets_data_un_ticker UNIQUE (ticker);


ALTER TABLE public.blocks ADD CONSTRAINT blocks_pkey PRIMARY KEY (height);


ALTER TABLE public.blocks_raw ADD CONSTRAINT blocks_raw_pkey PRIMARY KEY (height);


ALTER TABLE public.candles ADD CONSTRAINT candles_pkey PRIMARY KEY (interval, time_start, amount_asset_uid, price_asset_uid, matcher_address_uid);


ALTER TABLE public.orders ADD CONSTRAINT orders_uid_key UNIQUE (uid);


ALTER TABLE public.pairs ADD CONSTRAINT pairs_pk PRIMARY KEY (amount_asset_uid, price_asset_uid, matcher_address_uid);


ALTER TABLE public.txs ADD CONSTRAINT txs_pk PRIMARY KEY (id, time_stamp, uid);


ALTER TABLE public.txs_10 ADD CONSTRAINT txs_10_tx_uid_key UNIQUE (tx_uid);


ALTER TABLE public.txs_11 ADD CONSTRAINT txs_11_tx_uid_key UNIQUE (tx_uid);


ALTER TABLE public.txs_11_transfers ADD CONSTRAINT txs_11_transfers_pkey PRIMARY KEY (tx_uid, position_in_tx);


ALTER TABLE public.txs_12_data ADD CONSTRAINT txs_12_data_pkey PRIMARY KEY (tx_uid, position_in_tx);


ALTER TABLE public.txs_12 ADD CONSTRAINT txs_12_tx_uid_key UNIQUE (tx_uid);


ALTER TABLE public.txs_13 ADD CONSTRAINT txs_13_tx_uid_key UNIQUE (tx_uid);


ALTER TABLE public.txs_14 ADD CONSTRAINT txs_14_tx_uid_key UNIQUE (tx_uid);


ALTER TABLE public.txs_15 ADD CONSTRAINT txs_15_tx_uid_key UNIQUE (tx_uid);


ALTER TABLE public.txs_16 ADD CONSTRAINT txs_16_un UNIQUE (tx_uid);


ALTER TABLE public.txs_16_args ADD CONSTRAINT txs_16_args_pk PRIMARY KEY (tx_uid, position_in_args);


ALTER TABLE public.txs_16_payment ADD CONSTRAINT txs_16_payment_pk PRIMARY KEY (tx_uid, position_in_payment);


ALTER TABLE public.txs_1 ADD CONSTRAINT txs_1_tx_uid_key UNIQUE (tx_uid);


ALTER TABLE public.txs_2 ADD CONSTRAINT txs_2_tx_uid_key UNIQUE (tx_uid);


ALTER TABLE public.txs_3 ADD CONSTRAINT txs_3_tx_uid_key UNIQUE (tx_uid);


ALTER TABLE public.txs_4 ADD CONSTRAINT txs_4_tx_uid_key UNIQUE (tx_uid);


ALTER TABLE public.txs_5 ADD CONSTRAINT txs_5_tx_uid_key UNIQUE (tx_uid);


ALTER TABLE public.txs_6 ADD CONSTRAINT txs_6_tx_uid_key UNIQUE (tx_uid);


ALTER TABLE public.txs_7 ADD CONSTRAINT txs_7_tx_uid_key UNIQUE (tx_uid);


ALTER TABLE public.txs_7_orders ADD CONSTRAINT txs_7_orders_pk PRIMARY KEY (tx_uid, order_uid);


ALTER TABLE public.txs_8 ADD CONSTRAINT txs_8_tx_uid_key UNIQUE (tx_uid);


ALTER TABLE public.txs_9 ADD CONSTRAINT txs_9_tx_uid_key UNIQUE (tx_uid);


ALTER TABLE public.txs_9 ADD CONSTRAINT txs_9_un UNIQUE (tx_uid, lease_tx_uid);


ALTER TABLE public.waves_data ADD CONSTRAINT waves_data_un UNIQUE (height);


CREATE INDEX addresses_address_uid_idx ON public.addresses USING btree (address, uid);


CREATE INDEX addresses_public_key_uid_idx ON public.addresses USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_address_first_appeared_on_height_idx ON public.addresses USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_uid_address_public_key_idx ON public.addresses USING btree (uid, address, public_key);


CREATE INDEX addresses_first_appeared_on_height_idx ON public.addresses USING btree (first_appeared_on_height);


CREATE INDEX assets_data_asset_id_idx ON public.assets_data USING btree (asset_id);


CREATE INDEX assets_data_asset_name_idx ON public.assets_data USING btree (asset_name varchar_pattern_ops);


CREATE UNIQUE INDEX assets_data_asset_id_first_appeared_on_height_idx ON public.assets_data USING btree (asset_id, first_appeared_on_height);


CREATE INDEX assets_data_first_appeared_on_height_idx ON public.assets_data USING btree (first_appeared_on_height);


CREATE INDEX assets_metadata_asset_name_idx ON public.assets_metadata USING btree (asset_name text_pattern_ops);


CREATE INDEX assets_data_ticker_idx ON public.assets_data USING btree (ticker text_pattern_ops);


CREATE INDEX assets_data_uid_asset_id_decimals_idx ON assets_data (uid, asset_id, decimals);


CREATE INDEX candles_max_height_index ON public.candles USING btree (max_height);


CREATE INDEX orders_height_idx ON public.orders USING btree (height);


CREATE INDEX orders_id_uid_idx ON public.orders USING btree (id, uid);


CREATE INDEX assets_data_to_tsvector_asset_name_idx ON public.assets_data USING gin (to_tsvector('simple'::regconfig, (asset_name)::text));


CREATE INDEX txs_height_idx ON public.txs USING btree (height);


CREATE INDEX txs_id_uid_idx ON public.txs USING btree (id, uid);


CREATE INDEX txs_sender_uid_idx ON public.txs USING btree (sender_uid);


CREATE INDEX txs_sender_uid_uid_idx ON public.txs USING btree (sender_uid, uid);


CREATE INDEX txs_time_stamp_idx ON public.txs USING btree (time_stamp);


CREATE UNIQUE INDEX txs_uid_time_stamp_unique_idx ON txs (uid, time_stamp);


CREATE UNIQUE INDEX txs_uid_desc_time_stamp_unique_idx ON txs (uid desc, time_stamp);


CREATE INDEX txs_tx_type_idx ON public.txs USING btree (tx_type);


CREATE INDEX txs_uid_idx ON public.txs USING btree (uid);


CREATE INDEX txs_10_alias_idx ON public.txs_10 USING hash (alias);


CREATE INDEX txs_10_alias_sender_uid_idx ON public.txs_10 USING btree (alias, sender_uid);


CREATE INDEX txs_10_alias_tuid_idx ON public.txs_10 USING btree (alias, tx_uid);


CREATE INDEX txs_10_height_idx ON public.txs_10 USING btree (height);


CREATE INDEX txs_10_sender_uid_idx ON public.txs_10 USING hash (sender_uid);


CREATE INDEX txs_10_tx_uid_alias_idx ON public.txs_10 USING btree (tx_uid, alias);


CREATE INDEX txs_10_id_tx_uid_idx ON public.txs_10 (id, tx_uid);


CREATE INDEX txs_11_asset_uid_idx ON public.txs_11 USING hash (asset_uid);


CREATE INDEX txs_11_height_idx ON public.txs_11 USING btree (height);


CREATE INDEX txs_11_sender_uid_idx ON public.txs_11 USING btree (sender_uid, tx_uid);


CREATE INDEX txs_11_id_tx_uid_idx ON public.txs_11 (id, tx_uid);


CREATE INDEX txs_11_transfers_height_idx ON public.txs_11_transfers USING btree (height);


CREATE INDEX txs_11_transfers_recipient_index ON public.txs_11_transfers USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_tuid_idx ON public.txs_11_transfers USING btree (tx_uid);


CREATE INDEX txs_12_data_data_key_idx ON public.txs_12_data USING hash (data_key);


CREATE INDEX txs_12_data_data_type_idx ON public.txs_12_data USING hash (data_type);


CREATE INDEX txs_12_data_data_value_binary_partial_idx ON public.txs_12_data USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


CREATE INDEX txs_12_data_data_value_boolean_partial_idx ON public.txs_12_data USING btree (data_value_boolean) WHERE (data_type = 'boolean'::text);


CREATE INDEX txs_12_data_data_value_integer_partial_idx ON public.txs_12_data USING btree (data_value_integer) WHERE (data_type = 'integer'::text);


CREATE INDEX txs_12_data_data_value_string_partial_idx ON public.txs_12_data USING hash (data_value_string) WHERE (data_type = 'string'::text);


CREATE INDEX txs_12_data_height_idx ON public.txs_12_data USING btree (height);


CREATE INDEX txs_12_data_tx_uid_idx ON public.txs_12_data USING btree (tx_uid);


CREATE INDEX txs_12_height_idx ON public.txs_12 USING btree (height);


CREATE INDEX txs_12_sender_uid_idx ON public.txs_12 USING hash (sender_uid);


CREATE INDEX txs_12_id_tx_uid_idx ON public.txs_12 (id, tx_uid);


CREATE INDEX txs_12_data_tx_uid_data_key_idx ON txs_12_data (tx_uid, data_key);


CREATE INDEX txs_12_data_tx_uid_data_type_idx ON txs_12_data (tx_uid, data_type);


CREATE INDEX txs_13_height_idx ON public.txs_13 USING btree (height);


CREATE INDEX txs_13_md5_script_idx ON public.txs_13 USING btree (md5((script)::text));


CREATE INDEX txs_13_sender_uid_idx ON public.txs_13 USING hash (sender_uid);


CREATE INDEX txs_13_id_tx_uid_idx ON public.txs_13 (id, tx_uid);


CREATE INDEX txs_14_height_idx ON public.txs_14 USING btree (height);


CREATE INDEX txs_14_sender_uid_idx ON public.txs_14 USING hash (sender_uid);


CREATE INDEX txs_14_id_tx_uid_idx ON public.txs_14 (id, tx_uid);


CREATE INDEX txs_15_height_idx ON public.txs_15 USING btree (height);


CREATE INDEX txs_15_md5_script_idx ON public.txs_15 USING btree (md5((script)::text));


CREATE INDEX txs_15_sender_uid_idx ON public.txs_15 USING btree (sender_uid);


CREATE INDEX txs_15_id_tx_uid_idx ON public.txs_15 (id, tx_uid);


CREATE INDEX txs_16_dapp_address_uid_tx_uid_idx ON public.txs_16 USING btree (dapp_address_uid, tx_uid);


CREATE INDEX txs_16_function_name_idx ON public.txs_16 USING btree (function_name);


CREATE INDEX txs_16_height_idx ON public.txs_16 USING btree (height);


CREATE INDEX txs_16_sender_uid_idx ON public.txs_16 USING btree (sender_uid);


CREATE INDEX txs_16_id_tx_uid_idx ON public.txs_16 (id, tx_uid);


CREATE INDEX txs_16_args_height_idx ON public.txs_16_args USING btree (height);


CREATE INDEX txs_16_payment_asset_uid_idx ON public.txs_16_payment USING btree (asset_uid);


CREATE INDEX txs_16_payment_height_idx ON public.txs_16_payment USING btree (height);


CREATE INDEX txs_16_sender_uid_tx_uid_idx ON public.txs_16 USING btree (sender_uid, tx_uid);


CREATE INDEX txs_16_function_name_tx_uid_idx ON txs_16 (function_name, tx_uid);


CREATE INDEX txs_1_height_idx ON public.txs_1 USING btree (height);


CREATE INDEX txs_1_sender_uid_idx ON public.txs_1 USING btree (sender_uid);


CREATE INDEX txs_1_id_tx_uid_idx ON public.txs_1 (id, tx_uid);


CREATE INDEX txs_2_height_idx ON public.txs_2 USING btree (height);


CREATE INDEX txs_2_sender_uid_idx ON public.txs_2 USING hash (sender_uid);


CREATE INDEX txs_2_id_tx_uid_idx ON public.txs_2 (id, tx_uid);


CREATE INDEX txs_3_asset_uid_idx ON public.txs_3 USING hash (asset_uid);


CREATE INDEX txs_3_height_idx ON public.txs_3 USING btree (height);


CREATE INDEX txs_3_md5_script_idx ON public.txs_3 USING btree (md5((script)::text));


CREATE INDEX txs_3_sender_uid_idx ON public.txs_3 USING hash (sender_uid);


CREATE INDEX txs_3_id_tx_uid_idx ON public.txs_3 (id, tx_uid);


CREATE INDEX txs_4_asset_uid_idx ON public.txs_4 USING btree (asset_uid);


CREATE INDEX txs_4_asset_uid_tx_uid_idx ON public.txs_4 USING btree (asset_uid, tx_uid);


CREATE INDEX txs_4_height_idx ON public.txs_4 USING btree (height);


CREATE INDEX txs_4_recipient_address_uid_idx ON public.txs_4 USING btree (recipient_address_uid);


CREATE INDEX txs_4_sender_uid_idx ON public.txs_4 USING btree (sender_uid);


CREATE INDEX txs_4_id_tx_uid_idx ON public.txs_4 (id, tx_uid);


CREATE INDEX txs_4_recipient_address_uid_tx_uid_idx ON txs_4 (recipient_address_uid, tx_uid);


CREATE INDEX txs_4_sender_uid_tx_uid_idx ON txs_4 (sender_uid, tx_uid);


CREATE INDEX txs_4_asset_uid_tx_uid ON txs_4 (asset_uid, tx_uid);


CREATE INDEX txs_5_asset_uid_idx ON public.txs_5 USING hash (asset_uid);


CREATE INDEX txs_5_height_idx ON public.txs_5 USING btree (height);


CREATE INDEX txs_5_sender_uid_idx ON public.txs_5 USING hash (sender_uid);


CREATE INDEX txs_5_id_tx_uid_idx ON public.txs_5 (id, tx_uid);


CREATE INDEX txs_6_asset_uid_idx ON public.txs_6 USING hash (asset_uid);


CREATE INDEX txs_6_height_idx ON public.txs_6 USING btree (height);


CREATE INDEX txs_6_sender_uid_idx ON public.txs_6 USING hash (sender_uid);


CREATE INDEX txs_6_id_tx_uid_idx ON public.txs_6 (id, tx_uid);


CREATE INDEX txs_7_height_idx ON public.txs_7 USING btree (height);


CREATE INDEX txs_7_sender_uid_idx ON public.txs_7 USING btree (sender_uid);


CREATE INDEX txs_7_tx_uid_height_idx ON public.txs_7 USING btree (tx_uid, height);


CREATE INDEX txs_7_tx_uid_order1_uid_order2_uid_idx ON public.txs_7 USING btree (tx_uid, order1_uid, order2_uid);


CREATE INDEX txs_7_id_tx_uid_idx ON public.txs_7 (id, tx_uid);


CREATE INDEX txs_7_orders_amount_asset_uid_price_asset_uid_tuid_idx ON public.txs_7_orders USING btree (amount_asset_uid, price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_amount_asset_uid_tx_uid_idx ON public.txs_7_orders USING btree (amount_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_height_idx ON public.txs_7_orders USING btree (height);


CREATE INDEX txs_7_orders_order_sender_uid_tuid_idx ON public.txs_7_orders USING btree (order_sender_uid, tx_uid);


CREATE INDEX txs_7_orders_order_uid_tx_uid_idx ON public.txs_7_orders USING btree (order_uid, tx_uid);


CREATE INDEX txs_7_orders_price_asset_uid_tx_uid_idx ON public.txs_7_orders USING btree (price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_sender_uid_tuid_idx ON public.txs_7_orders USING btree (sender_uid, tx_uid);


CREATE INDEX txs_8_height_idx ON public.txs_8 USING btree (height);


CREATE INDEX txs_8_recipient_idx ON public.txs_8 USING btree (recipient_address_uid);


CREATE INDEX txs_8_recipient_address_uid_tx_uid_idx ON public.txs_8 USING btree (recipient_address_uid, tx_uid);


CREATE INDEX txs_8_sender_uid_idx ON public.txs_8 USING btree (sender_uid);


CREATE INDEX txs_8_id_tx_uid_idx ON public.txs_8 (id, tx_uid);


CREATE INDEX txs_9_height_idx ON public.txs_9 USING btree (height);


CREATE INDEX txs_9_sender_idx ON public.txs_9 USING hash (sender_uid);


CREATE index txs_9_id_tx_uid_idx ON public.txs_9 (id, tx_uid);


CREATE INDEX waves_data_height_desc_quantity_idx ON public.waves_data (height DESC NULLS LAST, quantity);


CREATE RULE block_delete AS
    ON DELETE TO public.blocks_raw DO DELETE FROM public.blocks
  WHERE (blocks.height = old.height);


CREATE TRIGGER block_insert_trigger BEFORE INSERT ON public.blocks_raw FOR EACH ROW EXECUTE PROCEDURE public.on_block_insert();


CREATE TRIGGER block_update_trigger BEFORE UPDATE ON public.blocks_raw FOR EACH ROW EXECUTE PROCEDURE public.on_block_update();


ALTER TABLE public.addresses
    ADD CONSTRAINT fk_blocks FOREIGN KEY (first_appeared_on_height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.assets_data
    ADD CONSTRAINT fk_blocks FOREIGN KEY (first_appeared_on_height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_1
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_10
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_11
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_13
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_14
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


ALTER TABLE public.orders
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_11_transfers
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_12_data
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_12
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_15
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_16
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs_7_orders
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.txs
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE public.waves_data
	ADD CONSTRAINT fk_waves_data FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
