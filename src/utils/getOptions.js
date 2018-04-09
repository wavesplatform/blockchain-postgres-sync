const YAML = require('yamljs');
const path = require('path');

module.exports = () => {
  let config;
  try {
    config = YAML.load(path.join(__dirname, '../../config.yml'));
  } catch (err) {
    // eslint-disable-next-line
    console.error(err);
  }
  return config;
};
