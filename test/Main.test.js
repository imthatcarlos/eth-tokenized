const util = require('ethereumjs-util');

const VTToken = artifacts.require('./VTToken.sol');
const TToken = artifacts.require('./TToken.sol');
const PTToken = artifacts.require('./PTToken.sol');
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
    web3.utils.toWei(CAP.toString(), 'ether'), // BigNumber format
    ANNUALIZED_ROI,
    (VALUE_USD + calculateProjectedProfit()),
    TIMEFRAME_MONTHS,
    VALUE_PER_TOKEN_USD_CENTS,
    { from: assetOwner }
  );
}

async function investVehicle(tokenAddress, investingStable, investor) {
  const investingTokens = web3.utils.toWei(investingStable.toString(), 'ether');
  await stableToken.mint(investor, investingTokens);
  await stableToken.approve(main.address, investingTokens, { from: investor });
  await main.investVehicle(investingTokens, tokenAddress, { from: investor });
}

async function fundAsset(assetOwner) {
  const amnt = web3.utils.toWei((VALUE_USD + calculateProjectedProfit()).toString(), 'ether');
  await stableToken.mint(assetOwner, amnt);
  await stableToken.approve(assetRegistry.address, amnt, { from: assetOwner});
  await assetRegistry.fundAsset(amnt, 1, { from: assetOwner });
}

