const hre = require("hardhat");
const { ReserveAssets } = require("../data/reserveAssets")

async function main() {    
    const accounts = await hre.ethers.getSigners();
    const lendingPoolAddress = "0x65aE1D13122Fd42c4e6656e1F3859E3f74603f79";
    const lendingPool  = await hre.ethers.getContractAt("LendingPool", lendingPoolAddress);    
    var reserveList = await lendingPool.getReservesList();
    console.log("ReservesList in lending pool: ", reserveList); 
    console.log("PriceOracle address: ", await lendingPool.getPriceOracle());
    console.log("Lending pool state: ", await lendingPool.paused());
    const rows = [];
    reserveAddresses = ReserveAssets;
    await Promise.all(reserveList.map(async (address) => {
        const reserveData = await lendingPool.getReserveData(address);
        const cTokenAddress = reserveData.cTokenAddress;
        const debtTokenAddress = reserveData.debtTokenAddress;
        const strData = hre.ethers.BigNumber.from(reserveData[0].data).toHexString().slice(2);
        if (strData.length < 20) strData = "0".repeat(15 - strData.length) + strData;
        const maxLTV = parseInt(strData.slice(-4), 16);
        const liqThres = parseInt(strData.slice(-8, -4), 16);
        const liqBonus = parseInt(strData.slice(-12, -8), 16);
        const decimals = parseInt(strData.slice(-14, -12), 16);
        const reserveFactor = parseInt(strData.slice(-20, -16), 16);
        const reserveName = Object.keys(reserveAddresses).filter(token => reserveAddresses[token]['underlyingAddress'].toLowerCase() == address.toLowerCase())?.[0];
        const reserve = {}
        reserve['Asset'] = reserveName
        reserve['UnderlyingAddress'] = address
        reserve['cTokenAddress'] = cTokenAddress
        reserve['debtTokenAddress'] = debtTokenAddress
        reserve['liquidityIndex'] = reserveData.liquidityIndex
        reserve['borrowIndex'] = reserveData.borrowIndex
        reserve['currentLiquidityRate'] = reserveData.currentLiquidityRate
        reserve['currentBorrowRate'] = reserveData.currentBorrowRate
        reserve['LTV'] = maxLTV
        reserve['Threshold'] = liqThres
        reserve['Bonus'] = liqBonus
        reserve['Decimals'] = decimals
        reserve['Reserve Factor'] = reserveFactor
        rows.push(reserve)
    }))
    console.log(rows);
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
