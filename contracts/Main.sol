pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./VTToken.sol";
import "./TToken.sol";
import "./PTToken.sol";
import "./AssetRegistry.sol";
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
  event AssetFullyInvested(address indexed tokenAddress, address investmentOwner);

  enum TokenType { Vehicle, Portfolio }

  struct Investment {
    TokenType tokenType;
    address owner;
    address tokenAddress;
    uint amountDAI;
    uint amountTokens; // if TokenType.Portfolio, 0
    uint createdAt;
    uint timeframeMonths; // if TokenType.Portfolio, 0
  }

  // an idea to avoid the mess...
  struct FillableAsset {
    address payable tokenAddress;
    uint tokenSupply;
  }

  TToken private stableToken;
  PTToken private portfolioToken;
  AssetRegistry private assetRegistry;
  uint public VALUE_PER_VT_TOKENS_CENTS = 10; // do we need setter? oracle? does it vary between VT contracts?

  Investment[] private investments;
  mapping (address => uint[]) private activeInvestmentIds;

  FillableAsset[] private fillableAssets;
  uint public fillableAssetsCount = 0;
  uint public minFillableAmount = 0; // minimum tokens required to fill one Asset

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
   *      create reference here, and give minting permission to this contract
   * @param _stableTokenAddress Address of T token
   * @param _portfolioTokenAddress Address of PT token
   */
  constructor(address _stableTokenAddress, address _portfolioTokenAddress) public {
    stableToken = TToken(_stableTokenAddress);
    portfolioToken = PTToken(_portfolioTokenAddress);

    // take care of zero-index for storage arrays
    investments.push(Investment({
      tokenType: TokenType.Vehicle,
      owner: address(0),
      tokenAddress: address(0),
      amountDAI: 0,
      amountTokens: 0,
      createdAt: 0,
      timeframeMonths: 0
    }));

    fillableAssets.push(FillableAsset({
      tokenAddress: address(0),
      tokenSupply: 0
    }));
  }

  function setAssetRegistry(address _contractAddress) public onlyOwner {
    assetRegistry = AssetRegistry(_contractAddress);
  }

  function addFillableAsset(address payable _tokenAddress, uint _cap) public {
    // only the AssetRegistry contract may call
    require(msg.sender == address(assetRegistry));

    // add to our modifiable lookup
    fillableAssets.push(FillableAsset({
      tokenAddress: _tokenAddress,
      tokenSupply: _cap
    }));

    // is this asset fillable quicker?
    if (_cap < minFillableAmount) {
      minFillableAmount = _cap;
    }

    fillableAssetsCount.add(1);
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

    // update our records of token supplies
    _updateAssetLookup(_tokenAddress, (tokenContract.cap().sub(tokenContract.totalSupply())));
  }

  /**
   * Allows the sender to invest in a basket of VT Token contracts
   * NOTE: The sender must have approved the transfer of T tokens to the PT contract
   * @param _amountStable Amount of T tokens the sender is investing
   */
  function investPortfolio(uint _amountStable) public {
    // sanity check
    require(fillableAssetsCount > 0, 'there are no assets to invest in');

    // transfer the T tokens to the PT token contract
    require(stableToken.transferFrom(msg.sender, address(portfolioToken), _amountStable));

    // calculate total amount of tokens available to invest in VT contracts
    // NOTE: algo changes dramatically if this varies per token contract
    uint totalTokens = _amountStable.div(VALUE_PER_VT_TOKENS_CENTS);

    // the user has enough tokens to cover all assets EQUALLY by filling the asset closest to being filled
    if (fillableAssetsCount.mul(minFillableAmount) < totalTokens) {
      uint amountStableEach = totalTokens.div(fillableAssetsCount);

      // for all our assets, check if it's fillable and then fill it
      for (uint i = 1; i < fillableAssets.length; i++) {
        // if this asset is indeed fillable, DO IT
        if (fillableAssets[i].tokenAddress != (address(0))) {
          investVehicle(amountStableEach, fillableAssets[i].tokenAddress);
        }
      }
    } else {
      // need a strategy here...
      revert();
    }

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

  // update storage mappings that reflect state of token contract funding
  function _updateAssetLookup(address _tokenAddress, uint remainingSupply) internal {
    // if this contract is now fully invested, emit an event
    uint id = assetRegistry.getAssetIdByToken(_tokenAddress);

    if (remainingSupply == 0) {
      // delete from lookup
      delete fillableAssets[id];

      // part of calculation
      fillableAssetsCount.sub(1);

      // what if this was the min?
      if (remainingSupply == minFillableAmount) {
        // how to calculate the new min with _getMin()
      }

      // update storage on asset registry
      assetRegistry.setAssetFilled(id);

      // who cares?
      emit AssetFullyInvested(_tokenAddress, msg.sender);
    } else {
      fillableAssets[id].tokenSupply = remainingSupply;

      if (remainingSupply < minFillableAmount) {
        minFillableAmount = remainingSupply;
      }
    }
  }

  /// @dev Returns the max value in an array.
  /// @param self Storage array containing uint256 type variables
  /// @return maxValue The highest value in the array
  /// https://github.com/Modular-Network/ethereum-libraries/contracts/Array256Lib.sol
  function _getMax(uint256[] storage self) internal view returns(uint256 maxValue) {
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

  /// @dev Returns the minimum value in an array.
  /// @param self Storage array containing uint256 type variables
  /// @return minValue The smallest value in the array
  /// https://github.com/Modular-Network/ethereum-libraries/contracts/Array256Lib.sol
  function _getMin(uint256[] storage self) internal view returns(uint256 minValue) {
    assembly {
      mstore(0x60,self_slot)
      minValue := sload(keccak256(0x60,0x20))

      for { let i := 0 } lt(i, sload(self_slot)) { i := add(i, 1) } {
        switch gt(sload(add(keccak256(0x60,0x20),i)), minValue)
        case 0 {
          minValue := sload(add(keccak256(0x60,0x20),i))
        }
      }
    }
  }
}
