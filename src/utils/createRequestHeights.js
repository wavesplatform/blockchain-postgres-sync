const createRequestHeights = (start, end, step) => {
  const arr = [];
  for (let i = start; i < end; i += step) {
    arr.push(i);
  }
  return arr;
};

module.exports = createRequestHeights;
