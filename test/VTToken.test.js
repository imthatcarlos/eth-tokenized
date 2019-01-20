const util = require('ethereumjs-util');

const VTToken = artifacts.require('./VTToken.sol');

const { shouldFail } = require('./../node_modules/openzeppelin-solidity/test/helpers/shouldFail');
const time = require('./../node_modules/openzeppelin-solidity/test/helpers/time');
const BigNumber = require('bignumber.js');

const VALUE_PER_TOKEN_USD_CENTS = 10;

const VALUE_USD = 100000; // let them all be 100k by default

/**
 * Create instance of contracts
 */
async function setupTokenContract() {
  const name = "BMW 2019";
  const cap = VALUE_USD; // USD : tokenCap are 1:1
  const annualizedROI = 15; // 15%
  const timeframeDays = 365 // need to be days to properly calculate profits

  return await VTToken.new(name, VALUE_USD, cap, annualizedROI, timeframeDays, VALUE_PER_TOKEN_USD_CENTS);
}

contract('VTToken', (accounts) => {
  describe('constructor()', () => {
    it('initializes storage variables', async() => {
      var token = await setupTokenContract();
      var cap = await token.cap();

      assert.equal(cap.toNumber(), VALUE_USD, 'storage initialized');
    });
  });
});
