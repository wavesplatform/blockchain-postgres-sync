const { version } = require('../../package.json');

const USER_AGENT = `blockchain-postgres-sync/${version}`;

module.exports = {
  USER_AGENT,
};
