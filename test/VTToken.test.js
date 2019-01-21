const util = require('ethereumjs-util');

const VTToken = artifacts.require('./VTToken.sol');
const TToken = artifacts.require('./TToken.sol');

const { shouldFail } = require('./../node_modules/openzeppelin-solidity/test/helpers/shouldFail');
// const { expectEvent } = require('./../node_modules/openzeppelin-solidity/test/helpers/expectEvent');
const time = require('./../node_modules/openzeppelin-solidity/test/helpers/time');
const BigNumber = require('bignumber.js');

const ASSET_NAME = "BMW 2019";
const VALUE_PER_TOKEN_USD_CENTS = 10;
const VALUE_USD = 100000; // let them all be 100k by default
const CAP = VALUE_USD / VALUE_PER_TOKEN_USD_CENTS;
const ANNUALIZED_ROI = 15; // %

let stableToken;

/**
 * Create instance of contracts
 */
async function setupTokenContract(assetOwner, timeframeMonths = 12) {
  return await VTToken.new(
    assetOwner,
    stableToken.address,
    ASSET_NAME,
    web3.utils.toWei(VALUE_USD.toString(), 'ether'),
    web3.utils.toWei(CAP.toString(), 'ether'),
    ANNUALIZED_ROI,
    web3.utils.toWei(calculateProjectedProfit(VALUE_USD, timeframeMonths).toString(), 'ether'), // total projected
    timeframeMonths,
    web3.utils.toWei(VALUE_PER_TOKEN_USD_CENTS.toString(), 'ether'),
    { from: assetOwner }
  );
}

function calculateProjectedProfit(value = VALUE_USD, timeframeMonths = 12) {
  return (value * (ANNUALIZED_ROI / 100)) * (timeframeMonths / 12);
}

contract('VTToken', (accounts) => {
  before(async ()=> {
    stableToken = await TToken.new();
  });

  describe('constructor()', () => {
    it('initializes storage variables', async() => {
      var token = await setupTokenContract(accounts[0]);
      var cap = await token.cap();

      assert.equal(web3.utils.fromWei(cap), CAP, 'storage initialized');
    });
  });

  describe('getProjectedProfit()', () => {
    it('calculates the projected profit given the number of tokens the investor owns', async() => {
      var token = await setupTokenContract(accounts[0].toLowerCase());

      const invested = (CAP / 10);
      await token.mint(
        accounts[1].toLowerCase(),
        web3.utils.toWei(invested.toString(), 'ether'),
        { from: accounts[0].toLowerCase() }
      );

      const tokens = await token.balanceOf(accounts[1]);

      // sanity check
      const projected = await token.projectedValueUSD();
      assert.equal(web3.utils.fromWei(projected), calculateProjectedProfit());

      // calculate our projected
      var ours = await token.getProjectedProfit({ from: accounts[1].toLowerCase() });
      ours = web3.utils.fromWei(ours) / 100; // account for ROI%

      assert.equal(ours, calculateProjectedProfit(invested));
    });
  });
});
