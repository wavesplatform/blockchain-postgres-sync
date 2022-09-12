SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

create index if not exists txs_1_block_uid_idx on  txs_1   (block_uid);
create index if not exists txs_2_block_uid_idx on  txs_2   (block_uid);
create index if not exists txs_3_block_uid_idx on  txs_3   (block_uid);
create index if not exists txs_4_block_uid_idx on  txs_4   (block_uid);
create index if not exists txs_5_block_uid_idx on  txs_5   (block_uid);
create index if not exists txs_6_block_uid_idx on  txs_6   (block_uid);
create index if not exists txs_7_block_uid_idx on  txs_7   (block_uid);
create index if not exists txs_8_block_uid_idx on  txs_8   (block_uid);
create index if not exists txs_9_block_uid_idx on  txs_9   (block_uid);
create index if not exists txs_10_block_uid_idx on txs_10  (block_uid);
create index if not exists txs_11_block_uid_idx on txs_11  (block_uid);
create index if not exists txs_12_block_uid_idx on txs_12  (block_uid);
create index if not exists txs_13_block_uid_idx on txs_13  (block_uid);
create index if not exists txs_14_block_uid_idx on txs_14  (block_uid);
create index if not exists txs_15_block_uid_idx on txs_15  (block_uid);
create index if not exists txs_16_block_uid_idx on txs_16  (block_uid);
create index if not exists txs_17_block_uid_idx on txs_17  (block_uid);
create index if not exists txs_18_block_uid_idx on txs_18  (block_uid);

create index if not exists  txs_1_id_idx on txs_1  using hash (id);
create index if not exists  txs_2_id_idx on txs_2  using hash (id);
create index if not exists  txs_3_id_idx on txs_3  using hash (id);
create index if not exists  txs_4_id_idx on txs_4  using hash (id);
create index if not exists  txs_5_id_idx on txs_5  using hash (id);
create index if not exists  txs_6_id_idx on txs_6  using hash (id);
create index if not exists  txs_7_id_idx on txs_7  using hash (id);
create index if not exists  txs_8_id_idx on txs_8  using hash (id);
create index if not exists  txs_9_id_idx on txs_9  using hash (id);
create index if not exists txs_10_id_idx on txs_10 using hash (id);
create index if not exists txs_11_id_idx on txs_11 using hash (id);
create index if not exists txs_12_id_idx on txs_12 using hash (id);
create index if not exists txs_13_id_idx on txs_13 using hash (id);
create index if not exists txs_14_id_idx on txs_14 using hash (id);
create index if not exists txs_15_id_idx on txs_15 using hash (id);
create index if not exists txs_16_id_idx on txs_16 using hash (id);
create index if not exists txs_17_id_idx on txs_17 using hash (id);
create index if not exists txs_18_id_idx on txs_18 using hash (id);
