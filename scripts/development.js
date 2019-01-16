const BigNumber = require('bignumber.js');
const getContracts = require('./../src/utils/getContracts');

module.exports = function(callback) {
  console.log('development.js ------');

  try {
    const contracts = await getContracts();
    console.log('initialized contracts');

    // do stuff
  } catch(error) {
    console.log(error);
    console.log('see errors --');
    callback();
  }
}
