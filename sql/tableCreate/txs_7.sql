CREATE TABLE IF NOT EXISTS txs_7 (
    fee bigint NOT NULL,
    sender varchar NOT NULL,
    sender_public_key varchar NOT NULL,
    order1 varchar NOT NULL,
    order2 varchar NOT NULL,
    amount_asset varchar NOT NULL,
    price_asset varchar NOT NULL,
    amount bigint NOT NULL,
    price bigint NOT NULL,
    buy_matcher_fee bigint NOT NULL,
    sell_matcher_fee bigint NOT NULL,
    PRIMARY KEY (id))
		-- FOREIGN KEY (order1) REFERENCES orders (id) ON DELETE RESTRICT,
		-- FOREIGN KEY (order2) REFERENCES orders (id) ON DELETE RESTRICT,
    -- FOREIGN KEY (height) REFERENCES blocks (height) ON DELETE CASCADE)
  INHERITS (
    txs
);

