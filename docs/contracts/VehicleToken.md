## VehicleToken.sol
## is `ERC20Burnable`, `ERC20Capped`, `Ownable`

This token contract represents a particular vehicle asset, and tokens are minted for accounts as they invest in them.

```
all numbers (except timeframeMonths, annualizedROI, and valuePerTokenCents) will have
18 decimal places to allow more precision when dividing. when reading such values from
this contract, clients should use `web3.utils.fromWei(number)`
```

```
this contract is only Ownable to allow editing certain data by the contract owner, specifically the AssetRegistry
contract, which itself will only be accessible to that contract owner
```

### Index

- #### getCurrentValue()
- #### getCurrentProfit()
- #### getCurrentValuePortfolio()
- #### getProjectedProfit()
- #### claimFundsAndBurn()
- #### editAssetData()

----
```
functions with 'activeInvestment' require that the sender have a balance
of VT tokens greater than 0
```

#### function getCurrentValue() public
Calculates and returns the current value of the asset - including total profit (to the second) - in T tokens

#### function getCurrentValue() public activeInvestment
Calculates and returns the current profit (to the second) in T tokens based on the sender's balance of VT tokens

#### function getCurrentValuePortfolio() public activeInvestment
(PT) Calculates and returns the current value (to the second) of the sender's balance. Similar to the above function but this is a helper for PT calculations

#### function getProjectedProfit() public activeInvestment
Calculates and returns the projected profit of the sender account's tokens

#### function claimFundsAndBurn() public activeInvestment
Allows a token holder to claim their profits once this contract has been funded, and burns their tokens
```
hacky: we don't require the contract to have enough T tokens to
cover claims, we mint any T tokens we need
```
#### function editAssetData(uint \_valueUSD, uint \_annualizedROI, uint \_projectedValueUSD, uint \_timeframeMonths, uint \_valuePerTokenCents) public onlyOwner
Allows the contract owner to edit certain data about the asset
```
can only be called by the contract owner (the AssetRegistry contract)
```
