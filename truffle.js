const HDWalletProvider = require("truffle-hdwallet-provider");
const NonceTrackerSubprovider = require("web3-provider-engine/subproviders/nonce-tracker");

require('dotenv').config();
require('@babel/register');
require('@babel/polyfill');

module.exports = {
  mocha: {
    useColors: true
  },
  // compilers: {
  //   solc: {
  //     version: '0.4.24'
  //   }
  // },
  networks: {
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '*',
      gasPrice: 4300000000 // based on https://ethgasstation.info/
    },
    ropsten: {
      provider: function() {
        return new HDWalletProvider(process.env.MNEMONIC, "https://ropsten.infura.io/" + process.env.INFURA_API_KEY)
      },
      network_id: '3',
      gas: 4500000
    },
    mainnet: {
      provider: function() {
        var wallet = new HDWalletProvider(process.env.MNEMONIC, "https://mainnet.infura.io/" + process.env.INFURA_API_KEY);
        var nonceTracker = new NonceTrackerSubprovider();
        wallet.engine._providers.unshift(nonceTracker);
        nonceTracker.setEngine(wallet.engine);
        return wallet;
      },
      network_id: '1',
      port: 8546,
      gas: 4500000
    }
  }
};
