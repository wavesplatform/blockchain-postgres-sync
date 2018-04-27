const throttle = require('throttle-debounce/throttle');

const run = require('./run');
const getOptions = require('./utils/getOptions');

const requestHeight = require('./api/requestHeight');

const options = getOptions();

const launchIter = async () => {
  const height = await requestHeight(options);

  const batches = [height - options.blocksPerUpdate + 1];

  return run(batches, {
    ...options,
    blocksPerRequest: options.blocksPerUpdate,
  });
};

const launchRecursiveThrottled = throttle(options.updateThrottleInterval, () =>
  launchIter()
    .then(() => console.log('Finished update', new Date()))
    .then(() => launchRecursiveThrottled())
    .catch(error => {
      console.log('Failed update', new Date());
      console.error(error);
    })
);

launchRecursiveThrottled();
