pragma solidity ^0.5.5;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol"; // need for tests

/**
 * @title StableToken
 * @author Carlos Beltran <imthatcarlos@gmail.com>
 */
contract StableToken is ERC20Mintable {
  string public name = "StableToken";
  string public symbol = "STL";
  uint public decimals = 18;
}
