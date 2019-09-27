exports.up = knex => {
  knex.schema
    .withSchema("public")
    .table("txs_13", table => {
      table.index("md5((script)::text)", "txs_13_md5_script_idx", "btree");
    })
    .table("txs_15", table => {
      table.index("md5((script)::text)", "txs_15_md5_script_idx", "btree");
    });
};

exports.down = knex =>
  knex.schema
    .withSchema("public")
    .table("txs_13", table => table.dropIndex(null, "txs_13_md5_script_idx"))
    .table("txs_15", table => table.dropIndex(null, "txs_15_md5_script_idx"));
