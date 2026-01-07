import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Hardhat Ignition module for deploying the V3Claimer contract with UUPS proxy pattern
 *
 * This module deploys:
 * 1. V3Claimer implementation contract (contains the actual logic)
 * 2. UUPSProxy contract (delegates calls to implementation)
 *
 * The proxy address is what users/frontends should interact with.
 * The implementation can be upgraded later by the contract owner.
 *
 * Usage:
 *   npx hardhat ignition deploy ignition/modules/V3Claimer.ts --network <network-name>
 *
 * @returns Object containing both proxy and implementation contract references
 */
const V3ClaimerModule = buildModule("V3ClaimerModule", (m) => {
  // Deploy the implementation contract
  const implementation = m.contract("V3Claimer");

  // Encode the initialize() function call
  const initializeData = m.encodeFunctionCall(implementation, "initialize", []);

  // Deploy the proxy contract with the implementation address and initialization data
  const proxy = m.contract("UUPSProxy", [implementation, initializeData]);

  // Return the proxy as the main contract instance
  // Users will interact with the proxy address, which delegates to the implementation
  return { proxy, implementation };
});

export default V3ClaimerModule;
