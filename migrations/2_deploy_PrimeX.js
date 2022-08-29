const tokenContract = artifacts.require("PrimeX");

module.exports = function (deployer) {
  deployer.deploy(tokenContract);
};