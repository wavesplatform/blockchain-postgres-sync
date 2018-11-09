--
-- PostgreSQL database dump
--

-- Dumped from database version 10.5 (Ubuntu 10.5-2.pgdg16.04+1)
-- Dumped by pg_dump version 10.5 (Ubuntu 10.5-1.pgdg16.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: btree_gin; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS btree_gin WITH SCHEMA public;


--
-- Name: EXTENSION btree_gin; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION btree_gin IS 'support for indexing common datatypes in GIN';


--
-- Name: delete_order_if_orphan(character varying); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.delete_order_if_orphan(order_id character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
  DELETE FROM orders
  WHERE id = order_id;
  RETURN TRUE;
EXCEPTION
  WHEN foreign_key_violation THEN
  RETURN FALSE;
END;
$$;


ALTER FUNCTION public.delete_order_if_orphan(order_id character varying) OWNER TO dba;

--
-- Name: delete_orders_after_tx(); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.delete_orders_after_tx() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM
    delete_order_if_orphan (old.order1);
  PERFORM
    delete_order_if_orphan (old.order2);
  RETURN NULL;
END
$$;


ALTER FUNCTION public.delete_orders_after_tx() OWNER TO dba;

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
-- Name: get_asset_id(text); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.get_asset_id(text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT COALESCE($1, 'WAVES');
$_$;


ALTER FUNCTION public.get_asset_id(text) OWNER TO dba;

--
-- Name: insert_all(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_all(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	PERFORM insert_block (b);
	PERFORM insert_orders (b);
	PERFORM insert_txs_1 (b);
	PERFORM insert_txs_2 (b);
	PERFORM insert_txs_3 (b);
	PERFORM insert_txs_4 (b);
	PERFORM insert_txs_5 (b);
	PERFORM insert_txs_6 (b);
	PERFORM insert_txs_7 (b);
	PERFORM insert_txs_7_v2 (b);
	PERFORM insert_txs_8 (b);
	PERFORM insert_txs_9 (b);
	PERFORM insert_txs_10 (b);
	PERFORM insert_txs_11 (b);
	PERFORM insert_txs_12 (b);
  PERFORM insert_txs_13 (b);
	PERFORM insert_txs_14 (b);
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
END
$$;


ALTER FUNCTION public.insert_block(b jsonb) OWNER TO dba;

--
-- Name: insert_orders(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_orders(b jsonb) RETURNS void
    LANGUAGE plpgsql
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
		to_timestamp((o ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		to_timestamp((o ->> 'expiration') :: DOUBLE PRECISION / 1000),
		(o->>'matcherFee')::bigint,
		o->>'signature',
    o->>'sender'
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
$$;


ALTER FUNCTION public.insert_orders(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_1(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_1(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_1 (
		height,
		tx_type,
		id,
		time_stamp,
		signature,
		proofs,
		tx_version,
		fee,
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
		-- type specific
		t->>'recipient',
		(t->>'amount')::bigint
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '1'
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
		alias
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
		t->>'alias'
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
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
  INSERT INTO txs_11 (
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
    attachment
  )
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

  INSERT INTO txs_11_transfers (
    tx_id,
    recipient,
    amount,
    position_in_tx
  )
    SELECT
      t ->> 'tx_id',
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


ALTER FUNCTION public.insert_txs_11(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_12(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_12(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
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


ALTER FUNCTION public.insert_txs_12(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_13(jsonb); Type: FUNCTION; Schema: public; Owner: dvshur
--

CREATE FUNCTION public.insert_txs_13(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
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


ALTER FUNCTION public.insert_txs_13(b jsonb) OWNER TO dvshur;

--
-- Name: insert_txs_14(jsonb); Type: FUNCTION; Schema: public; Owner: dvshur
--

CREATE FUNCTION public.insert_txs_14(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
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


ALTER FUNCTION public.insert_txs_14(b jsonb) OWNER TO dvshur;

--
-- Name: insert_txs_2(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_2(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
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


ALTER FUNCTION public.insert_txs_2(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_3(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_3(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
		sender,
		sender_public_key,
		asset_id,
		asset_name,
		description,
		quantity,
		decimals,
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
		-- with sender
		t->>'sender',
		t->>'senderPublicKey',
		-- type specific
		get_asset_id(t->>'assetId'),
		t->>'name',
		t->>'description',
		(t->>'quantity')::bigint,
		(t->>'decimals')::smallint,
		(t->>'reissuable')::bool
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
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
	insert into txs_4
	(height, tx_type, id, time_stamp, fee, amount, asset_id, fee_asset, sender, sender_public_key, recipient, attachment, signature, proofs, tx_version)
	select
		(t->>'height')::int4,
		(t->>'type')::smallint,
		t->>'id',
		to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
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
		to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
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


ALTER FUNCTION public.insert_txs_6(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_7(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_7(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
		sell_matcher_fee,
    order1_sender,
    order2_sender
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
		(t->>'sellMatcherFee')::bigint,
    t->'order1'->>'sender',
    t->'order2'->>'sender'
	from (
		select jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') as t
	) as txs
	where (t->>'type') = '7'
	on conflict do nothing;
END
$$;


ALTER FUNCTION public.insert_txs_7(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_7_v2(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_7_v2(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into txs_7_v2 (
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
		to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		t->>'signature',
		jsonb_array_cast_text(t->'proofs'),
		(t->>'version')::smallint,
		(t->>'fee')::bigint,
		-- with sender
		t->>'sender',
		t->>'senderPublicKey',
		-- type specific
		t->'order1',
		t->'order2',
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
$$;


ALTER FUNCTION public.insert_txs_7_v2(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_8(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_8(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
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


ALTER FUNCTION public.insert_txs_8(b jsonb) OWNER TO dba;

--
-- Name: insert_txs_9(jsonb); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.insert_txs_9(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
--  	insert into call_log values('block_insert', new.height, new.b->>'signature', now());
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
-- Name: update_materialized_views(); Type: FUNCTION; Schema: public; Owner: dba
--

CREATE FUNCTION public.update_materialized_views() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	refresh materialized view blockchain_events_m;
	refresh materialized view first_time_events_m;
	refresh materialized view first_money_receive;
	refresh materialized view daily_active_addresses_m;
END 
$$;


ALTER FUNCTION public.update_materialized_views() OWNER TO dba;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: txs; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs (
    height integer NOT NULL,
    tx_type smallint NOT NULL,
    id character varying NOT NULL,
    time_stamp timestamp without time zone NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint
);


ALTER TABLE public.txs OWNER TO dba;

--
-- Name: txs_11_transfers; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_11_transfers (
    tx_id character varying NOT NULL,
    recipient character varying NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL
);


ALTER TABLE public.txs_11_transfers OWNER TO dba;

--
-- Name: txs_4; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_4 (
    fee bigint NOT NULL,
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    asset_id character varying NOT NULL,
    amount bigint NOT NULL,
    recipient character varying NOT NULL,
    fee_asset character varying NOT NULL,
    attachment character varying NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_4 OWNER TO dba;

--
-- Name: all_recipients; Type: MATERIALIZED VIEW; Schema: public; Owner: dvshur
--

CREATE MATERIALIZED VIEW public.all_recipients AS
 SELECT DISTINCT txs_4.recipient
   FROM public.txs_4
UNION
 SELECT DISTINCT txs_11_transfers.recipient
   FROM public.txs_11_transfers
  WITH NO DATA;


ALTER TABLE public.all_recipients OWNER TO dvshur;

--
-- Name: txs_11; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_11 (
    fee bigint NOT NULL,
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    asset_id character varying NOT NULL,
    attachment character varying NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_11 OWNER TO dba;

--
-- Name: all_recipients_time; Type: MATERIALIZED VIEW; Schema: public; Owner: ttsiguleva
--

CREATE MATERIALIZED VIEW public.all_recipients_time AS
 SELECT DISTINCT txs_4.recipient,
    txs_4.time_stamp
   FROM public.txs_4
UNION
 SELECT DISTINCT txs_11_transfers.recipient,
    txs_11.time_stamp
   FROM (public.txs_11_transfers
     JOIN public.txs_11 ON (((txs_11_transfers.tx_id)::text = (txs_11.id)::text)))
  WITH NO DATA;


ALTER TABLE public.all_recipients_time OWNER TO ttsiguleva;

--
-- Name: txs_3; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_3 (
    fee bigint NOT NULL,
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    asset_id character varying NOT NULL,
    asset_name character varying NOT NULL,
    description character varying NOT NULL,
    quantity bigint NOT NULL,
    decimals smallint NOT NULL,
    reissuable boolean NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_3 OWNER TO dba;

--
-- Name: asset_decimals; Type: VIEW; Schema: public; Owner: dba
--

CREATE VIEW public.asset_decimals AS
 SELECT txs_3.asset_id,
    txs_3.decimals
   FROM public.txs_3
UNION ALL
 SELECT 'WAVES'::character varying AS asset_id,
    8 AS decimals;


ALTER TABLE public.asset_decimals OWNER TO dba;

--
-- Name: tickers; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.tickers (
    asset_id text NOT NULL,
    ticker text NOT NULL
);


ALTER TABLE public.tickers OWNER TO dba;

--
-- Name: txs_5; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_5 (
    fee bigint NOT NULL,
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
    fee bigint NOT NULL,
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    asset_id character varying NOT NULL,
    amount bigint NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_6 OWNER TO dba;

--
-- Name: assets; Type: VIEW; Schema: public; Owner: dba
--

CREATE VIEW public.assets AS
 SELECT issue.asset_id,
    t.ticker,
    issue.asset_name,
    issue.description,
    issue.sender,
    issue.height AS issue_height,
    issue.time_stamp AS issue_timestamp,
    (((issue.quantity)::numeric + COALESCE(reissue_q.reissued_total, (0)::numeric)) - COALESCE(burn_q.burned_total, (0)::numeric)) AS total_quantity,
    issue.decimals,
    COALESCE(reissuable_last.reissuable, issue.reissuable) AS reissuable
   FROM ((((public.txs_3 issue
     LEFT JOIN ( SELECT txs_5.asset_id,
            sum(txs_5.quantity) AS reissued_total
           FROM public.txs_5
          GROUP BY txs_5.asset_id) reissue_q ON (((issue.asset_id)::text = (reissue_q.asset_id)::text)))
     LEFT JOIN ( SELECT txs_6.asset_id,
            sum(txs_6.amount) AS burned_total
           FROM public.txs_6
          GROUP BY txs_6.asset_id) burn_q ON (((issue.asset_id)::text = (burn_q.asset_id)::text)))
     LEFT JOIN ( SELECT DISTINCT ON (txs_5.asset_id) txs_5.asset_id,
            txs_5.time_stamp,
            txs_5.reissuable
           FROM public.txs_5
          ORDER BY txs_5.asset_id, txs_5.time_stamp DESC) reissuable_last ON (((issue.asset_id)::text = (reissuable_last.asset_id)::text)))
     LEFT JOIN ( SELECT tickers.asset_id,
            tickers.ticker
           FROM public.tickers) t ON (((issue.asset_id)::text = t.asset_id)))
UNION ALL
 SELECT 'WAVES'::character varying AS asset_id,
    'WAVES'::text AS ticker,
    'Waves'::character varying AS asset_name,
    ''::character varying AS description,
    ''::character varying AS sender,
    0 AS issue_height,
    '2016-04-11 21:00:00'::timestamp without time zone AS issue_timestamp,
    ('10000000000000000'::bigint)::numeric AS total_quantity,
    8 AS decimals,
    false AS reissuable;


ALTER TABLE public.assets OWNER TO dba;

--
-- Name: assets1; Type: VIEW; Schema: public; Owner: dvshur
--

CREATE VIEW public.assets1 AS
 SELECT issue.asset_id,
    t.ticker,
    issue.asset_name,
    issue.description,
    issue.sender,
    issue.height AS issue_height,
    issue.time_stamp AS issue_timestamp,
    (((issue.quantity)::numeric + COALESCE(reissue_q.reissued_total, (0)::numeric)) - COALESCE(burn_q.burned_total, (0)::numeric)) AS total_quantity,
    issue.decimals,
        CASE
            WHEN (r_after.reissuable_after IS NULL) THEN issue.reissuable
            ELSE (issue.reissuable AND r_after.reissuable_after)
        END AS reissuable
   FROM ((((public.txs_3 issue
     LEFT JOIN ( SELECT txs_5.asset_id,
            sum(txs_5.quantity) AS reissued_total
           FROM public.txs_5
          GROUP BY txs_5.asset_id) reissue_q ON (((issue.asset_id)::text = (reissue_q.asset_id)::text)))
     LEFT JOIN ( SELECT txs_6.asset_id,
            sum(txs_6.amount) AS burned_total
           FROM public.txs_6
          GROUP BY txs_6.asset_id) burn_q ON (((issue.asset_id)::text = (burn_q.asset_id)::text)))
     LEFT JOIN ( SELECT txs_5.asset_id,
            bool_and(txs_5.reissuable) AS reissuable_after
           FROM public.txs_5
          GROUP BY txs_5.asset_id) r_after ON (((issue.asset_id)::text = (r_after.asset_id)::text)))
     LEFT JOIN ( SELECT tickers.asset_id,
            tickers.ticker
           FROM public.tickers) t ON (((issue.asset_id)::text = t.asset_id)))
UNION ALL
 SELECT 'WAVES'::character varying AS asset_id,
    'WAVES'::text AS ticker,
    'Waves'::character varying AS asset_name,
    ''::character varying AS description,
    ''::character varying AS sender,
    0 AS issue_height,
    '2016-04-11 21:00:00'::timestamp without time zone AS issue_timestamp,
    ('10000000000000000'::bigint)::numeric AS total_quantity,
    8 AS decimals,
    false AS reissuable;


ALTER TABLE public.assets1 OWNER TO dvshur;

--
-- Name: orders; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.orders (
    id character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    matcher_public_key character varying NOT NULL,
    order_type character varying NOT NULL,
    price_asset character varying NOT NULL,
    amount_asset character varying NOT NULL,
    price bigint NOT NULL,
    amount bigint NOT NULL,
    time_stamp timestamp without time zone NOT NULL,
    expiration timestamp without time zone NOT NULL,
    matcher_fee bigint NOT NULL,
    signature character varying NOT NULL,
    sender text
);


ALTER TABLE public.orders OWNER TO dba;

--
-- Name: txs_1; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_1 (
    fee bigint NOT NULL,
    recipient character varying NOT NULL,
    amount bigint NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_1 OWNER TO dba;

--
-- Name: txs_10; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_10 (
    fee bigint NOT NULL,
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    alias character varying NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_10 OWNER TO dba;

--
-- Name: txs_2; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_2 (
    fee bigint NOT NULL,
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    recipient character varying NOT NULL,
    amount bigint NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_2 OWNER TO dba;

--
-- Name: txs_7; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_7 (
    fee bigint NOT NULL,
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    order1 character varying NOT NULL,
    order2 character varying NOT NULL,
    amount_asset character varying NOT NULL,
    price_asset character varying NOT NULL,
    amount bigint NOT NULL,
    price bigint NOT NULL,
    buy_matcher_fee bigint NOT NULL,
    sell_matcher_fee bigint NOT NULL,
    order1_sender text,
    order2_sender text
)
INHERITS (public.txs);


ALTER TABLE public.txs_7 OWNER TO dba;

--
-- Name: txs_8; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_8 (
    fee bigint NOT NULL,
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    recipient character varying NOT NULL,
    amount bigint NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_8 OWNER TO dba;

--
-- Name: txs_9; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_9 (
    fee bigint NOT NULL,
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    lease_id character varying NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_9 OWNER TO dba;

--
-- Name: transactions; Type: VIEW; Schema: public; Owner: dba
--

CREATE VIEW public.transactions AS
 SELECT txs_1.id,
    txs_1.time_stamp,
    NULL::character varying AS sender,
    NULL::character varying AS sender_public_key,
    txs_1.tx_type
   FROM public.txs_1
UNION ALL
 SELECT txs_2.id,
    txs_2.time_stamp,
    txs_2.sender,
    txs_2.sender_public_key,
    txs_2.tx_type
   FROM public.txs_2
UNION ALL
 SELECT txs_3.id,
    txs_3.time_stamp,
    txs_3.sender,
    txs_3.sender_public_key,
    txs_3.tx_type
   FROM public.txs_3
UNION ALL
 SELECT txs_4.id,
    txs_4.time_stamp,
    txs_4.sender,
    txs_4.sender_public_key,
    txs_4.tx_type
   FROM public.txs_4
UNION ALL
 SELECT txs_5.id,
    txs_5.time_stamp,
    txs_5.sender,
    txs_5.sender_public_key,
    txs_5.tx_type
   FROM public.txs_5
UNION ALL
 SELECT txs_6.id,
    txs_6.time_stamp,
    txs_6.sender,
    txs_6.sender_public_key,
    txs_6.tx_type
   FROM public.txs_6
UNION ALL
 SELECT txs_7.id,
    txs_7.time_stamp,
    txs_7.sender,
    txs_7.sender_public_key,
    txs_7.tx_type
   FROM public.txs_7
UNION ALL
 SELECT txs_8.id,
    txs_8.time_stamp,
    txs_8.sender,
    txs_8.sender_public_key,
    txs_8.tx_type
   FROM public.txs_8
UNION ALL
 SELECT txs_9.id,
    txs_9.time_stamp,
    txs_9.sender,
    txs_9.sender_public_key,
    txs_9.tx_type
   FROM public.txs_9
UNION ALL
 SELECT txs_10.id,
    txs_10.time_stamp,
    txs_10.sender,
    txs_10.sender_public_key,
    txs_10.tx_type
   FROM public.txs_10
UNION ALL
 SELECT txs_11.id,
    txs_11.time_stamp,
    txs_11.sender,
    txs_11.sender_public_key,
    txs_11.tx_type
   FROM public.txs_11;


ALTER TABLE public.transactions OWNER TO dba;

--
-- Name: blockchain_events; Type: VIEW; Schema: public; Owner: dba
--

CREATE VIEW public.blockchain_events AS
 SELECT transactions.id,
    transactions.time_stamp,
    transactions.sender_public_key,
    transactions.tx_type AS event_type
   FROM public.transactions
UNION ALL
 SELECT orders.id,
    orders.time_stamp,
    orders.sender_public_key,
    0 AS event_type
   FROM public.orders;


ALTER TABLE public.blockchain_events OWNER TO dba;

--
-- Name: blockchain_events_m; Type: MATERIALIZED VIEW; Schema: public; Owner: dba
--

CREATE MATERIALIZED VIEW public.blockchain_events_m AS
 SELECT orders.id,
    orders.time_stamp,
    orders.sender,
    orders.sender_public_key,
    0 AS event_type
   FROM public.orders
UNION ALL
 SELECT txs_2.id,
    txs_2.time_stamp,
    txs_2.sender,
    txs_2.sender_public_key,
    txs_2.tx_type AS event_type
   FROM public.txs_2
UNION ALL
 SELECT txs_3.id,
    txs_3.time_stamp,
    txs_3.sender,
    txs_3.sender_public_key,
    txs_3.tx_type AS event_type
   FROM public.txs_3
UNION ALL
 SELECT txs_4.id,
    txs_4.time_stamp,
    txs_4.sender,
    txs_4.sender_public_key,
    txs_4.tx_type AS event_type
   FROM public.txs_4
UNION ALL
 SELECT txs_5.id,
    txs_5.time_stamp,
    txs_5.sender,
    txs_5.sender_public_key,
    txs_5.tx_type AS event_type
   FROM public.txs_5
UNION ALL
 SELECT txs_6.id,
    txs_6.time_stamp,
    txs_6.sender,
    txs_6.sender_public_key,
    txs_6.tx_type AS event_type
   FROM public.txs_6
UNION ALL
 SELECT txs_7.id,
    txs_7.time_stamp,
    txs_7.sender,
    txs_7.sender_public_key,
    txs_7.tx_type AS event_type
   FROM public.txs_7
UNION ALL
 SELECT txs_8.id,
    txs_8.time_stamp,
    txs_8.sender,
    txs_8.sender_public_key,
    txs_8.tx_type AS event_type
   FROM public.txs_8
UNION ALL
 SELECT txs_9.id,
    txs_9.time_stamp,
    txs_9.sender,
    txs_9.sender_public_key,
    txs_9.tx_type AS event_type
   FROM public.txs_9
UNION ALL
 SELECT txs_10.id,
    txs_10.time_stamp,
    txs_10.sender,
    txs_10.sender_public_key,
    txs_10.tx_type AS event_type
   FROM public.txs_10
UNION ALL
 SELECT txs_11.id,
    txs_11.time_stamp,
    txs_11.sender,
    txs_11.sender_public_key,
    txs_11.tx_type AS event_type
   FROM public.txs_11
  WITH NO DATA;


ALTER TABLE public.blockchain_events_m OWNER TO dba;

--
-- Name: blocks; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.blocks (
    schema_version smallint NOT NULL,
    time_stamp timestamp without time zone NOT NULL,
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
-- Name: blocks_raw; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.blocks_raw (
    height integer NOT NULL,
    b jsonb NOT NULL
);


ALTER TABLE public.blocks_raw OWNER TO dba;

--
-- Name: daily_active_addresses_m; Type: MATERIALIZED VIEW; Schema: public; Owner: dba
--

CREATE MATERIALIZED VIEW public.daily_active_addresses_m AS
 SELECT counted.days,
    counted.sender,
    counted.event_type
   FROM ( SELECT date(blockchain_events_m.time_stamp) AS days,
            blockchain_events_m.sender,
            blockchain_events_m.event_type,
            row_number() OVER (PARTITION BY (date(blockchain_events_m.time_stamp)), blockchain_events_m.sender, blockchain_events_m.event_type ORDER BY blockchain_events_m.time_stamp) AS rc
           FROM public.blockchain_events_m) counted
  WHERE (counted.rc = 1)
  WITH NO DATA;


ALTER TABLE public.daily_active_addresses_m OWNER TO dba;

--
-- Name: first_money_receive; Type: MATERIALIZED VIEW; Schema: public; Owner: dba
--

CREATE MATERIALIZED VIEW public.first_money_receive AS
 WITH counted_txs AS (
         SELECT t.time_stamp,
            t.asset_id,
            t.amount,
            t.recipient,
            row_number() OVER (PARTITION BY t.recipient ORDER BY t.time_stamp) AS rk
           FROM public.txs_4 t
        )
 SELECT ct.time_stamp,
    ct.asset_id,
    ((ct.amount)::double precision * ((10)::double precision ^ ((- assets.decimals))::double precision)) AS amount,
    ct.recipient
   FROM (counted_txs ct
     JOIN public.assets ON (((ct.asset_id)::text = (assets.asset_id)::text)))
  WHERE (ct.rk = 1)
  WITH NO DATA;


ALTER TABLE public.first_money_receive OWNER TO dba;

--
-- Name: first_time_events_m; Type: MATERIALIZED VIEW; Schema: public; Owner: dba
--

CREATE MATERIALIZED VIEW public.first_time_events_m AS
 SELECT counted.time_stamp,
    counted.id,
    counted.sender,
    counted.sender_public_key,
    counted.event_type
   FROM ( SELECT blockchain_events_m.id,
            blockchain_events_m.time_stamp,
            blockchain_events_m.sender,
            blockchain_events_m.sender_public_key,
            blockchain_events_m.event_type,
            row_number() OVER (PARTITION BY blockchain_events_m.sender ORDER BY blockchain_events_m.time_stamp) AS rc
           FROM public.blockchain_events_m) counted
  WHERE (counted.rc = 1)
  WITH NO DATA;


ALTER TABLE public.first_time_events_m OWNER TO dba;

--
-- Name: test_types; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.test_types (
    i8 bigint,
    f4 double precision,
    f8 double precision,
    n numeric,
    i8a bigint[],
    f4a double precision[],
    f8a double precision[],
    na numeric[]
);


ALTER TABLE public.test_types OWNER TO dba;

--
-- Name: txs_12; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_12 (
    fee bigint NOT NULL,
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_12 OWNER TO dba;

--
-- Name: txs_12_data; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_12_data (
    tx_id text NOT NULL,
    data_key text NOT NULL,
    data_type text NOT NULL,
    data_value_integer bigint,
    data_value_boolean boolean,
    data_value_binary text,
    data_value_string text,
    position_in_tx smallint NOT NULL
);


ALTER TABLE public.txs_12_data OWNER TO dba;

--
-- Name: txs_13; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_13 (
    fee bigint NOT NULL,
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
    fee bigint NOT NULL,
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    asset_id character varying NOT NULL,
    min_sponsored_asset_fee bigint
)
INHERITS (public.txs);


ALTER TABLE public.txs_14 OWNER TO dba;

--
-- Name: txs_7_v2; Type: TABLE; Schema: public; Owner: dba
--

CREATE TABLE public.txs_7_v2 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    fee bigint NOT NULL,
    order1 jsonb NOT NULL,
    order2 jsonb NOT NULL,
    amount_asset character varying NOT NULL,
    price_asset character varying NOT NULL,
    amount bigint NOT NULL,
    price bigint NOT NULL,
    buy_matcher_fee bigint NOT NULL,
    sell_matcher_fee bigint NOT NULL
)
INHERITS (public.txs);


ALTER TABLE public.txs_7_v2 OWNER TO dba;

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
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: tickers tickers_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.tickers
    ADD CONSTRAINT tickers_pkey PRIMARY KEY (asset_id);


--
-- Name: txs_10 txs_10_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_10
    ADD CONSTRAINT txs_10_pkey PRIMARY KEY (id, time_stamp);


--
-- Name: txs_11 txs_11_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_11
    ADD CONSTRAINT txs_11_pkey PRIMARY KEY (id);


--
-- Name: txs_11_transfers txs_11_transfers_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_11_transfers
    ADD CONSTRAINT txs_11_transfers_pkey PRIMARY KEY (tx_id, position_in_tx);


--
-- Name: txs_12_data txs_12_data_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_12_data
    ADD CONSTRAINT txs_12_data_pkey PRIMARY KEY (tx_id, position_in_tx);


--
-- Name: txs_12 txs_12_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_12
    ADD CONSTRAINT txs_12_pkey PRIMARY KEY (id);


--
-- Name: txs_13 txs_13_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_13
    ADD CONSTRAINT txs_13_pkey PRIMARY KEY (id);


--
-- Name: txs_14 txs_14_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_14
    ADD CONSTRAINT txs_14_pkey PRIMARY KEY (id);


--
-- Name: txs_1 txs_1_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_1
    ADD CONSTRAINT txs_1_pkey PRIMARY KEY (id);


--
-- Name: txs_2 txs_2_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_2
    ADD CONSTRAINT txs_2_pkey PRIMARY KEY (id, time_stamp);


--
-- Name: txs_3 txs_3_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_3
    ADD CONSTRAINT txs_3_pkey PRIMARY KEY (id);


--
-- Name: txs_4 txs_4_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_4
    ADD CONSTRAINT txs_4_pkey PRIMARY KEY (id);


--
-- Name: txs_5 txs_5_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_5
    ADD CONSTRAINT txs_5_pkey PRIMARY KEY (id);


--
-- Name: txs_6 txs_6_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_6
    ADD CONSTRAINT txs_6_pkey PRIMARY KEY (id);


--
-- Name: txs_7 txs_7_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_7
    ADD CONSTRAINT txs_7_pkey PRIMARY KEY (id);


--
-- Name: txs_7_v2 txs_7_v2_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_7_v2
    ADD CONSTRAINT txs_7_v2_pkey PRIMARY KEY (id);


--
-- Name: txs_8 txs_8_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_8
    ADD CONSTRAINT txs_8_pkey PRIMARY KEY (id);


--
-- Name: txs_9 txs_9_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_9
    ADD CONSTRAINT txs_9_pkey PRIMARY KEY (id);


--
-- Name: txs txs_pkey; Type: CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs
    ADD CONSTRAINT txs_pkey PRIMARY KEY (id);


--
-- Name: blockchain_events_m_date_sender_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX blockchain_events_m_date_sender_idx ON public.blockchain_events_m USING btree (date(time_stamp), sender);


--
-- Name: blockchain_events_m_event_type_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX blockchain_events_m_event_type_idx ON public.blockchain_events_m USING btree (event_type);


--
-- Name: blockchain_events_m_sender_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX blockchain_events_m_sender_idx ON public.blockchain_events_m USING btree (sender);


--
-- Name: blockchain_events_m_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX blockchain_events_m_time_stamp_idx ON public.blockchain_events_m USING btree (time_stamp);


--
-- Name: daily_active_addresses_m_days_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX daily_active_addresses_m_days_idx ON public.daily_active_addresses_m USING btree (days);


--
-- Name: daily_active_addresses_m_sender_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX daily_active_addresses_m_sender_idx ON public.daily_active_addresses_m USING btree (sender);


--
-- Name: first_money_receive_asset_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX first_money_receive_asset_id_idx ON public.first_money_receive USING hash (asset_id);


--
-- Name: first_money_receive_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX first_money_receive_time_stamp_idx ON public.first_money_receive USING btree (time_stamp);


--
-- Name: first_time_events_m_sender_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX first_time_events_m_sender_idx ON public.first_time_events_m USING btree (sender);


--
-- Name: first_time_events_m_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX first_time_events_m_time_stamp_idx ON public.first_time_events_m USING btree (time_stamp);


--
-- Name: orders_sender_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX orders_sender_idx ON public.orders USING btree (sender);


--
-- Name: orders_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX orders_time_stamp_idx ON public.orders USING btree (time_stamp);


--
-- Name: txs_10_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_10_height_idx ON public.txs_10 USING btree (height);


--
-- Name: txs_10_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_10_time_stamp_idx ON public.txs_10 USING btree (time_stamp);


--
-- Name: txs_11_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_11_height_idx ON public.txs_11 USING btree (height);


--
-- Name: txs_11_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_11_time_stamp_idx ON public.txs_11 USING btree (time_stamp);


--
-- Name: txs_11_transfers_tx_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_11_transfers_tx_id_idx ON public.txs_11_transfers USING hash (tx_id);


--
-- Name: txs_12_data_data_key_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_data_data_key_idx ON public.txs_12_data USING hash (data_key);


--
-- Name: txs_12_data_data_type_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_data_data_type_idx ON public.txs_12_data USING hash (data_type);


--
-- Name: txs_12_data_value_binary_partial_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_data_value_binary_partial_idx ON public.txs_12_data USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


--
-- Name: txs_12_data_value_boolean_partial_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_data_value_boolean_partial_idx ON public.txs_12_data USING btree (data_value_boolean) WHERE (data_type = 'boolean'::text);


--
-- Name: txs_12_data_value_integer_partial_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_data_value_integer_partial_idx ON public.txs_12_data USING btree (data_value_integer) WHERE (data_type = 'integer'::text);


--
-- Name: txs_12_data_value_string_partial_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_data_value_string_partial_idx ON public.txs_12_data USING hash (data_value_string) WHERE (data_type = 'string'::text);


--
-- Name: txs_12_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_height_idx ON public.txs_12 USING btree (height);


--
-- Name: txs_12_time_stamp_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_12_time_stamp_id_idx ON public.txs_12 USING btree (time_stamp, id);


--
-- Name: txs_13_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_13_height_idx ON public.txs_13 USING btree (height);


--
-- Name: txs_14_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_14_height_idx ON public.txs_14 USING btree (height);


--
-- Name: txs_1_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_1_height_idx ON public.txs_1 USING btree (height);


--
-- Name: txs_1_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_1_time_stamp_idx ON public.txs_1 USING btree (time_stamp);


--
-- Name: txs_2_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_2_height_idx ON public.txs_2 USING btree (height);


--
-- Name: txs_2_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_2_time_stamp_idx ON public.txs_2 USING btree (time_stamp);


--
-- Name: txs_3_asset_id_idx1; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_3_asset_id_idx1 ON public.txs_3 USING btree (asset_id);


--
-- Name: txs_3_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_3_height_idx ON public.txs_3 USING btree (height);


--
-- Name: txs_3_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_3_time_stamp_idx ON public.txs_3 USING btree (time_stamp);


--
-- Name: txs_4_asset_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_4_asset_id_idx ON public.txs_4 USING btree (asset_id);


--
-- Name: txs_4_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_4_height_idx ON public.txs_4 USING btree (height);


--
-- Name: txs_4_recipient_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_4_recipient_idx ON public.txs_4 USING btree (recipient);


--
-- Name: txs_4_recipient_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_4_recipient_time_stamp_idx ON public.txs_4 USING btree (recipient, time_stamp);


--
-- Name: txs_4_sender_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_4_sender_idx ON public.txs_4 USING btree (sender);


--
-- Name: txs_4_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_4_time_stamp_idx ON public.txs_4 USING btree (time_stamp);


--
-- Name: txs_5_asset_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_5_asset_id_idx ON public.txs_5 USING hash (asset_id);


--
-- Name: txs_5_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_5_height_idx ON public.txs_5 USING btree (height);


--
-- Name: txs_5_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_5_time_stamp_idx ON public.txs_5 USING btree (time_stamp);


--
-- Name: txs_6_asset_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_6_asset_id_idx ON public.txs_6 USING hash (asset_id);


--
-- Name: txs_6_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_6_height_idx ON public.txs_6 USING btree (height);


--
-- Name: txs_6_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_6_time_stamp_idx ON public.txs_6 USING btree (time_stamp);


--
-- Name: txs_7_amount_asset_price_asset_time_stamp_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_amount_asset_price_asset_time_stamp_id_idx ON public.txs_7 USING btree (amount_asset, price_asset, time_stamp, id);


--
-- Name: txs_7_amount_asset_price_asset_time_stamp_id_idx1; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_amount_asset_price_asset_time_stamp_id_idx1 ON public.txs_7 USING btree (amount_asset, price_asset, time_stamp, id DESC);


--
-- Name: txs_7_array_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_array_idx ON public.txs_7 USING gin ((ARRAY[order1, order2]));


--
-- Name: txs_7_array_time_stamp_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_array_time_stamp_id_idx ON public.txs_7 USING gin ((ARRAY[order1, order2]), time_stamp, id);


--
-- Name: txs_7_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_height_idx ON public.txs_7 USING btree (height);


--
-- Name: txs_7_order1_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_order1_idx ON public.txs_7 USING hash (order1);


--
-- Name: txs_7_order2_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_order2_idx ON public.txs_7 USING hash (order2);


--
-- Name: txs_7_price_asset_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_price_asset_idx ON public.txs_7 USING btree (price_asset);


--
-- Name: txs_7_sender_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_sender_idx ON public.txs_7 USING btree (sender);


--
-- Name: txs_7_time_stamp_desc_id_asc_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_time_stamp_desc_id_asc_idx ON public.txs_7 USING btree (time_stamp DESC, id);


--
-- Name: txs_7_time_stamp_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_time_stamp_id_idx ON public.txs_7 USING btree (time_stamp, id);


--
-- Name: txs_7_v2_amount_asset_price_asset_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_v2_amount_asset_price_asset_time_stamp_idx ON public.txs_7_v2 USING btree (amount_asset, price_asset, time_stamp);


--
-- Name: txs_7_v2_array_time_stamp_id_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_v2_array_time_stamp_id_idx ON public.txs_7_v2 USING gin ((ARRAY[(order1 ->> 'sender'::text), (order2 ->> 'sender'::text)]), time_stamp, id);


--
-- Name: txs_7_v2_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_v2_height_idx ON public.txs_7_v2 USING btree (height);


--
-- Name: txs_7_v2_price_asset_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_v2_price_asset_idx ON public.txs_7_v2 USING btree (price_asset);


--
-- Name: txs_7_v2_sender_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_v2_sender_idx ON public.txs_7_v2 USING btree (sender);


--
-- Name: txs_7_v2_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_7_v2_time_stamp_idx ON public.txs_7_v2 USING btree (time_stamp);


--
-- Name: txs_8_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_8_height_idx ON public.txs_8 USING btree (height);


--
-- Name: txs_8_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_8_time_stamp_idx ON public.txs_8 USING btree (time_stamp);


--
-- Name: txs_9_height_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_9_height_idx ON public.txs_9 USING btree (height);


--
-- Name: txs_9_time_stamp_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_9_time_stamp_idx ON public.txs_9 USING btree (time_stamp);


--
-- Name: txs_tx_type_idx; Type: INDEX; Schema: public; Owner: dba
--

CREATE INDEX txs_tx_type_idx ON public.txs USING btree (tx_type);


--
-- Name: blocks_raw block_delete; Type: RULE; Schema: public; Owner: dba
--

CREATE RULE block_delete AS
    ON DELETE TO public.blocks_raw DO  DELETE FROM public.blocks
  WHERE (blocks.height = old.height);


--
-- Name: blocks_raw block_insert_trigger; Type: TRIGGER; Schema: public; Owner: dba
--

CREATE TRIGGER block_insert_trigger BEFORE INSERT ON public.blocks_raw FOR EACH ROW EXECUTE PROCEDURE public.on_block_insert();


--
-- Name: blocks_raw block_update_trigger; Type: TRIGGER; Schema: public; Owner: dba
--

CREATE TRIGGER block_update_trigger BEFORE UPDATE ON public.blocks_raw FOR EACH ROW EXECUTE PROCEDURE public.on_block_update();


--
-- Name: txs_7 delete_orphan_orders; Type: TRIGGER; Schema: public; Owner: dba
--

CREATE TRIGGER delete_orphan_orders AFTER DELETE ON public.txs_7 FOR EACH ROW EXECUTE PROCEDURE public.delete_orders_after_tx();


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
-- Name: txs_7_v2 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_7_v2
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_7 fk_orders_1; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_7
    ADD CONSTRAINT fk_orders_1 FOREIGN KEY (order1) REFERENCES public.orders(id) ON DELETE RESTRICT;


--
-- Name: txs_7 fk_orders_2; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_7
    ADD CONSTRAINT fk_orders_2 FOREIGN KEY (order2) REFERENCES public.orders(id) ON DELETE RESTRICT;


--
-- Name: txs_11_transfers fk_tx_id; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_11_transfers
    ADD CONSTRAINT fk_tx_id FOREIGN KEY (tx_id) REFERENCES public.txs_11(id) ON DELETE CASCADE;


--
-- Name: txs_12_data txs_12_data_tx_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_12_data
    ADD CONSTRAINT txs_12_data_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES public.txs_12(id) ON DELETE CASCADE;


--
-- Name: txs_12 txs_12_height_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dba
--

ALTER TABLE ONLY public.txs_12
    ADD CONSTRAINT txs_12_height_fkey FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

