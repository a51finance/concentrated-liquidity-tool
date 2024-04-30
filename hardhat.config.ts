import fs from "fs";
import "@nomicfoundation/hardhat-verify";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-preprocessor";
import { HardhatUserConfig, task } from "hardhat/config";
import { HardhatNetworkAccountUserConfig, NetworkUserConfig } from "hardhat/types";
import { config as dotenvConfig } from "dotenv";
import { resolve } from "path";
import "./tasks/accounts";

function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean)
    .map((line) => line.trim().split("="));
}

dotenvConfig({ path: resolve(__dirname, "./.env") });

const etherscanApiKey = process.env.ETHMAINNET_API_KEY;

const chainIds = {
  sepolia: 11155111,
  hardhat: 31337,
  mainnet: 1,
  manta: 169,
};

function createTestnetConfig(network: keyof typeof chainIds): NetworkUserConfig {
  const url: string = "https://pacific-rpc.manta.network/http";
  return {
    accounts: [`${process.env.PRIVATE_KEY_MAIN}`],
    chainId: chainIds[network],
    url,
    // gas: 2100000,
    // gasPrice: 58000000000,
  };
}

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    manta: createTestnetConfig("manta"),
  },

  solidity: {
    version: "0.8.15",
    settings: {
      optimizer: {
        enabled: true,
        runs: 4000,
      },
    },
  },
  paths: {
    sources: "./src", // Use ./src rather than ./contracts as Hardhat expects
    cache: "./cache_hardhat", // Use a different cache for Hardhat than Foundry
    artifacts: "./artifacts",
  },
  etherscan: {
    apiKey: {
      manta: "124",
    },
    customChains: [
      {
        network: "manta",
        chainId: 169,
        urls: {
          apiURL: "https://manta-pacific.calderaexplorer.xyz/api",
          browserURL: "https://manta-pacific.calderaexplorer.xyz/",
        },
      },
    ],
  },

  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          getRemappings().forEach(([find, replace]) => {
            if (line.match(find)) {
              line = line.replace(find, replace);
            }
          });
        }
        return line;
      },
    }),
  },
};

export default config;
