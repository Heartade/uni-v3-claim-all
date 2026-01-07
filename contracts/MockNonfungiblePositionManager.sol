// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {
    IERC721Enumerable
} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @notice Mock Uniswap V3 Position Manager for testing purposes
contract MockNonfungiblePositionManager is ERC721, IERC721Enumerable {
    uint256 private _tokenIdCounter;

    mapping(uint256 => Position) public positions;
    mapping(address => uint256[]) private _ownedTokens;
    mapping(uint256 => uint256) private _ownedTokensIndex;
    uint256[] private _allTokens;
    mapping(uint256 => uint256) private _allTokensIndex;

    struct Position {
        uint96 nonce;
        address operator;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    constructor() ERC721("Mock Uniswap V3 Positions", "UNI-V3-POS") {}

    function mint(
        address to,
        uint256 liquidityAmount
    ) external returns (uint256 tokenId) {
        tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);

        positions[tokenId] = Position({
            nonce: 0,
            operator: address(0),
            token0: address(0),
            token1: address(0),
            fee: 3000,
            tickLower: -887220,
            tickUpper: 887220,
            liquidity: uint128(liquidityAmount),
            feeGrowthInside0LastX128: 0,
            feeGrowthInside1LastX128: 0,
            tokensOwed0: 0,
            tokensOwed1: 0
        });
    }

    function decreaseLiquidity(
        DecreaseLiquidityParams calldata params
    ) external returns (uint256 amount0, uint256 amount1) {
        require(_ownerOf(params.tokenId) == msg.sender, "Not owner");
        Position storage pos = positions[params.tokenId];
        require(pos.liquidity >= params.liquidity, "Insufficient liquidity");

        pos.liquidity -= params.liquidity;
        pos.tokensOwed0 += params.liquidity / 2;
        pos.tokensOwed1 += params.liquidity / 2;

        return (params.liquidity / 2, params.liquidity / 2);
    }

    function collect(
        CollectParams calldata params
    ) external returns (uint256 amount0, uint256 amount1) {
        require(_ownerOf(params.tokenId) == msg.sender, "Not owner");
        Position storage pos = positions[params.tokenId];

        amount0 = pos.tokensOwed0;
        amount1 = pos.tokensOwed1;

        pos.tokensOwed0 = 0;
        pos.tokensOwed1 = 0;

        return (amount0, amount1);
    }

    function burn(uint256 tokenId) external {
        require(_ownerOf(tokenId) == msg.sender, "Not owner");
        Position storage pos = positions[tokenId];
        require(pos.liquidity == 0, "Liquidity not zero");
        require(pos.tokensOwed0 == 0 && pos.tokensOwed1 == 0, "Tokens owed");

        _burn(tokenId);
        delete positions[tokenId];
    }

    // ERC721Enumerable implementation
    function tokenOfOwnerByIndex(
        address owner,
        uint256 index
    ) public view override returns (uint256) {
        require(index < balanceOf(owner), "Index out of bounds");
        return _ownedTokens[owner][index];
    }

    function totalSupply() public view override returns (uint256) {
        return _allTokens.length;
    }

    function tokenByIndex(
        uint256 index
    ) public view override returns (uint256) {
        require(index < totalSupply(), "Index out of bounds");
        return _allTokens[index];
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721Enumerable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // Override _update to maintain enumeration
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);

        if (from == address(0)) {
            // Mint
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            // Transfer
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }

        if (to == address(0)) {
            // Burn
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            // Transfer or Mint
            _addTokenToOwnerEnumeration(to, tokenId);
        }

        return super._update(to, tokenId, auth);
    }

    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        // this is called before super._update so balance is not updated yet
        uint256 length = balanceOf(to);
        _ownedTokens[to].push(tokenId);
        _ownedTokensIndex[tokenId] = length;
    }

    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    function _removeTokenFromOwnerEnumeration(
        address from,
        uint256 tokenId
    ) private {
        // this is called before super._update so balance is not updated yet
        uint256 lastTokenIndex = balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];
            _ownedTokens[from][tokenIndex] = lastTokenId;
            _ownedTokensIndex[lastTokenId] = tokenIndex;
        }

        delete _ownedTokensIndex[tokenId];
        _ownedTokens[from].pop();
    }

    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId;
        _allTokensIndex[lastTokenId] = tokenIndex;

        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}
