const { reservesParamsConfig } = require('./data/reserveParamsConfig');
const { ReserveAssets } = require("./data/reserveAssets");
const hre = require("hardhat");

async function deployLendingPool() {

    const accounts = await hre.ethers.getSigners();
    const DAI = "0x5147fBBB26AD307DBF562EE242BFA3eF44fb3145";
    const BTCB = "0x37502cDeAfC39662c9F15FC2135cC5Ff4fa6Da04";
    const LendingPool = "0x65aE1D13122Fd42c4e6656e1F3859E3f74603f79";
    const DAIcontract = await hre.ethers.getContractAt("IERC20", DAI);
    const BTCBcontract = await hre.ethers.getContractAt("IERC20", BTCB);
    for(let i=0; i<2; i++){
        await (await DAIcontract.connect(accounts[i]).approve(LendingPool, BigInt(10000000 * 1e18)));
        await (await BTCBcontract.connect(accounts[i]).approve(LendingPool, BigInt(10000000 * 1e18)));
    }
    console.log("Approve done");

}


if (require.main === module) {
    deployLendingPool()
    .then(() => process.exit())
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
  }

module.exports = {
    deployLendingPool
};
