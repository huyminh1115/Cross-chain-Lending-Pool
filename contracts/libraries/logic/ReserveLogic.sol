// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IERC20} from "../../interfaces/IERC20.sol";
import {cToken} from "../../cToken.sol";
import {debtToken} from "../../debtToken.sol";
import {ReserveInterestRateStrategy} from "../../ReserveInterestRateStrategy.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {MathUtils} from "../math/MathUtils.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {DataTypes} from "../types/DataTypes.sol";

/**
 * @title ReserveLogic library
 * @notice Implements the logic to update the reserves state
 */
library ReserveLogic {
    using WadRayMath for uint256;
    using PercentageMath for uint256;

    event ReserveDataUpdated(
        address indexed asset,
        uint256 liquidityRate,
        uint256 borrowRate,
        uint256 liquidityIndex,
        uint256 borrowIndex
    );

    // using ReserveLogic for DataTypes.ReserveData;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    /**
     * @dev Returns the ongoing normalized income for the reserve
     * A value of 1e27 means there is no income. As time passes, the income is accrued
     * A value of 2*1e27 means for each unit of asset one unit of income has been accrued
     * @param reserve The reserve object
     * @return the normalized income. expressed in ray
     **/
    function getNormalizedIncome(DataTypes.ReserveData storage reserve)
        internal
        view
        returns (uint256)
    {
        uint40 timestamp = reserve.lastUpdateTimestamp;

        //solium-disable-next-line
        if (timestamp == uint40(block.timestamp)) {
            //if the index was updated in the same block, no need to perform any calculation
            return reserve.liquidityIndex;
        }

        uint256 cumulated = MathUtils
            .calculateLinearInterest(reserve.currentLiquidityRate, timestamp)
            .rayMul(reserve.liquidityIndex);
        return cumulated;
    }

    /**
     * @dev Returns the ongoing normalized debt for the reserve
     * A value of 1e27 means there is no debt. As time passes, the income is accrued
     * A value of 2*1e27 means that for each unit of debt, one unit worth of interest has been accumulated
     * @param reserve The reserve object
     * @return The normalized debt. expressed in ray
     **/
    function getNormalizedDebt(DataTypes.ReserveData storage reserve)
        internal
        view
        returns (uint256)
    {
        uint40 timestamp = reserve.lastUpdateTimestamp;

        //solium-disable-next-line
        if (timestamp == uint40(block.timestamp)) {
            //if the index was updated in the same block, no need to perform any calculation
            return reserve.borrowIndex;
        }

        uint256 cumulated = MathUtils
            .calculateCompoundedInterest(reserve.currentBorrowRate, timestamp)
            .rayMul(reserve.borrowIndex);

        return cumulated;
    }

    /**
     * @dev Updates the liquidity cumulative index and the borrow index.
     * @param reserve the reserve object
     **/
    function updateState(DataTypes.ReserveData storage reserve) internal {
        uint256 scaledDebt = debtToken(reserve.debtTokenAddress)
            .scaledTotalSupply();
        uint256 previousBorrowIndex = reserve.borrowIndex;
        uint256 previousLiquidityIndex = reserve.liquidityIndex;
        uint40 lastUpdatedTimestamp = reserve.lastUpdateTimestamp;

        (uint256 newLiquidityIndex, uint256 newBorrowIndex) = _updateIndexes(
            reserve,
            scaledDebt,
            previousLiquidityIndex,
            previousBorrowIndex,
            lastUpdatedTimestamp
        );

        _mintToTreasury(
            reserve,
            scaledDebt,
            previousBorrowIndex,
            newLiquidityIndex,
            newBorrowIndex,
            lastUpdatedTimestamp
        );
    }

    /**
     * @dev Accumulates a predefined amount of asset to the reserve as a fixed, instantaneous income. Used for example to accumulate
     * the flashloan fee to the reserve, and spread it between all the depositors
     * Formular: newLiquidityIndex = ((amountAdded / total) + 1) * liquidityIndex
     * @param reserve The reserve object
     * @param totalLiquidity The total liquidity available in the reserve
     * @param amount The amount to accomulate
     **/
    function cumulateToLiquidityIndex(
        DataTypes.ReserveData storage reserve,
        uint256 totalLiquidity,
        uint256 amount
    ) internal returns (uint256) {
        uint256 amountToLiquidityRatio = amount.wadToRay().rayDiv(
            totalLiquidity.wadToRay()
        );

        uint256 result = amountToLiquidityRatio + WadRayMath.ray();

        result = result.rayMul(reserve.liquidityIndex);
        require(result <= type(uint128).max, "RL_LIQUIDITY_INDEX_OVERFLOW");

        reserve.liquidityIndex = uint128(result);
        return result;
    }

    function init(
        DataTypes.ReserveData storage reserve,
        cToken cTokenAddress,
        debtToken debtTokenAddress,
        ReserveInterestRateStrategy interestRateStrategy
    ) external {
        require(
            reserve.cTokenAddress == address(0),
            "RL_RESERVE_ALREADY_INITIALIZED"
        );

        reserve.liquidityIndex = uint128(WadRayMath.ray());
        reserve.borrowIndex = uint128(WadRayMath.ray());
        reserve.cTokenAddress = address(cTokenAddress);
        reserve.debtTokenAddress = address(debtTokenAddress);
        reserve.interestRateStrategyAddress = address(interestRateStrategy);
    }

    struct UpdateInterestRatesLocalVars {
        uint256 availableLiquidity;
        uint256 newLiquidityRate;
        uint256 newBorrowRate;
        uint256 totalDebt;
    }

    /**
     * @dev Updates the current borrow rate and the current liquidity rate
     * @param reserveAddress The address of the reserve to be updated
     * @param cTokenAddress The address of tToken to be updated
     * @param liquidityAdded The amount of liquidity added to the protocol (deposit or repay) in the previous action
     * @param liquidityTaken The amount of liquidity taken from the protocol (redeem or borrow)
     **/
    function updateInterestRates(
        DataTypes.ReserveData storage reserve,
        address reserveAddress,
        address cTokenAddress,
        uint256 liquidityAdded,
        uint256 liquidityTaken
    ) internal {
        UpdateInterestRatesLocalVars memory vars;

        //calculates the total debt locally using the scaled total supply instead
        //of totalSupply(), as it's noticeably cheaper. Also, the index has been
        //updated by the previous updateState() call
        vars.totalDebt = debtToken(reserve.debtTokenAddress)
            .scaledTotalSupply()
            .rayMul(reserve.borrowIndex);

        (
            vars.newLiquidityRate,
            vars.newBorrowRate
        ) = ReserveInterestRateStrategy(reserve.interestRateStrategyAddress)
            .calculateInterestRates(
                reserveAddress,
                cTokenAddress,
                liquidityAdded,
                liquidityTaken,
                vars.totalDebt,
                reserve.configuration.getReserveFactor(),
                reserve.unbacked
            );
        require(
            vars.newLiquidityRate <= type(uint128).max,
            "RL_LIQUIDITY_RATE_OVERFLOW"
        );

        require(
            vars.newBorrowRate <= type(uint128).max,
            "RL_VARIABLE_BORROW_RATE_OVERFLOW"
        );

        reserve.currentLiquidityRate = uint128(vars.newLiquidityRate);
        reserve.currentBorrowRate = uint128(vars.newBorrowRate);

        emit ReserveDataUpdated(
            reserveAddress,
            vars.newLiquidityRate,
            vars.newBorrowRate,
            reserve.liquidityIndex,
            reserve.borrowIndex
        );
    }

    struct MintToTreasuryLocalVars {
        uint256 currentStableDebt;
        uint256 principalStableDebt;
        uint256 previousStableDebt;
        uint256 currentDebt;
        uint256 previousDebt;
        uint256 avgStableRate;
        uint256 cumulatedStableInterest;
        uint256 totalDebtAccrued;
        uint256 amountToMint;
        uint256 reserveFactor;
        uint40 stableSupplyUpdatedTimestamp;
    }

    /**
     * @dev Mints part of the repaid interest to the reserve treasury as a function of the reserveFactor for the
     * specific asset.
     * @param reserve The reserve to be updated
     * @param scaledDebt The current scaled total variable debt
     * @param previousBorrowIndex The variable borrow index before the last accumulation of the interest
     * @param newLiquidityIndex The new liquidity index
     * @param newBorrowIndex The variable borrow index after the last accumulation of the interest
     * @param timestamp The timestamp of the last update
     **/
    function _mintToTreasury(
        DataTypes.ReserveData storage reserve,
        uint256 scaledDebt,
        uint256 previousBorrowIndex,
        uint256 newLiquidityIndex,
        uint256 newBorrowIndex,
        uint40 timestamp
    ) internal {
        MintToTreasuryLocalVars memory vars;

        vars.reserveFactor = reserve.configuration.getReserveFactor();

        if (vars.reserveFactor == 0) {
            return;
        }

        //calculate the last principal variable debt
        vars.previousDebt = scaledDebt.rayMul(previousBorrowIndex);

        //calculate the new total supply after accumulation of the index
        vars.currentDebt = scaledDebt.rayMul(newBorrowIndex);

        //debt accrued is the sum of the current debt minus the sum of the debt at the last update
        vars.totalDebtAccrued = vars.currentDebt - (vars.previousDebt);

        vars.amountToMint = vars.totalDebtAccrued.percentMul(
            vars.reserveFactor
        );

        if (vars.amountToMint != 0) {
            cToken(reserve.cTokenAddress).mintToTreasury(
                vars.amountToMint,
                newLiquidityIndex
            );
        }
    }

    /**
     * @dev Updates the reserve indexes and the timestamp of the update
     * @param reserve The reserve reserve to be updated
     * @param scaledDebt The scaled variable debt
     * @param liquidityIndex The last stored liquidity index
     * @param borrowIndex The last stored variable borrow index
     * @param timestamp The timestamp of the last update
     * @return The new updated liquidity index and variable borrow index
     **/
    function _updateIndexes(
        DataTypes.ReserveData storage reserve,
        uint256 scaledDebt,
        uint256 liquidityIndex,
        uint256 borrowIndex,
        uint40 timestamp
    ) internal returns (uint256, uint256) {
        uint256 currentLiquidityRate = reserve.currentLiquidityRate;

        uint256 newLiquidityIndex = liquidityIndex;
        uint256 newBorrowIndex = borrowIndex;

        //only cumulating if there is any income being produced
        if (currentLiquidityRate > 0) {
            uint256 cumulatedLiquidityInterest = MathUtils
                .calculateLinearInterest(currentLiquidityRate, timestamp);

            newLiquidityIndex = cumulatedLiquidityInterest.rayMul(
                liquidityIndex
            );
            require(
                newLiquidityIndex <= type(uint128).max,
                "RL_LIQUIDITY_INDEX_OVERFLOW"
            );

            reserve.liquidityIndex = uint128(newLiquidityIndex);

            //as the liquidity rate might come only from stable rate loans, we need to ensure
            //that there is actual variable debt before accumulating
            if (scaledDebt != 0) {
                uint256 cumulatedBorrowInterest = MathUtils
                    .calculateCompoundedInterest(
                        reserve.currentBorrowRate,
                        timestamp
                    );
                newBorrowIndex = cumulatedBorrowInterest.rayMul(borrowIndex);
                require(
                    newBorrowIndex <= type(uint128).max,
                    "BORROW_INDEX_OVERFLOW"
                );
                reserve.borrowIndex = uint128(newBorrowIndex);
            }
        }

        //solium-disable-next-line
        reserve.lastUpdateTimestamp = uint40(block.timestamp);
        return (newLiquidityIndex, newBorrowIndex);
    }
}
