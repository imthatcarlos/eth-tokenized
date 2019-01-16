pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";
import "./ERC223.sol";

/**
 * @title TToken
 * @author Carlos Beltran <imthatcarlos>
 */
contract TToken is ERC20Mintable, ERC20Burnable, ERC223 {
  string public name = "T Token";
  string public symbol = "TKN";
  uint256 public decimals = 18;
}
