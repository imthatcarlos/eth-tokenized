pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Capped.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./ERC223.sol";
import "./TToken.sol";

/**
 * @title VTToken
 * This token contract represents a particular vehicle asset, and tokens are minted for
 * accounts as they invest in them.
 * NOTE: all numbers (except timeframeMonths and annualizedROI) will have 18 decimal places to allow more
 *       precision when dividing. when reading such values from this contract, clients
 *       should use `web3.utils.fromWei(number)`
 * NOTE: we don't divide the annualizedROI by 100 (precision) so the client must do so after calls to
 *       getCurrentProfit() and getProjectedProfit()
 *
 * @author Carlos Beltran <imthatcarlos@gmail.com>
 */
contract VTToken is ERC20Burnable, ERC20Capped, ERC223 {
  using SafeMath for uint;

  uint public decimals = 18;  // allows us to divide and retain decimals

  uint private MONTHS_PER_YEAR = 12;
  uint private DAYS_PER_YEAR = 365;
  uint private SECONDS_PER_DAY = 86400;

  address payable public assetOwner;   // address of the asset owner
  string public name;                  // might want to define a standard, ex: MAKE MODEL YEAR
  uint public valueUSD;                // initial USD value of the asset
  uint public annualizedROI;           // percentage value
  uint public projectedValueUSD;       // projected USD value of the asset
  uint public createdAt;               // datetime when contract was created
  uint public timeframeMonths;         // timeframe to be sold (months)
  uint public valuePerTokenCents;

  TToken private stableToken;

  // mapping(address => uint) mintedAtTimestamps; // lets us track when tokens were minted for which address

  modifier activeInvestment() {
    require(balanceOf(msg.sender) != 0, "must have an active investment in this asset");
    _;
  }

  /**
   * Contract constructor
   * Instantiates an instance of a VT token contract with specific properties for the asset
   * @param _assetOwner Address of asset owner
   * @param _stableTokenAddress Address of T token
   * @param _name Name of the asset
   * @param _valueUSD Value of the asset in USD
   * @param _cap token cap == _valueUSD / _valuePerTokenUSD
   * @param _annualizedROI AROI %
   * @param _projectedValueUSD The PROJECTED value of the asset in USD
   * @param _timeframeMonths Time frame for the investment
   * @param _valuePerTokenCents Value of each token
   */
  constructor(
    address payable _assetOwner,
    address _stableTokenAddress,
    string memory _name,
    uint _valueUSD,
    uint _cap,
    uint _annualizedROI,
    uint _projectedValueUSD,
    uint _timeframeMonths,
    uint _valuePerTokenCents
  ) public ERC20Capped(_cap) {
    name = _name;
    valueUSD = _valueUSD;
    annualizedROI = _annualizedROI;
    projectedValueUSD = _projectedValueUSD;
    createdAt = block.timestamp; // solium-disable-line security/no-block-members, whitespace
    timeframeMonths = _timeframeMonths;
    valuePerTokenCents = _valuePerTokenCents;
    stableToken = TToken(_stableTokenAddress);
    assetOwner = _assetOwner;
  }

  /**
   * Do not accept ETH
   */
  function() external payable {
    require(msg.value == 0, "not accepting ETH");
  }

  /**
   * Calculates and returns the current profit (to the second) of the sender account's tokens
   * NOTE: we calculate the proft from the second the contract was created, NOT when the tokens have been
   * minted -> createdAt might need to become mintedAtTimestamps[msg.sender] and assigned in Main#investVehicle
   */
  function getCurrentProfit() public view activeInvestment returns(uint) {
    uint amountTokens = balanceOf(msg.sender);
    uint perSec = calculateProfitPerSecond(amountTokens);
    return perSec.mul(block.timestamp - createdAt);
  }

  /**
   * Calculates and returns the projected profit of the sender account's tokens
   */
  function getProjectedProfit() public view activeInvestment returns(uint) {
    uint amountTokens = balanceOf(msg.sender);
    uint yearly = calculateProfitYearly(amountTokens);
    uint monthly = yearly.div(MONTHS_PER_YEAR);

    return monthly.mul(timeframeMonths);
  }

  /**
   * Allows a token holder to claim their profits once this contract has been funded
   * NOTE: hacky: we don't require this contract to have enough T tokens to cover claims, we mint any T tokens we need
   * Burns the sender's VT tokens
   */
  function claimFundsAndBurn() public activeInvestment {
    // sanity check - make sure we're funded
    // require(stableToken.balanceOf(address(this)) > 0);

    // hacky: if this contract has not been sufficiently funded, mint T tokens to cover the investor's claim
    uint investorClaim = getCurrentProfit();
    uint stableBalance = stableToken.balanceOf(address(this));
    if (stableBalance < investorClaim) {
      stableToken.mint(address(this), investorClaim.sub(stableBalance));
    }

    // transfer T tokens to the investor equal to the current profit
    // NOTE: we are assuming there is no ceiling to the possible profit, meaning not greater than getProjectedProfit()
    require(stableToken.transfer(msg.sender, investorClaim));

    // burn their tokens
    burn(balanceOf(msg.sender));

    if (totalSupply() == 0) {
      // if everyone has claimed their profits, we should have 0 supply of tokens
      uint balanceStable = stableToken.balanceOf(address(this));

      // and we have some T tokens remaining (most likely a tiny fraction < 1) send them to the asset owner
      if (balanceStable > 0) {
        require(stableToken.transfer(assetOwner, balanceStable));
      }

      // and terminate the contract, sending any remaining ETH to the asset owner
      selfdestruct(assetOwner);
    }
  }

  /**
   * Calculates profit per second - based on yearly
   * NOTE this uses DAYS_PER_YEAR which should be mofifiable for leap years
   * @param _amountTokens Number of tokens held
   */
  function calculateProfitPerSecond(uint _amountTokens) internal view returns(uint) {
    uint yearly = calculateProfitYearly(_amountTokens);
    uint daily = yearly.div(DAYS_PER_YEAR);
    uint perSec = daily.div(SECONDS_PER_DAY); // we shouldn't lose precision with

    return perSec;
  }

  /**
   * Calculates yearly profit of holding tokens for this asset
   * NOTE: we don't divide the annualizedROI by 100 here (precision) so the client must do so
   * @param _amountTokens Number of tokens held
   */
  function calculateProfitYearly(uint _amountTokens) internal view returns(uint) {
    return _amountTokens.mul(annualizedROI).div(100);
  }
}
