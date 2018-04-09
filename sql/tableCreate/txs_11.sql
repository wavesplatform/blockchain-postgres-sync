CREATE TABLE IF NOT EXISTS txs_11 (
    fee bigint NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id varchar NOT NULL,
    attachment varchar NOT NULL,
    PRIMARY KEY (id))
    -- FOREIGN KEY (height) REFERENCES blocks (height) ON DELETE CASCADE)
  INHERITS (
    txs
);

