pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./VTToken.sol";
import "./TToken.sol";
import "./AssetRegistry.sol";

contract Main is Ownable, Pausable, AssetRegistry {
  using SafeMath for uint;

  event InvestmentRecordCreated(address indexed owner, uint id, address tokenAddress);

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

  Investment[] private investments;
  mapping (address => uint[]) private activeInvestmentIds;

  modifier hasActiveInvestment() {
    require(activeInvestmentIds[msg.sender].length != 0, "must have an active investment");
    _;
  }

  constructor(address _stableTokenAddress) public AssetRegistry(_stableTokenAddress) {
    stableToken = TToken(_stableTokenAddress);

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

  function investVehicle(uint _amountStable, address payable _tokenAddress) public {
    VTToken tokenContract = VTToken(_tokenAddress);

    // total amount of tokens to mint for the sender
    uint amountTokens = _amountStable.div(tokenContract.valuePerTokenCents());

    // sanity check, make sure we don't overflow
    require(tokenContract.cap() >= tokenContract.totalSupply().add(amountTokens));

    // add to storage
    _createInvestmentRecordV(_amountStable, amountTokens, _tokenAddress, tokenContract.timeframeMonths());

    // transfer the DAI tokens to this contract
    require(stableToken.transferFrom(msg.sender, address(this), _amountStable));

    // mint VT tokens for them
    tokenContract.mint(msg.sender, amountTokens);
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
  function getInvestmentById(uint _id) public view validAsset(_id)
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
  function _createInvestmentRecordV(
    uint _amountDAI,
    uint _amountTokens,
    address _tokenAddress,
    uint _timeframeMonths
  ) internal {
    Investment memory record = Investment({
      tokenType: TokenType.Vehicle,
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

    emit InvestmentRecordCreated(msg.sender, id, _tokenAddress);
  }
}
