## AssetRegistry.sol
## is `Ownable`, `Pausable`

This contract manages the functionality for assets - adding records, as well as reading data. It allows users to add assets to the platform, and asset owners to fund their assets once sold.

### Index

- #### addAsset()
- #### editAsset()
- #### fundAsset()
- #### setAssetFilled()
- #### calculateTotalProjectedValue()
- #### calculateTotalCurrentValue()
- #### getAssetIdByToken()
- #### getActiveAssetIds()
- #### getActiveAssetIdsOf()
- #### getAssetsCount()
- #### getAssetById()
----
```
functions with 'hasActiveAsset' or `validAsset` require that the requested
data is valid. those with `onlyAssetOwner` only allow the asset owner to access, and with `onlyOwner` allows only contract owner to call, the one that deployed the contract.
```

#### function addAsset(address payable owner, string calldata \_name, uint \_valueUSD, uint \_cap, uint \_annualizedROI, uint \_projectedValueUSD, uint \_timeframeMonths, uint \_valuePerTokenCents) public
Creates an Asset record and adds it to storage, also creating a VehicleToken contract instance to represent the asset
```
The only contracts that are able to mint tokens for the newly created VT contract are this AssetRegistry contract and the Main contract. If architecture changes, new contracts can
be given minting permission with `addMinter()`
```

#### function editAsset(address payable tokenAddress, uint \_valueUSD, uint \_annualizedROI, uint \_projectedValueUSD, uint \_timeframeMonths, uint \_valuePerTokenCents) public
Allows the contract owner to edit certain data on the token contract
```
we don't allow editing the token cap of the contract as it would jeopardize the validity of lookup records of other contracts (ie: Asset.filled in AssetRegistry)
```

#### function fundAsset(uint \_amountStable, uint \_assetId) public onlyAssetOwner(\_assetId)
Allows an Asset owner to fund the VehicleToken contract with T tokens to be distributed to investors
```
should be called when the asset is sold, and any amount of T tokens sent in should equal the
projected profit. this amount is divided amongst token owners based on the percentage of tokens
they own. these token owners must claim their profit, it will NOT be automatically distributed
to avoid security concerns
```

```
The sender must have approved the transfer of T tokens to this contract by calling
`approve(thisContractAddress, amount)` on the StableToken contract (stable)
```

#### function setAssetFilled(uint \_assetId) public validAsset(\_assetId)
Updates the asset record to filled when fully invested
```
this method may only be called by the Main contract (in _updateAssetLookup())
```

#### function getActiveInvestmentIdsOf() public onlyOwner
Returns the ids of all the given accounts's active investments


#### function calculateTotalProjectedValue() public
Calculates and returns the sum of PROJECTED values of all assets (USD)

#### function calculateTotalCurrentValue() public
Calculates and returns the sum of CURRENT values of all assets (T/USD)

#### function getAssetIdByToken(address \_tokenAddress)
Returns the storage array id of the asset with the given VT contract address

#### function getActiveAssetIds() public hasActiveAsset
Returns the ids of all the sender's active assets

#### function getActiveAssetIdsOf(address \_owner) public onlyOwner
Returns the ids of all the given accounts's active assets

#### function getAssetsCount() public
Returns the number of active assets
```
this value can be incorrect, as we might have gaps in the record list. clients that read from this value must check the validity of an element by making sure the `owner` attribute of the object being read is != address(0)
```

#### function getAssetById(address \_id) public validAsset(\_id)
Returns details of the Asset with the given id
