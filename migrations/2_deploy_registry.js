const EthSignPublicEncryptionKeyRegistry = artifacts.require(
  "EthSignPublicEncryptionKeyRegistry"
);
const config = require("../truffle-config");

module.exports = function (deployer, network) {
  deployer.deploy(
    EthSignPublicEncryptionKeyRegistry,
    config.networks[network].trustedForwarder
  );
};
