ALTER TABLE txs_1 
   ADD CONSTRAINT fk_blocks
   FOREIGN KEY (height) 
   REFERENCES blocks(height)
	 ON DELETE CASCADE;

ALTER TABLE txs_2
   ADD CONSTRAINT fk_blocks
   FOREIGN KEY (height) 
   REFERENCES blocks(height)
	 ON DELETE CASCADE;

ALTER TABLE txs_3
   ADD CONSTRAINT fk_blocks
   FOREIGN KEY (height) 
   REFERENCES blocks(height)
	 ON DELETE CASCADE;

ALTER TABLE txs_4
   ADD CONSTRAINT fk_blocks
   FOREIGN KEY (height) 
   REFERENCES blocks(height)
	 ON DELETE CASCADE;

ALTER TABLE txs_5
   ADD CONSTRAINT fk_blocks
   FOREIGN KEY (height) 
   REFERENCES blocks(height)
	 ON DELETE CASCADE;

ALTER TABLE txs_6
   ADD CONSTRAINT fk_blocks
   FOREIGN KEY (height) 
   REFERENCES blocks(height)
	 ON DELETE CASCADE;

ALTER TABLE txs_7
   ADD CONSTRAINT fk_blocks
   FOREIGN KEY (height) 
   REFERENCES blocks(height)
	 ON DELETE CASCADE;

ALTER TABLE txs_8
   ADD CONSTRAINT fk_blocks
   FOREIGN KEY (height) 
   REFERENCES blocks(height)
	 ON DELETE CASCADE;

ALTER TABLE txs_9
   ADD CONSTRAINT fk_blocks
   FOREIGN KEY (height) 
   REFERENCES blocks(height)
	 ON DELETE CASCADE;

ALTER TABLE txs_10
   ADD CONSTRAINT fk_blocks
   FOREIGN KEY (height) 
   REFERENCES blocks(height)
	 ON DELETE CASCADE;

ALTER TABLE txs_11
   ADD CONSTRAINT fk_blocks
   FOREIGN KEY (height) 
   REFERENCES blocks(height)
	 ON DELETE CASCADE;