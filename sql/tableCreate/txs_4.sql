CREATE TABLE IF NOT EXISTS txs_4 (
    fee bigint NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id varchar NOT NULL,
    amount bigint NOT NULL,
    recipient varchar NOT NULL,
    fee_asset varchar NOT NULL,
    attachment varchar NOT NULL,
    PRIMARY KEY (id))
    -- FOREIGN KEY (height) REFERENCES blocks (height) ON DELETE CASCADE)
  INHERITS (
    txs
);

