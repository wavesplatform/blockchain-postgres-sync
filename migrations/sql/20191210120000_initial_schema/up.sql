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


CREATE FUNCTION public.create_asset(_asset_id character varying, _issuer_address_uid bigint, _name character varying, _description text, _height integer, _timestamp timestamp with time zone, _quantity bigint, _decimals smallint, _reissuable boolean, _has_script boolean, _min_sponsored_asset_fee numeric) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	declare
		asset_uid bigint;
	begin
		insert 
			into assets (asset_id, issuer_address_uid, asset_name, searchable_asset_name, description, first_appeared_on_height, issue_timestamp, quantity, decimals, reissuable, has_script, min_sponsored_asset_fee) 
			values (_asset_id, _issuer_address_uid, _name, to_tsvector(_name), _description, _height, _timestamp, _quantity, _decimals, _reissuable, _has_script, _min_sponsored_asset_fee) 
			on conflict (asset_id) 
			do update set 
                issuer_address_uid=EXCLUDED.issuer_address_uid,
				asset_name=EXCLUDED.asset_name, 
				searchable_asset_name=EXCLUDED.searchable_asset_name, 
				description=EXCLUDED.description, 
				reissuable=EXCLUDED.reissuable, 
				has_script=EXCLUDED.has_script, 
				min_sponsored_asset_fee=EXCLUDED.min_sponsored_asset_fee
			returning uid 
			into asset_uid;
		return asset_uid;
	END;
$$;


ALTER FUNCTION public.create_asset(_asset_id character varying, _issuer_address_uid bigint, _name character varying, _description text, _height integer, _timestamp timestamp with time zone, _quantity bigint, _decimals smallint, _reissuable boolean, _has_script boolean, _min_sponsored_asset_fee numeric) OWNER TO dba;


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
			select uid from assets where asset_id=aid into asset_uid;
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
        (CASE WHEN (b->>'version')::smallint < 5 THEN (b->'nxt-consensus'->>'base-target')::bigint ELSE (b->>'baseTarget')::bigint END),
        (CASE WHEN (b->>'version')::smallint < 5 THEN b->'nxt-consensus'->>'generation-signature' ELSE b->>'generationSignature' END),
		b->>'generator',
		b->>'signature',
		(b->>'fee')::bigint,
		(b->>'blocksize')::integer,
		(b->>'height')::integer,
		jsonb_array_cast_int(b->'features')::smallint[ ]
	)
	on conflict do nothing;

    if b->>'reward' is not null then
		update assets 
        set quantity = quantity + (b->>'reward')::bigint 
        where asset_id = 'WAVES';
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
  					 height,
                     sender_uid,
                     recipient_address_uid,
                     recipient_alias_uid,
                     amount)
  select
    -- common
    get_tuid_by_tx_id_and_time_stamp(t ->> 'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
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
		height,
		sender_uid,
		alias
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
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
  					  height,
                      sender_uid,
                      asset_uid,
                      attachment)
  SELECT
    -- common
    get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000)),
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
		height,
		sender_uid
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
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
		height,
		sender_uid,
	    script
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
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
		height,
		sender_uid,
	    asset_uid,
    	min_sponsored_asset_fee
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
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

	update assets
	set min_sponsored_asset_fee=(t->>'minSponsoredAssetFee')::bigint
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '14' and asset_id = t->>'assetId';
END
$$;


