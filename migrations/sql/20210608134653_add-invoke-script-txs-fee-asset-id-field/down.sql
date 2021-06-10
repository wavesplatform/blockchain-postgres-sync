CREATE OR REPLACE FUNCTION insert_txs_16(b jsonb) RETURNS void
    language plpgsql
AS
$$
BEGIN
	INSERT INTO txs_16 (
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
	SELECT
		-- common
		(t->>'height')::int4,
		(t->>'type')::smallint,
		t->>'id',
		to_timestamp((t ->> 'timestamp') :: DOUBLE PRECISION / 1000),
		t->>'signature',
		jsonb_array_cast_text(t->'proofs'),
		(t->>'version')::smallint,
		(t->>'fee')::bigint,
		coalesce(t->>'applicationStatus', 'succeeded'),
		-- with sender
		t->>'sender',
		t->>'senderPublicKey',
		-- type specific
		t->>'dApp',
	    t->'call'->>'function'
	FROM (
		SELECT jsonb_array_elements(b->'transactions') || jsonb_build_object('height', b->'height') AS t
	) AS txs
	WHERE (t->>'type') = '16'
	ON CONFLICT DO NOTHING;

	INSERT INTO txs_16_args (
		tx_id,
		arg_type,
		arg_value_integer,
		arg_value_boolean,
		arg_value_binary,
		arg_value_string,
	    arg_value_list,
		position_in_args
	)
	SELECT
		arg->>'tx_id' AS tx_id,
		arg->>'type' AS arg_type,
		CASE WHEN arg->>'type' = 'integer'
			THEN (arg->>'value')::bigint
			ELSE NULL
		END AS arg_value_integer,
		CASE WHEN arg->>'type' = 'boolean'
			THEN (arg->>'value')::boolean
			ELSE NULL
		END AS arg_value_boolean,
		CASE WHEN arg->>'type' = 'binary'
			THEN arg->>'value'
			ELSE NULL
		END AS arg_value_binary,
		CASE WHEN arg->>'type' = 'string'
			THEN arg->>'value'
			ELSE NULL
		END AS arg_value_string,
		CASE WHEN arg->>'type' = 'list'
			THEN arg->'value'
			ELSE NULL
		END AS arg_value_list,
		row_number() OVER (PARTITION BY arg->>'tx_id') - 1 AS position_in_args
	FROM (
		SELECT jsonb_array_elements(tx->'call'->'args') || jsonb_build_object('tx_id', tx->>'id') AS arg
			FROM (
				SELECT jsonb_array_elements(b->'transactions') AS tx
			) AS txs
			WHERE (tx->>'type') = '16'
	) AS data
	ON CONFLICT DO NOTHING;

	INSERT INTO txs_16_payment (
		tx_id,
		amount,
		asset_id,
		position_in_payment
	)
	SELECT
		p->>'tx_id' AS tx_id,
		(p->>'amount')::bigint AS amount,
		p->>'assetId' AS asset_id,
		row_number() OVER (PARTITION BY p->>'tx_id') - 1 AS position_in_payment
	FROM (
		SELECT jsonb_array_elements(tx->'payment') || jsonb_build_object('tx_id', tx->>'id') AS p
			FROM (
				SELECT jsonb_array_elements(b->'transactions') AS tx
			) AS txs
			WHERE (tx->>'type') = '16'
	) AS data
	ON CONFLICT DO NOTHING;
END
$$;

ALTER FUNCTION insert_txs_16(jsonb) OWNER TO dba;

ALTER TABLE txs_16 DROP COLUMN fee_asset_id;
