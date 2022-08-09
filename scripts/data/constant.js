const BigNumber = require('bignumber.js');

// ----------------
// MATH
// ----------------

const PERCENTAGE_FACTOR = '10000';
const HALF_PERCENTAGE = '5000';
const WAD = Math.pow(10, 18).toString();
const HALF_WAD = new BigNumber(WAD).multipliedBy(0.5).toString();
const RAY = new BigNumber(10).exponentiatedBy(27).toFixed();
const HALF_RAY = new BigNumber(RAY).multipliedBy(0.5).toFixed();
const WAD_RAY_RATIO = Math.pow(10, 9).toString();
const oneEther = new BigNumber(Math.pow(10, 18));
const oneRay = new BigNumber(Math.pow(10, 27));

const MAX_UINT_AMOUNT =
  '115792089237316195423570985008687907853269984665640564039457584007913129639935';
const ONE_YEAR = '31536000';
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ONE_ADDRESS = '0x0000000000000000000000000000000000000001';


module.exports = {
    PERCENTAGE_FACTOR,
    HALF_PERCENTAGE,
    WAD,
    HALF_WAD,
    RAY,
    HALF_RAY,
    WAD_RAY_RATIO,
    oneEther,
    oneRay,
    MAX_UINT_AMOUNT,
    ONE_YEAR,
    ZERO_ADDRESS,
    ONE_ADDRESS,
};
