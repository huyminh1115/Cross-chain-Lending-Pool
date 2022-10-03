const { reservesParamsConfig } = require('./data/reserveParamsConfig');
const { ReserveAssets } = require("./data/reserveAssets")

async function deployLendingPool() {

    const accounts = await hre.ethers.getSigners();
    
    const cTokenAddress = "0x16C62df6eF5A3a56CF206CA572Ca89dEA05A6F8B";
    const debtTokenAddress = "0xbAB929AAd75Be7B581CD5540e7608A8778d59156";
    const LendingPoolConfigurator = "0xCbbC902122E8b270E3f11ef6151d676bd6b480CC";
    var initialReserves = ["DAI", "BTCB"];
    var reserves = ReserveAssets;
    var reserveInterestRateStrategyAddressList = [];
    for (var i = 0; i < initialReserves.length; i++) {
        const ReserveInterestRateStrategy = await hre.ethers.getContractFactory("ReserveInterestRateStrategy");
        var reserveInterestRateStrategy = await ReserveInterestRateStrategy.deploy(
            reservesParamsConfig[initialReserves[i]].utilizationOptimal,
            reservesParamsConfig[initialReserves[i]].BaseInterstRate,
            reservesParamsConfig[initialReserves[i]].slope1,
            reservesParamsConfig[initialReserves[i]].slope2
        );
        // console.log("Transaction reserveInterestRateStrategy hash: ", reserveInterestRateStrategy.deployTransaction.hash);
        await reserveInterestRateStrategy.deployed();
        console.log("reserveInterestRateStrategy address: ", reserveInterestRateStrategy.address);
        reserveInterestRateStrategyAddressList.push(reserveInterestRateStrategy.address);
    }

    var initReserveInput = [];
    for (var i = 0; i < initialReserves.length; i++) {
        var _initReserveInput = [
            cTokenAddress,
            debtTokenAddress,
            reservesParamsConfig[initialReserves[i]].reserveDecimals,
            reserveInterestRateStrategyAddressList[i],
            reserves[initialReserves[i]]['underlyingAddress'],
            accounts[0].address,
            reserves[initialReserves[i]].reserveName,
            'c' + reserves[initialReserves[i]].reserveName,
            'c' + reserves[initialReserves[i]].reserveName,
            'debt' + reserves[initialReserves[i]].reserveName,
            'debtt' + reserves[initialReserves[i]].reserveName,
            reservesParamsConfig[initialReserves[i]].baseLTVAsCollateral,
            reservesParamsConfig[initialReserves[i]].liquidationThreshold,
            reservesParamsConfig[initialReserves[i]].liquidationBonus,
            reservesParamsConfig[initialReserves[i]].reserveFactor,
        ];
        initReserveInput.push(_initReserveInput);
    }
    
    lendingPoolConfigurator = await hre.ethers.getContractAt('LendingPoolConfigurator', LendingPoolConfigurator);
    
    var batchInitReserveTxid = await lendingPoolConfigurator.batchInitReserve(initReserveInput);
    console.log("batchInitReserveTxid: ", batchInitReserveTxid.hash);
    await batchInitReserveTxid.wait();
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
