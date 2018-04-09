const run = require('./run');
const getOptions = require('./utils/getOptions');

const createRequestHeights = require('./utils/createRequestHeights');

const launch = () => {
  const options = getOptions();
  const startHeight = parseInt(process.argv[2]);
  const endHeight = parseInt(process.argv[3]);

  if (isNaN(startHeight) || isNaN(endHeight))
    throw new Error(
      'No height range provided. Please provide explicit block range, i.e. `yarn download 1 100000`.'
    );

  const batches = createRequestHeights(
    startHeight,
    endHeight,
    options.blocksPerRequest
  );

  return run(batches, options);
};

launch()
  .then(data => {
    // COMMIT has been executed
    console.log('Total batches:', data.total, ', Duration:', data.duration);
  })
  .catch(error => {
    // ROLLBACK has been executed
    console.log(error);
  });
