const requestBlocksBatch = require('./api/requestBlocksBatch');

// init db
const pgp = require('./db/pgp');
const schema = require('./db/schema');
const createDb = require('./db/create');

const transformBlock = b => ({
  height: b.height,
  b,
});

const singleInsert = ({ onConflict }) => {
  const ON_CONFLICT_OPTIONS = {
    update: ` on conflict on constraint blocks_raw_pkey
      do update set 
        height = excluded.height,
        b = excluded.b
        where blocks_raw.b->>'signature' != excluded.b->>'signature'
    `,
    updateForce: ` on conflict on constraint blocks_raw_pkey
      do update set 
        height = excluded.height,
        b = excluded.b;
    `,
    nothing: ` on conflict do nothing`,
  };

  console.log(ON_CONFLICT_OPTIONS[onConflict]);

  return (q, data) => {
    const insert =
      pgp.helpers.insert(data.map(transformBlock), schema.blocks_raw) +
      ON_CONFLICT_OPTIONS[onConflict];

    const timer = `${data[0].height} — ${
      data[data.length - 1].height
    } insert, ${data.length} objects`;

    // console.log(timer + ' started');
    console.time(timer);

    return q.none(insert).then(r => {
      console.timeEnd(timer);
      return r;
    });
  };
};

// run from batches array
const run = async (batches, options) => {
  const db = createDb(options);
  const insertBatch = singleInsert(options);

  const requestMore = index => {
    console.time('Requesting blocks');
    return index >= batches.length
      ? Promise.resolve(null)
      : requestBlocksBatch(batches[index], options).then(r => {
          console.timeEnd('Requesting blocks');
          return r;
        });
  };

  // either do a transaction wita many insert, or one
  // single insert without transaction
  return batches.length > 1
    ? db.tx('massive-insert', t =>
        t.sequence(index =>
          requestMore(index).then(data => {
            if (data && data.length) {
              return insertBatch(t, data);
            }
          })
        )
      )
    : requestMore(0).then(data => insertBatch(db, data));
};

module.exports = run;
