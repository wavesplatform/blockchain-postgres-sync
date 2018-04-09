CREATE TABLE IF NOT EXISTS txs_1 (
    fee bigint NOT NULL,
    recipient varchar NOT NULL,
    amount bigint NOT NULL,
    PRIMARY KEY (id))
    -- FOREIGN KEY (height) REFERENCES blocks (height) ON DELETE CASCADE)
  INHERITS (
    txs
);

