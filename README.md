# Uniswap V3 Position Claimer (uni-v3-claim-all)

A smart contract helper for efficiently closing (collecting fees + removing liquidity + burning) multiple Uniswap V3 positions in a single transaction. Built with UUPS upgradeability pattern for future improvements.

## Overview

This project provides a gas-efficient way to manage Uniswap V3 liquidity positions by batching operations. Instead of manually calling `decreaseLiquidity`, `collect`, and `burn` for each position individually, users can close all their positions or specific positions in one transaction.

### Features

- **Batch Operations**: Close all positions or specific positions in a single transaction
- **UUPS Upgradeable**: Contract can be upgraded by the owner to add new features
- **Flexible Parameters**: Configure recipient addresses and deadlines
- **Safe Execution**: Continues processing even if individual positions fail
- **Gas Efficient**: Reduces transaction overhead by batching operations

### Key Functions

- `closeAll()` - Close all Uniswap V3 positions owned by `msg.sender`
- `closeMany()` - Close specific positions by providing token IDs
- Both functions have overloads for custom recipients and deadlines

## Project Structure

```
contracts/
├── V3Claimer.sol                    # Main contract implementation
├── UUPSProxy.sol                    # Proxy contract for upgradeability
├── MockNonfungiblePositionManager.sol # Mock for testing
└── interfaces/
    ├── IV3Claimer.sol               # Interface definition
    ├── INonfungiblePositionManagerCompat.sol
    └── IMulticallCompat.sol
ignition/
└── modules/
    └── V3Claimer.ts                 # Deployment module
test/
└── V3Claimer.ts                     # Comprehensive test suite
```

## Installation

```shell
# Clone the repository
git clone <repository-url>
cd uni-v3-claim-all

# Install dependencies
pnpm install
```

## Contract Details

### V3Claimer Contract

The `V3Claimer` contract is an upgradeable helper that batches Uniswap V3 position closing operations.

#### Main Functions

**closeAll(address npmAddress) → bool[]**
- Closes all Uniswap V3 positions owned by `msg.sender`
- Uses default recipient (`msg.sender`) and deadline (1 hour from now)
- Returns array of success flags for each position

**closeAll(address npmAddress, address recipient, uint256 deadline) → bool[]**
- Closes all positions with custom recipient and deadline
- Useful for sending collected tokens to a different address

**closeMany(address npmAddress, uint256[] tokenIds) → bool[]**
- Closes specific positions by token IDs
- Uses default recipient and deadline
- More gas-efficient when you know which positions to close

**closeMany(address npmAddress, address recipient, uint256 deadline, uint256[] tokenIds) → bool[]**
- Full control over positions, recipient, and deadline

#### How It Works

For each position, the contract:
1. **Decreases Liquidity**: Removes all liquidity from the position
2. **Collects Tokens**: Collects all owed tokens (fees + withdrawn liquidity)
3. **Burns NFT**: Burns the position NFT

If any step fails for a position, it returns `false` for that position and continues with the next one.

### Upgradeability

The contract uses the UUPS (Universal Upgradeable Proxy Standard) pattern:
- **Proxy Contract**: `UUPSProxy.sol` - Delegates calls to implementation
- **Implementation**: `V3Claimer.sol` - Contains the actual logic
- **Owner Control**: Only the owner can upgrade to new implementations

## Development

### Compiling Contracts

```shell
pnpm hardhat compile
```

### Running Tests

Run all tests:
```shell
pnpm hardhat test
```

Run only Node.js tests:
```shell
pnpm hardhat test nodejs
```

Run only Solidity tests (if any):
```shell
pnpm hardhat test solidity
```

The test suite includes:
- Deployment and initialization tests
- Function parameter validation (deadline checks)
- Batch closing operations
- Upgradeability tests
- Access control tests

## Deployment

### Deploy to Local Network

```shell
npx hardhat ignition deploy ignition/modules/V3Claimer.ts
```

### Deploy to Sepolia Testnet

First, set up your private key:

```shell
# Using hardhat-keystore (recommended)
npx hardhat keystore set SEPOLIA_PRIVATE_KEY

# Or set as environment variable
export SEPOLIA_PRIVATE_KEY=your_private_key_here
```

Set your RPC URL:
```shell
npx hardhat keystore set SEPOLIA_RPC_URL
# Or
export SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
```

Deploy:
```shell
npx hardhat ignition deploy ignition/modules/V3Claimer.ts --network sepolia
```

### Deploy to Production

For production deployments:
1. Review and audit all contract code
2. Configure appropriate RPC endpoints in `hardhat.config.ts`
3. Set up secure key management
4. Deploy using Ignition with appropriate network flag
5. Verify contracts on block explorer

## Usage Example

### Using Web3 Library

```typescript
import { createPublicClient, createWalletClient, http } from 'viem';
import { mainnet } from 'viem/chains';

// Your deployed proxy address
const V3_CLAIMER_ADDRESS = '0x...';

// Uniswap V3 Position Manager on Ethereum Mainnet
const NPM_ADDRESS = '0xC36442b4a4522E871399CD717aBDD847Ab11FE88';

const walletClient = createWalletClient({
  chain: mainnet,
  transport: http()
});

// Close all your positions
const { request } = await publicClient.simulateContract({
  address: V3_CLAIMER_ADDRESS,
  abi: V3ClaimerABI,
  functionName: 'closeAll',
  args: [NPM_ADDRESS],
  account: yourAccount
});

const hash = await walletClient.writeContract(request);
```

### Using ethers.js

```javascript
const v3Claimer = new ethers.Contract(
  V3_CLAIMER_ADDRESS,
  V3ClaimerABI,
  signer
);

// Close specific positions
const tokenIds = [12345, 12346, 12347];
const tx = await v3Claimer.closeMany(NPM_ADDRESS, tokenIds);
await tx.wait();
console.log('Positions closed!');
```

## Uniswap V3 Position Manager Addresses

- **Ethereum Mainnet**: `0xC36442b4a4522E871399CD717aBDD847Ab11FE88`
- **Polygon**: `0xC36442b4a4522E871399CD717aBDD847Ab11FE88`
- **Optimism**: `0xC36442b4a4522E871399CD717aBDD847Ab11FE88`
- **Arbitrum**: `0xC36442b4a4522E871399CD717aBDD847Ab11FE88`
- **Base**: `0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1`

## Security Considerations

- **Audits**: This contract has not been audited. Use at your own risk.
- **Permissions**: The contract only closes positions owned by `msg.sender`
- **Deadline**: Always set appropriate deadlines to prevent stale transactions
- **Failures**: Individual position failures don't revert the entire transaction
- **Upgradeability**: Only the owner can upgrade the implementation

## Built With

- [Hardhat 3](https://hardhat.org/) - Development environment
- [Viem](https://viem.sh/) - TypeScript interface for Ethereum
- [OpenZeppelin Contracts](https://www.openzeppelin.com/contracts) - Upgradeable contract standards
- [Node.js Test Runner](https://nodejs.org/api/test.html) - Native testing framework

## License

GPL-2.0-or-later

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

- Uniswap Labs for the V3 Protocol
- OpenZeppelin for secure contract libraries



After setting the variable, you can run the deployment with the Sepolia network:

```shell
npx hardhat ignition deploy --network sepolia ignition/modules/Counter.ts
```
