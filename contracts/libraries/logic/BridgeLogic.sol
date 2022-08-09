// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ReserveLogic} from "./ReserveLogic.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {ValidationLogic} from "./ValidationLogic.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {UserConfiguration} from "../configuration/UserConfiguration.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {PriceOracle} from "../../PriceOracle.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {cToken} from "../../cToken.sol";

library BridgeLogic {
    using ReserveLogic for DataTypes.ReserveData;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using WadRayMath for uint256;
    using PercentageMath for uint256;

    /**
     * @notice Mint unbacked aTokens to a user and updates the unbacked for the reserve.
     * @dev Essentially a supply without transferring the underlying.
     **/
    function executeMintUnbacked(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(address => mapping(uint256 => DataTypes.UnBackedInfor))
            storage unBackedInfor,
        mapping(address => uint256) storage totalUnbacked,
        DataTypes.UserConfigurationMap storage userConfig,
        uint256 debtNumber,
        DataTypes.ExecuteMintUnbackedParams memory params
    ) external {
        DataTypes.ReserveData storage reserve = reservesData[params.asset];

        reserve.updateState();

        ValidationLogic.validateDeposit(reserve, params.amount);

        uint256 unbackedMintCap = reserve.unbackedCap;

        uint256 unbacked = reserve.unbacked += params.amount;

        require(unbacked <= unbackedMintCap, "UNBACKED_MINT_CAP_EXCEEDED");

        address cTokenAddress = reserve.cTokenAddress;
        uint256 bridgeBalance = cToken(cTokenAddress).balanceOf(msg.sender);

        uint256 liquidityIndex = reserve.liquidityIndex;
        require(
            totalUnbacked[params.asset] < bridgeBalance,
            "BRIDGE_NOT_DEPOSIT_ENOUGH"
        );

        // increase total unbacked
        totalUnbacked[params.asset] += params.amount;
        // Save unback info to caculate fee
        unBackedInfor[params.asset][debtNumber] = DataTypes.UnBackedInfor({
            cTokenAmount: params.amount,
            oldIndex: reserve.liquidityIndex
        });

        reserve.updateInterestRates(params.asset, cTokenAddress, 0, 0);

        bool isFirstSupply = cToken(cTokenAddress).mint(
            params.user,
            params.amount,
            liquidityIndex
        );

        if (isFirstSupply) {
            userConfig.setUsingAsCollateral(reserve.id, true);
        }
    }

    /**
     * @notice Back the current unbacked with `amount` and pay `fee`.
     **/
    function executeBackUnbacked(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(address => mapping(uint256 => DataTypes.UnBackedInfor))
            storage unBackedInfor,
        mapping(address => uint256) storage totalUnbacked,
        uint256 debtNumber,
        uint256[] memory unbackedList,
        DataTypes.ExecuteBackUnbackedParams memory params
    ) external {
        DataTypes.ReserveData storage reserve = reservesData[params.asset];

        reserve.updateState();

        uint256 backingAmount = (params.amount < reserve.unbacked)
            ? params.amount
            : reserve.unbacked;

        uint256 liquidityIndex = reserve.liquidityIndex;

        uint256 fee;
        for (uint256 i; i < unbackedList.length; i++) {
            require(unbackedList[i] < debtNumber, "NOT_EXISTS_UNBACKED_INFO");
            DataTypes.UnBackedInfor memory _unbackInfo = unBackedInfor[
                params.asset
            ][unbackedList[i]];
            fee +=
                _unbackInfo.cTokenAmount *
                (liquidityIndex / _unbackInfo.oldIndex - 1);
        }

        uint256 added = backingAmount + fee;
        address cTokenAddress = reserve.cTokenAddress;
        reserve.cumulateToLiquidityIndex(
            IERC20(cTokenAddress).totalSupply(),
            fee
        );

        // update
        reserve.unbacked -= backingAmount;
        totalUnbacked[params.asset] -= backingAmount;

        reserve.updateInterestRates(params.asset, cTokenAddress, added, 0);
        IERC20(params.asset).transferFrom(msg.sender, cTokenAddress, added);
    }
}
