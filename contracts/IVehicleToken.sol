pragma solidity ^0.5.5;

/**
 * @title VehicleToken interface
 * @author Carlos Beltran <imthatcarlos@gmail.com>
 */
interface IVehicleToken {
  function editAssetData(uint _valueUSD, uint _annualizedROI, uint _projectedValueUSD, uint _timeframeMonths, uint _valuePerTokenCents) external;
  function getCurrentValue() external view returns(uint);
  function getCurrentProfit() external view returns(uint);
  function getCurrentValuePortfolio() external view returns(uint);
  function getProjectedProfit() external view returns(uint);
  function claimFundsAndBurn() external;

  // compiler-generated getter methods
  function valuePerTokenCents() external view returns(uint value);
  function cap() external view returns(uint value);
  function totalSupply() external view returns(uint value);
  function timeframeMonths() external view returns(uint value);
  function projectedValueUSD() external view returns(uint);

  // openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol
  function mint(address to, uint256 tokenId) external returns (bool);

  // openzeppelin-solidity/contracts/token/ERC20/IERC20.sol
  function balanceOf(address who) external view returns (uint256);
  function transfer(address to, uint256 value) external returns (bool);
}
