const tradeContract = artifacts.require("PrimeTrade");

module.exports = function (deployer) {
  deployer.deploy(tradeContract);
};