CREATE TABLE IF NOT EXISTS txs_18
(
    payload BYTEA NOT NULL,

    PRIMARY KEY (uid),
    CONSTRAINT fk_blocks FOREIGN KEY (height) REFERENCES blocks_microblocks(height) ON DELETE CASCADE
) INHERITS (txs);