const fs = require("fs");

const upSqlFilePath = "./migrations/sql/20200728210521_set-data-entry-type-nullable/up.sql";
const downSqlFilePath = "./migrations/sql/20200728210521_set-data-entry-type-nullable/down.sql";

exports.up = knex => knex.schema.raw(fs.readFileSync(upSqlFilePath, "utf8"));

exports.down = knex =>
  knex.schema.raw(fs.readFileSync(downSqlFilePath, "utf8"));
