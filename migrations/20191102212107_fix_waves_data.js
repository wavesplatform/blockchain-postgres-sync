const fs = require("fs");

const upSqlFilePath = "./migrations/sql/20191102212107_fix_waves_data/up.sql";
const downSqlFilePath =
  "./migrations/sql/20191102212107_fix_waves_data/down.sql";

exports.up = knex => knex.schema.raw(fs.readFileSync(upSqlFilePath, "utf8"));

exports.down = knex =>
  knex.schema.raw(fs.readFileSync(downSqlFilePath, "utf8"));
