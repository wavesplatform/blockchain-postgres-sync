CREATE TABLE IF NOT EXISTS txs_3 (
    fee bigint NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    asset_id varchar NOT NULL,
    asset_name varchar NOT NULL,
    description varchar NOT NULL,
    quantity bigint NOT NULL,
    decimals smallint NOT NULL,
    reissuable bool NOT NULL,
    PRIMARY KEY (id)
		-- FOREIGN KEY (height) REFERENCES blocks (height) ON DELETE CASCADE)
)
  INHERITS (
    txs
);

