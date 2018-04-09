CREATE TABLE IF NOT EXISTS txs (
    height integer NOT NULL,
    tx_type smallint NOT NULL,
    id varchar NOT NULL,
    time_stamp timestamp NOT NULL,
    signature varchar, -- can be signature or proofs array
    proofs varchar [ ],
		tx_version smallint,
    PRIMARY KEY (id)
    -- FOREIGN KEY (height) REFERENCES blocks (height) ON DELETE CASCADE
);

