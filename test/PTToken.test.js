const util = require('ethereumjs-util');

const VTToken = artifacts.require('./VTToken.sol');
const TToken = artifacts.require('./TToken.sol');
const PTToken = artifacts.require('./PTToken.sol');
const AssetRegistry = artifacts.require('./AssetRegistry.sol');
const Main = artifacts.require('./Main.sol');

const shouldFail = require('./helpers/shouldFail');
const increaseTime = require('./helpers/increaseTime');
const BigNumber = require('bignumber.js');

const ASSET_NAME = "BMW 2019";
const VALUE_PER_TOKEN_USD_CENTS = 10;
const VALUE_USD = 100000; // let them all be 100k by default
const CAP = VALUE_USD / VALUE_PER_TOKEN_USD_CENTS;
const ANNUALIZED_ROI = 15; // %
const TIMEFRAME_MONTHS = 12;

let stableToken;
let assetRegistry;
let portfolioToken;
let main;

/**
 * Create instance of contracts
 */
 async function setupMainContract(contractOwner) {
   return await Main.new(stableToken.address, { from: contractOwner } );
 }

 async function setupAssetRegistryContract(contractOwner) {
   const contract = await AssetRegistry.new(stableToken.address, main.address, { from: contractOwner } );
   await main.setAssetRegistry(contract.address, { from: contractOwner });
   return contract;
 }

 async function setupPortfolioContract(contractOwner) {
   const contract = await PTToken.new(assetRegistry.address, { from: contractOwner });
   await main.setPortfolioToken(contract.address, { from: contractOwner });
   return contract;
 }

function calculateProjectedProfit(value = VALUE_USD, timeframeMonths = 12) {
  return (value * (ANNUALIZED_ROI / 100)) * (timeframeMonths / 12);
}

async function addAsset(assetOwner) {
  await assetRegistry.addAsset(
    assetOwner,
    ASSET_NAME,
    VALUE_USD,
    CAP,
    ANNUALIZED_ROI,
    (VALUE_USD + calculateProjectedProfit()),
    TIMEFRAME_MONTHS,
    VALUE_PER_TOKEN_USD_CENTS
  );
}

async function investVehicle(tokenAddress, investingStable, investor) {
  const investingTokens = web3.utils.toWei(investingStable.toString(), 'ether');
  await stableToken.mint(investor, investingTokens);
  await stableToken.approve(main.address, investingTokens, { from: investor });
  await main.investVehicle(investingTokens, tokenAddress, { from: investor });
}

contract('PTToken', (accounts) => {
  let assetData;
  let assetToken;

  before(async ()=> {
    stableToken = await TToken.new({ from: accounts[0] });
    main = await setupMainContract(accounts[0]);
    assetRegistry = await setupAssetRegistryContract(accounts[0]);
    portfolioToken = await setupPortfolioContract(accounts[0]);
    await portfolioToken.addMinter(main.address, { from: accounts[0] });
    // hacky: give permission for stable token as well
    await stableToken.addMinter(main.address, { from: accounts[0] });
  });

  describe('addInvestment()', () => {
    before(async ()=> {
      await addAsset(accounts[2]);
      assetData = await assetRegistry.getAssetById(1);
      assetToken = await VTToken.at(assetData.tokenAddress);
    });

    it('reverts if the investor does not have PT tokens', async() => {
      await shouldFail.reverting(portfolioToken.addInvestment(assetData.tokenAddress, accounts[3], 100));
    });

    it('reverts if the contract does not have the specified VT tokens', async() => {
      await portfolioToken.mint(accounts[3], 100);
      await shouldFail.reverting(portfolioToken.addInvestment(assetData.tokenAddress, accounts[3], 100));
    });

    it('adds the investment to lookup table', async() => {
      // this test is handled in Main.test.js
    });
  });
});
