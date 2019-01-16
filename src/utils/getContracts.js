const contract = require('truffle-contract');
const getWeb3 = require('./getWeb3');
const fixTruffleContract = require('./fixTruffleContract');

const HelbizToken = require('./../json/HelbizToken.json');
const contracts = require("./../json/contracts.json");

module.exports = async function getContracts(websocket = false) {
  var isWeb3Enabled = false;

  try {
    const results = await getWeb3(websocket);

    if (results.error === null) { reject(results.web3 !== null) }

    // web3 is enabled - if we fail it'll be initiating the contracts
    isWeb3Enabled = true;

    const helbizTokenAddress = contracts[results.network]["HelbizToken"];
    var helbizTokenContract = contract(HelbizToken);
    helbizTokenContract.setProvider(results.web3.currentProvider);
    helbizTokenContract = fixTruffleContract(helbizTokenContract);

    const helbizToken = helbizTokenContract.at(helbizTokenAddress);

    return {
      network:        results.network,
      web3:           results.web3,
      coinbase:       results.coinbase,
      helbizToken:    helbizToken,
      accounts:       results.accounts
    };
  } catch(error) {
    console.log(error);
    return;
  }
}
