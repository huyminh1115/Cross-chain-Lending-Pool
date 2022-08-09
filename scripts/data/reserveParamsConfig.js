const BigNumber = require('bignumber.js');
const { oneRay } = require('./constant');

// ----------------
// RESERVES CONFIG
// ----------------
const reservesParamsConfig = {
    DAI: {
        baseLTVAsCollateral: 7500,
        liquidationThreshold: 8000,
        liquidationBonus: 10500,
        borrowingEnabled: true,
        reserveDecimals: 18,
        reserveFactor: 1000,
        utilizationOptimal: new BigNumber(0.8).multipliedBy(oneRay).toFixed(),
        BaseInterstRate: 0,
        slope1: new BigNumber(0.04).multipliedBy(oneRay).toFixed(),
        slope2: new BigNumber(0.75).multipliedBy(oneRay).toFixed()
    },
    BTCB: {
        baseLTVAsCollateral: 7000,
        liquidationThreshold: 7500,
        liquidationBonus: 10900,
        borrowingEnabled: true,
        reserveDecimals: 18,
        reserveFactor: 1000,
        utilizationOptimal: new BigNumber(0.6).multipliedBy(oneRay).toFixed(),
        BaseInterstRate: new BigNumber(0).multipliedBy(oneRay).toFixed(),
        slope1: new BigNumber(0.01).multipliedBy(oneRay).toFixed(),
        slope2: new BigNumber(1).multipliedBy(oneRay).toFixed()
    },
    BUSD: {
        baseLTVAsCollateral: 7500,
        liquidationThreshold: 8000,
        liquidationBonus: 10500,
        borrowingEnabled: true,
        reserveDecimals: 18,
        reserveFactor: 1000,
        utilizationOptimal: new BigNumber(0.8).multipliedBy(oneRay).toFixed(),
        BaseInterstRate: new BigNumber(0).multipliedBy(oneRay).toFixed(),
        slope1: new BigNumber(0.04).multipliedBy(oneRay).toFixed(),
        slope2: new BigNumber(1).multipliedBy(oneRay).toFixed()
    }
}

module.exports = {
    reservesParamsConfig
};
