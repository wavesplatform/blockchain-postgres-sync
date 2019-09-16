const YAML = require('yamljs');
const path = require('path');
const fs = require('fs');

const getEnvInt = varName => parseInt(process.env[varName]) || undefined;

module.exports = () => {
  let config;
  try {
    const fileContents = fs.readFileSync(
      path.join(__dirname, '../../config.yml'),
      { encoding: 'utf-8' }
    );
    config = YAML.parse(fileContents);
  } catch (err) {
    // eslint-disable-next-line
    console.error(err);
  }
  return {
    ...config,
    blocksPerRequest:
      getEnvInt('BLOCKS_PER_REQUEST') || config.blocksPerRequest,
    blocksPerUpdate: getEnvInt('BLOCKS_PER_UPDATE') || config.blocksPerUpdate,
    updateThrottleInterval:
      getEnvInt('UPDATE_THROTTLE_INTERVAL') || config.updateThrottleInterval,
    onConflict: process.env.ON_CONFLICT || config.onConflict,
  };
};
