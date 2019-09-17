const fs = require('fs');

const upSqlFilePath = './migrations/sql/initial_schema.up.sql';
const downSqlFilePath = './migrations/sql/initial_schema.down.sql';

exports.up = knex => knex.schema.raw(fs.readFileSync(upSqlFilePath, 'utf8'));

exports.down = knex =>
  knex.schema.raw(fs.readFileSync(downSqlFilePath, 'utf8'));
