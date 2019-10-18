CREATE index txs_3_md5_script_idx ON txs_3 USING btree (md5((script)::text));
