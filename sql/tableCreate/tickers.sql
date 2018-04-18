create table tickers(
	asset_id text primary key,
	ticker text not null,	
 	FOREIGN KEY (asset_id) REFERENCES txs_3 (id) ON DELETE CASCADE
);