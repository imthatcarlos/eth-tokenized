## AssetRegistry.sol
## is `Ownable`, `Pausable`

This contract manages the functionality for assets - adding records, as well as reading data. It allows users to add assets to the platform, and asset owners to fund their assets once sold.

### Index

- #### [addAsset()](#addAsset)
- #### [fundAsset()](#fundAsset)
- #### [setAssetFilled()](setAssetFilled)
- #### [calculateTotalProjectedValue()](calculateTotalProjectedValue)
- #### [calculateTotalCurrentValue()](calculateTotalCurrentValue)
- #### [getAssetIdByToken()](getAssetIdByToken)
- #### [getActiveAssetIds()](getActiveAssetIds)
- #### [getActiveAssetIdsOf()](#getActiveAssetIdsOf)
- #### [getAssetsCount()](#getAssetsCount)
- #### [getAssetById()](#getAssetById)
----
```
functions with 'hasActiveAsset' or `validAsset` require that the requested
data is valid. those with `onlyAssetOwner` only allow the asset owner to access
```

#### function addAsset(address payable owner, string calldata \_name, uint \_valueUSD, uint \_cap, uint \_annualizedROI, uint \_projectedValueUSD, uint \_timeframeMonths, uint \_valuePerTokenCents) public <a name="addAsset"></a>
Creates an Asset record and adds it to storage, also creating a VTToken contract instance to represent the asset
```
The only contracts that are able to mint tokens for the newly created VT contract are this AssetRegistry contract and the Main contract. If architecture changes, new contracts can
be given minting permission with `addMinter()`
```

#### function fundAsset(uint \_amountStable, uint \_assetId) public onlyAssetOwner(\_assetId)<a name="fundAsset"></a>
Allows an Asset owner to fund the VTToken contract with T tokens to be distributed to investors
```
should be called when the asset is sold, and any amount of T tokens sent in should equal the
projected profit. this amount is divided amongst token owners based on the percentage of tokens
they own. these token owners must claim their profit, it will NOT be automatically distributed
to avoid security concerns
```

```
The sender must have approved the transfer of T tokens to this contract by calling
`approve(thisContractAddress, amount)` on the TToken contract (stable)
```

#### function setAssetFilled(uint \_assetId) public validAsset(\_assetId) <a name="getActiveInvestmentIds"></a>
Updates the asset record to filled when fully invested
```
this method may only be called by the Main contract (in _updateAssetLookup())
```

#### function getActiveInvestmentIdsOf() public onlyOwner <a name="getActiveInvestmentIdsOf"></a>
Returns the ids of all the given accounts's active investments


#### function calculateTotalProjectedValue() public <a name="calculateTotalProjectedValue"></a>
Calculates and returns the sum of PROJECTED values of all assets (USD)

#### function calculateTotalCurrentValue() public <a name="calculateTotalCurrentValue"></a>
Calculates and returns the sum of CURRENT values of all assets (T/USD)

#### function getAssetIdByToken(address \_tokenAddress) public <a name="getAssetIdByToken"></a>
Returns the storage array id of the asset with the given VT contract address

#### function getActiveAssetIds() public hasActiveAsset <a name="getActiveAssetIds"></a>
Returns the ids of all the sender's active assets

#### function getActiveAssetIdsOf(address \_owner) public onlyOwner <a name="getActiveAssetIdsOf"></a>
Returns the ids of all the given accounts's active assets

#### function getAssetsCount() public <a name="getAssetsCount"></a>
Returns the number of active assets
```
this value can be incorrect, as we might have gaps in the record list. clients that read from this value must check the validity of an element by making sure the `owner` attribute of the object being read is != address(0)
```

#### function getAssetById(address \_id) public validAsset(\_id) <a name="getAssetById"></a>
Returns details of the Asset with the given id
