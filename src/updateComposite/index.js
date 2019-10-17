const { merge, interval, from, of } = require('rxjs');
const {
  map,
  mapTo,
  bufferTime,
  filter,
  concatMap,
  catchError,
  startWith,
  timeout,
} = require('rxjs/operators');

const run = require('../run');
const requestHeight = require('../api/requestHeight');

const update = options => {
  const launchIter = async blocksPerUpdate => {
    const height = await requestHeight(options);

    const batches = [Math.max(0, height - blocksPerUpdate) + 1];

    return run(batches, {
      ...options,
      blocksPerRequest: blocksPerUpdate,
    });
  };

  /*
@TODO distribute events more evenly. Currently
on a long concatMap events queue in background,
then they get executed quicker than they should
*/

  // Create tick to determine how many blocks to request.
  // Request with more blocks takes priority.
  const max = a => a.reduce((x, y) => Math.max(x, y), -Infinity);
  const min = a => a.reduce((x, y) => Math.min(x, y), Infinity);

  const intervals = options.updateStrategy.map(x => x.interval);
  const bufferInterval = min(intervals) / 2;
  const requestTimeoutInterval = max(intervals);

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
        timeout(requestTimeoutInterval),
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
};

module.exports = {
  update,
};
