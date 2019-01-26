pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./VTToken.sol";
import "./TToken.sol";
import "./PTToken.sol";
//import "./Array256Lib.sol";

/**
 * @title Main
 * Manages the main functionality for ledgers (adding/retriving assets and investments)
 *
 * @author Carlos Beltran <imthatcarlos@gmail.com>
 */
contract Main is Ownable, Pausable {
  using SafeMath for uint;
  //using Array256Lib for uint256[];

  event InvestmentRecordCreated(address indexed tokenAddress, address investmentOwner, uint id);

  enum TokenType { Vehicle, Portfolio }

  struct Investment {
    TokenType tokenType;
    address owner;
    address tokenAddress;
    uint amountDAI;
    uint amountTokens;
    uint createdAt;
    uint timeframeMonths;
  }

  TToken private stableToken;
  PTToken private portfolioToken;

  Investment[] private investments;
  mapping (address => uint[]) private activeInvestmentIds;
  mapping (address => uint) private assetContractsRemainingTokens;
  mapping (address => bool) private assetContractsFullyFunded;
  uint[] test = new uint[](3);

  modifier hasActiveInvestment() {
    require(activeInvestmentIds[msg.sender].length != 0, "must have an active investment");
    _;
  }

  modifier validInvestment(uint _id) {
    require(investments[_id].owner != address(0));
    _;
  }

  /**
   * Contract constructor
   * @dev To avoid bloating the constructor, deploy the PTToken contract off-chain,
   *      create reference here, and change that contract owner to this contract so we can mint
   * @param _stableTokenAddress Address of T token
   * @param _portfolioTokenAddress Address of PT token
   */
  constructor(address _stableTokenAddress, address _portfolioTokenAddress) public {
    stableToken = TToken(_stableTokenAddress);
    portfolioToken = PTToken(_portfolioTokenAddress);

    // take care of zero-index for storage array
    investments.push(Investment({
      tokenType: TokenType.Vehicle,
      owner: address(0),
      tokenAddress: address(0),
      amountDAI: 0,
      amountTokens: 0,
      createdAt: 0,
      timeframeMonths: 0
    }));
  }

  /**
   * Allows the sender to invest in the Asset represented by the VTToken with the given address
   * NOTE: The sender must have approved the transfer of T tokens to this contract
   * @param _amountStable Amount of T tokens the sender is investing
   * @param _tokenAddress Address of the VTToken contract
   */
  function investVehicle(uint _amountStable, address payable _tokenAddress) public {
    VTToken tokenContract = VTToken(_tokenAddress);

    // total amount of tokens to mint for the sender
    uint amountTokens = _amountStable.div(tokenContract.valuePerTokenCents());

    // sanity check, make sure we don't overflow
    require(tokenContract.cap() >= tokenContract.totalSupply().add(amountTokens));

    // add to storage
    _createInvestmentRecord(
      TokenType.Vehicle,
      _amountStable,
      amountTokens,
      _tokenAddress,
      tokenContract.timeframeMonths()
    );

    // transfer the DAI tokens to the VT token contract
    require(stableToken.transferFrom(msg.sender, _tokenAddress, _amountStable));

    // mint VT tokens for them
    tokenContract.mint(msg.sender, amountTokens);

    // update storage mappings that reflect state of token contract funding
    uint tokenCap = tokenContract.cap();
    uint tokenSupply = tokenContract.totalSupply();
    if (tokenCap == tokenSupply) {
      assetContractsFullyFunded[_tokenAddress] = true;
      assetContractsRemainingTokens[_tokenAddress] = 0;
    } else {
      assetContractsRemainingTokens[_tokenAddress] = tokenCap - tokenSupply;
    }
  }

  /**
   * Allows the sender to invest in a basket of VT Token contracts
   * NOTE: The sender must have approved the transfer of T tokens to this contract
   * @param _amountStable Amount of T tokens the sender is investing
   */
  function investPortfolio(uint _amountStable) public {
    // transfer the DAI tokens to the PT token contract
    require(stableToken.transferFrom(msg.sender, address(portfolioToken), _amountStable));

    // mint PT tokens for them
    portfolioToken.mint(msg.sender, _amountStable); // mint the equivalent of PT tokens as stable

    // add to storage
    _createInvestmentRecord(
      TokenType.Portfolio,
      _amountStable,
      _amountStable,
      address(portfolioToken),
      0
    );

    // how to distribute based on existing VT contracts
    // check if all contracts have the same amount of totalSupply() (T tokens invested)
    // if yes
    //   invest in all evenly, making sure not to go over cap() on each
    //   if we go over on cap() for one... ?
    // if no
    //   invest in the contracts one at a time, based on..
    //   - newest
    //   - with the least totalSupply()
    //   - with the most totalSupply() closes to being fully funded
    //   - oldest
  }

  // function redeemVehicle() public {
  //
  // }
  //
  // function redeemPortfolio() public {
  //
  // }

  /**
   * Returns the ids of all the sender's active assets
   */
  function getActiveInvestmentIds() public hasActiveInvestment view returns(uint[] memory) {
    return activeInvestmentIds[msg.sender];
  }

  /**
   * Returns the ids of all the given accounts's active investments
   * NOTE: can only be called by contract owner
   */
  function getActiveInvestmentIdsOf(address owner) public view returns(uint[] memory) {
    return activeInvestmentIds[owner];
  }

  /**
   * Returns the number of active investments
   */
  function getInvestmentsCount() public view returns(uint) {
    return investments.length - 1; // ignoring first one created at init
  }

  /**
   * Returns details of the Investment with the given id
   * @param _id Investment id
   */
  function getInvestmentById(uint _id) public view validInvestment(_id)
    returns (
      TokenType tokenType,
      address owner,
      address tokenAddress,
      uint amountDAI,
      uint amountTokens,
      uint createdAt,
      uint timeframeMonths
    )
  {
    Investment storage inv = investments[_id];

    tokenType = inv.tokenType;
    owner = inv.owner;
    tokenAddress = inv.tokenAddress;
    amountDAI = inv.amountDAI;
    amountTokens = inv.amountTokens;
    createdAt = inv.createdAt;
    timeframeMonths = inv.timeframeMonths;
  }

  /**
   * Creates an Investment record and adds it to storage
   * @param _amountDAI Amount of DAI tokens invested
   * @param _amountTokens Amount of tokens minted in the VT token contract
   @ @param _tokenAddress Address of VT token contract
   @ param _timeframeMonths timeframe to be sold (months)
   */
  function _createInvestmentRecord(
    TokenType _tokenType,
    uint _amountDAI,
    uint _amountTokens,
    address _tokenAddress,
    uint _timeframeMonths
  ) internal {
    Investment memory record = Investment({
      tokenType: _tokenType,
      owner: msg.sender,
      tokenAddress: _tokenAddress,
      amountDAI: _amountDAI,
      amountTokens: _amountTokens,
      createdAt: block.timestamp,
      timeframeMonths: _timeframeMonths
    });

    // add the record to the storage array and push the index to the hashmap
    uint id = investments.push(record) - 1;
    activeInvestmentIds[msg.sender].push(id);

    emit InvestmentRecordCreated(_tokenAddress, msg.sender, id);
  }

  /// @dev Returns the max value in an array.
  /// @param self Storage array containing uint256 type variables
  /// @return maxValue The highest value in the array
  /// https://github.com/Modular-Network/ethereum-libraries/contracts/Array256Lib.sol
  function getMax(uint256[] storage self) internal view returns(uint256 maxValue) {
    assembly {
      mstore(0x60,self_slot)
      maxValue := sload(keccak256(0x60,0x20))

      for { let i := 0 } lt(i, sload(self_slot)) { i := add(i, 1) } {
        switch gt(sload(add(keccak256(0x60,0x20),i)), maxValue)
        case 1 {
          maxValue := sload(add(keccak256(0x60,0x20),i))
        }
      }
    }
  }
}
