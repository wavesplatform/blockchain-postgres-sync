const throttle = require('throttle-debounce/throttle');

const createDb = require('./db/create');
const getOptions = require('./utils/getOptions');

const requestHeight = require('./api/requestHeight');

const options = getOptions();

const launchIter = async () => {
  const db = createDb(options);
  const blockchainHeight = await requestHeight(options);
  const { height: dbHeight } = await db.one(
    'select height from blocks_raw order by height desc limit 1;'
  );

  let deletedHeights = [];
  if (blockchainHeight < dbHeight)
    deletedHeights = await db
      .any('delete from blocks_raw where height >= $1 returning height', [
        blockchainHeight,
      ])
      .then(xs => xs.map(x => x.height));

  return deletedHeights;
};

const launchRecursiveThrottled = throttle(
  options.rollbackMonitorThrottleInterval,
  () =>
    launchIter()
      .then(deletedBs => {
        let logMessage = deletedBs.length
          ? 'ROLLBACK found: deleted blocks ' + deletedBs
          : 'no blocks deleted';
        console.log(`[INFO | ${new Date()}] -- ${logMessage}`);
      })
      .then(() => launchRecursiveThrottled())
      .catch(error => {
        console.log(`[ERROR | ${new Date()}] -- Failed rollback check`);
        console.error(error);
      })
);

launchRecursiveThrottled();
