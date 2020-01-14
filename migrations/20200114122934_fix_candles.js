const fs = require("fs");

const upSqlFilePath = "./migrations/sql/20200114122934_fix_candles/up.sql";
const downSqlFilePath = "./migrations/sql/20200114122934_fix_candles/down.sql";

exports.up = knex => knex.schema.raw(fs.readFileSync(upSqlFilePath, "utf8"));

exports.down = knex =>
  knex.schema.raw(fs.readFileSync(downSqlFilePath, "utf8"));
