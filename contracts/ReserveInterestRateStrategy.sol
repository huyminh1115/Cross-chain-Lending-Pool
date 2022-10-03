pragma solidity ^0.8.0;

import {WadRayMath} from "./libraries/math/WadRayMath.sol";
import {PercentageMath} from "./libraries/math/PercentageMath.sol";
import {PriceOracle} from "./PriceOracle.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {IERC20} from "./interfaces/IERC20.sol";

contract ReserveInterestRateStrategy {
    using WadRayMath for uint256;
    using PercentageMath for uint256;

    uint256 public immutable OPTIMAL_UTILIZATION_RATE;

    uint256 public immutable EXCESS_UTILIZATION_RATE;

    // Base variable borrow rate when Utilization rate = 0. Expressed in ray
    uint256 internal immutable _baseVariableBorrowRate;

    // Slope of the variable interest curve when utilization rate > 0 and <= OPTIMAL_UTILIZATION_RATE. Expressed in ray
    uint256 internal immutable _variableRateSlope1;

    // Slope of the variable interest curve when utilization rate > OPTIMAL_UTILIZATION_RATE. Expressed in ray
    uint256 internal immutable _variableRateSlope2;

    constructor(
        uint256 optimalUtilizationRate,
        uint256 baseVariableBorrowRate,
        uint256 variableRateSlope1,
        uint256 variableRateSlope2
    ) public {
        OPTIMAL_UTILIZATION_RATE = optimalUtilizationRate;
        EXCESS_UTILIZATION_RATE = WadRayMath.ray() - optimalUtilizationRate;
        _baseVariableBorrowRate = baseVariableBorrowRate;
        _variableRateSlope1 = variableRateSlope1;
        _variableRateSlope2 = variableRateSlope2;
    }

    function variableRateSlope1() external view returns (uint256) {
        return _variableRateSlope1;
    }

    function variableRateSlope2() external view returns (uint256) {
        return _variableRateSlope2;
    }

    function baseVariableBorrowRate() external view returns (uint256) {
        return _baseVariableBorrowRate;
    }

    function getMaxVariableBorrowRate() external view returns (uint256) {
        return
            _baseVariableBorrowRate + _variableRateSlope1 + _variableRateSlope2;
    }

    function calculateInterestRates(
        address reserve,
        address tToken,
        uint256 liquidityAdded,
        uint256 liquidityTaken,
        uint256 totalVariableDebt,
        uint256 reserveFactor,
        uint256 unbackedAmount
    ) external view returns (uint256, uint256) {
        uint256 availableLiquidity = IERC20(reserve).balanceOf(tToken);
        //avoid stack too deep
        availableLiquidity =
            availableLiquidity +
            liquidityAdded -
            liquidityTaken;

        return
            calculateInterestRates(
                unbackedAmount,
                availableLiquidity,
                totalVariableDebt,
                reserveFactor
            );
    }

    struct CalcInterestRatesLocalVars {
        uint256 totalDebt;
        uint256 currentVariableBorrowRate;
        uint256 currentLiquidityRate;
        uint256 borrowUsageRatio;
        uint256 supplyUsageRatio;
    }

    function calculateInterestRates(
        uint256 unbackedAmount,
        uint256 availableLiquidity,
        uint256 totalVariableDebt,
        uint256 reserveFactor
    ) public view returns (uint256, uint256) {
        CalcInterestRatesLocalVars memory vars;

        vars.totalDebt = totalVariableDebt;
        vars.currentVariableBorrowRate = 0;
        vars.currentLiquidityRate = 0;
        uint256 availableLiquidityPlusDebt = availableLiquidity +
            vars.totalDebt;
        // real usageRatio
        vars.borrowUsageRatio = vars.totalDebt == 0
            ? 0
            : vars.totalDebt.rayDiv(availableLiquidityPlusDebt);
        // fake usageRatio
        vars.supplyUsageRatio = vars.totalDebt == 0
            ? 0
            : vars.totalDebt.rayDiv(
                availableLiquidityPlusDebt + unbackedAmount
            );

        // Borrow rate
        if (vars.borrowUsageRatio > OPTIMAL_UTILIZATION_RATE) {
            // Ut > Uoptimal
            uint256 excessUtilizationRateRatio = vars.borrowUsageRatio -
                OPTIMAL_UTILIZATION_RATE.rayDiv(EXCESS_UTILIZATION_RATE);
            vars.currentVariableBorrowRate =
                _baseVariableBorrowRate +
                _variableRateSlope1 +
                (_variableRateSlope2.rayMul(excessUtilizationRateRatio));
        } else {
            // Ut < Uoptimal
            uint256 excessUtilizationRateRatio = vars.borrowUsageRatio.rayDiv(
                OPTIMAL_UTILIZATION_RATE
            );

            vars.currentVariableBorrowRate =
                _baseVariableBorrowRate +
                (excessUtilizationRateRatio.rayMul(_variableRateSlope1));
        }
        // LRt = Overal Rt * Ut
        // Don't use Stable rate. So Overall borrow rate = variable borrow rate
        vars.currentLiquidityRate = vars
            .currentVariableBorrowRate
            .rayMul(vars.supplyUsageRatio)
            .percentMul(PercentageMath.PERCENTAGE_FACTOR - reserveFactor);
        return (vars.currentLiquidityRate, vars.currentVariableBorrowRate);
    }
}
