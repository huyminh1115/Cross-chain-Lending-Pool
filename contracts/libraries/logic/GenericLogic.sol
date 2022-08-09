// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IERC20} from "../../interfaces/IERC20.sol";
import {ReserveLogic} from "./ReserveLogic.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {UserConfiguration} from "../configuration/UserConfiguration.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {PriceOracle} from "../../PriceOracle.sol";
import {DataTypes} from "../types/DataTypes.sol";

/**
 * @title GenericLogic library
 * @title Implements protocol-level logic to calculate and validate the state of a user
 */
library GenericLogic {
    using ReserveLogic for DataTypes.ReserveData;
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;

    uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1 ether;

    struct balanceDecreaseAllowedLocalVars {
        uint256 decimals;
        uint256 liquidationThreshold;
        uint256 totalCollateralInUSD;
        uint256 totalDebtInUSD;
        uint256 avgLiquidationThreshold;
        uint256 amountToDecreaseInUSD;
        uint256 collateralBalanceAfterDecrease;
        uint256 liquidationThresholdAfterDecrease;
        uint256 healthFactorAfterDecrease;
        bool reserveUsageAsCollateralEnabled;
    }

    /**
     * @dev Checks if a specific balance decrease is allowed
     * (i.e. doesn't bring the user borrow position health factor under HEALTH_FACTOR_LIQUIDATION_THRESHOLD)
     * @param asset The address of the underlying asset of the reserve
     * @param user The address of the user
     * @param amount The amount to decrease
     * @param reservesData The data of all the reserves
     * @param userConfig The user configuration
     * @param reserves The list of all the active reserves
     * @param oracle The address of the oracle contract
     * @return true if the decrease of the balance is allowed
     **/
    function balanceDecreaseAllowed(
        address asset,
        address user,
        uint256 amount,
        mapping(address => DataTypes.ReserveData) storage reservesData,
        DataTypes.UserConfigurationMap calldata userConfig,
        mapping(uint256 => address) storage reserves,
        uint256 reservesCount,
        address oracle
    ) external view returns (bool) {
        if (
            !userConfig.isBorrowingAny() ||
            !userConfig.isUsingAsCollateral(reservesData[asset].id)
        ) {
            return true;
        }

        balanceDecreaseAllowedLocalVars memory vars;

        (, vars.liquidationThreshold, , vars.decimals, ) = reservesData[asset]
            .configuration
            .getParams();

        if (vars.liquidationThreshold == 0) {
            return true;
        }

        (
            vars.totalCollateralInUSD,
            vars.totalDebtInUSD,
            ,
            vars.avgLiquidationThreshold,

        ) = calculateUserAccountData(
            user,
            reservesData,
            userConfig,
            reserves,
            reservesCount,
            oracle
        );

        if (vars.totalDebtInUSD == 0) {
            return true;
        }

        vars.amountToDecreaseInUSD =
            (PriceOracle(oracle).getAssetPrice(asset) * amount) /
            (10**vars.decimals);

        vars.collateralBalanceAfterDecrease =
            vars.totalCollateralInUSD -
            (vars.amountToDecreaseInUSD);
        //if there is a borrow, there can't be 0 collateral
        if (vars.collateralBalanceAfterDecrease == 0) {
            return false;
        }

        vars.liquidationThresholdAfterDecrease =
            vars.totalCollateralInUSD *
            vars.avgLiquidationThreshold -
            (vars.amountToDecreaseInUSD * (vars.liquidationThreshold)) /
            (vars.collateralBalanceAfterDecrease);

        uint256 healthFactorAfterDecrease = calculateHealthFactorFromBalances(
            vars.collateralBalanceAfterDecrease,
            vars.totalDebtInUSD,
            vars.liquidationThresholdAfterDecrease
        );

        return
            healthFactorAfterDecrease >=
            GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    }

    struct CalculateUserAccountDataVars {
        uint256 reserveUnitPrice;
        uint256 tokenUnit;
        uint256 compoundedLiquidityBalance;
        uint256 compoundedBorrowBalance;
        uint256 decimals;
        uint256 ltv;
        uint256 liquidationThreshold;
        uint256 i;
        uint256 healthFactor;
        uint256 totalCollateralInUSD;
        uint256 totalDebtInUSD;
        uint256 avgLtv;
        uint256 avgLiquidationThreshold;
        uint256 reservesLength;
        bool healthFactorBelowThreshold;
        address currentReserveAddress;
        bool usageAsCollateralEnabled;
        bool userUsesReserveAsCollateral;
    }

    /**
     * @dev Calculates the user data across the reserves.
     * this includes the total liquidity/collateral/borrow balances in USD,
     * the average Loan To Value, the average Liquidation Ratio, and the Health factor.
     * @param user The address of the user
     * @param reservesData Data of all the reserves
     * @param userConfig The configuration of the user
     * @param reserves The list of the available reserves
     * @param oracle The price oracle address
     * @return The total collateral and total debt of the user in USD, the avg ltv, liquidation threshold and the HF
     **/
    function calculateUserAccountData(
        address user,
        mapping(address => DataTypes.ReserveData) storage reservesData,
        DataTypes.UserConfigurationMap memory userConfig,
        mapping(uint256 => address) storage reserves,
        uint256 reservesCount,
        address oracle
    )
        internal
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        CalculateUserAccountDataVars memory vars;
        if (userConfig.isEmpty()) {
            return (0, 0, 0, 0, type(uint256).max);
        }
        for (vars.i = 0; vars.i < reservesCount; vars.i++) {
            if (!userConfig.isUsingAsCollateralOrBorrowing(vars.i)) {
                continue;
            }

            vars.currentReserveAddress = reserves[vars.i];
            DataTypes.ReserveData storage currentReserve = reservesData[
                vars.currentReserveAddress
            ];

            (
                vars.ltv,
                vars.liquidationThreshold,
                ,
                vars.decimals,

            ) = currentReserve.configuration.getParams();

            vars.tokenUnit = 10**vars.decimals;
            vars.reserveUnitPrice = PriceOracle(oracle).getAssetPrice(
                vars.currentReserveAddress
            );

            if (
                vars.liquidationThreshold != 0 &&
                userConfig.isUsingAsCollateral(vars.i)
            ) {
                vars.compoundedLiquidityBalance = IERC20(
                    currentReserve.cTokenAddress
                ).balanceOf(user);

                uint256 liquidityBalanceUSD = (vars.reserveUnitPrice *
                    (vars.compoundedLiquidityBalance)) / (vars.tokenUnit);

                vars.totalCollateralInUSD =
                    vars.totalCollateralInUSD +
                    (liquidityBalanceUSD);

                vars.avgLtv = vars.avgLtv + (liquidityBalanceUSD * (vars.ltv));
                vars.avgLiquidationThreshold =
                    vars.avgLiquidationThreshold +
                    (liquidityBalanceUSD * (vars.liquidationThreshold));
            }

            if (userConfig.isBorrowing(vars.i)) {
                vars.compoundedBorrowBalance = IERC20(
                    currentReserve.debtTokenAddress
                ).balanceOf(user);
                vars.totalDebtInUSD =
                    vars.totalDebtInUSD +
                    ((vars.reserveUnitPrice * (vars.compoundedBorrowBalance)) /
                        (vars.tokenUnit));
            }
        }

        vars.avgLtv = vars.totalCollateralInUSD > 0
            ? vars.avgLtv / (vars.totalCollateralInUSD)
            : 0;
        vars.avgLiquidationThreshold = vars.totalCollateralInUSD > 0
            ? vars.avgLiquidationThreshold / (vars.totalCollateralInUSD)
            : 0;

        vars.healthFactor = calculateHealthFactorFromBalances(
            vars.totalCollateralInUSD,
            vars.totalDebtInUSD,
            vars.avgLiquidationThreshold
        );
        return (
            vars.totalCollateralInUSD,
            vars.totalDebtInUSD,
            vars.avgLtv,
            vars.avgLiquidationThreshold,
            vars.healthFactor
        );
    }

    /**
     * @dev Calculates the health factor from the corresponding balances
     * @param totalCollateralInUSD The total collateral in USD
     * @param totalDebtInUSD The total debt in USD
     * @param liquidationThreshold The avg liquidation threshold
     * @return The health factor calculated from the balances provided
     **/
    function calculateHealthFactorFromBalances(
        uint256 totalCollateralInUSD,
        uint256 totalDebtInUSD,
        uint256 liquidationThreshold
    ) internal pure returns (uint256) {
        if (totalDebtInUSD == 0) return type(uint256).max;

        return
            (totalCollateralInUSD.percentMul(liquidationThreshold)).wadDiv(
                totalDebtInUSD
            );
    }

    /**
     * @dev Calculates the equivalent amount in USD that an user can borrow, depending on the available collateral and the
     * average Loan To Value
     * @param totalCollateralInUSD The total collateral in USD
     * @param totalDebtInUSD The total borrow balance
     * @param ltv The average loan to value
     * @return the amount available to borrow in USD for the user
     **/

    function calculateAvailableBorrowsUSD(
        uint256 totalCollateralInUSD,
        uint256 totalDebtInUSD,
        uint256 ltv
    ) internal pure returns (uint256) {
        uint256 availableBorrowsUSD = totalCollateralInUSD.percentMul(ltv);

        if (availableBorrowsUSD < totalDebtInUSD) {
            return 0;
        }

        availableBorrowsUSD = availableBorrowsUSD - (totalDebtInUSD);
        return availableBorrowsUSD;
    }
}
