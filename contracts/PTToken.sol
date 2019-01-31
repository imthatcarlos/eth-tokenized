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

  // to calculate investor claims
  address payable[] public tokenInvestments;
  mapping (address => bool) public tokenHasInvestment;

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

  // NOTE: not used, but keeping for ref
  // /**
  //  * Records an allowance in VT between this contract and the investor for future ref
  //  * NOTE: this might not be necessary, although how do we keep track of VT tokens being minted... maybe
  //  *       we can mint them for this contract only for holding.
  //  * @param _tokenAddress Address of the VT contract we have filled
  //  * @param _investor Address of the investor
  //  * @param _amountTokens Amount of tokens we have minted / filled for the investor
  //  */
  // function approveFor(
  //   address payable _tokenAddress,
  //   address payable _investor,
  //   uint _amountTokens
  // ) public returns(bool) {
  //   // the investor must have already received PT tokens
  //   require(balanceOf(_investor) > 0);
  //   // this contract must have received the VT tokens
  //   require(VTToken(_tokenAddress).balanceOf(address(this)) >= _amountTokens);
  //
  //   // log an allowance for future ref
  //   require(VTToken(_tokenAddress).approve(_investor, _amountTokens));
  //
  //   return true;
  // }

  /**
   * Records an investment in a VT contract
   * @dev Although this function can be called from anyone, we require that the investor specified
   *      has PT tokens and that the balance in VT of this contract is greater than the specified token amount
   *      Also, this function is simply updating values in storage for future calculations.
   * @param _tokenAddress Address of the VT contract we have filled
   * @param _amountTokens Amount of tokens we have minted / filled for the investor
   */
  function addInvestment(
    address payable _tokenAddress,
    address payable _investor,
    uint _amountTokens
  ) public returns (bool) {
    // the investor must have already received PT tokens
    require(balanceOf(_investor) > 0, 'investor does not have PT tokens');
    // this contract must have received the VT tokens
    require(VTToken(_tokenAddress).balanceOf(address(this)) >= _amountTokens, 'invalid value for _amountTokens');

    // log whether we have holdings in this asset
    if (tokenHasInvestment[_tokenAddress] == false) {
      tokenHasInvestment[_tokenAddress] = true;
      tokenInvestments.push(_tokenAddress);
    }

    return true;
  }

  /**
   * Allows a token holder to burn all or a portion of their PT tokens to receive VT tokens proportionate
   * to the percentage of total PT tokens they own.
   * Ex: If someone's balance is 100 tokens and the total supply is 500, that investor has a claim on 20% of all
   * profits the PT contract has a claim on, and we should send the investor 20% of this contract's holdings in each
   * VT contract.
   * @param _amountTokens Amount of tokens the investor is trying to redeem
   */
  function claimFundsAndBurn(uint _amountTokens) public activeInvestment {
    // sanity check
    require(_amountTokens > 0 && _amountTokens <= balanceOf(msg.sender), 'invalid value for _amountTokens');

    // TODO: need to guard against 5 / 100000000000000000
    uint ownershipPercentage = _amountTokens.mul(100).div(totalSupply());

    // given the above % ownership, send VT tokens from each of this contract's holdings
    for (uint i = 0; i < tokenInvestments.length; i++) {
      if (tokenInvestments[i] != address(0)) {
        VTToken token = VTToken(tokenInvestments[i]);
        uint amount = token.balanceOf(address(this)).mul(ownershipPercentage).div(100);

        // transfer
        require(token.transfer(msg.sender, amount), 'transfer of VT tokens failed');

        // if we no longer have funds in this VT contract, update our lookup records
        if (token.balanceOf(address(this)) == 0) {
          tokenHasInvestment[address(token)] = false;
          delete tokenInvestments[i];
        }
      }
    }

    // burn PT tokens
    burn(_amountTokens);
  }

  /**
   * Calculates the current value (in T) of the sender's PT investment based on this contract's holdings
   */
  function calculateTotalCurrentValueOwned() public view activeInvestment returns(uint) {
    return calculateTotalCurrentValue().mul(getCurrentOwnershipPercentage()).div(100);
  }

  /**
   * Calculates the current value (in T) of the sender's PT investment based on this contract's holdings
   */
  function calculateTotalCurrentValue() public view returns(uint) {
    uint total;
    for (uint i = 0; i < tokenInvestments.length; i++) {
      if (tokenInvestments[i] != address(0)) {
        total = total.add(VTToken(tokenInvestments[i]).getCurrentValuePortfolio());
      }
    }

    return total;
  }

  /**
   * Calculates the PROJECTED value (in T) of the sender's PT investment based on this contract's holdings
   */
  function calculateTotalProjectedValueOwned() public view activeInvestment returns (uint) {
    return calculateTotalProjectedValue().mul(getCurrentOwnershipPercentage()).div(100);
  }

  /**
   * Calculates the PROJECTED value (in T) of this asset's holdings
   */
  function calculateTotalProjectedValue() public view returns (uint) {
    uint total;
    for (uint i = 0; i < tokenInvestments.length; i++) {
      if (tokenInvestments[i] != address(0)) {
        total = total.add(VTToken(tokenInvestments[i]).projectedValueUSD());
      }
    }

    return total;
  }

  /**
   * Calculates and returns the percentage of total tokens the sender holds
   */
  function getCurrentOwnershipPercentage() public view returns(uint) {
    // TODO: need to guard against 5 / 100000000000000000
    return balanceOf(msg.sender).mul(100).div(totalSupply());
  }
}
