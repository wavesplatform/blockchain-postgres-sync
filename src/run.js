const requestBlocksBatch = require('./api/requestBlocksBatch');

// init db
const pgp = require('./db/pgp');
const schema = require('./db/schema');
const createDb = require('./db/create');

const transformBlock = b => ({
  height: b.height,
  b,
});

const singleInsert = (q, data) => {
  const insert =
    pgp.helpers.insert(data.map(transformBlock), schema.blocks_raw) +
    ` on conflict on constraint blocks_raw_pkey
		do update set 
			height = excluded.height,
			b = excluded.b
			where blocks_raw.b->>'signature' != excluded.b->>'signature'
	`;

  const timer = `${data[0].height} — ${data[data.length - 1].height} insert, ${
    data.length
  } objects`;

  // console.log(timer + ' started');
  console.time(timer);

  return q.none(insert).then(r => {
    console.timeEnd(timer);
    return r;
  });
};

// run from batches array
const run = async (batches, options) => {
  const db = createDb(options);

  const requestMore = index =>
    index >= batches.length
      ? Promise.resolve(null)
      : requestBlocksBatch(batches[index], options);

  // either do a transaction wita many insert, or one
  // single insert without transaction
  return batches.length > 1
    ? db.tx('massive-insert', t =>
        t.sequence(index =>
          requestMore(index).then(data => {
            if (data && data.length) {
              return singleInsert(t, data);
            }
          })
        )
      )
    : requestMore(0).then(data => singleInsert(db, data));
};

module.exports = run;
