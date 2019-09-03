--
-- PostgreSQL database dump
--

-- Dumped from database version 11.1 (Ubuntu 11.1-3.pgdg18.04+1)
-- Dumped by pg_dump version 11.2 (Ubuntu 11.2-1.pgdg16.04+1)

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
-- Name: btree_gin; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gin WITH SCHEMA public;


--
-- Name: EXTENSION btree_gin; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gin IS 'support for indexing common datatypes in GIN';


--
-- Name: find_missing_blocks(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: get_asset_id(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_asset_id(text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT COALESCE($1, 'WAVES');
$_$;


--
-- Name: insert_all(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_all(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	PERFORM insert_block (b);
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


--
-- Name: insert_block(jsonb); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: insert_txs_1(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_txs_1(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  insert into txs_1 (height,
                     tx_type,
                     id,
                     time_stamp,
                     signature,
                     proofs,
                     tx_version,
                     fee,
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


--
-- Name: insert_txs_10(jsonb); Type: FUNCTION; Schema: public; Owner: -
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
		to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
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


--
-- Name: insert_txs_11(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_txs_11(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO txs_11 (height,
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


--
-- Name: insert_txs_12(jsonb); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: insert_txs_13(jsonb); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: insert_txs_14(jsonb); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: insert_txs_15(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_txs_15(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: insert_txs_16(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_txs_16(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: insert_txs_2(jsonb); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: insert_txs_3(jsonb); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: insert_txs_4(jsonb); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: insert_txs_5(jsonb); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: insert_txs_6(jsonb); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: insert_txs_7(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_txs_7(b jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  insert into txs_7 (height,
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


--
-- Name: insert_txs_8(jsonb); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: insert_txs_9(jsonb); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: jsonb_array_cast_int(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.jsonb_array_cast_int(jsonb) RETURNS integer[]
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT array_agg(x)::int[] || ARRAY[]::int[] FROM jsonb_array_elements_text($1) t(x);
$_$;


--
-- Name: jsonb_array_cast_text(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.jsonb_array_cast_text(jsonb) RETURNS text[]
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT array_agg(x) || ARRAY[]::text[] FROM jsonb_array_elements_text($1) t(x);
$_$;


--
-- Name: on_block_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.on_block_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  	PERFORM insert_all (new.b);
	return new;
END
$$;


--
-- Name: on_block_update(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: reinsert_range(integer, integer); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: reinsert_range(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: text_timestamp_cast(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.text_timestamp_cast(text) RETURNS timestamp without time zone
    LANGUAGE plpgsql
    AS $_$
begin
--   raise notice $1;
  return to_timestamp($1 :: DOUBLE PRECISION / 1000);
END
$_$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: txs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs (
    height integer NOT NULL,
    tx_type smallint NOT NULL,
    id character varying NOT NULL,
    time_stamp timestamp without time zone NOT NULL,
    signature character varying,
    proofs character varying[],
    tx_version smallint,
    sender character varying,
    sender_public_key character varying
);


--
-- Name: txs_3; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_3 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    fee bigint NOT NULL,
    asset_id character varying NOT NULL,
    asset_name character varying NOT NULL,
    description character varying NOT NULL,
    quantity bigint NOT NULL,
    decimals smallint NOT NULL,
    reissuable boolean NOT NULL,
    script character varying
)
INHERITS (public.txs);


--
-- Name: asset_decimals; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.asset_decimals AS
 SELECT txs_3.asset_id,
    txs_3.decimals
   FROM public.txs_3
UNION ALL
 SELECT 'WAVES'::character varying AS asset_id,
    8 AS decimals;


--
-- Name: tickers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tickers (
    asset_id text NOT NULL,
    ticker text NOT NULL
);


--
-- Name: txs_14; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_14 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    fee bigint NOT NULL,
    asset_id character varying NOT NULL,
    min_sponsored_asset_fee bigint
)
INHERITS (public.txs);


--
-- Name: txs_5; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_5 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    fee bigint NOT NULL,
    asset_id character varying NOT NULL,
    quantity bigint NOT NULL,
    reissuable boolean NOT NULL
)
INHERITS (public.txs);


--
-- Name: txs_6; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_6 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    fee bigint NOT NULL,
    asset_id character varying NOT NULL,
    amount bigint NOT NULL
)
INHERITS (public.txs);


--
-- Name: assets; Type: VIEW; Schema: public; Owner: -
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
        CASE
            WHEN (r_after.reissuable_after IS NULL) THEN issue.reissuable
            ELSE (issue.reissuable AND r_after.reissuable_after)
        END AS reissuable,
        CASE
            WHEN (issue.script IS NOT NULL) THEN true
            ELSE false
        END AS has_script,
    txs_14.min_sponsored_asset_fee
   FROM (((((public.txs_3 issue
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
     LEFT JOIN ( SELECT DISTINCT ON (txs_14_1.asset_id) txs_14_1.asset_id,
            txs_14_1.min_sponsored_asset_fee
           FROM public.txs_14 txs_14_1
          ORDER BY txs_14_1.asset_id, txs_14_1.height DESC) txs_14 ON (((issue.asset_id)::text = (txs_14.asset_id)::text)))
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
    false AS reissuable,
    false AS has_script,
    NULL::bigint AS min_sponsored_asset_fee;


--
-- Name: assets_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assets_metadata (
    asset_id character varying NOT NULL,
    asset_name character varying,
    ticker character varying,
    height integer
);


--
-- Name: assets_names_map; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assets_names_map (
    asset_id character varying NOT NULL,
    asset_name character varying NOT NULL,
    searchable_asset_name tsvector NOT NULL
);


--
-- Name: blocks; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: blocks_raw; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blocks_raw (
    height integer NOT NULL,
    b jsonb NOT NULL
);


--
-- Name: candles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.candles (
    time_start timestamp without time zone NOT NULL,
    amount_asset_id character varying(255) NOT NULL,
    price_asset_id character varying(255) NOT NULL,
    low numeric NOT NULL,
    high numeric NOT NULL,
    volume numeric NOT NULL,
    quote_volume numeric NOT NULL,
    max_height integer NOT NULL,
    txs_count integer NOT NULL,
    weighted_average_price numeric NOT NULL,
    open numeric NOT NULL,
    close numeric NOT NULL,
    interval_in_secs integer NOT NULL,
    matcher character varying(255) NOT NULL
);


--
-- Name: pairs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pairs (
    amount_asset_id character varying(255) NOT NULL,
    price_asset_id character varying(255) NOT NULL,
    first_price numeric NOT NULL,
    last_price numeric NOT NULL,
    volume numeric NOT NULL,
    volume_waves numeric,
    quote_volume numeric NOT NULL,
    high numeric NOT NULL,
    low numeric NOT NULL,
    weighted_average_price numeric NOT NULL,
    txs_count integer NOT NULL,
    matcher character varying(255) NOT NULL
);


--
-- Name: txs_1; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_1 (
    fee bigint NOT NULL,
    recipient character varying NOT NULL,
    amount bigint NOT NULL
)
INHERITS (public.txs);


--
-- Name: txs_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_10 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    fee bigint NOT NULL,
    alias character varying NOT NULL
)
INHERITS (public.txs);


--
-- Name: txs_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_11 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    fee bigint NOT NULL,
    asset_id character varying NOT NULL,
    attachment character varying NOT NULL
)
INHERITS (public.txs);


--
-- Name: txs_11_transfers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_11_transfers (
    tx_id character varying NOT NULL,
    recipient character varying NOT NULL,
    amount bigint NOT NULL,
    position_in_tx smallint NOT NULL
);


--
-- Name: txs_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_12 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    fee bigint NOT NULL
)
INHERITS (public.txs);


--
-- Name: txs_12_data; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: txs_13; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_13 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    fee bigint NOT NULL,
    script character varying
)
INHERITS (public.txs);


--
-- Name: txs_15; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_15 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    fee bigint NOT NULL,
    asset_id character varying NOT NULL,
    script character varying
)
INHERITS (public.txs);


--
-- Name: txs_16; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_16 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    fee bigint NOT NULL,
    dapp character varying NOT NULL,
    function_name character varying
)
INHERITS (public.txs);


--
-- Name: txs_16_args; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_16_args (
    tx_id text NOT NULL,
    arg_type text NOT NULL,
    arg_value_integer bigint,
    arg_value_boolean boolean,
    arg_value_binary text,
    arg_value_string text,
    position_in_args smallint NOT NULL
);


--
-- Name: txs_16_payment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_16_payment (
    tx_id text NOT NULL,
    amount bigint NOT NULL,
    asset_id text,
    position_in_payment smallint NOT NULL
);


--
-- Name: txs_2; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_2 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    fee bigint NOT NULL,
    recipient character varying NOT NULL,
    amount bigint NOT NULL
)
INHERITS (public.txs);


--
-- Name: txs_4; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_4 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    fee bigint NOT NULL,
    asset_id character varying NOT NULL,
    amount bigint NOT NULL,
    recipient character varying NOT NULL,
    fee_asset character varying NOT NULL,
    attachment character varying NOT NULL
)
INHERITS (public.txs);
ALTER TABLE ONLY public.txs_4 ALTER COLUMN sender SET STATISTICS 1000;


--
-- Name: txs_7; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_7 (
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


--
-- Name: txs_8; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_8 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    fee bigint NOT NULL,
    recipient character varying NOT NULL,
    amount bigint NOT NULL
)
INHERITS (public.txs);


--
-- Name: txs_9; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.txs_9 (
    sender character varying NOT NULL,
    sender_public_key character varying NOT NULL,
    fee bigint NOT NULL,
    lease_id character varying NOT NULL
)
INHERITS (public.txs);


--
-- Name: assets_names_map assets_map_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assets_names_map
    ADD CONSTRAINT assets_map_pk PRIMARY KEY (asset_id);


--
-- Name: blocks blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_pkey PRIMARY KEY (height);


--
-- Name: blocks_raw blocks_raw_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks_raw
    ADD CONSTRAINT blocks_raw_pkey PRIMARY KEY (height);


--
-- Name: candles candles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.candles
    ADD CONSTRAINT candles_pkey PRIMARY KEY (interval_in_secs, time_start, amount_asset_id, price_asset_id, matcher);


--
-- Name: tickers tickers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickers
    ADD CONSTRAINT tickers_pkey PRIMARY KEY (asset_id);


--
-- Name: txs_10 txs_10_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_10
    ADD CONSTRAINT txs_10_pkey PRIMARY KEY (id, time_stamp);


--
-- Name: txs_11 txs_11_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_11
    ADD CONSTRAINT txs_11_pkey PRIMARY KEY (id);


--
-- Name: txs_11_transfers txs_11_transfers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_11_transfers
    ADD CONSTRAINT txs_11_transfers_pkey PRIMARY KEY (tx_id, position_in_tx);


--
-- Name: txs_12_data txs_12_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_12_data
    ADD CONSTRAINT txs_12_data_pkey PRIMARY KEY (tx_id, position_in_tx);


--
-- Name: txs_12 txs_12_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_12
    ADD CONSTRAINT txs_12_pkey PRIMARY KEY (id);


--
-- Name: txs_13 txs_13_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_13
    ADD CONSTRAINT txs_13_pkey PRIMARY KEY (id);


--
-- Name: txs_14 txs_14_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_14
    ADD CONSTRAINT txs_14_pkey PRIMARY KEY (id);


--
-- Name: txs_15 txs_15_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_15
    ADD CONSTRAINT txs_15_pk PRIMARY KEY (id);


--
-- Name: txs_16_args txs_16_args_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_16_args
    ADD CONSTRAINT txs_16_args_pkey PRIMARY KEY (tx_id, position_in_args);


--
-- Name: txs_16_payment txs_16_payment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_16_payment
    ADD CONSTRAINT txs_16_payment_pkey PRIMARY KEY (tx_id, position_in_payment);


--
-- Name: txs_16 txs_16_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_16
    ADD CONSTRAINT txs_16_pk PRIMARY KEY (id);


--
-- Name: txs_1 txs_1_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_1
    ADD CONSTRAINT txs_1_pkey PRIMARY KEY (id);


--
-- Name: txs_2 txs_2_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_2
    ADD CONSTRAINT txs_2_pkey PRIMARY KEY (id, time_stamp);


--
-- Name: txs_3 txs_3_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_3
    ADD CONSTRAINT txs_3_pkey PRIMARY KEY (id);


--
-- Name: txs_4 txs_4_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_4
    ADD CONSTRAINT txs_4_pkey PRIMARY KEY (id);


--
-- Name: txs_5 txs_5_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_5
    ADD CONSTRAINT txs_5_pkey PRIMARY KEY (id);


--
-- Name: txs_6 txs_6_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_6
    ADD CONSTRAINT txs_6_pkey PRIMARY KEY (id);


--
-- Name: txs_7 txs_7_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_7
    ADD CONSTRAINT txs_7_pkey PRIMARY KEY (id);


--
-- Name: txs_8 txs_8_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_8
    ADD CONSTRAINT txs_8_pkey PRIMARY KEY (id);


--
-- Name: txs_9 txs_9_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_9
    ADD CONSTRAINT txs_9_pkey PRIMARY KEY (id);


--
-- Name: txs txs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs
    ADD CONSTRAINT txs_pkey PRIMARY KEY (id);


--
-- Name: assets_names_map_asset_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX assets_names_map_asset_name_idx ON public.assets_names_map USING btree (asset_name varchar_pattern_ops);


--
-- Name: candles_max_height_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX candles_max_height_index ON public.candles USING btree (max_height);


--
-- Name: order_senders_timestamp_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX order_senders_timestamp_id_idx ON public.txs_7 USING gin ((ARRAY[(order1 ->> 'sender'::text), (order2 ->> 'sender'::text)]), time_stamp, id);


--
-- Name: pairs_amount_asset_id_price_asset_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pairs_amount_asset_id_price_asset_id_index ON public.pairs USING btree (amount_asset_id, price_asset_id);


--
-- Name: searchable_asset_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX searchable_asset_name_idx ON public.assets_names_map USING gin (searchable_asset_name);


--
-- Name: tickers_ticker_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tickers_ticker_idx ON public.tickers USING btree (ticker);


--
-- Name: txs_10_alias_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_10_alias_idx ON public.txs_10 USING hash (alias);


--
-- Name: txs_10_height_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_10_height_idx ON public.txs_10 USING btree (height);


--
-- Name: txs_10_sender_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_10_sender_idx ON public.txs_10 USING hash (sender);


--
-- Name: txs_10_time_stamp_asc_id_asc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_10_time_stamp_asc_id_asc_idx ON public.txs_10 USING btree (time_stamp, id);


--
-- Name: txs_11_asset_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_11_asset_id_idx ON public.txs_11 USING hash (asset_id);


--
-- Name: txs_11_height_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_11_height_idx ON public.txs_11 USING btree (height);


--
-- Name: txs_11_sender_time_stamp_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_11_sender_time_stamp_id_idx ON public.txs_11 USING btree (sender, time_stamp, id);


--
-- Name: txs_11_time_stamp_desc_id_desc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_11_time_stamp_desc_id_desc_idx ON public.txs_11 USING btree (time_stamp DESC, id);


--
-- Name: txs_11_transfers_recipient_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_11_transfers_recipient_index ON public.txs_11_transfers USING btree (recipient);


--
-- Name: txs_12_data_data_key_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_12_data_data_key_idx ON public.txs_12_data USING hash (data_key);


--
-- Name: txs_12_data_data_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_12_data_data_type_idx ON public.txs_12_data USING hash (data_type);


--
-- Name: txs_12_data_value_binary_partial_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_12_data_value_binary_partial_idx ON public.txs_12_data USING hash (data_value_binary) WHERE (data_type = 'binary'::text);


--
-- Name: txs_12_data_value_boolean_partial_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_12_data_value_boolean_partial_idx ON public.txs_12_data USING btree (data_value_boolean) WHERE (data_type = 'boolean'::text);


--
-- Name: txs_12_data_value_integer_partial_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_12_data_value_integer_partial_idx ON public.txs_12_data USING btree (data_value_integer) WHERE (data_type = 'integer'::text);


--
-- Name: txs_12_data_value_string_partial_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_12_data_value_string_partial_idx ON public.txs_12_data USING hash (data_value_string) WHERE (data_type = 'string'::text);


--
-- Name: txs_12_height_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_12_height_idx ON public.txs_12 USING btree (height);


--
-- Name: txs_12_sender_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_12_sender_idx ON public.txs_12 USING hash (sender);


--
-- Name: txs_12_time_stamp_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_12_time_stamp_id_idx ON public.txs_12 USING btree (time_stamp, id);


--
-- Name: txs_13_height_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_13_height_idx ON public.txs_13 USING btree (height);


--
-- Name: txs_13_script_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_13_script_idx ON public.txs_13 USING hash (script);


--
-- Name: txs_13_sender_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_13_sender_idx ON public.txs_13 USING hash (sender);


--
-- Name: txs_13_time_stamp_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_13_time_stamp_id_idx ON public.txs_13 USING btree (time_stamp, id);


--
-- Name: txs_14_height_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_14_height_idx ON public.txs_14 USING btree (height);


--
-- Name: txs_14_sender_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_14_sender_idx ON public.txs_14 USING hash (sender);


--
-- Name: txs_14_time_stamp_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_14_time_stamp_id_idx ON public.txs_14 USING btree (time_stamp, id);


--
-- Name: txs_15_height_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_15_height_idx ON public.txs_15 USING btree (height);


--
-- Name: txs_15_script_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_15_script_idx ON public.txs_15 USING btree (script);


--
-- Name: txs_15_sender_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_15_sender_idx ON public.txs_15 USING btree (sender);


--
-- Name: txs_15_time_stamp_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_15_time_stamp_id_idx ON public.txs_15 USING btree (time_stamp, id);


--
-- Name: txs_16_args_arg_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_16_args_arg_type_idx ON public.txs_16_args USING hash (arg_type);


--
-- Name: txs_16_args_arg_value_binary_partial_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_16_args_arg_value_binary_partial_idx ON public.txs_16_args USING hash (arg_value_binary) WHERE (arg_type = 'binary'::text);


--
-- Name: txs_16_args_arg_value_boolean_partial_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_16_args_arg_value_boolean_partial_idx ON public.txs_16_args USING btree (arg_value_boolean) WHERE (arg_type = 'boolean'::text);


--
-- Name: txs_16_args_arg_value_integer_partial_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_16_args_arg_value_integer_partial_idx ON public.txs_16_args USING btree (arg_value_integer) WHERE (arg_type = 'integer'::text);


--
-- Name: txs_16_args_arg_value_string_partial_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_16_args_arg_value_string_partial_idx ON public.txs_16_args USING hash (arg_value_string) WHERE (arg_type = 'string'::text);


--
-- Name: txs_16_height_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_16_height_idx ON public.txs_16 USING btree (height);


--
-- Name: txs_1_height_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_1_height_idx ON public.txs_1 USING btree (height);


--
-- Name: txs_2_height_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_2_height_idx ON public.txs_2 USING btree (height);


--
-- Name: txs_2_sender_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_2_sender_idx ON public.txs_2 USING hash (sender);


--
-- Name: txs_2_time_stamp_desc_id_asc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_2_time_stamp_desc_id_asc_idx ON public.txs_2 USING btree (time_stamp DESC, id);


--
-- Name: txs_3_asset_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_3_asset_id_idx ON public.txs_3 USING hash (asset_id);


--
-- Name: txs_3_height_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_3_height_idx ON public.txs_3 USING btree (height);


--
-- Name: txs_3_script_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_3_script_idx ON public.txs_3 USING btree (script);


--
-- Name: txs_3_sender_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_3_sender_idx ON public.txs_3 USING hash (sender);


--
-- Name: txs_3_time_stamp_asc_id_asc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_3_time_stamp_asc_id_asc_idx ON public.txs_3 USING btree (time_stamp, id);


--
-- Name: txs_3_time_stamp_desc_id_asc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_3_time_stamp_desc_id_asc_idx ON public.txs_3 USING btree (time_stamp DESC, id);


--
-- Name: txs_3_time_stamp_desc_id_desc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_3_time_stamp_desc_id_desc_idx ON public.txs_3 USING btree (time_stamp DESC, id DESC);


--
-- Name: txs_4_asset_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_4_asset_id_index ON public.txs_4 USING btree (asset_id);


--
-- Name: txs_4_height_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_4_height_idx ON public.txs_4 USING btree (height);


--
-- Name: txs_4_recipient_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_4_recipient_idx ON public.txs_4 USING btree (recipient);


--
-- Name: txs_4_sender_time_stamp_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_4_sender_time_stamp_id_idx ON public.txs_4 USING btree (sender, time_stamp, id);


--
-- Name: txs_4_time_stamp_desc_id_asc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_4_time_stamp_desc_id_asc_idx ON public.txs_4 USING btree (time_stamp DESC, id);


--
-- Name: txs_4_time_stamp_desc_id_desc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_4_time_stamp_desc_id_desc_idx ON public.txs_4 USING btree (time_stamp DESC, id DESC);


--
-- Name: txs_5_asset_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_5_asset_id_idx ON public.txs_5 USING hash (asset_id);


--
-- Name: txs_5_height_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_5_height_idx ON public.txs_5 USING btree (height);


--
-- Name: txs_5_sender_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_5_sender_idx ON public.txs_5 USING hash (sender);


--
-- Name: txs_5_time_stamp_asc_id_asc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_5_time_stamp_asc_id_asc_idx ON public.txs_5 USING btree (time_stamp, id);


--
-- Name: txs_5_time_stamp_desc_id_asc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_5_time_stamp_desc_id_asc_idx ON public.txs_5 USING btree (time_stamp DESC, id);


--
-- Name: txs_5_time_stamp_desc_id_desc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_5_time_stamp_desc_id_desc_idx ON public.txs_5 USING btree (time_stamp DESC, id DESC);


--
-- Name: txs_6_asset_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_6_asset_id_idx ON public.txs_6 USING hash (asset_id);


--
-- Name: txs_6_height_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_6_height_idx ON public.txs_6 USING btree (height);


--
-- Name: txs_6_sender_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_6_sender_idx ON public.txs_6 USING hash (sender);


--
-- Name: txs_6_time_stamp_asc_id_asc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_6_time_stamp_asc_id_asc_idx ON public.txs_6 USING btree (time_stamp, id);


--
-- Name: txs_6_time_stamp_desc_id_asc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_6_time_stamp_desc_id_asc_idx ON public.txs_6 USING btree (time_stamp DESC, id);


--
-- Name: txs_6_time_stamp_desc_id_desc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_6_time_stamp_desc_id_desc_idx ON public.txs_6 USING btree (time_stamp DESC, id DESC);


--
-- Name: txs_7_amount_asset_price_asset_time_stamp_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_7_amount_asset_price_asset_time_stamp_id_idx ON public.txs_7 USING btree (amount_asset, price_asset, time_stamp, id);


--
-- Name: txs_7_height_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_7_height_idx ON public.txs_7 USING btree (height);


--
-- Name: txs_7_price_asset_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_7_price_asset_idx ON public.txs_7 USING hash (price_asset);


--
-- Name: txs_7_sender_time_stamp_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_7_sender_time_stamp_id_idx ON public.txs_7 USING btree (sender, time_stamp, id);


--
-- Name: txs_7_time_stamp_asc_id_asc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_7_time_stamp_asc_id_asc_idx ON public.txs_7 USING btree (time_stamp, id);


--
-- Name: txs_7_time_stamp_desc_id_desc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_7_time_stamp_desc_id_desc_idx ON public.txs_7 USING btree (time_stamp DESC, id DESC);


--
-- Name: txs_7_time_stamp_desc_id_desc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_7_amount_asset_price_asset_time_stamp_id_partial_idx ON public.txs_7 USING btree (amount_asset, price_asset, time_stamp, id) WHERE ((sender)::text = '3PJaDyprvekvPXPuAtxrapacuDJopgJRaU3'::text);


--
-- Name: txs_7_time_stamp_id_partial_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_7_time_stamp_id_partial_idx ON public.txs_7 USING btree (time_stamp, id) WHERE ((sender)::text = '3PJaDyprvekvPXPuAtxrapacuDJopgJRaU3'::text);


--
-- Name: txs_8_height_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_8_height_idx ON public.txs_8 USING btree (height);


--
-- Name: txs_8_recipient_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_8_recipient_idx ON public.txs_8 USING btree (recipient);


--
-- Name: txs_8_sender_time_stamp_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_8_sender_time_stamp_id_idx ON public.txs_8 USING btree (sender, time_stamp, id);


--
-- Name: txs_8_time_stamp_asc_id_asc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_8_time_stamp_asc_id_asc_idx ON public.txs_8 USING btree (time_stamp, id);


--
-- Name: txs_8_time_stamp_desc_id_asc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_8_time_stamp_desc_id_asc_idx ON public.txs_8 USING btree (time_stamp DESC, id);


--
-- Name: txs_8_time_stamp_desc_id_desc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_8_time_stamp_desc_id_desc_idx ON public.txs_8 USING btree (time_stamp DESC, id DESC);


--
-- Name: txs_9_height_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_9_height_idx ON public.txs_9 USING btree (height);


--
-- Name: txs_9_lease_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_9_lease_id_idx ON public.txs_9 USING hash (lease_id);


--
-- Name: txs_9_sender_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_9_sender_idx ON public.txs_9 USING hash (sender);


--
-- Name: txs_9_time_stamp_asc_id_asc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_9_time_stamp_asc_id_asc_idx ON public.txs_9 USING btree (time_stamp, id);


--
-- Name: txs_9_time_stamp_desc_id_asc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_9_time_stamp_desc_id_asc_idx ON public.txs_9 USING btree (time_stamp DESC, id);


--
-- Name: txs_9_time_stamp_desc_id_desc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX txs_9_time_stamp_desc_id_desc_idx ON public.txs_9 USING btree (time_stamp DESC, id DESC);


--
-- Name: blocks_raw block_delete; Type: RULE; Schema: public; Owner: -
--

CREATE RULE block_delete AS
    ON DELETE TO public.blocks_raw DO  DELETE FROM public.blocks
  WHERE (blocks.height = old.height);


--
-- Name: blocks_raw block_insert_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER block_insert_trigger BEFORE INSERT ON public.blocks_raw FOR EACH ROW EXECUTE PROCEDURE public.on_block_insert();


--
-- Name: blocks_raw block_update_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER block_update_trigger BEFORE UPDATE ON public.blocks_raw FOR EACH ROW EXECUTE PROCEDURE public.on_block_update();


--
-- Name: txs_1 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_1
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_2 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_2
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_3 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_3
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_4 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_4
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_5 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_5
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_6 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_6
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_7 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_7
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_8 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_8
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_9 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_9
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_10 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_10
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_11 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_11
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_13 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_13
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_14 fk_blocks; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_14
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_11_transfers fk_tx_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_11_transfers
    ADD CONSTRAINT fk_tx_id FOREIGN KEY (tx_id) REFERENCES public.txs_11(id) ON DELETE CASCADE;


--
-- Name: txs_12_data txs_12_data_tx_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_12_data
    ADD CONSTRAINT txs_12_data_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES public.txs_12(id) ON DELETE CASCADE;


--
-- Name: txs_12 txs_12_height_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_12
    ADD CONSTRAINT txs_12_height_fkey FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_15 txs_15_blocks_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_15
    ADD CONSTRAINT txs_15_blocks_fk FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_16_args txs_16_args_tx_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_16_args
    ADD CONSTRAINT txs_16_args_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES public.txs_16(id) ON DELETE CASCADE;


--
-- Name: txs_16 txs_16_blocks_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_16
    ADD CONSTRAINT txs_16_blocks_fk FOREIGN KEY (height) REFERENCES public.blocks(height) ON DELETE CASCADE;


--
-- Name: txs_16_payment txs_16_payment_tx_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.txs_16_payment
    ADD CONSTRAINT txs_16_payment_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES public.txs_16(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

