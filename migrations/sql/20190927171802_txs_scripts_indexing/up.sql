create index txs_13_md5_script_idx on txs_13 using btree (md5((script)::text));
create index txs_15_md5_script_idx on txs_15 using btree (md5((script)::text));