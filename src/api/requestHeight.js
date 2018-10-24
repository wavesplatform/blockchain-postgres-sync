const request = require('superagent');
const { USER_AGENT } = require('./constants');

const requestHeight = options =>
  request
    .get(`${options.nodeAddress}/blocks/height`)
    .set('User-Agent', USER_AGENT)
    .retry(2)
    .then(r => r.body.height);

module.exports = requestHeight;
