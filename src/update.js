const run = require('./run');
const getOptions = require('./utils/getOptions');

const requestHeight = require('./api/requestHeight');

const launchIter = async () => {
  const options = getOptions();

  const height = await requestHeight(options);

  const batches = [height - options.blocksPerUpdate + 1];

  return run(batches, {
    ...options,
    blocksPerRequest: options.blocksPerUpdate,
  });
};

const launchRecursive = () =>
  launchIter()
    .then(() => console.log('Finished update', new Date()))
    .then(() => launchRecursive())
    .catch(error => {
      console.log('Failed update', new Date());
      console.error(error);
    });

launchRecursive();
