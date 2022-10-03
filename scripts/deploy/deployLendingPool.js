
const { getLendingPoolLogicLibraries } = require("./deployLogic");

async function deployLendingPool() {

    const accounts = await hre.ethers.getSigners();

    // Init Lendingpool logic libraries
    console.log("Deploy libraries: ");
    const { reserveLogicAddress, genericLogicAddress, validationLogicAddress,
        depositLogicAddress, borrowLogicAddress, 
        liquidationManagerAddress, bridgeLogicAddress } 
    = await getLendingPoolLogicLibraries();

    console.log("Deploy LendingPoolConfigurator Logic: ");
    const LendingPoolConfigurator = await hre.ethers.getContractFactory("LendingPoolConfigurator");
    var lendingPoolConfigurator = await LendingPoolConfigurator.deploy();
    // console.log("Transaction lendingPoolConfigurator hash: ", lendingPoolConfigurator.deployTransaction.hash);
    await lendingPoolConfigurator.deployed();
    console.log("lendingPoolConfiguratorLogic: ", lendingPoolConfigurator.address);
    var lendingPoolConfiguratorAddress = lendingPoolConfigurator.address;
    var priceOracle = "0x6f0FA13C8b6D3765532dfEDF56d6eF976A7fB370";

    console.log("Deploy LendingPool Logic:");
    var LendingPool = await hre.ethers.getContractFactory('LendingPool', {
        libraries: {
            ReserveLogic: reserveLogicAddress,
            ValidationLogic: validationLogicAddress,
            DepositLogic: depositLogicAddress,
            BorrowLogic: borrowLogicAddress,
            LiquidationManager: liquidationManagerAddress,
            BridgeLogic: bridgeLogicAddress
        }
    });
    const lendingPool = await LendingPool.deploy(lendingPoolConfiguratorAddress, priceOracle);
    // console.log("Transaction lendingPool hash: ", lendingPool.deployTransaction.hash);
    await lendingPool.deployed();
    console.log("Lending pool address: ", lendingPool.address);

    await(await lendingPoolConfigurator.setLendingPool(lendingPool.address)).wait();
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
