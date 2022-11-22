require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
const accounts = require('../accounts');
 
const networks = {
  bsc: {
      url: "https://bsc-dataseed1.defibit.io/",
      chainId: 56,
      gasPrice: 20000000000,
      accounts: [accounts.bsc.privateKey]
  },
  test: {
    url: "https://bsctestapi.terminet.io/rpc",
    chainId: 97,
    gasPrice: 20000000000,
    accounts: [accounts.bsc.privateKey]
  }
};

module.exports = {
  solidity: {
        version: "0.8.13",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            }
        }
    },
  networks: networks,
  etherscan: {
    apiKey: "EYK2X8KUEV48N8J3WPJKE5YTY3IHSVJH32"
  }
};
