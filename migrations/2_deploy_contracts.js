const Main = artifacts.require("./Main");
const AssetRegistry = artifacts.require("./AssetRegistry");
const TToken = artifacts.require("./TToken");
const PortfolioToken = artifacts.require("./PortfolioToken");

var fs = require("fs");
var path = require("path");

module.exports = function(deployer, _network, _accounts) {
  var networkIdx = process.argv.indexOf("--network");
  var network = networkIdx != -1 ? process.argv[networkIdx + 1] : "development"

  var filePath = path.join(__dirname, "./../contracts.json");
  var data = JSON.parse(fs.readFileSync(filePath, "utf8"));

  // deploy contract
  deployer.deploy(TToken).then(() => {
    //return deployer.deploy(PortfolioToken).then((portfolioToken) => {
      return deployer.deploy(Main, TToken.address).then((main) => {
        return deployer.deploy(AssetRegistry, TToken.address, Main.address).then(() => {
          return deployer.deploy(PortfolioToken).then((portfolioToken) => {
            data[network]["Main"] = Main.address;
            data[network]["AssetRegistry"] = AssetRegistry.address;
            data[network]["TToken"] = TToken.address;
            data[network]["PortfolioToken"] = PortfolioToken.address;

            var json = JSON.stringify(data);
            fs.writeFileSync(filePath, json, "utf8");

            // write to src/ directory as well
            const srcFilePath = path.join(__dirname, "./../src/json/contracts.json");
            fs.writeFileSync(srcFilePath, json, "utf8");

            // for ref
            main.setPortfolioToken(PortfolioToken.address);

            // give Main contract minting permission
            portfolioToken.addMinter(Main.address);

            // for ref
            main.setAssetRegistry(AssetRegistry.address);
          });
        });
      });
    //})
  });
};
