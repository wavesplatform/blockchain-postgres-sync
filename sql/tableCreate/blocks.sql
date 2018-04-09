CREATE TABLE IF NOT EXISTS blocks (
    schema_version smallint NOT NULL,
    time_stamp timestamp NOT NULL,
    reference varchar NOT NULL,
    nxt_consensus_base_target bigint NOT NULL,
    nxt_consensus_generation_signature varchar NOT NULL,
    generator varchar NOT NULL,
    signature varchar NOT NULL,
    fee bigint NOT NULL,
		blocksize integer,
    height integer PRIMARY KEY,
    features smallint [ ] -- only in version 3
);

