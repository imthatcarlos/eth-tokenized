pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./VTToken.sol";
import "./TToken.sol";

contract AssetRegistry is Ownable, Pausable {
  using SafeMath for uint;

  event AssetRecordCreated(address indexed owner, uint id, address tokenAddress);
  event AssetFunded(uint id, address tokenAddress);

  struct Asset {
    address owner;
    address tokenAddress;
  }

  TToken stableToken;

  Asset[] private assets;
  mapping (address => uint[]) private ownerToAssetIds;

  modifier hasActiveAsset() {
    require(ownerToAssetIds[msg.sender].length != 0, "must have an active asset");
    _;
  }

  modifier validAsset(uint _id) {
    require(assets[_id].owner != address(0));
    _;
  }

  modifier onlyAssetOwner() {
    require(ownerToAssetIds[msg.sender].length != 0);
    _;
  }

  constructor(address _stableTokenAddress) public {
    stableToken = TToken(_stableTokenAddress);
  }

  function addAsset(
    address owner,
    string calldata _name,
    uint _valueUSD,
    uint _cap,
    uint _annualizedROI,
    uint _projectedValueUSD,
    uint _timeframeMonths,
    uint _valuePerTokenCents
  ) external {
    VTToken token = new VTToken(
      _name,
      _valueUSD,
      _cap,
      _annualizedROI,
      _projectedValueUSD,
      _timeframeMonths,
      _valuePerTokenCents
    );

    Asset memory record = Asset({
      owner: owner,
      tokenAddress: address(token)
    });

    // add the record to the storage array and push the index to the hashmap
    uint id = assets.push(record) - 1;
    ownerToAssetIds[owner].push(id);

    emit AssetRecordCreated(owner, id, address(token));
  }

  // should be called when the asset is sold, and any amount of T tokens sent in should
  // equal the projected profit. this amount is divided amongst token owners based on the percentage
  // of tokens they own. these token owners must claim their profit, it will NOT be automatically
  // distributed to avoid security concerns
  // NOTE: asset owner must have approved the transfer of T tokens from their wallet to the VTToken contract
  function fundAsset(uint _amountStable, uint _assetId) public onlyAssetOwner validAsset(_assetId) {
    Asset storage asset = assets[_assetId];

    // sanity check
    require(_amountStable >= VTToken(asset.tokenAddress).projectedValueUSD());

    // send T tokens from owner wallet to the token contract to be claimed by investors
    require(stableToken.transferFrom(msg.sender, asset.tokenAddress, _amountStable));

    emit AssetFunded(_assetId, asset.tokenAddress);
  }

  function getActiveAssetIds() public hasActiveAsset view returns(uint[] memory) {
    return ownerToAssetIds[msg.sender];
  }

  function getAssetsCount() public view returns(uint) {
    return assets.length;
  }

  function getAssetById(uint _id) public view validAsset(_id) returns (address owner, address tokenAddress) {
    Asset storage asset = assets[_id];

    owner = asset.owner;
    tokenAddress = asset.tokenAddress;
  }
}
