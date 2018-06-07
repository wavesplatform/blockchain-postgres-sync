const request = require('superagent');
const jsonBigint = require('json-bigint')({ storeAsString: true });

const bigIntParse = sanitize => (res, fn) => {
  res.text = '';
  res.setEncoding('utf8');
  res.on('data', chunk => (res.text += chunk));
  res.on('end', err => fn(err, jsonBigint.parse(sanitize(res.text))));
};

// \u0000 in JSON is problematic for PostgreSQL
// removing it from strings
const sanitize = text => text.replace(/\\u0000/g, '');

const requestBlocksBatch = (start, options) =>
  request
    .get(
      `${options.nodeAddress}/blocks/seq/${start}/${start +
        options.blocksPerRequest -
        1}`
    )
    .retry(2)
    .buffer(true)
    .parse(bigIntParse(sanitize))
    .then(r => r.body);

module.exports = requestBlocksBatch;
