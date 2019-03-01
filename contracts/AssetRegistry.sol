pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./IAssetRegistry.sol";
import "./VehicleToken.sol";
import "./Main.sol";

/**
 * @title AssetRegistry
 * This contract manages the functionality for assets - adding records, as well as reading data. It allows
 * users to add assets to the platform, and asset owners to fund their assets once sold.
 *
 * @author Carlos Beltran <imthatcarlos@gmail.com>
 */
contract AssetRegistry is IAssetRegistry, Pausable, Ownable {
  using SafeMath for uint;

  struct Asset {
    address owner;
    address payable tokenAddress;
    bool filled;
    bool funded;
  }

  struct FillableAsset {
    address payable tokenAddress;
    uint tokenSupply;
  }

  uint public fillableAssetsCount;
  uint public minFillableAmount; // minimum tokens required to fill one Asset

  StableToken private stableToken;
  address private mainContractAddress;
  uint[] private assetProjectedValuesUSD; // allows us to easily calculate the total value of all assets

  Asset[] private assets;
  FillableAsset[] private fillableAssets;
  mapping (address => uint[]) private ownerToAssetIds;
  mapping (address => uint) private tokenToAssetIds;

  modifier hasActiveAsset() {
    require(ownerToAssetIds[msg.sender].length != 0, "must have an active asset");
    _;
  }

  modifier validAsset(uint _id) {
    require(assets[_id].owner != address(0));
    _;
  }

  modifier onlyAssetOwner(uint _id) {
    require(assets[_id].owner == msg.sender);
    _;
  }

  constructor(address _stableTokenAddress, address _mainContractAddress) public {
    stableToken = StableToken(_stableTokenAddress);
    mainContractAddress = _mainContractAddress;

    // take care of zero-index for storage array
    assets.push(Asset({
      owner: address(0),
      tokenAddress: address(0),
      filled: false,
      funded: false
    }));

    fillableAssets.push(FillableAsset({
      tokenAddress: address(0),
      tokenSupply: 0
    }));

    assetProjectedValuesUSD.push(0);
  }

  /**
   * Sets this contract's reference to the Main contract
   * @param _contractAddress Main contract address
   */
  function setMainContractAddress(address _contractAddress) public onlyOwner {
    mainContractAddress = _contractAddress;
  }

  /**
   * Creates an Asset record and adds it to storage, also creating a VehicleToken contract instance to
   * represent the asset
   * @param _owner Owner of the asset
   * @param _name Name of the asset
   * @param _valueUSD Value of the asset in USD
   * @param _cap token cap == _valueUSD / _valuePerTokenUSD
   * @param _annualizedROI AROI %
   * @param _projectedValueUSD The PROJECTED value of the asset in USD
   * @param _timeframeMonths Time frame for the investment
   * @param _valuePerTokenCents Value of each token
   */
  function addAsset(
    address payable _owner,
    string calldata _name,
    uint _valueUSD,
    uint _cap,
    uint _annualizedROI,
    uint _projectedValueUSD,
    uint _timeframeMonths,
    uint _valuePerTokenCents
  ) external {
    VehicleToken token = new VehicleToken(
      _owner,
      address(stableToken),
      _name,
      _valueUSD,
      _cap,
      _annualizedROI,
      _projectedValueUSD,
      _timeframeMonths,
      _valuePerTokenCents
    );

    // so the main contract can mint
    token.addMinter(mainContractAddress);

    // so the main contract can later reference
    _addFillableAsset(address(token), _cap);

    Asset memory record = Asset({
      owner: _owner,
      tokenAddress: address(token),
      filled: false,
      funded: false
    });

    // add the record to the storage array and push the index to the hashmap
    uint id = assets.push(record) - 1;
    ownerToAssetIds[_owner].push(id);
    tokenToAssetIds[address(token)] = id;

    // update our records for calculating
    assetProjectedValuesUSD.push(_projectedValueUSD);

    emit AssetRecordCreated(address(token), _owner, id);
  }

  /**
   * Allows the contract owner to edit certain data on the token contract
   * NOTE: we don't allow editing the token cap of the contract as it would jeopardize the validity of lookup
   *       records of other contracts (ie: Asset.filled in AssetRegistry). That being said...
   * NOTE: the cap is derived from the initial _valueUSD / _valuePerTokenUSD, so there will have to be some balancing
   *       if we want to preserve correct calculations
   * @param _tokenAddress The address of token contract
   * @param _valueUSD Value of the asset in USD
   * @param _annualizedROI AROI %
   * @param _projectedValueUSD The PROJECTED value of the asset in USD
   * @param _timeframeMonths Time frame for the investment
   * @param _valuePerTokenCents Value of each token
   */
  function editAsset(
    address payable _tokenAddress,
    uint _valueUSD,
    uint _annualizedROI,
    uint _projectedValueUSD,
    uint _timeframeMonths,
    uint _valuePerTokenCents
  ) external onlyOwner {
    // sanity check, must be a valid asset contract
    require(tokenToAssetIds[_tokenAddress] != 0);

    VehicleToken(_tokenAddress).editAssetData(
      _valueUSD,
      _annualizedROI,
      _projectedValueUSD,
      _timeframeMonths,
      _valuePerTokenCents
    );

    // udpate the projected value usd for the lookup record
    // ids on both arrays should be 1:1
    uint id = tokenToAssetIds[_tokenAddress];
    assetProjectedValuesUSD[id] = _projectedValueUSD;

    // emit an event for active clients to be notified
    emit AssetRecordUpdated(_tokenAddress, id);
  }

  /**
   * Update storage mappings that reflect global state of token contract funding and storage variables that
   * assist in calculations needed for Portfolio investing
   * NOTE: can only be called by Main contract
   * @param _tokenAddress Address of VT contract
   * @param _remainingSupply Remaining supply of tokens available in this VT contract
   * @param _tokensMinted Amount of tokens just minted for this asset
   */
  function updateAssetLookup(address _tokenAddress, uint _remainingSupply, uint _tokensMinted) public {
    require(msg.sender == mainContractAddress);

    uint id = tokenToAssetIds[_tokenAddress];
    if (_remainingSupply == 0) {
      // delete from lookup
      delete fillableAssets[id];

      // part of calculation
      fillableAssetsCount = fillableAssetsCount.sub(1);

      // what if this was the min? (and there's more assets)
      if (_tokensMinted == minFillableAmount && fillableAssetsCount > 0) {
        minFillableAmount = _calculateNewMinFillableAmount();
      } else if (fillableAssetsCount == 0) {
        minFillableAmount = 0;
      }

      // update record
      assets[id].filled = true;

      // who cares?
      emit AssetFullyInvested(_tokenAddress, msg.sender);
    } else {
      fillableAssets[id].tokenSupply = _remainingSupply;

      if (_remainingSupply < minFillableAmount || minFillableAmount == 0) {
        minFillableAmount = _remainingSupply;
      }
    }
  }

  /**
   * Allows an Asset Owner to fund the VehicleToken contract with T tokens to be distributed to investors
   * @dev should be called when the asset is sold, and any amount of T tokens sent in should
   *      equal the projected profit. this amount is divided amongst token owners based on the percentage
   *      of tokens they own. these token owners must claim their profit, it will NOT be automatically
   *      distributed to avoid security concerns
   * NOTE: asset owner must have approved the transfer of T tokens from their wallet to the VehicleToken contract
   * @param _amountStable Amount of T tokens the owner will fund - MUST equal the asset's projected value recorded
   * @param _assetId Asset id
   */

  function fundAsset(uint _amountStable, uint _assetId) public onlyAssetOwner(_assetId) {
    Asset storage asset = assets[_assetId];

    // sanity check
    require(_amountStable.div(10**18) >= VehicleToken(asset.tokenAddress).projectedValueUSD());

    // send T tokens from owner wallet to the token contract to be claimed by investors
    require(stableToken.transferFrom(msg.sender, asset.tokenAddress, _amountStable));

    asset.funded = true;

    emit AssetFunded(_assetId, asset.tokenAddress);
  }

  /**
   * Calculates and returns the sum of PROJECTED values of all assets (USD)
   */
  function calculateTotalProjectedValue() public view returns(uint) {
    return _sumElementsStorage(assetProjectedValuesUSD);
  }

  /**
   * Calculates and returns the sum of CURRENT values of all assets (T/USD)
   * @dev For all assets in the storage array that have not been deleted, calculate its current value
   */
  function calculateTotalCurrentValue() public view returns(uint) {
    uint total;
    for (uint i = 1; i <= (assets.length - 1); i++) {
      if (assets[i].tokenAddress != address(0)) {
        total = total.add(VehicleToken(assets[i].tokenAddress).getCurrentValue());
      }
    }

    return total;
  }

  /**
   * Returns the storage array id of the asset with the given VT contract address
   * @param _tokenAddress Address of VT contract
   */
  function getAssetIdByToken(address _tokenAddress) public view returns(uint) {
    return tokenToAssetIds[_tokenAddress];
  }

  /**
   * Returns the ids of all the sender's active assets
   */
  function getActiveAssetIds() public hasActiveAsset view returns(uint[] memory) {
    return ownerToAssetIds[msg.sender];
  }

  /**
   * Returns the ids of all the given accounts's active assets
   * NOTE: can only be called by contract owner
   */
  function getActiveAssetIdsOf(address _owner) public view onlyOwner returns(uint[] memory) {
    return ownerToAssetIds[_owner];
  }

  /**
   * Returns the number of active assets
   */
  function getAssetsCount() public view returns(uint) {
    return assets.length - 1; // ignoring first one created at init
  }

  /**
   * Returns the address (or zero-address) for the fillabel asset at the given id
   * @param _id Asset id
   */
  function getFillableAssetAddressAt(uint _id) public view returns(address payable tokenAddress) {
    return fillableAssets[_id].tokenAddress;
  }

  function getFillableAssetsCount() public view returns(uint) {
    return fillableAssetsCount;
  }

  function getMinFillableAmount() public view returns(uint) {
    return minFillableAmount;
  }

  /**
   * Returns details of the Asset with the given id
   * @param _id Asset id
   */
  function getAssetById(uint _id)
    public
    view
    validAsset(_id)
    returns (
      address owner,
      address tokenAddress,
      bool filled,
      bool funded
    )
  {
    Asset storage asset = assets[_id];

    owner = asset.owner;
    tokenAddress = asset.tokenAddress;
    filled = asset.filled;
    funded = asset.funded;
  }

  /**
   * Adds the new asset token contract to our lookup table for PT calculations, and updates
   * helper variables `minFillableAmount` and `fillableAssetsCount`
   * @param _tokenAddress Address of new VT contract
   * @param _cap Token cap of the asset
   */
  function _addFillableAsset(address payable _tokenAddress, uint _cap) internal {
    fillableAssets.push(FillableAsset({
      tokenAddress: _tokenAddress,
      tokenSupply: _cap
    }));

    // is this asset fillable quicker?
    if (minFillableAmount == 0 || _cap < minFillableAmount) {
      minFillableAmount = _cap;
    }

    fillableAssetsCount = fillableAssetsCount.add(1);

    // hacky: allows the token contract contract to mint T tokens it needs to satisfy investor claims
    stableToken.addMinter(_tokenAddress);
  }

  /**
   * Calculate a new minimum fillable amount for all fillable assets
   * TODO: this should be in assembly for efficiency
   */
  function _calculateNewMinFillableAmount() internal view returns (uint) {
    uint[] memory supplies = new uint[](fillableAssetsCount);
    uint j = 0;
    for (uint i = 1; i <= (fillableAssets.length - 1); i++) {
      if (fillableAssets[i].tokenAddress != (address(0))) {
        supplies[j] = fillableAssets[i].tokenSupply; // out-of-bounds should not occur...
        j = j.add(1);
      }
    }

    // sanity check
    require(fillableAssetsCount == j);

    return _getMin(supplies);
  }

  /// @dev Returns the minimum value in an array.
  /// @param self Storage array containing uint256 type variables
  /// @return minValue The smallest value in the array
  /// https://github.com/Modular-Network/ethereum-libraries/contracts/Array256Lib.sol
  function _getMin(uint256[] memory self) internal view returns (uint256 minValue) {
    assembly {
      mstore(0x60,self)
      minValue := sload(keccak256(0x60,0x20))

      for { let i := 0 } lt(i, sload(self)) { i := add(i, 1) } {
        switch gt(sload(add(keccak256(0x60,0x20),i)), minValue)
        case 0 {
          minValue := sload(add(keccak256(0x60,0x20),i))
        }
      }
    }
  }

  /// @dev Sum vector
  /// @param self Storage array containing uint256 type variables
  /// @return sum The sum of all elements, does not check for overflow
  /// https://github.com/Modular-Network/ethereum-libraries/contracts/Array256Lib.sol
  function _sumElementsStorage(uint256[] storage self) internal view returns(uint256 sum) {
    assembly {
      mstore(0x60,self_slot)

      for { let i := 0 } lt(i, sload(self_slot)) { i := add(i, 1) } {
        sum := add(sload(add(keccak256(0x60,0x20),i)),sum)
      }
    }
  }

  /// @dev Sum vector
  /// @param self Storage array containing uint256 type variables
  /// @return sum The sum of all elements, does not check for overflow
  /// https://github.com/Modular-Network/ethereum-libraries/contracts/Array256Lib.sol
  function _sumElementsMemory(uint256[] memory self) internal view returns(uint256 sum) {
    assembly {
      mstore(0x60,self)

      for { let i := 0 } lt(i, sload(self)) { i := add(i, 1) } {
        sum := add(sload(add(keccak256(0x60,0x20),i)),sum)
      }
    }
  }
}
