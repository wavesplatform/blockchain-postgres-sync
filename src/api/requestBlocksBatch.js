const request = require("superagent");
const { USER_AGENT } = require("./constants");

function unfold(fn, seed) {
  var pair = fn(seed);
  var result = [];
  while (pair && pair.length) {
    result[result.length] = pair[0];
    pair = fn(pair[1]);
  }
  return result;
}

// split {blockData},{blockData},{blockData} to array of {blockData}
// blockData may contain symbols {}, so its need to count
const splitBlocks = s =>
  unfold(cur => {
    let end = -1;
    let c = 1;
    let i = 0;
    let found = false;
    while (i < cur.length && !found) {
      if (cur[i] === "{") c++;
      else if (cur[i] === "}") c--;
      if (c === 1) {
        end = i;
        found = true;
      } else {
        i++;
      }
    }

    if (end === -1) {
      return false;
    } else {
      return [cur.slice(0, end + 1), cur.slice(end + 2)];
    }
  }, s);

const parseBlocks = sanitize => (res, fn) => {
  res.text = "";
  res.setEncoding("utf8");
  res.on("data", chunk => (res.text += chunk));
  res.on("end", err => fn(err, splitBlocks(sanitize(res.text).slice(1, -1))));
};

// \u0000 in JSON is problematic for PostgreSQL
// removing it from strings
const sanitize = text => text.replace(/\\u0000/g, "");

const requestBlocksBatch = (start, options) =>
  request
    .get(
      `${options.nodeAddress}/blocks/seq/${start}/${start +
        options.blocksPerRequest -
        1}`
    )
    .set("User-Agent", USER_AGENT)
    .retry(2)
    .buffer(true)
    .parse(parseBlocks(sanitize))
    .then(r => r.body);

module.exports = requestBlocksBatch;
