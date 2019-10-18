CREATE INDEX txs_13_md5_script_idx ON txs_13 USING btree (md5((script)::text));
CREATE INDEX txs_15_md5_script_idx ON txs_15 USING btree (md5((script)::text));