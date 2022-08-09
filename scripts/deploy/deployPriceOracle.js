const hre = require("hardhat");

const { ReserveAssets } = require("../data/reserveAssets")

async function getPriceOracle() {
    const reserveAssets = ReserveAssets;
    const FallbackOracle = "0x0000000000000000000000000000000000000000";
    const PriceOracle = await hre.ethers.getContractFactory("PriceOracle");
    var assets = [];
    var sources = [];

    for (var i = 0; i < Object.keys(reserveAssets).length; i++) {
        tokenName = Object.keys(reserveAssets)[i]
        assets.push(reserveAssets[tokenName].underlyingAddress);
        sources.push(reserveAssets[tokenName].PriceFeed);
    }
    
    var priceOracle = await PriceOracle.deploy(assets, sources, FallbackOracle);
    await priceOracle.deployed();
    console.log("Price oracle address: ", priceOracle.address);
    return priceOracle;
}

if (require.main === module) {
    getPriceOracle()
    .then(() => process.exit())
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
  }


module.exports = {
    getPriceOracle
};
