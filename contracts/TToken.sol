pragma solidity 0.5.0;

import "./ERC223.sol";

/**
 * @title TToken
 * this is the the token that is pegged to USD...
 * @author Carlos Beltran <imthatcarlos>
 */
contract TToken is ERC223 {
  string public name = "T Token";
  string public symbol = "TKN";
  uint public decimals = 18;
}
