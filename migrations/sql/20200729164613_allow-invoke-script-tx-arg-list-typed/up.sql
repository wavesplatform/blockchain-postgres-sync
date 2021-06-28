ALTER TABLE txs_16_args ADD COLUMN arg_value_list jsonb DEFAULT NULL;

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