ALTER FUNCTION public.insert_txs_14(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_15(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_15 (
		tx_uid,
		height,
		sender_uid,
		asset_uid,
	    script
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
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

	update assets
	set has_script=(t->>'script' is not null)
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '15' and asset_id = t->>'assetId';
END
$$;


ALTER FUNCTION public.insert_txs_15(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_16(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_16 (
		tx_uid,
		height,
		sender_uid,
		dapp_address_uid,
	    function_name
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
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
		height,
		sender_uid,
		recipient_address_uid,
		recipient_alias_uid,
		amount
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
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
			t->>'script' is not null, 
			null
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
		height,
		sender_uid,
		asset_uid,
		quantity,
		reissuable
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
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

	update assets
	set 
		quantity = quantity::numeric + (t->>'quantity')::bigint, 
		reissuable = (t->>'reissuable')::bool
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '5' and asset_id = t->>'assetId';
END
$$;


ALTER FUNCTION public.insert_txs_5(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_6(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_6 (
		tx_uid,
		height,
		sender_uid,
		asset_uid,
		amount
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
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

	update assets
	set 
		quantity = quantity::numeric - (t->>'amount')::bigint
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '6' and asset_id = t->>'assetId';
END
$$;


ALTER FUNCTION public.insert_txs_6(b jsonb) OWNER TO dba;


CREATE FUNCTION public.insert_txs_7(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  insert into txs_7 (tx_uid,
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
		height,
		sender_uid,
		recipient_address_uid,
		recipient_alias_uid,
		amount
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
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
		height,
		sender_uid,
		lease_tx_uid
	)
	select
		-- common
		get_tuid_by_tx_id_and_time_stamp(t->>'id', to_timestamp((t->>'timestamp') :: DOUBLE PRECISION / 1000)),
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
    uid bigint NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
)
PARTITION BY RANGE (address);


ALTER TABLE public.addresses OWNER TO dba;


CREATE SEQUENCE public.addresses_uid_seq
    AS bigint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.addresses_uid_seq OWNER TO dba;


ALTER SEQUENCE public.addresses_uid_seq OWNED BY public.addresses.uid;



CREATE TABLE public.addresses_0_1 (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_0_1 FOR VALUES FROM ('3P0') TO ('3P1');


ALTER TABLE public.addresses_0_1 OWNER TO dba;


CREATE TABLE public.addresses_1_2 (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_1_2 FOR VALUES FROM ('3P1') TO ('3P2');


ALTER TABLE public.addresses_1_2 OWNER TO dba;


CREATE TABLE public.addresses_2_3 (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_2_3 FOR VALUES FROM ('3P2') TO ('3P3');


ALTER TABLE public.addresses_2_3 OWNER TO dba;


CREATE TABLE public.addresses_3_4 (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_3_4 FOR VALUES FROM ('3P3') TO ('3P4');


ALTER TABLE public.addresses_3_4 OWNER TO dba;


CREATE TABLE public.addresses_4_5 (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_4_5 FOR VALUES FROM ('3P4') TO ('3P5');


ALTER TABLE public.addresses_4_5 OWNER TO dba;


CREATE TABLE public.addresses_5_6 (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_5_6 FOR VALUES FROM ('3P5') TO ('3P6');


ALTER TABLE public.addresses_5_6 OWNER TO dba;


CREATE TABLE public.addresses_6_7 (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_6_7 FOR VALUES FROM ('3P6') TO ('3P7');


ALTER TABLE public.addresses_6_7 OWNER TO dba;


CREATE TABLE public.addresses_7_8 (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_7_8 FOR VALUES FROM ('3P7') TO ('3P8');


ALTER TABLE public.addresses_7_8 OWNER TO dba;


CREATE TABLE public.addresses_8_9 (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_8_9 FOR VALUES FROM ('3P8') TO ('3P9');


ALTER TABLE public.addresses_8_9 OWNER TO dba;


CREATE TABLE public.addresses_9_a (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_9_a FOR VALUES FROM ('3P9') TO ('3Pa');


ALTER TABLE public.addresses_9_a OWNER TO dba;


CREATE TABLE public.addresses_a_b (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_a_b FOR VALUES FROM ('3Pa') TO ('3Pb');


ALTER TABLE public.addresses_a_b OWNER TO dba;


CREATE TABLE public.addresses_b_c (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_b_c FOR VALUES FROM ('3Pb') TO ('3Pc');


ALTER TABLE public.addresses_b_c OWNER TO dba;


CREATE TABLE public.addresses_c_d (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_c_d FOR VALUES FROM ('3Pc') TO ('3Pd');


ALTER TABLE public.addresses_c_d OWNER TO dba;


CREATE TABLE public.addresses_d_e (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_d_e FOR VALUES FROM ('3Pd') TO ('3Pe');


ALTER TABLE public.addresses_d_e OWNER TO dba;


CREATE TABLE public.addresses_e_f (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_e_f FOR VALUES FROM ('3Pe') TO ('3Pf');


ALTER TABLE public.addresses_e_f OWNER TO dba;


CREATE TABLE public.addresses_f_g (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_f_g FOR VALUES FROM ('3Pf') TO ('3Pg');


ALTER TABLE public.addresses_f_g OWNER TO dba;


CREATE TABLE public.addresses_g_h (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_g_h FOR VALUES FROM ('3Pg') TO ('3Ph');


ALTER TABLE public.addresses_g_h OWNER TO dba;


CREATE TABLE public.addresses_h_i (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_h_i FOR VALUES FROM ('3Ph') TO ('3Pi');


ALTER TABLE public.addresses_h_i OWNER TO dba;


CREATE TABLE public.addresses_i_j (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_i_j FOR VALUES FROM ('3Pi') TO ('3Pj');


ALTER TABLE public.addresses_i_j OWNER TO dba;


CREATE TABLE public.addresses_j_k (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_j_k FOR VALUES FROM ('3Pj') TO ('3Pk');


ALTER TABLE public.addresses_j_k OWNER TO dba;


CREATE TABLE public.addresses_k_l (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_k_l FOR VALUES FROM ('3Pk') TO ('3Pl');


ALTER TABLE public.addresses_k_l OWNER TO dba;


CREATE TABLE public.addresses_l_m (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_l_m FOR VALUES FROM ('3Pl') TO ('3Pm');


ALTER TABLE public.addresses_l_m OWNER TO dba;


CREATE TABLE public.addresses_m_n (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_m_n FOR VALUES FROM ('3Pm') TO ('3Pn');


ALTER TABLE public.addresses_m_n OWNER TO dba;


CREATE TABLE public.addresses_n_o (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_n_o FOR VALUES FROM ('3Pn') TO ('3Po');


ALTER TABLE public.addresses_n_o OWNER TO dba;


CREATE TABLE public.addresses_o_p (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_o_p FOR VALUES FROM ('3Po') TO ('3Pp');


ALTER TABLE public.addresses_o_p OWNER TO dba;


CREATE TABLE public.addresses_p_q (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_p_q FOR VALUES FROM ('3Pp') TO ('3Pq');


ALTER TABLE public.addresses_p_q OWNER TO dba;


CREATE TABLE public.addresses_q_r (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_q_r FOR VALUES FROM ('3Pq') TO ('3Pr');


ALTER TABLE public.addresses_q_r OWNER TO dba;


CREATE TABLE public.addresses_r_s (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_r_s FOR VALUES FROM ('3Pr') TO ('3Ps');


ALTER TABLE public.addresses_r_s OWNER TO dba;


CREATE TABLE public.addresses_s_t (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_s_t FOR VALUES FROM ('3Ps') TO ('3Pt');


ALTER TABLE public.addresses_s_t OWNER TO dba;


CREATE TABLE public.addresses_t_u (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_t_u FOR VALUES FROM ('3Pt') TO ('3Pu');


ALTER TABLE public.addresses_t_u OWNER TO dba;


CREATE TABLE public.addresses_u_v (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_u_v FOR VALUES FROM ('3Pu') TO ('3Pv');


ALTER TABLE public.addresses_u_v OWNER TO dba;


CREATE TABLE public.addresses_v_w (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_v_w FOR VALUES FROM ('3Pv') TO ('3Pw');


ALTER TABLE public.addresses_v_w OWNER TO dba;


CREATE TABLE public.addresses_w_x (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_w_x FOR VALUES FROM ('3Pw') TO ('3Px');


ALTER TABLE public.addresses_w_x OWNER TO dba;


CREATE TABLE public.addresses_x_y (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_x_y FOR VALUES FROM ('3Px') TO ('3Py');


ALTER TABLE public.addresses_x_y OWNER TO dba;


CREATE TABLE public.addresses_y_z (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_y_z FOR VALUES FROM ('3Py') TO ('3Pz');


ALTER TABLE public.addresses_y_z OWNER TO dba;


CREATE TABLE public.addresses_z (
    uid bigint DEFAULT nextval('public.addresses_uid_seq'::regclass) NOT NULL,
    address character varying NOT NULL,
    public_key character varying,
    first_appeared_on_height integer NOT NULL
);
ALTER TABLE ONLY public.addresses ATTACH PARTITION public.addresses_z DEFAULT;


ALTER TABLE public.addresses_z OWNER TO dba;


CREATE TABLE public.assets (
    uid bigint NOT NULL,
    issuer_address_uid bigint,
    asset_id character varying NOT NULL,
    first_appeared_on_height integer,
    asset_name character varying NOT NULL,
    searchable_asset_name tsvector NOT NULL,
    description text,
    decimals smallint NOT NULL,
    ticker text,
    issue_timestamp timestamp with time zone,
    quantity numeric,
    reissuable boolean,
    has_script boolean,
    min_sponsored_asset_fee numeric
);

INSERT INTO public.assets VALUES (0, null, 'WAVES', null, 'Waves', to_tsvector('Waves'), '', 8, 'WAVES', '2016-04-12 00:00:00', 10000000000000000, false, false, null);

ALTER TABLE public.assets OWNER TO dba;


CREATE TABLE public.assets_metadata (
    asset_uid bigint NOT NULL,
    asset_name character varying,
    ticker character varying,
    height integer
);


ALTER TABLE public.assets_metadata OWNER TO dba;


CREATE SEQUENCE public.assets_uid_seq
    AS bigint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.assets_uid_seq OWNER TO dba;


ALTER SEQUENCE public.assets_uid_seq OWNED BY public.assets.uid;



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


CREATE TABLE public.blocks_raw (
    height integer NOT NULL,
    b jsonb NOT NULL
);


ALTER TABLE public.blocks_raw OWNER TO dba;


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


ALTER TABLE public.candles OWNER TO dba;


CREATE TABLE public.orders (
    uid bigint NOT NULL,
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    "order" jsonb NOT NULL
)
PARTITION BY RANGE (uid);


ALTER TABLE public.orders OWNER TO dba;


CREATE SEQUENCE public.orders_uid_seq
    AS bigint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.orders_uid_seq OWNER TO dba;


ALTER SEQUENCE public.orders_uid_seq OWNED BY public.orders.uid;



CREATE TABLE public.orders_0_30000000 (
    uid bigint DEFAULT nextval('public.orders_uid_seq'::regclass) NOT NULL,
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    "order" jsonb NOT NULL
);
ALTER TABLE ONLY public.orders ATTACH PARTITION public.orders_0_30000000 FOR VALUES FROM (0) TO (30000000);


ALTER TABLE public.orders_0_30000000 OWNER TO dba;


CREATE TABLE public.orders_120000000_150000000 (
    uid bigint DEFAULT nextval('public.orders_uid_seq'::regclass) NOT NULL,
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    "order" jsonb NOT NULL
);
ALTER TABLE ONLY public.orders ATTACH PARTITION public.orders_120000000_150000000 FOR VALUES FROM (120000000) TO (150000000);


ALTER TABLE public.orders_120000000_150000000 OWNER TO dba;


CREATE TABLE public.orders_150000000_180000000 (
    uid bigint DEFAULT nextval('public.orders_uid_seq'::regclass) NOT NULL,
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    "order" jsonb NOT NULL
);
ALTER TABLE ONLY public.orders ATTACH PARTITION public.orders_150000000_180000000 FOR VALUES FROM (150000000) TO (180000000);


ALTER TABLE public.orders_150000000_180000000 OWNER TO dba;


CREATE TABLE public.orders_180000000_210000000 (
    uid bigint DEFAULT nextval('public.orders_uid_seq'::regclass) NOT NULL,
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    "order" jsonb NOT NULL
);
ALTER TABLE ONLY public.orders ATTACH PARTITION public.orders_180000000_210000000 FOR VALUES FROM (180000000) TO (210000000);


ALTER TABLE public.orders_180000000_210000000 OWNER TO dba;


CREATE TABLE public.orders_210000000_240000000 (
    uid bigint DEFAULT nextval('public.orders_uid_seq'::regclass) NOT NULL,
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    "order" jsonb NOT NULL
);
ALTER TABLE ONLY public.orders ATTACH PARTITION public.orders_210000000_240000000 FOR VALUES FROM (210000000) TO (240000000);


ALTER TABLE public.orders_210000000_240000000 OWNER TO dba;


CREATE TABLE public.orders_240000000_270000000 (
    uid bigint DEFAULT nextval('public.orders_uid_seq'::regclass) NOT NULL,
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    "order" jsonb NOT NULL
);
ALTER TABLE ONLY public.orders ATTACH PARTITION public.orders_240000000_270000000 FOR VALUES FROM (240000000) TO (270000000);


ALTER TABLE public.orders_240000000_270000000 OWNER TO dba;


CREATE TABLE public.orders_270000000_300000000 (
    uid bigint DEFAULT nextval('public.orders_uid_seq'::regclass) NOT NULL,
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    "order" jsonb NOT NULL
);
ALTER TABLE ONLY public.orders ATTACH PARTITION public.orders_270000000_300000000 FOR VALUES FROM (270000000) TO (300000000);


ALTER TABLE public.orders_270000000_300000000 OWNER TO dba;


CREATE TABLE public.orders_300000000_330000000 (
    uid bigint DEFAULT nextval('public.orders_uid_seq'::regclass) NOT NULL,
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    "order" jsonb NOT NULL
);
ALTER TABLE ONLY public.orders ATTACH PARTITION public.orders_300000000_330000000 FOR VALUES FROM (300000000) TO (330000000);


ALTER TABLE public.orders_300000000_330000000 OWNER TO dba;


CREATE TABLE public.orders_30000000_60000000 (
    uid bigint DEFAULT nextval('public.orders_uid_seq'::regclass) NOT NULL,
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    "order" jsonb NOT NULL
);
ALTER TABLE ONLY public.orders ATTACH PARTITION public.orders_30000000_60000000 FOR VALUES FROM (30000000) TO (60000000);


ALTER TABLE public.orders_30000000_60000000 OWNER TO dba;


CREATE TABLE public.orders_60000000_90000000 (
    uid bigint DEFAULT nextval('public.orders_uid_seq'::regclass) NOT NULL,
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    "order" jsonb NOT NULL
);
ALTER TABLE ONLY public.orders ATTACH PARTITION public.orders_60000000_90000000 FOR VALUES FROM (60000000) TO (90000000);


ALTER TABLE public.orders_60000000_90000000 OWNER TO dba;


CREATE TABLE public.orders_90000000_120000000 (
    uid bigint DEFAULT nextval('public.orders_uid_seq'::regclass) NOT NULL,
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    "order" jsonb NOT NULL
);
ALTER TABLE ONLY public.orders ATTACH PARTITION public.orders_90000000_120000000 FOR VALUES FROM (90000000) TO (120000000);


ALTER TABLE public.orders_90000000_120000000 OWNER TO dba;


CREATE TABLE public.orders_default (
    uid bigint DEFAULT nextval('public.orders_uid_seq'::regclass) NOT NULL,
    tx_uid bigint NOT NULL,
    id character varying NOT NULL,
    height integer NOT NULL,
    "order" jsonb NOT NULL
);
ALTER TABLE ONLY public.orders ATTACH PARTITION public.orders_default DEFAULT;


ALTER TABLE public.orders_default OWNER TO dba;


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


ALTER TABLE public.pairs OWNER TO dba;


CREATE TABLE public.txs (
    uid bigint NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
)
PARTITION BY RANGE (id);


ALTER TABLE public.txs OWNER TO dba;


CREATE SEQUENCE public.txs_uid_seq
    AS bigint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.txs_uid_seq OWNER TO dba;


ALTER SEQUENCE public.txs_uid_seq OWNED BY public.txs.uid;



CREATE TABLE public.txs_0_1 (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_0_1 FOR VALUES FROM ('0') TO ('1');


ALTER TABLE public.txs_0_1 OWNER TO dba;


CREATE TABLE public.txs_1 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    recipient_alias_uid bigint
)
PARTITION BY RANGE (tx_uid);


ALTER TABLE public.txs_1 OWNER TO dba;


CREATE TABLE public.txs_10 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    alias character varying NOT NULL
)
PARTITION BY RANGE (tx_uid);


ALTER TABLE public.txs_10 OWNER TO dba;


CREATE TABLE public.txs_10_default (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    alias character varying NOT NULL
);
ALTER TABLE ONLY public.txs_10 ATTACH PARTITION public.txs_10_default DEFAULT;


ALTER TABLE public.txs_10_default OWNER TO dba;


CREATE TABLE public.txs_11 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint,
    attachment character varying NOT NULL
)
PARTITION BY RANGE (tx_uid);


ALTER TABLE public.txs_11 OWNER TO dba;


CREATE TABLE public.txs_11_default (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint,
    attachment character varying NOT NULL
);
ALTER TABLE ONLY public.txs_11 ATTACH PARTITION public.txs_11_default DEFAULT;


ALTER TABLE public.txs_11_default OWNER TO dba;


CREATE TABLE public.txs_11_transfers (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
)
PARTITION BY RANGE (tx_uid);


ALTER TABLE public.txs_11_transfers OWNER TO dba;


CREATE TABLE public.txs_11_transfers_0_30000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_0_30000000 FOR VALUES FROM (0) TO (30000000);


ALTER TABLE public.txs_11_transfers_0_30000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_120000000_150000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_120000000_150000000 FOR VALUES FROM (120000000) TO (150000000);


ALTER TABLE public.txs_11_transfers_120000000_150000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_150000000_180000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_150000000_180000000 FOR VALUES FROM (150000000) TO (180000000);


ALTER TABLE public.txs_11_transfers_150000000_180000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_180000000_210000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_180000000_210000000 FOR VALUES FROM (180000000) TO (210000000);


ALTER TABLE public.txs_11_transfers_180000000_210000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_210000000_240000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_210000000_240000000 FOR VALUES FROM (210000000) TO (240000000);


ALTER TABLE public.txs_11_transfers_210000000_240000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_240000000_270000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_240000000_270000000 FOR VALUES FROM (240000000) TO (270000000);


ALTER TABLE public.txs_11_transfers_240000000_270000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_270000000_300000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_270000000_300000000 FOR VALUES FROM (270000000) TO (300000000);


ALTER TABLE public.txs_11_transfers_270000000_300000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_300000000_330000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_300000000_330000000 FOR VALUES FROM (300000000) TO (330000000);


ALTER TABLE public.txs_11_transfers_300000000_330000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_30000000_60000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_30000000_60000000 FOR VALUES FROM (30000000) TO (60000000);


ALTER TABLE public.txs_11_transfers_30000000_60000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_330000000_360000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_330000000_360000000 FOR VALUES FROM (330000000) TO (360000000);


ALTER TABLE public.txs_11_transfers_330000000_360000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_360000000_390000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_360000000_390000000 FOR VALUES FROM (360000000) TO (390000000);


ALTER TABLE public.txs_11_transfers_360000000_390000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_390000000_420000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_390000000_420000000 FOR VALUES FROM (390000000) TO (420000000);


ALTER TABLE public.txs_11_transfers_390000000_420000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_420000000_450000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_420000000_450000000 FOR VALUES FROM (420000000) TO (450000000);


ALTER TABLE public.txs_11_transfers_420000000_450000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_450000000_480000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_450000000_480000000 FOR VALUES FROM (450000000) TO (480000000);


ALTER TABLE public.txs_11_transfers_450000000_480000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_480000000_510000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_480000000_510000000 FOR VALUES FROM (480000000) TO (510000000);


ALTER TABLE public.txs_11_transfers_480000000_510000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_510000000_540000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_510000000_540000000 FOR VALUES FROM (510000000) TO (540000000);


ALTER TABLE public.txs_11_transfers_510000000_540000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_540000000_570000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_540000000_570000000 FOR VALUES FROM (540000000) TO (570000000);


ALTER TABLE public.txs_11_transfers_540000000_570000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_570000000_600000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_570000000_600000000 FOR VALUES FROM (570000000) TO (600000000);


ALTER TABLE public.txs_11_transfers_570000000_600000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_600000000_630000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_600000000_630000000 FOR VALUES FROM (600000000) TO (630000000);


ALTER TABLE public.txs_11_transfers_600000000_630000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_60000000_90000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_60000000_90000000 FOR VALUES FROM (60000000) TO (90000000);


ALTER TABLE public.txs_11_transfers_60000000_90000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_90000000_120000000 (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_90000000_120000000 FOR VALUES FROM (90000000) TO (120000000);


ALTER TABLE public.txs_11_transfers_90000000_120000000 OWNER TO dba;


CREATE TABLE public.txs_11_transfers_default (
    tx_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL,
    height integer NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_11_transfers ATTACH PARTITION public.txs_11_transfers_default DEFAULT;


ALTER TABLE public.txs_11_transfers_default OWNER TO dba;


CREATE TABLE public.txs_12 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL
)
PARTITION BY RANGE (tx_uid);


ALTER TABLE public.txs_12 OWNER TO dba;


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


ALTER TABLE public.txs_12_data OWNER TO dba;


CREATE TABLE public.txs_12_data_0_30000000 (
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
ALTER TABLE ONLY public.txs_12_data ATTACH PARTITION public.txs_12_data_0_30000000 FOR VALUES FROM (0) TO (30000000);


ALTER TABLE public.txs_12_data_0_30000000 OWNER TO dba;


CREATE TABLE public.txs_12_data_120000000_150000000 (
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
ALTER TABLE ONLY public.txs_12_data ATTACH PARTITION public.txs_12_data_120000000_150000000 FOR VALUES FROM (120000000) TO (150000000);


ALTER TABLE public.txs_12_data_120000000_150000000 OWNER TO dba;


CREATE TABLE public.txs_12_data_150000000_180000000 (
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
ALTER TABLE ONLY public.txs_12_data ATTACH PARTITION public.txs_12_data_150000000_180000000 FOR VALUES FROM (150000000) TO (180000000);


ALTER TABLE public.txs_12_data_150000000_180000000 OWNER TO dba;


CREATE TABLE public.txs_12_data_180000000_210000000 (
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
ALTER TABLE ONLY public.txs_12_data ATTACH PARTITION public.txs_12_data_180000000_210000000 FOR VALUES FROM (180000000) TO (210000000);


ALTER TABLE public.txs_12_data_180000000_210000000 OWNER TO dba;


CREATE TABLE public.txs_12_data_210000000_240000000 (
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
ALTER TABLE ONLY public.txs_12_data ATTACH PARTITION public.txs_12_data_210000000_240000000 FOR VALUES FROM (210000000) TO (240000000);


ALTER TABLE public.txs_12_data_210000000_240000000 OWNER TO dba;


CREATE TABLE public.txs_12_data_240000000_270000000 (
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
ALTER TABLE ONLY public.txs_12_data ATTACH PARTITION public.txs_12_data_240000000_270000000 FOR VALUES FROM (240000000) TO (270000000);


ALTER TABLE public.txs_12_data_240000000_270000000 OWNER TO dba;


CREATE TABLE public.txs_12_data_270000000_300000000 (
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
ALTER TABLE ONLY public.txs_12_data ATTACH PARTITION public.txs_12_data_270000000_300000000 FOR VALUES FROM (270000000) TO (300000000);


ALTER TABLE public.txs_12_data_270000000_300000000 OWNER TO dba;


CREATE TABLE public.txs_12_data_300000000_330000000 (
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
ALTER TABLE ONLY public.txs_12_data ATTACH PARTITION public.txs_12_data_300000000_330000000 FOR VALUES FROM (300000000) TO (330000000);


ALTER TABLE public.txs_12_data_300000000_330000000 OWNER TO dba;


CREATE TABLE public.txs_12_data_30000000_60000000 (
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
ALTER TABLE ONLY public.txs_12_data ATTACH PARTITION public.txs_12_data_30000000_60000000 FOR VALUES FROM (30000000) TO (60000000);


ALTER TABLE public.txs_12_data_30000000_60000000 OWNER TO dba;


CREATE TABLE public.txs_12_data_60000000_90000000 (
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
ALTER TABLE ONLY public.txs_12_data ATTACH PARTITION public.txs_12_data_60000000_90000000 FOR VALUES FROM (60000000) TO (90000000);


ALTER TABLE public.txs_12_data_60000000_90000000 OWNER TO dba;


CREATE TABLE public.txs_12_data_90000000_120000000 (
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
ALTER TABLE ONLY public.txs_12_data ATTACH PARTITION public.txs_12_data_90000000_120000000 FOR VALUES FROM (90000000) TO (120000000);


ALTER TABLE public.txs_12_data_90000000_120000000 OWNER TO dba;


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


ALTER TABLE public.txs_12_data_default OWNER TO dba;


CREATE TABLE public.txs_12_default (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL
);
ALTER TABLE ONLY public.txs_12 ATTACH PARTITION public.txs_12_default DEFAULT;


ALTER TABLE public.txs_12_default OWNER TO dba;


CREATE TABLE public.txs_13 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    script character varying
)
PARTITION BY RANGE (tx_uid);


ALTER TABLE public.txs_13 OWNER TO dba;


CREATE TABLE public.txs_13_default (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    script character varying
);
ALTER TABLE ONLY public.txs_13 ATTACH PARTITION public.txs_13_default DEFAULT;


ALTER TABLE public.txs_13_default OWNER TO dba;


CREATE TABLE public.txs_14 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    min_sponsored_asset_fee bigint
)
PARTITION BY RANGE (tx_uid);


ALTER TABLE public.txs_14 OWNER TO dba;


CREATE TABLE public.txs_14_default (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    min_sponsored_asset_fee bigint
);
ALTER TABLE ONLY public.txs_14 ATTACH PARTITION public.txs_14_default DEFAULT;


ALTER TABLE public.txs_14_default OWNER TO dba;


CREATE TABLE public.txs_15 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    script character varying
)
PARTITION BY RANGE (tx_uid);


ALTER TABLE public.txs_15 OWNER TO dba;


CREATE TABLE public.txs_15_default (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    script character varying
);
ALTER TABLE ONLY public.txs_15 ATTACH PARTITION public.txs_15_default DEFAULT;


ALTER TABLE public.txs_15_default OWNER TO dba;


CREATE TABLE public.txs_16 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    dapp_address_uid bigint NOT NULL,
    function_name character varying,
    dapp_alias_uid bigint
)
PARTITION BY RANGE (tx_uid);


ALTER TABLE public.txs_16 OWNER TO dba;


CREATE TABLE public.txs_16_0_30000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    dapp_address_uid bigint NOT NULL,
    function_name character varying,
    dapp_alias_uid bigint
);
ALTER TABLE ONLY public.txs_16 ATTACH PARTITION public.txs_16_0_30000000 FOR VALUES FROM (0) TO (30000000);


ALTER TABLE public.txs_16_0_30000000 OWNER TO dba;


CREATE TABLE public.txs_16_120000001_150000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    dapp_address_uid bigint NOT NULL,
    function_name character varying,
    dapp_alias_uid bigint
);
ALTER TABLE ONLY public.txs_16 ATTACH PARTITION public.txs_16_120000001_150000000 FOR VALUES FROM (120000001) TO (150000000);


ALTER TABLE public.txs_16_120000001_150000000 OWNER TO dba;


CREATE TABLE public.txs_16_150000001_180000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    dapp_address_uid bigint NOT NULL,
    function_name character varying,
    dapp_alias_uid bigint
);
ALTER TABLE ONLY public.txs_16 ATTACH PARTITION public.txs_16_150000001_180000000 FOR VALUES FROM (150000001) TO (180000000);


ALTER TABLE public.txs_16_150000001_180000000 OWNER TO dba;


CREATE TABLE public.txs_16_180000001_210000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    dapp_address_uid bigint NOT NULL,
    function_name character varying,
    dapp_alias_uid bigint
);
ALTER TABLE ONLY public.txs_16 ATTACH PARTITION public.txs_16_180000001_210000000 FOR VALUES FROM (180000001) TO (210000000);


ALTER TABLE public.txs_16_180000001_210000000 OWNER TO dba;


CREATE TABLE public.txs_16_210000001_240000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    dapp_address_uid bigint NOT NULL,
    function_name character varying,
    dapp_alias_uid bigint
);
ALTER TABLE ONLY public.txs_16 ATTACH PARTITION public.txs_16_210000001_240000000 FOR VALUES FROM (210000001) TO (240000000);


ALTER TABLE public.txs_16_210000001_240000000 OWNER TO dba;


CREATE TABLE public.txs_16_240000001_270000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    dapp_address_uid bigint NOT NULL,
    function_name character varying,
    dapp_alias_uid bigint
);
ALTER TABLE ONLY public.txs_16 ATTACH PARTITION public.txs_16_240000001_270000000 FOR VALUES FROM (240000001) TO (270000000);


ALTER TABLE public.txs_16_240000001_270000000 OWNER TO dba;


CREATE TABLE public.txs_16_270000001_300000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    dapp_address_uid bigint NOT NULL,
    function_name character varying,
    dapp_alias_uid bigint
);
ALTER TABLE ONLY public.txs_16 ATTACH PARTITION public.txs_16_270000001_300000000 FOR VALUES FROM (270000001) TO (300000000);


ALTER TABLE public.txs_16_270000001_300000000 OWNER TO dba;


CREATE TABLE public.txs_16_300000001_330000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    dapp_address_uid bigint NOT NULL,
    function_name character varying,
    dapp_alias_uid bigint
);
ALTER TABLE ONLY public.txs_16 ATTACH PARTITION public.txs_16_300000001_330000000 FOR VALUES FROM (300000001) TO (330000000);


ALTER TABLE public.txs_16_300000001_330000000 OWNER TO dba;


CREATE TABLE public.txs_16_30000001_60000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    dapp_address_uid bigint NOT NULL,
    function_name character varying,
    dapp_alias_uid bigint
);
ALTER TABLE ONLY public.txs_16 ATTACH PARTITION public.txs_16_30000001_60000000 FOR VALUES FROM (30000001) TO (60000000);


ALTER TABLE public.txs_16_30000001_60000000 OWNER TO dba;


CREATE TABLE public.txs_16_60000001_90000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    dapp_address_uid bigint NOT NULL,
    function_name character varying,
    dapp_alias_uid bigint
);
ALTER TABLE ONLY public.txs_16 ATTACH PARTITION public.txs_16_60000001_90000000 FOR VALUES FROM (60000001) TO (90000000);


ALTER TABLE public.txs_16_60000001_90000000 OWNER TO dba;


CREATE TABLE public.txs_16_90000001_120000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    dapp_address_uid bigint NOT NULL,
    function_name character varying,
    dapp_alias_uid bigint
);
ALTER TABLE ONLY public.txs_16 ATTACH PARTITION public.txs_16_90000001_120000000 FOR VALUES FROM (90000001) TO (120000000);


ALTER TABLE public.txs_16_90000001_120000000 OWNER TO dba;


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


ALTER TABLE public.txs_16_args OWNER TO dba;


CREATE TABLE public.txs_16_args_0_30000000 (
    arg_type text NOT NULL,
    arg_value_integer bigint,
    arg_value_boolean boolean,
    arg_value_binary text,
    arg_value_string text,
    position_in_args smallint NOT NULL,
    tx_uid bigint NOT NULL,
    height integer
);
ALTER TABLE ONLY public.txs_16_args ATTACH PARTITION public.txs_16_args_0_30000000 FOR VALUES FROM (0) TO (30000000);


ALTER TABLE public.txs_16_args_0_30000000 OWNER TO dba;


CREATE TABLE public.txs_16_args_120000000_150000000 (
    arg_type text NOT NULL,
    arg_value_integer bigint,
    arg_value_boolean boolean,
    arg_value_binary text,
    arg_value_string text,
    position_in_args smallint NOT NULL,
    tx_uid bigint NOT NULL,
    height integer
);
ALTER TABLE ONLY public.txs_16_args ATTACH PARTITION public.txs_16_args_120000000_150000000 FOR VALUES FROM (120000000) TO (150000000);


ALTER TABLE public.txs_16_args_120000000_150000000 OWNER TO dba;


CREATE TABLE public.txs_16_args_150000000_180000000 (
    arg_type text NOT NULL,
    arg_value_integer bigint,
    arg_value_boolean boolean,
    arg_value_binary text,
    arg_value_string text,
    position_in_args smallint NOT NULL,
    tx_uid bigint NOT NULL,
    height integer
);
ALTER TABLE ONLY public.txs_16_args ATTACH PARTITION public.txs_16_args_150000000_180000000 FOR VALUES FROM (150000000) TO (180000000);


ALTER TABLE public.txs_16_args_150000000_180000000 OWNER TO dba;


CREATE TABLE public.txs_16_args_180000000_210000000 (
    arg_type text NOT NULL,
    arg_value_integer bigint,
    arg_value_boolean boolean,
    arg_value_binary text,
    arg_value_string text,
    position_in_args smallint NOT NULL,
    tx_uid bigint NOT NULL,
    height integer
);
ALTER TABLE ONLY public.txs_16_args ATTACH PARTITION public.txs_16_args_180000000_210000000 FOR VALUES FROM (180000000) TO (210000000);


ALTER TABLE public.txs_16_args_180000000_210000000 OWNER TO dba;


CREATE TABLE public.txs_16_args_210000000_240000000 (
    arg_type text NOT NULL,
    arg_value_integer bigint,
    arg_value_boolean boolean,
    arg_value_binary text,
    arg_value_string text,
    position_in_args smallint NOT NULL,
    tx_uid bigint NOT NULL,
    height integer
);
ALTER TABLE ONLY public.txs_16_args ATTACH PARTITION public.txs_16_args_210000000_240000000 FOR VALUES FROM (210000000) TO (240000000);


ALTER TABLE public.txs_16_args_210000000_240000000 OWNER TO dba;


CREATE TABLE public.txs_16_args_240000000_270000000 (
    arg_type text NOT NULL,
    arg_value_integer bigint,
    arg_value_boolean boolean,
    arg_value_binary text,
    arg_value_string text,
    position_in_args smallint NOT NULL,
    tx_uid bigint NOT NULL,
    height integer
);
ALTER TABLE ONLY public.txs_16_args ATTACH PARTITION public.txs_16_args_240000000_270000000 FOR VALUES FROM (240000000) TO (270000000);


ALTER TABLE public.txs_16_args_240000000_270000000 OWNER TO dba;


CREATE TABLE public.txs_16_args_270000000_300000000 (
    arg_type text NOT NULL,
    arg_value_integer bigint,
    arg_value_boolean boolean,
    arg_value_binary text,
    arg_value_string text,
    position_in_args smallint NOT NULL,
    tx_uid bigint NOT NULL,
    height integer
);
ALTER TABLE ONLY public.txs_16_args ATTACH PARTITION public.txs_16_args_270000000_300000000 FOR VALUES FROM (270000000) TO (300000000);


ALTER TABLE public.txs_16_args_270000000_300000000 OWNER TO dba;


CREATE TABLE public.txs_16_args_300000000_330000000 (
    arg_type text NOT NULL,
    arg_value_integer bigint,
    arg_value_boolean boolean,
    arg_value_binary text,
    arg_value_string text,
    position_in_args smallint NOT NULL,
    tx_uid bigint NOT NULL,
    height integer
);
ALTER TABLE ONLY public.txs_16_args ATTACH PARTITION public.txs_16_args_300000000_330000000 FOR VALUES FROM (300000000) TO (330000000);


ALTER TABLE public.txs_16_args_300000000_330000000 OWNER TO dba;


CREATE TABLE public.txs_16_args_30000000_60000000 (
    arg_type text NOT NULL,
    arg_value_integer bigint,
    arg_value_boolean boolean,
    arg_value_binary text,
    arg_value_string text,
    position_in_args smallint NOT NULL,
    tx_uid bigint NOT NULL,
    height integer
);
ALTER TABLE ONLY public.txs_16_args ATTACH PARTITION public.txs_16_args_30000000_60000000 FOR VALUES FROM (30000000) TO (60000000);


ALTER TABLE public.txs_16_args_30000000_60000000 OWNER TO dba;


CREATE TABLE public.txs_16_args_60000000_90000000 (
    arg_type text NOT NULL,
    arg_value_integer bigint,
    arg_value_boolean boolean,
    arg_value_binary text,
    arg_value_string text,
    position_in_args smallint NOT NULL,
    tx_uid bigint NOT NULL,
    height integer
);
ALTER TABLE ONLY public.txs_16_args ATTACH PARTITION public.txs_16_args_60000000_90000000 FOR VALUES FROM (60000000) TO (90000000);


ALTER TABLE public.txs_16_args_60000000_90000000 OWNER TO dba;


CREATE TABLE public.txs_16_args_90000000_120000000 (
    arg_type text NOT NULL,
    arg_value_integer bigint,
    arg_value_boolean boolean,
    arg_value_binary text,
    arg_value_string text,
    position_in_args smallint NOT NULL,
    tx_uid bigint NOT NULL,
    height integer
);
ALTER TABLE ONLY public.txs_16_args ATTACH PARTITION public.txs_16_args_90000000_120000000 FOR VALUES FROM (90000000) TO (120000000);


ALTER TABLE public.txs_16_args_90000000_120000000 OWNER TO dba;


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


ALTER TABLE public.txs_16_args_default OWNER TO dba;


CREATE TABLE public.txs_16_default (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    dapp_address_uid bigint NOT NULL,
    function_name character varying,
    dapp_alias_uid bigint
);
ALTER TABLE ONLY public.txs_16 ATTACH PARTITION public.txs_16_default DEFAULT;


ALTER TABLE public.txs_16_default OWNER TO dba;


CREATE TABLE public.txs_16_payment (
    tx_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_payment smallint NOT NULL,
    height integer,
    asset_uid bigint
)
PARTITION BY RANGE (tx_uid);


ALTER TABLE public.txs_16_payment OWNER TO dba;


CREATE TABLE public.txs_16_payment_0_30000000 (
    tx_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_payment smallint NOT NULL,
    height integer,
    asset_uid bigint
);
ALTER TABLE ONLY public.txs_16_payment ATTACH PARTITION public.txs_16_payment_0_30000000 FOR VALUES FROM (0) TO (30000000);


ALTER TABLE public.txs_16_payment_0_30000000 OWNER TO dba;


CREATE TABLE public.txs_16_payment_120000000_150000000 (
    tx_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_payment smallint NOT NULL,
    height integer,
    asset_uid bigint
);
ALTER TABLE ONLY public.txs_16_payment ATTACH PARTITION public.txs_16_payment_120000000_150000000 FOR VALUES FROM (120000000) TO (150000000);


ALTER TABLE public.txs_16_payment_120000000_150000000 OWNER TO dba;


CREATE TABLE public.txs_16_payment_150000000_180000000 (
    tx_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_payment smallint NOT NULL,
    height integer,
    asset_uid bigint
);
ALTER TABLE ONLY public.txs_16_payment ATTACH PARTITION public.txs_16_payment_150000000_180000000 FOR VALUES FROM (150000000) TO (180000000);


ALTER TABLE public.txs_16_payment_150000000_180000000 OWNER TO dba;


CREATE TABLE public.txs_16_payment_180000000_210000000 (
    tx_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_payment smallint NOT NULL,
    height integer,
    asset_uid bigint
);
ALTER TABLE ONLY public.txs_16_payment ATTACH PARTITION public.txs_16_payment_180000000_210000000 FOR VALUES FROM (180000000) TO (210000000);


ALTER TABLE public.txs_16_payment_180000000_210000000 OWNER TO dba;


CREATE TABLE public.txs_16_payment_210000000_240000000 (
    tx_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_payment smallint NOT NULL,
    height integer,
    asset_uid bigint
);
ALTER TABLE ONLY public.txs_16_payment ATTACH PARTITION public.txs_16_payment_210000000_240000000 FOR VALUES FROM (210000000) TO (240000000);


ALTER TABLE public.txs_16_payment_210000000_240000000 OWNER TO dba;


CREATE TABLE public.txs_16_payment_240000000_270000000 (
    tx_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_payment smallint NOT NULL,
    height integer,
    asset_uid bigint
);
ALTER TABLE ONLY public.txs_16_payment ATTACH PARTITION public.txs_16_payment_240000000_270000000 FOR VALUES FROM (240000000) TO (270000000);


ALTER TABLE public.txs_16_payment_240000000_270000000 OWNER TO dba;


CREATE TABLE public.txs_16_payment_270000000_300000000 (
    tx_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_payment smallint NOT NULL,
    height integer,
    asset_uid bigint
);
ALTER TABLE ONLY public.txs_16_payment ATTACH PARTITION public.txs_16_payment_270000000_300000000 FOR VALUES FROM (270000000) TO (300000000);


ALTER TABLE public.txs_16_payment_270000000_300000000 OWNER TO dba;


CREATE TABLE public.txs_16_payment_300000000_330000000 (
    tx_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_payment smallint NOT NULL,
    height integer,
    asset_uid bigint
);
ALTER TABLE ONLY public.txs_16_payment ATTACH PARTITION public.txs_16_payment_300000000_330000000 FOR VALUES FROM (300000000) TO (330000000);


ALTER TABLE public.txs_16_payment_300000000_330000000 OWNER TO dba;


CREATE TABLE public.txs_16_payment_30000000_60000000 (
    tx_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_payment smallint NOT NULL,
    height integer,
    asset_uid bigint
);
ALTER TABLE ONLY public.txs_16_payment ATTACH PARTITION public.txs_16_payment_30000000_60000000 FOR VALUES FROM (30000000) TO (60000000);


ALTER TABLE public.txs_16_payment_30000000_60000000 OWNER TO dba;


CREATE TABLE public.txs_16_payment_60000000_90000000 (
    tx_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_payment smallint NOT NULL,
    height integer,
    asset_uid bigint
);
ALTER TABLE ONLY public.txs_16_payment ATTACH PARTITION public.txs_16_payment_60000000_90000000 FOR VALUES FROM (60000000) TO (90000000);


ALTER TABLE public.txs_16_payment_60000000_90000000 OWNER TO dba;


CREATE TABLE public.txs_16_payment_90000000_120000000 (
    tx_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_payment smallint NOT NULL,
    height integer,
    asset_uid bigint
);
ALTER TABLE ONLY public.txs_16_payment ATTACH PARTITION public.txs_16_payment_90000000_120000000 FOR VALUES FROM (90000000) TO (120000000);


ALTER TABLE public.txs_16_payment_90000000_120000000 OWNER TO dba;


CREATE TABLE public.txs_16_payment_default (
    tx_uid bigint NOT NULL,
    amount bigint NOT NULL,
    position_in_payment smallint NOT NULL,
    height integer,
    asset_uid bigint
);
ALTER TABLE ONLY public.txs_16_payment ATTACH PARTITION public.txs_16_payment_default DEFAULT;


ALTER TABLE public.txs_16_payment_default OWNER TO dba;


CREATE TABLE public.txs_1_2 (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_1_2 FOR VALUES FROM ('1') TO ('2');


ALTER TABLE public.txs_1_2 OWNER TO dba;


CREATE TABLE public.txs_1_default (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_1 ATTACH PARTITION public.txs_1_default DEFAULT;


ALTER TABLE public.txs_1_default OWNER TO dba;


CREATE TABLE public.txs_2 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    recipient_alias_uid bigint
)
PARTITION BY RANGE (tx_uid);


ALTER TABLE public.txs_2 OWNER TO dba;


CREATE TABLE public.txs_2_3 (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_2_3 FOR VALUES FROM ('2') TO ('3');


ALTER TABLE public.txs_2_3 OWNER TO dba;


CREATE TABLE public.txs_2_default (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_2 ATTACH PARTITION public.txs_2_default DEFAULT;


ALTER TABLE public.txs_2_default OWNER TO dba;


CREATE TABLE public.txs_3 (
    tx_uid bigint NOT NULL,
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


ALTER TABLE public.txs_3 OWNER TO dba;


CREATE TABLE public.txs_3_4 (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_3_4 FOR VALUES FROM ('3') TO ('4');


ALTER TABLE public.txs_3_4 OWNER TO dba;


CREATE TABLE public.txs_3_default (
    tx_uid bigint NOT NULL,
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


ALTER TABLE public.txs_3_default OWNER TO dba;


CREATE TABLE public.txs_4 (
    tx_uid bigint NOT NULL,
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


ALTER TABLE public.txs_4 OWNER TO dba;


CREATE TABLE public.txs_4_0_30000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint,
    amount bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    fee_asset_uid bigint,
    attachment character varying NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_4 ATTACH PARTITION public.txs_4_0_30000000 FOR VALUES FROM (0) TO (30000000);


ALTER TABLE public.txs_4_0_30000000 OWNER TO dba;


CREATE TABLE public.txs_4_120000000_150000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint,
    amount bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    fee_asset_uid bigint,
    attachment character varying NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_4 ATTACH PARTITION public.txs_4_120000000_150000000 FOR VALUES FROM (120000000) TO (150000000);


ALTER TABLE public.txs_4_120000000_150000000 OWNER TO dba;


CREATE TABLE public.txs_4_150000000_180000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint,
    amount bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    fee_asset_uid bigint,
    attachment character varying NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_4 ATTACH PARTITION public.txs_4_150000000_180000000 FOR VALUES FROM (150000000) TO (180000000);


ALTER TABLE public.txs_4_150000000_180000000 OWNER TO dba;


CREATE TABLE public.txs_4_180000000_210000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint,
    amount bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    fee_asset_uid bigint,
    attachment character varying NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_4 ATTACH PARTITION public.txs_4_180000000_210000000 FOR VALUES FROM (180000000) TO (210000000);


ALTER TABLE public.txs_4_180000000_210000000 OWNER TO dba;


CREATE TABLE public.txs_4_210000000_240000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint,
    amount bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    fee_asset_uid bigint,
    attachment character varying NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_4 ATTACH PARTITION public.txs_4_210000000_240000000 FOR VALUES FROM (210000000) TO (240000000);


ALTER TABLE public.txs_4_210000000_240000000 OWNER TO dba;


CREATE TABLE public.txs_4_240000000_270000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint,
    amount bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    fee_asset_uid bigint,
    attachment character varying NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_4 ATTACH PARTITION public.txs_4_240000000_270000000 FOR VALUES FROM (240000000) TO (270000000);


ALTER TABLE public.txs_4_240000000_270000000 OWNER TO dba;


CREATE TABLE public.txs_4_270000000_300000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint,
    amount bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    fee_asset_uid bigint,
    attachment character varying NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_4 ATTACH PARTITION public.txs_4_270000000_300000000 FOR VALUES FROM (270000000) TO (300000000);


ALTER TABLE public.txs_4_270000000_300000000 OWNER TO dba;


CREATE TABLE public.txs_4_300000000_330000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint,
    amount bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    fee_asset_uid bigint,
    attachment character varying NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_4 ATTACH PARTITION public.txs_4_300000000_330000000 FOR VALUES FROM (300000000) TO (330000000);


ALTER TABLE public.txs_4_300000000_330000000 OWNER TO dba;


CREATE TABLE public.txs_4_30000000_60000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint,
    amount bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    fee_asset_uid bigint,
    attachment character varying NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_4 ATTACH PARTITION public.txs_4_30000000_60000000 FOR VALUES FROM (30000000) TO (60000000);


ALTER TABLE public.txs_4_30000000_60000000 OWNER TO dba;


CREATE TABLE public.txs_4_5 (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_4_5 FOR VALUES FROM ('4') TO ('5');


ALTER TABLE public.txs_4_5 OWNER TO dba;


CREATE TABLE public.txs_4_60000000_90000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint,
    amount bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    fee_asset_uid bigint,
    attachment character varying NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_4 ATTACH PARTITION public.txs_4_60000000_90000000 FOR VALUES FROM (60000000) TO (90000000);


ALTER TABLE public.txs_4_60000000_90000000 OWNER TO dba;


CREATE TABLE public.txs_4_90000000_120000000 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint,
    amount bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    fee_asset_uid bigint,
    attachment character varying NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_4 ATTACH PARTITION public.txs_4_90000000_120000000 FOR VALUES FROM (90000000) TO (120000000);


ALTER TABLE public.txs_4_90000000_120000000 OWNER TO dba;


CREATE TABLE public.txs_4_default (
    tx_uid bigint NOT NULL,
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


ALTER TABLE public.txs_4_default OWNER TO dba;


CREATE TABLE public.txs_5 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    quantity bigint NOT NULL,
    reissuable boolean NOT NULL
)
PARTITION BY RANGE (tx_uid);


ALTER TABLE public.txs_5 OWNER TO dba;


CREATE TABLE public.txs_5_6 (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_5_6 FOR VALUES FROM ('5') TO ('6');


ALTER TABLE public.txs_5_6 OWNER TO dba;


CREATE TABLE public.txs_5_default (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    quantity bigint NOT NULL,
    reissuable boolean NOT NULL
);
ALTER TABLE ONLY public.txs_5 ATTACH PARTITION public.txs_5_default DEFAULT;


ALTER TABLE public.txs_5_default OWNER TO dba;


CREATE TABLE public.txs_6 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    amount bigint NOT NULL
)
PARTITION BY RANGE (tx_uid);


ALTER TABLE public.txs_6 OWNER TO dba;


CREATE TABLE public.txs_6_7 (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_6_7 FOR VALUES FROM ('6') TO ('7');


ALTER TABLE public.txs_6_7 OWNER TO dba;


CREATE TABLE public.txs_6_default (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    asset_uid bigint NOT NULL,
    amount bigint NOT NULL
);
ALTER TABLE ONLY public.txs_6 ATTACH PARTITION public.txs_6_default DEFAULT;


ALTER TABLE public.txs_6_default OWNER TO dba;


CREATE TABLE public.txs_7 (
    tx_uid bigint NOT NULL,
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


ALTER TABLE public.txs_7 OWNER TO dba;


CREATE TABLE public.txs_7_0_30000000 (
    tx_uid bigint NOT NULL,
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
ALTER TABLE ONLY public.txs_7 ATTACH PARTITION public.txs_7_0_30000000 FOR VALUES FROM (0) TO (30000000);


ALTER TABLE public.txs_7_0_30000000 OWNER TO dba;


CREATE TABLE public.txs_7_120000000_150000000 (
    tx_uid bigint NOT NULL,
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
ALTER TABLE ONLY public.txs_7 ATTACH PARTITION public.txs_7_120000000_150000000 FOR VALUES FROM (120000000) TO (150000000);


ALTER TABLE public.txs_7_120000000_150000000 OWNER TO dba;


CREATE TABLE public.txs_7_150000000_180000000 (
    tx_uid bigint NOT NULL,
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
ALTER TABLE ONLY public.txs_7 ATTACH PARTITION public.txs_7_150000000_180000000 FOR VALUES FROM (150000000) TO (180000000);


ALTER TABLE public.txs_7_150000000_180000000 OWNER TO dba;


CREATE TABLE public.txs_7_180000000_210000000 (
    tx_uid bigint NOT NULL,
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
ALTER TABLE ONLY public.txs_7 ATTACH PARTITION public.txs_7_180000000_210000000 FOR VALUES FROM (180000000) TO (210000000);


ALTER TABLE public.txs_7_180000000_210000000 OWNER TO dba;


CREATE TABLE public.txs_7_210000000_240000000 (
    tx_uid bigint NOT NULL,
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
ALTER TABLE ONLY public.txs_7 ATTACH PARTITION public.txs_7_210000000_240000000 FOR VALUES FROM (210000000) TO (240000000);


ALTER TABLE public.txs_7_210000000_240000000 OWNER TO dba;


CREATE TABLE public.txs_7_240000000_270000000 (
    tx_uid bigint NOT NULL,
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
ALTER TABLE ONLY public.txs_7 ATTACH PARTITION public.txs_7_240000000_270000000 FOR VALUES FROM (240000000) TO (270000000);


ALTER TABLE public.txs_7_240000000_270000000 OWNER TO dba;


CREATE TABLE public.txs_7_270000000_300000000 (
    tx_uid bigint NOT NULL,
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
ALTER TABLE ONLY public.txs_7 ATTACH PARTITION public.txs_7_270000000_300000000 FOR VALUES FROM (270000000) TO (300000000);


ALTER TABLE public.txs_7_270000000_300000000 OWNER TO dba;


CREATE TABLE public.txs_7_300000000_330000000 (
    tx_uid bigint NOT NULL,
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
ALTER TABLE ONLY public.txs_7 ATTACH PARTITION public.txs_7_300000000_330000000 FOR VALUES FROM (300000000) TO (330000000);


ALTER TABLE public.txs_7_300000000_330000000 OWNER TO dba;


CREATE TABLE public.txs_7_30000000_60000000 (
    tx_uid bigint NOT NULL,
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
ALTER TABLE ONLY public.txs_7 ATTACH PARTITION public.txs_7_30000000_60000000 FOR VALUES FROM (30000000) TO (60000000);


ALTER TABLE public.txs_7_30000000_60000000 OWNER TO dba;


CREATE TABLE public.txs_7_60000000_90000000 (
    tx_uid bigint NOT NULL,
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
ALTER TABLE ONLY public.txs_7 ATTACH PARTITION public.txs_7_60000000_90000000 FOR VALUES FROM (60000000) TO (90000000);


ALTER TABLE public.txs_7_60000000_90000000 OWNER TO dba;


CREATE TABLE public.txs_7_8 (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_7_8 FOR VALUES FROM ('7') TO ('8');


ALTER TABLE public.txs_7_8 OWNER TO dba;


CREATE TABLE public.txs_7_90000000_120000000 (
    tx_uid bigint NOT NULL,
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
ALTER TABLE ONLY public.txs_7 ATTACH PARTITION public.txs_7_90000000_120000000 FOR VALUES FROM (90000000) TO (120000000);


ALTER TABLE public.txs_7_90000000_120000000 OWNER TO dba;


CREATE TABLE public.txs_7_default (
    tx_uid bigint NOT NULL,
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


ALTER TABLE public.txs_7_default OWNER TO dba;


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


ALTER TABLE public.txs_7_orders OWNER TO dba;


CREATE TABLE public.txs_7_orders_0_30000000 (
    tx_uid bigint NOT NULL,
    height integer,
    order_uid bigint NOT NULL,
    sender_uid bigint NOT NULL,
    order_sender_uid bigint NOT NULL,
    amount_asset_uid bigint,
    price_asset_uid bigint
);
ALTER TABLE ONLY public.txs_7_orders ATTACH PARTITION public.txs_7_orders_0_30000000 FOR VALUES FROM (0) TO (30000000);


ALTER TABLE public.txs_7_orders_0_30000000 OWNER TO dba;


CREATE TABLE public.txs_7_orders_120000000_150000000 (
    tx_uid bigint NOT NULL,
    height integer,
    order_uid bigint NOT NULL,
    sender_uid bigint NOT NULL,
    order_sender_uid bigint NOT NULL,
    amount_asset_uid bigint,
    price_asset_uid bigint
);
ALTER TABLE ONLY public.txs_7_orders ATTACH PARTITION public.txs_7_orders_120000000_150000000 FOR VALUES FROM (120000000) TO (150000000);


ALTER TABLE public.txs_7_orders_120000000_150000000 OWNER TO dba;


CREATE TABLE public.txs_7_orders_150000000_180000000 (
    tx_uid bigint NOT NULL,
    height integer,
    order_uid bigint NOT NULL,
    sender_uid bigint NOT NULL,
    order_sender_uid bigint NOT NULL,
    amount_asset_uid bigint,
    price_asset_uid bigint
);
ALTER TABLE ONLY public.txs_7_orders ATTACH PARTITION public.txs_7_orders_150000000_180000000 FOR VALUES FROM (150000000) TO (180000000);


ALTER TABLE public.txs_7_orders_150000000_180000000 OWNER TO dba;


CREATE TABLE public.txs_7_orders_180000000_210000000 (
    tx_uid bigint NOT NULL,
    height integer,
    order_uid bigint NOT NULL,
    sender_uid bigint NOT NULL,
    order_sender_uid bigint NOT NULL,
    amount_asset_uid bigint,
    price_asset_uid bigint
);
ALTER TABLE ONLY public.txs_7_orders ATTACH PARTITION public.txs_7_orders_180000000_210000000 FOR VALUES FROM (180000000) TO (210000000);


ALTER TABLE public.txs_7_orders_180000000_210000000 OWNER TO dba;


CREATE TABLE public.txs_7_orders_210000000_240000000 (
    tx_uid bigint NOT NULL,
    height integer,
    order_uid bigint NOT NULL,
    sender_uid bigint NOT NULL,
    order_sender_uid bigint NOT NULL,
    amount_asset_uid bigint,
    price_asset_uid bigint
);
ALTER TABLE ONLY public.txs_7_orders ATTACH PARTITION public.txs_7_orders_210000000_240000000 FOR VALUES FROM (210000000) TO (240000000);


ALTER TABLE public.txs_7_orders_210000000_240000000 OWNER TO dba;


CREATE TABLE public.txs_7_orders_240000000_270000000 (
    tx_uid bigint NOT NULL,
    height integer,
    order_uid bigint NOT NULL,
    sender_uid bigint NOT NULL,
    order_sender_uid bigint NOT NULL,
    amount_asset_uid bigint,
    price_asset_uid bigint
);
ALTER TABLE ONLY public.txs_7_orders ATTACH PARTITION public.txs_7_orders_240000000_270000000 FOR VALUES FROM (240000000) TO (270000000);


ALTER TABLE public.txs_7_orders_240000000_270000000 OWNER TO dba;


CREATE TABLE public.txs_7_orders_270000000_300000000 (
    tx_uid bigint NOT NULL,
    height integer,
    order_uid bigint NOT NULL,
    sender_uid bigint NOT NULL,
    order_sender_uid bigint NOT NULL,
    amount_asset_uid bigint,
    price_asset_uid bigint
);
ALTER TABLE ONLY public.txs_7_orders ATTACH PARTITION public.txs_7_orders_270000000_300000000 FOR VALUES FROM (270000000) TO (300000000);


ALTER TABLE public.txs_7_orders_270000000_300000000 OWNER TO dba;


CREATE TABLE public.txs_7_orders_300000000_330000000 (
    tx_uid bigint NOT NULL,
    height integer,
    order_uid bigint NOT NULL,
    sender_uid bigint NOT NULL,
    order_sender_uid bigint NOT NULL,
    amount_asset_uid bigint,
    price_asset_uid bigint
);
ALTER TABLE ONLY public.txs_7_orders ATTACH PARTITION public.txs_7_orders_300000000_330000000 FOR VALUES FROM (300000000) TO (330000000);


ALTER TABLE public.txs_7_orders_300000000_330000000 OWNER TO dba;


CREATE TABLE public.txs_7_orders_30000000_60000000 (
    tx_uid bigint NOT NULL,
    height integer,
    order_uid bigint NOT NULL,
    sender_uid bigint NOT NULL,
    order_sender_uid bigint NOT NULL,
    amount_asset_uid bigint,
    price_asset_uid bigint
);
ALTER TABLE ONLY public.txs_7_orders ATTACH PARTITION public.txs_7_orders_30000000_60000000 FOR VALUES FROM (30000000) TO (60000000);


ALTER TABLE public.txs_7_orders_30000000_60000000 OWNER TO dba;


CREATE TABLE public.txs_7_orders_60000000_90000000 (
    tx_uid bigint NOT NULL,
    height integer,
    order_uid bigint NOT NULL,
    sender_uid bigint NOT NULL,
    order_sender_uid bigint NOT NULL,
    amount_asset_uid bigint,
    price_asset_uid bigint
);
ALTER TABLE ONLY public.txs_7_orders ATTACH PARTITION public.txs_7_orders_60000000_90000000 FOR VALUES FROM (60000000) TO (90000000);


ALTER TABLE public.txs_7_orders_60000000_90000000 OWNER TO dba;


CREATE TABLE public.txs_7_orders_90000000_120000000 (
    tx_uid bigint NOT NULL,
    height integer,
    order_uid bigint NOT NULL,
    sender_uid bigint NOT NULL,
    order_sender_uid bigint NOT NULL,
    amount_asset_uid bigint,
    price_asset_uid bigint
);
ALTER TABLE ONLY public.txs_7_orders ATTACH PARTITION public.txs_7_orders_90000000_120000000 FOR VALUES FROM (90000000) TO (120000000);


ALTER TABLE public.txs_7_orders_90000000_120000000 OWNER TO dba;


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


ALTER TABLE public.txs_7_orders_default OWNER TO dba;


CREATE TABLE public.txs_8 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    recipient_alias_uid bigint
)
PARTITION BY RANGE (tx_uid);


ALTER TABLE public.txs_8 OWNER TO dba;


CREATE TABLE public.txs_8_9 (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_8_9 FOR VALUES FROM ('8') TO ('9');


ALTER TABLE public.txs_8_9 OWNER TO dba;


CREATE TABLE public.txs_8_default (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    recipient_address_uid bigint NOT NULL,
    amount bigint NOT NULL,
    recipient_alias_uid bigint
);
ALTER TABLE ONLY public.txs_8 ATTACH PARTITION public.txs_8_default DEFAULT;


ALTER TABLE public.txs_8_default OWNER TO dba;


CREATE TABLE public.txs_9 (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    lease_tx_uid bigint
)
PARTITION BY RANGE (tx_uid);


ALTER TABLE public.txs_9 OWNER TO dba;


CREATE TABLE public.txs_9_a (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_9_a FOR VALUES FROM ('9') TO ('a');


ALTER TABLE public.txs_9_a OWNER TO dba;


CREATE TABLE public.txs_9_default (
    tx_uid bigint NOT NULL,
    height integer NOT NULL,
    sender_uid bigint NOT NULL,
    lease_tx_uid bigint
);
ALTER TABLE ONLY public.txs_9 ATTACH PARTITION public.txs_9_default DEFAULT;


ALTER TABLE public.txs_9_default OWNER TO dba;


CREATE TABLE public.txs_a_b (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_a_b FOR VALUES FROM ('a') TO ('b');


ALTER TABLE public.txs_a_b OWNER TO dba;


CREATE TABLE public.txs_b_c (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_b_c FOR VALUES FROM ('b') TO ('c');


ALTER TABLE public.txs_b_c OWNER TO dba;


CREATE TABLE public.txs_c_d (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_c_d FOR VALUES FROM ('c') TO ('d');


ALTER TABLE public.txs_c_d OWNER TO dba;


CREATE TABLE public.txs_d_e (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_d_e FOR VALUES FROM ('d') TO ('e');


ALTER TABLE public.txs_d_e OWNER TO dba;


CREATE TABLE public.txs_e_f (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_e_f FOR VALUES FROM ('e') TO ('f');


ALTER TABLE public.txs_e_f OWNER TO dba;


CREATE TABLE public.txs_f_g (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_f_g FOR VALUES FROM ('f') TO ('g');


ALTER TABLE public.txs_f_g OWNER TO dba;


CREATE TABLE public.txs_g_h (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_g_h FOR VALUES FROM ('g') TO ('h');


ALTER TABLE public.txs_g_h OWNER TO dba;


CREATE TABLE public.txs_h_i (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_h_i FOR VALUES FROM ('h') TO ('i');


ALTER TABLE public.txs_h_i OWNER TO dba;


CREATE TABLE public.txs_i_j (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_i_j FOR VALUES FROM ('i') TO ('j');


ALTER TABLE public.txs_i_j OWNER TO dba;


CREATE TABLE public.txs_j_k (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_j_k FOR VALUES FROM ('j') TO ('k');


ALTER TABLE public.txs_j_k OWNER TO dba;


CREATE TABLE public.txs_k_l (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_k_l FOR VALUES FROM ('k') TO ('l');


ALTER TABLE public.txs_k_l OWNER TO dba;


CREATE TABLE public.txs_l_m (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_l_m FOR VALUES FROM ('l') TO ('m');


ALTER TABLE public.txs_l_m OWNER TO dba;


CREATE TABLE public.txs_m_n (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_m_n FOR VALUES FROM ('m') TO ('n');


ALTER TABLE public.txs_m_n OWNER TO dba;


CREATE TABLE public.txs_n_o (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_n_o FOR VALUES FROM ('n') TO ('o');


ALTER TABLE public.txs_n_o OWNER TO dba;


CREATE TABLE public.txs_o_p (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_o_p FOR VALUES FROM ('o') TO ('p');


ALTER TABLE public.txs_o_p OWNER TO dba;


CREATE TABLE public.txs_p_q (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_p_q FOR VALUES FROM ('p') TO ('q');


ALTER TABLE public.txs_p_q OWNER TO dba;


CREATE TABLE public.txs_q_r (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_q_r FOR VALUES FROM ('q') TO ('r');


ALTER TABLE public.txs_q_r OWNER TO dba;


CREATE TABLE public.txs_r_s (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_r_s FOR VALUES FROM ('r') TO ('s');


ALTER TABLE public.txs_r_s OWNER TO dba;


CREATE TABLE public.txs_s_t (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_s_t FOR VALUES FROM ('s') TO ('t');


ALTER TABLE public.txs_s_t OWNER TO dba;


CREATE TABLE public.txs_t_u (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_t_u FOR VALUES FROM ('t') TO ('u');


ALTER TABLE public.txs_t_u OWNER TO dba;


CREATE TABLE public.txs_u_v (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_u_v FOR VALUES FROM ('u') TO ('v');


ALTER TABLE public.txs_u_v OWNER TO dba;


CREATE TABLE public.txs_v_w (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_v_w FOR VALUES FROM ('v') TO ('w');


ALTER TABLE public.txs_v_w OWNER TO dba;


CREATE TABLE public.txs_w_x (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_w_x FOR VALUES FROM ('w') TO ('x');


ALTER TABLE public.txs_w_x OWNER TO dba;


CREATE TABLE public.txs_x_y (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_x_y FOR VALUES FROM ('x') TO ('y');


ALTER TABLE public.txs_x_y OWNER TO dba;


CREATE TABLE public.txs_y_z (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_y_z FOR VALUES FROM ('y') TO ('z');


ALTER TABLE public.txs_y_z OWNER TO dba;


CREATE TABLE public.txs_z (
    uid bigint DEFAULT nextval('public.txs_uid_seq'::regclass) NOT NULL,
    tx_type smallint NOT NULL,
    sender_uid bigint,
    time_stamp timestamp with time zone NOT NULL,
    height integer NOT NULL,
    id character varying NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    fee bigint
);
ALTER TABLE ONLY public.txs ATTACH PARTITION public.txs_z DEFAULT;


ALTER TABLE public.txs_z OWNER TO dba;


ALTER TABLE ONLY public.addresses ALTER COLUMN uid SET DEFAULT nextval('public.addresses_uid_seq'::regclass);



ALTER TABLE ONLY public.assets ALTER COLUMN uid SET DEFAULT nextval('public.assets_uid_seq'::regclass);



ALTER TABLE ONLY public.orders ALTER COLUMN uid SET DEFAULT nextval('public.orders_uid_seq'::regclass);



ALTER TABLE ONLY public.txs ALTER COLUMN uid SET DEFAULT nextval('public.txs_uid_seq'::regclass);



ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_pk PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_0_1
    ADD CONSTRAINT addresses_0_1_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_1_2
    ADD CONSTRAINT addresses_1_2_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_2_3
    ADD CONSTRAINT addresses_2_3_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_3_4
    ADD CONSTRAINT addresses_3_4_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_4_5
    ADD CONSTRAINT addresses_4_5_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_5_6
    ADD CONSTRAINT addresses_5_6_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_6_7
    ADD CONSTRAINT addresses_6_7_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_7_8
    ADD CONSTRAINT addresses_7_8_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_8_9
    ADD CONSTRAINT addresses_8_9_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_9_a
    ADD CONSTRAINT addresses_9_a_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_a_b
    ADD CONSTRAINT addresses_a_b_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_b_c
    ADD CONSTRAINT addresses_b_c_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_c_d
    ADD CONSTRAINT addresses_c_d_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_d_e
    ADD CONSTRAINT addresses_d_e_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_e_f
    ADD CONSTRAINT addresses_e_f_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_f_g
    ADD CONSTRAINT addresses_f_g_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_g_h
    ADD CONSTRAINT addresses_g_h_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_h_i
    ADD CONSTRAINT addresses_h_i_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_i_j
    ADD CONSTRAINT addresses_i_j_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_j_k
    ADD CONSTRAINT addresses_j_k_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_k_l
    ADD CONSTRAINT addresses_k_l_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_l_m
    ADD CONSTRAINT addresses_l_m_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_m_n
    ADD CONSTRAINT addresses_m_n_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_n_o
    ADD CONSTRAINT addresses_n_o_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_o_p
    ADD CONSTRAINT addresses_o_p_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_p_q
    ADD CONSTRAINT addresses_p_q_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_q_r
    ADD CONSTRAINT addresses_q_r_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_r_s
    ADD CONSTRAINT addresses_r_s_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_s_t
    ADD CONSTRAINT addresses_s_t_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_t_u
    ADD CONSTRAINT addresses_t_u_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_u_v
    ADD CONSTRAINT addresses_u_v_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_v_w
    ADD CONSTRAINT addresses_v_w_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_w_x
    ADD CONSTRAINT addresses_w_x_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_x_y
    ADD CONSTRAINT addresses_x_y_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_y_z
    ADD CONSTRAINT addresses_y_z_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.addresses_z
    ADD CONSTRAINT addresses_z_pkey PRIMARY KEY (address);



ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_map_un UNIQUE (uid);



ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_map_un_asset_id UNIQUE (asset_id);



ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_map_un_ticker UNIQUE (ticker);



ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_pkey PRIMARY KEY (height);



ALTER TABLE ONLY public.blocks_raw
    ADD CONSTRAINT blocks_raw_pkey PRIMARY KEY (height);



ALTER TABLE ONLY public.candles
    ADD CONSTRAINT candles_pkey PRIMARY KEY (interval, time_start, amount_asset_uid, price_asset_uid, matcher_address_uid);



ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_uid_key UNIQUE (uid);



ALTER TABLE ONLY public.orders_0_30000000
    ADD CONSTRAINT orders_0_30000000_uid_key UNIQUE (uid);



ALTER TABLE ONLY public.orders_120000000_150000000
    ADD CONSTRAINT orders_120000000_150000000_uid_key UNIQUE (uid);



ALTER TABLE ONLY public.orders_150000000_180000000
    ADD CONSTRAINT orders_150000000_180000000_uid_key UNIQUE (uid);



ALTER TABLE ONLY public.orders_180000000_210000000
    ADD CONSTRAINT orders_180000000_210000000_uid_key UNIQUE (uid);



ALTER TABLE ONLY public.orders_210000000_240000000
    ADD CONSTRAINT orders_210000000_240000000_uid_key UNIQUE (uid);



ALTER TABLE ONLY public.orders_240000000_270000000
    ADD CONSTRAINT orders_240000000_270000000_uid_key UNIQUE (uid);



ALTER TABLE ONLY public.orders_270000000_300000000
    ADD CONSTRAINT orders_270000000_300000000_uid_key UNIQUE (uid);



ALTER TABLE ONLY public.orders_300000000_330000000
    ADD CONSTRAINT orders_300000000_330000000_uid_key UNIQUE (uid);



ALTER TABLE ONLY public.orders_30000000_60000000
    ADD CONSTRAINT orders_30000000_60000000_uid_key UNIQUE (uid);



ALTER TABLE ONLY public.orders_60000000_90000000
    ADD CONSTRAINT orders_60000000_90000000_uid_key UNIQUE (uid);



ALTER TABLE ONLY public.orders_90000000_120000000
    ADD CONSTRAINT orders_90000000_120000000_uid_key UNIQUE (uid);



ALTER TABLE ONLY public.orders_default
    ADD CONSTRAINT orders_default_uid_key UNIQUE (uid);



ALTER TABLE ONLY public.pairs
    ADD CONSTRAINT pairs_pk PRIMARY KEY (amount_asset_uid, price_asset_uid, matcher_address_uid);



ALTER TABLE ONLY public.txs
    ADD CONSTRAINT txs_pk PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_0_1
    ADD CONSTRAINT txs_0_1_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_10
    ADD CONSTRAINT txs_10_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_10_default
    ADD CONSTRAINT txs_10_default_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_11
    ADD CONSTRAINT txs_11_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_11_default
    ADD CONSTRAINT txs_11_default_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_11_transfers
    ADD CONSTRAINT txs_11_transfers_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_0_30000000
    ADD CONSTRAINT txs_11_transfers_0_30000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_120000000_150000000
    ADD CONSTRAINT txs_11_transfers_120000000_150000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_150000000_180000000
    ADD CONSTRAINT txs_11_transfers_150000000_180000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_180000000_210000000
    ADD CONSTRAINT txs_11_transfers_180000000_210000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_210000000_240000000
    ADD CONSTRAINT txs_11_transfers_210000000_240000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_240000000_270000000
    ADD CONSTRAINT txs_11_transfers_240000000_270000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_270000000_300000000
    ADD CONSTRAINT txs_11_transfers_270000000_300000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_300000000_330000000
    ADD CONSTRAINT txs_11_transfers_300000000_330000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_30000000_60000000
    ADD CONSTRAINT txs_11_transfers_30000000_60000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_330000000_360000000
    ADD CONSTRAINT txs_11_transfers_330000000_360000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_360000000_390000000
    ADD CONSTRAINT txs_11_transfers_360000000_390000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_390000000_420000000
    ADD CONSTRAINT txs_11_transfers_390000000_420000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_420000000_450000000
    ADD CONSTRAINT txs_11_transfers_420000000_450000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_450000000_480000000
    ADD CONSTRAINT txs_11_transfers_450000000_480000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_480000000_510000000
    ADD CONSTRAINT txs_11_transfers_480000000_510000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_510000000_540000000
    ADD CONSTRAINT txs_11_transfers_510000000_540000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_540000000_570000000
    ADD CONSTRAINT txs_11_transfers_540000000_570000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_570000000_600000000
    ADD CONSTRAINT txs_11_transfers_570000000_600000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_600000000_630000000
    ADD CONSTRAINT txs_11_transfers_600000000_630000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_60000000_90000000
    ADD CONSTRAINT txs_11_transfers_60000000_90000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_90000000_120000000
    ADD CONSTRAINT txs_11_transfers_90000000_120000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_11_transfers_default
    ADD CONSTRAINT txs_11_transfers_default_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_12_data
    ADD CONSTRAINT txs_12_data_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_12_data_0_30000000
    ADD CONSTRAINT txs_12_data_0_30000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_12_data_120000000_150000000
    ADD CONSTRAINT txs_12_data_120000000_150000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_12_data_150000000_180000000
    ADD CONSTRAINT txs_12_data_150000000_180000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_12_data_180000000_210000000
    ADD CONSTRAINT txs_12_data_180000000_210000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_12_data_210000000_240000000
    ADD CONSTRAINT txs_12_data_210000000_240000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_12_data_240000000_270000000
    ADD CONSTRAINT txs_12_data_240000000_270000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_12_data_270000000_300000000
    ADD CONSTRAINT txs_12_data_270000000_300000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_12_data_300000000_330000000
    ADD CONSTRAINT txs_12_data_300000000_330000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_12_data_30000000_60000000
    ADD CONSTRAINT txs_12_data_30000000_60000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_12_data_60000000_90000000
    ADD CONSTRAINT txs_12_data_60000000_90000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_12_data_90000000_120000000
    ADD CONSTRAINT txs_12_data_90000000_120000000_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_12_data_default
    ADD CONSTRAINT txs_12_data_default_pkey PRIMARY KEY (tx_uid, position_in_tx);



ALTER TABLE ONLY public.txs_12
    ADD CONSTRAINT txs_12_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_12_default
    ADD CONSTRAINT txs_12_default_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_13
    ADD CONSTRAINT txs_13_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_13_default
    ADD CONSTRAINT txs_13_default_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_14
    ADD CONSTRAINT txs_14_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_14_default
    ADD CONSTRAINT txs_14_default_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_15
    ADD CONSTRAINT txs_15_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_15_default
    ADD CONSTRAINT txs_15_default_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_16
    ADD CONSTRAINT txs_16_un UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_16_0_30000000
    ADD CONSTRAINT txs_16_0_30000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_16_120000001_150000000
    ADD CONSTRAINT txs_16_120000001_150000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_16_150000001_180000000
    ADD CONSTRAINT txs_16_150000001_180000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_16_180000001_210000000
    ADD CONSTRAINT txs_16_180000001_210000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_16_210000001_240000000
    ADD CONSTRAINT txs_16_210000001_240000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_16_240000001_270000000
    ADD CONSTRAINT txs_16_240000001_270000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_16_270000001_300000000
    ADD CONSTRAINT txs_16_270000001_300000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_16_300000001_330000000
    ADD CONSTRAINT txs_16_300000001_330000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_16_30000001_60000000
    ADD CONSTRAINT txs_16_30000001_60000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_16_60000001_90000000
    ADD CONSTRAINT txs_16_60000001_90000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_16_90000001_120000000
    ADD CONSTRAINT txs_16_90000001_120000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_16_args
    ADD CONSTRAINT txs_16_args_pk PRIMARY KEY (tx_uid, position_in_args);



ALTER TABLE ONLY public.txs_16_args_0_30000000
    ADD CONSTRAINT txs_16_args_0_30000000_pkey PRIMARY KEY (tx_uid, position_in_args);



ALTER TABLE ONLY public.txs_16_args_120000000_150000000
    ADD CONSTRAINT txs_16_args_120000000_150000000_pkey PRIMARY KEY (tx_uid, position_in_args);



ALTER TABLE ONLY public.txs_16_args_150000000_180000000
    ADD CONSTRAINT txs_16_args_150000000_180000000_pkey PRIMARY KEY (tx_uid, position_in_args);



ALTER TABLE ONLY public.txs_16_args_180000000_210000000
    ADD CONSTRAINT txs_16_args_180000000_210000000_pkey PRIMARY KEY (tx_uid, position_in_args);



ALTER TABLE ONLY public.txs_16_args_210000000_240000000
    ADD CONSTRAINT txs_16_args_210000000_240000000_pkey PRIMARY KEY (tx_uid, position_in_args);



ALTER TABLE ONLY public.txs_16_args_240000000_270000000
    ADD CONSTRAINT txs_16_args_240000000_270000000_pkey PRIMARY KEY (tx_uid, position_in_args);



ALTER TABLE ONLY public.txs_16_args_270000000_300000000
    ADD CONSTRAINT txs_16_args_270000000_300000000_pkey PRIMARY KEY (tx_uid, position_in_args);



ALTER TABLE ONLY public.txs_16_args_300000000_330000000
    ADD CONSTRAINT txs_16_args_300000000_330000000_pkey PRIMARY KEY (tx_uid, position_in_args);



ALTER TABLE ONLY public.txs_16_args_30000000_60000000
    ADD CONSTRAINT txs_16_args_30000000_60000000_pkey PRIMARY KEY (tx_uid, position_in_args);



ALTER TABLE ONLY public.txs_16_args_60000000_90000000
    ADD CONSTRAINT txs_16_args_60000000_90000000_pkey PRIMARY KEY (tx_uid, position_in_args);



ALTER TABLE ONLY public.txs_16_args_90000000_120000000
    ADD CONSTRAINT txs_16_args_90000000_120000000_pkey PRIMARY KEY (tx_uid, position_in_args);



ALTER TABLE ONLY public.txs_16_args_default
    ADD CONSTRAINT txs_16_args_default_pkey PRIMARY KEY (tx_uid, position_in_args);



ALTER TABLE ONLY public.txs_16_default
    ADD CONSTRAINT txs_16_default_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_16_payment
    ADD CONSTRAINT txs_16_payment_pk PRIMARY KEY (tx_uid, position_in_payment);



ALTER TABLE ONLY public.txs_16_payment_0_30000000
    ADD CONSTRAINT txs_16_payment_0_30000000_pkey PRIMARY KEY (tx_uid, position_in_payment);



ALTER TABLE ONLY public.txs_16_payment_120000000_150000000
    ADD CONSTRAINT txs_16_payment_120000000_150000000_pkey PRIMARY KEY (tx_uid, position_in_payment);



ALTER TABLE ONLY public.txs_16_payment_150000000_180000000
    ADD CONSTRAINT txs_16_payment_150000000_180000000_pkey PRIMARY KEY (tx_uid, position_in_payment);



ALTER TABLE ONLY public.txs_16_payment_180000000_210000000
    ADD CONSTRAINT txs_16_payment_180000000_210000000_pkey PRIMARY KEY (tx_uid, position_in_payment);



ALTER TABLE ONLY public.txs_16_payment_210000000_240000000
    ADD CONSTRAINT txs_16_payment_210000000_240000000_pkey PRIMARY KEY (tx_uid, position_in_payment);



ALTER TABLE ONLY public.txs_16_payment_240000000_270000000
    ADD CONSTRAINT txs_16_payment_240000000_270000000_pkey PRIMARY KEY (tx_uid, position_in_payment);



ALTER TABLE ONLY public.txs_16_payment_270000000_300000000
    ADD CONSTRAINT txs_16_payment_270000000_300000000_pkey PRIMARY KEY (tx_uid, position_in_payment);



ALTER TABLE ONLY public.txs_16_payment_300000000_330000000
    ADD CONSTRAINT txs_16_payment_300000000_330000000_pkey PRIMARY KEY (tx_uid, position_in_payment);



ALTER TABLE ONLY public.txs_16_payment_30000000_60000000
    ADD CONSTRAINT txs_16_payment_30000000_60000000_pkey PRIMARY KEY (tx_uid, position_in_payment);



ALTER TABLE ONLY public.txs_16_payment_60000000_90000000
    ADD CONSTRAINT txs_16_payment_60000000_90000000_pkey PRIMARY KEY (tx_uid, position_in_payment);



ALTER TABLE ONLY public.txs_16_payment_90000000_120000000
    ADD CONSTRAINT txs_16_payment_90000000_120000000_pkey PRIMARY KEY (tx_uid, position_in_payment);



ALTER TABLE ONLY public.txs_16_payment_default
    ADD CONSTRAINT txs_16_payment_default_pkey PRIMARY KEY (tx_uid, position_in_payment);



ALTER TABLE ONLY public.txs_1_2
    ADD CONSTRAINT txs_1_2_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_1
    ADD CONSTRAINT txs_1_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_1_default
    ADD CONSTRAINT txs_1_default_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_2_3
    ADD CONSTRAINT txs_2_3_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_2
    ADD CONSTRAINT txs_2_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_2_default
    ADD CONSTRAINT txs_2_default_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_3_4
    ADD CONSTRAINT txs_3_4_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_3
    ADD CONSTRAINT txs_3_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_3_default
    ADD CONSTRAINT txs_3_default_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_4
    ADD CONSTRAINT txs_4_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_4_0_30000000
    ADD CONSTRAINT txs_4_0_30000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_4_120000000_150000000
    ADD CONSTRAINT txs_4_120000000_150000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_4_150000000_180000000
    ADD CONSTRAINT txs_4_150000000_180000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_4_180000000_210000000
    ADD CONSTRAINT txs_4_180000000_210000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_4_210000000_240000000
    ADD CONSTRAINT txs_4_210000000_240000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_4_240000000_270000000
    ADD CONSTRAINT txs_4_240000000_270000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_4_270000000_300000000
    ADD CONSTRAINT txs_4_270000000_300000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_4_300000000_330000000
    ADD CONSTRAINT txs_4_300000000_330000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_4_30000000_60000000
    ADD CONSTRAINT txs_4_30000000_60000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_4_5
    ADD CONSTRAINT txs_4_5_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_4_60000000_90000000
    ADD CONSTRAINT txs_4_60000000_90000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_4_90000000_120000000
    ADD CONSTRAINT txs_4_90000000_120000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_4_default
    ADD CONSTRAINT txs_4_default_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_5_6
    ADD CONSTRAINT txs_5_6_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_5
    ADD CONSTRAINT txs_5_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_5_default
    ADD CONSTRAINT txs_5_default_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_6_7
    ADD CONSTRAINT txs_6_7_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_6
    ADD CONSTRAINT txs_6_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_6_default
    ADD CONSTRAINT txs_6_default_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_7
    ADD CONSTRAINT txs_7_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_7_0_30000000
    ADD CONSTRAINT txs_7_0_30000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_7_120000000_150000000
    ADD CONSTRAINT txs_7_120000000_150000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_7_150000000_180000000
    ADD CONSTRAINT txs_7_150000000_180000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_7_180000000_210000000
    ADD CONSTRAINT txs_7_180000000_210000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_7_210000000_240000000
    ADD CONSTRAINT txs_7_210000000_240000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_7_240000000_270000000
    ADD CONSTRAINT txs_7_240000000_270000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_7_270000000_300000000
    ADD CONSTRAINT txs_7_270000000_300000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_7_300000000_330000000
    ADD CONSTRAINT txs_7_300000000_330000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_7_30000000_60000000
    ADD CONSTRAINT txs_7_30000000_60000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_7_60000000_90000000
    ADD CONSTRAINT txs_7_60000000_90000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_7_8
    ADD CONSTRAINT txs_7_8_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_7_90000000_120000000
    ADD CONSTRAINT txs_7_90000000_120000000_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_7_default
    ADD CONSTRAINT txs_7_default_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_7_orders
    ADD CONSTRAINT txs_7_orders_pk PRIMARY KEY (tx_uid, order_uid);



ALTER TABLE ONLY public.txs_7_orders_0_30000000
    ADD CONSTRAINT txs_7_orders_0_30000000_pkey PRIMARY KEY (tx_uid, order_uid);



ALTER TABLE ONLY public.txs_7_orders_120000000_150000000
    ADD CONSTRAINT txs_7_orders_120000000_150000000_pkey PRIMARY KEY (tx_uid, order_uid);



ALTER TABLE ONLY public.txs_7_orders_150000000_180000000
    ADD CONSTRAINT txs_7_orders_150000000_180000000_pkey PRIMARY KEY (tx_uid, order_uid);



ALTER TABLE ONLY public.txs_7_orders_180000000_210000000
    ADD CONSTRAINT txs_7_orders_180000000_210000000_pkey PRIMARY KEY (tx_uid, order_uid);



ALTER TABLE ONLY public.txs_7_orders_210000000_240000000
    ADD CONSTRAINT txs_7_orders_210000000_240000000_pkey PRIMARY KEY (tx_uid, order_uid);



ALTER TABLE ONLY public.txs_7_orders_240000000_270000000
    ADD CONSTRAINT txs_7_orders_240000000_270000000_pkey PRIMARY KEY (tx_uid, order_uid);



ALTER TABLE ONLY public.txs_7_orders_270000000_300000000
    ADD CONSTRAINT txs_7_orders_270000000_300000000_pkey PRIMARY KEY (tx_uid, order_uid);



ALTER TABLE ONLY public.txs_7_orders_300000000_330000000
    ADD CONSTRAINT txs_7_orders_300000000_330000000_pkey PRIMARY KEY (tx_uid, order_uid);



ALTER TABLE ONLY public.txs_7_orders_30000000_60000000
    ADD CONSTRAINT txs_7_orders_30000000_60000000_pkey PRIMARY KEY (tx_uid, order_uid);



ALTER TABLE ONLY public.txs_7_orders_60000000_90000000
    ADD CONSTRAINT txs_7_orders_60000000_90000000_pkey PRIMARY KEY (tx_uid, order_uid);



ALTER TABLE ONLY public.txs_7_orders_90000000_120000000
    ADD CONSTRAINT txs_7_orders_90000000_120000000_pkey PRIMARY KEY (tx_uid, order_uid);



ALTER TABLE ONLY public.txs_7_orders_default
    ADD CONSTRAINT txs_7_orders_default_pkey PRIMARY KEY (tx_uid, order_uid);



ALTER TABLE ONLY public.txs_8_9
    ADD CONSTRAINT txs_8_9_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_8
    ADD CONSTRAINT txs_8_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_8_default
    ADD CONSTRAINT txs_8_default_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_9_a
    ADD CONSTRAINT txs_9_a_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_9
    ADD CONSTRAINT txs_9_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_9_default
    ADD CONSTRAINT txs_9_default_tx_uid_key UNIQUE (tx_uid);



ALTER TABLE ONLY public.txs_9
    ADD CONSTRAINT txs_9_un UNIQUE (tx_uid, lease_tx_uid);



ALTER TABLE ONLY public.txs_9_default
    ADD CONSTRAINT txs_9_default_tx_uid_lease_tx_uid_key UNIQUE (tx_uid, lease_tx_uid);



ALTER TABLE ONLY public.txs_a_b
    ADD CONSTRAINT txs_a_b_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_b_c
    ADD CONSTRAINT txs_b_c_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_c_d
    ADD CONSTRAINT txs_c_d_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_d_e
    ADD CONSTRAINT txs_d_e_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_e_f
    ADD CONSTRAINT txs_e_f_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_f_g
    ADD CONSTRAINT txs_f_g_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_g_h
    ADD CONSTRAINT txs_g_h_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_h_i
    ADD CONSTRAINT txs_h_i_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_i_j
    ADD CONSTRAINT txs_i_j_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_j_k
    ADD CONSTRAINT txs_j_k_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_k_l
    ADD CONSTRAINT txs_k_l_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_l_m
    ADD CONSTRAINT txs_l_m_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_m_n
    ADD CONSTRAINT txs_m_n_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_n_o
    ADD CONSTRAINT txs_n_o_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_o_p
    ADD CONSTRAINT txs_o_p_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_p_q
    ADD CONSTRAINT txs_p_q_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_q_r
    ADD CONSTRAINT txs_q_r_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_r_s
    ADD CONSTRAINT txs_r_s_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_s_t
    ADD CONSTRAINT txs_s_t_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_t_u
    ADD CONSTRAINT txs_t_u_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_u_v
    ADD CONSTRAINT txs_u_v_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_v_w
    ADD CONSTRAINT txs_v_w_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_w_x
    ADD CONSTRAINT txs_w_x_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_x_y
    ADD CONSTRAINT txs_x_y_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_y_z
    ADD CONSTRAINT txs_y_z_pkey PRIMARY KEY (id, time_stamp);



ALTER TABLE ONLY public.txs_z
    ADD CONSTRAINT txs_z_pkey PRIMARY KEY (id, time_stamp);


CREATE INDEX addresses_address_uid_idx ON ONLY public.addresses USING btree (address, uid);


CREATE INDEX addresses_0_1_address_uid_idx ON public.addresses_0_1 USING btree (address, uid);


CREATE INDEX addresses_public_key_uid_idx ON ONLY public.addresses USING btree (public_key, uid);


CREATE INDEX addresses_0_1_public_key_uid_idx ON public.addresses_0_1 USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_address_first_appeared_on_height_idx ON ONLY public.addresses USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_0_1_uid_address_first_appeared_on_height_idx ON public.addresses_0_1 USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_uid_address_public_key_idx ON ONLY public.addresses USING btree (uid, address, public_key);


CREATE UNIQUE INDEX addresses_0_1_uid_address_public_key_idx ON public.addresses_0_1 USING btree (uid, address, public_key);


CREATE INDEX addresses_1_2_address_uid_idx ON public.addresses_1_2 USING btree (address, uid);


CREATE INDEX addresses_1_2_public_key_uid_idx ON public.addresses_1_2 USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_1_2_uid_address_first_appeared_on_height_idx ON public.addresses_1_2 USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_1_2_uid_address_public_key_idx ON public.addresses_1_2 USING btree (uid, address, public_key);


CREATE INDEX addresses_2_3_address_uid_idx ON public.addresses_2_3 USING btree (address, uid);


CREATE INDEX addresses_2_3_public_key_uid_idx ON public.addresses_2_3 USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_2_3_uid_address_first_appeared_on_height_idx ON public.addresses_2_3 USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_2_3_uid_address_public_key_idx ON public.addresses_2_3 USING btree (uid, address, public_key);


CREATE INDEX addresses_3_4_address_uid_idx ON public.addresses_3_4 USING btree (address, uid);


CREATE INDEX addresses_3_4_public_key_uid_idx ON public.addresses_3_4 USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_3_4_uid_address_first_appeared_on_height_idx ON public.addresses_3_4 USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_3_4_uid_address_public_key_idx ON public.addresses_3_4 USING btree (uid, address, public_key);


CREATE INDEX addresses_4_5_address_uid_idx ON public.addresses_4_5 USING btree (address, uid);


CREATE INDEX addresses_4_5_public_key_uid_idx ON public.addresses_4_5 USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_4_5_uid_address_first_appeared_on_height_idx ON public.addresses_4_5 USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_4_5_uid_address_public_key_idx ON public.addresses_4_5 USING btree (uid, address, public_key);


CREATE INDEX addresses_5_6_address_uid_idx ON public.addresses_5_6 USING btree (address, uid);


CREATE INDEX addresses_5_6_public_key_uid_idx ON public.addresses_5_6 USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_5_6_uid_address_first_appeared_on_height_idx ON public.addresses_5_6 USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_5_6_uid_address_public_key_idx ON public.addresses_5_6 USING btree (uid, address, public_key);


CREATE INDEX addresses_6_7_address_uid_idx ON public.addresses_6_7 USING btree (address, uid);


CREATE INDEX addresses_6_7_public_key_uid_idx ON public.addresses_6_7 USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_6_7_uid_address_first_appeared_on_height_idx ON public.addresses_6_7 USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_6_7_uid_address_public_key_idx ON public.addresses_6_7 USING btree (uid, address, public_key);


CREATE INDEX addresses_7_8_address_uid_idx ON public.addresses_7_8 USING btree (address, uid);


CREATE INDEX addresses_7_8_public_key_uid_idx ON public.addresses_7_8 USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_7_8_uid_address_first_appeared_on_height_idx ON public.addresses_7_8 USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_7_8_uid_address_public_key_idx ON public.addresses_7_8 USING btree (uid, address, public_key);


CREATE INDEX addresses_8_9_address_uid_idx ON public.addresses_8_9 USING btree (address, uid);


CREATE INDEX addresses_8_9_public_key_uid_idx ON public.addresses_8_9 USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_8_9_uid_address_first_appeared_on_height_idx ON public.addresses_8_9 USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_8_9_uid_address_public_key_idx ON public.addresses_8_9 USING btree (uid, address, public_key);


CREATE INDEX addresses_9_a_address_uid_idx ON public.addresses_9_a USING btree (address, uid);


CREATE INDEX addresses_9_a_public_key_uid_idx ON public.addresses_9_a USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_9_a_uid_address_first_appeared_on_height_idx ON public.addresses_9_a USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_9_a_uid_address_public_key_idx ON public.addresses_9_a USING btree (uid, address, public_key);


CREATE INDEX addresses_a_b_address_uid_idx ON public.addresses_a_b USING btree (address, uid);


CREATE INDEX addresses_a_b_public_key_uid_idx ON public.addresses_a_b USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_a_b_uid_address_first_appeared_on_height_idx ON public.addresses_a_b USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_a_b_uid_address_public_key_idx ON public.addresses_a_b USING btree (uid, address, public_key);


CREATE INDEX addresses_b_c_address_uid_idx ON public.addresses_b_c USING btree (address, uid);


CREATE INDEX addresses_b_c_public_key_uid_idx ON public.addresses_b_c USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_b_c_uid_address_first_appeared_on_height_idx ON public.addresses_b_c USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_b_c_uid_address_public_key_idx ON public.addresses_b_c USING btree (uid, address, public_key);


CREATE INDEX addresses_c_d_address_uid_idx ON public.addresses_c_d USING btree (address, uid);


CREATE INDEX addresses_c_d_public_key_uid_idx ON public.addresses_c_d USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_c_d_uid_address_first_appeared_on_height_idx ON public.addresses_c_d USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_c_d_uid_address_public_key_idx ON public.addresses_c_d USING btree (uid, address, public_key);


CREATE INDEX addresses_d_e_address_uid_idx ON public.addresses_d_e USING btree (address, uid);


CREATE INDEX addresses_d_e_public_key_uid_idx ON public.addresses_d_e USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_d_e_uid_address_first_appeared_on_height_idx ON public.addresses_d_e USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_d_e_uid_address_public_key_idx ON public.addresses_d_e USING btree (uid, address, public_key);


CREATE INDEX addresses_e_f_address_uid_idx ON public.addresses_e_f USING btree (address, uid);


CREATE INDEX addresses_e_f_public_key_uid_idx ON public.addresses_e_f USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_e_f_uid_address_first_appeared_on_height_idx ON public.addresses_e_f USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_e_f_uid_address_public_key_idx ON public.addresses_e_f USING btree (uid, address, public_key);


CREATE INDEX addresses_f_g_address_uid_idx ON public.addresses_f_g USING btree (address, uid);


CREATE INDEX addresses_f_g_public_key_uid_idx ON public.addresses_f_g USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_f_g_uid_address_first_appeared_on_height_idx ON public.addresses_f_g USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_f_g_uid_address_public_key_idx ON public.addresses_f_g USING btree (uid, address, public_key);


CREATE INDEX addresses_g_h_address_uid_idx ON public.addresses_g_h USING btree (address, uid);


CREATE INDEX addresses_g_h_public_key_uid_idx ON public.addresses_g_h USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_g_h_uid_address_first_appeared_on_height_idx ON public.addresses_g_h USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_g_h_uid_address_public_key_idx ON public.addresses_g_h USING btree (uid, address, public_key);


CREATE INDEX addresses_h_i_address_uid_idx ON public.addresses_h_i USING btree (address, uid);


CREATE INDEX addresses_h_i_public_key_uid_idx ON public.addresses_h_i USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_h_i_uid_address_first_appeared_on_height_idx ON public.addresses_h_i USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_h_i_uid_address_public_key_idx ON public.addresses_h_i USING btree (uid, address, public_key);


CREATE INDEX addresses_i_j_address_uid_idx ON public.addresses_i_j USING btree (address, uid);


CREATE INDEX addresses_i_j_public_key_uid_idx ON public.addresses_i_j USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_i_j_uid_address_first_appeared_on_height_idx ON public.addresses_i_j USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_i_j_uid_address_public_key_idx ON public.addresses_i_j USING btree (uid, address, public_key);


CREATE INDEX addresses_j_k_address_uid_idx ON public.addresses_j_k USING btree (address, uid);


CREATE INDEX addresses_j_k_public_key_uid_idx ON public.addresses_j_k USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_j_k_uid_address_first_appeared_on_height_idx ON public.addresses_j_k USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_j_k_uid_address_public_key_idx ON public.addresses_j_k USING btree (uid, address, public_key);


CREATE INDEX addresses_k_l_address_uid_idx ON public.addresses_k_l USING btree (address, uid);


CREATE INDEX addresses_k_l_public_key_uid_idx ON public.addresses_k_l USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_k_l_uid_address_first_appeared_on_height_idx ON public.addresses_k_l USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_k_l_uid_address_public_key_idx ON public.addresses_k_l USING btree (uid, address, public_key);


CREATE INDEX addresses_l_m_address_uid_idx ON public.addresses_l_m USING btree (address, uid);


CREATE INDEX addresses_l_m_public_key_uid_idx ON public.addresses_l_m USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_l_m_uid_address_first_appeared_on_height_idx ON public.addresses_l_m USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_l_m_uid_address_public_key_idx ON public.addresses_l_m USING btree (uid, address, public_key);


CREATE INDEX addresses_m_n_address_uid_idx ON public.addresses_m_n USING btree (address, uid);


CREATE INDEX addresses_m_n_public_key_uid_idx ON public.addresses_m_n USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_m_n_uid_address_first_appeared_on_height_idx ON public.addresses_m_n USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_m_n_uid_address_public_key_idx ON public.addresses_m_n USING btree (uid, address, public_key);


CREATE INDEX addresses_n_o_address_uid_idx ON public.addresses_n_o USING btree (address, uid);


CREATE INDEX addresses_n_o_public_key_uid_idx ON public.addresses_n_o USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_n_o_uid_address_first_appeared_on_height_idx ON public.addresses_n_o USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_n_o_uid_address_public_key_idx ON public.addresses_n_o USING btree (uid, address, public_key);


CREATE INDEX addresses_o_p_address_uid_idx ON public.addresses_o_p USING btree (address, uid);


CREATE INDEX addresses_o_p_public_key_uid_idx ON public.addresses_o_p USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_o_p_uid_address_first_appeared_on_height_idx ON public.addresses_o_p USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_o_p_uid_address_public_key_idx ON public.addresses_o_p USING btree (uid, address, public_key);


CREATE INDEX addresses_p_q_address_uid_idx ON public.addresses_p_q USING btree (address, uid);


CREATE INDEX addresses_p_q_public_key_uid_idx ON public.addresses_p_q USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_p_q_uid_address_first_appeared_on_height_idx ON public.addresses_p_q USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_p_q_uid_address_public_key_idx ON public.addresses_p_q USING btree (uid, address, public_key);


CREATE INDEX addresses_q_r_address_uid_idx ON public.addresses_q_r USING btree (address, uid);


CREATE INDEX addresses_q_r_public_key_uid_idx ON public.addresses_q_r USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_q_r_uid_address_first_appeared_on_height_idx ON public.addresses_q_r USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_q_r_uid_address_public_key_idx ON public.addresses_q_r USING btree (uid, address, public_key);


CREATE INDEX addresses_r_s_address_uid_idx ON public.addresses_r_s USING btree (address, uid);


CREATE INDEX addresses_r_s_public_key_uid_idx ON public.addresses_r_s USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_r_s_uid_address_first_appeared_on_height_idx ON public.addresses_r_s USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_r_s_uid_address_public_key_idx ON public.addresses_r_s USING btree (uid, address, public_key);


CREATE INDEX addresses_s_t_address_uid_idx ON public.addresses_s_t USING btree (address, uid);


CREATE INDEX addresses_s_t_public_key_uid_idx ON public.addresses_s_t USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_s_t_uid_address_first_appeared_on_height_idx ON public.addresses_s_t USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_s_t_uid_address_public_key_idx ON public.addresses_s_t USING btree (uid, address, public_key);


CREATE INDEX addresses_t_u_address_uid_idx ON public.addresses_t_u USING btree (address, uid);


CREATE INDEX addresses_t_u_public_key_uid_idx ON public.addresses_t_u USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_t_u_uid_address_first_appeared_on_height_idx ON public.addresses_t_u USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_t_u_uid_address_public_key_idx ON public.addresses_t_u USING btree (uid, address, public_key);


CREATE INDEX addresses_u_v_address_uid_idx ON public.addresses_u_v USING btree (address, uid);


CREATE INDEX addresses_u_v_public_key_uid_idx ON public.addresses_u_v USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_u_v_uid_address_first_appeared_on_height_idx ON public.addresses_u_v USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_u_v_uid_address_public_key_idx ON public.addresses_u_v USING btree (uid, address, public_key);


CREATE INDEX addresses_v_w_address_uid_idx ON public.addresses_v_w USING btree (address, uid);


CREATE INDEX addresses_v_w_public_key_uid_idx ON public.addresses_v_w USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_v_w_uid_address_first_appeared_on_height_idx ON public.addresses_v_w USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_v_w_uid_address_public_key_idx ON public.addresses_v_w USING btree (uid, address, public_key);


CREATE INDEX addresses_w_x_address_uid_idx ON public.addresses_w_x USING btree (address, uid);


CREATE INDEX addresses_w_x_public_key_uid_idx ON public.addresses_w_x USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_w_x_uid_address_first_appeared_on_height_idx ON public.addresses_w_x USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_w_x_uid_address_public_key_idx ON public.addresses_w_x USING btree (uid, address, public_key);


CREATE INDEX addresses_x_y_address_uid_idx ON public.addresses_x_y USING btree (address, uid);


CREATE INDEX addresses_x_y_public_key_uid_idx ON public.addresses_x_y USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_x_y_uid_address_first_appeared_on_height_idx ON public.addresses_x_y USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_x_y_uid_address_public_key_idx ON public.addresses_x_y USING btree (uid, address, public_key);


CREATE INDEX addresses_y_z_address_uid_idx ON public.addresses_y_z USING btree (address, uid);


CREATE INDEX addresses_y_z_public_key_uid_idx ON public.addresses_y_z USING btree (public_key, uid);


CREATE UNIQUE INDEX addresses_y_z_uid_address_first_appeared_on_height_idx ON public.addresses_y_z USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_y_z_uid_address_public_key_idx ON public.addresses_y_z USING btree (uid, address, public_key);


CREATE INDEX addresses_z_address_uid_idx ON public.addresses_z USING btree (address, uid);


CREATE INDEX addresses_z_public_key_uid_idx ON public.addresses_z USING btree (public_key, uid);


CREATE INDEX addresses_first_appeared_on_height_idx ON public.addresses USING btree (first_appeared_on_height);


CREATE UNIQUE INDEX addresses_z_uid_address_first_appeared_on_height_idx ON public.addresses_z USING btree (uid, address, first_appeared_on_height);


CREATE UNIQUE INDEX addresses_z_uid_address_public_key_idx ON public.addresses_z USING btree (uid, address, public_key);


CREATE INDEX assets_asset_id_idx ON public.assets USING btree (asset_id);


CREATE INDEX assets_asset_name_idx ON public.assets USING btree (asset_name varchar_pattern_ops);


CREATE UNIQUE INDEX assets_map_asset_id_first_appeared_on_height_idx ON public.assets USING btree (asset_id, first_appeared_on_height);


CREATE INDEX assets_map_first_appeared_on_height_idx ON public.assets USING btree (first_appeared_on_height);


CREATE INDEX assets_metadata_asset_name_idx ON public.assets_metadata USING btree (asset_name text_pattern_ops);


CREATE INDEX assets_ticker_idx ON public.assets USING btree (ticker text_pattern_ops);


CREATE INDEX candles_max_height_index ON public.candles USING btree (max_height);


CREATE INDEX orders_height_idx ON ONLY public.orders USING btree (height);


CREATE INDEX orders_0_30000000_height_idx ON public.orders_0_30000000 USING btree (height);


CREATE INDEX orders_id_uid_idx ON ONLY public.orders USING btree (id, uid);


CREATE INDEX orders_0_30000000_id_uid_idx ON public.orders_0_30000000 USING btree (id, uid);


CREATE INDEX orders_120000000_150000000_height_idx ON public.orders_120000000_150000000 USING btree (height);


CREATE INDEX orders_120000000_150000000_id_uid_idx ON public.orders_120000000_150000000 USING btree (id, uid);


CREATE INDEX orders_150000000_180000000_height_idx ON public.orders_150000000_180000000 USING btree (height);


CREATE INDEX orders_150000000_180000000_id_uid_idx ON public.orders_150000000_180000000 USING btree (id, uid);


CREATE INDEX orders_180000000_210000000_height_idx ON public.orders_180000000_210000000 USING btree (height);


CREATE INDEX orders_180000000_210000000_id_uid_idx ON public.orders_180000000_210000000 USING btree (id, uid);


CREATE INDEX orders_210000000_240000000_height_idx ON public.orders_210000000_240000000 USING btree (height);


CREATE INDEX orders_210000000_240000000_id_uid_idx ON public.orders_210000000_240000000 USING btree (id, uid);


CREATE INDEX orders_240000000_270000000_height_idx ON public.orders_240000000_270000000 USING btree (height);


CREATE INDEX orders_240000000_270000000_id_uid_idx ON public.orders_240000000_270000000 USING btree (id, uid);


CREATE INDEX orders_270000000_300000000_height_idx ON public.orders_270000000_300000000 USING btree (height);


CREATE INDEX orders_270000000_300000000_id_uid_idx ON public.orders_270000000_300000000 USING btree (id, uid);


CREATE INDEX orders_300000000_330000000_height_idx ON public.orders_300000000_330000000 USING btree (height);


CREATE INDEX orders_300000000_330000000_id_uid_idx ON public.orders_300000000_330000000 USING btree (id, uid);


CREATE INDEX orders_30000000_60000000_height_idx ON public.orders_30000000_60000000 USING btree (height);


CREATE INDEX orders_30000000_60000000_id_uid_idx ON public.orders_30000000_60000000 USING btree (id, uid);


CREATE INDEX orders_60000000_90000000_height_idx ON public.orders_60000000_90000000 USING btree (height);


CREATE INDEX orders_60000000_90000000_id_uid_idx ON public.orders_60000000_90000000 USING btree (id, uid);


CREATE INDEX orders_90000000_120000000_height_idx ON public.orders_90000000_120000000 USING btree (height);


CREATE INDEX orders_90000000_120000000_id_uid_idx ON public.orders_90000000_120000000 USING btree (id, uid);


CREATE INDEX orders_default_height_idx ON public.orders_default USING btree (height);


CREATE INDEX orders_default_id_uid_idx ON public.orders_default USING btree (id, uid);


CREATE INDEX searchable_asset_name_idx ON public.assets USING gin (searchable_asset_name);


CREATE INDEX txs_height_idx ON ONLY public.txs USING btree (height);


CREATE INDEX txs_0_1_height_idx ON public.txs_0_1 USING btree (height);


CREATE INDEX txs_id_uid_idx ON ONLY public.txs USING btree (id, uid);


CREATE INDEX txs_0_1_id_uid_idx ON public.txs_0_1 USING btree (id, uid);


CREATE INDEX txs_sender_uid_idx ON ONLY public.txs USING btree (sender_uid);


CREATE INDEX txs_0_1_sender_uid_idx ON public.txs_0_1 USING btree (sender_uid);


CREATE INDEX txs_sender_uid_uid_idx ON ONLY public.txs USING btree (sender_uid, uid);


CREATE INDEX txs_0_1_sender_uid_uid_idx ON public.txs_0_1 USING btree (sender_uid, uid);


CREATE INDEX txs_time_stamp_idx ON ONLY public.txs USING btree (time_stamp);


CREATE INDEX txs_0_1_time_stamp_idx ON public.txs_0_1 USING btree (time_stamp);


CREATE INDEX txs_time_stamp_uid_idx ON ONLY public.txs USING btree (time_stamp, uid);


CREATE INDEX txs_0_1_time_stamp_uid_idx ON public.txs_0_1 USING btree (time_stamp, uid);


CREATE INDEX txs_tx_type_idx ON ONLY public.txs USING btree (tx_type);


CREATE INDEX txs_0_1_tx_type_idx ON public.txs_0_1 USING btree (tx_type);


CREATE INDEX txs_uid_idx ON ONLY public.txs USING btree (uid);


CREATE INDEX txs_0_1_uid_idx ON public.txs_0_1 USING btree (uid);


CREATE INDEX txs_10_alias_idx ON ONLY public.txs_10 USING hash (alias);


CREATE INDEX txs_10_alias_sender_uid_idx ON ONLY public.txs_10 USING btree (alias, sender_uid);


CREATE INDEX txs_10_alias_tuid_idx ON ONLY public.txs_10 USING btree (alias, tx_uid);


CREATE INDEX txs_10_default_alias_idx ON public.txs_10_default USING hash (alias);


CREATE INDEX txs_10_default_alias_sender_uid_idx ON public.txs_10_default USING btree (alias, sender_uid);


CREATE INDEX txs_10_default_alias_tx_uid_idx ON public.txs_10_default USING btree (alias, tx_uid);


CREATE INDEX txs_10_height_idx ON ONLY public.txs_10 USING btree (height);


CREATE INDEX txs_10_default_height_idx ON public.txs_10_default USING btree (height);


CREATE INDEX txs_10_sender_uid_idx ON ONLY public.txs_10 USING hash (sender_uid);


CREATE INDEX txs_10_default_sender_uid_idx ON public.txs_10_default USING hash (sender_uid);


CREATE INDEX txs_10_tx_uid_alias_idx ON ONLY public.txs_10 USING btree (tx_uid, alias);


CREATE INDEX txs_10_default_tx_uid_alias_idx ON public.txs_10_default USING btree (tx_uid, alias);


CREATE INDEX txs_11_asset_uid_idx ON ONLY public.txs_11 USING hash (asset_uid);


CREATE INDEX txs_11_default_asset_uid_idx ON public.txs_11_default USING hash (asset_uid);


CREATE INDEX txs_11_height_idx ON ONLY public.txs_11 USING btree (height);


CREATE INDEX txs_11_default_height_idx ON public.txs_11_default USING btree (height);


CREATE INDEX txs_11_sender_uid_idx ON ONLY public.txs_11 USING btree (sender_uid, tx_uid);


CREATE INDEX txs_11_default_sender_uid_tx_uid_idx ON public.txs_11_default USING btree (sender_uid, tx_uid);


CREATE INDEX txs_11_transfers_height_idx ON ONLY public.txs_11_transfers USING btree (height);


CREATE INDEX txs_11_transfers_0_30000000_height_idx ON public.txs_11_transfers_0_30000000 USING btree (height);


CREATE INDEX txs_11_transfers_recipient_index ON ONLY public.txs_11_transfers USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_0_30000000_recipient_address_uid_idx ON public.txs_11_transfers_0_30000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_tuid_idx ON ONLY public.txs_11_transfers USING btree (tx_uid);


CREATE INDEX txs_11_transfers_0_30000000_tx_uid_idx ON public.txs_11_transfers_0_30000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_120000000_150000000_height_idx ON public.txs_11_transfers_120000000_150000000 USING btree (height);


CREATE INDEX txs_11_transfers_120000000_150000000_recipient_address_uid_idx ON public.txs_11_transfers_120000000_150000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_120000000_150000000_tx_uid_idx ON public.txs_11_transfers_120000000_150000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_150000000_180000000_height_idx ON public.txs_11_transfers_150000000_180000000 USING btree (height);


CREATE INDEX txs_11_transfers_150000000_180000000_recipient_address_uid_idx ON public.txs_11_transfers_150000000_180000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_150000000_180000000_tx_uid_idx ON public.txs_11_transfers_150000000_180000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_180000000_210000000_height_idx ON public.txs_11_transfers_180000000_210000000 USING btree (height);


CREATE INDEX txs_11_transfers_180000000_210000000_recipient_address_uid_idx ON public.txs_11_transfers_180000000_210000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_180000000_210000000_tx_uid_idx ON public.txs_11_transfers_180000000_210000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_210000000_240000000_height_idx ON public.txs_11_transfers_210000000_240000000 USING btree (height);


CREATE INDEX txs_11_transfers_210000000_240000000_recipient_address_uid_idx ON public.txs_11_transfers_210000000_240000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_210000000_240000000_tx_uid_idx ON public.txs_11_transfers_210000000_240000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_240000000_270000000_height_idx ON public.txs_11_transfers_240000000_270000000 USING btree (height);


CREATE INDEX txs_11_transfers_240000000_270000000_recipient_address_uid_idx ON public.txs_11_transfers_240000000_270000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_240000000_270000000_tx_uid_idx ON public.txs_11_transfers_240000000_270000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_270000000_300000000_height_idx ON public.txs_11_transfers_270000000_300000000 USING btree (height);


CREATE INDEX txs_11_transfers_270000000_300000000_recipient_address_uid_idx ON public.txs_11_transfers_270000000_300000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_270000000_300000000_tx_uid_idx ON public.txs_11_transfers_270000000_300000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_300000000_330000000_height_idx ON public.txs_11_transfers_300000000_330000000 USING btree (height);


CREATE INDEX txs_11_transfers_300000000_330000000_recipient_address_uid_idx ON public.txs_11_transfers_300000000_330000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_300000000_330000000_tx_uid_idx ON public.txs_11_transfers_300000000_330000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_30000000_60000000_height_idx ON public.txs_11_transfers_30000000_60000000 USING btree (height);


CREATE INDEX txs_11_transfers_30000000_60000000_recipient_address_uid_idx ON public.txs_11_transfers_30000000_60000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_30000000_60000000_tx_uid_idx ON public.txs_11_transfers_30000000_60000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_330000000_360000000_height_idx ON public.txs_11_transfers_330000000_360000000 USING btree (height);


CREATE INDEX txs_11_transfers_330000000_360000000_recipient_address_uid_idx ON public.txs_11_transfers_330000000_360000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_330000000_360000000_tx_uid_idx ON public.txs_11_transfers_330000000_360000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_360000000_390000000_height_idx ON public.txs_11_transfers_360000000_390000000 USING btree (height);


CREATE INDEX txs_11_transfers_360000000_390000000_recipient_address_uid_idx ON public.txs_11_transfers_360000000_390000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_360000000_390000000_tx_uid_idx ON public.txs_11_transfers_360000000_390000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_390000000_420000000_height_idx ON public.txs_11_transfers_390000000_420000000 USING btree (height);


CREATE INDEX txs_11_transfers_390000000_420000000_recipient_address_uid_idx ON public.txs_11_transfers_390000000_420000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_390000000_420000000_tx_uid_idx ON public.txs_11_transfers_390000000_420000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_420000000_450000000_height_idx ON public.txs_11_transfers_420000000_450000000 USING btree (height);


CREATE INDEX txs_11_transfers_420000000_450000000_recipient_address_uid_idx ON public.txs_11_transfers_420000000_450000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_420000000_450000000_tx_uid_idx ON public.txs_11_transfers_420000000_450000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_450000000_480000000_height_idx ON public.txs_11_transfers_450000000_480000000 USING btree (height);


CREATE INDEX txs_11_transfers_450000000_480000000_recipient_address_uid_idx ON public.txs_11_transfers_450000000_480000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_450000000_480000000_tx_uid_idx ON public.txs_11_transfers_450000000_480000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_480000000_510000000_height_idx ON public.txs_11_transfers_480000000_510000000 USING btree (height);


CREATE INDEX txs_11_transfers_480000000_510000000_recipient_address_uid_idx ON public.txs_11_transfers_480000000_510000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_480000000_510000000_tx_uid_idx ON public.txs_11_transfers_480000000_510000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_510000000_540000000_height_idx ON public.txs_11_transfers_510000000_540000000 USING btree (height);


CREATE INDEX txs_11_transfers_510000000_540000000_recipient_address_uid_idx ON public.txs_11_transfers_510000000_540000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_510000000_540000000_tx_uid_idx ON public.txs_11_transfers_510000000_540000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_540000000_570000000_height_idx ON public.txs_11_transfers_540000000_570000000 USING btree (height);


CREATE INDEX txs_11_transfers_540000000_570000000_recipient_address_uid_idx ON public.txs_11_transfers_540000000_570000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_540000000_570000000_tx_uid_idx ON public.txs_11_transfers_540000000_570000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_570000000_600000000_height_idx ON public.txs_11_transfers_570000000_600000000 USING btree (height);


CREATE INDEX txs_11_transfers_570000000_600000000_recipient_address_uid_idx ON public.txs_11_transfers_570000000_600000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_570000000_600000000_tx_uid_idx ON public.txs_11_transfers_570000000_600000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_600000000_630000000_height_idx ON public.txs_11_transfers_600000000_630000000 USING btree (height);


CREATE INDEX txs_11_transfers_600000000_630000000_recipient_address_uid_idx ON public.txs_11_transfers_600000000_630000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_600000000_630000000_tx_uid_idx ON public.txs_11_transfers_600000000_630000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_60000000_90000000_height_idx ON public.txs_11_transfers_60000000_90000000 USING btree (height);


CREATE INDEX txs_11_transfers_60000000_90000000_recipient_address_uid_idx ON public.txs_11_transfers_60000000_90000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_60000000_90000000_tx_uid_idx ON public.txs_11_transfers_60000000_90000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_90000000_120000000_height_idx ON public.txs_11_transfers_90000000_120000000 USING btree (height);


CREATE INDEX txs_11_transfers_90000000_120000000_recipient_address_uid_idx ON public.txs_11_transfers_90000000_120000000 USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_90000000_120000000_tx_uid_idx ON public.txs_11_transfers_90000000_120000000 USING btree (tx_uid);


CREATE INDEX txs_11_transfers_default_height_idx ON public.txs_11_transfers_default USING btree (height);


CREATE INDEX txs_11_transfers_default_recipient_address_uid_idx ON public.txs_11_transfers_default USING btree (recipient_address_uid);


CREATE INDEX txs_11_transfers_default_tx_uid_idx ON public.txs_11_transfers_default USING btree (tx_uid);


CREATE INDEX txs_12_data_data_key_idx ON ONLY public.txs_12_data USING hash (data_key);


CREATE INDEX txs_12_data_0_30000000_data_key_idx ON public.txs_12_data_0_30000000 USING hash (data_key);


CREATE INDEX txs_12_data_data_type_idx ON ONLY public.txs_12_data USING hash (data_type);


CREATE INDEX txs_12_data_0_30000000_data_type_idx ON public.txs_12_data_0_30000000 USING hash (data_type);


CREATE INDEX txs_12_data_value_binary_partial_idx ON ONLY public.txs_12_data USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


CREATE INDEX txs_12_data_0_30000000_data_value_binary_idx ON public.txs_12_data_0_30000000 USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


CREATE INDEX txs_12_data_value_boolean_partial_idx ON ONLY public.txs_12_data USING btree (data_value_boolean) WHERE (data_type = 'boolean'::text);


CREATE INDEX txs_12_data_0_30000000_data_value_boolean_idx ON public.txs_12_data_0_30000000 USING btree (data_value_boolean) WHERE (data_type = 'boolean'::text);


CREATE INDEX txs_12_data_value_integer_partial_idx ON ONLY public.txs_12_data USING btree (data_value_integer) WHERE (data_type = 'integer'::text);


CREATE INDEX txs_12_data_0_30000000_data_value_integer_idx ON public.txs_12_data_0_30000000 USING btree (data_value_integer) WHERE (data_type = 'integer'::text);


CREATE INDEX txs_12_data_value_string_partial_idx ON ONLY public.txs_12_data USING hash (data_value_string) WHERE (data_type = 'string'::text);


CREATE INDEX txs_12_data_0_30000000_data_value_string_idx ON public.txs_12_data_0_30000000 USING hash (data_value_string) WHERE (data_type = 'string'::text);


CREATE INDEX txs_12_data_height_idx ON ONLY public.txs_12_data USING btree (height);


CREATE INDEX txs_12_data_0_30000000_height_idx ON public.txs_12_data_0_30000000 USING btree (height);


CREATE INDEX txs_12_data_tx_uid_idx ON ONLY public.txs_12_data USING btree (tx_uid);


CREATE INDEX txs_12_data_0_30000000_tx_uid_idx ON public.txs_12_data_0_30000000 USING btree (tx_uid);


CREATE INDEX txs_12_data_120000000_150000000_data_key_idx ON public.txs_12_data_120000000_150000000 USING hash (data_key);


CREATE INDEX txs_12_data_120000000_150000000_data_type_idx ON public.txs_12_data_120000000_150000000 USING hash (data_type);


CREATE INDEX txs_12_data_120000000_150000000_data_value_binary_idx ON public.txs_12_data_120000000_150000000 USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


CREATE INDEX txs_12_data_120000000_150000000_data_value_boolean_idx ON public.txs_12_data_120000000_150000000 USING btree (data_value_boolean) WHERE (data_type = 'boolean'::text);


CREATE INDEX txs_12_data_120000000_150000000_data_value_integer_idx ON public.txs_12_data_120000000_150000000 USING btree (data_value_integer) WHERE (data_type = 'integer'::text);


CREATE INDEX txs_12_data_120000000_150000000_data_value_string_idx ON public.txs_12_data_120000000_150000000 USING hash (data_value_string) WHERE (data_type = 'string'::text);


CREATE INDEX txs_12_data_120000000_150000000_height_idx ON public.txs_12_data_120000000_150000000 USING btree (height);


CREATE INDEX txs_12_data_120000000_150000000_tx_uid_idx ON public.txs_12_data_120000000_150000000 USING btree (tx_uid);


CREATE INDEX txs_12_data_150000000_180000000_data_key_idx ON public.txs_12_data_150000000_180000000 USING hash (data_key);


CREATE INDEX txs_12_data_150000000_180000000_data_type_idx ON public.txs_12_data_150000000_180000000 USING hash (data_type);


CREATE INDEX txs_12_data_150000000_180000000_data_value_binary_idx ON public.txs_12_data_150000000_180000000 USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


CREATE INDEX txs_12_data_150000000_180000000_data_value_boolean_idx ON public.txs_12_data_150000000_180000000 USING btree (data_value_boolean) WHERE (data_type = 'boolean'::text);


CREATE INDEX txs_12_data_150000000_180000000_data_value_integer_idx ON public.txs_12_data_150000000_180000000 USING btree (data_value_integer) WHERE (data_type = 'integer'::text);


CREATE INDEX txs_12_data_150000000_180000000_data_value_string_idx ON public.txs_12_data_150000000_180000000 USING hash (data_value_string) WHERE (data_type = 'string'::text);


CREATE INDEX txs_12_data_150000000_180000000_height_idx ON public.txs_12_data_150000000_180000000 USING btree (height);


CREATE INDEX txs_12_data_150000000_180000000_tx_uid_idx ON public.txs_12_data_150000000_180000000 USING btree (tx_uid);


CREATE INDEX txs_12_data_180000000_210000000_data_key_idx ON public.txs_12_data_180000000_210000000 USING hash (data_key);


CREATE INDEX txs_12_data_180000000_210000000_data_type_idx ON public.txs_12_data_180000000_210000000 USING hash (data_type);


CREATE INDEX txs_12_data_180000000_210000000_data_value_binary_idx ON public.txs_12_data_180000000_210000000 USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


CREATE INDEX txs_12_data_180000000_210000000_data_value_boolean_idx ON public.txs_12_data_180000000_210000000 USING btree (data_value_boolean) WHERE (data_type = 'boolean'::text);


CREATE INDEX txs_12_data_180000000_210000000_data_value_integer_idx ON public.txs_12_data_180000000_210000000 USING btree (data_value_integer) WHERE (data_type = 'integer'::text);


CREATE INDEX txs_12_data_180000000_210000000_data_value_string_idx ON public.txs_12_data_180000000_210000000 USING hash (data_value_string) WHERE (data_type = 'string'::text);


CREATE INDEX txs_12_data_180000000_210000000_height_idx ON public.txs_12_data_180000000_210000000 USING btree (height);


CREATE INDEX txs_12_data_180000000_210000000_tx_uid_idx ON public.txs_12_data_180000000_210000000 USING btree (tx_uid);


CREATE INDEX txs_12_data_210000000_240000000_data_key_idx ON public.txs_12_data_210000000_240000000 USING hash (data_key);


CREATE INDEX txs_12_data_210000000_240000000_data_type_idx ON public.txs_12_data_210000000_240000000 USING hash (data_type);


CREATE INDEX txs_12_data_210000000_240000000_data_value_binary_idx ON public.txs_12_data_210000000_240000000 USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


CREATE INDEX txs_12_data_210000000_240000000_data_value_boolean_idx ON public.txs_12_data_210000000_240000000 USING btree (data_value_boolean) WHERE (data_type = 'boolean'::text);


CREATE INDEX txs_12_data_210000000_240000000_data_value_integer_idx ON public.txs_12_data_210000000_240000000 USING btree (data_value_integer) WHERE (data_type = 'integer'::text);


CREATE INDEX txs_12_data_210000000_240000000_data_value_string_idx ON public.txs_12_data_210000000_240000000 USING hash (data_value_string) WHERE (data_type = 'string'::text);


CREATE INDEX txs_12_data_210000000_240000000_height_idx ON public.txs_12_data_210000000_240000000 USING btree (height);


CREATE INDEX txs_12_data_210000000_240000000_tx_uid_idx ON public.txs_12_data_210000000_240000000 USING btree (tx_uid);


CREATE INDEX txs_12_data_240000000_270000000_data_key_idx ON public.txs_12_data_240000000_270000000 USING hash (data_key);


CREATE INDEX txs_12_data_240000000_270000000_data_type_idx ON public.txs_12_data_240000000_270000000 USING hash (data_type);


CREATE INDEX txs_12_data_240000000_270000000_data_value_binary_idx ON public.txs_12_data_240000000_270000000 USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


CREATE INDEX txs_12_data_240000000_270000000_data_value_boolean_idx ON public.txs_12_data_240000000_270000000 USING btree (data_value_boolean) WHERE (data_type = 'boolean'::text);


CREATE INDEX txs_12_data_240000000_270000000_data_value_integer_idx ON public.txs_12_data_240000000_270000000 USING btree (data_value_integer) WHERE (data_type = 'integer'::text);


CREATE INDEX txs_12_data_240000000_270000000_data_value_string_idx ON public.txs_12_data_240000000_270000000 USING hash (data_value_string) WHERE (data_type = 'string'::text);


CREATE INDEX txs_12_data_240000000_270000000_height_idx ON public.txs_12_data_240000000_270000000 USING btree (height);


CREATE INDEX txs_12_data_240000000_270000000_tx_uid_idx ON public.txs_12_data_240000000_270000000 USING btree (tx_uid);


CREATE INDEX txs_12_data_270000000_300000000_data_key_idx ON public.txs_12_data_270000000_300000000 USING hash (data_key);


CREATE INDEX txs_12_data_270000000_300000000_data_type_idx ON public.txs_12_data_270000000_300000000 USING hash (data_type);


CREATE INDEX txs_12_data_270000000_300000000_data_value_binary_idx ON public.txs_12_data_270000000_300000000 USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


CREATE INDEX txs_12_data_270000000_300000000_data_value_boolean_idx ON public.txs_12_data_270000000_300000000 USING btree (data_value_boolean) WHERE (data_type = 'boolean'::text);


CREATE INDEX txs_12_data_270000000_300000000_data_value_integer_idx ON public.txs_12_data_270000000_300000000 USING btree (data_value_integer) WHERE (data_type = 'integer'::text);


CREATE INDEX txs_12_data_270000000_300000000_data_value_string_idx ON public.txs_12_data_270000000_300000000 USING hash (data_value_string) WHERE (data_type = 'string'::text);


CREATE INDEX txs_12_data_270000000_300000000_height_idx ON public.txs_12_data_270000000_300000000 USING btree (height);


CREATE INDEX txs_12_data_270000000_300000000_tx_uid_idx ON public.txs_12_data_270000000_300000000 USING btree (tx_uid);


CREATE INDEX txs_12_data_300000000_330000000_data_key_idx ON public.txs_12_data_300000000_330000000 USING hash (data_key);


CREATE INDEX txs_12_data_300000000_330000000_data_type_idx ON public.txs_12_data_300000000_330000000 USING hash (data_type);


CREATE INDEX txs_12_data_300000000_330000000_data_value_binary_idx ON public.txs_12_data_300000000_330000000 USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


CREATE INDEX txs_12_data_300000000_330000000_data_value_boolean_idx ON public.txs_12_data_300000000_330000000 USING btree (data_value_boolean) WHERE (data_type = 'boolean'::text);


CREATE INDEX txs_12_data_300000000_330000000_data_value_integer_idx ON public.txs_12_data_300000000_330000000 USING btree (data_value_integer) WHERE (data_type = 'integer'::text);


CREATE INDEX txs_12_data_300000000_330000000_data_value_string_idx ON public.txs_12_data_300000000_330000000 USING hash (data_value_string) WHERE (data_type = 'string'::text);


CREATE INDEX txs_12_data_300000000_330000000_height_idx ON public.txs_12_data_300000000_330000000 USING btree (height);


CREATE INDEX txs_12_data_300000000_330000000_tx_uid_idx ON public.txs_12_data_300000000_330000000 USING btree (tx_uid);


CREATE INDEX txs_12_data_30000000_60000000_data_key_idx ON public.txs_12_data_30000000_60000000 USING hash (data_key);


CREATE INDEX txs_12_data_30000000_60000000_data_type_idx ON public.txs_12_data_30000000_60000000 USING hash (data_type);


CREATE INDEX txs_12_data_30000000_60000000_data_value_binary_idx ON public.txs_12_data_30000000_60000000 USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


CREATE INDEX txs_12_data_30000000_60000000_data_value_boolean_idx ON public.txs_12_data_30000000_60000000 USING btree (data_value_boolean) WHERE (data_type = 'boolean'::text);


CREATE INDEX txs_12_data_30000000_60000000_data_value_integer_idx ON public.txs_12_data_30000000_60000000 USING btree (data_value_integer) WHERE (data_type = 'integer'::text);


CREATE INDEX txs_12_data_30000000_60000000_data_value_string_idx ON public.txs_12_data_30000000_60000000 USING hash (data_value_string) WHERE (data_type = 'string'::text);


CREATE INDEX txs_12_data_30000000_60000000_height_idx ON public.txs_12_data_30000000_60000000 USING btree (height);


CREATE INDEX txs_12_data_30000000_60000000_tx_uid_idx ON public.txs_12_data_30000000_60000000 USING btree (tx_uid);


CREATE INDEX txs_12_data_60000000_90000000_data_key_idx ON public.txs_12_data_60000000_90000000 USING hash (data_key);


CREATE INDEX txs_12_data_60000000_90000000_data_type_idx ON public.txs_12_data_60000000_90000000 USING hash (data_type);


CREATE INDEX txs_12_data_60000000_90000000_data_value_binary_idx ON public.txs_12_data_60000000_90000000 USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


CREATE INDEX txs_12_data_60000000_90000000_data_value_boolean_idx ON public.txs_12_data_60000000_90000000 USING btree (data_value_boolean) WHERE (data_type = 'boolean'::text);


CREATE INDEX txs_12_data_60000000_90000000_data_value_integer_idx ON public.txs_12_data_60000000_90000000 USING btree (data_value_integer) WHERE (data_type = 'integer'::text);


CREATE INDEX txs_12_data_60000000_90000000_data_value_string_idx ON public.txs_12_data_60000000_90000000 USING hash (data_value_string) WHERE (data_type = 'string'::text);


CREATE INDEX txs_12_data_60000000_90000000_height_idx ON public.txs_12_data_60000000_90000000 USING btree (height);


CREATE INDEX txs_12_data_60000000_90000000_tx_uid_idx ON public.txs_12_data_60000000_90000000 USING btree (tx_uid);


CREATE INDEX txs_12_data_90000000_120000000_data_key_idx ON public.txs_12_data_90000000_120000000 USING hash (data_key);


CREATE INDEX txs_12_data_90000000_120000000_data_type_idx ON public.txs_12_data_90000000_120000000 USING hash (data_type);


CREATE INDEX txs_12_data_90000000_120000000_data_value_binary_idx ON public.txs_12_data_90000000_120000000 USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


CREATE INDEX txs_12_data_90000000_120000000_data_value_boolean_idx ON public.txs_12_data_90000000_120000000 USING btree (data_value_boolean) WHERE (data_type = 'boolean'::text);


CREATE INDEX txs_12_data_90000000_120000000_data_value_integer_idx ON public.txs_12_data_90000000_120000000 USING btree (data_value_integer) WHERE (data_type = 'integer'::text);


CREATE INDEX txs_12_data_90000000_120000000_data_value_string_idx ON public.txs_12_data_90000000_120000000 USING hash (data_value_string) WHERE (data_type = 'string'::text);


CREATE INDEX txs_12_data_90000000_120000000_height_idx ON public.txs_12_data_90000000_120000000 USING btree (height);


CREATE INDEX txs_12_data_90000000_120000000_tx_uid_idx ON public.txs_12_data_90000000_120000000 USING btree (tx_uid);


CREATE INDEX txs_12_data_default_data_key_idx ON public.txs_12_data_default USING hash (data_key);


CREATE INDEX txs_12_data_default_data_type_idx ON public.txs_12_data_default USING hash (data_type);


CREATE INDEX txs_12_data_default_data_value_binary_idx ON public.txs_12_data_default USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


CREATE INDEX txs_12_data_default_data_value_boolean_idx ON public.txs_12_data_default USING btree (data_value_boolean) WHERE (data_type = 'boolean'::text);


CREATE INDEX txs_12_data_default_data_value_integer_idx ON public.txs_12_data_default USING btree (data_value_integer) WHERE (data_type = 'integer'::text);


CREATE INDEX txs_12_data_default_data_value_string_idx ON public.txs_12_data_default USING hash (data_value_string) WHERE (data_type = 'string'::text);


CREATE INDEX txs_12_data_default_height_idx ON public.txs_12_data_default USING btree (height);


CREATE INDEX txs_12_data_default_tx_uid_idx ON public.txs_12_data_default USING btree (tx_uid);


CREATE INDEX txs_12_height_idx ON ONLY public.txs_12 USING btree (height);


CREATE INDEX txs_12_default_height_idx ON public.txs_12_default USING btree (height);


CREATE INDEX txs_12_sender_uid_idx ON ONLY public.txs_12 USING hash (sender_uid);


CREATE INDEX txs_12_default_sender_uid_idx ON public.txs_12_default USING hash (sender_uid);


CREATE INDEX txs_13_height_idx ON ONLY public.txs_13 USING btree (height);


CREATE INDEX txs_13_default_height_idx ON public.txs_13_default USING btree (height);


CREATE INDEX txs_13_md5_script_idx ON ONLY public.txs_13 USING btree (md5((script)::text));


CREATE INDEX txs_13_default_md5_idx ON public.txs_13_default USING btree (md5((script)::text));


CREATE INDEX txs_13_sender_uid_idx ON ONLY public.txs_13 USING hash (sender_uid);


CREATE INDEX txs_13_default_sender_uid_idx ON public.txs_13_default USING hash (sender_uid);


CREATE INDEX txs_14_height_idx ON ONLY public.txs_14 USING btree (height);


CREATE INDEX txs_14_default_height_idx ON public.txs_14_default USING btree (height);


CREATE INDEX txs_14_sender_uid_idx ON ONLY public.txs_14 USING hash (sender_uid);


CREATE INDEX txs_14_default_sender_uid_idx ON public.txs_14_default USING hash (sender_uid);


CREATE INDEX txs_15_height_idx ON ONLY public.txs_15 USING btree (height);


CREATE INDEX txs_15_default_height_idx ON public.txs_15_default USING btree (height);


CREATE INDEX txs_15_md5_script_idx ON ONLY public.txs_15 USING btree (md5((script)::text));


CREATE INDEX txs_15_default_md5_idx ON public.txs_15_default USING btree (md5((script)::text));


CREATE INDEX txs_15_sender_uid_idx ON ONLY public.txs_15 USING btree (sender_uid);


CREATE INDEX txs_15_default_sender_uid_idx ON public.txs_15_default USING btree (sender_uid);


CREATE INDEX txs_16_dapp_address_uid_idx ON ONLY public.txs_16 USING btree (dapp_address_uid);


CREATE INDEX txs_16_0_30000000_dapp_address_uid_idx ON public.txs_16_0_30000000 USING btree (dapp_address_uid);


CREATE INDEX txs_16_function_name_idx ON ONLY public.txs_16 USING btree (function_name);


CREATE INDEX txs_16_0_30000000_function_name_idx ON public.txs_16_0_30000000 USING btree (function_name);


CREATE INDEX txs_16_height_idx ON ONLY public.txs_16 USING btree (height);


CREATE INDEX txs_16_0_30000000_height_idx ON public.txs_16_0_30000000 USING btree (height);


CREATE INDEX txs_16_sender_uid_idx ON ONLY public.txs_16 USING btree (sender_uid);


CREATE INDEX txs_16_0_30000000_sender_uid_idx ON public.txs_16_0_30000000 USING btree (sender_uid);


CREATE INDEX txs_16_120000001_150000000_dapp_address_uid_idx ON public.txs_16_120000001_150000000 USING btree (dapp_address_uid);


CREATE INDEX txs_16_120000001_150000000_function_name_idx ON public.txs_16_120000001_150000000 USING btree (function_name);


CREATE INDEX txs_16_120000001_150000000_height_idx ON public.txs_16_120000001_150000000 USING btree (height);


CREATE INDEX txs_16_120000001_150000000_sender_uid_idx ON public.txs_16_120000001_150000000 USING btree (sender_uid);


CREATE INDEX txs_16_150000001_180000000_dapp_address_uid_idx ON public.txs_16_150000001_180000000 USING btree (dapp_address_uid);


CREATE INDEX txs_16_150000001_180000000_function_name_idx ON public.txs_16_150000001_180000000 USING btree (function_name);


CREATE INDEX txs_16_150000001_180000000_height_idx ON public.txs_16_150000001_180000000 USING btree (height);


CREATE INDEX txs_16_150000001_180000000_sender_uid_idx ON public.txs_16_150000001_180000000 USING btree (sender_uid);


CREATE INDEX txs_16_180000001_210000000_dapp_address_uid_idx ON public.txs_16_180000001_210000000 USING btree (dapp_address_uid);


CREATE INDEX txs_16_180000001_210000000_function_name_idx ON public.txs_16_180000001_210000000 USING btree (function_name);


CREATE INDEX txs_16_180000001_210000000_height_idx ON public.txs_16_180000001_210000000 USING btree (height);


CREATE INDEX txs_16_180000001_210000000_sender_uid_idx ON public.txs_16_180000001_210000000 USING btree (sender_uid);


CREATE INDEX txs_16_210000001_240000000_dapp_address_uid_idx ON public.txs_16_210000001_240000000 USING btree (dapp_address_uid);


CREATE INDEX txs_16_210000001_240000000_function_name_idx ON public.txs_16_210000001_240000000 USING btree (function_name);


CREATE INDEX txs_16_210000001_240000000_height_idx ON public.txs_16_210000001_240000000 USING btree (height);


CREATE INDEX txs_16_210000001_240000000_sender_uid_idx ON public.txs_16_210000001_240000000 USING btree (sender_uid);


CREATE INDEX txs_16_240000001_270000000_dapp_address_uid_idx ON public.txs_16_240000001_270000000 USING btree (dapp_address_uid);


CREATE INDEX txs_16_240000001_270000000_function_name_idx ON public.txs_16_240000001_270000000 USING btree (function_name);


CREATE INDEX txs_16_240000001_270000000_height_idx ON public.txs_16_240000001_270000000 USING btree (height);


CREATE INDEX txs_16_240000001_270000000_sender_uid_idx ON public.txs_16_240000001_270000000 USING btree (sender_uid);


CREATE INDEX txs_16_270000001_300000000_dapp_address_uid_idx ON public.txs_16_270000001_300000000 USING btree (dapp_address_uid);


CREATE INDEX txs_16_270000001_300000000_function_name_idx ON public.txs_16_270000001_300000000 USING btree (function_name);


CREATE INDEX txs_16_270000001_300000000_height_idx ON public.txs_16_270000001_300000000 USING btree (height);


CREATE INDEX txs_16_270000001_300000000_sender_uid_idx ON public.txs_16_270000001_300000000 USING btree (sender_uid);


CREATE INDEX txs_16_300000001_330000000_dapp_address_uid_idx ON public.txs_16_300000001_330000000 USING btree (dapp_address_uid);


CREATE INDEX txs_16_300000001_330000000_function_name_idx ON public.txs_16_300000001_330000000 USING btree (function_name);


CREATE INDEX txs_16_300000001_330000000_height_idx ON public.txs_16_300000001_330000000 USING btree (height);


CREATE INDEX txs_16_300000001_330000000_sender_uid_idx ON public.txs_16_300000001_330000000 USING btree (sender_uid);


CREATE INDEX txs_16_30000001_60000000_dapp_address_uid_idx ON public.txs_16_30000001_60000000 USING btree (dapp_address_uid);


CREATE INDEX txs_16_30000001_60000000_function_name_idx ON public.txs_16_30000001_60000000 USING btree (function_name);


CREATE INDEX txs_16_30000001_60000000_height_idx ON public.txs_16_30000001_60000000 USING btree (height);


CREATE INDEX txs_16_30000001_60000000_sender_uid_idx ON public.txs_16_30000001_60000000 USING btree (sender_uid);


CREATE INDEX txs_16_60000001_90000000_dapp_address_uid_idx ON public.txs_16_60000001_90000000 USING btree (dapp_address_uid);


CREATE INDEX txs_16_60000001_90000000_function_name_idx ON public.txs_16_60000001_90000000 USING btree (function_name);


CREATE INDEX txs_16_60000001_90000000_height_idx ON public.txs_16_60000001_90000000 USING btree (height);


CREATE INDEX txs_16_60000001_90000000_sender_uid_idx ON public.txs_16_60000001_90000000 USING btree (sender_uid);


CREATE INDEX txs_16_90000001_120000000_dapp_address_uid_idx ON public.txs_16_90000001_120000000 USING btree (dapp_address_uid);


CREATE INDEX txs_16_90000001_120000000_function_name_idx ON public.txs_16_90000001_120000000 USING btree (function_name);


CREATE INDEX txs_16_90000001_120000000_height_idx ON public.txs_16_90000001_120000000 USING btree (height);


CREATE INDEX txs_16_90000001_120000000_sender_uid_idx ON public.txs_16_90000001_120000000 USING btree (sender_uid);


CREATE INDEX txs_16_args_height_idx ON ONLY public.txs_16_args USING btree (height);


CREATE INDEX txs_16_args_0_30000000_height_idx ON public.txs_16_args_0_30000000 USING btree (height);


CREATE INDEX txs_16_args_120000000_150000000_height_idx ON public.txs_16_args_120000000_150000000 USING btree (height);


CREATE INDEX txs_16_args_150000000_180000000_height_idx ON public.txs_16_args_150000000_180000000 USING btree (height);


CREATE INDEX txs_16_args_180000000_210000000_height_idx ON public.txs_16_args_180000000_210000000 USING btree (height);


CREATE INDEX txs_16_args_210000000_240000000_height_idx ON public.txs_16_args_210000000_240000000 USING btree (height);


CREATE INDEX txs_16_args_240000000_270000000_height_idx ON public.txs_16_args_240000000_270000000 USING btree (height);


CREATE INDEX txs_16_args_270000000_300000000_height_idx ON public.txs_16_args_270000000_300000000 USING btree (height);


CREATE INDEX txs_16_args_300000000_330000000_height_idx ON public.txs_16_args_300000000_330000000 USING btree (height);


CREATE INDEX txs_16_args_30000000_60000000_height_idx ON public.txs_16_args_30000000_60000000 USING btree (height);


CREATE INDEX txs_16_args_60000000_90000000_height_idx ON public.txs_16_args_60000000_90000000 USING btree (height);


CREATE INDEX txs_16_args_90000000_120000000_height_idx ON public.txs_16_args_90000000_120000000 USING btree (height);


CREATE INDEX txs_16_args_default_height_idx ON public.txs_16_args_default USING btree (height);


CREATE INDEX txs_16_default_dapp_address_uid_idx ON public.txs_16_default USING btree (dapp_address_uid);


CREATE INDEX txs_16_default_function_name_idx ON public.txs_16_default USING btree (function_name);


CREATE INDEX txs_16_default_height_idx ON public.txs_16_default USING btree (height);


CREATE INDEX txs_16_default_sender_uid_idx ON public.txs_16_default USING btree (sender_uid);


CREATE INDEX txs_16_payment_asset_uid_idx ON ONLY public.txs_16_payment USING btree (asset_uid);


CREATE INDEX txs_16_payment_0_30000000_asset_uid_idx ON public.txs_16_payment_0_30000000 USING btree (asset_uid);


CREATE INDEX txs_16_payment_height_idx ON ONLY public.txs_16_payment USING btree (height);


CREATE INDEX txs_16_payment_0_30000000_height_idx ON public.txs_16_payment_0_30000000 USING btree (height);


CREATE INDEX txs_16_payment_120000000_150000000_asset_uid_idx ON public.txs_16_payment_120000000_150000000 USING btree (asset_uid);


CREATE INDEX txs_16_payment_120000000_150000000_height_idx ON public.txs_16_payment_120000000_150000000 USING btree (height);


CREATE INDEX txs_16_payment_150000000_180000000_asset_uid_idx ON public.txs_16_payment_150000000_180000000 USING btree (asset_uid);


CREATE INDEX txs_16_payment_150000000_180000000_height_idx ON public.txs_16_payment_150000000_180000000 USING btree (height);


CREATE INDEX txs_16_payment_180000000_210000000_asset_uid_idx ON public.txs_16_payment_180000000_210000000 USING btree (asset_uid);


CREATE INDEX txs_16_payment_180000000_210000000_height_idx ON public.txs_16_payment_180000000_210000000 USING btree (height);


CREATE INDEX txs_16_payment_210000000_240000000_asset_uid_idx ON public.txs_16_payment_210000000_240000000 USING btree (asset_uid);


CREATE INDEX txs_16_payment_210000000_240000000_height_idx ON public.txs_16_payment_210000000_240000000 USING btree (height);


CREATE INDEX txs_16_payment_240000000_270000000_asset_uid_idx ON public.txs_16_payment_240000000_270000000 USING btree (asset_uid);


CREATE INDEX txs_16_payment_240000000_270000000_height_idx ON public.txs_16_payment_240000000_270000000 USING btree (height);


CREATE INDEX txs_16_payment_270000000_300000000_asset_uid_idx ON public.txs_16_payment_270000000_300000000 USING btree (asset_uid);


CREATE INDEX txs_16_payment_270000000_300000000_height_idx ON public.txs_16_payment_270000000_300000000 USING btree (height);


CREATE INDEX txs_16_payment_300000000_330000000_asset_uid_idx ON public.txs_16_payment_300000000_330000000 USING btree (asset_uid);


CREATE INDEX txs_16_payment_300000000_330000000_height_idx ON public.txs_16_payment_300000000_330000000 USING btree (height);


CREATE INDEX txs_16_payment_30000000_60000000_asset_uid_idx ON public.txs_16_payment_30000000_60000000 USING btree (asset_uid);


CREATE INDEX txs_16_payment_30000000_60000000_height_idx ON public.txs_16_payment_30000000_60000000 USING btree (height);


CREATE INDEX txs_16_payment_60000000_90000000_asset_uid_idx ON public.txs_16_payment_60000000_90000000 USING btree (asset_uid);


CREATE INDEX txs_16_payment_60000000_90000000_height_idx ON public.txs_16_payment_60000000_90000000 USING btree (height);


CREATE INDEX txs_16_payment_90000000_120000000_asset_uid_idx ON public.txs_16_payment_90000000_120000000 USING btree (asset_uid);


CREATE INDEX txs_16_payment_90000000_120000000_height_idx ON public.txs_16_payment_90000000_120000000 USING btree (height);


CREATE INDEX txs_16_payment_default_asset_uid_idx ON public.txs_16_payment_default USING btree (asset_uid);


CREATE INDEX txs_16_payment_default_height_idx ON public.txs_16_payment_default USING btree (height);


CREATE INDEX txs_1_2_height_idx ON public.txs_1_2 USING btree (height);


CREATE INDEX txs_1_2_id_uid_idx ON public.txs_1_2 USING btree (id, uid);


CREATE INDEX txs_1_2_sender_uid_idx ON public.txs_1_2 USING btree (sender_uid);


CREATE INDEX txs_1_2_sender_uid_uid_idx ON public.txs_1_2 USING btree (sender_uid, uid);


CREATE INDEX txs_1_2_time_stamp_idx ON public.txs_1_2 USING btree (time_stamp);


CREATE INDEX txs_1_2_time_stamp_uid_idx ON public.txs_1_2 USING btree (time_stamp, uid);


CREATE INDEX txs_1_2_tx_type_idx ON public.txs_1_2 USING btree (tx_type);


CREATE INDEX txs_1_2_uid_idx ON public.txs_1_2 USING btree (uid);


CREATE INDEX txs_1_height_idx ON ONLY public.txs_1 USING btree (height);


CREATE INDEX txs_1_default_height_idx ON public.txs_1_default USING btree (height);


CREATE INDEX txs_1_sender_uid_idx ON ONLY public.txs_1 USING btree (sender_uid);


CREATE INDEX txs_1_default_sender_uid_idx ON public.txs_1_default USING btree (sender_uid);


CREATE INDEX txs_2_3_height_idx ON public.txs_2_3 USING btree (height);


CREATE INDEX txs_2_3_id_uid_idx ON public.txs_2_3 USING btree (id, uid);


CREATE INDEX txs_2_3_sender_uid_idx ON public.txs_2_3 USING btree (sender_uid);


CREATE INDEX txs_2_3_sender_uid_uid_idx ON public.txs_2_3 USING btree (sender_uid, uid);


CREATE INDEX txs_2_3_time_stamp_idx ON public.txs_2_3 USING btree (time_stamp);


CREATE INDEX txs_2_3_time_stamp_uid_idx ON public.txs_2_3 USING btree (time_stamp, uid);


CREATE INDEX txs_2_3_tx_type_idx ON public.txs_2_3 USING btree (tx_type);


CREATE INDEX txs_2_3_uid_idx ON public.txs_2_3 USING btree (uid);


CREATE INDEX txs_2_height_idx ON ONLY public.txs_2 USING btree (height);


CREATE INDEX txs_2_default_height_idx ON public.txs_2_default USING btree (height);


CREATE INDEX txs_2_sender_uid_idx ON ONLY public.txs_2 USING hash (sender_uid);


CREATE INDEX txs_2_default_sender_uid_idx ON public.txs_2_default USING hash (sender_uid);


CREATE INDEX txs_3_4_height_idx ON public.txs_3_4 USING btree (height);


CREATE INDEX txs_3_4_id_uid_idx ON public.txs_3_4 USING btree (id, uid);


CREATE INDEX txs_3_4_sender_uid_idx ON public.txs_3_4 USING btree (sender_uid);


CREATE INDEX txs_3_4_sender_uid_uid_idx ON public.txs_3_4 USING btree (sender_uid, uid);


CREATE INDEX txs_3_4_time_stamp_idx ON public.txs_3_4 USING btree (time_stamp);


CREATE INDEX txs_3_4_time_stamp_uid_idx ON public.txs_3_4 USING btree (time_stamp, uid);


CREATE INDEX txs_3_4_tx_type_idx ON public.txs_3_4 USING btree (tx_type);


CREATE INDEX txs_3_4_uid_idx ON public.txs_3_4 USING btree (uid);


CREATE INDEX txs_3_asset_uid_idx ON ONLY public.txs_3 USING hash (asset_uid);


CREATE INDEX txs_3_default_asset_uid_idx ON public.txs_3_default USING hash (asset_uid);


CREATE INDEX txs_3_height_idx ON ONLY public.txs_3 USING btree (height);


CREATE INDEX txs_3_default_height_idx ON public.txs_3_default USING btree (height);


CREATE INDEX txs_3_md5_script_idx ON ONLY public.txs_3 USING btree (md5((script)::text));


CREATE INDEX txs_3_default_md5_idx ON public.txs_3_default USING btree (md5((script)::text));


CREATE INDEX txs_3_sender_uid_idx ON ONLY public.txs_3 USING hash (sender_uid);


CREATE INDEX txs_3_default_sender_uid_idx ON public.txs_3_default USING hash (sender_uid);


CREATE INDEX txs_4_asset_uid_idx ON ONLY public.txs_4 USING btree (asset_uid);


CREATE INDEX txs_4_0_30000000_asset_uid_idx ON public.txs_4_0_30000000 USING btree (asset_uid);


CREATE INDEX txs_4_height_idx ON ONLY public.txs_4 USING btree (height);


CREATE INDEX txs_4_0_30000000_height_idx ON public.txs_4_0_30000000 USING btree (height);


CREATE INDEX txs_4_recipient_address_uid_idx ON ONLY public.txs_4 USING btree (recipient_address_uid);


CREATE INDEX txs_4_0_30000000_recipient_address_uid_idx ON public.txs_4_0_30000000 USING btree (recipient_address_uid);


CREATE INDEX txs_4_sender_uid_idx ON ONLY public.txs_4 USING btree (sender_uid);


CREATE INDEX txs_4_0_30000000_sender_uid_idx ON public.txs_4_0_30000000 USING btree (sender_uid);


CREATE INDEX txs_4_120000000_150000000_asset_uid_idx ON public.txs_4_120000000_150000000 USING btree (asset_uid);


CREATE INDEX txs_4_120000000_150000000_height_idx ON public.txs_4_120000000_150000000 USING btree (height);


CREATE INDEX txs_4_120000000_150000000_recipient_address_uid_idx ON public.txs_4_120000000_150000000 USING btree (recipient_address_uid);


CREATE INDEX txs_4_120000000_150000000_sender_uid_idx ON public.txs_4_120000000_150000000 USING btree (sender_uid);


CREATE INDEX txs_4_150000000_180000000_asset_uid_idx ON public.txs_4_150000000_180000000 USING btree (asset_uid);


CREATE INDEX txs_4_150000000_180000000_height_idx ON public.txs_4_150000000_180000000 USING btree (height);


CREATE INDEX txs_4_150000000_180000000_recipient_address_uid_idx ON public.txs_4_150000000_180000000 USING btree (recipient_address_uid);


CREATE INDEX txs_4_150000000_180000000_sender_uid_idx ON public.txs_4_150000000_180000000 USING btree (sender_uid);


CREATE INDEX txs_4_180000000_210000000_asset_uid_idx ON public.txs_4_180000000_210000000 USING btree (asset_uid);


CREATE INDEX txs_4_180000000_210000000_height_idx ON public.txs_4_180000000_210000000 USING btree (height);


CREATE INDEX txs_4_180000000_210000000_recipient_address_uid_idx ON public.txs_4_180000000_210000000 USING btree (recipient_address_uid);


CREATE INDEX txs_4_180000000_210000000_sender_uid_idx ON public.txs_4_180000000_210000000 USING btree (sender_uid);


CREATE INDEX txs_4_210000000_240000000_asset_uid_idx ON public.txs_4_210000000_240000000 USING btree (asset_uid);


CREATE INDEX txs_4_210000000_240000000_height_idx ON public.txs_4_210000000_240000000 USING btree (height);


CREATE INDEX txs_4_210000000_240000000_recipient_address_uid_idx ON public.txs_4_210000000_240000000 USING btree (recipient_address_uid);


CREATE INDEX txs_4_210000000_240000000_sender_uid_idx ON public.txs_4_210000000_240000000 USING btree (sender_uid);


CREATE INDEX txs_4_240000000_270000000_asset_uid_idx ON public.txs_4_240000000_270000000 USING btree (asset_uid);


CREATE INDEX txs_4_240000000_270000000_height_idx ON public.txs_4_240000000_270000000 USING btree (height);


CREATE INDEX txs_4_240000000_270000000_recipient_address_uid_idx ON public.txs_4_240000000_270000000 USING btree (recipient_address_uid);


CREATE INDEX txs_4_240000000_270000000_sender_uid_idx ON public.txs_4_240000000_270000000 USING btree (sender_uid);


CREATE INDEX txs_4_270000000_300000000_asset_uid_idx ON public.txs_4_270000000_300000000 USING btree (asset_uid);


CREATE INDEX txs_4_270000000_300000000_height_idx ON public.txs_4_270000000_300000000 USING btree (height);


CREATE INDEX txs_4_270000000_300000000_recipient_address_uid_idx ON public.txs_4_270000000_300000000 USING btree (recipient_address_uid);


CREATE INDEX txs_4_270000000_300000000_sender_uid_idx ON public.txs_4_270000000_300000000 USING btree (sender_uid);


CREATE INDEX txs_4_300000000_330000000_asset_uid_idx ON public.txs_4_300000000_330000000 USING btree (asset_uid);


CREATE INDEX txs_4_300000000_330000000_height_idx ON public.txs_4_300000000_330000000 USING btree (height);


CREATE INDEX txs_4_300000000_330000000_recipient_address_uid_idx ON public.txs_4_300000000_330000000 USING btree (recipient_address_uid);


CREATE INDEX txs_4_300000000_330000000_sender_uid_idx ON public.txs_4_300000000_330000000 USING btree (sender_uid);


CREATE INDEX txs_4_30000000_60000000_asset_uid_idx ON public.txs_4_30000000_60000000 USING btree (asset_uid);


CREATE INDEX txs_4_30000000_60000000_height_idx ON public.txs_4_30000000_60000000 USING btree (height);


CREATE INDEX txs_4_30000000_60000000_recipient_address_uid_idx ON public.txs_4_30000000_60000000 USING btree (recipient_address_uid);


CREATE INDEX txs_4_30000000_60000000_sender_uid_idx ON public.txs_4_30000000_60000000 USING btree (sender_uid);


CREATE INDEX txs_4_5_height_idx ON public.txs_4_5 USING btree (height);


CREATE INDEX txs_4_5_id_uid_idx ON public.txs_4_5 USING btree (id, uid);


CREATE INDEX txs_4_5_sender_uid_idx ON public.txs_4_5 USING btree (sender_uid);


CREATE INDEX txs_4_5_sender_uid_uid_idx ON public.txs_4_5 USING btree (sender_uid, uid);


CREATE INDEX txs_4_5_time_stamp_idx ON public.txs_4_5 USING btree (time_stamp);


CREATE INDEX txs_4_5_time_stamp_uid_idx ON public.txs_4_5 USING btree (time_stamp, uid);


CREATE INDEX txs_4_5_tx_type_idx ON public.txs_4_5 USING btree (tx_type);


CREATE INDEX txs_4_5_uid_idx ON public.txs_4_5 USING btree (uid);


CREATE INDEX txs_4_60000000_90000000_asset_uid_idx ON public.txs_4_60000000_90000000 USING btree (asset_uid);


CREATE INDEX txs_4_60000000_90000000_height_idx ON public.txs_4_60000000_90000000 USING btree (height);


CREATE INDEX txs_4_60000000_90000000_recipient_address_uid_idx ON public.txs_4_60000000_90000000 USING btree (recipient_address_uid);


CREATE INDEX txs_4_60000000_90000000_sender_uid_idx ON public.txs_4_60000000_90000000 USING btree (sender_uid);


CREATE INDEX txs_4_90000000_120000000_asset_uid_idx ON public.txs_4_90000000_120000000 USING btree (asset_uid);


CREATE INDEX txs_4_90000000_120000000_height_idx ON public.txs_4_90000000_120000000 USING btree (height);


CREATE INDEX txs_4_90000000_120000000_recipient_address_uid_idx ON public.txs_4_90000000_120000000 USING btree (recipient_address_uid);


CREATE INDEX txs_4_90000000_120000000_sender_uid_idx ON public.txs_4_90000000_120000000 USING btree (sender_uid);


CREATE INDEX txs_4_default_asset_uid_idx ON public.txs_4_default USING btree (asset_uid);


CREATE INDEX txs_4_default_height_idx ON public.txs_4_default USING btree (height);


CREATE INDEX txs_4_default_recipient_address_uid_idx ON public.txs_4_default USING btree (recipient_address_uid);


CREATE INDEX txs_4_default_sender_uid_idx ON public.txs_4_default USING btree (sender_uid);


CREATE INDEX txs_5_6_height_idx ON public.txs_5_6 USING btree (height);


CREATE INDEX txs_5_6_id_uid_idx ON public.txs_5_6 USING btree (id, uid);


CREATE INDEX txs_5_6_sender_uid_idx ON public.txs_5_6 USING btree (sender_uid);


CREATE INDEX txs_5_6_sender_uid_uid_idx ON public.txs_5_6 USING btree (sender_uid, uid);


CREATE INDEX txs_5_6_time_stamp_idx ON public.txs_5_6 USING btree (time_stamp);


CREATE INDEX txs_5_6_time_stamp_uid_idx ON public.txs_5_6 USING btree (time_stamp, uid);


CREATE INDEX txs_5_6_tx_type_idx ON public.txs_5_6 USING btree (tx_type);


CREATE INDEX txs_5_6_uid_idx ON public.txs_5_6 USING btree (uid);


CREATE INDEX txs_5_asset_uid_idx ON ONLY public.txs_5 USING hash (asset_uid);


CREATE INDEX txs_5_default_asset_uid_idx ON public.txs_5_default USING hash (asset_uid);


CREATE INDEX txs_5_height_idx ON ONLY public.txs_5 USING btree (height);


CREATE INDEX txs_5_default_height_idx ON public.txs_5_default USING btree (height);


CREATE INDEX txs_5_sender_uid_idx ON ONLY public.txs_5 USING hash (sender_uid);


CREATE INDEX txs_5_default_sender_uid_idx ON public.txs_5_default USING hash (sender_uid);


CREATE INDEX txs_6_7_height_idx ON public.txs_6_7 USING btree (height);


CREATE INDEX txs_6_7_id_uid_idx ON public.txs_6_7 USING btree (id, uid);


CREATE INDEX txs_6_7_sender_uid_idx ON public.txs_6_7 USING btree (sender_uid);


CREATE INDEX txs_6_7_sender_uid_uid_idx ON public.txs_6_7 USING btree (sender_uid, uid);


CREATE INDEX txs_6_7_time_stamp_idx ON public.txs_6_7 USING btree (time_stamp);


CREATE INDEX txs_6_7_time_stamp_uid_idx ON public.txs_6_7 USING btree (time_stamp, uid);


CREATE INDEX txs_6_7_tx_type_idx ON public.txs_6_7 USING btree (tx_type);


CREATE INDEX txs_6_7_uid_idx ON public.txs_6_7 USING btree (uid);


CREATE INDEX txs_6_asset_uid_idx ON ONLY public.txs_6 USING hash (asset_uid);


CREATE INDEX txs_6_default_asset_uid_idx ON public.txs_6_default USING hash (asset_uid);


CREATE INDEX txs_6_height_idx ON ONLY public.txs_6 USING btree (height);


CREATE INDEX txs_6_default_height_idx ON public.txs_6_default USING btree (height);


CREATE INDEX txs_6_sender_uid_idx ON ONLY public.txs_6 USING hash (sender_uid);


CREATE INDEX txs_6_default_sender_uid_idx ON public.txs_6_default USING hash (sender_uid);


CREATE INDEX txs_7_height_idx ON ONLY public.txs_7 USING btree (height);


CREATE INDEX txs_7_0_30000000_height_idx ON public.txs_7_0_30000000 USING btree (height);


CREATE INDEX txs_7_sender_uid_idx ON ONLY public.txs_7 USING btree (sender_uid);


CREATE INDEX txs_7_0_30000000_sender_uid_idx ON public.txs_7_0_30000000 USING btree (sender_uid);


CREATE INDEX txs_7_120000000_150000000_height_idx ON public.txs_7_120000000_150000000 USING btree (height);


CREATE INDEX txs_7_120000000_150000000_sender_uid_idx ON public.txs_7_120000000_150000000 USING btree (sender_uid);


CREATE INDEX txs_7_150000000_180000000_height_idx ON public.txs_7_150000000_180000000 USING btree (height);


CREATE INDEX txs_7_150000000_180000000_sender_uid_idx ON public.txs_7_150000000_180000000 USING btree (sender_uid);


CREATE INDEX txs_7_180000000_210000000_height_idx ON public.txs_7_180000000_210000000 USING btree (height);


CREATE INDEX txs_7_180000000_210000000_sender_uid_idx ON public.txs_7_180000000_210000000 USING btree (sender_uid);


CREATE INDEX txs_7_210000000_240000000_height_idx ON public.txs_7_210000000_240000000 USING btree (height);


CREATE INDEX txs_7_210000000_240000000_sender_uid_idx ON public.txs_7_210000000_240000000 USING btree (sender_uid);


CREATE INDEX txs_7_240000000_270000000_height_idx ON public.txs_7_240000000_270000000 USING btree (height);


CREATE INDEX txs_7_240000000_270000000_sender_uid_idx ON public.txs_7_240000000_270000000 USING btree (sender_uid);


CREATE INDEX txs_7_270000000_300000000_height_idx ON public.txs_7_270000000_300000000 USING btree (height);


CREATE INDEX txs_7_270000000_300000000_sender_uid_idx ON public.txs_7_270000000_300000000 USING btree (sender_uid);


CREATE INDEX txs_7_300000000_330000000_height_idx ON public.txs_7_300000000_330000000 USING btree (height);


CREATE INDEX txs_7_300000000_330000000_sender_uid_idx ON public.txs_7_300000000_330000000 USING btree (sender_uid);


CREATE INDEX txs_7_30000000_60000000_height_idx ON public.txs_7_30000000_60000000 USING btree (height);


CREATE INDEX txs_7_30000000_60000000_sender_uid_idx ON public.txs_7_30000000_60000000 USING btree (sender_uid);


CREATE INDEX txs_7_60000000_90000000_height_idx ON public.txs_7_60000000_90000000 USING btree (height);


CREATE INDEX txs_7_60000000_90000000_sender_uid_idx ON public.txs_7_60000000_90000000 USING btree (sender_uid);


CREATE INDEX txs_7_8_height_idx ON public.txs_7_8 USING btree (height);


CREATE INDEX txs_7_8_id_uid_idx ON public.txs_7_8 USING btree (id, uid);


CREATE INDEX txs_7_8_sender_uid_idx ON public.txs_7_8 USING btree (sender_uid);


CREATE INDEX txs_7_8_sender_uid_uid_idx ON public.txs_7_8 USING btree (sender_uid, uid);


CREATE INDEX txs_7_8_time_stamp_idx ON public.txs_7_8 USING btree (time_stamp);


CREATE INDEX txs_7_8_time_stamp_uid_idx ON public.txs_7_8 USING btree (time_stamp, uid);


CREATE INDEX txs_7_8_tx_type_idx ON public.txs_7_8 USING btree (tx_type);


CREATE INDEX txs_7_8_uid_idx ON public.txs_7_8 USING btree (uid);


CREATE INDEX txs_7_90000000_120000000_height_idx ON public.txs_7_90000000_120000000 USING btree (height);


CREATE INDEX txs_7_90000000_120000000_sender_uid_idx ON public.txs_7_90000000_120000000 USING btree (sender_uid);


CREATE INDEX txs_7_default_height_idx ON public.txs_7_default USING btree (height);


CREATE INDEX txs_7_default_sender_uid_idx ON public.txs_7_default USING btree (sender_uid);


CREATE INDEX txs_7_tx_uid_height_idx ON public.txs_7 USING btree (tx_uid, height);


CREATE INDEX txs_7_orders_amount_asset_uid_price_asset_uid_tuid_idx ON ONLY public.txs_7_orders USING btree (amount_asset_uid, price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_0_30000000_amount_asset_uid_price_asset_uid_tx_idx ON public.txs_7_orders_0_30000000 USING btree (amount_asset_uid, price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_amount_asset_uid_tx_uid_idx ON ONLY public.txs_7_orders USING btree (amount_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_0_30000000_amount_asset_uid_tx_uid_idx ON public.txs_7_orders_0_30000000 USING btree (amount_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_height_idx ON ONLY public.txs_7_orders USING btree (height);


CREATE INDEX txs_7_orders_0_30000000_height_idx ON public.txs_7_orders_0_30000000 USING btree (height);


CREATE INDEX txs_7_orders_order_sender_uid_tuid_idx ON ONLY public.txs_7_orders USING btree (order_sender_uid, tx_uid);


CREATE INDEX txs_7_orders_0_30000000_order_sender_uid_tx_uid_idx ON public.txs_7_orders_0_30000000 USING btree (order_sender_uid, tx_uid);


CREATE INDEX txs_7_orders_order_uid_tx_uid_idx ON ONLY public.txs_7_orders USING btree (order_uid, tx_uid);


CREATE INDEX txs_7_orders_0_30000000_order_uid_tx_uid_idx ON public.txs_7_orders_0_30000000 USING btree (order_uid, tx_uid);


CREATE INDEX txs_7_orders_price_asset_uid_tx_uid_idx ON ONLY public.txs_7_orders USING btree (price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_0_30000000_price_asset_uid_tx_uid_idx ON public.txs_7_orders_0_30000000 USING btree (price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_sender_uid_tuid_idx ON ONLY public.txs_7_orders USING btree (sender_uid, tx_uid);


CREATE INDEX txs_7_orders_0_30000000_sender_uid_tx_uid_idx ON public.txs_7_orders_0_30000000 USING btree (sender_uid, tx_uid);


CREATE INDEX txs_7_orders_120000000_150000000_amount_asset_uid_tx_uid_idx ON public.txs_7_orders_120000000_150000000 USING btree (amount_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_120000000_150000000_height_idx ON public.txs_7_orders_120000000_150000000 USING btree (height);


CREATE INDEX txs_7_orders_120000000_150000000_order_sender_uid_tx_uid_idx ON public.txs_7_orders_120000000_150000000 USING btree (order_sender_uid, tx_uid);


CREATE INDEX txs_7_orders_120000000_150000000_order_uid_tx_uid_idx ON public.txs_7_orders_120000000_150000000 USING btree (order_uid, tx_uid);


CREATE INDEX txs_7_orders_120000000_150000000_price_asset_uid_tx_uid_idx ON public.txs_7_orders_120000000_150000000 USING btree (price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_120000000_150000000_sender_uid_tx_uid_idx ON public.txs_7_orders_120000000_150000000 USING btree (sender_uid, tx_uid);


CREATE INDEX txs_7_orders_120000000_150000_amount_asset_uid_price_asset__idx ON public.txs_7_orders_120000000_150000000 USING btree (amount_asset_uid, price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_150000000_180000000_amount_asset_uid_tx_uid_idx ON public.txs_7_orders_150000000_180000000 USING btree (amount_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_150000000_180000000_height_idx ON public.txs_7_orders_150000000_180000000 USING btree (height);


CREATE INDEX txs_7_orders_150000000_180000000_order_sender_uid_tx_uid_idx ON public.txs_7_orders_150000000_180000000 USING btree (order_sender_uid, tx_uid);


CREATE INDEX txs_7_orders_150000000_180000000_order_uid_tx_uid_idx ON public.txs_7_orders_150000000_180000000 USING btree (order_uid, tx_uid);


CREATE INDEX txs_7_orders_150000000_180000000_price_asset_uid_tx_uid_idx ON public.txs_7_orders_150000000_180000000 USING btree (price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_150000000_180000000_sender_uid_tx_uid_idx ON public.txs_7_orders_150000000_180000000 USING btree (sender_uid, tx_uid);


CREATE INDEX txs_7_orders_150000000_180000_amount_asset_uid_price_asset__idx ON public.txs_7_orders_150000000_180000000 USING btree (amount_asset_uid, price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_180000000_210000000_amount_asset_uid_tx_uid_idx ON public.txs_7_orders_180000000_210000000 USING btree (amount_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_180000000_210000000_height_idx ON public.txs_7_orders_180000000_210000000 USING btree (height);


CREATE INDEX txs_7_orders_180000000_210000000_order_sender_uid_tx_uid_idx ON public.txs_7_orders_180000000_210000000 USING btree (order_sender_uid, tx_uid);


CREATE INDEX txs_7_orders_180000000_210000000_order_uid_tx_uid_idx ON public.txs_7_orders_180000000_210000000 USING btree (order_uid, tx_uid);


CREATE INDEX txs_7_orders_180000000_210000000_price_asset_uid_tx_uid_idx ON public.txs_7_orders_180000000_210000000 USING btree (price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_180000000_210000000_sender_uid_tx_uid_idx ON public.txs_7_orders_180000000_210000000 USING btree (sender_uid, tx_uid);


CREATE INDEX txs_7_orders_180000000_210000_amount_asset_uid_price_asset__idx ON public.txs_7_orders_180000000_210000000 USING btree (amount_asset_uid, price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_210000000_240000000_amount_asset_uid_tx_uid_idx ON public.txs_7_orders_210000000_240000000 USING btree (amount_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_210000000_240000000_height_idx ON public.txs_7_orders_210000000_240000000 USING btree (height);


CREATE INDEX txs_7_orders_210000000_240000000_order_sender_uid_tx_uid_idx ON public.txs_7_orders_210000000_240000000 USING btree (order_sender_uid, tx_uid);


CREATE INDEX txs_7_orders_210000000_240000000_order_uid_tx_uid_idx ON public.txs_7_orders_210000000_240000000 USING btree (order_uid, tx_uid);


CREATE INDEX txs_7_orders_210000000_240000000_price_asset_uid_tx_uid_idx ON public.txs_7_orders_210000000_240000000 USING btree (price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_210000000_240000000_sender_uid_tx_uid_idx ON public.txs_7_orders_210000000_240000000 USING btree (sender_uid, tx_uid);


CREATE INDEX txs_7_orders_210000000_240000_amount_asset_uid_price_asset__idx ON public.txs_7_orders_210000000_240000000 USING btree (amount_asset_uid, price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_240000000_270000000_amount_asset_uid_tx_uid_idx ON public.txs_7_orders_240000000_270000000 USING btree (amount_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_240000000_270000000_height_idx ON public.txs_7_orders_240000000_270000000 USING btree (height);


CREATE INDEX txs_7_orders_240000000_270000000_order_sender_uid_tx_uid_idx ON public.txs_7_orders_240000000_270000000 USING btree (order_sender_uid, tx_uid);


CREATE INDEX txs_7_orders_240000000_270000000_order_uid_tx_uid_idx ON public.txs_7_orders_240000000_270000000 USING btree (order_uid, tx_uid);


CREATE INDEX txs_7_orders_240000000_270000000_price_asset_uid_tx_uid_idx ON public.txs_7_orders_240000000_270000000 USING btree (price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_240000000_270000000_sender_uid_tx_uid_idx ON public.txs_7_orders_240000000_270000000 USING btree (sender_uid, tx_uid);


CREATE INDEX txs_7_orders_240000000_270000_amount_asset_uid_price_asset__idx ON public.txs_7_orders_240000000_270000000 USING btree (amount_asset_uid, price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_270000000_300000000_amount_asset_uid_tx_uid_idx ON public.txs_7_orders_270000000_300000000 USING btree (amount_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_270000000_300000000_height_idx ON public.txs_7_orders_270000000_300000000 USING btree (height);


CREATE INDEX txs_7_orders_270000000_300000000_order_sender_uid_tx_uid_idx ON public.txs_7_orders_270000000_300000000 USING btree (order_sender_uid, tx_uid);


CREATE INDEX txs_7_orders_270000000_300000000_order_uid_tx_uid_idx ON public.txs_7_orders_270000000_300000000 USING btree (order_uid, tx_uid);


CREATE INDEX txs_7_orders_270000000_300000000_price_asset_uid_tx_uid_idx ON public.txs_7_orders_270000000_300000000 USING btree (price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_270000000_300000000_sender_uid_tx_uid_idx ON public.txs_7_orders_270000000_300000000 USING btree (sender_uid, tx_uid);


CREATE INDEX txs_7_orders_270000000_300000_amount_asset_uid_price_asset__idx ON public.txs_7_orders_270000000_300000000 USING btree (amount_asset_uid, price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_300000000_330000000_amount_asset_uid_tx_uid_idx ON public.txs_7_orders_300000000_330000000 USING btree (amount_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_300000000_330000000_height_idx ON public.txs_7_orders_300000000_330000000 USING btree (height);


CREATE INDEX txs_7_orders_300000000_330000000_order_sender_uid_tx_uid_idx ON public.txs_7_orders_300000000_330000000 USING btree (order_sender_uid, tx_uid);


CREATE INDEX txs_7_orders_300000000_330000000_order_uid_tx_uid_idx ON public.txs_7_orders_300000000_330000000 USING btree (order_uid, tx_uid);


CREATE INDEX txs_7_orders_300000000_330000000_price_asset_uid_tx_uid_idx ON public.txs_7_orders_300000000_330000000 USING btree (price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_300000000_330000000_sender_uid_tx_uid_idx ON public.txs_7_orders_300000000_330000000 USING btree (sender_uid, tx_uid);


CREATE INDEX txs_7_orders_300000000_330000_amount_asset_uid_price_asset__idx ON public.txs_7_orders_300000000_330000000 USING btree (amount_asset_uid, price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_30000000_60000000_amount_asset_uid_tx_uid_idx ON public.txs_7_orders_30000000_60000000 USING btree (amount_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_30000000_60000000_height_idx ON public.txs_7_orders_30000000_60000000 USING btree (height);


CREATE INDEX txs_7_orders_30000000_60000000_order_sender_uid_tx_uid_idx ON public.txs_7_orders_30000000_60000000 USING btree (order_sender_uid, tx_uid);


CREATE INDEX txs_7_orders_30000000_60000000_order_uid_tx_uid_idx ON public.txs_7_orders_30000000_60000000 USING btree (order_uid, tx_uid);


CREATE INDEX txs_7_orders_30000000_60000000_price_asset_uid_tx_uid_idx ON public.txs_7_orders_30000000_60000000 USING btree (price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_30000000_60000000_sender_uid_tx_uid_idx ON public.txs_7_orders_30000000_60000000 USING btree (sender_uid, tx_uid);


CREATE INDEX txs_7_orders_30000000_6000000_amount_asset_uid_price_asset__idx ON public.txs_7_orders_30000000_60000000 USING btree (amount_asset_uid, price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_60000000_90000000_amount_asset_uid_tx_uid_idx ON public.txs_7_orders_60000000_90000000 USING btree (amount_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_60000000_90000000_height_idx ON public.txs_7_orders_60000000_90000000 USING btree (height);


CREATE INDEX txs_7_orders_60000000_90000000_order_sender_uid_tx_uid_idx ON public.txs_7_orders_60000000_90000000 USING btree (order_sender_uid, tx_uid);


CREATE INDEX txs_7_orders_60000000_90000000_order_uid_tx_uid_idx ON public.txs_7_orders_60000000_90000000 USING btree (order_uid, tx_uid);


CREATE INDEX txs_7_orders_60000000_90000000_price_asset_uid_tx_uid_idx ON public.txs_7_orders_60000000_90000000 USING btree (price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_60000000_90000000_sender_uid_tx_uid_idx ON public.txs_7_orders_60000000_90000000 USING btree (sender_uid, tx_uid);


CREATE INDEX txs_7_orders_60000000_9000000_amount_asset_uid_price_asset__idx ON public.txs_7_orders_60000000_90000000 USING btree (amount_asset_uid, price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_90000000_120000000_amount_asset_uid_tx_uid_idx ON public.txs_7_orders_90000000_120000000 USING btree (amount_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_90000000_120000000_height_idx ON public.txs_7_orders_90000000_120000000 USING btree (height);


CREATE INDEX txs_7_orders_90000000_120000000_order_sender_uid_tx_uid_idx ON public.txs_7_orders_90000000_120000000 USING btree (order_sender_uid, tx_uid);


CREATE INDEX txs_7_orders_90000000_120000000_order_uid_tx_uid_idx ON public.txs_7_orders_90000000_120000000 USING btree (order_uid, tx_uid);


CREATE INDEX txs_7_orders_90000000_120000000_price_asset_uid_tx_uid_idx ON public.txs_7_orders_90000000_120000000 USING btree (price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_90000000_120000000_sender_uid_tx_uid_idx ON public.txs_7_orders_90000000_120000000 USING btree (sender_uid, tx_uid);


CREATE INDEX txs_7_orders_90000000_1200000_amount_asset_uid_price_asset__idx ON public.txs_7_orders_90000000_120000000 USING btree (amount_asset_uid, price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_default_amount_asset_uid_price_asset_uid_tx_ui_idx ON public.txs_7_orders_default USING btree (amount_asset_uid, price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_default_amount_asset_uid_tx_uid_idx ON public.txs_7_orders_default USING btree (amount_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_default_height_idx ON public.txs_7_orders_default USING btree (height);


CREATE INDEX txs_7_orders_default_order_sender_uid_tx_uid_idx ON public.txs_7_orders_default USING btree (order_sender_uid, tx_uid);


CREATE INDEX txs_7_orders_default_order_uid_tx_uid_idx ON public.txs_7_orders_default USING btree (order_uid, tx_uid);


CREATE INDEX txs_7_orders_default_price_asset_uid_tx_uid_idx ON public.txs_7_orders_default USING btree (price_asset_uid, tx_uid);


CREATE INDEX txs_7_orders_default_sender_uid_tx_uid_idx ON public.txs_7_orders_default USING btree (sender_uid, tx_uid);


CREATE INDEX txs_8_9_height_idx ON public.txs_8_9 USING btree (height);


CREATE INDEX txs_8_9_id_uid_idx ON public.txs_8_9 USING btree (id, uid);


CREATE INDEX txs_8_9_sender_uid_idx ON public.txs_8_9 USING btree (sender_uid);


CREATE INDEX txs_8_9_sender_uid_uid_idx ON public.txs_8_9 USING btree (sender_uid, uid);


CREATE INDEX txs_8_9_time_stamp_idx ON public.txs_8_9 USING btree (time_stamp);


CREATE INDEX txs_8_9_time_stamp_uid_idx ON public.txs_8_9 USING btree (time_stamp, uid);


CREATE INDEX txs_8_9_tx_type_idx ON public.txs_8_9 USING btree (tx_type);


CREATE INDEX txs_8_9_uid_idx ON public.txs_8_9 USING btree (uid);


CREATE INDEX txs_8_height_idx ON ONLY public.txs_8 USING btree (height);


CREATE INDEX txs_8_default_height_idx ON public.txs_8_default USING btree (height);


CREATE INDEX txs_8_recipient_idx ON ONLY public.txs_8 USING btree (recipient_address_uid);


CREATE INDEX txs_8_default_recipient_address_uid_idx ON public.txs_8_default USING btree (recipient_address_uid);


CREATE INDEX txs_8_recipient_address_uid_tx_uid_idx ON ONLY public.txs_8 USING btree (recipient_address_uid, tx_uid);


CREATE INDEX txs_8_default_recipient_address_uid_tx_uid_idx ON public.txs_8_default USING btree (recipient_address_uid, tx_uid);


CREATE INDEX txs_8_sender_uid_idx ON ONLY public.txs_8 USING btree (sender_uid);


CREATE INDEX txs_8_default_sender_uid_idx ON public.txs_8_default USING btree (sender_uid);


CREATE INDEX txs_9_a_height_idx ON public.txs_9_a USING btree (height);


CREATE INDEX txs_9_a_id_uid_idx ON public.txs_9_a USING btree (id, uid);


CREATE INDEX txs_9_a_sender_uid_idx ON public.txs_9_a USING btree (sender_uid);


CREATE INDEX txs_9_a_sender_uid_uid_idx ON public.txs_9_a USING btree (sender_uid, uid);


CREATE INDEX txs_9_a_time_stamp_idx ON public.txs_9_a USING btree (time_stamp);


CREATE INDEX txs_9_a_time_stamp_uid_idx ON public.txs_9_a USING btree (time_stamp, uid);


CREATE INDEX txs_9_a_tx_type_idx ON public.txs_9_a USING btree (tx_type);


CREATE INDEX txs_9_a_uid_idx ON public.txs_9_a USING btree (uid);


CREATE INDEX txs_9_height_idx ON ONLY public.txs_9 USING btree (height);


CREATE INDEX txs_9_default_height_idx ON public.txs_9_default USING btree (height);


CREATE INDEX txs_9_sender_idx ON ONLY public.txs_9 USING hash (sender_uid);


CREATE INDEX txs_9_default_sender_uid_idx ON public.txs_9_default USING hash (sender_uid);


CREATE INDEX txs_a_b_height_idx ON public.txs_a_b USING btree (height);


CREATE INDEX txs_a_b_id_uid_idx ON public.txs_a_b USING btree (id, uid);


CREATE INDEX txs_a_b_sender_uid_idx ON public.txs_a_b USING btree (sender_uid);


CREATE INDEX txs_a_b_sender_uid_uid_idx ON public.txs_a_b USING btree (sender_uid, uid);


CREATE INDEX txs_a_b_time_stamp_idx ON public.txs_a_b USING btree (time_stamp);


CREATE INDEX txs_a_b_time_stamp_uid_idx ON public.txs_a_b USING btree (time_stamp, uid);


CREATE INDEX txs_a_b_tx_type_idx ON public.txs_a_b USING btree (tx_type);


CREATE INDEX txs_a_b_uid_idx ON public.txs_a_b USING btree (uid);


CREATE INDEX txs_b_c_height_idx ON public.txs_b_c USING btree (height);


CREATE INDEX txs_b_c_id_uid_idx ON public.txs_b_c USING btree (id, uid);


CREATE INDEX txs_b_c_sender_uid_idx ON public.txs_b_c USING btree (sender_uid);


CREATE INDEX txs_b_c_sender_uid_uid_idx ON public.txs_b_c USING btree (sender_uid, uid);


CREATE INDEX txs_b_c_time_stamp_idx ON public.txs_b_c USING btree (time_stamp);


CREATE INDEX txs_b_c_time_stamp_uid_idx ON public.txs_b_c USING btree (time_stamp, uid);


CREATE INDEX txs_b_c_tx_type_idx ON public.txs_b_c USING btree (tx_type);


CREATE INDEX txs_b_c_uid_idx ON public.txs_b_c USING btree (uid);


CREATE INDEX txs_c_d_height_idx ON public.txs_c_d USING btree (height);


CREATE INDEX txs_c_d_id_uid_idx ON public.txs_c_d USING btree (id, uid);


CREATE INDEX txs_c_d_sender_uid_idx ON public.txs_c_d USING btree (sender_uid);


CREATE INDEX txs_c_d_sender_uid_uid_idx ON public.txs_c_d USING btree (sender_uid, uid);


CREATE INDEX txs_c_d_time_stamp_idx ON public.txs_c_d USING btree (time_stamp);


CREATE INDEX txs_c_d_time_stamp_uid_idx ON public.txs_c_d USING btree (time_stamp, uid);


CREATE INDEX txs_c_d_tx_type_idx ON public.txs_c_d USING btree (tx_type);


CREATE INDEX txs_c_d_uid_idx ON public.txs_c_d USING btree (uid);


CREATE INDEX txs_d_e_height_idx ON public.txs_d_e USING btree (height);


CREATE INDEX txs_d_e_id_uid_idx ON public.txs_d_e USING btree (id, uid);


CREATE INDEX txs_d_e_sender_uid_idx ON public.txs_d_e USING btree (sender_uid);


CREATE INDEX txs_d_e_sender_uid_uid_idx ON public.txs_d_e USING btree (sender_uid, uid);


CREATE INDEX txs_d_e_time_stamp_idx ON public.txs_d_e USING btree (time_stamp);


CREATE INDEX txs_d_e_time_stamp_uid_idx ON public.txs_d_e USING btree (time_stamp, uid);


CREATE INDEX txs_d_e_tx_type_idx ON public.txs_d_e USING btree (tx_type);


CREATE INDEX txs_d_e_uid_idx ON public.txs_d_e USING btree (uid);


CREATE INDEX txs_e_f_height_idx ON public.txs_e_f USING btree (height);


CREATE INDEX txs_e_f_id_uid_idx ON public.txs_e_f USING btree (id, uid);


CREATE INDEX txs_e_f_sender_uid_idx ON public.txs_e_f USING btree (sender_uid);


CREATE INDEX txs_e_f_sender_uid_uid_idx ON public.txs_e_f USING btree (sender_uid, uid);


CREATE INDEX txs_e_f_time_stamp_idx ON public.txs_e_f USING btree (time_stamp);


CREATE INDEX txs_e_f_time_stamp_uid_idx ON public.txs_e_f USING btree (time_stamp, uid);


CREATE INDEX txs_e_f_tx_type_idx ON public.txs_e_f USING btree (tx_type);


CREATE INDEX txs_e_f_uid_idx ON public.txs_e_f USING btree (uid);


CREATE INDEX txs_f_g_height_idx ON public.txs_f_g USING btree (height);


CREATE INDEX txs_f_g_id_uid_idx ON public.txs_f_g USING btree (id, uid);


CREATE INDEX txs_f_g_sender_uid_idx ON public.txs_f_g USING btree (sender_uid);


CREATE INDEX txs_f_g_sender_uid_uid_idx ON public.txs_f_g USING btree (sender_uid, uid);


CREATE INDEX txs_f_g_time_stamp_idx ON public.txs_f_g USING btree (time_stamp);


CREATE INDEX txs_f_g_time_stamp_uid_idx ON public.txs_f_g USING btree (time_stamp, uid);


CREATE INDEX txs_f_g_tx_type_idx ON public.txs_f_g USING btree (tx_type);


CREATE INDEX txs_f_g_uid_idx ON public.txs_f_g USING btree (uid);


CREATE INDEX txs_g_h_height_idx ON public.txs_g_h USING btree (height);


CREATE INDEX txs_g_h_id_uid_idx ON public.txs_g_h USING btree (id, uid);


CREATE INDEX txs_g_h_sender_uid_idx ON public.txs_g_h USING btree (sender_uid);


CREATE INDEX txs_g_h_sender_uid_uid_idx ON public.txs_g_h USING btree (sender_uid, uid);


CREATE INDEX txs_g_h_time_stamp_idx ON public.txs_g_h USING btree (time_stamp);


CREATE INDEX txs_g_h_time_stamp_uid_idx ON public.txs_g_h USING btree (time_stamp, uid);


CREATE INDEX txs_g_h_tx_type_idx ON public.txs_g_h USING btree (tx_type);


CREATE INDEX txs_g_h_uid_idx ON public.txs_g_h USING btree (uid);


CREATE INDEX txs_h_i_height_idx ON public.txs_h_i USING btree (height);


CREATE INDEX txs_h_i_id_uid_idx ON public.txs_h_i USING btree (id, uid);


CREATE INDEX txs_h_i_sender_uid_idx ON public.txs_h_i USING btree (sender_uid);


CREATE INDEX txs_h_i_sender_uid_uid_idx ON public.txs_h_i USING btree (sender_uid, uid);


CREATE INDEX txs_h_i_time_stamp_idx ON public.txs_h_i USING btree (time_stamp);


CREATE INDEX txs_h_i_time_stamp_uid_idx ON public.txs_h_i USING btree (time_stamp, uid);


CREATE INDEX txs_h_i_tx_type_idx ON public.txs_h_i USING btree (tx_type);


CREATE INDEX txs_h_i_uid_idx ON public.txs_h_i USING btree (uid);


CREATE INDEX txs_i_j_height_idx ON public.txs_i_j USING btree (height);


CREATE INDEX txs_i_j_id_uid_idx ON public.txs_i_j USING btree (id, uid);


CREATE INDEX txs_i_j_sender_uid_idx ON public.txs_i_j USING btree (sender_uid);


CREATE INDEX txs_i_j_sender_uid_uid_idx ON public.txs_i_j USING btree (sender_uid, uid);


CREATE INDEX txs_i_j_time_stamp_idx ON public.txs_i_j USING btree (time_stamp);


CREATE INDEX txs_i_j_time_stamp_uid_idx ON public.txs_i_j USING btree (time_stamp, uid);


CREATE INDEX txs_i_j_tx_type_idx ON public.txs_i_j USING btree (tx_type);


CREATE INDEX txs_i_j_uid_idx ON public.txs_i_j USING btree (uid);


CREATE INDEX txs_j_k_height_idx ON public.txs_j_k USING btree (height);


CREATE INDEX txs_j_k_id_uid_idx ON public.txs_j_k USING btree (id, uid);


CREATE INDEX txs_j_k_sender_uid_idx ON public.txs_j_k USING btree (sender_uid);


CREATE INDEX txs_j_k_sender_uid_uid_idx ON public.txs_j_k USING btree (sender_uid, uid);


CREATE INDEX txs_j_k_time_stamp_idx ON public.txs_j_k USING btree (time_stamp);


CREATE INDEX txs_j_k_time_stamp_uid_idx ON public.txs_j_k USING btree (time_stamp, uid);


CREATE INDEX txs_j_k_tx_type_idx ON public.txs_j_k USING btree (tx_type);


CREATE INDEX txs_j_k_uid_idx ON public.txs_j_k USING btree (uid);


CREATE INDEX txs_k_l_height_idx ON public.txs_k_l USING btree (height);


CREATE INDEX txs_k_l_id_uid_idx ON public.txs_k_l USING btree (id, uid);


CREATE INDEX txs_k_l_sender_uid_idx ON public.txs_k_l USING btree (sender_uid);


CREATE INDEX txs_k_l_sender_uid_uid_idx ON public.txs_k_l USING btree (sender_uid, uid);


CREATE INDEX txs_k_l_time_stamp_idx ON public.txs_k_l USING btree (time_stamp);


CREATE INDEX txs_k_l_time_stamp_uid_idx ON public.txs_k_l USING btree (time_stamp, uid);


CREATE INDEX txs_k_l_tx_type_idx ON public.txs_k_l USING btree (tx_type);


CREATE INDEX txs_k_l_uid_idx ON public.txs_k_l USING btree (uid);


CREATE INDEX txs_l_m_height_idx ON public.txs_l_m USING btree (height);


CREATE INDEX txs_l_m_id_uid_idx ON public.txs_l_m USING btree (id, uid);


CREATE INDEX txs_l_m_sender_uid_idx ON public.txs_l_m USING btree (sender_uid);


CREATE INDEX txs_l_m_sender_uid_uid_idx ON public.txs_l_m USING btree (sender_uid, uid);


CREATE INDEX txs_l_m_time_stamp_idx ON public.txs_l_m USING btree (time_stamp);


CREATE INDEX txs_l_m_time_stamp_uid_idx ON public.txs_l_m USING btree (time_stamp, uid);


CREATE INDEX txs_l_m_tx_type_idx ON public.txs_l_m USING btree (tx_type);


CREATE INDEX txs_l_m_uid_idx ON public.txs_l_m USING btree (uid);


CREATE INDEX txs_m_n_height_idx ON public.txs_m_n USING btree (height);


CREATE INDEX txs_m_n_id_uid_idx ON public.txs_m_n USING btree (id, uid);


CREATE INDEX txs_m_n_sender_uid_idx ON public.txs_m_n USING btree (sender_uid);


CREATE INDEX txs_m_n_sender_uid_uid_idx ON public.txs_m_n USING btree (sender_uid, uid);


CREATE INDEX txs_m_n_time_stamp_idx ON public.txs_m_n USING btree (time_stamp);


CREATE INDEX txs_m_n_time_stamp_uid_idx ON public.txs_m_n USING btree (time_stamp, uid);


CREATE INDEX txs_m_n_tx_type_idx ON public.txs_m_n USING btree (tx_type);


CREATE INDEX txs_m_n_uid_idx ON public.txs_m_n USING btree (uid);


CREATE INDEX txs_n_o_height_idx ON public.txs_n_o USING btree (height);


CREATE INDEX txs_n_o_id_uid_idx ON public.txs_n_o USING btree (id, uid);


CREATE INDEX txs_n_o_sender_uid_idx ON public.txs_n_o USING btree (sender_uid);


CREATE INDEX txs_n_o_sender_uid_uid_idx ON public.txs_n_o USING btree (sender_uid, uid);


CREATE INDEX txs_n_o_time_stamp_idx ON public.txs_n_o USING btree (time_stamp);


CREATE INDEX txs_n_o_time_stamp_uid_idx ON public.txs_n_o USING btree (time_stamp, uid);


CREATE INDEX txs_n_o_tx_type_idx ON public.txs_n_o USING btree (tx_type);


CREATE INDEX txs_n_o_uid_idx ON public.txs_n_o USING btree (uid);


CREATE INDEX txs_o_p_height_idx ON public.txs_o_p USING btree (height);


CREATE INDEX txs_o_p_id_uid_idx ON public.txs_o_p USING btree (id, uid);


CREATE INDEX txs_o_p_sender_uid_idx ON public.txs_o_p USING btree (sender_uid);


CREATE INDEX txs_o_p_sender_uid_uid_idx ON public.txs_o_p USING btree (sender_uid, uid);


CREATE INDEX txs_o_p_time_stamp_idx ON public.txs_o_p USING btree (time_stamp);


CREATE INDEX txs_o_p_time_stamp_uid_idx ON public.txs_o_p USING btree (time_stamp, uid);


CREATE INDEX txs_o_p_tx_type_idx ON public.txs_o_p USING btree (tx_type);


CREATE INDEX txs_o_p_uid_idx ON public.txs_o_p USING btree (uid);


CREATE INDEX txs_p_q_height_idx ON public.txs_p_q USING btree (height);


CREATE INDEX txs_p_q_id_uid_idx ON public.txs_p_q USING btree (id, uid);


CREATE INDEX txs_p_q_sender_uid_idx ON public.txs_p_q USING btree (sender_uid);


CREATE INDEX txs_p_q_sender_uid_uid_idx ON public.txs_p_q USING btree (sender_uid, uid);


CREATE INDEX txs_p_q_time_stamp_idx ON public.txs_p_q USING btree (time_stamp);


CREATE INDEX txs_p_q_time_stamp_uid_idx ON public.txs_p_q USING btree (time_stamp, uid);


CREATE INDEX txs_p_q_tx_type_idx ON public.txs_p_q USING btree (tx_type);


CREATE INDEX txs_p_q_uid_idx ON public.txs_p_q USING btree (uid);


CREATE INDEX txs_q_r_height_idx ON public.txs_q_r USING btree (height);


CREATE INDEX txs_q_r_id_uid_idx ON public.txs_q_r USING btree (id, uid);


CREATE INDEX txs_q_r_sender_uid_idx ON public.txs_q_r USING btree (sender_uid);


CREATE INDEX txs_q_r_sender_uid_uid_idx ON public.txs_q_r USING btree (sender_uid, uid);


CREATE INDEX txs_q_r_time_stamp_idx ON public.txs_q_r USING btree (time_stamp);


CREATE INDEX txs_q_r_time_stamp_uid_idx ON public.txs_q_r USING btree (time_stamp, uid);


CREATE INDEX txs_q_r_tx_type_idx ON public.txs_q_r USING btree (tx_type);


CREATE INDEX txs_q_r_uid_idx ON public.txs_q_r USING btree (uid);


CREATE INDEX txs_r_s_height_idx ON public.txs_r_s USING btree (height);


CREATE INDEX txs_r_s_id_uid_idx ON public.txs_r_s USING btree (id, uid);


CREATE INDEX txs_r_s_sender_uid_idx ON public.txs_r_s USING btree (sender_uid);


CREATE INDEX txs_r_s_sender_uid_uid_idx ON public.txs_r_s USING btree (sender_uid, uid);


CREATE INDEX txs_r_s_time_stamp_idx ON public.txs_r_s USING btree (time_stamp);


CREATE INDEX txs_r_s_time_stamp_uid_idx ON public.txs_r_s USING btree (time_stamp, uid);


CREATE INDEX txs_r_s_tx_type_idx ON public.txs_r_s USING btree (tx_type);


CREATE INDEX txs_r_s_uid_idx ON public.txs_r_s USING btree (uid);


CREATE INDEX txs_s_t_height_idx ON public.txs_s_t USING btree (height);


CREATE INDEX txs_s_t_id_uid_idx ON public.txs_s_t USING btree (id, uid);


CREATE INDEX txs_s_t_sender_uid_idx ON public.txs_s_t USING btree (sender_uid);


CREATE INDEX txs_s_t_sender_uid_uid_idx ON public.txs_s_t USING btree (sender_uid, uid);


CREATE INDEX txs_s_t_time_stamp_idx ON public.txs_s_t USING btree (time_stamp);


CREATE INDEX txs_s_t_time_stamp_uid_idx ON public.txs_s_t USING btree (time_stamp, uid);


CREATE INDEX txs_s_t_tx_type_idx ON public.txs_s_t USING btree (tx_type);


CREATE INDEX txs_s_t_uid_idx ON public.txs_s_t USING btree (uid);


CREATE INDEX txs_t_u_height_idx ON public.txs_t_u USING btree (height);


CREATE INDEX txs_t_u_id_uid_idx ON public.txs_t_u USING btree (id, uid);


CREATE INDEX txs_t_u_sender_uid_idx ON public.txs_t_u USING btree (sender_uid);


CREATE INDEX txs_t_u_sender_uid_uid_idx ON public.txs_t_u USING btree (sender_uid, uid);


CREATE INDEX txs_t_u_time_stamp_idx ON public.txs_t_u USING btree (time_stamp);


CREATE INDEX txs_t_u_time_stamp_uid_idx ON public.txs_t_u USING btree (time_stamp, uid);


CREATE INDEX txs_t_u_tx_type_idx ON public.txs_t_u USING btree (tx_type);


CREATE INDEX txs_t_u_uid_idx ON public.txs_t_u USING btree (uid);


CREATE INDEX txs_u_v_height_idx ON public.txs_u_v USING btree (height);


CREATE INDEX txs_u_v_id_uid_idx ON public.txs_u_v USING btree (id, uid);


CREATE INDEX txs_u_v_sender_uid_idx ON public.txs_u_v USING btree (sender_uid);


CREATE INDEX txs_u_v_sender_uid_uid_idx ON public.txs_u_v USING btree (sender_uid, uid);


CREATE INDEX txs_u_v_time_stamp_idx ON public.txs_u_v USING btree (time_stamp);


CREATE INDEX txs_u_v_time_stamp_uid_idx ON public.txs_u_v USING btree (time_stamp, uid);


CREATE INDEX txs_u_v_tx_type_idx ON public.txs_u_v USING btree (tx_type);


CREATE INDEX txs_u_v_uid_idx ON public.txs_u_v USING btree (uid);


CREATE INDEX txs_v_w_height_idx ON public.txs_v_w USING btree (height);


CREATE INDEX txs_v_w_id_uid_idx ON public.txs_v_w USING btree (id, uid);


CREATE INDEX txs_v_w_sender_uid_idx ON public.txs_v_w USING btree (sender_uid);


CREATE INDEX txs_v_w_sender_uid_uid_idx ON public.txs_v_w USING btree (sender_uid, uid);


CREATE INDEX txs_v_w_time_stamp_idx ON public.txs_v_w USING btree (time_stamp);


CREATE INDEX txs_v_w_time_stamp_uid_idx ON public.txs_v_w USING btree (time_stamp, uid);


CREATE INDEX txs_v_w_tx_type_idx ON public.txs_v_w USING btree (tx_type);


CREATE INDEX txs_v_w_uid_idx ON public.txs_v_w USING btree (uid);


CREATE INDEX txs_w_x_height_idx ON public.txs_w_x USING btree (height);


CREATE INDEX txs_w_x_id_uid_idx ON public.txs_w_x USING btree (id, uid);


CREATE INDEX txs_w_x_sender_uid_idx ON public.txs_w_x USING btree (sender_uid);


CREATE INDEX txs_w_x_sender_uid_uid_idx ON public.txs_w_x USING btree (sender_uid, uid);


CREATE INDEX txs_w_x_time_stamp_idx ON public.txs_w_x USING btree (time_stamp);


CREATE INDEX txs_w_x_time_stamp_uid_idx ON public.txs_w_x USING btree (time_stamp, uid);


CREATE INDEX txs_w_x_tx_type_idx ON public.txs_w_x USING btree (tx_type);


CREATE INDEX txs_w_x_uid_idx ON public.txs_w_x USING btree (uid);


CREATE INDEX txs_x_y_height_idx ON public.txs_x_y USING btree (height);


CREATE INDEX txs_x_y_id_uid_idx ON public.txs_x_y USING btree (id, uid);


CREATE INDEX txs_x_y_sender_uid_idx ON public.txs_x_y USING btree (sender_uid);


CREATE INDEX txs_x_y_sender_uid_uid_idx ON public.txs_x_y USING btree (sender_uid, uid);


CREATE INDEX txs_x_y_time_stamp_idx ON public.txs_x_y USING btree (time_stamp);


CREATE INDEX txs_x_y_time_stamp_uid_idx ON public.txs_x_y USING btree (time_stamp, uid);


CREATE INDEX txs_x_y_tx_type_idx ON public.txs_x_y USING btree (tx_type);


CREATE INDEX txs_x_y_uid_idx ON public.txs_x_y USING btree (uid);


CREATE INDEX txs_y_z_height_idx ON public.txs_y_z USING btree (height);


CREATE INDEX txs_y_z_id_uid_idx ON public.txs_y_z USING btree (id, uid);


CREATE INDEX txs_y_z_sender_uid_idx ON public.txs_y_z USING btree (sender_uid);


CREATE INDEX txs_y_z_sender_uid_uid_idx ON public.txs_y_z USING btree (sender_uid, uid);


CREATE INDEX txs_y_z_time_stamp_idx ON public.txs_y_z USING btree (time_stamp);


CREATE INDEX txs_y_z_time_stamp_uid_idx ON public.txs_y_z USING btree (time_stamp, uid);


CREATE INDEX txs_y_z_tx_type_idx ON public.txs_y_z USING btree (tx_type);


CREATE INDEX txs_y_z_uid_idx ON public.txs_y_z USING btree (uid);


CREATE INDEX txs_z_height_idx ON public.txs_z USING btree (height);


CREATE INDEX txs_z_id_uid_idx ON public.txs_z USING btree (id, uid);


CREATE INDEX txs_z_sender_uid_idx ON public.txs_z USING btree (sender_uid);


CREATE INDEX txs_z_sender_uid_uid_idx ON public.txs_z USING btree (sender_uid, uid);


CREATE INDEX txs_z_time_stamp_idx ON public.txs_z USING btree (time_stamp);


CREATE INDEX txs_z_time_stamp_uid_idx ON public.txs_z USING btree (time_stamp, uid);


CREATE INDEX txs_z_tx_type_idx ON public.txs_z USING btree (tx_type);


CREATE INDEX txs_z_uid_idx ON public.txs_z USING btree (uid);


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_0_1_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_0_1_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_0_1_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_0_1_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_0_1_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_1_2_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_1_2_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_1_2_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_1_2_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_1_2_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_2_3_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_2_3_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_2_3_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_2_3_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_2_3_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_3_4_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_3_4_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_3_4_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_3_4_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_3_4_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_4_5_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_4_5_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_4_5_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_4_5_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_4_5_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_5_6_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_5_6_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_5_6_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_5_6_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_5_6_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_6_7_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_6_7_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_6_7_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_6_7_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_6_7_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_7_8_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_7_8_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_7_8_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_7_8_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_7_8_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_8_9_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_8_9_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_8_9_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_8_9_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_8_9_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_9_a_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_9_a_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_9_a_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_9_a_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_9_a_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_a_b_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_a_b_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_a_b_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_a_b_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_a_b_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_b_c_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_b_c_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_b_c_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_b_c_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_b_c_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_c_d_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_c_d_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_c_d_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_c_d_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_c_d_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_d_e_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_d_e_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_d_e_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_d_e_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_d_e_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_e_f_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_e_f_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_e_f_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_e_f_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_e_f_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_f_g_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_f_g_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_f_g_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_f_g_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_f_g_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_g_h_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_g_h_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_g_h_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_g_h_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_g_h_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_h_i_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_h_i_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_h_i_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_h_i_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_h_i_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_i_j_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_i_j_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_i_j_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_i_j_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_i_j_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_j_k_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_j_k_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_j_k_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_j_k_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_j_k_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_k_l_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_k_l_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_k_l_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_k_l_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_k_l_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_l_m_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_l_m_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_l_m_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_l_m_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_l_m_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_m_n_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_m_n_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_m_n_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_m_n_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_m_n_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_n_o_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_n_o_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_n_o_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_n_o_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_n_o_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_o_p_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_o_p_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_o_p_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_o_p_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_o_p_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_p_q_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_p_q_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_p_q_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_p_q_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_p_q_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_q_r_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_q_r_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_q_r_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_q_r_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_q_r_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_r_s_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_r_s_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_r_s_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_r_s_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_r_s_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_s_t_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_s_t_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_s_t_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_s_t_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_s_t_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_t_u_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_t_u_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_t_u_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_t_u_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_t_u_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_u_v_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_u_v_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_u_v_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_u_v_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_u_v_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_v_w_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_v_w_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_v_w_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_v_w_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_v_w_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_w_x_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_w_x_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_w_x_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_w_x_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_w_x_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_x_y_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_x_y_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_x_y_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_x_y_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_x_y_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_y_z_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_y_z_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_y_z_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_y_z_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_y_z_uid_address_public_key_idx;


ALTER INDEX public.addresses_address_uid_idx ATTACH PARTITION public.addresses_z_address_uid_idx;


ALTER INDEX public.addresses_pk ATTACH PARTITION public.addresses_z_pkey;


ALTER INDEX public.addresses_public_key_uid_idx ATTACH PARTITION public.addresses_z_public_key_uid_idx;


ALTER INDEX public.addresses_address_first_appeared_on_height_idx ATTACH PARTITION public.addresses_z_uid_address_first_appeared_on_height_idx;


ALTER INDEX public.addresses_uid_address_public_key_idx ATTACH PARTITION public.addresses_z_uid_address_public_key_idx;


ALTER INDEX public.orders_height_idx ATTACH PARTITION public.orders_0_30000000_height_idx;


ALTER INDEX public.orders_id_uid_idx ATTACH PARTITION public.orders_0_30000000_id_uid_idx;


ALTER INDEX public.orders_uid_key ATTACH PARTITION public.orders_0_30000000_uid_key;


ALTER INDEX public.orders_height_idx ATTACH PARTITION public.orders_120000000_150000000_height_idx;


ALTER INDEX public.orders_id_uid_idx ATTACH PARTITION public.orders_120000000_150000000_id_uid_idx;


ALTER INDEX public.orders_uid_key ATTACH PARTITION public.orders_120000000_150000000_uid_key;


ALTER INDEX public.orders_height_idx ATTACH PARTITION public.orders_150000000_180000000_height_idx;


ALTER INDEX public.orders_id_uid_idx ATTACH PARTITION public.orders_150000000_180000000_id_uid_idx;


ALTER INDEX public.orders_uid_key ATTACH PARTITION public.orders_150000000_180000000_uid_key;


ALTER INDEX public.orders_height_idx ATTACH PARTITION public.orders_180000000_210000000_height_idx;


ALTER INDEX public.orders_id_uid_idx ATTACH PARTITION public.orders_180000000_210000000_id_uid_idx;


ALTER INDEX public.orders_uid_key ATTACH PARTITION public.orders_180000000_210000000_uid_key;


ALTER INDEX public.orders_height_idx ATTACH PARTITION public.orders_210000000_240000000_height_idx;


ALTER INDEX public.orders_id_uid_idx ATTACH PARTITION public.orders_210000000_240000000_id_uid_idx;


ALTER INDEX public.orders_uid_key ATTACH PARTITION public.orders_210000000_240000000_uid_key;


ALTER INDEX public.orders_height_idx ATTACH PARTITION public.orders_240000000_270000000_height_idx;


ALTER INDEX public.orders_id_uid_idx ATTACH PARTITION public.orders_240000000_270000000_id_uid_idx;


ALTER INDEX public.orders_uid_key ATTACH PARTITION public.orders_240000000_270000000_uid_key;


ALTER INDEX public.orders_height_idx ATTACH PARTITION public.orders_270000000_300000000_height_idx;


ALTER INDEX public.orders_id_uid_idx ATTACH PARTITION public.orders_270000000_300000000_id_uid_idx;


ALTER INDEX public.orders_uid_key ATTACH PARTITION public.orders_270000000_300000000_uid_key;


ALTER INDEX public.orders_height_idx ATTACH PARTITION public.orders_300000000_330000000_height_idx;


ALTER INDEX public.orders_id_uid_idx ATTACH PARTITION public.orders_300000000_330000000_id_uid_idx;


ALTER INDEX public.orders_uid_key ATTACH PARTITION public.orders_300000000_330000000_uid_key;


ALTER INDEX public.orders_height_idx ATTACH PARTITION public.orders_30000000_60000000_height_idx;


ALTER INDEX public.orders_id_uid_idx ATTACH PARTITION public.orders_30000000_60000000_id_uid_idx;


ALTER INDEX public.orders_uid_key ATTACH PARTITION public.orders_30000000_60000000_uid_key;


ALTER INDEX public.orders_height_idx ATTACH PARTITION public.orders_60000000_90000000_height_idx;


ALTER INDEX public.orders_id_uid_idx ATTACH PARTITION public.orders_60000000_90000000_id_uid_idx;


ALTER INDEX public.orders_uid_key ATTACH PARTITION public.orders_60000000_90000000_uid_key;


ALTER INDEX public.orders_height_idx ATTACH PARTITION public.orders_90000000_120000000_height_idx;


ALTER INDEX public.orders_id_uid_idx ATTACH PARTITION public.orders_90000000_120000000_id_uid_idx;


ALTER INDEX public.orders_uid_key ATTACH PARTITION public.orders_90000000_120000000_uid_key;


ALTER INDEX public.orders_height_idx ATTACH PARTITION public.orders_default_height_idx;


ALTER INDEX public.orders_id_uid_idx ATTACH PARTITION public.orders_default_id_uid_idx;


ALTER INDEX public.orders_uid_key ATTACH PARTITION public.orders_default_uid_key;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_0_1_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_0_1_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_0_1_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_0_1_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_0_1_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_0_1_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_0_1_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_0_1_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_0_1_uid_idx;


ALTER INDEX public.txs_10_alias_idx ATTACH PARTITION public.txs_10_default_alias_idx;


ALTER INDEX public.txs_10_alias_sender_uid_idx ATTACH PARTITION public.txs_10_default_alias_sender_uid_idx;


ALTER INDEX public.txs_10_alias_tuid_idx ATTACH PARTITION public.txs_10_default_alias_tx_uid_idx;


ALTER INDEX public.txs_10_height_idx ATTACH PARTITION public.txs_10_default_height_idx;


ALTER INDEX public.txs_10_sender_uid_idx ATTACH PARTITION public.txs_10_default_sender_uid_idx;


ALTER INDEX public.txs_10_tx_uid_alias_idx ATTACH PARTITION public.txs_10_default_tx_uid_alias_idx;


ALTER INDEX public.txs_10_tx_uid_key ATTACH PARTITION public.txs_10_default_tx_uid_key;


ALTER INDEX public.txs_11_asset_uid_idx ATTACH PARTITION public.txs_11_default_asset_uid_idx;


ALTER INDEX public.txs_11_height_idx ATTACH PARTITION public.txs_11_default_height_idx;


ALTER INDEX public.txs_11_sender_uid_idx ATTACH PARTITION public.txs_11_default_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_11_tx_uid_key ATTACH PARTITION public.txs_11_default_tx_uid_key;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_0_30000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_0_30000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_0_30000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_0_30000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_120000000_150000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_120000000_150000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_120000000_150000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_120000000_150000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_150000000_180000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_150000000_180000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_150000000_180000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_150000000_180000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_180000000_210000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_180000000_210000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_180000000_210000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_180000000_210000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_210000000_240000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_210000000_240000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_210000000_240000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_210000000_240000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_240000000_270000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_240000000_270000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_240000000_270000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_240000000_270000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_270000000_300000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_270000000_300000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_270000000_300000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_270000000_300000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_300000000_330000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_300000000_330000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_300000000_330000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_300000000_330000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_30000000_60000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_30000000_60000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_30000000_60000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_30000000_60000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_330000000_360000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_330000000_360000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_330000000_360000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_330000000_360000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_360000000_390000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_360000000_390000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_360000000_390000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_360000000_390000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_390000000_420000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_390000000_420000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_390000000_420000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_390000000_420000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_420000000_450000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_420000000_450000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_420000000_450000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_420000000_450000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_450000000_480000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_450000000_480000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_450000000_480000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_450000000_480000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_480000000_510000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_480000000_510000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_480000000_510000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_480000000_510000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_510000000_540000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_510000000_540000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_510000000_540000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_510000000_540000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_540000000_570000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_540000000_570000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_540000000_570000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_540000000_570000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_570000000_600000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_570000000_600000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_570000000_600000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_570000000_600000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_600000000_630000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_600000000_630000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_600000000_630000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_600000000_630000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_60000000_90000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_60000000_90000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_60000000_90000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_60000000_90000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_90000000_120000000_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_90000000_120000000_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_90000000_120000000_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_90000000_120000000_tx_uid_idx;


ALTER INDEX public.txs_11_transfers_height_idx ATTACH PARTITION public.txs_11_transfers_default_height_idx;


ALTER INDEX public.txs_11_transfers_pkey ATTACH PARTITION public.txs_11_transfers_default_pkey;


ALTER INDEX public.txs_11_transfers_recipient_index ATTACH PARTITION public.txs_11_transfers_default_recipient_address_uid_idx;


ALTER INDEX public.txs_11_transfers_tuid_idx ATTACH PARTITION public.txs_11_transfers_default_tx_uid_idx;


ALTER INDEX public.txs_12_data_data_key_idx ATTACH PARTITION public.txs_12_data_0_30000000_data_key_idx;


ALTER INDEX public.txs_12_data_data_type_idx ATTACH PARTITION public.txs_12_data_0_30000000_data_type_idx;


ALTER INDEX public.txs_12_data_value_binary_partial_idx ATTACH PARTITION public.txs_12_data_0_30000000_data_value_binary_idx;


ALTER INDEX public.txs_12_data_value_boolean_partial_idx ATTACH PARTITION public.txs_12_data_0_30000000_data_value_boolean_idx;


ALTER INDEX public.txs_12_data_value_integer_partial_idx ATTACH PARTITION public.txs_12_data_0_30000000_data_value_integer_idx;


ALTER INDEX public.txs_12_data_value_string_partial_idx ATTACH PARTITION public.txs_12_data_0_30000000_data_value_string_idx;


ALTER INDEX public.txs_12_data_height_idx ATTACH PARTITION public.txs_12_data_0_30000000_height_idx;


ALTER INDEX public.txs_12_data_pkey ATTACH PARTITION public.txs_12_data_0_30000000_pkey;


ALTER INDEX public.txs_12_data_tx_uid_idx ATTACH PARTITION public.txs_12_data_0_30000000_tx_uid_idx;


ALTER INDEX public.txs_12_data_data_key_idx ATTACH PARTITION public.txs_12_data_120000000_150000000_data_key_idx;


ALTER INDEX public.txs_12_data_data_type_idx ATTACH PARTITION public.txs_12_data_120000000_150000000_data_type_idx;


ALTER INDEX public.txs_12_data_value_binary_partial_idx ATTACH PARTITION public.txs_12_data_120000000_150000000_data_value_binary_idx;


ALTER INDEX public.txs_12_data_value_boolean_partial_idx ATTACH PARTITION public.txs_12_data_120000000_150000000_data_value_boolean_idx;


ALTER INDEX public.txs_12_data_value_integer_partial_idx ATTACH PARTITION public.txs_12_data_120000000_150000000_data_value_integer_idx;


ALTER INDEX public.txs_12_data_value_string_partial_idx ATTACH PARTITION public.txs_12_data_120000000_150000000_data_value_string_idx;


ALTER INDEX public.txs_12_data_height_idx ATTACH PARTITION public.txs_12_data_120000000_150000000_height_idx;


ALTER INDEX public.txs_12_data_pkey ATTACH PARTITION public.txs_12_data_120000000_150000000_pkey;


ALTER INDEX public.txs_12_data_tx_uid_idx ATTACH PARTITION public.txs_12_data_120000000_150000000_tx_uid_idx;


ALTER INDEX public.txs_12_data_data_key_idx ATTACH PARTITION public.txs_12_data_150000000_180000000_data_key_idx;


ALTER INDEX public.txs_12_data_data_type_idx ATTACH PARTITION public.txs_12_data_150000000_180000000_data_type_idx;


ALTER INDEX public.txs_12_data_value_binary_partial_idx ATTACH PARTITION public.txs_12_data_150000000_180000000_data_value_binary_idx;


ALTER INDEX public.txs_12_data_value_boolean_partial_idx ATTACH PARTITION public.txs_12_data_150000000_180000000_data_value_boolean_idx;


ALTER INDEX public.txs_12_data_value_integer_partial_idx ATTACH PARTITION public.txs_12_data_150000000_180000000_data_value_integer_idx;


ALTER INDEX public.txs_12_data_value_string_partial_idx ATTACH PARTITION public.txs_12_data_150000000_180000000_data_value_string_idx;


ALTER INDEX public.txs_12_data_height_idx ATTACH PARTITION public.txs_12_data_150000000_180000000_height_idx;


ALTER INDEX public.txs_12_data_pkey ATTACH PARTITION public.txs_12_data_150000000_180000000_pkey;


ALTER INDEX public.txs_12_data_tx_uid_idx ATTACH PARTITION public.txs_12_data_150000000_180000000_tx_uid_idx;


ALTER INDEX public.txs_12_data_data_key_idx ATTACH PARTITION public.txs_12_data_180000000_210000000_data_key_idx;


ALTER INDEX public.txs_12_data_data_type_idx ATTACH PARTITION public.txs_12_data_180000000_210000000_data_type_idx;


ALTER INDEX public.txs_12_data_value_binary_partial_idx ATTACH PARTITION public.txs_12_data_180000000_210000000_data_value_binary_idx;


ALTER INDEX public.txs_12_data_value_boolean_partial_idx ATTACH PARTITION public.txs_12_data_180000000_210000000_data_value_boolean_idx;


ALTER INDEX public.txs_12_data_value_integer_partial_idx ATTACH PARTITION public.txs_12_data_180000000_210000000_data_value_integer_idx;


ALTER INDEX public.txs_12_data_value_string_partial_idx ATTACH PARTITION public.txs_12_data_180000000_210000000_data_value_string_idx;


ALTER INDEX public.txs_12_data_height_idx ATTACH PARTITION public.txs_12_data_180000000_210000000_height_idx;


ALTER INDEX public.txs_12_data_pkey ATTACH PARTITION public.txs_12_data_180000000_210000000_pkey;


ALTER INDEX public.txs_12_data_tx_uid_idx ATTACH PARTITION public.txs_12_data_180000000_210000000_tx_uid_idx;


ALTER INDEX public.txs_12_data_data_key_idx ATTACH PARTITION public.txs_12_data_210000000_240000000_data_key_idx;


ALTER INDEX public.txs_12_data_data_type_idx ATTACH PARTITION public.txs_12_data_210000000_240000000_data_type_idx;


ALTER INDEX public.txs_12_data_value_binary_partial_idx ATTACH PARTITION public.txs_12_data_210000000_240000000_data_value_binary_idx;


ALTER INDEX public.txs_12_data_value_boolean_partial_idx ATTACH PARTITION public.txs_12_data_210000000_240000000_data_value_boolean_idx;


ALTER INDEX public.txs_12_data_value_integer_partial_idx ATTACH PARTITION public.txs_12_data_210000000_240000000_data_value_integer_idx;


ALTER INDEX public.txs_12_data_value_string_partial_idx ATTACH PARTITION public.txs_12_data_210000000_240000000_data_value_string_idx;


ALTER INDEX public.txs_12_data_height_idx ATTACH PARTITION public.txs_12_data_210000000_240000000_height_idx;


ALTER INDEX public.txs_12_data_pkey ATTACH PARTITION public.txs_12_data_210000000_240000000_pkey;


ALTER INDEX public.txs_12_data_tx_uid_idx ATTACH PARTITION public.txs_12_data_210000000_240000000_tx_uid_idx;


ALTER INDEX public.txs_12_data_data_key_idx ATTACH PARTITION public.txs_12_data_240000000_270000000_data_key_idx;


ALTER INDEX public.txs_12_data_data_type_idx ATTACH PARTITION public.txs_12_data_240000000_270000000_data_type_idx;


ALTER INDEX public.txs_12_data_value_binary_partial_idx ATTACH PARTITION public.txs_12_data_240000000_270000000_data_value_binary_idx;


ALTER INDEX public.txs_12_data_value_boolean_partial_idx ATTACH PARTITION public.txs_12_data_240000000_270000000_data_value_boolean_idx;


ALTER INDEX public.txs_12_data_value_integer_partial_idx ATTACH PARTITION public.txs_12_data_240000000_270000000_data_value_integer_idx;


ALTER INDEX public.txs_12_data_value_string_partial_idx ATTACH PARTITION public.txs_12_data_240000000_270000000_data_value_string_idx;


ALTER INDEX public.txs_12_data_height_idx ATTACH PARTITION public.txs_12_data_240000000_270000000_height_idx;


ALTER INDEX public.txs_12_data_pkey ATTACH PARTITION public.txs_12_data_240000000_270000000_pkey;


ALTER INDEX public.txs_12_data_tx_uid_idx ATTACH PARTITION public.txs_12_data_240000000_270000000_tx_uid_idx;


ALTER INDEX public.txs_12_data_data_key_idx ATTACH PARTITION public.txs_12_data_270000000_300000000_data_key_idx;


ALTER INDEX public.txs_12_data_data_type_idx ATTACH PARTITION public.txs_12_data_270000000_300000000_data_type_idx;


ALTER INDEX public.txs_12_data_value_binary_partial_idx ATTACH PARTITION public.txs_12_data_270000000_300000000_data_value_binary_idx;


ALTER INDEX public.txs_12_data_value_boolean_partial_idx ATTACH PARTITION public.txs_12_data_270000000_300000000_data_value_boolean_idx;


ALTER INDEX public.txs_12_data_value_integer_partial_idx ATTACH PARTITION public.txs_12_data_270000000_300000000_data_value_integer_idx;


ALTER INDEX public.txs_12_data_value_string_partial_idx ATTACH PARTITION public.txs_12_data_270000000_300000000_data_value_string_idx;


ALTER INDEX public.txs_12_data_height_idx ATTACH PARTITION public.txs_12_data_270000000_300000000_height_idx;


ALTER INDEX public.txs_12_data_pkey ATTACH PARTITION public.txs_12_data_270000000_300000000_pkey;


ALTER INDEX public.txs_12_data_tx_uid_idx ATTACH PARTITION public.txs_12_data_270000000_300000000_tx_uid_idx;


ALTER INDEX public.txs_12_data_data_key_idx ATTACH PARTITION public.txs_12_data_300000000_330000000_data_key_idx;


ALTER INDEX public.txs_12_data_data_type_idx ATTACH PARTITION public.txs_12_data_300000000_330000000_data_type_idx;


ALTER INDEX public.txs_12_data_value_binary_partial_idx ATTACH PARTITION public.txs_12_data_300000000_330000000_data_value_binary_idx;


ALTER INDEX public.txs_12_data_value_boolean_partial_idx ATTACH PARTITION public.txs_12_data_300000000_330000000_data_value_boolean_idx;


ALTER INDEX public.txs_12_data_value_integer_partial_idx ATTACH PARTITION public.txs_12_data_300000000_330000000_data_value_integer_idx;


ALTER INDEX public.txs_12_data_value_string_partial_idx ATTACH PARTITION public.txs_12_data_300000000_330000000_data_value_string_idx;


ALTER INDEX public.txs_12_data_height_idx ATTACH PARTITION public.txs_12_data_300000000_330000000_height_idx;


ALTER INDEX public.txs_12_data_pkey ATTACH PARTITION public.txs_12_data_300000000_330000000_pkey;


ALTER INDEX public.txs_12_data_tx_uid_idx ATTACH PARTITION public.txs_12_data_300000000_330000000_tx_uid_idx;


ALTER INDEX public.txs_12_data_data_key_idx ATTACH PARTITION public.txs_12_data_30000000_60000000_data_key_idx;


ALTER INDEX public.txs_12_data_data_type_idx ATTACH PARTITION public.txs_12_data_30000000_60000000_data_type_idx;


ALTER INDEX public.txs_12_data_value_binary_partial_idx ATTACH PARTITION public.txs_12_data_30000000_60000000_data_value_binary_idx;


ALTER INDEX public.txs_12_data_value_boolean_partial_idx ATTACH PARTITION public.txs_12_data_30000000_60000000_data_value_boolean_idx;


ALTER INDEX public.txs_12_data_value_integer_partial_idx ATTACH PARTITION public.txs_12_data_30000000_60000000_data_value_integer_idx;


ALTER INDEX public.txs_12_data_value_string_partial_idx ATTACH PARTITION public.txs_12_data_30000000_60000000_data_value_string_idx;


ALTER INDEX public.txs_12_data_height_idx ATTACH PARTITION public.txs_12_data_30000000_60000000_height_idx;


ALTER INDEX public.txs_12_data_pkey ATTACH PARTITION public.txs_12_data_30000000_60000000_pkey;


ALTER INDEX public.txs_12_data_tx_uid_idx ATTACH PARTITION public.txs_12_data_30000000_60000000_tx_uid_idx;


ALTER INDEX public.txs_12_data_data_key_idx ATTACH PARTITION public.txs_12_data_60000000_90000000_data_key_idx;


ALTER INDEX public.txs_12_data_data_type_idx ATTACH PARTITION public.txs_12_data_60000000_90000000_data_type_idx;


ALTER INDEX public.txs_12_data_value_binary_partial_idx ATTACH PARTITION public.txs_12_data_60000000_90000000_data_value_binary_idx;


ALTER INDEX public.txs_12_data_value_boolean_partial_idx ATTACH PARTITION public.txs_12_data_60000000_90000000_data_value_boolean_idx;


ALTER INDEX public.txs_12_data_value_integer_partial_idx ATTACH PARTITION public.txs_12_data_60000000_90000000_data_value_integer_idx;


ALTER INDEX public.txs_12_data_value_string_partial_idx ATTACH PARTITION public.txs_12_data_60000000_90000000_data_value_string_idx;


ALTER INDEX public.txs_12_data_height_idx ATTACH PARTITION public.txs_12_data_60000000_90000000_height_idx;


ALTER INDEX public.txs_12_data_pkey ATTACH PARTITION public.txs_12_data_60000000_90000000_pkey;


ALTER INDEX public.txs_12_data_tx_uid_idx ATTACH PARTITION public.txs_12_data_60000000_90000000_tx_uid_idx;


ALTER INDEX public.txs_12_data_data_key_idx ATTACH PARTITION public.txs_12_data_90000000_120000000_data_key_idx;


ALTER INDEX public.txs_12_data_data_type_idx ATTACH PARTITION public.txs_12_data_90000000_120000000_data_type_idx;


ALTER INDEX public.txs_12_data_value_binary_partial_idx ATTACH PARTITION public.txs_12_data_90000000_120000000_data_value_binary_idx;


ALTER INDEX public.txs_12_data_value_boolean_partial_idx ATTACH PARTITION public.txs_12_data_90000000_120000000_data_value_boolean_idx;


ALTER INDEX public.txs_12_data_value_integer_partial_idx ATTACH PARTITION public.txs_12_data_90000000_120000000_data_value_integer_idx;


ALTER INDEX public.txs_12_data_value_string_partial_idx ATTACH PARTITION public.txs_12_data_90000000_120000000_data_value_string_idx;


ALTER INDEX public.txs_12_data_height_idx ATTACH PARTITION public.txs_12_data_90000000_120000000_height_idx;


ALTER INDEX public.txs_12_data_pkey ATTACH PARTITION public.txs_12_data_90000000_120000000_pkey;


ALTER INDEX public.txs_12_data_tx_uid_idx ATTACH PARTITION public.txs_12_data_90000000_120000000_tx_uid_idx;


ALTER INDEX public.txs_12_data_data_key_idx ATTACH PARTITION public.txs_12_data_default_data_key_idx;


ALTER INDEX public.txs_12_data_data_type_idx ATTACH PARTITION public.txs_12_data_default_data_type_idx;


ALTER INDEX public.txs_12_data_value_binary_partial_idx ATTACH PARTITION public.txs_12_data_default_data_value_binary_idx;


ALTER INDEX public.txs_12_data_value_boolean_partial_idx ATTACH PARTITION public.txs_12_data_default_data_value_boolean_idx;


ALTER INDEX public.txs_12_data_value_integer_partial_idx ATTACH PARTITION public.txs_12_data_default_data_value_integer_idx;


ALTER INDEX public.txs_12_data_value_string_partial_idx ATTACH PARTITION public.txs_12_data_default_data_value_string_idx;


ALTER INDEX public.txs_12_data_height_idx ATTACH PARTITION public.txs_12_data_default_height_idx;


ALTER INDEX public.txs_12_data_pkey ATTACH PARTITION public.txs_12_data_default_pkey;


ALTER INDEX public.txs_12_data_tx_uid_idx ATTACH PARTITION public.txs_12_data_default_tx_uid_idx;


ALTER INDEX public.txs_12_height_idx ATTACH PARTITION public.txs_12_default_height_idx;


ALTER INDEX public.txs_12_sender_uid_idx ATTACH PARTITION public.txs_12_default_sender_uid_idx;


ALTER INDEX public.txs_12_tx_uid_key ATTACH PARTITION public.txs_12_default_tx_uid_key;


ALTER INDEX public.txs_13_height_idx ATTACH PARTITION public.txs_13_default_height_idx;


ALTER INDEX public.txs_13_md5_script_idx ATTACH PARTITION public.txs_13_default_md5_idx;


ALTER INDEX public.txs_13_sender_uid_idx ATTACH PARTITION public.txs_13_default_sender_uid_idx;


ALTER INDEX public.txs_13_tx_uid_key ATTACH PARTITION public.txs_13_default_tx_uid_key;


ALTER INDEX public.txs_14_height_idx ATTACH PARTITION public.txs_14_default_height_idx;


ALTER INDEX public.txs_14_sender_uid_idx ATTACH PARTITION public.txs_14_default_sender_uid_idx;


ALTER INDEX public.txs_14_tx_uid_key ATTACH PARTITION public.txs_14_default_tx_uid_key;


ALTER INDEX public.txs_15_height_idx ATTACH PARTITION public.txs_15_default_height_idx;


ALTER INDEX public.txs_15_md5_script_idx ATTACH PARTITION public.txs_15_default_md5_idx;


ALTER INDEX public.txs_15_sender_uid_idx ATTACH PARTITION public.txs_15_default_sender_uid_idx;


ALTER INDEX public.txs_15_tx_uid_key ATTACH PARTITION public.txs_15_default_tx_uid_key;


ALTER INDEX public.txs_16_dapp_address_uid_idx ATTACH PARTITION public.txs_16_0_30000000_dapp_address_uid_idx;


ALTER INDEX public.txs_16_function_name_idx ATTACH PARTITION public.txs_16_0_30000000_function_name_idx;


ALTER INDEX public.txs_16_height_idx ATTACH PARTITION public.txs_16_0_30000000_height_idx;


ALTER INDEX public.txs_16_sender_uid_idx ATTACH PARTITION public.txs_16_0_30000000_sender_uid_idx;


ALTER INDEX public.txs_16_un ATTACH PARTITION public.txs_16_0_30000000_tx_uid_key;


ALTER INDEX public.txs_16_dapp_address_uid_idx ATTACH PARTITION public.txs_16_120000001_150000000_dapp_address_uid_idx;


ALTER INDEX public.txs_16_function_name_idx ATTACH PARTITION public.txs_16_120000001_150000000_function_name_idx;


ALTER INDEX public.txs_16_height_idx ATTACH PARTITION public.txs_16_120000001_150000000_height_idx;


ALTER INDEX public.txs_16_sender_uid_idx ATTACH PARTITION public.txs_16_120000001_150000000_sender_uid_idx;


ALTER INDEX public.txs_16_un ATTACH PARTITION public.txs_16_120000001_150000000_tx_uid_key;


ALTER INDEX public.txs_16_dapp_address_uid_idx ATTACH PARTITION public.txs_16_150000001_180000000_dapp_address_uid_idx;


ALTER INDEX public.txs_16_function_name_idx ATTACH PARTITION public.txs_16_150000001_180000000_function_name_idx;


ALTER INDEX public.txs_16_height_idx ATTACH PARTITION public.txs_16_150000001_180000000_height_idx;


ALTER INDEX public.txs_16_sender_uid_idx ATTACH PARTITION public.txs_16_150000001_180000000_sender_uid_idx;


ALTER INDEX public.txs_16_un ATTACH PARTITION public.txs_16_150000001_180000000_tx_uid_key;


ALTER INDEX public.txs_16_dapp_address_uid_idx ATTACH PARTITION public.txs_16_180000001_210000000_dapp_address_uid_idx;


ALTER INDEX public.txs_16_function_name_idx ATTACH PARTITION public.txs_16_180000001_210000000_function_name_idx;


ALTER INDEX public.txs_16_height_idx ATTACH PARTITION public.txs_16_180000001_210000000_height_idx;


ALTER INDEX public.txs_16_sender_uid_idx ATTACH PARTITION public.txs_16_180000001_210000000_sender_uid_idx;


ALTER INDEX public.txs_16_un ATTACH PARTITION public.txs_16_180000001_210000000_tx_uid_key;


ALTER INDEX public.txs_16_dapp_address_uid_idx ATTACH PARTITION public.txs_16_210000001_240000000_dapp_address_uid_idx;


ALTER INDEX public.txs_16_function_name_idx ATTACH PARTITION public.txs_16_210000001_240000000_function_name_idx;


ALTER INDEX public.txs_16_height_idx ATTACH PARTITION public.txs_16_210000001_240000000_height_idx;


ALTER INDEX public.txs_16_sender_uid_idx ATTACH PARTITION public.txs_16_210000001_240000000_sender_uid_idx;


ALTER INDEX public.txs_16_un ATTACH PARTITION public.txs_16_210000001_240000000_tx_uid_key;


ALTER INDEX public.txs_16_dapp_address_uid_idx ATTACH PARTITION public.txs_16_240000001_270000000_dapp_address_uid_idx;


ALTER INDEX public.txs_16_function_name_idx ATTACH PARTITION public.txs_16_240000001_270000000_function_name_idx;


ALTER INDEX public.txs_16_height_idx ATTACH PARTITION public.txs_16_240000001_270000000_height_idx;


ALTER INDEX public.txs_16_sender_uid_idx ATTACH PARTITION public.txs_16_240000001_270000000_sender_uid_idx;


ALTER INDEX public.txs_16_un ATTACH PARTITION public.txs_16_240000001_270000000_tx_uid_key;


ALTER INDEX public.txs_16_dapp_address_uid_idx ATTACH PARTITION public.txs_16_270000001_300000000_dapp_address_uid_idx;


ALTER INDEX public.txs_16_function_name_idx ATTACH PARTITION public.txs_16_270000001_300000000_function_name_idx;


ALTER INDEX public.txs_16_height_idx ATTACH PARTITION public.txs_16_270000001_300000000_height_idx;


ALTER INDEX public.txs_16_sender_uid_idx ATTACH PARTITION public.txs_16_270000001_300000000_sender_uid_idx;


ALTER INDEX public.txs_16_un ATTACH PARTITION public.txs_16_270000001_300000000_tx_uid_key;


ALTER INDEX public.txs_16_dapp_address_uid_idx ATTACH PARTITION public.txs_16_300000001_330000000_dapp_address_uid_idx;


ALTER INDEX public.txs_16_function_name_idx ATTACH PARTITION public.txs_16_300000001_330000000_function_name_idx;


ALTER INDEX public.txs_16_height_idx ATTACH PARTITION public.txs_16_300000001_330000000_height_idx;


ALTER INDEX public.txs_16_sender_uid_idx ATTACH PARTITION public.txs_16_300000001_330000000_sender_uid_idx;


ALTER INDEX public.txs_16_un ATTACH PARTITION public.txs_16_300000001_330000000_tx_uid_key;


ALTER INDEX public.txs_16_dapp_address_uid_idx ATTACH PARTITION public.txs_16_30000001_60000000_dapp_address_uid_idx;


ALTER INDEX public.txs_16_function_name_idx ATTACH PARTITION public.txs_16_30000001_60000000_function_name_idx;


ALTER INDEX public.txs_16_height_idx ATTACH PARTITION public.txs_16_30000001_60000000_height_idx;


ALTER INDEX public.txs_16_sender_uid_idx ATTACH PARTITION public.txs_16_30000001_60000000_sender_uid_idx;


ALTER INDEX public.txs_16_un ATTACH PARTITION public.txs_16_30000001_60000000_tx_uid_key;


ALTER INDEX public.txs_16_dapp_address_uid_idx ATTACH PARTITION public.txs_16_60000001_90000000_dapp_address_uid_idx;


ALTER INDEX public.txs_16_function_name_idx ATTACH PARTITION public.txs_16_60000001_90000000_function_name_idx;


ALTER INDEX public.txs_16_height_idx ATTACH PARTITION public.txs_16_60000001_90000000_height_idx;


ALTER INDEX public.txs_16_sender_uid_idx ATTACH PARTITION public.txs_16_60000001_90000000_sender_uid_idx;


ALTER INDEX public.txs_16_un ATTACH PARTITION public.txs_16_60000001_90000000_tx_uid_key;


ALTER INDEX public.txs_16_dapp_address_uid_idx ATTACH PARTITION public.txs_16_90000001_120000000_dapp_address_uid_idx;


ALTER INDEX public.txs_16_function_name_idx ATTACH PARTITION public.txs_16_90000001_120000000_function_name_idx;


ALTER INDEX public.txs_16_height_idx ATTACH PARTITION public.txs_16_90000001_120000000_height_idx;


ALTER INDEX public.txs_16_sender_uid_idx ATTACH PARTITION public.txs_16_90000001_120000000_sender_uid_idx;


ALTER INDEX public.txs_16_un ATTACH PARTITION public.txs_16_90000001_120000000_tx_uid_key;


ALTER INDEX public.txs_16_args_height_idx ATTACH PARTITION public.txs_16_args_0_30000000_height_idx;


ALTER INDEX public.txs_16_args_pk ATTACH PARTITION public.txs_16_args_0_30000000_pkey;


ALTER INDEX public.txs_16_args_height_idx ATTACH PARTITION public.txs_16_args_120000000_150000000_height_idx;


ALTER INDEX public.txs_16_args_pk ATTACH PARTITION public.txs_16_args_120000000_150000000_pkey;


ALTER INDEX public.txs_16_args_height_idx ATTACH PARTITION public.txs_16_args_150000000_180000000_height_idx;


ALTER INDEX public.txs_16_args_pk ATTACH PARTITION public.txs_16_args_150000000_180000000_pkey;


ALTER INDEX public.txs_16_args_height_idx ATTACH PARTITION public.txs_16_args_180000000_210000000_height_idx;


ALTER INDEX public.txs_16_args_pk ATTACH PARTITION public.txs_16_args_180000000_210000000_pkey;


ALTER INDEX public.txs_16_args_height_idx ATTACH PARTITION public.txs_16_args_210000000_240000000_height_idx;


ALTER INDEX public.txs_16_args_pk ATTACH PARTITION public.txs_16_args_210000000_240000000_pkey;


ALTER INDEX public.txs_16_args_height_idx ATTACH PARTITION public.txs_16_args_240000000_270000000_height_idx;


ALTER INDEX public.txs_16_args_pk ATTACH PARTITION public.txs_16_args_240000000_270000000_pkey;


ALTER INDEX public.txs_16_args_height_idx ATTACH PARTITION public.txs_16_args_270000000_300000000_height_idx;


ALTER INDEX public.txs_16_args_pk ATTACH PARTITION public.txs_16_args_270000000_300000000_pkey;


ALTER INDEX public.txs_16_args_height_idx ATTACH PARTITION public.txs_16_args_300000000_330000000_height_idx;


ALTER INDEX public.txs_16_args_pk ATTACH PARTITION public.txs_16_args_300000000_330000000_pkey;


ALTER INDEX public.txs_16_args_height_idx ATTACH PARTITION public.txs_16_args_30000000_60000000_height_idx;


ALTER INDEX public.txs_16_args_pk ATTACH PARTITION public.txs_16_args_30000000_60000000_pkey;


ALTER INDEX public.txs_16_args_height_idx ATTACH PARTITION public.txs_16_args_60000000_90000000_height_idx;


ALTER INDEX public.txs_16_args_pk ATTACH PARTITION public.txs_16_args_60000000_90000000_pkey;


ALTER INDEX public.txs_16_args_height_idx ATTACH PARTITION public.txs_16_args_90000000_120000000_height_idx;


ALTER INDEX public.txs_16_args_pk ATTACH PARTITION public.txs_16_args_90000000_120000000_pkey;


ALTER INDEX public.txs_16_args_height_idx ATTACH PARTITION public.txs_16_args_default_height_idx;


ALTER INDEX public.txs_16_args_pk ATTACH PARTITION public.txs_16_args_default_pkey;


ALTER INDEX public.txs_16_dapp_address_uid_idx ATTACH PARTITION public.txs_16_default_dapp_address_uid_idx;


ALTER INDEX public.txs_16_function_name_idx ATTACH PARTITION public.txs_16_default_function_name_idx;


ALTER INDEX public.txs_16_height_idx ATTACH PARTITION public.txs_16_default_height_idx;


ALTER INDEX public.txs_16_sender_uid_idx ATTACH PARTITION public.txs_16_default_sender_uid_idx;


ALTER INDEX public.txs_16_un ATTACH PARTITION public.txs_16_default_tx_uid_key;


ALTER INDEX public.txs_16_payment_asset_uid_idx ATTACH PARTITION public.txs_16_payment_0_30000000_asset_uid_idx;


ALTER INDEX public.txs_16_payment_height_idx ATTACH PARTITION public.txs_16_payment_0_30000000_height_idx;


ALTER INDEX public.txs_16_payment_pk ATTACH PARTITION public.txs_16_payment_0_30000000_pkey;


ALTER INDEX public.txs_16_payment_asset_uid_idx ATTACH PARTITION public.txs_16_payment_120000000_150000000_asset_uid_idx;


ALTER INDEX public.txs_16_payment_height_idx ATTACH PARTITION public.txs_16_payment_120000000_150000000_height_idx;


ALTER INDEX public.txs_16_payment_pk ATTACH PARTITION public.txs_16_payment_120000000_150000000_pkey;


ALTER INDEX public.txs_16_payment_asset_uid_idx ATTACH PARTITION public.txs_16_payment_150000000_180000000_asset_uid_idx;


ALTER INDEX public.txs_16_payment_height_idx ATTACH PARTITION public.txs_16_payment_150000000_180000000_height_idx;


ALTER INDEX public.txs_16_payment_pk ATTACH PARTITION public.txs_16_payment_150000000_180000000_pkey;


ALTER INDEX public.txs_16_payment_asset_uid_idx ATTACH PARTITION public.txs_16_payment_180000000_210000000_asset_uid_idx;


ALTER INDEX public.txs_16_payment_height_idx ATTACH PARTITION public.txs_16_payment_180000000_210000000_height_idx;


ALTER INDEX public.txs_16_payment_pk ATTACH PARTITION public.txs_16_payment_180000000_210000000_pkey;


ALTER INDEX public.txs_16_payment_asset_uid_idx ATTACH PARTITION public.txs_16_payment_210000000_240000000_asset_uid_idx;


ALTER INDEX public.txs_16_payment_height_idx ATTACH PARTITION public.txs_16_payment_210000000_240000000_height_idx;


ALTER INDEX public.txs_16_payment_pk ATTACH PARTITION public.txs_16_payment_210000000_240000000_pkey;


ALTER INDEX public.txs_16_payment_asset_uid_idx ATTACH PARTITION public.txs_16_payment_240000000_270000000_asset_uid_idx;


ALTER INDEX public.txs_16_payment_height_idx ATTACH PARTITION public.txs_16_payment_240000000_270000000_height_idx;


ALTER INDEX public.txs_16_payment_pk ATTACH PARTITION public.txs_16_payment_240000000_270000000_pkey;


ALTER INDEX public.txs_16_payment_asset_uid_idx ATTACH PARTITION public.txs_16_payment_270000000_300000000_asset_uid_idx;


ALTER INDEX public.txs_16_payment_height_idx ATTACH PARTITION public.txs_16_payment_270000000_300000000_height_idx;


ALTER INDEX public.txs_16_payment_pk ATTACH PARTITION public.txs_16_payment_270000000_300000000_pkey;


ALTER INDEX public.txs_16_payment_asset_uid_idx ATTACH PARTITION public.txs_16_payment_300000000_330000000_asset_uid_idx;


ALTER INDEX public.txs_16_payment_height_idx ATTACH PARTITION public.txs_16_payment_300000000_330000000_height_idx;


ALTER INDEX public.txs_16_payment_pk ATTACH PARTITION public.txs_16_payment_300000000_330000000_pkey;


ALTER INDEX public.txs_16_payment_asset_uid_idx ATTACH PARTITION public.txs_16_payment_30000000_60000000_asset_uid_idx;


ALTER INDEX public.txs_16_payment_height_idx ATTACH PARTITION public.txs_16_payment_30000000_60000000_height_idx;


ALTER INDEX public.txs_16_payment_pk ATTACH PARTITION public.txs_16_payment_30000000_60000000_pkey;


ALTER INDEX public.txs_16_payment_asset_uid_idx ATTACH PARTITION public.txs_16_payment_60000000_90000000_asset_uid_idx;


ALTER INDEX public.txs_16_payment_height_idx ATTACH PARTITION public.txs_16_payment_60000000_90000000_height_idx;


ALTER INDEX public.txs_16_payment_pk ATTACH PARTITION public.txs_16_payment_60000000_90000000_pkey;


ALTER INDEX public.txs_16_payment_asset_uid_idx ATTACH PARTITION public.txs_16_payment_90000000_120000000_asset_uid_idx;


ALTER INDEX public.txs_16_payment_height_idx ATTACH PARTITION public.txs_16_payment_90000000_120000000_height_idx;


ALTER INDEX public.txs_16_payment_pk ATTACH PARTITION public.txs_16_payment_90000000_120000000_pkey;


ALTER INDEX public.txs_16_payment_asset_uid_idx ATTACH PARTITION public.txs_16_payment_default_asset_uid_idx;


ALTER INDEX public.txs_16_payment_height_idx ATTACH PARTITION public.txs_16_payment_default_height_idx;


ALTER INDEX public.txs_16_payment_pk ATTACH PARTITION public.txs_16_payment_default_pkey;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_1_2_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_1_2_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_1_2_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_1_2_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_1_2_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_1_2_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_1_2_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_1_2_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_1_2_uid_idx;


ALTER INDEX public.txs_1_height_idx ATTACH PARTITION public.txs_1_default_height_idx;


ALTER INDEX public.txs_1_sender_uid_idx ATTACH PARTITION public.txs_1_default_sender_uid_idx;


ALTER INDEX public.txs_1_tx_uid_key ATTACH PARTITION public.txs_1_default_tx_uid_key;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_2_3_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_2_3_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_2_3_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_2_3_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_2_3_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_2_3_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_2_3_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_2_3_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_2_3_uid_idx;


ALTER INDEX public.txs_2_height_idx ATTACH PARTITION public.txs_2_default_height_idx;


ALTER INDEX public.txs_2_sender_uid_idx ATTACH PARTITION public.txs_2_default_sender_uid_idx;


ALTER INDEX public.txs_2_tx_uid_key ATTACH PARTITION public.txs_2_default_tx_uid_key;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_3_4_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_3_4_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_3_4_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_3_4_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_3_4_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_3_4_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_3_4_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_3_4_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_3_4_uid_idx;


ALTER INDEX public.txs_3_asset_uid_idx ATTACH PARTITION public.txs_3_default_asset_uid_idx;


ALTER INDEX public.txs_3_height_idx ATTACH PARTITION public.txs_3_default_height_idx;


ALTER INDEX public.txs_3_md5_script_idx ATTACH PARTITION public.txs_3_default_md5_idx;


ALTER INDEX public.txs_3_sender_uid_idx ATTACH PARTITION public.txs_3_default_sender_uid_idx;


ALTER INDEX public.txs_3_tx_uid_key ATTACH PARTITION public.txs_3_default_tx_uid_key;


ALTER INDEX public.txs_4_asset_uid_idx ATTACH PARTITION public.txs_4_0_30000000_asset_uid_idx;


ALTER INDEX public.txs_4_height_idx ATTACH PARTITION public.txs_4_0_30000000_height_idx;


ALTER INDEX public.txs_4_recipient_address_uid_idx ATTACH PARTITION public.txs_4_0_30000000_recipient_address_uid_idx;


ALTER INDEX public.txs_4_sender_uid_idx ATTACH PARTITION public.txs_4_0_30000000_sender_uid_idx;


ALTER INDEX public.txs_4_tx_uid_key ATTACH PARTITION public.txs_4_0_30000000_tx_uid_key;


ALTER INDEX public.txs_4_asset_uid_idx ATTACH PARTITION public.txs_4_120000000_150000000_asset_uid_idx;


ALTER INDEX public.txs_4_height_idx ATTACH PARTITION public.txs_4_120000000_150000000_height_idx;


ALTER INDEX public.txs_4_recipient_address_uid_idx ATTACH PARTITION public.txs_4_120000000_150000000_recipient_address_uid_idx;


ALTER INDEX public.txs_4_sender_uid_idx ATTACH PARTITION public.txs_4_120000000_150000000_sender_uid_idx;


ALTER INDEX public.txs_4_tx_uid_key ATTACH PARTITION public.txs_4_120000000_150000000_tx_uid_key;


ALTER INDEX public.txs_4_asset_uid_idx ATTACH PARTITION public.txs_4_150000000_180000000_asset_uid_idx;


ALTER INDEX public.txs_4_height_idx ATTACH PARTITION public.txs_4_150000000_180000000_height_idx;


ALTER INDEX public.txs_4_recipient_address_uid_idx ATTACH PARTITION public.txs_4_150000000_180000000_recipient_address_uid_idx;


ALTER INDEX public.txs_4_sender_uid_idx ATTACH PARTITION public.txs_4_150000000_180000000_sender_uid_idx;


ALTER INDEX public.txs_4_tx_uid_key ATTACH PARTITION public.txs_4_150000000_180000000_tx_uid_key;


ALTER INDEX public.txs_4_asset_uid_idx ATTACH PARTITION public.txs_4_180000000_210000000_asset_uid_idx;


ALTER INDEX public.txs_4_height_idx ATTACH PARTITION public.txs_4_180000000_210000000_height_idx;


ALTER INDEX public.txs_4_recipient_address_uid_idx ATTACH PARTITION public.txs_4_180000000_210000000_recipient_address_uid_idx;


ALTER INDEX public.txs_4_sender_uid_idx ATTACH PARTITION public.txs_4_180000000_210000000_sender_uid_idx;


ALTER INDEX public.txs_4_tx_uid_key ATTACH PARTITION public.txs_4_180000000_210000000_tx_uid_key;


ALTER INDEX public.txs_4_asset_uid_idx ATTACH PARTITION public.txs_4_210000000_240000000_asset_uid_idx;


ALTER INDEX public.txs_4_height_idx ATTACH PARTITION public.txs_4_210000000_240000000_height_idx;


ALTER INDEX public.txs_4_recipient_address_uid_idx ATTACH PARTITION public.txs_4_210000000_240000000_recipient_address_uid_idx;


ALTER INDEX public.txs_4_sender_uid_idx ATTACH PARTITION public.txs_4_210000000_240000000_sender_uid_idx;


ALTER INDEX public.txs_4_tx_uid_key ATTACH PARTITION public.txs_4_210000000_240000000_tx_uid_key;


ALTER INDEX public.txs_4_asset_uid_idx ATTACH PARTITION public.txs_4_240000000_270000000_asset_uid_idx;


ALTER INDEX public.txs_4_height_idx ATTACH PARTITION public.txs_4_240000000_270000000_height_idx;


ALTER INDEX public.txs_4_recipient_address_uid_idx ATTACH PARTITION public.txs_4_240000000_270000000_recipient_address_uid_idx;


ALTER INDEX public.txs_4_sender_uid_idx ATTACH PARTITION public.txs_4_240000000_270000000_sender_uid_idx;


ALTER INDEX public.txs_4_tx_uid_key ATTACH PARTITION public.txs_4_240000000_270000000_tx_uid_key;


ALTER INDEX public.txs_4_asset_uid_idx ATTACH PARTITION public.txs_4_270000000_300000000_asset_uid_idx;


ALTER INDEX public.txs_4_height_idx ATTACH PARTITION public.txs_4_270000000_300000000_height_idx;


ALTER INDEX public.txs_4_recipient_address_uid_idx ATTACH PARTITION public.txs_4_270000000_300000000_recipient_address_uid_idx;


ALTER INDEX public.txs_4_sender_uid_idx ATTACH PARTITION public.txs_4_270000000_300000000_sender_uid_idx;


ALTER INDEX public.txs_4_tx_uid_key ATTACH PARTITION public.txs_4_270000000_300000000_tx_uid_key;


ALTER INDEX public.txs_4_asset_uid_idx ATTACH PARTITION public.txs_4_300000000_330000000_asset_uid_idx;


ALTER INDEX public.txs_4_height_idx ATTACH PARTITION public.txs_4_300000000_330000000_height_idx;


ALTER INDEX public.txs_4_recipient_address_uid_idx ATTACH PARTITION public.txs_4_300000000_330000000_recipient_address_uid_idx;


ALTER INDEX public.txs_4_sender_uid_idx ATTACH PARTITION public.txs_4_300000000_330000000_sender_uid_idx;


ALTER INDEX public.txs_4_tx_uid_key ATTACH PARTITION public.txs_4_300000000_330000000_tx_uid_key;


ALTER INDEX public.txs_4_asset_uid_idx ATTACH PARTITION public.txs_4_30000000_60000000_asset_uid_idx;


ALTER INDEX public.txs_4_height_idx ATTACH PARTITION public.txs_4_30000000_60000000_height_idx;


ALTER INDEX public.txs_4_recipient_address_uid_idx ATTACH PARTITION public.txs_4_30000000_60000000_recipient_address_uid_idx;


ALTER INDEX public.txs_4_sender_uid_idx ATTACH PARTITION public.txs_4_30000000_60000000_sender_uid_idx;


ALTER INDEX public.txs_4_tx_uid_key ATTACH PARTITION public.txs_4_30000000_60000000_tx_uid_key;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_4_5_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_4_5_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_4_5_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_4_5_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_4_5_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_4_5_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_4_5_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_4_5_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_4_5_uid_idx;


ALTER INDEX public.txs_4_asset_uid_idx ATTACH PARTITION public.txs_4_60000000_90000000_asset_uid_idx;


ALTER INDEX public.txs_4_height_idx ATTACH PARTITION public.txs_4_60000000_90000000_height_idx;


ALTER INDEX public.txs_4_recipient_address_uid_idx ATTACH PARTITION public.txs_4_60000000_90000000_recipient_address_uid_idx;


ALTER INDEX public.txs_4_sender_uid_idx ATTACH PARTITION public.txs_4_60000000_90000000_sender_uid_idx;


ALTER INDEX public.txs_4_tx_uid_key ATTACH PARTITION public.txs_4_60000000_90000000_tx_uid_key;


ALTER INDEX public.txs_4_asset_uid_idx ATTACH PARTITION public.txs_4_90000000_120000000_asset_uid_idx;


ALTER INDEX public.txs_4_height_idx ATTACH PARTITION public.txs_4_90000000_120000000_height_idx;


ALTER INDEX public.txs_4_recipient_address_uid_idx ATTACH PARTITION public.txs_4_90000000_120000000_recipient_address_uid_idx;


ALTER INDEX public.txs_4_sender_uid_idx ATTACH PARTITION public.txs_4_90000000_120000000_sender_uid_idx;


ALTER INDEX public.txs_4_tx_uid_key ATTACH PARTITION public.txs_4_90000000_120000000_tx_uid_key;


ALTER INDEX public.txs_4_asset_uid_idx ATTACH PARTITION public.txs_4_default_asset_uid_idx;


ALTER INDEX public.txs_4_height_idx ATTACH PARTITION public.txs_4_default_height_idx;


ALTER INDEX public.txs_4_recipient_address_uid_idx ATTACH PARTITION public.txs_4_default_recipient_address_uid_idx;


ALTER INDEX public.txs_4_sender_uid_idx ATTACH PARTITION public.txs_4_default_sender_uid_idx;


ALTER INDEX public.txs_4_tx_uid_key ATTACH PARTITION public.txs_4_default_tx_uid_key;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_5_6_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_5_6_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_5_6_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_5_6_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_5_6_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_5_6_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_5_6_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_5_6_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_5_6_uid_idx;


ALTER INDEX public.txs_5_asset_uid_idx ATTACH PARTITION public.txs_5_default_asset_uid_idx;


ALTER INDEX public.txs_5_height_idx ATTACH PARTITION public.txs_5_default_height_idx;


ALTER INDEX public.txs_5_sender_uid_idx ATTACH PARTITION public.txs_5_default_sender_uid_idx;


ALTER INDEX public.txs_5_tx_uid_key ATTACH PARTITION public.txs_5_default_tx_uid_key;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_6_7_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_6_7_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_6_7_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_6_7_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_6_7_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_6_7_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_6_7_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_6_7_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_6_7_uid_idx;


ALTER INDEX public.txs_6_asset_uid_idx ATTACH PARTITION public.txs_6_default_asset_uid_idx;


ALTER INDEX public.txs_6_height_idx ATTACH PARTITION public.txs_6_default_height_idx;


ALTER INDEX public.txs_6_sender_uid_idx ATTACH PARTITION public.txs_6_default_sender_uid_idx;


ALTER INDEX public.txs_6_tx_uid_key ATTACH PARTITION public.txs_6_default_tx_uid_key;


ALTER INDEX public.txs_7_height_idx ATTACH PARTITION public.txs_7_0_30000000_height_idx;


ALTER INDEX public.txs_7_sender_uid_idx ATTACH PARTITION public.txs_7_0_30000000_sender_uid_idx;


ALTER INDEX public.txs_7_tx_uid_key ATTACH PARTITION public.txs_7_0_30000000_tx_uid_key;


ALTER INDEX public.txs_7_height_idx ATTACH PARTITION public.txs_7_120000000_150000000_height_idx;


ALTER INDEX public.txs_7_sender_uid_idx ATTACH PARTITION public.txs_7_120000000_150000000_sender_uid_idx;


ALTER INDEX public.txs_7_tx_uid_key ATTACH PARTITION public.txs_7_120000000_150000000_tx_uid_key;


ALTER INDEX public.txs_7_height_idx ATTACH PARTITION public.txs_7_150000000_180000000_height_idx;


ALTER INDEX public.txs_7_sender_uid_idx ATTACH PARTITION public.txs_7_150000000_180000000_sender_uid_idx;


ALTER INDEX public.txs_7_tx_uid_key ATTACH PARTITION public.txs_7_150000000_180000000_tx_uid_key;


ALTER INDEX public.txs_7_height_idx ATTACH PARTITION public.txs_7_180000000_210000000_height_idx;


ALTER INDEX public.txs_7_sender_uid_idx ATTACH PARTITION public.txs_7_180000000_210000000_sender_uid_idx;


ALTER INDEX public.txs_7_tx_uid_key ATTACH PARTITION public.txs_7_180000000_210000000_tx_uid_key;


ALTER INDEX public.txs_7_height_idx ATTACH PARTITION public.txs_7_210000000_240000000_height_idx;


ALTER INDEX public.txs_7_sender_uid_idx ATTACH PARTITION public.txs_7_210000000_240000000_sender_uid_idx;


ALTER INDEX public.txs_7_tx_uid_key ATTACH PARTITION public.txs_7_210000000_240000000_tx_uid_key;


ALTER INDEX public.txs_7_height_idx ATTACH PARTITION public.txs_7_240000000_270000000_height_idx;


ALTER INDEX public.txs_7_sender_uid_idx ATTACH PARTITION public.txs_7_240000000_270000000_sender_uid_idx;


ALTER INDEX public.txs_7_tx_uid_key ATTACH PARTITION public.txs_7_240000000_270000000_tx_uid_key;


ALTER INDEX public.txs_7_height_idx ATTACH PARTITION public.txs_7_270000000_300000000_height_idx;


ALTER INDEX public.txs_7_sender_uid_idx ATTACH PARTITION public.txs_7_270000000_300000000_sender_uid_idx;


ALTER INDEX public.txs_7_tx_uid_key ATTACH PARTITION public.txs_7_270000000_300000000_tx_uid_key;


ALTER INDEX public.txs_7_height_idx ATTACH PARTITION public.txs_7_300000000_330000000_height_idx;


ALTER INDEX public.txs_7_sender_uid_idx ATTACH PARTITION public.txs_7_300000000_330000000_sender_uid_idx;


ALTER INDEX public.txs_7_tx_uid_key ATTACH PARTITION public.txs_7_300000000_330000000_tx_uid_key;


ALTER INDEX public.txs_7_height_idx ATTACH PARTITION public.txs_7_30000000_60000000_height_idx;


ALTER INDEX public.txs_7_sender_uid_idx ATTACH PARTITION public.txs_7_30000000_60000000_sender_uid_idx;


ALTER INDEX public.txs_7_tx_uid_key ATTACH PARTITION public.txs_7_30000000_60000000_tx_uid_key;


ALTER INDEX public.txs_7_height_idx ATTACH PARTITION public.txs_7_60000000_90000000_height_idx;


ALTER INDEX public.txs_7_sender_uid_idx ATTACH PARTITION public.txs_7_60000000_90000000_sender_uid_idx;


ALTER INDEX public.txs_7_tx_uid_key ATTACH PARTITION public.txs_7_60000000_90000000_tx_uid_key;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_7_8_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_7_8_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_7_8_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_7_8_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_7_8_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_7_8_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_7_8_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_7_8_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_7_8_uid_idx;


ALTER INDEX public.txs_7_height_idx ATTACH PARTITION public.txs_7_90000000_120000000_height_idx;


ALTER INDEX public.txs_7_sender_uid_idx ATTACH PARTITION public.txs_7_90000000_120000000_sender_uid_idx;


ALTER INDEX public.txs_7_tx_uid_key ATTACH PARTITION public.txs_7_90000000_120000000_tx_uid_key;


ALTER INDEX public.txs_7_height_idx ATTACH PARTITION public.txs_7_default_height_idx;


ALTER INDEX public.txs_7_sender_uid_idx ATTACH PARTITION public.txs_7_default_sender_uid_idx;


ALTER INDEX public.txs_7_tx_uid_key ATTACH PARTITION public.txs_7_default_tx_uid_key;


ALTER INDEX public.txs_7_orders_amount_asset_uid_price_asset_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_0_30000000_amount_asset_uid_price_asset_uid_tx_idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_0_30000000_amount_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_height_idx ATTACH PARTITION public.txs_7_orders_0_30000000_height_idx;


ALTER INDEX public.txs_7_orders_order_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_0_30000000_order_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_order_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_0_30000000_order_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_pk ATTACH PARTITION public.txs_7_orders_0_30000000_pkey;


ALTER INDEX public.txs_7_orders_price_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_0_30000000_price_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_0_30000000_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_120000000_150000000_amount_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_height_idx ATTACH PARTITION public.txs_7_orders_120000000_150000000_height_idx;


ALTER INDEX public.txs_7_orders_order_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_120000000_150000000_order_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_order_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_120000000_150000000_order_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_pk ATTACH PARTITION public.txs_7_orders_120000000_150000000_pkey;


ALTER INDEX public.txs_7_orders_price_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_120000000_150000000_price_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_120000000_150000000_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_price_asset_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_120000000_150000_amount_asset_uid_price_asset__idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_150000000_180000000_amount_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_height_idx ATTACH PARTITION public.txs_7_orders_150000000_180000000_height_idx;


ALTER INDEX public.txs_7_orders_order_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_150000000_180000000_order_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_order_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_150000000_180000000_order_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_pk ATTACH PARTITION public.txs_7_orders_150000000_180000000_pkey;


ALTER INDEX public.txs_7_orders_price_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_150000000_180000000_price_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_150000000_180000000_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_price_asset_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_150000000_180000_amount_asset_uid_price_asset__idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_180000000_210000000_amount_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_height_idx ATTACH PARTITION public.txs_7_orders_180000000_210000000_height_idx;


ALTER INDEX public.txs_7_orders_order_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_180000000_210000000_order_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_order_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_180000000_210000000_order_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_pk ATTACH PARTITION public.txs_7_orders_180000000_210000000_pkey;


ALTER INDEX public.txs_7_orders_price_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_180000000_210000000_price_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_180000000_210000000_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_price_asset_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_180000000_210000_amount_asset_uid_price_asset__idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_210000000_240000000_amount_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_height_idx ATTACH PARTITION public.txs_7_orders_210000000_240000000_height_idx;


ALTER INDEX public.txs_7_orders_order_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_210000000_240000000_order_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_order_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_210000000_240000000_order_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_pk ATTACH PARTITION public.txs_7_orders_210000000_240000000_pkey;


ALTER INDEX public.txs_7_orders_price_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_210000000_240000000_price_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_210000000_240000000_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_price_asset_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_210000000_240000_amount_asset_uid_price_asset__idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_240000000_270000000_amount_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_height_idx ATTACH PARTITION public.txs_7_orders_240000000_270000000_height_idx;


ALTER INDEX public.txs_7_orders_order_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_240000000_270000000_order_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_order_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_240000000_270000000_order_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_pk ATTACH PARTITION public.txs_7_orders_240000000_270000000_pkey;


ALTER INDEX public.txs_7_orders_price_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_240000000_270000000_price_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_240000000_270000000_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_price_asset_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_240000000_270000_amount_asset_uid_price_asset__idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_270000000_300000000_amount_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_height_idx ATTACH PARTITION public.txs_7_orders_270000000_300000000_height_idx;


ALTER INDEX public.txs_7_orders_order_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_270000000_300000000_order_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_order_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_270000000_300000000_order_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_pk ATTACH PARTITION public.txs_7_orders_270000000_300000000_pkey;


ALTER INDEX public.txs_7_orders_price_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_270000000_300000000_price_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_270000000_300000000_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_price_asset_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_270000000_300000_amount_asset_uid_price_asset__idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_300000000_330000000_amount_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_height_idx ATTACH PARTITION public.txs_7_orders_300000000_330000000_height_idx;


ALTER INDEX public.txs_7_orders_order_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_300000000_330000000_order_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_order_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_300000000_330000000_order_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_pk ATTACH PARTITION public.txs_7_orders_300000000_330000000_pkey;


ALTER INDEX public.txs_7_orders_price_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_300000000_330000000_price_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_300000000_330000000_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_price_asset_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_300000000_330000_amount_asset_uid_price_asset__idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_30000000_60000000_amount_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_height_idx ATTACH PARTITION public.txs_7_orders_30000000_60000000_height_idx;


ALTER INDEX public.txs_7_orders_order_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_30000000_60000000_order_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_order_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_30000000_60000000_order_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_pk ATTACH PARTITION public.txs_7_orders_30000000_60000000_pkey;


ALTER INDEX public.txs_7_orders_price_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_30000000_60000000_price_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_30000000_60000000_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_price_asset_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_30000000_6000000_amount_asset_uid_price_asset__idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_60000000_90000000_amount_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_height_idx ATTACH PARTITION public.txs_7_orders_60000000_90000000_height_idx;


ALTER INDEX public.txs_7_orders_order_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_60000000_90000000_order_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_order_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_60000000_90000000_order_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_pk ATTACH PARTITION public.txs_7_orders_60000000_90000000_pkey;


ALTER INDEX public.txs_7_orders_price_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_60000000_90000000_price_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_60000000_90000000_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_price_asset_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_60000000_9000000_amount_asset_uid_price_asset__idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_90000000_120000000_amount_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_height_idx ATTACH PARTITION public.txs_7_orders_90000000_120000000_height_idx;


ALTER INDEX public.txs_7_orders_order_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_90000000_120000000_order_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_order_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_90000000_120000000_order_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_pk ATTACH PARTITION public.txs_7_orders_90000000_120000000_pkey;


ALTER INDEX public.txs_7_orders_price_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_90000000_120000000_price_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_90000000_120000000_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_price_asset_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_90000000_1200000_amount_asset_uid_price_asset__idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_price_asset_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_default_amount_asset_uid_price_asset_uid_tx_ui_idx;


ALTER INDEX public.txs_7_orders_amount_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_default_amount_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_height_idx ATTACH PARTITION public.txs_7_orders_default_height_idx;


ALTER INDEX public.txs_7_orders_order_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_default_order_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_order_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_default_order_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_pk ATTACH PARTITION public.txs_7_orders_default_pkey;


ALTER INDEX public.txs_7_orders_price_asset_uid_tx_uid_idx ATTACH PARTITION public.txs_7_orders_default_price_asset_uid_tx_uid_idx;


ALTER INDEX public.txs_7_orders_sender_uid_tuid_idx ATTACH PARTITION public.txs_7_orders_default_sender_uid_tx_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_8_9_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_8_9_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_8_9_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_8_9_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_8_9_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_8_9_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_8_9_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_8_9_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_8_9_uid_idx;


ALTER INDEX public.txs_8_height_idx ATTACH PARTITION public.txs_8_default_height_idx;


ALTER INDEX public.txs_8_recipient_idx ATTACH PARTITION public.txs_8_default_recipient_address_uid_idx;


ALTER INDEX public.txs_8_recipient_address_uid_tx_uid_idx ATTACH PARTITION public.txs_8_default_recipient_address_uid_tx_uid_idx;


ALTER INDEX public.txs_8_sender_uid_idx ATTACH PARTITION public.txs_8_default_sender_uid_idx;


ALTER INDEX public.txs_8_tx_uid_key ATTACH PARTITION public.txs_8_default_tx_uid_key;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_9_a_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_9_a_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_9_a_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_9_a_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_9_a_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_9_a_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_9_a_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_9_a_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_9_a_uid_idx;


ALTER INDEX public.txs_9_height_idx ATTACH PARTITION public.txs_9_default_height_idx;


ALTER INDEX public.txs_9_sender_idx ATTACH PARTITION public.txs_9_default_sender_uid_idx;


ALTER INDEX public.txs_9_tx_uid_key ATTACH PARTITION public.txs_9_default_tx_uid_key;


ALTER INDEX public.txs_9_un ATTACH PARTITION public.txs_9_default_tx_uid_lease_tx_uid_key;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_a_b_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_a_b_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_a_b_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_a_b_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_a_b_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_a_b_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_a_b_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_a_b_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_a_b_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_b_c_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_b_c_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_b_c_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_b_c_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_b_c_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_b_c_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_b_c_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_b_c_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_b_c_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_c_d_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_c_d_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_c_d_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_c_d_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_c_d_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_c_d_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_c_d_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_c_d_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_c_d_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_d_e_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_d_e_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_d_e_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_d_e_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_d_e_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_d_e_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_d_e_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_d_e_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_d_e_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_e_f_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_e_f_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_e_f_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_e_f_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_e_f_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_e_f_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_e_f_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_e_f_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_e_f_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_f_g_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_f_g_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_f_g_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_f_g_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_f_g_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_f_g_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_f_g_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_f_g_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_f_g_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_g_h_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_g_h_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_g_h_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_g_h_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_g_h_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_g_h_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_g_h_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_g_h_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_g_h_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_h_i_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_h_i_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_h_i_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_h_i_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_h_i_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_h_i_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_h_i_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_h_i_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_h_i_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_i_j_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_i_j_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_i_j_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_i_j_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_i_j_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_i_j_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_i_j_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_i_j_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_i_j_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_j_k_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_j_k_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_j_k_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_j_k_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_j_k_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_j_k_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_j_k_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_j_k_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_j_k_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_k_l_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_k_l_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_k_l_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_k_l_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_k_l_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_k_l_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_k_l_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_k_l_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_k_l_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_l_m_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_l_m_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_l_m_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_l_m_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_l_m_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_l_m_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_l_m_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_l_m_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_l_m_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_m_n_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_m_n_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_m_n_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_m_n_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_m_n_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_m_n_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_m_n_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_m_n_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_m_n_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_n_o_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_n_o_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_n_o_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_n_o_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_n_o_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_n_o_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_n_o_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_n_o_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_n_o_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_o_p_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_o_p_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_o_p_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_o_p_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_o_p_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_o_p_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_o_p_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_o_p_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_o_p_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_p_q_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_p_q_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_p_q_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_p_q_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_p_q_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_p_q_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_p_q_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_p_q_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_p_q_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_q_r_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_q_r_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_q_r_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_q_r_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_q_r_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_q_r_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_q_r_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_q_r_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_q_r_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_r_s_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_r_s_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_r_s_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_r_s_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_r_s_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_r_s_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_r_s_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_r_s_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_r_s_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_s_t_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_s_t_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_s_t_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_s_t_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_s_t_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_s_t_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_s_t_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_s_t_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_s_t_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_t_u_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_t_u_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_t_u_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_t_u_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_t_u_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_t_u_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_t_u_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_t_u_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_t_u_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_u_v_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_u_v_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_u_v_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_u_v_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_u_v_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_u_v_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_u_v_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_u_v_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_u_v_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_v_w_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_v_w_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_v_w_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_v_w_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_v_w_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_v_w_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_v_w_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_v_w_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_v_w_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_w_x_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_w_x_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_w_x_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_w_x_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_w_x_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_w_x_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_w_x_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_w_x_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_w_x_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_x_y_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_x_y_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_x_y_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_x_y_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_x_y_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_x_y_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_x_y_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_x_y_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_x_y_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_y_z_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_y_z_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_y_z_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_y_z_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_y_z_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_y_z_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_y_z_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_y_z_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_y_z_uid_idx;


ALTER INDEX public.txs_height_idx ATTACH PARTITION public.txs_z_height_idx;


ALTER INDEX public.txs_id_uid_idx ATTACH PARTITION public.txs_z_id_uid_idx;


ALTER INDEX public.txs_pk ATTACH PARTITION public.txs_z_pkey;


ALTER INDEX public.txs_sender_uid_idx ATTACH PARTITION public.txs_z_sender_uid_idx;


ALTER INDEX public.txs_sender_uid_uid_idx ATTACH PARTITION public.txs_z_sender_uid_uid_idx;


ALTER INDEX public.txs_time_stamp_idx ATTACH PARTITION public.txs_z_time_stamp_idx;


ALTER INDEX public.txs_time_stamp_uid_idx ATTACH PARTITION public.txs_z_time_stamp_uid_idx;


ALTER INDEX public.txs_tx_type_idx ATTACH PARTITION public.txs_z_tx_type_idx;


ALTER INDEX public.txs_uid_idx ATTACH PARTITION public.txs_z_uid_idx;


CREATE RULE block_delete AS
    ON DELETE TO public.blocks_raw DO  DELETE FROM public.blocks
  WHERE (blocks.height = old.height);


CREATE TRIGGER block_insert_trigger BEFORE INSERT ON public.blocks_raw FOR EACH ROW EXECUTE PROCEDURE public.on_block_insert();


CREATE TRIGGER block_update_trigger BEFORE UPDATE ON public.blocks_raw FOR EACH ROW EXECUTE PROCEDURE public.on_block_update();


ALTER TABLE public.addresses
    ADD CONSTRAINT fk_blocks FOREIGN KEY (first_appeared_on_height) REFERENCES public.blocks(height) ON DELETE CASCADE;


ALTER TABLE ONLY public.assets
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
