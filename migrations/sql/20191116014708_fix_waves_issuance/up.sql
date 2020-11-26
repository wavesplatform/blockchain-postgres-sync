CREATE OR REPLACE FUNCTION public.insert_block(b jsonb)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
		insert into waves_data (height, quantity) 
		values ((b->>'height')::integer, coalesce((select quantity from waves_data where height = (b->>'height')::integer - 1), (select quantity from waves_data where height is null)) + (b->>'reward')::bigint) 
		on conflict do nothing;
	end if;
END
$function$
;
