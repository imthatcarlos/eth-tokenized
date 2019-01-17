pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./VTToken.sol";

contract Main {
  using SafeMath for uint;

  event InvestmentRecordCreated(address indexed owner, uint id, address tokenAddress);

  enum TokenType { Vehicle, Portfolio }

  ERC20 private daiToken;

  uint public VALUE_PER_TOKEN_USD_CENTS = 10;
  uint public lockPeriodSeconds;

  struct Investment {
    TokenType tokenType;
    address owner;
    address[] tokenAddresses; // TODO: maybe set a cap?
    uint amountDAI;
    uint amountTokens;
    uint createdAt;
    uint releasedAt;
  }

  Investment[] private investments;
  mapping (address => uint[]) private activeInvestmentIds;

  constructor(address _daiTokenAddress, uint _lockPeriodSeconds) public {
    daiToken = ERC20(_daiTokenAddress);
    lockPeriodSeconds = _lockPeriodSeconds;
  }

  function investVehicle(uint _amountDAI, address _tokenAddress) public {
    VTToken tokenContract = VTToken(_tokenAddress);

    // total amount of tokens to mint for the sender
    uint amountTokens = _amountDAI.div(VALUE_PER_TOKEN_USD_CENTS);

    // sanity check, make sure we don't overflow
    require(tokenContract.cap() > tokenContract.totalSupply().add(amountTokens));

    // add to storage
    _createInvestmentRecordV(_amountDAI, amountTokens, _tokenAddress);

    // transfer the DAI tokens to this contract
    require(daiToken.transferFrom(msg.sender, address(this), _amountDAI));

    // mint VT tokens for them
    tokenContract.mint(msg.sender, amountTokens);
  }
  /**
   * Creates an Investment record and adds it to storage
   * @param _amountDAI Amount of DAI tokens invested
   * @param _amountTokens Amount of tokens minted in the VT token contract
   @ @param _tokenAddress Address of VT token contract
   */
  function _createInvestmentRecordV(uint _amountDAI, uint _amountTokens, address _tokenAddress) internal {
    /* solium-disable-next-line security/no-block-members */
    uint releasedAt = block.timestamp.add(lockPeriodSeconds);
    Investment memory record = Investment({
      tokenType: TokenType.Vehicle,
      owner: msg.sender,
      tokenAddresses: new address[](0),
      amountDAI: _amountDAI,
      amountTokens: _amountTokens,
      createdAt: block.timestamp,
      releasedAt: releasedAt
    });

    // add the record to the storage array and push the index to the hashmap
    uint id = investments.push(record) - 1;
    activeInvestmentIds[msg.sender].push(id);

    emit InvestmentRecordCreated(msg.sender, id, _tokenAddress);
  }
}
