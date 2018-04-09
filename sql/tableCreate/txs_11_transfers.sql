CREATE TABLE IF NOT EXISTS txs_11_transfers (
    tx_id varchar NOT NULL,
    recipient varchar NOT NULL,
    amount bigint NOT NULL
    -- FOREIGN KEY (tx_id) REFERENCES txs_11 (id) ON DELETE CASCADE
);

