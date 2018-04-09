const { ColumnSet } = require('./pgp').helpers;

module.exports.blocks_raw = new ColumnSet(['height', 'b'], {
  table: 'blocks_raw',
});
