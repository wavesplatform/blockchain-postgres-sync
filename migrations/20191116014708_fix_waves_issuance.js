const fs = require("fs");

const upSqlFilePath = "./migrations/sql/20191116014708_fix_waves_issuance/up.sql";
const downSqlFilePath =
  "./migrations/sql/20191116014708_fix_waves_issuance/down.sql";

exports.up = knex => knex.schema.raw(fs.readFileSync(upSqlFilePath, "utf8"));

exports.down = knex =>
  knex.schema.raw(fs.readFileSync(downSqlFilePath, "utf8"));
