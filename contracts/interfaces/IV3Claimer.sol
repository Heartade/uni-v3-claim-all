// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

/// @title IV3Claimer Interface
/// @notice Interface for the Uniswap V3 Position Claimer contract
/// @dev Defines functions for batch closing Uniswap V3 liquidity positions
interface IV3Claimer {
    /// @notice Error thrown when a transaction deadline has passed
    error DeadlinePassed();
    
    /// @notice Error thrown when attempting enumeration on a non-enumerable contract
    error NotEnumerable();
    
    /// @notice Close all positions owned by msg.sender with custom parameters
    /// @param npmAddress Address of the Uniswap V3 NonfungiblePositionManager
    /// @param recipient Address to receive collected tokens
    /// @param deadline Transaction deadline timestamp
    /// @return Array of success flags for each position
    function closeAll(
        address npmAddress,
        address recipient,
        uint256 deadline
    ) external returns (bool[] memory);
    
    /// @notice Close all positions with default parameters
    /// @param npmAddress Address of the Uniswap V3 NonfungiblePositionManager
    /// @return Array of success flags for each position
    function closeAll(address npmAddress) external returns (bool[] memory);
    
    /// @notice Close the first N positions with custom parameters
    /// @param npmAddress Address of the Uniswap V3 NonfungiblePositionManager
    /// @param recipient Address to receive collected tokens
    /// @param deadline Transaction deadline timestamp
    /// @param n Maximum number of positions to close
    /// @return Array of success flags for each position
    function closeFirstN(
        address npmAddress,
        address recipient,
        uint256 deadline,
        uint256 n
    ) external returns (bool[] memory);
    
    /// @notice Close the first N positions with default parameters
    /// @param npmAddress Address of the Uniswap V3 NonfungiblePositionManager
    /// @param n Maximum number of positions to close
    /// @return Array of success flags for each position
    function closeFirstN(
        address npmAddress,
        uint256 n
    ) external returns (bool[] memory);
    
    /// @notice Close specific positions by token IDs with custom parameters
    /// @param npmAddress Address of the Uniswap V3 NonfungiblePositionManager
    /// @param recipient Address to receive collected tokens
    /// @param deadline Transaction deadline timestamp
    /// @param tokenIds Array of position token IDs to close
    /// @return Array of success flags for each position
    function closeMany(
        address npmAddress,
        address recipient,
        uint256 deadline,
        uint256[] memory tokenIds
    ) external returns (bool[] memory);
    
    /// @notice Close specific positions with default parameters
    /// @param npmAddress Address of the Uniswap V3 NonfungiblePositionManager
    /// @param tokenIds Array of position token IDs to close
    /// @return Array of success flags for each position
    function closeMany(
        address npmAddress,
        uint256[] memory tokenIds
    ) external returns (bool[] memory);
}
