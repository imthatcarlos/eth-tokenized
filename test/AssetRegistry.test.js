const util = require('ethereumjs-util');

const VTToken = artifacts.require('./VTToken.sol');
const TToken = artifacts.require('./TToken.sol');
const AssetRegistry = artifacts.require('./AssetRegistry.sol');

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
let registry;


/**
 * Create instance of contracts
 */
async function setupAssetContract(contractOwner) {
  return await AssetRegistry.new(stableToken.address, { from: contractOwner });
}

function calculateProjectedProfit(value = VALUE_USD, timeframeMonths = 12) {
  return (value * (ANNUALIZED_ROI / 100)) * (timeframeMonths / 12);
}

async function addAsset(assetOwner) {
  await registry.addAsset(
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

contract('AssetRegistry', (accounts) => {
  before(async ()=> {
    stableToken = await TToken.new();
  });

  describe('constructor()', () => {
    it('initializes storage variables', async() => {
      var registry = await setupAssetContract(accounts[0]);

      assert.equal(await registry.owner(), accounts[0] , 'storage initialized');
    });
  });

  describe('addAsset()', () => {
    before(async ()=> {
      registry = await setupAssetContract(accounts[0]);
    });

    it('adds the asset to storage', async() => {
      await addAsset(accounts[3]);

      const count = await registry.getAssetsCount();
      assert.equal(count.toNumber(), '1', 'one record was added to storage');
    });

    it('creates an instance of VT token contract', async() => {
      const asset = await registry.getAssetById(1);
      assert.isNotNull(asset.tokenAddress, 'token contract was created');
    });
  });

  describe('fundAsset()', () => {
    before(async ()=> {
      registry = await setupAssetContract(accounts[0]);
      await addAsset(accounts[3]);
    });

    it('reverts if the sender does not own the given asset', async() => {
      const amnt = web3.utils.toWei(calculateProjectedProfit().toString(), 'ether');
      await shouldFail.reverting(registry.fundAsset(amnt, 1, { from: accounts[1] }));
    });

    it('reverts if the sender does not have enough T tokens to cover the projectedValueUSD', async() => {
      const amnt = web3.utils.toWei(calculateProjectedProfit().toString(), 'ether');
      await shouldFail.reverting(registry.fundAsset(amnt, 1, { from: accounts[3] }));
    });

    it('reverts if the sender has not approved the transfer of T tokens before funding', async() => {
      const amnt = web3.utils.toWei(calculateProjectedProfit().toString(), 'ether');
      stableToken.mint(accounts[3], amnt);

      await shouldFail.reverting(registry.fundAsset(amnt, 1, { from: accounts[3] }));
    });

    it('sets storage variable funded to true', async() => {
      const amnt = web3.utils.toWei((VALUE_USD + calculateProjectedProfit()).toString(), 'ether');
      stableToken.mint(accounts[3], amnt);

      await stableToken.approve(registry.address, amnt, { from: accounts[3]});

      await registry.fundAsset(amnt, 1, { from: accounts[3] });
      const data = await registry.getAssetById(1);
      assert.equal(data.funded, true, 'storage variable updated');
    });
  });
});
