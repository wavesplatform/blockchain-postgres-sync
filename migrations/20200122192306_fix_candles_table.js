const fs = require("fs");

const upSqlFilePath = "./migrations/sql/20200122192306_fix_candles_table/up.sql";
const downSqlFilePath = "./migrations/sql/20200122192306_fix_candles_table/down.sql";

exports.up = knex => knex.schema.raw(fs.readFileSync(upSqlFilePath, "utf8"));

exports.down = knex =>
  knex.schema.raw(fs.readFileSync(downSqlFilePath, "utf8"));
