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
  event Log(bool val);
  event Log(uint val);

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
  uint public fillableAssetsCount;
  uint public minFillableAmount; // minimum tokens required to fill one Asset

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

  /**
   * Sets this contract's reference to AssetRegistry contract
   * @param _contractAddress Address of AssetRegistry
   */
  function setAssetRegistry(address _contractAddress) public onlyOwner {
    assetRegistry = AssetRegistry(_contractAddress);
  }

  /**
   * Adds the new asset token contract to our lookup table for PT calculations, and updates
   * helper variables `minFillableAmount` and `fillableAssetsCount`
   * NOTE: this method can only be called from the AssetRegistry contract (in addAsset())
   * @param _tokenAddress Address of new VT contract
   * @param _cap Token cap of the asset
   */
  function addFillableAsset(address payable _tokenAddress, uint _cap) public {
    // only the AssetRegistry contract may call
    require(msg.sender == address(assetRegistry));

    // add to our modifiable lookup
    fillableAssets.push(FillableAsset({
      tokenAddress: _tokenAddress,
      tokenSupply: _cap
    }));

    // is this asset fillable quicker?
    if (minFillableAmount == 0 || _cap < minFillableAmount) {
      minFillableAmount = _cap;
    }

    fillableAssetsCount = fillableAssetsCount.add(1);
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

    // mint the equivalent of PT tokens as stable for them
    portfolioToken.mint(msg.sender, _amountStable);

    // calculate total amount of tokens available to invest in VT contracts
    // NOTE: algo changes dramatically if this varies per token contract
    uint totalTokens = _amountStable.div(VALUE_PER_VT_TOKENS_CENTS);

    // recursively invest in all assets with a given strategy
    // TODO: the calculations could be done recursively and THEN we iterate and invest... extra iteration though...
    uint tempTotal = totalTokens;
    while(tempTotal != 0) {
      tempTotal = _recursiveInvestPortfolio(_amountStable, tempTotal);
    }

    // add to storage
    _createInvestmentRecord(
      TokenType.Portfolio,
      _amountStable,
      totalTokens,
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

  function _recursiveInvestPortfolio(uint _amountStable, uint _totalTokens) internal returns (uint) {
    // HAPPY PATH: the user has enough tokens to cover all assets EQUALLY AND filling the asset closest to being filled
    uint minFillableRound = fillableAssetsCount.mul(minFillableAmount);

    // OK PATH: the user has enough tokens to cover all assets evenly, even if not filling one
    uint amountTokensEach = _totalTokens.div(fillableAssetsCount);

    if (minFillableRound <= _totalTokens || amountTokensEach <= minFillableAmount) {
      uint amountStableEach = _amountStable.div(fillableAssetsCount);

      // iterate over our asset lookup and if the element is present, it is because it's still fillable
      uint amountInvested = 0;
      for (uint i = 1; i <= (fillableAssets.length - 1); i++) {
        if (fillableAssets[i].tokenAddress != (address(0))) {
          _fillAssetForPortfolio(amountStableEach, amountTokensEach, fillableAssets[i].tokenAddress);
          amountInvested = amountInvested.add(amountTokensEach);
        }
      }

      // they should be equal if all were invested in...
      if (amountInvested == minFillableAmount) {
        return _totalTokens.sub(amountInvested);
      }
    } else {
      // need another strategy... try doing less than minFillableRound
      return 0;
    }
  }

  /**
   * Fills a Portfolio investment order for a particular VT contract
   * @dev To avoid overflow, we preemptively refuse to fill if the amount puts the token contract over its cap
   *      The calling method mints PT tokens for the user - but here we mint VT tokens for the PT contract, and set
   *      the allowance in VT of PT contract => user to the amount of tokens we minted for future ref (when burning)
   * @param _amountStable The amount of stable tokens to be sent to the VT contract
   * @param _amountTokens The amount of VT tokens the user has filled
   * @param _tokenAddress Address of VT contract
   */
  function _fillAssetForPortfolio(uint _amountStable, uint _amountTokens, address payable _tokenAddress) internal {
    VTToken tokenContract = VTToken(_tokenAddress);

    // sanity check, make sure we don't overflow
    require(tokenContract.cap() >= tokenContract.totalSupply().add(_amountTokens));

    // transfer the T tokens to the VT token contract
    require(stableToken.transferFrom(msg.sender, _tokenAddress, _amountStable));

    // mint VT tokens for them, but PT contract holds and records the allowance of VT between PT and the sender
    tokenContract.mint(address(portfolioToken), _amountTokens);
    require(portfolioToken.approveFor(_tokenAddress, msg.sender, _amountTokens));

    // update our records of token supplies
    _updateAssetLookup(_tokenAddress, (tokenContract.cap().sub(tokenContract.totalSupply())));
  }

  /**
   * [WIP] Update storage mappings that reflect global state of token contract funding and storage variables that
   * assist in calculations needed for Portfolio investing
   * @param _tokenAddress Address of VT contract
   * @param _remainingSupply Remaining supply of tokens available in this VT contract
   */
  function _updateAssetLookup(address _tokenAddress, uint _remainingSupply) internal {
    // if this contract is now fully invested, emit an event
    uint id = assetRegistry.getAssetIdByToken(_tokenAddress);

    if (_remainingSupply == 0) {
      // delete from lookup
      delete fillableAssets[id];

      // part of calculation
      fillableAssetsCount = fillableAssetsCount.sub(1);

      // what if this was the min?
      if (_remainingSupply == minFillableAmount) {
        // TODO: how to calculate the new min with _getMin()
      }

      // update storage on asset registry
      assetRegistry.setAssetFilled(id);

      // who cares?
      emit AssetFullyInvested(_tokenAddress, msg.sender);
    } else {
      fillableAssets[id].tokenSupply = _remainingSupply;

      if (_remainingSupply < minFillableAmount) {
        minFillableAmount = _remainingSupply;
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
