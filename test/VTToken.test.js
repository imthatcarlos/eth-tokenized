const util = require('ethereumjs-util');

const VTToken = artifacts.require('./VTToken.sol');
const TToken = artifacts.require('./TToken.sol');

const shouldFail = require('./helpers/shouldFail');
const increaseTime = require('./helpers/increaseTime');
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
    web3.currentProvider.sendAsync = web3.currentProvider.send.bind(web3.currentProvider);
  });

  describe('constructor()', () => {
    it('initializes storage variables', async() => {
      var token = await setupTokenContract(accounts[0]);
      var cap = await token.cap();

      assert.equal(web3.utils.fromWei(cap), CAP, 'storage initialized');
    });
  });

  describe('getProjectedProfit()', () => {
    it('reverts if the caller does not have an investment', async() => {
      var token = await setupTokenContract(accounts[0].toLowerCase());
      await shouldFail.reverting(token.getProjectedProfit({ from: accounts[1].toLowerCase() }));
    });

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
      ours = web3.utils.fromWei(ours);

      assert.equal(ours, calculateProjectedProfit(invested));
    });
  });

  describe('getCurrentProfit()', () => {
    it('reverts if the caller does not have an investment', async() => {
      var token = await setupTokenContract(accounts[0].toLowerCase());
      await shouldFail.reverting(token.getCurrentProfit({ from: accounts[1].toLowerCase() }));
    });

    it('calculates the profit the investor would receive if they cashed out now', async() => {
      var token = await setupTokenContract(accounts[0].toLowerCase());

      const invested = (CAP / 10);
      await token.mint(
        accounts[1].toLowerCase(),
        web3.utils.toWei(invested.toString(), 'ether'),
        { from: accounts[0].toLowerCase() }
      );

      // simulate 12 months having passed
      // NOTE: below will not work if using geth node provided from running `npm run 0x:ganache`
      await increaseTime(web3, 60 * 60 * 24 * 365);

      // if we cashed out one month from now, we should be getting ~ projected / 12
      var profit = await token.getCurrentProfit({ from: accounts[1].toLowerCase() });
      profit = web3.utils.fromWei(profit);
      profit = Math.round(profit) // it's gonna be off by ~0.0000001

      assert.equal(profit, calculateProjectedProfit(invested), 'after 12 months, current profit = projected');
    });
  });

  describe('claimFundsAndBurn()', () => {
    let token;
    let invested

    before(async() => {
      token = await setupTokenContract(accounts[0].toLowerCase());
      invested = (CAP / 10); // 10% of total possible
    });

    it('reverts if the caller does not have an investment', async() => {
      await shouldFail.reverting(token.claimFundsAndBurn({ from: accounts[1] }));
    });

    describe('context: HACKY', () => {
      it('transfers profit T tokens to the investor and burns their VT tokens - HACKY', async() => {
        await token.mint(
          accounts[1].toLowerCase(),
          web3.utils.toWei(invested.toString(), 'ether'),
          { from: accounts[0].toLowerCase() }
        );

        // simulate 12 months having passed
        // NOTE: below will not work if using geth node provided from running `npm run 0x:ganache`
        await increaseTime(web3, 60 * 60 * 24 * 365);

        // using getProjectedProfit() as getCurrentProfit() is to the second and not reliable
        // as we are going to mine another block after this
        var profit = await token.getProjectedProfit({ from: accounts[1].toLowerCase() });
        profit = web3.utils.fromWei(profit);
        profit = Math.round(profit) // it's gonna be off by a small fraction, the perSec profit

        // need to fund VT contract with T tokens
        // await stableToken.mint(token.address, web3.utils.toWei(VALUE_USD.toString(), 'ether'));

        // hacky: we do need to give it minting permission (done in Main#addFillableAsset())
        await stableToken.addMinter(token.address, { from: accounts[0] });

        await token.claimFundsAndBurn({ from: accounts[1].toLowerCase() });

        // user now has T tokens
        var balance = await stableToken.balanceOf(accounts[1].toLowerCase());
        balance = web3.utils.fromWei(balance);

        assert.equal(profit, Math.round(balance)); // it's gonna be off by a small fraction, the perSec profit
      });

      it('calls selfdestruct() when there are no tokens left (everyone has claimed their funds)', async() => {
        // storage values are now set to 0 or garbage values
        // we should not be able to read from the contract (web3 issue)
        await shouldFail.invalidValues(token.balanceOf(accounts[1]));
      });
    });

    // describe('context: ORIGINAL', () => {
    //   before(async() => {
    //     // refresh contracts
    //     token = await setupTokenContract(accounts[0].toLowerCase());
    //     stableToken = await TToken.new();
    //   });
    //
    //   // it('reverts if the asset owner has not funded with T tokens', async() => {
    //   //   await token.mint(
    //   //     accounts[1].toLowerCase(),
    //   //     web3.utils.toWei(invested.toString(), 'ether'),
    //   //     { from: accounts[0].toLowerCase() }
    //   //   );
    //   //
    //   //   await shouldFail.reverting(token.claimFundsAndBurn({ from: accounts[1] }));
    //   // });
    //
    //   it('transfers profit T tokens to the investor and burns their VT tokens', async() => {
    //     await token.mint(
    //       accounts[1].toLowerCase(),
    //       web3.utils.toWei(invested.toString(), 'ether'),
    //       { from: accounts[0].toLowerCase() }
    //     );
    //
    //     // simulate 12 months having passed
    //     // NOTE: below will not work if using geth node provided from running `npm run 0x:ganache`
    //     await increaseTime(web3, 60 * 60 * 24 * 365);
    //
    //     // using getProjectedProfit() as getCurrentProfit() is to the second and not reliable
    //     // as we are going to mine another block after this
    //     var profit = await token.getProjectedProfit({ from: accounts[1].toLowerCase() });
    //     profit = web3.utils.fromWei(profit);
    //     profit = Math.round(profit) // it's gonna be off by a small fraction, the perSec profit
    //
    //     // need to fund VT contract with T tokens
    //     await stableToken.mint(token.address, web3.utils.toWei(VALUE_USD.toString(), 'ether'));
    //
    //     // hacky: we do need to give it minting permission (done in Main#addFillableAsset())
    //     // test still passes if contract has funds
    //     // await stableToken.addMinter(token.address, { from: accounts[0] });
    //
    //     await token.claimFundsAndBurn({ from: accounts[1].toLowerCase() });
    //
    //     // user now has T tokens
    //     var balance = await stableToken.balanceOf(accounts[1].toLowerCase());
    //     balance = web3.utils.fromWei(balance);
    //
    //     assert.equal(profit, Math.round(balance)); // it's gonna be off by a small fraction, the perSec profit
    //   });
    //
    //   it('calls selfdestruct() when there are no tokens left (everyone has claimed their funds)', async() => {
    //     // storage values are now set to 0 or garbage values
    //     // we should not be able to read from the contract (web3 issue)
    //     await shouldFail.invalidValues(token.balanceOf(accounts[1]));
    //   });
    // });

    it('does NOT call selfdestruct when there are tokens left to redeem', async() => {
      var token = await setupTokenContract(accounts[0].toLowerCase());
      await token.mint(
        accounts[1].toLowerCase(),
        web3.utils.toWei(invested.toString(), 'ether'),
        { from: accounts[0].toLowerCase() }
      );
      await token.mint( // another investor
        accounts[2].toLowerCase(),
        web3.utils.toWei(invested.toString(), 'ether'),
        { from: accounts[0].toLowerCase() }
      );

      // need to fund VT contract with T tokens
      await stableToken.mint(token.address, web3.utils.toWei(VALUE_USD.toString(), 'ether'));

      // investor 1 claims
      await token.claimFundsAndBurn({ from: accounts[1].toLowerCase() });

      const investorTwoBalance = await token.balanceOf(accounts[2].toLowerCase());

      // we can still read from the contract
      assert.equal(investorTwoBalance, web3.utils.toWei(invested.toString(), 'ether'))
    });
  });
});
