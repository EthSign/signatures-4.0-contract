const EthSignV4 = artifacts.require("EthSignV4");
const { deployProxy, upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const config = require("../truffle-config");

module.exports = async function (deployer, network) {
  try {
    const existing = await EthSignV4.deployed();
    await upgradeProxy(existing.address, EthSignV4, { deployer });
  } catch (error) {
    console.log(`Error upgrading, redeploying instead...`);
    await deployProxy(
      EthSignV4,
      [
        config.networks[network].network_id,
        config.networks[network].trustedForwarder,
      ],
      { deployer }
    );
  }
};
