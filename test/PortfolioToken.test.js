const util = require('ethereumjs-util');

const VehicleToken = artifacts.require('./VehicleToken.sol');
const StableToken = artifacts.require('./StableToken.sol');
const PortfolioToken = artifacts.require('./PortfolioToken.sol');
const Main = artifacts.require('./Main.sol');
const AssetRegistry = artifacts.require('./AssetRegistry.sol')

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
let portfolioToken;
let main;
let assetRegistry;

let assetData;
let assetToken;
let assetData2;
let assetToken2;
let assetData3;
let assetToken3;

async function setupMainContract(contractOwner) {
  return await Main.new(stableToken.address, { from: contractOwner} );
}

async function setupAssetRegistryContract(contractOwner) {
  const contract = await AssetRegistry.new(stableToken.address, main.address, { from: contractOwner } );
  await main.setAssetRegistry(contract.address, { from: contractOwner });
  return contract;
}

async function setupPortfolioContract(contractOwner) {
  const contract = await PortfolioToken.new();
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
    web3.utils.toWei(VALUE_USD.toString(), 'ether'),
    web3.utils.toWei(CAP.toString(), 'ether'), // BigNumber format
    ANNUALIZED_ROI,
    web3.utils.toWei((VALUE_USD + calculateProjectedProfit()).toString(), 'ether'),
    TIMEFRAME_MONTHS,
    VALUE_PER_TOKEN_USD_CENTS,
    { from: assetOwner }
  );
}

// context: happy path of evenly invested assets
async function investPortfolio(investor) {
  // acquiring total cap of both tokens
  const investingStable = (CAP * 2) * VALUE_PER_TOKEN_USD_CENTS;
  const investingTokens = web3.utils.toWei(investingStable.toString(), 'ether');

  await stableToken.mint(investor, investingTokens);
  await stableToken.approve(main.address, investingTokens, { from: investor });

  await main.investPortfolio(investingTokens, { from: investor, gas: 1500000 });
}

contract('PortfolioToken', (accounts) => {
  describe('addInvestment()', () => {
    before(async ()=> {
      web3.currentProvider.sendAsync = web3.currentProvider.send.bind(web3.currentProvider);

      stableToken = await StableToken.new({ from: accounts[0] });
      main = await setupMainContract(accounts[0]);
      assetRegistry = await setupAssetRegistryContract(accounts[0]);
      portfolioToken = await setupPortfolioContract(accounts[0]);
      await portfolioToken.addMinter(main.address, { from: accounts[0] });
      // hacky: give permission for stable token as well
      await stableToken.addMinter(assetRegistry.address, { from: accounts[0] });
    });

    before(async ()=> {
      await addAsset(accounts[2]);
      assetData = await assetRegistry.getAssetById(1);
      assetToken = await VehicleToken.at(assetData.tokenAddress);
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

  describe('claimFundsAndBurn()', async() => {
    before(async ()=> {
      stableToken = await StableToken.new({ from: accounts[0] });
      main = await setupMainContract(accounts[0]);
      assetRegistry = await setupAssetRegistryContract(accounts[0]);
      portfolioToken = await setupPortfolioContract(accounts[0]);
      await portfolioToken.addMinter(main.address, { from: accounts[0] });
      // hacky: give permission for stable token as well
      await stableToken.addMinter(assetRegistry.address, { from: accounts[0] });
    });

    describe('context: only one investor', () => {
      before(async() => {
        // now prepare scenarios
        await addAsset(accounts[2]);
        await addAsset(accounts[3]);

        assetData = await assetRegistry.getAssetById(1);
        assetToken = await VehicleToken.at(assetData.tokenAddress);

        assetData2 = await assetRegistry.getAssetById(2);
        assetToken2 = await VehicleToken.at(assetData2.tokenAddress);

        // invest in PT
        await investPortfolio(accounts[4]);
      });

      // the three tests below are not used in claimFundsAndBurn() but we want to qualify first anyways
      it('gets correct data from getCurrentOwnershipPercentage()', async() => {
        const data = await portfolioToken.getCurrentOwnershipPercentage({ from: accounts[4] });

        assert.equal(web3.utils.fromWei(data), 100, 'investor owns 100% of PT tokens');
      });

      it('gets correct data from calculateTotalProjectedValueOwned()', async() => {
        var data = await portfolioToken.calculateTotalProjectedValueOwned({ from: accounts[4] });
        data = web3.utils.fromWei(data);
        const total = (VALUE_USD + calculateProjectedProfit()) * 2;
        assert.equal(data, total.toString(), 'correct data');
      });

      it.skip('gets correct data from calculateTotalCurrentValueOwned()', async() => {
        // simulate 12 months having passed
        // NOTE: below will not work if using geth node provided from running `npm run 0x:ganache`
        await increaseTime(web3, 60 * 60 * 24 * 365);

        // if we cashed out one month from now, we should be getting ~ projected / 12
        var value = await portfolioToken.calculateTotalCurrentValueOwned({ from: accounts[4] });
        value = web3.utils.fromWei(value);
        value = Math.round(value) // it's gonna be off by ~0.0000001

        const expected = (VALUE_USD + calculateProjectedProfit()) * 2;
        assert.equal(expected, value, 'correct data');
      });

      it('reverts when the sender does not have PT tokens', async() => {
        await shouldFail.reverting(portfolioToken.claimFundsAndBurn(100, { from: accounts[5] }));
      });

      it('reverts when the sender has less PT tokens than they attempt to redeem', async() => {
        const b = await portfolioToken.balanceOf(accounts[4]);
        const amount = web3.utils.fromWei(b);
        const toClaim = web3.utils.toWei((amount + 100).toString(), 'ether');
        await shouldFail.reverting(portfolioToken.claimFundsAndBurn(toClaim, { from: accounts[4] }));
      });

      it('transfers VT tokens to the investor proportionate to their PT ownership', async() => {
        const b = await portfolioToken.balanceOf(accounts[4]);
        await portfolioToken.claimFundsAndBurn(b.toString(), { from: accounts[4] });

        const tokens = await assetToken.balanceOf(accounts[4]);
        const tokens2 = await assetToken2.balanceOf(accounts[4]);

        assert.equal(web3.utils.fromWei(tokens), web3.utils.fromWei(tokens2), 'equal amount of both VT tokens');
      });

      it('burns the investor\'s PT tokens', async() => {
        const b = await portfolioToken.balanceOf(accounts[4]);
        assert.equal(b, '0', 'investor has no PT tokens left');
      });

      it('updates the investment lookup table', async() => {
        const hasInvestment = await portfolioToken.tokenHasInvestment.call(assetData.tokenAddress);
        const storage = await portfolioToken.tokenInvestments.call(0);

        assert.equal(storage, '0x0000000000000000000000000000000000000000', 'lookup was deleted');
        assert.equal(hasInvestment, false, 'storage lookup was updated');
      });
    });
  });
});
