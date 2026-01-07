import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import hardhatVerify from "@nomicfoundation/hardhat-verify";
import { configVariable, defineConfig } from "hardhat/config";
import { config } from "dotenv";

config();

export default defineConfig({
  plugins: [hardhatToolboxViemPlugin, hardhatVerify],
  solidity: {
    profiles: {
      default: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      production: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },
  verify: {
    etherscan: {
      enabled: process.env.ETHERSCAN_API_KEY ? true : false,
      apiKey: process.env.ETHERSCAN_API_KEY ?? "",
    },
    blockscout: {
      enabled: true,
    },
    sourcify: {
      enabled: false,
    },
  },
  networks: {
    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1",
    },
    hardhatOp: {
      type: "edr-simulated",
      chainType: "op",
    },
    ...(process.env.SEPOLIA_RPC_URL && process.env.SEPOLIA_PRIVATE_KEY
      ? {
          sepolia: {
            type: "http",
            chainType: "l1",
            url: process.env.SEPOLIA_RPC_URL!,
            accounts: [process.env.SEPOLIA_PRIVATE_KEY! as `0x${string}`],
          },
        }
      : undefined),
    ...(process.env.MAINNET_RPC_URL && process.env.MAINNET_PRIVATE_KEY
      ? {
          mainnet: {
            type: "http",
            chainType: "l1",
            url: process.env.MAINNET_RPC_URL!,
            accounts: [process.env.MAINNET_PRIVATE_KEY! as `0x${string}`],
          },
        }
      : undefined),
    ...(process.env.OP_RPC_URL && process.env.OP_PRIVATE_KEY
      ? {
          op: {
            type: "http",
            chainType: "op",
            url: process.env.OP_RPC_URL!,
            accounts: [process.env.OP_PRIVATE_KEY! as `0x${string}`],
          },
        }
      : undefined),
  },
});
