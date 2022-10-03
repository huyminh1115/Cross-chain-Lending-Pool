pragma solidity ^0.8.0;

import {DataTypes} from "../libraries/types/DataTypes.sol";
import {IERC20} from "../interfaces/IERC20.sol";

interface ILendingPool {
    event MintUnbacked(
        address indexed reserve,
        address indexed bridge,
        address user,
        uint256 amount
    );

    event BackUnbacked(
        address indexed reserve,
        address indexed backer,
        uint256[] debtList,
        uint256 amount,
        uint256 totalFee
    );

    event Deposit(
        address indexed reserve,
        address user,
        address indexed onBehalfOf,
        uint256 amount
    );

    event Withdraw(
        address indexed reserve,
        address indexed user,
        address indexed to,
        uint256 amount
    );

    event Borrow(address indexed reserve, address indexed user, uint256 amount);

    event Repay(
        address indexed reserve,
        address indexed user,
        address indexed repayer,
        uint256 amount
    );

    event Paused();

    event Unpaused();

    event LiquidationCall(
        address indexed collateralAsset,
        address indexed debtAsset,
        address indexed user,
        uint256 debtToCover,
        uint256 liquidatedCollateralAmount,
        address liquidator,
        bool receivecToken
    );

    function mintUnbacked(
        address asset,
        uint256 amount,
        address user
    ) external;

    function backUnbacked(
        address asset,
        uint256 amount,
        uint256[] calldata unbackedList
    ) external;

    function getPriceOracle() external view returns (address);

    function setBridge(address bridgeAddress, bool state) external;

    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf
    ) external;

    function setUnbackedCap(address, uint256) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    function borrow(address asset, uint256 amount) external;

    function repay(
        address asset,
        uint256 amount,
        address onBehalfOf
    ) external returns (uint256);

    function liquidate(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receivecToken
    ) external;

    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralUSD,
            uint256 totalDebtUSD,
            uint256 availableBorrowsUSD,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    function getUnbacked(address bridge, address asset)
        external
        view
        returns (uint256);

    function initReserve(
        IERC20 asset,
        address cTokenAddress,
        address variableDebtAddress,
        address interestRateStrategyAddress
    ) external;

    // Return Index
    function getReserveNormalizedIncome(address asset)
        external
        view
        returns (uint256);

    function finalizeTransfer(
        address asset,
        address from,
        address to,
        uint256 amount,
        uint256 balanceFromAfter,
        uint256 balanceToBefore
    ) external;

    function getReserveData(address asset)
        external
        view
        returns (DataTypes.ReserveData memory);

    function getReservesList() external view returns (address[] memory);

    function getReserveNormalizedVariableDebt(address asset)
        external
        view
        returns (uint256);

    function setReserveInterestRateStrategyAddress(
        address reserve,
        address rateStrategyAddress
    ) external;

    function setConfiguration(address reserve, uint256 configuration) external;

    /**
     * @dev Returns the configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The configuration of the reserve
     **/
    function getConfiguration(address asset)
        external
        view
        returns (DataTypes.ReserveConfigurationMap memory);

    /**
     * @dev Returns the configuration of the user across all the reserves
     * @param user The user address
     * @return The configuration of the user
     **/
    function getUserConfiguration(address user)
        external
        view
        returns (DataTypes.UserConfigurationMap memory);

    function setPause(bool val) external;

    function paused() external view returns (bool);
}
