# V3Claimer Contract Architecture

## Overview

The V3Claimer is an upgradeable smart contract designed to efficiently manage Uniswap V3 liquidity positions by batching multiple operations into single transactions.

## Architecture Pattern: UUPS Proxy

The contract uses the **Universal Upgradeable Proxy Standard (UUPS)** pattern, which provides:

- **Upgradeability**: Logic can be updated without changing the contract address
- **Gas Efficiency**: Upgrade logic stored in implementation, not proxy
- **Ownership Control**: Only the contract owner can perform upgrades

### Contract Structure

```
┌─────────────────┐
│   User/DApp     │
└────────┬────────┘
         │ Interacts with
         ▼
┌─────────────────┐
│   UUPSProxy     │ ◄── Proxy Contract (Immutable Address)
│  (ERC1967Proxy) │     - Stores state
└────────┬────────┘     - Delegates calls to implementation
         │ delegatecall
         ▼
┌─────────────────┐
│   V3Claimer     │ ◄── Implementation Contract (Upgradeable)
│ (Implementation)│     - Contains all logic
└─────────────────┘     - Can be replaced
```

## Core Components

### 1. V3Claimer.sol (Implementation)

The main contract containing all business logic:

**Inheritance Hierarchy:**
```
V3Claimer
├── Initializable (OpenZeppelin)
├── OwnableUpgradeable (OpenZeppelin)
├── UUPSUpgradeable (OpenZeppelin)
└── IV3Claimer (Custom Interface)
```

**Key Features:**
- **No Constructor State**: Uses `initialize()` instead of constructor
- **Access Control**: Only owner can upgrade
- **Safe Execution**: Try-catch blocks prevent individual failures from reverting entire batch

### 2. UUPSProxy.sol (Proxy)

Thin wrapper around OpenZeppelin's ERC1967Proxy:

```solidity
contract UUPSProxy is ERC1967Proxy {
    constructor(address _logic, bytes memory _data) 
        payable ERC1967Proxy(_logic, _data) {}
    
    function implementation() external view returns (address);
    receive() external payable;
}
```

**Purpose:**
- Provides stable address for users
- Stores all contract state
- Forwards all calls to implementation via `delegatecall`

### 3. Interfaces

**IV3Claimer.sol**: Defines the public API and custom errors

**INonfungiblePositionManagerCompat.sol**: Interface for Uniswap V3 Position Manager

**IMulticallCompat.sol**: Interface for batched calls (future use)

## State Management

### Storage Layout

All state is stored in the **proxy contract**:

```
Proxy Storage:
├── ERC1967 Implementation Slot
│   └── Address of current V3Claimer implementation
├── OwnableUpgradeable Storage
│   └── Owner address
└── (Future upgrade storage slots)
```

The implementation contract is **stateless** - all state modifications happen in proxy context via `delegatecall`.

## Function Flow

### Example: Closing All Positions

```
User calls: proxy.closeAll(npmAddress)
                    ↓
1. Proxy receives call
                    ↓
2. Proxy performs delegatecall to implementation
                    ↓
3. Implementation executes in proxy's context:
   ├── _closeFirstN() - Enumerate positions
   │   ├── Get balance from NPM
   │   └── Build tokenIds array
   ├── _closePositions() - Iterate through positions
   │   └── For each position:
   │       └── _closePosition()
   │           ├── decreaseLiquidity() - Remove liquidity
   │           ├── collect() - Collect tokens
   │           └── burn() - Burn NFT
                    ↓
4. Return success array to user
```

### Error Handling Strategy

The contract uses **soft failures**:

```solidity
try npm.decreaseLiquidity(...) {
    // Success
} catch {
    return false;  // Mark as failed, continue with next position
}
```

**Benefits:**
- Partial failures don't revert entire transaction
- User gets feedback on which positions succeeded/failed
- More gas-efficient than reverting and retrying

## Upgrade Process

### How Upgrades Work

1. **Deploy New Implementation**
   ```bash
   npx hardhat run scripts/deploy-new-implementation.ts
   ```

2. **Call upgradeToAndCall() on Proxy**
   ```solidity
   // Only owner can call this
   proxy.upgradeToAndCall(newImplementation, "");
   ```

3. **Proxy Updates Implementation Slot**
   - Old implementation reference replaced
   - All future calls use new implementation
   - Existing state preserved

### Upgrade Safety

**Protected by:**
- `_authorizeUpgrade()` requires `onlyOwner`
- OpenZeppelin's UUPS safeguards prevent bricking
- Initialization protection via `_disableInitializers()`

