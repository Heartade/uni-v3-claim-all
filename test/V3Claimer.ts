import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { network } from "hardhat";
import { parseAbi, encodeFunctionData, Address } from "viem";

describe("V3Claimer", async function () {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [deployer, user1, user2] = await viem.getWalletClients();

  // Helper to deploy the V3Claimer proxy
  async function deployV3Claimer() {
    const implementation = await viem.deployContract("V3Claimer");
    const initData = encodeFunctionData({
      abi: parseAbi(["function initialize()"]),
      functionName: "initialize",
    });
    const proxy = await viem.deployContract("UUPSProxy", [
      implementation.address,
      initData,
    ]);
    return viem.getContractAt("V3Claimer", proxy.address);
  }

  // Mock Uniswap V3 Position Manager for testing
  async function deployMockNPM() {
    const mockNPM = await viem.deployContract("MockNonfungiblePositionManager");
    return mockNPM;
  }

  describe("Deployment", function () {
    it("Should deploy and initialize correctly", async function () {
      const claimer = await deployV3Claimer();
      assert.ok(claimer.address);

      // Check that owner is set correctly
      const owner = await claimer.read.owner();
      assert.equal(owner.toLowerCase(), deployer.account.address.toLowerCase());
    });

    it("Should not allow re-initialization", async function () {
      const claimer = await deployV3Claimer();

      // Try to initialize again - should revert
      await assert.rejects(
        async () => await claimer.write.initialize(),
        /InvalidInitialization|Initializable: contract is already initialized/,
      );
    });
  });

  describe("closeAll", function () {
    it("Should revert if deadline has passed", async function () {
      const claimer = await deployV3Claimer();
      const mockNPM = await deployMockNPM();

      const pastDeadline = BigInt(Math.floor(Date.now() / 1000) - 3600); // 1 hour ago

      await assert.rejects(
        async () =>
          await claimer.write.closeAll([
            mockNPM.address,
            user1.account.address,
            pastDeadline,
          ]),
        /DeadlinePassed/,
      );
    });

    it("Should call closeAll with default parameters", async function () {
      const claimer = await deployV3Claimer();
      const mockNPM = await deployMockNPM();

      // Create a mock position for the deployer
      await mockNPM.write.mint([deployer.account.address, 1n]);

      const result = await claimer.write.closeAll([mockNPM.address]);
      assert.ok(result);
    });

    it("Should handle multiple positions", async function () {
      const claimer = await deployV3Claimer();
      const mockNPM = await deployMockNPM();

      // Create multiple mock positions
      await mockNPM.write.mint([deployer.account.address, 1n]);
      await mockNPM.write.mint([deployer.account.address, 2n]);
      await mockNPM.write.mint([deployer.account.address, 3n]);

      const futureDeadline = BigInt(Math.floor(Date.now() / 1000) + 3600);
      const result = await claimer.write.closeAll([
        mockNPM.address,
        deployer.account.address,
        futureDeadline,
      ]);

      assert.ok(result);
    });
  });

  describe("closeMany", function () {
    it("Should close specific token IDs", async function () {
      const claimer = await deployV3Claimer();
      const mockNPM = await deployMockNPM();

      // Create mock positions
      await mockNPM.write.mint([deployer.account.address, 1n]);
      await mockNPM.write.mint([deployer.account.address, 2n]);
      await mockNPM.write.mint([deployer.account.address, 3n]);

      const futureDeadline = BigInt(Math.floor(Date.now() / 1000) + 3600);
      const tokenIds = [1n, 3n]; // Only close tokens 1 and 3

      const result = await claimer.write.closeMany([
        mockNPM.address,
        deployer.account.address,
        futureDeadline,
        tokenIds,
      ]);

      assert.ok(result);
    });

    it("Should close with default parameters", async function () {
      const claimer = await deployV3Claimer();
      const mockNPM = await deployMockNPM();

      await mockNPM.write.mint([deployer.account.address, 1n]);

      const result = await claimer.write.closeMany([mockNPM.address, [1n]]);

      assert.ok(result);
    });

    it("Should revert if deadline has passed for closeMany", async function () {
      const claimer = await deployV3Claimer();
      const mockNPM = await deployMockNPM();

      const pastDeadline = BigInt(Math.floor(Date.now() / 1000) - 3600);

      await assert.rejects(
        async () =>
          await claimer.write.closeMany([
            mockNPM.address,
            user1.account.address,
            pastDeadline,
            [1n],
          ]),
        /DeadlinePassed/,
      );
    });

    it("Should handle empty token ID array", async function () {
      const claimer = await deployV3Claimer();
      const mockNPM = await deployMockNPM();

      const futureDeadline = BigInt(Math.floor(Date.now() / 1000) + 3600);
      const result = await claimer.write.closeMany([
        mockNPM.address,
        deployer.account.address,
        futureDeadline,
        [],
      ]);

      assert.ok(result);
    });
  });

  describe("Upgradeability", function () {
    it("Should allow owner to upgrade", async function () {
      const claimer = await deployV3Claimer();

      // Deploy a new implementation
      const newImplementation = await viem.deployContract("V3Claimer");

      // Upgrade should succeed for owner
      const hash = await claimer.write.upgradeToAndCall([
        newImplementation.address,
        "0x",
      ]);

      assert.ok(hash);
    });

    it("Should not allow non-owner to upgrade", async function () {
      const claimer = await deployV3Claimer();
      const newImplementation = await viem.deployContract("V3Claimer");

      const claimerAsUser = await viem.getContractAt(
        "V3Claimer",
        claimer.address,
        { client: { wallet: user1 } },
      );

      await assert.rejects(
        async () =>
          await claimerAsUser.write.upgradeToAndCall([
            newImplementation.address,
            "0x",
          ]),
        /OwnableUnauthorizedAccount/,
      );
    });
  });

  describe("Ownership", function () {
    it("Should transfer ownership correctly", async function () {
      const claimer = await deployV3Claimer();

      // Transfer ownership
      await claimer.write.transferOwnership([user1.account.address]);

      const newOwner = await claimer.read.owner();
      assert.equal(newOwner.toLowerCase(), user1.account.address.toLowerCase());
    });

    it("Should not allow non-owner to transfer ownership", async function () {
      const claimer = await deployV3Claimer();

      const claimerAsUser = await viem.getContractAt(
        "V3Claimer",
        claimer.address,
        { client: { wallet: user1 } },
      );

      await assert.rejects(
        async () =>
          await claimerAsUser.write.transferOwnership([user2.account.address]),
        /OwnableUnauthorizedAccount/,
      );
    });
  });
});
