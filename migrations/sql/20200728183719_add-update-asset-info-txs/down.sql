drop table txs_17;


drop index txs_17_height_idx;


drop index txs_17_sender_time_stamp_id_idx;


drop index txs_17_asset_id_id_idx;


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
END
$$;


drop function insert_txs_17;
