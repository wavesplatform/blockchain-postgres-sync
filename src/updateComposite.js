const { merge, interval, from, of } = require('rxjs');
const {
  map,
  mapTo,
  bufferTime,
  filter,
  concatMap,
  catchError,
  startWith,
} = require('rxjs/operators');

const getOptions = require('./utils/getOptions');
const run = require('./run');
const requestHeight = require('./api/requestHeight');

const options = getOptions();

const launchIter = async blocksPerUpdate => {
  const height = await requestHeight(options);

  const batches = [height - blocksPerUpdate + 1];

  return run(batches, {
    ...options,
    blocksPerRequest: blocksPerUpdate,
  });
  // .then(() => console.log('Finished update', new Date()))
  // .catch(error => {
  //   console.log('Failed update', new Date());
  //   console.error(error);
  // });
};

// Create tick to determine how many blocks to request.
// Request with more blocks takes priority.
const max = a => a.reduce((x, y) => Math.max(x, y), -Infinity);
const min = a => a.reduce((x, y) => Math.min(x, y), Infinity);

const bufferInterval = min(options.updateStrategy.map(x => x.interval)) / 2;

const tick$ = merge(
  ...options.updateStrategy.map(({ interval: i, blocks }) =>
    interval(i).pipe(
      startWith(0),
      mapTo(blocks)
    )
  )
).pipe(
  bufferTime(bufferInterval),
  map(max),
  filter(x => x > 0)
);

const requests$ = tick$.pipe(
  concatMap(b =>
    from(launchIter(b)).pipe(
      map(() => ({
        type: 'success',
        blocks: b,
        timestamp: new Date(),
      })),
      catchError(error =>
        of({
          type: 'error',
          blocks: b,
          timestamp: new Date(),
          error,
        })
      )
    )
  )
);

const log = e =>
  console.log(
    `${e.type.toUpperCase()} | ${e.timestamp.toISOString()} | ${
      e.blocks
    } blocks`
  );

requests$.subscribe(
  e => {
    log(e);
    if (e.type === 'error') console.error(e.error);
  },
  console.error,
  () => console.log('Stream finished')
);
