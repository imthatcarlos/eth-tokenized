pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./VTToken.sol";
import "./TToken.sol";
import "./Main.sol";

contract AssetRegistry is Pausable, Ownable {
  using SafeMath for uint;

  event AssetRecordCreated(address tokenAddress, address assetOwner, uint id);
  event AssetFunded(uint id, address tokenAddress);

  struct Asset {
    address owner;
    address payable tokenAddress;
    bool filled;
    bool funded;
  }

  TToken private stableToken;
  address private mainContractAddress;

  Asset[] private assets;
  mapping (address => uint[]) private ownerToAssetIds;
  mapping (address => uint) private tokenToAssetIds;

  // allows us to easily calculate the total value of all assets
  uint[] private assetProjectedValuesUSD;

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
    stableToken = TToken(_stableTokenAddress);
    mainContractAddress = _mainContractAddress;

    // take care of zero-index for storage array
    assets.push(Asset({
      owner: address(0),
      tokenAddress: address(0),
      filled: false,
      funded: false
    }));

    assetProjectedValuesUSD.push(0);
  }

  function setMainContractAddress(address _contractAddress) public onlyOwner {
    mainContractAddress = _contractAddress;
  }

  /**
   * Creates an Asset record and adds it to storage, also creating a VTToken contract instance to
   * represent the asset
   * @param owner Owner of the asset
   * @param _name Name of the asset
   * @param _valueUSD Value of the asset in USD
   * @param _cap token cap == _valueUSD / _valuePerTokenUSD
   * @param _annualizedROI AROI %
   * @param _projectedValueUSD The PROJECTED value of the asset in USD
   * @param _timeframeMonths Time frame for the investment
   * @param _valuePerTokenCents Value of each token
   */
  function addAsset(
    address payable owner,
    string calldata _name,
    uint _valueUSD,
    uint _cap,
    uint _annualizedROI,
    uint _projectedValueUSD,
    uint _timeframeMonths,
    uint _valuePerTokenCents
  ) external {
    VTToken token = new VTToken(
      owner,
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

    // so main contract is always in sync
    Main(mainContractAddress).addFillableAsset(address(token), _cap);

    Asset memory record = Asset({
      owner: owner,
      tokenAddress: address(token),
      filled: false,
      funded: false
    });

    // add the record to the storage array and push the index to the hashmap
    uint id = assets.push(record) - 1;
    ownerToAssetIds[owner].push(id);
    tokenToAssetIds[address(token)] = id;

    // update our records for calculating
    assetProjectedValuesUSD.push(_projectedValueUSD);

    emit AssetRecordCreated(address(token), owner, id);
  }


  /**
   * Allows an Asset Owner to fund the VTToken contract with T tokens to be distributed to investors
   * @dev should be called when the asset is sold, and any amount of T tokens sent in should
   *      equal the projected profit. this amount is divided amongst token owners based on the percentage
   *      of tokens they own. these token owners must claim their profit, it will NOT be automatically
   *      distributed to avoid security concerns
   * NOTE: asset owner must have approved the transfer of T tokens from their wallet to the VTToken contract
   * @param _amountStable Amount of T tokens the owner will fund - MUST equal the asset's projected value recorded
   * @param _assetId Asset id
   */

  function fundAsset(uint _amountStable, uint _assetId) public onlyAssetOwner(_assetId) {
    Asset storage asset = assets[_assetId];

    // sanity check
    require(_amountStable.div(10**18) >= VTToken(asset.tokenAddress).projectedValueUSD());

    // send T tokens from owner wallet to the token contract to be claimed by investors
    require(stableToken.transferFrom(msg.sender, asset.tokenAddress, _amountStable));

    asset.funded = true;

    emit AssetFunded(_assetId, asset.tokenAddress);
  }

  /**
   * Updates the asset record to filled when fully invested
   * @param _assetId Storage array id of the asset
   * NOTE: this method may only be called by the Main contract (in _updateAssetLookup())
   */
  function setAssetFilled(uint _assetId) public validAsset(_assetId) {
    // only the Main contract may call
    require(msg.sender == mainContractAddress);

    assets[_assetId].filled = true;
  }

  /**
   * Calculates and returns the sum of values of all assets (USD)
   */
  function calculateTotalValue() public view returns(uint) {
    return _sumElements(assetProjectedValuesUSD);
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
  function getActiveAssetIdsOf(address owner) public view returns(uint[] memory) {
    return ownerToAssetIds[owner];
  }

  /**
   * Returns the number of active assets
   */
  function getAssetsCount() public view returns(uint) {
    return assets.length - 1; // ignoring first one created at init
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

  /// @dev Sum vector
  /// @param self Storage array containing uint256 type variables
  /// @return sum The sum of all elements, does not check for overflow
  /// https://github.com/Modular-Network/ethereum-libraries/contracts/Array256Lib.sol
  function _sumElements(uint256[] storage self) internal view returns(uint256 sum) {
    assembly {
      mstore(0x60,self_slot)

      for { let i := 0 } lt(i, sload(self_slot)) { i := add(i, 1) } {
        sum := add(sload(add(keccak256(0x60,0x20),i)),sum)
      }
    }
  }
}
