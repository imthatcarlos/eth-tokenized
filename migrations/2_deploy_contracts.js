const Main = artifacts.require("./Main");
const AssetRegistry = artifacts.require("./AssetRegistry");
const TToken = artifacts.require("./TToken");
const PTToken = artifacts.require("./PTToken");

// linking lib...
// const contract = require("truffle-contract");
// const Web3 = require("web3");

var fs = require("fs");
var path = require("path");

module.exports = function(deployer, _network, _accounts) {
  var networkIdx = process.argv.indexOf("--network");
  var network = networkIdx != -1 ? process.argv[networkIdx + 1] : "development"

  // if (network == "mainnet") {
  //   return;
  // }

  var filePath = path.join(__dirname, "./../contracts.json");
  var data = JSON.parse(fs.readFileSync(filePath, "utf8"));

  // linking lib...
  // // hacky workaroung to include compiled bytecode for Array256Lib
  // var provider = new Web3.providers.HttpProvider("http://localhost:8545");
  // var arrayLibJSON = require("./../node_modules/ethereum-libraries-array-utils/build/contracts/Array256Lib.json")
  // const Array256Lib = contract(arrayLibJSON);
  // Array256Lib.setProvider(provider);
  //
  // // only overwriting the deployed code if deploying locally
  // const overwrite = network === "mainnet" ? false : true;
  // deployer.deploy(Array256Lib, { overwrite: overwrite, from: _accounts[0] });
  // deployer.link(Array256Lib, Main);

  // deploy contract
  deployer.deploy(TToken).then(() => {
    return deployer.deploy(PTToken).then((portfolioToken) => {
      return deployer.deploy(Main, TToken.address, PTToken.address).then((main) => {
        return deployer.deploy(AssetRegistry, TToken.address, Main.address).then(() => {
          data[network]["Main"] = Main.address;
          data[network]["AssetRegistry"] = AssetRegistry.address;
          data[network]["TToken"] = TToken.address;
          data[network]["PTToken"] = PTToken.address;

          var json = JSON.stringify(data);
          fs.writeFileSync(filePath, json, "utf8");

          // write to src/ directory as well
          const srcFilePath = path.join(__dirname, "./../src/json/contracts.json");
          fs.writeFileSync(srcFilePath, json, "utf8");

          // give Main contract minting
          portfolioToken.addMinter(Main.address);

          // for ref
          main.setAssetRegistry(AssetRegistry.address);
        });
      });
    })
  });
};
