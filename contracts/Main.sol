pragma solidity ^0.5.5;

import "./../node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./../node_modules/openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./IVehicleToken.sol";
import "./StableToken.sol";
import "./IPortfolioToken.sol";
import "./IAssetRegistry.sol";

/**
 * @title Main
 * Manages the main functionality for ledgers (adding/retriving assets and investments)
 *
 * @author Carlos Beltran <imthatcarlos@gmail.com>
 */
contract Main is Ownable, Pausable {
  using SafeMath for uint;

  event InvestmentRecordCreated(address indexed tokenAddress, address investmentOwner, uint id);

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

  uint public VALUE_PER_VT_TOKENS_CENTS = 10;

  StableToken private stableToken;
  IPortfolioToken private portfolioToken;
  IAssetRegistry private assetRegistry;

  Investment[] private investments;
  mapping (address => uint[]) private activeInvestmentIds;

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
   * @dev To avoid bloating the constructor, deploy the PortfolioToken contract off-chain,
   *      create reference with `setPortfolioToken()`, and give minting permission to this contract
   * @param _stableTokenAddress Address of T token
   */
  constructor(address _stableTokenAddress) public {
    stableToken = StableToken(_stableTokenAddress);

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
  }

  /**
   * Sets this contract's reference to AssetRegistry contract
   * @param _contractAddress Address of AssetRegistry
   */
  function setAssetRegistry(address _contractAddress) public onlyOwner {
    assetRegistry = IAssetRegistry(_contractAddress);
  }

  /**
   * Sets this contract's reference to PortfolioToken contract
   * @param _contractAddress Address of PortfolioToken
   */
  function setPortfolioToken(address _contractAddress) public onlyOwner {
    portfolioToken = IPortfolioToken(_contractAddress);
  }

  /**
   * Allows the sender to invest in the Asset represented by the VehicleToken with the given address
   * NOTE: The sender must have approved the transfer of T tokens to this contract
   * @param _amountStable Amount of T tokens the sender is investing
   * @param _tokenAddress Address of the VehicleToken contract
   */
  function investVehicle(uint _amountStable, address payable _tokenAddress) public {
    IVehicleToken tokenContract = IVehicleToken(_tokenAddress);

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
    uint remainingSupply = tokenContract.cap().sub(tokenContract.totalSupply());
    assetRegistry.updateAssetLookup(_tokenAddress, remainingSupply, amountTokens);
  }

  /**
   * Allows the sender to invest in a basket of VT Token contracts
   * NOTE: The sender must have approved the transfer of T tokens to the PT contract
   * @param _amountStable Amount of T tokens the sender is investing
   */
  function investPortfolio(uint _amountStable) public {
    // sanity check
    require(assetRegistry.fillableAssetsCount() > 0, 'there are no assets to invest in');

    // mint the equivalent of PT tokens as stable for them
    portfolioToken.mint(msg.sender, _amountStable);

    // calculate total amount of tokens available to invest in VT contracts
    // NOTE: algo changes dramatically if this varies per token contract
    uint totalTokens = _amountStable.div(VALUE_PER_VT_TOKENS_CENTS);

    // recursively invest in all assets with a given strategy
    // TODO: the calculations could be done recursively and THEN we iterate and invest.
    //       this would require us to log how many tokens all contracts get, and then the minFillableAmount is how much
    //       ONE gets, but we need to know which one. This also would require is to log this for ALL rounds, as the
    //       minFillableAmount WILL change after the initial round.
    _recursiveInvestPortfolio(totalTokens);

    // add to storage
    _createInvestmentRecord(
      TokenType.Portfolio,
      _amountStable,
      totalTokens,
      address(portfolioToken),
      0
    );
  }

  /**
   * Returns the ids of all the sender's active assets
   */
  function getActiveInvestmentIds() public hasActiveInvestment view returns(uint[] memory) {
    return activeInvestmentIds[msg.sender];
  }

  /**
   * Returns the ids of all the given accounts's active investments
   * NOTE: can only be called by contract owner
   * @param _owner Owner address of assets
   */
  function getActiveInvestmentIdsOf(address _owner) public view onlyOwner returns(uint[] memory) {
    return activeInvestmentIds[_owner];
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

  /**
   * Not-so-recursively invests in all VT contracts by prioritizing the one closest to being filled, while still investing
   * in all assets evenly.
   * NOTE: this function will be called as many times as it takes to fully use up the invested T tokens while following
   *       the algo. It will get expensive and compute-intense as more assets are added to the platform.
   * @dev `minFillableAmount` allows us to safely mint tokens for all VT contracts without going over the cap on one,
          as this varilable represents the closest a contract is to being filled - _amountStable should be updated as well
   */
  function _recursiveInvestPortfolio(uint _totalTokens) internal {
    uint count = assetRegistry.fillableAssetsCount();
    uint minFillableAmount = assetRegistry.minFillableAmount();

    uint amountTokensEach = _totalTokens.div(count);
    uint minFillableRound = count.mul(minFillableAmount);
    uint amountStableEach;

    // HAPPY PATH: the user has enough tokens to cover all assets EQUALLY AND filling the asset closest to being filled
    if (minFillableRound <= _totalTokens) {
      amountStableEach = minFillableAmount.mul(VALUE_PER_VT_TOKENS_CENTS);
      amountTokensEach = minFillableAmount;
    } else if (amountTokensEach <= minFillableAmount) {
      // OK PATH: the user has enough tokens to cover all assets evenly, even if not filling one
      amountStableEach = amountTokensEach.mul(VALUE_PER_VT_TOKENS_CENTS);
    } else {
      // need another strategy... try doing less than minFillableRound
      return;
    }

    // iterate over our asset lookup and if the element is present, it is because it's still fillable
    uint amountInvested = 0;
    uint fillableAssetsIterate = assetRegistry.getAssetsCount();
    for (uint i = 1; i <= fillableAssetsIterate; i++) {
      address payable fillableAddress = assetRegistry.getFillableAssetAddressAt(i);
      if (fillableAddress != (address(0))) {
        _fillAssetForPortfolio(amountStableEach, amountTokensEach, fillableAddress);
        amountInvested = amountInvested.add(amountTokensEach);
      }
    }

    uint remainingTokens = _totalTokens.sub(amountInvested);

    // hacky way of avoiding impossible division
    if (remainingTokens < count) {
      // TODO: should be invest all in the next possible one?
      remainingTokens = 0;
    }

    if (remainingTokens != 0) {
      _recursiveInvestPortfolio(remainingTokens);
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
    IVehicleToken tokenContract = IVehicleToken(_tokenAddress);

    // sanity check, make sure we don't overflow
    require(tokenContract.cap() >= tokenContract.totalSupply().add(_amountTokens), 'overflow in VT contract supply');

    // transfer the T tokens to the VT token contract
    require(stableToken.transferFrom(msg.sender, _tokenAddress, _amountStable), 'failed transferring T tokens');

    // mint VT tokens for them, but PT contract holds and records the allowance of VT between PT and the sender
    tokenContract.mint(address(portfolioToken), _amountTokens);

    // NOTE: we don't need to log which PT investor got what VT tokens, but keeping here for ref
    //require(portfolioToken.approveFor(_tokenAddress, msg.sender, _amountTokens));

    require(portfolioToken.addInvestment(_tokenAddress, msg.sender, _amountTokens), 'failed adding investment');

    // update lookup records for asset registry
    uint remainingSupply = tokenContract.cap().sub(tokenContract.totalSupply());
    require(assetRegistry.updateAssetLookup(_tokenAddress, remainingSupply, _amountTokens));
  }
}
