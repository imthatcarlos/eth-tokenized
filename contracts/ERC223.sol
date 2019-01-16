pragma solidity 0.5.0;

import "./ERC223ReceivingContract.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title Reference implementation of the ERC223 standard token.
 * https://github.com/Dexaran/ERC223-token-standard
 */
contract ERC223 {
  using SafeMath for uint;

  event Transfer(address indexed from, address indexed to, uint value, bytes data);

  mapping(address => uint) balances; // declared in ERC20 but we need it in this scope for transfer()

  /**
   * @dev Transfer the specified amount of tokens to the specified address.
   *      Invokes the `tokenFallback` function if the recipient is a contract.
   *      The token transfer fails if the recipient is a contract
   *      but does not implement the `tokenFallback` function
   *      or the fallback function to receive funds.
   *
   * @param _to    Receiver address.
   * @param _value Amount of tokens that will be transferred.
   * @param _data  Transaction metadata.
   */
  function transfer(address _to, uint _value, bytes memory _data) public returns (bool) {
    // Standard function transfer similar to ERC20 transfer with no _data .
    // Added due to backwards compatibility reasons .
    uint codeLength;

    assembly {
        // Retrieve the size of the code on target address, this needs assembly .
        codeLength := extcodesize(_to)
    }

    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);

    if (codeLength > 0) {
        ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
        receiver.tokenFallback(msg.sender, _value, _data);
    }

    emit Transfer(msg.sender, _to, _value, _data);

    return true;
  }

  /**
   * @dev Transfer the specified amount of tokens to the specified address.
   *      This function works the same with the previous one
   *      but doesn't contain `_data` param.
   *      Added due to backwards compatibility reasons.
   *
   * @param _to    Receiver address.
   * @param _value Amount of tokens that will be transferred.
   */
  function transfer(address _to, uint _value) public returns (bool) {
    uint codeLength;
    bytes memory empty;

    assembly {
      // Retrieve the size of the code on target address, this needs assembly .
      codeLength := extcodesize(_to)
    }

    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);

    if (codeLength > 0) {
      ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
      receiver.tokenFallback(msg.sender, _value, empty);
    }

    emit Transfer(msg.sender, _to, _value, empty);

    return true;
  }
}
