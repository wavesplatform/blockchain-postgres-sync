const fs = require("fs");

const upSqlFilePath =
  "./migrations/sql/20191018100006_issue_txs_indexing/up.sql";
const downSqlFilePath =
  "./migrations/sql/20191018100006_issue_txs_indexing/down.sql";

exports.up = knex => knex.schema.raw(fs.readFileSync(upSqlFilePath, "utf8"));

exports.down = knex =>
  knex.schema.raw(fs.readFileSync(downSqlFilePath, "utf8"));
