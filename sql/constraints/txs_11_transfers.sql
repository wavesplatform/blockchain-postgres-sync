ALTER TABLE txs_11_transfers
   ADD CONSTRAINT fk_tx_id
	 FOREIGN KEY (tx_id)
	 REFERENCES txs_11 (id)
	 ON DELETE CASCADE;
