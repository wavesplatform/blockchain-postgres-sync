CREATE TABLE IF NOT EXISTS txs_10 (
    fee bigint NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    alias varchar NOT NULL,
    PRIMARY KEY (id))
    -- FOREIGN KEY (height) REFERENCES blocks (height) ON DELETE CASCADE)
  INHERITS (
    txs
);

