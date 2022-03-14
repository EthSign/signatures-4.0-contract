const HDWalletProvider = require("@truffle/hdwallet-provider");
const fs = require("fs");
const mnemonic = fs.readFileSync(".secret").toString().trim();

module.exports = {
  networks: {
    mumbai: {
      provider: () =>
        new HDWalletProvider(mnemonic, `https://rpc-mumbai.matic.today`),
      network_id: 80001,
      confirmations: 2,
      skipDryRun: true,
      trustedForwarder: "0x9399BB24DBB5C4b782C70c2969F58716Ebbd6a3b",
    },
    matic: {
      provider: () =>
        new HDWalletProvider(
          mnemonic,
          `https://polygon-mainnet.g.alchemy.com/v2/b8HxLm8ftPKUWbEUInT5yb2WI_meyqNe`
        ),
      network_id: 137,
      confirmations: 2,
      skipDryRun: true,
      trustedForwarder: "0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8",
    },
  },

  compilers: {
    solc: {
      version: "0.8.12",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    },
  },

  api_keys: {
    etherscan: "1EZ3964PC38FSFDJNI2WPF7RSFR1JGC92B",
    polygonscan: "D1PK4SCQ3WGYYU93SQI5YKTU544QYZDMB4",
  },

  plugins: ["truffle-plugin-verify"],
};