contract('Main', (accounts) => {
  before(async ()=> {
    stableToken = await TToken.new();
    main = await setupMainContract(accounts[0]);
    assetRegistry = await setupAssetRegistryContract(accounts[0]);
    portfolioToken = await setupPortfolioContract(accounts[0]);

    // give Main contract minting permission
    await portfolioToken.addMinter(main.address, { from: accounts[0] });

    // hacky: give permission for stable token as well
    await stableToken.addMinter(main.address, { from: accounts[0] });
  });

  describe('constructor()', () => {
    it('initializes storage variables', async() => {
      assert.equal(await main.owner(), accounts[0] , 'storage initialized');
    });
  });

  describe('investVehicle()', () => {
    before(async() => {
      await addAsset(accounts[2]);
      assetData = await assetRegistry.getAssetById(1);
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

      // VTToken contract now has T tokens
      const b2 = await stableToken.balanceOf(assetData.tokenAddress);
      assert.equal(web3.utils.fromWei(b2.toString()), investingStable);

      // investment record created
      const record = await main.getInvestmentById(1);
      assert.equal(record.owner, accounts[3], 'record added to storage');
    });

    it('calls setAssetFilled() in AssetRegistry when the asset is fully filled', async() => {
      assetData = await assetRegistry.getAssetById(1);
      assert.equal(assetData.filled, true, 'storage was updated')
    });

    it('does NOT call setAssetFilled() in AssetRegistry when the asset is NOT fully filled', async() => {
      await addAsset(accounts[3]);
      assetData = await assetRegistry.getAssetById(2);

      const cap = web3.utils.fromWei(await assetToken.cap());
      const investingStable = (cap / 2) * VALUE_PER_TOKEN_USD_CENTS; // not filling it
      const investingTokens = web3.utils.toWei(investingStable.toString(), 'ether')
      await stableToken.mint(accounts[4], investingTokens);
      await stableToken.approve(main.address, investingTokens, { from: accounts[4] })
      await main.investVehicle(investingTokens, assetData.tokenAddress, { from: accounts[4] });

      assetData = await assetRegistry.getAssetById(2); // refresh
      assert.equal(assetData.filled, false, 'storage was NOT updated')
    });

    it('off the last test, it does update minFillableAmount on Main', async() => {
      const minVal = await main.minFillableAmount.call();
      assert.equal(web3.utils.fromWei(minVal), (CAP / 2), 'storage was update to the remaining tokens of this asset');
    });
  });

  describe('investPortfolio()', () => {
    before(async() => {
      // refresh contracts
      stableToken = await TToken.new({ from: accounts[0] });
      main = await setupMainContract(accounts[0]);
      assetRegistry = await setupAssetRegistryContract(accounts[0]);
      portfolioToken = await setupPortfolioContract(accounts[0]);
      await portfolioToken.addMinter(main.address, { from: accounts[0] });
      // hacky: give permission for stable token as well
      await stableToken.addMinter(main.address, { from: accounts[0] });
    });

    it('reverts when there are no assets to invest in', async() => {
      const cap = web3.utils.toWei(CAP.toString(), 'ether');
      await shouldFail.reverting(main.investPortfolio(cap, { from: accounts[4] }));
    });

    describe('context: happy path of evenly invested assets', () => {
      before(async() => {
        // now prepare scenarios
        await addAsset(accounts[2]);
        await addAsset(accounts[3]);

        assetData = await assetRegistry.getAssetById(1);
        assetToken = await VTToken.at(assetData.tokenAddress);

        assetData2 = await assetRegistry.getAssetById(2);
        assetToken2 = await VTToken.at(assetData2.tokenAddress);
      });

      it('mints an equal amount of PT tokens as T tokens invested', async() => {
        const cap = web3.utils.fromWei(await assetToken.cap());
        // acquiring total cap of both tokens
        const investingStable = (cap * 2) * VALUE_PER_TOKEN_USD_CENTS;
        const investingTokens = web3.utils.toWei(investingStable.toString(), 'ether');

        await stableToken.mint(accounts[4], investingTokens);
        await stableToken.approve(main.address, investingTokens, { from: accounts[4] });

        await main.investPortfolio(investingTokens, { from: accounts[4], gas: 1200000 });

        const b = await portfolioToken.balanceOf(accounts[4]);
        assert.equal(b, investingTokens, 'user now has PT tokens');
      });

      it('invests those T tokens into the respective VT contracts, evenly', async() => {
        var b = await stableToken.balanceOf(assetData.tokenAddress);
        b = web3.utils.fromWei(b.toString());
        var b2 = await stableToken.balanceOf(assetData2.tokenAddress);
        b2 = web3.utils.fromWei(b2.toString());

        assert.equal(b, VALUE_USD, 'asset has T tokens equal to its total USD value');
        assert.equal(b, b2 , 'assets were invested in evenly');
      });

      it('updates the lookup of fillable assets count to 0', async() => {
        const count = await main.fillableAssetsCount.call();
        assert.equal(count, '0', 'storage was updated');
      });

      it('updates the filled state of both assets', async() => {
        assetData = await assetRegistry.getAssetById(1);
        assetData2 = await assetRegistry.getAssetById(2);

        assert.equal(assetData.filled, true, 'storage was updated');
        assert.equal(assetData2.filled, true, 'storage was updated');
      });

      it('mints VT tokens for the PT contract', async() => {
        var b = await assetToken.balanceOf(portfolioToken.address);
        b = web3.utils.fromWei(b.toString());
        var b2 = await assetToken2.balanceOf(portfolioToken.address);
        b2 = web3.utils.fromWei(b2.toString());

        assert.equal(b, CAP, 'PT contract balance of VT contract 1 is the cap');
        assert.equal(b, b2, 'PT contract has equal balance in both VT contracts');
      });

      describe('context: when more assets are added', () => {
        before(async() => {
          // add new assets
          await addAsset(accounts[4]);
          await addAsset(accounts[5]);
          await addAsset(accounts[6]);

          assetData = await assetRegistry.getAssetById(3);
          assetToken = await VTToken.at(assetData.tokenAddress);

          assetData2 = await assetRegistry.getAssetById(4);
          assetToken2 = await VTToken.at(assetData2.tokenAddress);

          assetData3 = await assetRegistry.getAssetById(5);
          assetToken3 = await VTToken.at(assetData3.tokenAddress);
        });

        it('distributes T tokens correctly', async() => {
          const cap = web3.utils.fromWei(await assetToken.cap());
          // acquiring total cap of one token, to be spread evenly across 3 contracts
          const investingStable = cap * VALUE_PER_TOKEN_USD_CENTS;
          const investingTokens = web3.utils.toWei(investingStable.toString(), 'ether');

          await stableToken.mint(accounts[7], investingTokens);
          await stableToken.approve(main.address, investingTokens, { from: accounts[7] });

          await main.investPortfolio(investingTokens, { from: accounts[7], gas: 1200000 });

          var b = await stableToken.balanceOf(assetData.tokenAddress);
          var b2 = await stableToken.balanceOf(assetData2.tokenAddress);

          assert.equal(parseFloat(web3.utils.fromWei(b).toString()).toFixed(3), (VALUE_USD/3).toFixed(3), 'asset has T tokens equal to a third of its USD value');
          assert.equal(web3.utils.fromWei(b), web3.utils.fromWei(b2) , 'assets were invested in evenly');
        });

        it('logs an equal allowance on all 3 VT contracts', async() => {
          var b = await assetToken.allowance(portfolioToken.address, accounts[7]);
          b = web3.utils.fromWei(b.toString());
          var b2 = await assetToken2.allowance(portfolioToken.address, accounts[7]);
          b2 = web3.utils.fromWei(b2.toString());
          var b3 = await assetToken3.allowance(portfolioToken.address, accounts[7]);
          b3 = web3.utils.fromWei(b3.toString());

          assert.equal(b, b2, 'allowance is the same on all three contracts');
          assert.equal(b3, b3, 'allowance is the same on all three contracts');
        });
      });
    });

    describe('context: un-even investments, all tokens with same cap', () => {
      let assetData4;
      let assetToken4;

      before(async() => {
        // refresh contracts
        stableToken = await TToken.new();
        main = await setupMainContract(accounts[0]);
        assetRegistry = await setupAssetRegistryContract(accounts[0]);
        portfolioToken = await setupPortfolioContract(accounts[0]);
        await portfolioToken.addMinter(main.address, { from: accounts[0] });
        // hacky: give permission for stable token as well
        await stableToken.addMinter(main.address, { from: accounts[0] });

        // now prepare scenario
        await addAsset(accounts[2]);
        await addAsset(accounts[3]);
        await addAsset(accounts[4]);
        await addAsset(accounts[5]);

        assetData = await assetRegistry.getAssetById(1);
        assetToken = await VTToken.at(assetData.tokenAddress);

        assetData2 = await assetRegistry.getAssetById(2);
        assetToken2 = await VTToken.at(assetData2.tokenAddress);

        assetData3 = await assetRegistry.getAssetById(3);
        assetToken3 = await VTToken.at(assetData3.tokenAddress);

        assetData4 = await assetRegistry.getAssetById(4);
        assetToken4 = await VTToken.at(assetData4.tokenAddress);

        // create some prior investments
        const cap = web3.utils.fromWei(await assetToken.cap());
        const investingStable = cap * VALUE_PER_TOKEN_USD_CENTS;
        await investVehicle(assetData.tokenAddress, (investingStable * 0.9), accounts[2]) // Vehicle 1 - 90% full / $100k
        await investVehicle(assetData2.tokenAddress, (investingStable * 0.5), accounts[3]) // Vehicle 2 - 50% full / $100k
        await investVehicle(assetData3.tokenAddress, (investingStable * 0.5), accounts[4]) // Vehicle 3 - 50% full / $100k
        await investVehicle(assetData4.tokenAddress, (investingStable * 0.5), accounts[5]) // Vehicle 4 - 50% full / $100k
      });

      // 4 vehicles
      // Vehicle 1 - 90% full / $100k
      // Vehicles 2-4 50% full / $100k
      //
      // 50k investment
      // $10k would be sent to all vehicles because the fact vehicle one has only $10k left
      // The remaining ($10K) would then be sent evenly again.
      it('invests T tokens appropriately by filling one while investing in others evenly', async() => {
        const cap = web3.utils.fromWei(await assetToken.cap());
        // 50k
        const investingStable = (VALUE_USD * 0.5);
        const investingTokens = web3.utils.toWei(investingStable.toString(), 'ether');

        await stableToken.mint(accounts[6], investingTokens);
        await stableToken.approve(main.address, investingTokens, { from: accounts[6] });

        await main.investPortfolio(investingTokens, { from: accounts[6], gas: 1200000 });

        // Vehicle 1 was fully filled
        assetData = await assetRegistry.getAssetById(1);
        assert.equal(assetData.filled, true, 'asset record was updated');

        // Vehicle 2 is not filled
        assetData2 = await assetRegistry.getAssetById(2);
        assert.equal(assetData2.filled, false, 'asset record was updated');

        // VT contract for Vehicle 1 has T tokens equal to its value
        const b = await stableToken.balanceOf(assetData.tokenAddress);
        assert.equal(web3.utils.fromWei(b), VALUE_USD, 'contract has correct num of T tokens');

        const b2 = await stableToken.balanceOf(assetData2.tokenAddress);
        const evenFill = (VALUE_USD * 0.1); // 10K
        const evenDistrib = ((VALUE_USD * 0.1) / 3); // 10K / 3
        const stable2 = investingStable + evenFill + evenDistrib;

        assert.equal(parseFloat(web3.utils.fromWei(b2).toString()).toFixed(3), stable2.toFixed(3), 'contract has correct num of T tokens');
      });
    });
  });
});
