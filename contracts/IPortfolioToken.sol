pragma solidity 0.5.0;

/**
 * @title PortfolioToken interface
 * @author Carlos Beltran <imthatcarlos@gmail.com>
 */
interface IPortfolioToken {
  function addInvestment(address payable _tokenAddress, address payable _investor, uint _amountTokens) external returns (bool);
  // function approveFor(address payable _tokenAddress, address payable _investor, uint _amountTokens) external returns(bool);
  function claimFundsAndBurn(uint _amountTokens) external;
  function calculateTotalCurrentValueOwned() external view returns(uint);
  function calculateTotalCurrentValue() external view returns(uint);
  function calculateTotalProjectedValueOwned() external view returns(uint);
  function calculateTotalProjectedValue() external view returns(uint);
  function getCurrentOwnershipPercentage() external view returns(uint);

  // openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol
  function mint(address to, uint256 value) external returns(bool);

  // openzeppelin-solidity/contracts/access/roles/MinterRole.sol
  function addMinter(address account) external;
}
