const request = require('superagent');
const { USER_AGENT } = require('./constants');

const requestHeight = options =>
  request
    .set('User-Agent', USER_AGENT)
    .get(`${options.nodeAddress}/blocks/height`)
    .retry(2)
    .then(r => r.body.height);

module.exports = requestHeight;
