
async function deployTokenLogic() {

    const accounts = await hre.ethers.getSigners();

    // Init Lendingpool logic libraries
    console.log("Deploy cToken logics: ");
    const cToken = await hre.ethers.getContractFactory("cToken");
    var cTokenContract = await cToken.deploy();
    // console.log("Transaction tToken hash: ", cTokenContract.deployTransaction.hash);
    await cTokenContract.deployed();
    console.log("cToken address: ", cTokenContract.address);

    console.log("Deploy debtToken logics: ");
    const debtToken = await hre.ethers.getContractFactory("debtToken");
    var debtTokenContract = await debtToken.deploy();
    // console.log("Transaction tToken hash: ", debtTokenContract.deployTransaction.hash);
    await debtTokenContract.deployed();
    console.log("debtToken address: ", debtTokenContract.address);
}


if (require.main === module) {
    deployTokenLogic()
    .then(() => process.exit())
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
  }

module.exports = {
    deployTokenLogic
};
