// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IERC20} from "../../interfaces/IERC20.sol";
import {ReserveLogic} from "./ReserveLogic.sol";
import {GenericLogic} from "./GenericLogic.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {UserConfiguration} from "../configuration/UserConfiguration.sol";
import {ReserveInterestRateStrategy} from "../../ReserveInterestRateStrategy.sol";
import {DataTypes} from "../types/DataTypes.sol";

/**
 * @title ReserveLogic library
 * @notice Implements functions to validate the different actions of the protocol
 */
library ValidationLogic {
    using ReserveLogic for DataTypes.ReserveData;
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;

    /**
     * @dev Validates a deposit action
     * @param reserve The reserve object on which the user is depositing
     * @param amount The amount to be deposited
     */
    function validateDeposit(
        DataTypes.ReserveData storage reserve,
        uint256 amount
    ) external view {
        require(amount != 0, "INVALID_AMOUNT");
        require(reserve.configuration.getActive(), "NO_ACTIVE_RESERVE");
    }

    /**
     * @dev Validates a withdraw action
     * @param reserveAddress The address of the reserve
     * @param amount The amount to be withdrawn
     * @param userBalance The balance of the user
     * @param reservesData The reserves state
     * @param userConfig The user configuration
     * @param reserves The addresses of the reserves
     * @param reservesCount The number of reserves
     * @param oracle The price oracle
     */
    function validateWithdraw(
        address reserveAddress,
        uint256 amount,
        uint256 userBalance,
        mapping(address => DataTypes.ReserveData) storage reservesData,
        DataTypes.UserConfigurationMap storage userConfig,
        mapping(uint256 => address) storage reserves,
        uint256 reservesCount,
        address oracle
    ) external view {
        require(amount != 0, "INVALID_AMOUNT");
        require(amount <= userBalance, "NOT_ENOUGH_AVAILABLE_USER_BALANCE");
        require(
            reservesData[reserveAddress].configuration.getActive(),
            "NO_ACTIVE_RESERVE"
        );

        require(
            GenericLogic.balanceDecreaseAllowed(
                reserveAddress,
                msg.sender,
                amount,
                reservesData,
                userConfig,
                reserves,
                reservesCount,
                oracle
            ),
            "TRANSFER_NOT_ALLOWED"
        );
    }

    struct ValidateBorrowLocalVars {
        uint256 currentLtv;
        uint256 currentLiquidationThreshold;
        uint256 amountOfCollateralNeededUSD;
        uint256 userCollateralBalanceUSD;
        uint256 userBorrowBalanceUSD;
        uint256 availableLiquidity;
        uint256 healthFactor;
    }

    /**
     * @dev Validates a borrow action
     * @param asset The address of the asset to borrow
     * @param reserve The reserve state from which the user is borrowing
     * @param userAddress The address of the user
     * @param amount The amount to be borrowed
     * @param amountInUSD The amount to be borrowed, in USD
     * @param reservesData The state of all the reserves
     * @param userConfig The state of the user for the specific reserve
     * @param reserves The addresses of all the active reserves
     * @param reservesCount The number of reserves
     * @param oracle The price oracle
     */

    function validateBorrow(
        address asset,
        DataTypes.ReserveData storage reserve,
        address userAddress,
        uint256 amount,
        uint256 amountInUSD,
        mapping(address => DataTypes.ReserveData) storage reservesData,
        DataTypes.UserConfigurationMap storage userConfig,
        mapping(uint256 => address) storage reserves,
        uint256 reservesCount,
        address oracle
    ) external view {
        ValidateBorrowLocalVars memory vars;
        require(reserve.configuration.getActive(), "NO_ACTIVE_RESERVE");
        require(amount != 0, "INVALID_AMOUNT");

        (
            vars.userCollateralBalanceUSD,
            vars.userBorrowBalanceUSD,
            vars.currentLtv,
            vars.currentLiquidationThreshold,
            vars.healthFactor
        ) = GenericLogic.calculateUserAccountData(
            userAddress,
            reservesData,
            userConfig,
            reserves,
            reservesCount,
            oracle
        );

        require(vars.userCollateralBalanceUSD > 0, "COLLATERAL_BALANCE_IS_0");

        require(
            vars.healthFactor >
                GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
            "HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD"
        );

        //add the current already borrowed amount to the amount requested to calculate the total collateral needed.
        vars.amountOfCollateralNeededUSD =
            vars.userBorrowBalanceUSD +
            amountInUSD.percentDiv(vars.currentLtv); //LTV is calculated in percentage

        require(
            vars.amountOfCollateralNeededUSD <= vars.userCollateralBalanceUSD,
            "COLLATERAL_CANNOT_COVER_NEW_BORROW"
        );
    }

    /**
     * @dev Validates a repay action
     * @param reserve The reserve state from which the user is repaying
     * @param amountSent The amount sent for the repayment. Can be an actual value or uint(-1)
     * @param onBehalfOf The address of the user msg.sender is repaying for
     * @param variableDebt The borrow balance of the user
     */
    function validateRepay(
        DataTypes.ReserveData storage reserve,
        uint256 amountSent,
        address onBehalfOf,
        uint256 variableDebt
    ) external view {
        bool isActive = reserve.configuration.getActive();

        require(isActive, "NO_ACTIVE_RESERVE");

        require(amountSent > 0, "INVALID_AMOUNT");

        require(variableDebt > 0, "NO_DEBT_OF_SELECTED_TYPE");

        require(
            amountSent != type(uint256).max || msg.sender == onBehalfOf,
            "NO_EXPLICIT_AMOUNT_TO_REPAY_ON_BEHALF"
        );
    }

    /**
     * @dev Validates the liquidation action
     * @param collateralReserve The reserve data of the collateral
     * @param principalReserve The reserve data of the principal
     * @param userConfig The user configuration
     * @param userHealthFactor The user's health factor
     * @param userVariableDebt Total variable debt balance of the user
     **/
    function validateLiquidationCall(
        DataTypes.ReserveData storage collateralReserve,
        DataTypes.ReserveData storage principalReserve,
        DataTypes.UserConfigurationMap storage userConfig,
        uint256 userHealthFactor,
        uint256 userVariableDebt
    ) external view returns (uint256, string memory) {
        if (
            !collateralReserve.configuration.getActive() ||
            !principalReserve.configuration.getActive()
        ) {
            return (1, "NO_ACTIVE_RESERVE");
        }

        if (
            userHealthFactor >= GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD
        ) {
            return (1, "HEALTH_FACTOR_NOT_BELOW_THRESHOLD");
        }

        bool isCollateralEnabled = collateralReserve
            .configuration
            .getLiquidationThreshold() >
            0 &&
            userConfig.isUsingAsCollateral(collateralReserve.id);

        //if collateral isn't enabled as collateral by user, it cannot be liquidated
        if (!isCollateralEnabled) {
            return (1, "COLLATERAL_CANNOT_BE_LIQUIDATED");
        }

        if (userVariableDebt == 0) {
            return (1, "SPECIFIED_CURRENCY_NOT_BORROWED_BY_USER");
        }

        return (0, "OK");
    }

    /**
     * @dev Validates an tToken transfer
     * @param from The user from which the tTokens are being transferred
     * @param reservesData The state of all the reserves
     * @param userConfig The state of the user for the specific reserve
     * @param reserves The addresses of all the active reserves
     * @param reservesCount The counting of reserves
     * @param oracle The price oracle
     */
    function validateTransfer(
        address from,
        mapping(address => DataTypes.ReserveData) storage reservesData,
        DataTypes.UserConfigurationMap storage userConfig,
        mapping(uint256 => address) storage reserves,
        uint256 reservesCount,
        address oracle
    ) external view {
        (, , , , uint256 healthFactor) = GenericLogic.calculateUserAccountData(
            from,
            reservesData,
            userConfig,
            reserves,
            reservesCount,
            oracle
        );

        require(
            healthFactor >= GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
            "TRANSFER_NOT_ALLOWED"
        );
    }
}
