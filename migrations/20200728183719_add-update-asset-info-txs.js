const fs = require("fs");

const upSqlFilePath = "./migrations/sql/20200728183719_add-update-asset-info-txs/up.sql";
const downSqlFilePath = "./migrations/sql/20200728183719_add-update-asset-info-txs/down.sql";

exports.up = knex => knex.schema.raw(fs.readFileSync(upSqlFilePath, "utf8"));

exports.down = knex =>
  knex.schema.raw(fs.readFileSync(downSqlFilePath, "utf8"));
