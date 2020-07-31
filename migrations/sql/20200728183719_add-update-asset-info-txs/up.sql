create table if not exists txs_17
(
    sender varchar not null,
    sender_public_key varchar not null,
    fee bigint not null,
    asset_id varchar not null,
    asset_name varchar not null,
    description varchar not null,
    constraint txs_17_pk primary key (id),
    constraint txs_17_blocks_fk foreign key (height) references blocks on delete cascade
) inherits (txs);


alter table txs_17 owner to dba;


create index if not exists txs_17_height_idx on txs_17 (height);


create index if not exists txs_17_sender_time_stamp_id_idx on txs_17 (sender, time_stamp, id);


create index if not exists txs_17_asset_id_id_idx on txs_17 (asset_id, id);


create or replace function insert_all(b jsonb) returns void
	language plpgsql
as $$
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
	PERFORM insert_txs_17 (b);
END
$$;


alter function insert_all(jsonb) owner to dba;


create or replace function insert_txs_17(b jsonb) returns void
	language plpgsql
as $$
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
