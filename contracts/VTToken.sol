pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Capped.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./ERC223.sol";

/**
 * @title VTToken
 * these are tokens that represent a particular vehicle asset
 * TODO: createdAt might need to become mintedAtTimestamps[msg.sender] = time, depending on minting timeline
 * @author Carlos Beltran <imthatcarlos>
 */
contract VTToken is ERC20Burnable, ERC20Capped, ERC223 {
  using SafeMath for uint;

  uint public decimals = 18;  // allows us to divide and retain decimals

  uint private DAYS_PER_YEAR = 365;           // TODO: should include setter function for leap years
  uint private SECONDS_PER_DAY = 86400;
  uint public VALUE_PER_TOKEN_USD_CENTS = 10;

  string public name;           // might want to define a standard, ex: MAKE MODEL YEAR
  uint public valueUSD;         // total USD value of the asset
  uint public annualizedROI;    // percentage value
  uint public createdAt;        // datetime when contract was created
  uint public timeframeMonths;  // timeframe to be sold (months) - might need to be seconds so it's flexible

  // mapping(address => uint) mintedAtTimestamps; // lets us track when tokens were minted for which address

  modifier activeInvestment() {
    require(balanceOf(msg.sender) != 0, "must have an active investment in this asset");
    _;
  }

  /**
   * Contract constructor
   * Instantiates an instance of a Vehicle Token contract with specific properties for the asset
   * NOTE: calling contract should manage the minting
   *
   * @param _name Name of the asset
   * @param _valueUSD Value of the asset in USD
   * @param _cap token cap == _valueUSD / _valuePerTokenUSD
   * @param _annualizedROI AROI %
   * @param _timeframeMonths Time Frame to be sold in months
   */
  constructor(
    string memory _name,
    uint _valueUSD,
    uint _cap,
    uint _annualizedROI,
    uint _timeframeMonths
  ) public ERC20Capped(_cap) {
    name = _name;
    valueUSD = _valueUSD;
    annualizedROI = _annualizedROI;
    createdAt = block.timestamp; // solium-disable-line security/no-block-members, whitespace
    timeframeMonths = _timeframeMonths;
  }

  /**
   * Calculates and returns the current profit (to the second) of the sender account's tokens
   * NOTE: requires that the sender account has an active investment in this asset
   */
  function getCurrentProfit() public view activeInvestment returns(uint) {
    uint balance = balanceOf(msg.sender);
    uint yearly = calculateProfitYearly(balance);
    uint perSec = calculateProfitPerSecond(yearly);
    return balance.add(perSec.mul(block.timestamp - createdAt));
  }

  /**
   * Calculates and returns the projected profit of the sender account's tokens
   * NOTE: requires that the sender account has an active investment in this asset
   */
  function getFutureProfit() public view activeInvestment returns(uint) {
    uint balance = balanceOf(msg.sender);
    uint yearly = calculateProfitYearly(balance);
    return balance.add(yearly); // assuming the timeframe is always 12 months, else we'll have to calculate
  }

  /**
   * Calculates yearly profit of holding tokens for this asset
   * @param _balance Number of tokens held
   */
  function calculateProfitYearly(uint _balance) internal view returns(uint) {
    return (_balance.mul(annualizedROI)).div(100);
  }

  /**
   * Calculates profit per second - based on yearly
   * @param _yearly Yearly profit
   */
  function calculateProfitPerSecond(uint _yearly) internal view returns(uint) {
    uint daily = _yearly.div(DAYS_PER_YEAR);
    return daily.div(SECONDS_PER_DAY);
  }
}
