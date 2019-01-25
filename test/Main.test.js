const util = require('ethereumjs-util');

const VTToken = artifacts.require('./VTToken.sol');
const TToken = artifacts.require('./TToken.sol');
const Main = artifacts.require('./Main.sol');

const shouldFail = require('./helpers/shouldFail');
const increaseTime = require('./helpers/increaseTime');
const BigNumber = require('bignumber.js');

const ASSET_NAME = "BMW 2019";
const VALUE_PER_TOKEN_USD_CENTS = 10;
const VALUE_USD = 100000; // let them all be 100k by default
const CAP = VALUE_USD / VALUE_PER_TOKEN_USD_CENTS; // token cap (not in BigNumber format)
const ANNUALIZED_ROI = 15; // %
const TIMEFRAME_MONTHS = 12;

let stableToken;
let main;
let assetData;
let assetToken;

async function setupMainContract(contractOwner) {
  return await Main.new(stableToken.address, { from: contractOwner} );
}

function calculateProjectedProfit(value = VALUE_USD, timeframeMonths = 12) {
  return (value * (ANNUALIZED_ROI / 100)) * (timeframeMonths / 12);
}

async function addAsset(assetOwner) {
  await main.addAsset(
    assetOwner,
    ASSET_NAME,
    VALUE_USD,
    web3.utils.toWei(CAP.toString(), 'ether'), // BigNumber format
    ANNUALIZED_ROI,
    (VALUE_USD + calculateProjectedProfit()),
    TIMEFRAME_MONTHS,
    VALUE_PER_TOKEN_USD_CENTS
  );
}

async function fundAsset(assetOwner) {
  const amnt = web3.utils.toWei((VALUE_USD + calculateProjectedProfit()).toString(), 'ether');
  await stableToken.mint(assetOwner, amnt);
  await stableToken.approve(main.address, amnt, { from: assetOwner});
  await main.fundAsset(amnt, 1, { from: assetOwner });
}

contract('Main', (accounts) => {
  before(async ()=> {
    stableToken = await TToken.new();
    main = await setupMainContract(accounts[0]);
  });

  describe('constructor()', () => {
    it('initializes storage variables', async() => {
      assert.equal(await main.owner(), accounts[0] , 'storage initialized');
    });
  });

  describe('investVehicle()', () => {
    before(async() => {
      await addAsset(accounts[2]);
      assetData = await main.getAssetById(1);
      assetToken = await VTToken.at(assetData.tokenAddress);
    });

    it('reverts when trying to invest more T tokens than there are VT tokens', async() => {
      const cap = web3.utils.fromWei(await assetToken.cap());
      const investingStable = cap * VALUE_PER_TOKEN_USD_CENTS;
      const investingTokens = web3.utils.toWei(investingStable.toString(), 'ether')

      await shouldFail.reverting(main.investVehicle((investingTokens + 1), assetData.tokenAddress, { from: accounts[3] }));
    });

    it('reverts when the sender does not have T tokens', async() => {
      const cap = web3.utils.fromWei(await assetToken.cap());
      const investingStable = cap * VALUE_PER_TOKEN_USD_CENTS;
      const investingTokens = web3.utils.toWei(investingStable.toString(), 'ether')

      await shouldFail.reverting(main.investVehicle(investingTokens, assetData.tokenAddress, { from: accounts[3] }));
    });

    it('allows the sender to invest in an asset and receive VT tokens', async() => {
      const cap = web3.utils.fromWei(await assetToken.cap());
      const investingStable = cap * VALUE_PER_TOKEN_USD_CENTS;
      const investingTokens = web3.utils.toWei(investingStable.toString(), 'ether')

      // user acquires T tokens
      await stableToken.mint(accounts[3], investingTokens);

      // user approves transfer of T tokens
      await stableToken.approve(main.address, investingTokens, { from: accounts[3] })

      // user invests T tokens
      await main.investVehicle(investingTokens, assetData.tokenAddress, { from: accounts[3] });

      // user now has VT tokens
      const token = await VTToken.at(assetData.tokenAddress);
      const b = await token.balanceOf(accounts[3]);
      assert.equal(web3.utils.fromWei(b.toString()), CAP);

      // Main contract now has T tokens
      const b2 = await stableToken.balanceOf(main.address);
      assert.equal(web3.utils.fromWei(b2.toString()), investingStable);

      // investment record created
      const record = await main.getInvestmentById(1);
      assert.equal(record.owner, accounts[3], 'record added to storage');
    });
  });
});
