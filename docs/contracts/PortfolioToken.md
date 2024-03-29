## PortfolioToken.sol
## is `ERC20Burnable`, `ERC20Capped`

This token contract represents a particular vehicle asset, and tokens are minted for accounts as they invest in them.

### Index

- #### addInvestment()
- #### claimFundsAndBurn()
- #### calculateTotalCurrentValueOwned()
- #### calculateTotalCurrentValue()
- #### calculateTotalProjectedValueOwned()
- #### calculateTotalProjectedValue()
- #### getCurrentOwnershipPercentage()
----
```
functions with 'activeInvestment' require that the sender have a balance
of PT tokens greater than 0
```

#### function addInvestment(address payable \_tokenAddress, address payable \_investor, uint \_amountTokens) public
Records an investment in a VT contract
```
Although this function can be called from anyone, we require that the investor specified
has PT tokens and that the balance in VT of this contract is greater than the specified
token amount
```

#### function claimFundsAndBurn(uint \_amountTokens) public activeInvestment
Allows a token holder to burn all or a portion of their PT tokens to receive VT tokens proportionate to the percentage of total PT tokens they own

#### function calculateTotalCurrentValueOwned() public activeInvestment
Calculates the current value (in T) of the sender's PT investment based on this contract's holdings in VT contracts

#### function calculateTotalCurrentValue() public
Calculates the current value (in T) of this contract's holdings in VT contracts

#### function calculateTotalProjectedValueOwned() public activeInvestment
Calculates the PROJECTED value (in T) of the sender's PT investment based on this contract's holdings in VT contracts

#### function calculateTotalProjectedValue() public
Calculates the PROJECTED value (in T) of this contract's holdings in VT contracts

#### function getCurrentOwnershipPercentage() public activeInvestment
Calculates and returns the percentage of total tokens the sender holds
```
we first multiply by 10e20 so to retain precision, and later divide by 10e20 to get
the real value. Clients reading this value should use `web3.utils.fromWei(number)`
```
