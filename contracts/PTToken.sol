pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./ERC223.sol";
import "./VTToken.sol";
import "./AssetRegistry.sol";

/**
 * @title PTToken
 * This token contract represents an investment in a basket of Assets, or VTToken contracts
 *
 * @author Carlos Beltran <imthatcarlos@gmail.com>
 */
contract PTToken is ERC20Burnable, ERC20Mintable, ERC223 {
  using SafeMath for uint;

  uint public decimals = 18;  // allows us to divide and retain decimals

  address public assetRegistryAddress;

  modifier activeInvestment() {
    require(balanceOf(msg.sender) != 0, "must have an active investment");
    _;
  }

  /**
   * Contract constructor
   * Sets this contract's ref to AssetRegistry contract address
   * @param _assetRegistryAddress Address of AssetRegistry
   */
  constructor(address _assetRegistryAddress) public {
    assetRegistryAddress = _assetRegistryAddress;
  }

  /**
   * Records an allowance in VT between this contract and the investor for future ref
   * NOTE: this might not be necessary, although how do we keep track of VT tokens being minted... maybe
   *       we can mint them for this contract only for holding.
   * @param _tokenAddress Address of the VT contract we have filled
   * @param _investor Address of the investor
   * @param _amountTokens Amount of tokens we have minted / filled for the investor
   */
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

  /**
   * Returns the total value of all assets
   */
  function getCurrentOwnershipValue() public view activeInvestment returns (uint) {

  }

  /**
   * Returns the total value of all assets
   */
  function getTotalValue() public view returns (uint) {
    return AssetRegistry(assetRegistryAddress).calculateTotalValue();
  }

  /**
   * Calculates and returns the percentage of total tokens the sender holds
   */
  function getCurrentOwnershipPercentage() public view activeInvestment returns(uint) {
    uint amountTokens = balanceOf(msg.sender);
    return (amountTokens.mul(100)).div(totalSupply());
  }
}
