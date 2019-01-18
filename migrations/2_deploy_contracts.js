const Main = artifacts.require("./Main");
const TToken = artifacts.require("./TToken");

var fs = require("fs");
var path = require("path");

const LOCK_PERIOD_SECONDS = 60 * 60 * 24 * 365; // 12 months

module.exports = function(deployer) {
  var networkIdx = process.argv.indexOf("--network");
  var network = networkIdx != -1 ? process.argv[networkIdx + 1] : "development"

  if (network == "mainnet") {
    return;
  }

  var filePath = path.join(__dirname, "./../contracts.json");
  var data = JSON.parse(fs.readFileSync(filePath, "utf8"));

  // deploy contract
  deployer.deploy(TToken).then(() => {
    return deployer.deploy(Main, TToken.address, LOCK_PERIOD_SECONDS).then(() => {
      data[network]["Main"] = Main.address;
      data[network]["TToken"] = TToken.address;

      var json = JSON.stringify(data);
      fs.writeFileSync(filePath, json, "utf8");

      // write to src/ directory as well
      const srcFilePath = path.join(__dirname, "./../src/json/contracts.json");
      fs.writeFileSync(srcFilePath, json, "utf8");
    });
  });
};
