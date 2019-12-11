const checkEnv = require('check-env');

const loadConfig = () => {
  // assert all necessary env vars are set
  checkEnv(['NODE_ADDRESS', 'PGHOST', 'PGDATABASE', 'PGUSER', 'PGPASSWORD']);

  return {
    nodeAddress: process.env.NODE_ADDRESS,

    postgresHost: process.env.PGHOST,
    postgresPort: parseInt(process.env.PGPORT) || 5432,
    postgresDatabase: process.env.PGDATABASE,
    postgresUser: process.env.PGUSER,
    postgresPassword: process.env.PGPASSWORD,
    postgresStatementTimeout: parseInt(process.env.PGSTATEMENTTIMEOUT) || false,

    onConflict: process.env.ON_CONFLICT || 'update',
    blocksPerRequest: parseInt(process.env.BLOCKS_PER_REQUEST) || 100,
    updateThrottleInterval: parseInt(process.env.UPDATE_THROTTLE_INTERVAL) || 500,
    updateStrategy: [
      {
        interval: 1000,
        blocks: 2,
      },
      {
        interval: 60000,
        blocks: 10,
      },
      {
        interval: 600000,
        blocks: 100,
      },
    ],
  };
};

module.exports = loadConfig;
