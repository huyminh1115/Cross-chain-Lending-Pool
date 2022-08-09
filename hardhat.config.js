require("@nomiclabs/hardhat-waffle");
let secret = require("./secrets.json");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId:31337,
      forking: {
        //url: "https://speedy-nodes-nyc.moralis.io/2ab951c0550908cbd73d21f4/eth/mainnet/archive",
        url: "https://speedy-nodes-nyc.moralis.io/884c451ac01af3a0539e7e3c/bsc/mainnet/archive",
      },
      allowUnlimitedContractSize: false
    },
    testnetbsc:{
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      accounts: [secret.key1,secret.key2]
    },
    // testnetarb: {
    //   url: "https://rinkeby.arbitrum.io/rpc",
    //   chainId: 421611,
    //   accounts: [
    //     `b66dd0480c81d4bc9818434e70358a0216d1608011d21f4d8c1ac209cc624cff`,
    //     `5dbc12be0c66284d02655cdca2670543277aa00072555fdad9a504d04e83835f`,
    //     `a0c31ec3759513cbdcb60bd0d3f30d298bcede28c06c5dd3b77b2b8219158de6`,
    //   ],
    // },
    // testnetftm:{
    //   // gas: 10012388,
    //   url: secret.urlFantomtestnet,
    //   accounts: [secret.key1,secret.key2]
    // },
    // mainnetftm:{
    //   gas: 9005991,
    //   url: secret.urlFantommainnet,
    //   accounts: [secret.main1,secret.main2]
    // },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 400
          }
        }
      },
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 400
          }
        }
      },
      {
        version: "0.4.18",
        settings: {
          optimizer: {
            enabled: true,
            runs: 400
          }
        }
      },
    ],
  },
};