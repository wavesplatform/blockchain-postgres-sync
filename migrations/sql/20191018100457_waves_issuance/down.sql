DROP TABLE waves_data;
DROP INDEX waves_data_height_idx;


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
