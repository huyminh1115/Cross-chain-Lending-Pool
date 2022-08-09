// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "../../interfaces/IERC20.sol";
import {cToken} from "../../cToken.sol";
import {debtToken} from "../../debtToken.sol";
import {UserConfiguration} from "../configuration/UserConfiguration.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {ValidationLogic} from "./ValidationLogic.sol";
import {ReserveLogic} from "./ReserveLogic.sol";
import {PriceOracle} from "../../PriceOracle.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";

/**
 * @title BorrowLogic library
 * @notice Implements the base logic for all the actions related to borrowing
 */
library BorrowLogic {
    using ReserveLogic for DataTypes.ReserveData;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    function executeBorrow(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.ExecuteBorrowParams memory params
    ) public {
        DataTypes.ReserveData storage reserve = reservesData[params.asset];

        reserve.updateState();

        address cTokenAddress = reserve.cTokenAddress;
        uint256 amountInUSD = (PriceOracle(params.oracle).getAssetPrice(
            params.asset
        ) * (params.amount)) / (10**reserve.configuration.getDecimals());

        ValidationLogic.validateBorrow(
            params.asset,
            reserve,
            params.user,
            params.amount,
            amountInUSD,
            reservesData,
            userConfig,
            reservesList,
            params.reservesCount,
            params.oracle
        );

        bool isFirstBorrowing = false;
        isFirstBorrowing = debtToken(reserve.debtTokenAddress).mint(
            params.user,
            params.user,
            params.amount,
            reserve.borrowIndex
        );

        if (isFirstBorrowing) {
            userConfig.setBorrowing(reserve.id, true);
        }

        reserve.updateInterestRates(
            params.asset,
            cTokenAddress,
            0,
            params.releaseUnderlying ? params.amount : 0
        );

        if (params.releaseUnderlying) {
            cToken(cTokenAddress).transferUnderlyingTo(
                params.user,
                params.amount
            );
        }
    }

    /**
     * @notice Implements the repay feature. Repaying transfers the underlying back to the aToken and clears the
     * equivalent amount of debt for the user by burning the corresponding debt token. For isolated positions, it also
     * reduces the isolated debt.
     * @dev  Emits the `Repay()` event
     * @param reservesData The state of all the reserves
     * @param reservesList The addresses of all the active reserves
     * @param userConfig The user configuration mapping that tracks the supplied/borrowed assets
     * @param params The additional parameters needed to execute the repay function
     * @return The actual amount being repaid
     */
    function executeRepay(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.ExecuteRepayParams memory params
    ) external returns (uint256) {
        DataTypes.ReserveData storage reserve = reservesData[params.asset];

        reserve.updateState();

        uint256 debt = IERC20(reserve.debtTokenAddress).balanceOf(
            params.onBehalfOf
        );

        ValidationLogic.validateRepay(
            reserve,
            params.amount,
            params.onBehalfOf,
            debt
        );
        uint256 paybackAmount = debt;
        if (params.amount < paybackAmount) {
            paybackAmount = params.amount;
        }

        debtToken(reserve.debtTokenAddress).burn(
            params.onBehalfOf,
            paybackAmount,
            reserve.borrowIndex
        );
        address cTokenAddress = reserve.cTokenAddress;
        reserve.updateInterestRates(
            params.asset,
            cTokenAddress,
            paybackAmount,
            0
        );
        if (debt - (paybackAmount) == 0) {
            userConfig.setBorrowing(reserve.id, false);
        }
        IERC20(params.asset).transferFrom(
            msg.sender,
            cTokenAddress,
            paybackAmount
        );
    }
}
