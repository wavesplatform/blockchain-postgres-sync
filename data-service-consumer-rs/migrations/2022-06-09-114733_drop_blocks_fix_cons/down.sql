ALTER TABLE assets_metadata DROP CONSTRAINT asset_meta_pk;

CREATE TABLE IF NOT EXISTS blocks (
    schema_version smallint NOT NULL,
    time_stamp timestamp without time zone NOT NULL,
    reference character varying NOT NULL,
    nxt_consensus_base_target bigint NOT NULL,
    nxt_consensus_generation_signature character varying NOT NULL,
    generator character varying NOT NULL,
    signature character varying NOT NULL,
    fee bigint NOT NULL,
    blocksize integer,
    height integer NOT NULL PRIMARY KEY,
    features smallint[]
);

CREATE TABLE blocks_raw (
    height integer NOT NULL,
    b jsonb NOT NULL
);

ALTER TABLE ONLY txs DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_1 DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_2 DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_3 DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_4 DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_5 DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_6 DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_7 DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_8 DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_9 DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_10 DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_11 DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_11_transfers DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_12 DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_12_data DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_13 DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_14 DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_15 DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_16 DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY txs_16_args DROP CONSTRAINT IF EXISTS fk_blocks;
ALTER TABLE ONLY txs_16_payment DROP CONSTRAINT IF EXISTS fk_blocks;
ALTER TABLE ONLY txs_17 DROP CONSTRAINT fk_blocks;
ALTER TABLE ONLY waves_data DROP CONSTRAINT fk_blocks;

ALTER TABLE ONLY txs
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_1
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_2
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_3
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_4
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_5
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_6
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_7
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_8
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_9
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_10
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_11
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_11_transfers
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_12
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_12_data
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_13
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_14
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_15
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_16
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_16_args
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_16_payment
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY txs_17
    ADD CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
ALTER TABLE ONLY waves_data
    ADD CONSTRAINT fk_waves_data FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;

ALTER TABLE blocks_microblocks DROP CONSTRAINT height_uniq;