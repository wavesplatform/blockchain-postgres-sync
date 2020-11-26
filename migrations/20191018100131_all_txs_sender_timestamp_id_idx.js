const fs = require("fs");

const upSqlFilePath =
  "./migrations/sql/20191018100131_all_txs_sender_timestamp_id_idx/up.sql";
const downSqlFilePath =
  "./migrations/sql/20191018100131_all_txs_sender_timestamp_id_idx/down.sql";

exports.up = knex => knex.schema.raw(fs.readFileSync(upSqlFilePath, "utf8"));

exports.down = knex =>
  knex.schema.raw(fs.readFileSync(downSqlFilePath, "utf8"));
