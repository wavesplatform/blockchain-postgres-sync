const request = require('superagent');
const jsonBigint = require('json-bigint')({ storeAsString: true });

const bigIntParse = (res, fn) => {
  res.text = '';
  res.setEncoding('utf8');
  res.on('data', chunk => (res.text += chunk));
  res.on('end', err => fn(err, jsonBigint.parse(res.text)));
};

const requestBlocksBatch = (start, options) =>
  request
    .get(
      `${options.nodeAddress}/blocks/seq/${start}/${start +
        options.blocksPerRequest -
        1}`
    )
    .retry(2)
    .buffer(true)
    .parse(bigIntParse)
    .then(r => r.body);

module.exports = requestBlocksBatch;
