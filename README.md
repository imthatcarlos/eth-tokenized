# [eth-tokenized]

A collection of smart contract that enable assets to be represented by ERC20 token contract that users can then invest in with a stable token.

### Setup
Clone the repo and run `npm install`

You will need [Truffle](https://github.com/trufflesuite/truffle) installed globally `npm install truffle -g`

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
```bash
Contract: AssetRegistry
  addAsset()
    ✓ adds the asset to storage (143ms)
    ✓ creates an instance of VT token contract
    ✓ calls Main contract addFillableAsset(), increasing its storage count and updating the min value
  fundAsset()
    ✓ reverts if the sender does not own the given asset (40ms)
    ✓ reverts if the sender does not have enough T tokens to cover the projectedValueUSD (52ms)
    ✓ reverts if the sender has not approved the transfer of T tokens before funding (89ms)
    ✓ sets storage variable funded to true (160ms)

Contract: Main
  constructor()
    ✓ initializes storage variables
  investVehicle()
    ✓ reverts when trying to invest more T tokens than there are VT tokens (82ms)
    ✓ reverts when the sender does not have T tokens (111ms)
    ✓ allows the sender to invest in an asset and receive VT tokens (296ms)
    ✓ calls setAssetFilled() in AssetRegistry when the asset is fully filled
    ✓ does NOT call setAssetFilled() in AssetRegistry when the asset is NOT fully filled (357ms)
    ✓ off the last test, it does update minFillableAmount on Main
  investPortfolio()
    ✓ reverts when there are no assets to invest in
    context: happy path of evenly invested assets
      ✓ mints an equal amount of PT tokens as T tokens invested (300ms)
      ✓ invests those T tokens into the respective VT contracts, evenly
      ✓ updates the lookup of fillable assets count to 0
      ✓ updates the filled state of both assets
      ✓ mints VT tokens for the PT contract
      ✓ adds the investment to PT contract investments lookup
      context: when more assets are added
        ✓ distributes T tokens correctly (393ms)
        ✓ logs an equal allowance on all 3 VT contracts (56ms)
    context: un-even investments, all tokens with same cap
      ✓ invests T tokens appropriately by filling one while investing in others evenly (607ms)

Contract: PTToken
  addInvestment()
    ✓ reverts if the investor does not have PT tokens (38ms)
    ✓ reverts if the contract does not have the specified VT tokens (76ms)
    ✓ adds the investment to lookup table
  claimFundsAndBurn()
    context: only one investor
      ✓ gets correct data from getCurrentOwnershipPercentage()
      ✓ gets correct data from calculateTotalProjectedValueOwned()
      ✓ gets correct data from calculateTotalCurrentValueOwned() (48ms)
      ✓ reverts when the sender does not have PT tokens (41ms)
      ✓ reverts when the sender has less PT tokens than they attempt to redeem (87ms)
      ✓ transfers VT tokens to the investor proportionate to their PT ownership (127ms)
      ✓ burns the investors PT tokens
      ✓ updates the investment lookup table

Contract: VTToken
  constructor()
    ✓ initializes storage variables (120ms)
  getProjectedProfit()
    ✓ reverts if the caller does not have an investment (116ms)
    ✓ calculates the projected profit given the number of tokens the investor owns (179ms)
  getCurrentProfit()
    ✓ reverts if the caller does not have an investment (117ms)
    ✓ calculates the profit the investor would receive if they cashed out now (160ms)
  getCurrentValuePortfolio()
    ✓ reverts if the caller does not have an investment (108ms)
    ✓ calculates the total value of the asset + its current profit (160ms)
  claimFundsAndBurn()
    ✓ reverts if the caller does not have an investment (50ms)
    ✓ does NOT call selfdestruct when there are tokens left to redeem (270ms)
    context: HACKY
      ✓ transfers profit T tokens to the investor and burns their VT tokens - HACKY (192ms)
      ✓ calls selfdestruct() when there are no tokens left (everyone has claimed their funds)


46 passing (13s)
```

### Migrate to your local blockchain
Make sure you run `ganache-cli` in one terminal
```bash
truffle migrate
```