**Best Practices:**
- Test upgrades on testnet first
- Verify storage layout compatibility
- Consider using transparent proxy for even more safety

## Position Closing Logic

### Three-Step Process

Each position requires three Uniswap V3 operations:

#### 1. Decrease Liquidity
```solidity
npm.decreaseLiquidity({
    tokenId: tokenId,
    liquidity: entireLiquidity,  // Remove 100%
    amount0Min: 0,               // Accept any amount (slippage)
    amount1Min: 0,
    deadline: deadline
})
```

**Effect:** Removes liquidity from the position, adding tokens to `tokensOwed0/1`

#### 2. Collect Tokens
```solidity
npm.collect({
    tokenId: tokenId,
    recipient: recipient,
    amount0Max: type(uint128).max,  // Collect everything
    amount1Max: type(uint128).max
})
```

**Effect:** Sends all owed tokens (fees + withdrawn liquidity) to recipient

#### 3. Burn NFT
```solidity
npm.burn(tokenId)
```

**Effect:** Burns the position NFT (only works if liquidity = 0 and tokens collected)

## Gas Optimization

### Enumeration Strategy

**Two approaches supported:**

1. **ERC721Enumerable (closeAll/closeFirstN)**
   - Uses `tokenOfOwnerByIndex()` to enumerate positions
   - Standard on mainnet Uniswap deployments
   - More expensive per position
   - Convenient (no need to track token IDs)

2. **Direct Token IDs (closeMany)**
   - User provides exact token IDs
   - Skips enumeration overhead
   - Better gas efficiency
   - Works on non-enumerable implementations

### Batch Size Considerations

```
Gas Cost Estimates (approximate):
├── Base transaction cost: ~21,000 gas
├── Proxy overhead: ~2,500 gas
├── Per position:
│   ├── Enumeration: ~5,000 gas
│   ├── decreaseLiquidity: ~100,000 gas
│   ├── collect: ~50,000 gas
│   └── burn: ~30,000 gas
│   Total: ~185,000 gas per position
└── Block gas limit consideration
```

**Recommendation:** Close 5-10 positions per transaction to stay within comfortable gas limits.

## Security Considerations

### Access Control

- **Owner-only upgrades**: Prevents unauthorized modifications
- **msg.sender enforcement**: Only closes positions owned by caller
- **No external funds handling**: Contract doesn't hold user funds

### Attack Vectors Mitigated

1. **Reentrancy**: Not applicable (no external calls with state changes afterward)
2. **Unauthorized access**: Positions can only be closed by their owner
3. **Upgrade attacks**: UUPS + Ownable ensures only owner can upgrade
4. **Initialization attacks**: `_disableInitializers()` in constructor

### Risks

1. **Smart contract risk**: Bugs in implementation could affect users
2. **Upgrade risk**: Malicious or buggy upgrade could harm users
3. **Uniswap dependency**: Relies on Uniswap V3 contracts behaving correctly
4. **No formal audit**: Use at your own risk

## Testing Strategy

### Test Coverage

```typescript
describe("V3Claimer", () => {
  // Unit Tests
  ├── Deployment & Initialization
  ├── closeAll() functionality
  ├── closeMany() functionality
  ├── closeFirstN() functionality
  ├── Deadline validation
  ├── Upgradeability
  └── Access control

  // Integration Tests (with Mock NPM)
  ├── Multiple positions
  ├── Empty token arrays
  ├── Failed operations
  └── Gas consumption
});
```

### Mock Contracts

**MockNonfungiblePositionManager.sol** simulates:
- ERC721Enumerable interface
- Position management (mint, decrease, collect, burn)
- Realistic state transitions

## Future Enhancements

Possible upgrades without changing proxy:

1. **Multicall Support**: Batch with other operations
2. **Gas Optimization**: More efficient enumeration
3. **Emergency Pause**: Circuit breaker functionality
4. **Event Emissions**: Better tracking and monitoring
5. **Fee Collection**: Optional service fee
6. **Slippage Protection**: Configurable min amounts
7. **Time-based Batching**: Automatically batch operations

## References

- [EIP-1967: Proxy Storage Slots](https://eips.ethereum.org/EIPS/eip-1967)
- [OpenZeppelin UUPS Proxies](https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable)
- [Uniswap V3 Core](https://docs.uniswap.org/contracts/v3/overview)
- [Hardhat Ignition](https://hardhat.org/ignition/docs/getting-started)
