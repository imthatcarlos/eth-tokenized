/**
 * Increases testrpc time by the passed duration in seconds
 * source: zeppelin-solidity/test/helpers/
 * NOTE: evm_increaseTime does not rollback changes
 * issue: https://github.com/trufflesuite/ganache-cli/issues/390
 */
module.exports = async function increaseTime (web3, duration) {
  const id = Date.now();

  return new Promise((resolve, reject) => {
    web3.currentProvider.sendAsync({
      jsonrpc: '2.0',
      method: 'evm_increaseTime',
      params: [duration],
      id: id,
    }, err1 => {
      if (err1) return reject(err1);

      web3.currentProvider.sendAsync({
        jsonrpc: '2.0',
        method: 'evm_mine',
        id: id + 1,
      }, (err2, res) => {
        return err2 ? reject(err2) : resolve(res);
      });
    });
  });
}
