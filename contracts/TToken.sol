pragma solidity 0.5.0;

//import "./ERC223.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

/**
 * @title TToken
 * this is the the token that is pegged to USD...
 * @author Carlos Beltran <imthatcarlos>
 */
contract TToken is ERC20 {
  string public name = "T Token";
  string public symbol = "TKN";
  uint public decimals = 18;
}
