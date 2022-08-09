// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "../../interfaces/IERC20.sol";
import {cToken} from "../../cToken.sol";
import {UserConfiguration} from "../configuration/UserConfiguration.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {ValidationLogic} from "./ValidationLogic.sol";
import {ReserveLogic} from "./ReserveLogic.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";

library DepositLogic {
    using ReserveLogic for DataTypes.ReserveData;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using WadRayMath for uint256;
    using PercentageMath for uint256;

    function executeDeposit(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.ExecuteDepositParams memory params
    ) external {
        DataTypes.ReserveData storage reserve = reservesData[params.asset];

        address cTokenAddress = reserve.cTokenAddress;

        reserve.updateState();

        ValidationLogic.validateDeposit(reserve, params.amount);

        reserve.updateInterestRates(
            params.asset,
            cTokenAddress,
            params.amount,
            0
        );

        IERC20(params.asset).transferFrom(
            msg.sender,
            cTokenAddress,
            params.amount
        );
        bool isFirstDeposit = cToken(cTokenAddress).mint(
            params.onBehalfOf,
            params.amount,
            reserve.liquidityIndex
        );
        if (isFirstDeposit) {
            userConfig.setUsingAsCollateral(reserve.id, true);
        }
    }

    /**
     * @notice Implements the withdraw feature. Through `withdraw()`, users redeem their aTokens for the underlying asset
     * previously supplied in the Aave protocol.
     * @dev Emits the `Withdraw()` event.
     * @dev If the user withdraws everything, `ReserveUsedAsCollateralDisabled()` is emitted.
     * @param reservesData The state of all the reserves
     * @param reservesList The addresses of all the active reserves
     * @param params The additional parameters needed to execute the withdraw function
     * @return The actual amount withdrawn
     */
    function executeWithdraw(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.ExecuteWithdrawParams memory params
    ) external returns (uint256) {
        DataTypes.ReserveData storage reserve = reservesData[params.asset];
        address cTokenAddress = reserve.cTokenAddress;
        reserve.updateState();
        uint256 userBalance = cToken(cTokenAddress).balanceOf(msg.sender);
        uint256 amountToWithdraw = params.amount;
        if (params.amount == type(uint256).max) {
            amountToWithdraw = userBalance;
        }
        ValidationLogic.validateWithdraw(
            params.asset,
            amountToWithdraw,
            userBalance,
            reservesData,
            userConfig,
            reservesList,
            params.reservesCount,
            params.oracle
        );
        reserve.updateInterestRates(
            params.asset,
            cTokenAddress,
            0,
            amountToWithdraw
        );
        if (amountToWithdraw == userBalance) {
            userConfig.setUsingAsCollateral(reserve.id, false);
        }
        cToken(cTokenAddress).burn(
            msg.sender,
            params.to,
            amountToWithdraw,
            reserve.liquidityIndex
        );
        return amountToWithdraw;
    }
}
