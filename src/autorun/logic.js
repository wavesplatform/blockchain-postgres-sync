const createRequestHeights = require('../utils/createRequestHeights');

const BLOCKS_PER_ITER = 10000;
const BLOCKS_CLOSE_ENOUGH_FOR_UPDATE_START = 50;

const autorun = options => ({
  requestDbHeight,
  requestApiHeight,
  run,
  update,
}) => {
  const loop = () =>
    Promise.all([requestDbHeight, requestApiHeight].map(f => f())).then(
      ([dbHeight, apiHeight]) => {
        const startHeight = (dbHeight || 0) + 1;
        const endHeight = Math.min(
          startHeight + BLOCKS_PER_ITER - 1,
          apiHeight
        );

        if (endHeight - startHeight > BLOCKS_CLOSE_ENOUGH_FOR_UPDATE_START) {
          const batches = createRequestHeights(
            startHeight,
            endHeight,
            options.blocksPerRequest
          );

          return run(batches, options).then(loop);
        } else {
          update();
        }
      }
    );

  return loop();
};

module.exports = { autorun };
