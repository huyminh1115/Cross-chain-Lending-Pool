
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
    console.log("Transaction lendingPoolConfigurator hash: ", lendingPoolConfigurator.deployTransaction.hash);
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
    console.log("Transaction lendingPool hash: ", lendingPool.deployTransaction.hash);
    await lendingPool.deployed();
    console.log("Lending pool address: ", lendingPool.address);

    await(await lendingPoolConfigurator.setLendingPool(lendingPool.address)).wait();


    // console.log("9. Deploy tToken Logic: ");
    // tTokenLogic = await initTTokenLogic();
    // tTokenLogicAddress = tTokenLogic.address;
    // console.log("tTokenLogic", tTokenLogicAddress);

    // console.log("10. Deploy dToken Logic: ");
    // variableDebtTokenLogic = await initVariableDebtTokenLogic();
    // variableDebtTokenLogicAddress = variableDebtTokenLogic.address;
    // console.log("variableDebtTokenLogic: ", variableDebtTokenLogicAddress);

    // // Init TREASURY
    // console.log("11. Deploy Treasury Collector: ");
    // TREASURY = await initTreasuryCollector(GOVERNANCE);
    // console.log('TREASURY: ', TREASURY)

    // // Init Trava Token
    // console.log("12. Get TravaToken: ");
    // const travaToken = await getTravaToken();
    // travaTokenAddress = travaToken.address;
    // console.log('travaToken: ', travaTokenAddress);
    // var cooldownSeconds = 0;
    // var unstakeWindow = 162650494900;
    // var distributionDuration = 4773826457;
    // var rewardsVault = GOVERNANCE;
    // var emissionManager = GOVERNANCE;
    // var governance = GOVERNANCE;

    // // Init INCESTIVES_CONTROLLER
    // console.log("13. Deploy staking and incentiveController: ");
    // const {stakedTrava, stakedTokenIncentivesController} = await initStaked(
    //     travaToken.address,         // staked Token
    //     travaToken.address,         // reward Token
    //     cooldownSeconds, 
    //     unstakeWindow, 
    //     distributionDuration,
    //     rewardsVault, 
    //     emissionManager, 
    //     governance);
    
    // stakedTravaAddress = stakedTrava.address;

    // INCESTIVES_CONTROLLER = stakedTokenIncentivesController.address;

    // poolManagementConfig.GOVERNANCE = GOVERNANCE;
    // poolManagementConfig.TTOKEN_LOGIC = tTokenLogicAddress;
    // poolManagementConfig.VARIABLE_DEBT_TOKEN_LOGIC = variableDebtTokenLogicAddress;
    // poolManagementConfig.LENDINGPOOL_LOGIC = lendingPoolLogicAddress;
    // poolManagementConfig.TREASURY = TREASURY;
    // poolManagementConfig.INCESTIVES_CONTROLLER = INCESTIVES_CONTROLLER;
    // poolManagementConfig.STAKED_TRAVA = stakedTravaAddress;
    // poolManagementConfig.FACTORY_REGISTRY_ADDRESS = factoryRegistryAddress;
    // poolManagementConfig.POOL_UPDATE_CONTROL = poolUpdateControlAddress;
    // poolManagementConfig.LENDINGPOOL_CONFIGURATOR_LOGIC = lendingPoolConfiguratorLogicAddress;
    // poolManagementConfig.TRAVA_TOKEN_ADDRESS = travaTokenAddress;

    // return poolManagementConfig;
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
