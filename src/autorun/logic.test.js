const { autorun } = require('./logic');

const getOptions = require('../utils/getOptions');

describe('Autorun', () => {
  const options = getOptions();
  const ar = autorun(options);

  const createRequestHeightMock = values => {
    const f = jest.fn();
    const valuesP = values.map(v => Promise.resolve(v));
    valuesP.forEach(v => f.mockReturnValueOnce(v));
    f.mockReturnValue(valuesP[valuesP.length - 1]);
    return f;
  };

  const assertRunCallWith = (runMock, ranges) => {
    expect(runMock).toHaveBeenCalledTimes(ranges.length);
    ranges.forEach(([start, end], index) => {
      expect(runMock.mock.calls[index][0][0]).toEqual(start);
      expect(
        end -
          runMock.mock.calls[index][0][runMock.mock.calls[index][0].length - 1]
      ).toBeLessThan(100);
    });
  };

  describe('should call run N times and then update on H blockchain height', () => {
    it('N = 1, H = 10000', async () => {
      const requestDbHeight = createRequestHeightMock([null, 10000]);
      const requestApiHeight = createRequestHeightMock([10000, 10000]);
      const run = jest.fn(() => Promise.resolve(null));
      const update = jest.fn();

      await ar({ requestDbHeight, requestApiHeight, run, update });

      expect(requestDbHeight).toHaveBeenCalledTimes(2);
      expect(requestApiHeight).toHaveBeenCalledTimes(2);
      assertRunCallWith(run, [[1, 10000]]);
      expect(update).toHaveBeenCalledTimes(1);
    });

    it('N = 3, H = 10060/10060/10061', async () => {
      const requestDbHeight = createRequestHeightMock([null, 10000, 10060]);
      const requestApiHeight = createRequestHeightMock([10060, 10060, 10061]);
      const run = jest.fn(() => Promise.resolve(null));
      const update = jest.fn();

      await ar({ requestDbHeight, requestApiHeight, run, update });

      expect(requestDbHeight).toHaveBeenCalledTimes(3);
      expect(requestApiHeight).toHaveBeenCalledTimes(3);
      assertRunCallWith(run, [[1, 10000], [10001, 10060]]);
      expect(update).toHaveBeenCalledTimes(1);
    });
  });
});
