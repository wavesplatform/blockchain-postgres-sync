const fs = require("fs");

const upSqlFilePath = "./migrations/sql/20200729164613_allow-invoke-script-tx-arg-list-typed/up.sql";
const downSqlFilePath = "./migrations/sql/20200729164613_allow-invoke-script-tx-arg-list-typed/down.sql";

exports.up = knex => knex.schema.raw(fs.readFileSync(upSqlFilePath, "utf8"));

exports.down = knex =>
  knex.schema.raw(fs.readFileSync(downSqlFilePath, "utf8"));
