/** @type import('hardhat/config').HardhatUserConfig */
require('dotenv').config()
const GOERLI_URL = process.env.GOERLI_URL
const LOCALHOST_PRIVATEKEY = process.env.LOCALHOST_PRIVATEKEY
const GOERLI_PRIVATEKEY = process.env.GOERLI_PRIVATEKEY

const { upgradePlugin } = require("@openzeppelin/hardhat-upgrades");

module.exports = {
  solidity: {
    version: "0.8.9",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  plugins: [
    upgradePlugin,
  ],
  networks: {
    localhost: {
      url: "http://127.0.0.1:443",
      chainId: 59003,
      accounts: [LOCALHOST_PRIVATEKEY],
    },
    goerli: {
      url: GOERLI_URL,
      accounts: [GOERLI_PRIVATEKEY],
    },
  }, 
};
