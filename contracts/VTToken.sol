pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Capped.sol";
// need to add lockperiod contract!!
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

  uint private MONTHS_PER_YEAR = 12;
  uint private DAYS_PER_YEAR = 365;
  uint private SECONDS_PER_DAY = 86400;

  string public name;                  // might want to define a standard, ex: MAKE MODEL YEAR
  uint public valueUSD;                // total USD value of the asset
  uint public annualizedROI;           // percentage value
  uint public createdAt;               // datetime when contract was created
  uint public timeframeMonths;         // timeframe to be sold (months)
  uint public valuePerTokenCents;      //

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
   * @param _timeframeMonths Time frame for the investment
   */
  constructor(
    string memory _name,
    uint _valueUSD,
    uint _cap,
    uint _annualizedROI,
    uint _timeframeMonths,
    uint _valuePerTokenCents
  ) public ERC20Capped(_cap) {
    name = _name;
    valueUSD = _valueUSD;
    annualizedROI = _annualizedROI;
    createdAt = block.timestamp; // solium-disable-line security/no-block-members, whitespace
    timeframeMonths = _timeframeMonths;
    valuePerTokenCents = _valuePerTokenCents;
  }

  /**
   * Calculates and returns the current profit (to the second) of the sender account's tokens
   */
  function getCurrentProfit() public view activeInvestment returns(uint) {
    uint amountTokens = balanceOf(msg.sender);
    uint perSec = calculateProfitPerSecond(amountTokens);
    return amountTokens.add(perSec.mul(block.timestamp - createdAt));
  }

  /**
   * Calculates and returns the projected profit of the sender account's tokens
   * NOTE: returns numbers with 2 point precision, ex: 1479 => 14.79
   */
  function getProjectedProfit() public view activeInvestment returns(uint) {
    uint amountTokens = balanceOf(msg.sender);
    uint yearly = calculateProfitYearly(amountTokens);
    uint monthly = yearly.div(MONTHS_PER_YEAR);

    return amountTokens.add(monthly.mul(timeframeMonths));
  }

  /**
   * Calculates profit per second - based on yearly
   * NOTE: returns numbers with 2 point precision, ex: 1479 => 14.79
   * @param _amountTokens Number of tokens held
   */
  function calculateProfitPerSecond(uint _amountTokens) internal view returns(uint) {
    // TODO: this is where we lose precision
    uint yearly = calculateProfitYearly(_amountTokens);
    uint daily = yearly.mul(100).div(DAYS_PER_YEAR);
    uint perSec = daily.div(SECONDS_PER_DAY);

    return perSec;
  }

  /**
   * Calculates yearly profit of holding tokens for this asset
   * @param _amountTokens Number of tokens held
   */
  function calculateProfitYearly(uint _amountTokens) internal view returns(uint) {
    return (_amountTokens.mul(annualizedROI)).div(100);
  }
}
