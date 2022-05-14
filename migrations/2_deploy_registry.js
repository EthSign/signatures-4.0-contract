const EthSignPublicEncryptionKeyRegistry = artifacts.require(
  "EthSignPublicEncryptionKeyRegistry"
);
const config = require("../truffle-config");

module.exports = async function (deployer, network) {
  try {
    console.log(
      `Already deployed at ${await EthSignPublicEncryptionKeyRegistry.deployed()}`
    );
  } catch (error) {
    deployer.deploy(
      EthSignPublicEncryptionKeyRegistry,
      config.networks[network].trustedForwarder
    );
  }
};
