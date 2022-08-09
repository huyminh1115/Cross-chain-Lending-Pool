// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IERC20} from "../../interfaces/IERC20.sol";
import {cToken} from "../../cToken.sol";
import {debtToken} from "../../debtToken.sol";
import {PriceOracle} from "../../PriceOracle.sol";
import {WadRayMath} from "../../libraries/math/WadRayMath.sol";
import {PercentageMath} from "../../libraries/math/PercentageMath.sol";
import {ReserveLogic} from "../../libraries/logic/ReserveLogic.sol";
import {ValidationLogic} from "../../libraries/logic/ValidationLogic.sol";
import {GenericLogic} from "../../libraries/logic/GenericLogic.sol";
import {DataTypes} from "../../libraries/types/DataTypes.sol";
import {UserConfiguration} from "../../libraries/configuration/UserConfiguration.sol";
import {ReserveConfiguration} from "../../libraries/configuration/ReserveConfiguration.sol";

library LiquidationManager {
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using ReserveLogic for DataTypes.ReserveData;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;

    uint256 internal constant LIQUIDATION_CLOSE_FACTOR_PERCENT = 5000;

    struct LiquidationCallLocalVars {
        uint256 userCollateralBalance;
        uint256 userVariableDebt;
        uint256 maxLiquidatableDebt;
        uint256 actualDebtToLiquidate;
        uint256 liquidationRatio;
        uint256 maxAmountCollateralToLiquidate;
        uint256 maxCollateralToLiquidate;
        uint256 debtAmountNeeded;
        uint256 healthFactor;
        uint256 liquidatorPreviousTTokenBalance;
        cToken collateralTtoken;
        bool isCollateralEnabled;
        uint256 errorCode;
        string errorMsg;
    }

    function executeLiquidation(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        mapping(address => DataTypes.UserConfigurationMap) storage userConfig,
        DataTypes.ExecuteLiquidateParams memory params
    ) external returns (uint256, uint256) {
        DataTypes.ReserveData storage collateralReserve = reservesData[
            params.collateralAsset
        ];
        DataTypes.ReserveData storage debtReserve = reservesData[
            params.debtAsset
        ];

        debtReserve.updateState();
        collateralReserve.updateState();

        LiquidationCallLocalVars memory vars;
        address user = params.user;

        (, , , , vars.healthFactor) = GenericLogic.calculateUserAccountData(
            user,
            reservesData,
            userConfig[user],
            reservesList,
            params.reservesCount,
            params.oracle
        );
        vars.userVariableDebt = IERC20(debtReserve.debtTokenAddress).balanceOf(
            params.user
        );
        (vars.errorCode, vars.errorMsg) = ValidationLogic
            .validateLiquidationCall(
                collateralReserve,
                debtReserve,
                userConfig[user],
                vars.healthFactor,
                vars.userVariableDebt
            );

        if (vars.errorCode != 0) {
            revert(vars.errorMsg);
        }

        vars.collateralTtoken = cToken(collateralReserve.cTokenAddress);

        vars.userCollateralBalance = vars.collateralTtoken.balanceOf(user);

        vars.maxLiquidatableDebt = vars.userVariableDebt.percentMul(
            LIQUIDATION_CLOSE_FACTOR_PERCENT
        );

        vars.actualDebtToLiquidate = params.debtToCover >
            vars.maxLiquidatableDebt
            ? vars.maxLiquidatableDebt
            : params.debtToCover;
        (
            vars.maxCollateralToLiquidate,
            vars.debtAmountNeeded
        ) = _calculateAvailableCollateralToLiquidate(
            collateralReserve,
            debtReserve,
            params.collateralAsset,
            params.debtAsset,
            params.oracle,
            vars.actualDebtToLiquidate,
            vars.userCollateralBalance
        );

        // If debtAmountNeeded < actualDebtToLiquidate, there isn't enough
        // collateral to cover the actual amount that is being liquidated, hence we liquidate
        // a smaller amount

        if (vars.debtAmountNeeded < vars.actualDebtToLiquidate) {
            vars.actualDebtToLiquidate = vars.debtAmountNeeded;
        }

        // If the liquidator reclaims the underlying asset, we make sure there is enough available liquidity in the
        // collateral reserve
        if (!params.receiveTToken) {
            uint256 currentAvailableCollateral = IERC20(params.collateralAsset)
                .balanceOf(address(vars.collateralTtoken));
            if (currentAvailableCollateral < vars.maxCollateralToLiquidate) {
                revert("LPCM_NOT_ENOUGH_LIQUIDITY_TO_LIQUIDATE");
            }
        }

        if (vars.userVariableDebt >= vars.actualDebtToLiquidate) {
            debtToken(debtReserve.debtTokenAddress).burn(
                user,
                vars.actualDebtToLiquidate,
                debtReserve.borrowIndex
            );
        } else {
            // If the user doesn't have variable debt, no need to try to burn variable debt tokens
            if (vars.userVariableDebt > 0) {
                debtToken(debtReserve.debtTokenAddress).burn(
                    user,
                    vars.userVariableDebt,
                    debtReserve.borrowIndex
                );
            }
        }
        debtReserve.updateInterestRates(
            params.debtAsset,
            debtReserve.cTokenAddress,
            vars.actualDebtToLiquidate,
            0
        );

        if (params.receiveTToken) {
            vars.liquidatorPreviousTTokenBalance = cToken(vars.collateralTtoken)
                .balanceOf(msg.sender);
            vars.collateralTtoken.transferOnLiquidation(
                user,
                msg.sender,
                vars.maxCollateralToLiquidate
            );

            if (vars.liquidatorPreviousTTokenBalance == 0) {
                DataTypes.UserConfigurationMap
                    storage liquidatorConfig = userConfig[msg.sender];
                liquidatorConfig.setUsingAsCollateral(
                    collateralReserve.id,
                    true
                );
            }
        } else {
            collateralReserve.updateInterestRates(
                params.collateralAsset,
                address(vars.collateralTtoken),
                0,
                vars.maxCollateralToLiquidate
            );

            // Burn the equivalent amount of tToken, sending the underlying to the liquidator
            vars.collateralTtoken.burn(
                user,
                msg.sender,
                vars.maxCollateralToLiquidate,
                collateralReserve.liquidityIndex
            );
        }

        // If the collateral being liquidated is equal to the user balance,
        // we set the currency as not being used as collateral anymore
        if (vars.maxCollateralToLiquidate == vars.userCollateralBalance) {
            userConfig[user].setUsingAsCollateral(collateralReserve.id, false);
        }
        // Transfers the debt asset being repaid to the tToken, where the liquidity is kept
        IERC20(params.debtAsset).transferFrom(
            msg.sender,
            debtReserve.cTokenAddress,
            vars.actualDebtToLiquidate
        );

        return (vars.actualDebtToLiquidate, vars.maxCollateralToLiquidate);
    }

    struct AvailableCollateralToLiquidateLocalVars {
        uint256 userCompoundedBorrowBalance;
        uint256 liquidationBonus;
        uint256 collateralPrice;
        uint256 debtAssetPrice;
        uint256 maxAmountCollateralToLiquidate;
        uint256 debtAssetDecimals;
        uint256 collateralDecimals;
    }

    /**
     * @dev Calculates how much of a specific collateral can be liquidated, given
     * a certain amount of debt asset.
     * - This function needs to be called after all the checks to validate the liquidation have been performed,
     *   otherwise it might fail.
     * @param collateralReserve The data of the collateral reserve
     * @param debtReserve The data of the debt reserve
     * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of the liquidation
     * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
     * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
     * @param userCollateralBalance The collateral balance for the specific `collateralAsset` of the user being liquidated
     * @return collateralAmount: The maximum amount that is possible to liquidate given all the liquidation constraints
     *                           (user balance, close factor)
     *         debtAmountNeeded: The amount to repay with the liquidation
     **/
    function _calculateAvailableCollateralToLiquidate(
        DataTypes.ReserveData storage collateralReserve,
        DataTypes.ReserveData storage debtReserve,
        address collateralAsset,
        address debtAsset,
        address priceOracle,
        uint256 debtToCover,
        uint256 userCollateralBalance
    ) internal view returns (uint256, uint256) {
        uint256 collateralAmount = 0;
        uint256 debtAmountNeeded = 0;
        PriceOracle oracle = PriceOracle(priceOracle);

        AvailableCollateralToLiquidateLocalVars memory vars;

        vars.collateralPrice = oracle.getAssetPrice(collateralAsset);
        vars.debtAssetPrice = oracle.getAssetPrice(debtAsset);

        (
            ,
            ,
            vars.liquidationBonus,
            vars.collateralDecimals,

        ) = collateralReserve.configuration.getParams();
        vars.debtAssetDecimals = debtReserve.configuration.getDecimals();

        // This is the maximum possible amount of the selected collateral that can be liquidated, given the
        // max amount of liquidatable debt
        vars.maxAmountCollateralToLiquidate =
            (vars.debtAssetPrice *
                (debtToCover) *
                (10**vars.collateralDecimals).percentMul(
                    vars.liquidationBonus
                )) /
            (vars.collateralPrice * (10**vars.debtAssetDecimals));

        if (vars.maxAmountCollateralToLiquidate > userCollateralBalance) {
            collateralAmount = userCollateralBalance;
            debtAmountNeeded =
                (vars.collateralPrice *
                    (collateralAmount) *
                    (10**vars.debtAssetDecimals)) /
                (vars.debtAssetPrice * (10**vars.collateralDecimals))
                    .percentDiv(vars.liquidationBonus);
        } else {
            collateralAmount = vars.maxAmountCollateralToLiquidate;
            debtAmountNeeded = debtToCover;
        }
        return (collateralAmount, debtAmountNeeded);
    }
}
