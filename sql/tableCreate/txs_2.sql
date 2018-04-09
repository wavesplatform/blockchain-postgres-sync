CREATE TABLE IF NOT EXISTS txs_2 (
    fee bigint NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    recipient varchar NOT NULL,
    amount bigint NOT NULL,
    PRIMARY KEY (id,
      time_stamp)
)
    -- FOREIGN KEY (height) REFERENCES blocks (height) ON DELETE CASCADE)
  INHERITS (
    txs
);

