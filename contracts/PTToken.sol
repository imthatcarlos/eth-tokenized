pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./ERC223.sol";
import "./TToken.sol";

/**
 * @title PTToken
 * This token contract represents an investment in a basket of Assets, or VTToken contracts
 *
 * @author Carlos Beltran <imthatcarlos@gmail.com>
 */
contract PTToken is ERC20Burnable, ERC20Mintable, ERC223 {
  using SafeMath for uint;

  uint public decimals = 18;  // allows us to divide and retain decimals
}
