const hre = require("hardhat");

async function getLendingPoolLogicLibraries() {
    accounts = await hre.ethers.getSigners();

    // Reserve Logic
    const ReserveLogic = await hre.ethers.getContractFactory('ReserveLogic');
    var reserveLogic = await ReserveLogic.deploy();
    // console.log("Transaction reserveLogic hash: ", reserveLogic.deployTransaction.hash);
    await reserveLogic.deployed();
    var reserveLogicAddress = reserveLogic.address;
    console.log("reserveLogicAddress: ", reserveLogicAddress);

    // Generic Logic
    const GenericLogic = await hre.ethers.getContractFactory('GenericLogic');
    var genericLogic = await GenericLogic.deploy();
    // console.log("Transaction genericLogic hash: ", genericLogic.deployTransaction.hash);
    await genericLogic.deployed();
    var genericLogicAddress = genericLogic.address;
    console.log("genericLogicAddress: ", genericLogicAddress);

    // Validation Logic
    const ValidationLogic = await hre.ethers.getContractFactory('ValidationLogic', {
        libraries: {
            GenericLogic: genericLogicAddress
        }
    });
    var validationLogic = await ValidationLogic.deploy();
    // console.log("Transaction validationLogic hash: ", validationLogic.deployTransaction.hash);
    await validationLogic.deployed();
    var validationLogicAddress = validationLogic.address;
    console.log("validationLogicAddress: ", validationLogicAddress);

    //Deposit Logic
    const DepositLogic = await hre.ethers.getContractFactory('DepositLogic', {
        libraries: {
            ValidationLogic: validationLogicAddress
        }
    });
    var depositLogic = await DepositLogic.deploy();
    // console.log("Transaction depositLogic hash: ", depositLogic.deployTransaction.hash);
    await depositLogic.deployed();
    var depositLogicAddress = depositLogic.address;

    //Borrow Logic
    const BorrowLogic = await hre.ethers.getContractFactory('BorrowLogic', {
        libraries: {
            ValidationLogic: validationLogicAddress
        }
    });
    var borrowLogic = await BorrowLogic.deploy();
    // console.log("Transaction borrowLogic hash: ", borrowLogic.deployTransaction.hash);
    await borrowLogic.deployed();
    var borrowLogicAddress = borrowLogic.address;

    //Liquidation manager
    const LiquidationManager = await hre.ethers.getContractFactory('LiquidationManager', {
        libraries: {
            ValidationLogic: validationLogicAddress
        }
    });
    var liquidationManager = await LiquidationManager.deploy();
    // console.log("Transaction liquidationManager hash: ", liquidationManager.deployTransaction.hash);
    await liquidationManager.deployed();
    var liquidationManagerAddress = liquidationManager.address;

    // Bridge Logic
    const BridgeLogic = await hre.ethers.getContractFactory('BridgeLogic', {
        libraries: {
            ValidationLogic: validationLogicAddress
        }
    });
    var bridgeLogic = await BridgeLogic.deploy();
    // console.log("Transaction bridgeLogic hash: ", bridgeLogic.deployTransaction.hash);
    await bridgeLogic.deployed();
    var bridgeLogicAddress = bridgeLogic.address;
    

    return {
        reserveLogicAddress,
        genericLogicAddress,
        validationLogicAddress,
        depositLogicAddress,
        borrowLogicAddress,
        liquidationManagerAddress,
        bridgeLogicAddress,
    }
}

module.exports = { getLendingPoolLogicLibraries };
