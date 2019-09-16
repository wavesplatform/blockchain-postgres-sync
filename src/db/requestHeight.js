module.exports = db =>
  db
    .oneOrNone('select height from blocks_raw order by height desc limit 1')
    .then(v => (v === null ? v : v.height));
