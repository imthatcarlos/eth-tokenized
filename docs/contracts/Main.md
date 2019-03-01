## Main.sol
## is `Ownable`, `Pausable`

This contract manages the main functionality for investments, as well as reading data. It allows users to invest in vehicle assets as well as a portfolio of all available assets.

### Index

- #### addFillableAsset()
- #### investVehicle()
- #### investPortfolio()
- #### getActiveInvestmentIds()
- #### getActiveInvestmentIdsOf()
- #### getInvestmentsCount()
- #### getInvestmentById()
- #### setAssetRegistry()
- #### setPortfolioToken()
----
```
functions with 'hasActiveInvestment' or `validInvestment` require that the requested
data is valid. those with `onlyOwner` only allow the contract owner (the account that
initially deployed) to access
```

#### function investVehicle(uint \_amountStable, address payable \_tokenAddress) public
Allows the sender to invest in an Asset represented by the VehicleToken with the given address, sending their T tokens and receiving VT tokens.
```
The sender must have approved the transfer of T tokens to this contract by calling
`approve(thisContractAddress, amount)` on the TToken contract (stable)
```

#### function investPortfolio(uint \_amountStable) public
Allows the sender to invest in a basket of VT Token contracts
```
The sender must have approved the transfer of T tokens to this contract by calling
`approve(thisContractAddress, amount)` on the TToken contract (stable)
```

#### function getActiveInvestmentIds() public hasActiveInvestment
Returns the ids of all the sender's active assets

#### function getActiveInvestmentIdsOf(address \_owner) public onlyOwner
Returns the ids of all the given accounts's active investments


#### function getInvestmentsCount() public
Returns the number of active investments
```
this value can be incorrect, as we might have gaps in the record list. clients that read from this value must check the validity of an element by making sure the `owner` attribute of the object being read is != address(0)
```

#### function getInvestmentById(uint \_id) public validInvestment(\_id)
Returns details of the Investment with the given id

#### function addFillableAsset(address payable \_tokenAddress, uint \_cap) public
Adds the new asset token contract to our lookup table for PT calculations, and updates helper variables `minFillableAmount` and `fillableAssetsCount`
```
this method can only be called from the AssetRegistry contract (in addAsset())
```

#### function setAssetRegistry(address \_contractAddress) public onlyOwner
Sets this contract's reference to AssetRegistry contract

#### function setPortfolioToken(address \_contractAddress) public onlyOwner
Sets this contract's reference to PortfolioToken contract
