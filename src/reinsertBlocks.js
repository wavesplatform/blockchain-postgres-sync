const createDb = require('./db/create');
const getOptions = require('./utils/getOptions');

const launch = async () => {
  const startHeight = parseInt(process.argv[2]);
  const endHeight = parseInt(process.argv[3]);
  // by default step is 1000 blocks
  const blocksPerReinsert = parseInt(process.argv[4]) || 1000;

  if (isNaN(startHeight) || isNaN(endHeight))
    throw new Error(
      'No height range provided. Please provide explicit block range, i.e. `yarn download 1 100000`.'
    );

  const db = createDb(getOptions());

  for (let i = startHeight; i < endHeight; i += blocksPerReinsert) {
    await db.any('select reinsert_range($1, $2);', [
      i,
      i + blocksPerReinsert - 1,
    ]);

    console.log(`Batch ${i}—${i + blocksPerReparse - 1} reinserted`);
  }
};

launch();