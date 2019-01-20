const util = require('ethereumjs-util');

const VTToken = artifacts.require('./VTToken.sol');

const { shouldFail } = require('./../node_modules/openzeppelin-solidity/test/helpers/shouldFail');
// const { expectEvent } = require('./../node_modules/openzeppelin-solidity/test/helpers/expectEvent');
const time = require('./../node_modules/openzeppelin-solidity/test/helpers/time');
const BigNumber = require('bignumber.js');

const ASSET_NAME = "BMW 2019";
const VALUE_PER_TOKEN_USD_CENTS = 10;
const VALUE_USD = 100000; // let them all be 100k by default
const CAP = VALUE_USD / VALUE_PER_TOKEN_USD_CENTS;
const ANNUALIZED_ROI = 15; // %

/**
 * Create instance of contracts
 */
async function setupTokenContract(timeframeMonths = 12) {
  return await VTToken.new(ASSET_NAME, VALUE_USD, CAP, ANNUALIZED_ROI, timeframeMonths, VALUE_PER_TOKEN_USD_CENTS);
}

contract('VTToken', (accounts) => {
  describe('constructor()', () => {
    it('initializes storage variables', async() => {
      var token = await setupTokenContract();
      var cap = await token.cap();

      assert.equal(cap.toNumber(), VALUE_USD, 'storage initialized');
    });
  });

  // describe('getProjectedProfit()', () => {
  //   it('calculates the profit of the asset to the second', async() => {
  //     var token = await setupTokenContract();
  //     await token.mint(accounts[0], CAP / 10);
  //
  //     const balance = await token.balanceOf(accounts[0]);
  //
  //     var projected = (balance / 10**18) + (VALUE_USD * ANNUALIZED_ROI) // projected profit for 12 months
  //     console.log(projected);
  //
  //     const calculated = await token.getProjectedProfit({ from: accounts[0] });
  //     console.log(calculated);
  //
  //     assert.equal(projected, calculated.toNumber(), 'storage initialized');
  //   });
  // });
});
