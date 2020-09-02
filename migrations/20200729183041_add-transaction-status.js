const fs = require("fs");

const upSqlFilePath = "./migrations/sql/20200729183041_add-transaction-status/up.sql";
const downSqlFilePath = "./migrations/sql/20200729183041_add-transaction-status/down.sql";

exports.up = knex => knex.schema.raw(fs.readFileSync(upSqlFilePath, "utf8"));

exports.down = knex =>
  knex.schema.raw(fs.readFileSync(downSqlFilePath, "utf8"));
