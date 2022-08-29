const exchangeContract = artifacts.require("PrimeExchange");

module.exports = function (deployer) {
  deployer.deploy(exchangeContract);
};