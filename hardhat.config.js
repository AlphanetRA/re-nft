require("dotenv").config();
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const getHDWallet = () => {
  const { MNEMONIC, PRIVATE_KEY } = process.env;

  if (PRIVATE_KEY && PRIVATE_KEY !== "") {
    return [PRIVATE_KEY];
  }
  if (MNEMONIC && MNEMONIC !== "") {
    return {
      mnemonic: MNEMONIC,
    };
  }

  throw Error("Private Key Not Set! Please set up .env");
};

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    development: {
      url: "http://localhost:8545",
      accounts: getHDWallet(),
    },
    bscTestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      accounts: getHDWallet(),
    },
    bsc: {
      url: "http://bsc-dataseed.binance.org",
      accounts: getHDWallet(),
    }
  },
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  etherscan: {
    apiKey: {
      // binance smart chain
      bsc: process.env.BSCSCAN_API_KEY,
      bscTestnet: process.env.BSCSCAN_API_KEY,
    }
  }
};
