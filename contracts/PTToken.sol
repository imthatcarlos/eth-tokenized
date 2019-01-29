pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./ERC223.sol";
import "./VTToken.sol";

/**
 * @title PTToken
 * This token contract represents an investment in a basket of Assets, or VTToken contracts
 *
 * @author Carlos Beltran <imthatcarlos@gmail.com>
 */
contract PTToken is ERC20Burnable, ERC20Mintable, ERC223 {
  using SafeMath for uint;

  uint public decimals = 18;  // allows us to divide and retain decimals

  function approveFor(
    address payable _tokenAddress,
    address payable _investor,
    uint _amountTokens
  ) public returns(bool) {
    // the investor must have already received PT tokens
    require(balanceOf(_investor) > 0);

    // log an allowance for future ref
    require(VTToken(_tokenAddress).approve(_investor, _amountTokens));

    return true;
  }

  // /**
  //  * Allows a token holder to claim their profits once this contract has been funded
  //  * Burns the sender's PT tokens
  //  */
  // function claimFundsAndBurn() public activeInvestment {
  //   // sanity check - make sure we're funded
  //   require(stableToken.balanceOf(address(this)) > 0);
  //
  //   // transfer T tokens to the investor equal to the current profit
  //   // NOTE: we are assuming there is no ceiling to the possible profit, meaning not greater than getProjectedProfit()
  //   require(stableToken.transfer(msg.sender, getCurrentProfit()));
  //
  //   // burn their tokens
  //   burn(balanceOf(msg.sender));
  //
  //   if (totalSupply() == 0) {
  //     // if everyone has claimed their profits, we should have 0 supply of tokens
  //     uint balanceStable = stableToken.balanceOf(address(this));
  //
  //     // and we have some T tokens remaining (most likely a tiny fraction < 1) send them to the asset owner
  //     if (balanceStable > 0) {
  //       require(stableToken.transfer(assetOwner, balanceStable));
  //     }
  //
  //     // and terminate the contract, sending any remaining ETH to the asset owner
  //     selfdestruct(assetOwner);
  //   }
  // }
}
