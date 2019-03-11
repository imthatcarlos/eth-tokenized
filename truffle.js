const ProviderEngine = require("web3-provider-engine")
const HDWalletProvider = require("truffle-hdwallet-provider");
const NonceTrackerSubprovider = require("web3-provider-engine/subproviders/nonce-tracker");
const RpcProvider = require("web3-provider-engine/subproviders/rpc.js")

const { TruffleArtifactAdapter } = require('@0x/sol-trace');
const { ProfilerSubprovider } = require("@0x/sol-profiler");
const { CoverageSubprovider } = require("@0x/sol-coverage");
const { RevertTraceSubprovider } = require("@0x/sol-trace");

require('dotenv').config();
require('@babel/register');
require('@babel/polyfill');

const projectRoot = "";
const solcVersion = "0.5.0";
const defaultFromAddress = "0x5409ed021d9299bf6814279a6a1411a7e866a631"; // from 0xorg/devnet docker
const isVerbose = true;
const artifactAdapter = new TruffleArtifactAdapter(projectRoot, solcVersion);
const provider = new ProviderEngine();

const mode = process.env.MODE
if (mode === "profile") {
  global.profilerSubprovider = new ProfilerSubprovider(
    artifactAdapter,
    defaultFromAddress,
    isVerbose
  );
  global.profilerSubprovider.stop();
  provider.addProvider(global.profilerSubprovider);
} else if (mode === "coverage") {
  global.coverageSubprovider = new CoverageSubprovider(
    artifactAdapter,
    defaultFromAddress,
    isVerbose
  );
  provider.addProvider(global.coverageSubprovider);
} else if (mode === "trace") {
  const revertTraceSubprovider = new RevertTraceSubprovider(
    artifactAdapter,
    defaultFromAddress,
    isVerbose
  );
  provider.addProvider(revertTraceSubprovider);
}

module.exports = {
  plugins: [ 'truffle-security' ],
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
      // provider: function() {
      //   provider.addProvider(new RpcProvider({ rpcUrl: "http://localhost:8545" }));
      //   provider.start();
      //   provider.send = provider.sendAsync.bind(provider);
      //   return provider;
      // },
      host: 'localhost',
      port: 8545,
      network_id: '*',
      gasPrice: 4300000000
    },
    ropsten: {
      provider: function() {
        provider.addProvider(new HDWalletProvider(process.env.MNEMONIC, "https://ropsten.infura.io/" + process.env.INFURA_API_KEY));
        provider.start();
        provider.send = provider.sendAsync.bind(provider);
        return provider;
      },
      network_id: '3',
      gas: 4500000
    },
    mainnet: {
      provider: function() {
        provider.addProvider(new HDWalletProvider(process.env.MNEMONIC, "https://mainnet.infura.io/" + process.env.INFURA_API_KEY));
        provider.addProvider(new NonceTrackerSubprovider());
        provider.start();
        provider.send = provider.sendAsync.bind(provider);
        return provider;
      },
      network_id: '1',
      port: 8546,
      gas: 4500000
    }
  }
};
