const fs = require('fs');

const upSqlFilePath = './migrations/sql/20201126000000_normalization/up.sql';
const downSqlFilePath = './migrations/sql/20201126000000_normalization/down.sql';

exports.up = knex => knex.schema.raw(fs.readFileSync(upSqlFilePath, 'utf8'));

exports.down = knex =>
  knex.schema.raw(fs.readFileSync(downSqlFilePath, 'utf8'));
