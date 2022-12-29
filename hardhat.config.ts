import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';

const { mnemonic } = require('./secrets.json');

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.9',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  // defaultNetwork: 'localhost',
  // networks: {
  //   localhost: {
  //     url: 'http://127.0.0.1:8545',
  //   },
  //   testnet: {
  //     url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
  //     chainId: 97,
  //     gasPrice: 20000000000,
  //     accounts: { mnemonic },
  //   },
  //   mainnet: {
  //     url: 'https://bsc-dataseed.binance.org/',
  //     chainId: 56,
  //     gasPrice: 20000000000,
  //     accounts: { mnemonic },
  //   },
  // },
  mocha: {
    timeout: 600000,
  },
};

export default config;
