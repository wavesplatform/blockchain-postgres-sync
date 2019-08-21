const createDb = require('../db/create');

const createRequestDbHeight = require('../db/requestHeight');
const createRequestApiHeight = require('../api/requestHeight');
const run = require('../run');
const { update } = require('../updateComposite');

const getOptions = require('./getOptionsEnv');

const { autorun } = require('./logic');

const launch = () => {
  const options = getOptions();
  const db = createDb(options);
  const requestDbHeight = () => createRequestDbHeight(db);
  const requestApiHeight = () => createRequestApiHeight(options);
  return autorun(options)({
    requestDbHeight,
    requestApiHeight,
    run,
    update: () => update(options),
  });
};

launch();
