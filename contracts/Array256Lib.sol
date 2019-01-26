pragma solidity 0.5.0;

/**
 * @title Array256 Library [INTERFACE]
 * @author Carlos Beltran <imthatcarlos@gmail.com>
 * NOTE: This is an interface contract to reference the compiled, pre- solidity 0.5 version
 * CHANGED: storage => calldata , public/private => external
 *
 * ORIGINAL:
 * @author Modular Inc, https://modular.network
 *
 * version 1.1.0
 * Copyright (c) 2017 Modular, Inc
 * The MIT License (MIT)
 * https://github.com/Modular-Network/ethereum-libraries/blob/master/LICENSE
 *
 * The Array256 Library provides a few utility functions to work with
 * calldata uint256[] types in place. Modular provides smart contract services
 * and security reviews for contract deployments in addition to working on open
 * source projects in the Ethereum community. Our purpose is to test, document,
 * and deploy reusable code onto the blockchain and improve both security and
 * usability. We also educate non-profits, schools, and other community members
 * about the application of blockchain technology.
 * For further information: Modular.network
 */
library Array256Lib {

  /// @dev Sum vector
  /// @param self calldata external containing uint256 type variables
  /// @return sum The sum of all elements, does not check for overflow
  function sumElements(uint256[] calldata self) external view returns(uint256 sum);

  /// @dev Returns the max value in an external.
  /// @param self calldata external containing uint256 type variables
  /// @return maxValue The highest value in the external
  function getMax(uint256[] calldata self) external view returns(uint256 maxValue);

  /// @dev Returns the minimum value in an external.
  /// @param self calldata external containing uint256 type variables
  /// @return minValue The highest value in the external
  function getMin(uint256[] calldata self) external view returns(uint256 minValue);

  /// @dev Finds the index of a given value in an external
  /// @param self calldata external containing uint256 type variables
  /// @param value The value to search for
  /// @param isSorted True if the external is sorted, false otherwise
  /// @return found True if the value was found, false otherwise
  /// @return index The index of the given value, returns 0 if found is false
  function indexOf(uint256[] calldata self, uint256 value, bool isSorted) external view returns(bool found, uint256 index);

  /// @dev Utility function for heapSort
  /// @param index The index of child node
  /// @return pI The parent node index
  function getParentI(uint256 index) external pure returns (uint256 pI);

  /// @dev Utility function for heapSort
  /// @param index The index of parent node
  /// @return lcI The index of left child
  function getLeftChildI(uint256 index) external pure returns (uint256 lcI);

  /// @dev Sorts given external in place
  /// @param self calldata external containing uint256 type variables
  function heapSort(uint256[] calldata self) external;

  /// @dev Removes duplicates from a given external.
  /// @param self calldata external containing uint256 type variables
  function uniq(uint256[] calldata self) external returns (uint256 length);
}
