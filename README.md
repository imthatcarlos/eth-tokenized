# [eth-tokenized]

A collection of smart contracts that enable assets to be represented by an ERC20 token contract that users can then
invest in with a stable token.

These contracts make use of the [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-solidity) library for secure
smart contracts, specifically standard functionality for ERC20 tokens and contract management (ownership/state). I would
recommend using ZeppelinOS(https://zeppelinos.org/) to make the production contracts upgradable.

This project uses the [Truffle](https://github.com/trufflesuite/truffle) framework to compile, debug, and deploy
contracts. The configuration file `truffle.js` is configured to deploy contracts to a specified network, and using
[Infura](https://infura.io/) to deploy to Ropsten and Main networks.

Developer Notes:
- `VTToken` and `PTToken` inherited from ERC223 contract for the `tokenFallback()` function in the overridden
`transfer()`. However, when transferring to user wallets, this function failed. So the inheritance was removed. Both
contracts still fully inherit from ERC20 for standard functionality as well as for minting and burning.
- To mitigate the heavy computations done on-chain, some functions from `Array256Lib.sol` contract were copied
over, including `_sumElements()` and `_getMin()`. These heavy computations could be done off-chain using the getter
methods provided, however it could risk invalid values being submitted.
- `Main.sol` contract is the most bloated and expensive to deploy. This could be mitigated by decoupling the logic
for Portfolio investing, especially `investPortfolio()` as it is the most expensive operation (iterating all VT over
  all contracts, reading, and computing). Logic was bundled into this contract to avoid extra read expenses.
- Most number values fed into contract functions _must_ be sent as `BigNumber` values. See tests for examples, but
generally is done like so: `web3.utils.toWei(number.toString(), 'ether')`
- Assets data can be updated by the contract owner via `editAsset()` on `AssetRegistry`, however the token cap is
derived from the initial `_valueUSD / _valuePerTokenUSD`, so there will have to be some balancing if we want to
preserve correct calculations. An idea is to pump the value of `_valuePerTokenUSD` to match the new `_valueUSD` with
the same cap, however this is situational (?)


### Setup
Clone the repo and run `npm install`

You will need Truffle installed globally `npm install truffle -g`

Finally, install a geth client like [Ganache](https://github.com/trufflesuite/ganache-cli) `npm install ganache-cli -g`

### Contracts interface
Read the docs for the 4 smart contracts:
- [Main](docs/contracts/Main.md)
- [AssetRegistry](docs/contracts/AssetRegistry.md)
- [VTToken](docs/contracts/VTToken.md)
- [PTToken](docs/contracts/PTToken.md)

### Compile
```bash
truffle compile
```

### Run tests
```bash
truffle test
```

That should yield:
```
Using network 'development'.


Contract: AssetRegistry
  addAsset()
    ✓ adds the asset to storage (126ms)
    ✓ creates an instance of VT token contract
    ✓ calls Main contract addFillableAsset(), increasing its storage count and updating the min value
  editAsset()
    ✓ reverts if the sender is not the contract owner (not to be confused with the asset owner) (46ms)
    ✓ updates storage (105ms)
  fundAsset()
    ✓ reverts if the sender does not own the given asset
    ✓ reverts if the sender does not have enough T tokens to cover the projectedValueUSD (40ms)
    ✓ reverts if the sender has not approved the transfer of T tokens before funding (75ms)
    ✓ sets storage variable funded to true (126ms)

Contract: Main
  constructor()
    ✓ initializes storage variables
  investVehicle()
    ✓ reverts when trying to invest more T tokens than there are VT tokens (75ms)
    ✓ reverts when the sender does not have T tokens (111ms)
    ✓ allows the sender to invest in an asset and receive VT tokens (261ms)
    ✓ calls setAssetFilled() in AssetRegistry when the asset is fully filled
    ✓ does NOT call setAssetFilled() in AssetRegistry when the asset is NOT fully filled (300ms)
    ✓ off the last test, it does update minFillableAmount on Main
  investPortfolio()
    ✓ reverts when there are no assets to invest in
    context: happy path of evenly invested assets
      ✓ mints an equal amount of PT tokens as T tokens invested (242ms)
      ✓ invests those T tokens into the respective VT contracts, evenly
      ✓ updates the lookup of fillable assets count to 0
      ✓ updates the filled state of both assets
      ✓ mints VT tokens for the PT contract (39ms)
      ✓ adds the investment to PT contract investments lookup
      context: when more assets are added
        ✓ distributes T tokens correctly (314ms)
        ✓ logs an equal allowance on all 3 VT contracts (47ms)
    context: un-even investments, all tokens with same cap
      ✓ invests T tokens appropriately by filling one while investing in others evenly (499ms)

Contract: PTToken
  addInvestment()
    ✓ reverts if the investor does not have PT tokens
    ✓ reverts if the contract does not have the specified VT tokens (69ms)
    ✓ adds the investment to lookup table
  claimFundsAndBurn()
    context: only one investor
      ✓ gets correct data from getCurrentOwnershipPercentage()
      ✓ gets correct data from calculateTotalProjectedValueOwned()
      ✓ gets correct data from calculateTotalCurrentValueOwned() (38ms)
      ✓ reverts when the sender does not have PT tokens
      ✓ reverts when the sender has less PT tokens than they attempt to redeem (43ms)
      ✓ transfers VT tokens to the investor proportionate to their PT ownership (111ms)
      ✓ burns the investor's PT tokens
      ✓ updates the investment lookup table

Contract: VTToken
  constructor()
    ✓ initializes storage variables (77ms)
  getProjectedProfit()
    ✓ reverts if the caller does not have an investment (86ms)
    ✓ calculates the projected profit given the number of tokens the investor owns (128ms)
  getCurrentProfit()
    ✓ reverts if the caller does not have an investment (83ms)
    ✓ calculates the profit the investor would receive if they cashed out now (141ms)
  getCurrentValuePortfolio()
    ✓ reverts if the caller does not have an investment (86ms)
    ✓ calculates the total value of the asset + its current profit (183ms)
  claimFundsAndBurn()
    ✓ reverts if the caller does not have an investment (42ms)
    ✓ does NOT call selfdestruct when there are tokens left to redeem (267ms)
    context: HACKY
      ✓ transfers profit T tokens to the investor and burns their VT tokens - HACKY (177ms)
      ✓ calls selfdestruct() when there are no tokens left (everyone has claimed their funds)


48 passing (10s)
```

### Migrate to your local blockchain
Make sure you run `ganache-cli` in one terminal
```bash
truffle migrate
```
