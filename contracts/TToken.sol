pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol"; // need for tests

/**
 * @title TToken
 * this is the the token that is pegged to USD...
 *
 * @author Carlos Beltran <imthatcarlos@gmail.com>
 */
contract TToken is ERC20Mintable {
  string public name = "T Token";
  string public symbol = "TKN";
  uint public decimals = 18;
}
