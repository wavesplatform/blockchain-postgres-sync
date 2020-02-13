const requestBlocksBatch = require("./api/requestBlocksBatch");

// init db
const pgp = require("./db/pgp");
const schema = require("./db/schema");
const createDb = require("./db/create");

const singleInsert = ({ onConflict, blocksPerRequest }) => {
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
    nothing: ` on conflict do nothing`
  };

  return (q, data, startHeight) => {
    const insert =
      pgp.helpers.insert(
        data.map((b, i) => ({ height: startHeight + i, b })),
        schema.blocks_raw
      ) + ON_CONFLICT_OPTIONS[onConflict];

    const timer = `${startHeight} — ${startHeight +
      blocksPerRequest -
      1} insert, ${data.length} objects`;
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
    const label = `Requesting blocks ${batches[index]} — ${batches[index] +
      options.blocksPerRequest -
      1}`;
    console.time(label);
    return index >= batches.length
      ? Promise.resolve(null)
      : requestBlocksBatch(batches[index], options).then(r => {
          console.timeEnd(label);
          return r;
        });
  };

  // either do a transaction wita many insert, or one
  // single insert without transaction
  return batches.length > 1
    ? db.tx("massive-insert", t =>
        t.sequence(index =>
          requestMore(index).then(data => {
            if (data && data.length) {
              return insertBatch(t, data, batches[index]);
            }
          })
        )
      )
    : requestMore(0).then(data => insertBatch(db, data, batches[0]));
};

module.exports = run;
