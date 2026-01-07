// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {
    INonfungiblePositionManager
} from "./interfaces/INonfungiblePositionManagerCompat.sol";
import {
    IERC721Enumerable
} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IV3Claimer} from "./interfaces/IV3Claimer.sol";

/// @title Uniswap V3 Position Claimer
/// @notice Helper contract to efficiently close (collect fees + remove liquidity + burn) Uniswap V3 positions
/// @dev Implements UUPS upgradeable pattern for future improvements
/// @dev Only closes positions owned by msg.sender to ensure security
contract V3Claimer is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IV3Claimer
{
    /// @notice Constructor that disables initializers to prevent implementation initialization
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract and sets up ownership
    /// @dev Can only be called once due to initializer modifier
    function initialize() external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /// @notice Internal function required by UUPS pattern to authorize upgrades
    /// @dev Only the contract owner can upgrade to a new implementation
    /// @param newImplementation Address of the new implementation contract
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /// @notice Internal function to close a single Uniswap V3 position
    /// @dev Performs three steps: decrease liquidity, collect tokens, and burn NFT
    /// @dev Uses try-catch to handle failures gracefully without reverting the entire transaction
    /// @param npm The Uniswap V3 NonfungiblePositionManager contract
    /// @param recipient Address to receive the collected tokens
    /// @param deadline Timestamp by which the transaction must be executed
    /// @param tokenId The ID of the position NFT to close
    /// @return success True if all operations succeeded, false otherwise
    function _closePosition(
        INonfungiblePositionManager npm,
        address recipient,
        uint256 deadline,
        uint256 tokenId
    ) private returns (bool) {
        (, , , , , , , uint128 liq, , , , ) = npm.positions(tokenId);

        // 1) Remove *all* liquidity if any.
        if (liq > 0) {
            try
                npm.decreaseLiquidity(
                    INonfungiblePositionManager.DecreaseLiquidityParams({
                        tokenId: tokenId,
                        liquidity: liq,
                        amount0Min: 0,
                        amount1Min: 0,
                        deadline: deadline
                    })
                )
            {} catch {
                return false;
            }
        }

        // 2) Collect everything owed (includes fees + withdrawn amounts accounted to tokensOwed).
        try
            npm.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: tokenId,
                    recipient: recipient,
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            )
        {} catch {
            return false;
        }
        // 3) Burn the position NFT (requires liquidity == 0 and tokens collected).
        try npm.burn(tokenId) {} catch {
            return false;
        }
        return true;
    }

    /// @notice Internal function to close multiple positions in a batch
    /// @dev Iterates through tokenIds and attempts to close each position
    /// @param npm The Uniswap V3 NonfungiblePositionManager contract
    /// @param recipient Address to receive the collected tokens from all positions
    /// @param deadline Timestamp by which the transaction must be executed
    /// @param tokenIds Array of position NFT IDs to close
    /// @return success Array of boolean values indicating success/failure for each position
    function _closePositions(
        INonfungiblePositionManager npm,
        address recipient,
        uint256 deadline,
        uint256[] memory tokenIds
    ) private returns (bool[] memory success) {
        uint256 len = tokenIds.length;
        success = new bool[](len);

        for (uint256 i = 0; i < len; i++) {
            success[i] = _closePosition(npm, recipient, deadline, tokenIds[i]);
        }
        return success;
    }

    /// @notice Internal function to close the first N positions owned by msg.sender
    /// @dev Uses ERC721Enumerable's tokenOfOwnerByIndex to enumerate positions
    /// @dev If N exceeds balance, only closes existing positions
    /// @param npmAddress Address of the Uniswap V3 NonfungiblePositionManager
    /// @param recipient Address to receive the collected tokens
    /// @param deadline Timestamp by which the transaction must be executed
    /// @param n Maximum number of positions to close (use type(uint256).max for all)
    /// @return Array of boolean values indicating success/failure for each position
    function _closeFirstN(
        address npmAddress,
        address recipient,
        uint256 deadline,
        uint256 n
    ) private returns (bool[] memory) {
        // NonfungiblePositionManager on Uniswap V3 main deployments implements tokenOfOwnerByIndex.
        // If you point this at a manager that doesn't, use closeMany() instead.
        uint256 bal = IERC721Enumerable(npmAddress).balanceOf(msg.sender);
        if (n > bal) {
            n = bal;
        }
        INonfungiblePositionManager npm = INonfungiblePositionManager(
            npmAddress
        );

        uint256[] memory tokenIds;
        {
            // Worst case 3 calls per position (decreaseLiquidity + collect + burn).
            tokenIds = new uint256[](n);
            while (n > 0) {
                n--;
                tokenIds[n] = IERC721Enumerable(npmAddress).tokenOfOwnerByIndex(
                    msg.sender,
                    n
                );
            }
        }
        return _closePositions(npm, recipient, deadline, tokenIds);
    }

    /// @notice Close ALL Uniswap V3 positions owned by msg.sender with custom parameters
    /// @dev Requires the Position Manager to implement ERC721Enumerable for position enumeration
    /// @param npmAddress Address of the Uniswap V3 NonfungiblePositionManager contract
    /// @param recipient Address where collected tokens (fees + liquidity) will be sent
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return Array of boolean flags indicating success (true) or failure (false) for each position
    function closeAll(
        address npmAddress,
        address recipient,
        uint256 deadline
    ) external returns (bool[] memory) {
        if (block.timestamp > deadline) revert DeadlinePassed();
        return _closeFirstN(npmAddress, recipient, deadline, type(uint256).max);
    }

    /// @notice Close ALL positions with default parameters (recipient = msg.sender, deadline = now + 1 hour)
    /// @dev Convenience function that uses sensible defaults
    /// @param npmAddress Address of the Uniswap V3 NonfungiblePositionManager contract
    /// @return Array of boolean flags indicating success/failure for each position
    function closeAll(address npmAddress) external returns (bool[] memory) {
        return
            _closeFirstN(
                npmAddress,
                msg.sender,
                block.timestamp + 1 hours,
                type(uint256).max
            );
    }

    /// @notice Close the first N positions owned by msg.sender with custom parameters
    /// @dev Useful for gas optimization when you have many positions but want to close them gradually
    /// @param npmAddress Address of the Uniswap V3 NonfungiblePositionManager contract
    /// @param recipient Address where collected tokens will be sent
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param n Maximum number of positions to close
    /// @return Array of boolean flags indicating success/failure for each position
    function closeFirstN(
        address npmAddress,
        address recipient,
        uint256 deadline,
        uint256 n
    ) external returns (bool[] memory) {
        if (block.timestamp > deadline) revert DeadlinePassed();
        return _closeFirstN(npmAddress, recipient, deadline, n);
    }

    /// @notice Close the first N positions with default parameters (recipient = msg.sender, deadline = now + 1 hour)
    /// @dev Convenience function for gas-controlled batch closing
    /// @param npmAddress Address of the Uniswap V3 NonfungiblePositionManager contract
    /// @param n Maximum number of positions to close
    /// @return Array of boolean flags indicating success/failure for each position
    function closeFirstN(
        address npmAddress,
        uint256 n
    ) external returns (bool[] memory) {
        return
            _closeFirstN(npmAddress, msg.sender, block.timestamp + 1 hours, n);
    }

    /// @notice Close specific positions by providing their token IDs with custom parameters
    /// @dev Safer for gas estimation and works even if Position Manager doesn't support enumeration
    /// @dev Allows precise control over which positions to close
    /// @param npmAddress Address of the Uniswap V3 NonfungiblePositionManager contract
    /// @param recipient Address where collected tokens will be sent
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param tokenIds Array of position NFT token IDs to close
    /// @return Array of boolean flags indicating success/failure for each position (same order as tokenIds)
    function closeMany(
        address npmAddress,
        address recipient,
        uint256 deadline,
        uint256[] calldata tokenIds
    ) external returns (bool[] memory) {
        if (block.timestamp > deadline) revert DeadlinePassed();
        INonfungiblePositionManager npm = INonfungiblePositionManager(
            npmAddress
        );
        return _closePositions(npm, recipient, deadline, tokenIds);
    }

    /// @notice Close specific positions with default parameters (recipient = msg.sender, deadline = now + 1 hour)
    /// @dev Convenience function for closing known positions with sensible defaults
    /// @param npmAddress Address of the Uniswap V3 NonfungiblePositionManager contract
    /// @param tokenIds Array of position NFT token IDs to close
    /// @return Array of boolean flags indicating success/failure for each position
    function closeMany(
        address npmAddress,
        uint256[] calldata tokenIds
    ) external returns (bool[] memory) {
        INonfungiblePositionManager npm = INonfungiblePositionManager(
            npmAddress
        );
        return
            _closePositions(
                npm,
                msg.sender,
                block.timestamp + 1 hours,
                tokenIds
            );
    }
}
