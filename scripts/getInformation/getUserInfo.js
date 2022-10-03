const hre = require("hardhat");
const { ReserveAssets } = require("../data/reserveAssets")

async function main() {    
    const accounts = await hre.ethers.getSigners();
    const lendingPoolAddress = "0x3f8D5645d531a8ab51866Be27aFf05c331c40d0d";
    const lendingPool  = await hre.ethers.getContractAt("LendingPool", lendingPoolAddress);    
    var UserInfo = await lendingPool.getUserAccountData(accounts[1].address);
    const rows = [];
    const reserve = {}
    reserve['totalCollateralUSD'] = UserInfo.totalCollateralUSD
    reserve['totalDebtUSD'] = UserInfo.totalDebtUSD
    reserve['availableBorrowsUSD'] = UserInfo.availableBorrowsUSD
    reserve['currentLiquidationThreshold'] = UserInfo.currentLiquidationThreshold
    reserve['ltv'] = UserInfo.ltv
    reserve['healthFactor'] = UserInfo.healthFactor
    rows.push(reserve)
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
