require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
const accounts = require('../accounts');

const networks = {
    localhost: {
        url: "http://127.0.0.1:8545"
    },
    eth: {
        url: "https://rpc.ankr.com/eth/6c2f34a42715fa4c50762b0069a7a658618c752709b7db32f7bfe442741117eb",
        chainId: 1,
        gasPrice: 36000000000,
        accounts: [accounts.bsc.privateKey]
    },
    bsc: {
        url: "https://bsc-dataseed1.defibit.io/",
        chainId: 56,
        gasPrice: 20000000000,
        accounts: [accounts.bsc.privateKey]
    },
    polygon: {
        url: "https://polygon-rpc.com",
        chainId: 137,
        gasPrice: 140000000000,
        accounts: [accounts.bsc.privateKey]
    },
    arbitrum: {
        url: "https://arb1.arbitrum.io/rpc",
        chainId: 42161,
        gasPrice: 200000000,
        accounts: [accounts.bsc.privateKey]
    },
    mumbai: {
        url: "https://rpc-mumbai.maticvigil.com/",
        chainId: 80001,
        gasPrice: 20000000000,
        accounts: [accounts.bsc.privateKey]
    },
    test: {
      url: "https://bsc-testnet.web3api.com/v1/KBR2FY9IJ2IXESQMQ45X76BNWDAW2TT3Z3",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: [accounts.bsc.privateKey]
    },
};

module.exports = {
    solidity: {
        version: "0.8.17",
        settings: {
            optimizer: {
                enabled: true,
                runs: 1
            }
        }
    },
    networks: networks,
    etherscan: {
        apiKey: accounts.bscscan
    }
};
