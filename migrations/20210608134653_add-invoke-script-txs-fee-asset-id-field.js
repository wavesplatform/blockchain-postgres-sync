const fs = require("fs");

const upSqlFilePath = "./migrations/sql/20210608134653_add-invoke-script-txs-fee-asset-id-field/up.sql";
const downSqlFilePath = "./migrations/sql/20210608134653_add-invoke-script-txs-fee-asset-id-field/down.sql";

exports.up = knex => knex.schema.raw(fs.readFileSync(upSqlFilePath, "utf8"));

exports.down = knex =>
  knex.schema.raw(fs.readFileSync(downSqlFilePath, "utf8"));
