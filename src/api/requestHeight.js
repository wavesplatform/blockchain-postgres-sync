const request = require('superagent');

const requestHeight = options =>
  request
    .get(`${options.nodeAddress}/blocks/height`)
    .retry(2)
    .then(r => r.body.height);

module.exports = requestHeight;
