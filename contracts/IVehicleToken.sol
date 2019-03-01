pragma solidity 0.5.0;

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
}
