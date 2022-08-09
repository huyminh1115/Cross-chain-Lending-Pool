pragma solidity ^0.8.0;

import {DataTypes} from "../libraries/types/DataTypes.sol";
import {IERC20} from "../interfaces/IERC20.sol";

interface ILendingPool {
    /**
     * @dev Emitted on mintUnbacked()
     * @param reserve The address of the underlying asset of the reserve
     * @param bridge The address of bridge
     * @param user The beneficiary of the supplied assets, receiving the cTokens
     * @param amount The amount of supplied assets
     **/
    event MintUnbacked(
        address indexed reserve,
        address indexed bridge,
        address user,
        uint256 amount
    );

    /**
     * @dev Emitted on backUnbacked()
     * @param reserve The address of the underlying asset of the reserve
     * @param backer The address paying for the backing
     * @param debtList list of debt
     * @param amount backed amount
     * @param totalFee total fee
     **/
    event BackUnbacked(
        address indexed reserve,
        address indexed backer,
        uint256[] debtList,
        uint256 amount,
        uint256 totalFee
    );

    /**
     * @dev Emitted on deposit()
     * @param reserve The address of the underlying asset of the reserve
     * @param user The address initiating the deposit
     * @param onBehalfOf The beneficiary of the deposit, receiving the cTokens
     * @param amount The amount deposited
     **/
    event Deposit(
        address indexed reserve,
        address user,
        address indexed onBehalfOf,
        uint256 amount
    );

    /**
     * @dev Emitted on withdraw()
     * @param reserve The address of the underlyng asset being withdrawn
     * @param user The address initiating the withdrawal, owner of cTokens
     * @param to Address that will receive the underlying
     * @param amount The amount to be withdrawn
     **/
    event Withdraw(
        address indexed reserve,
        address indexed user,
        address indexed to,
        uint256 amount
    );

    /**
     * @dev Emitted on borrow() and flashLoan() when debt needs to be opened
     * @param reserve The address of the underlying asset being borrowed
     * @param user The address of the user initiating the borrow(), receiving the funds on borrow() or just
     * initiator of the transaction on flashLoan()
     * @param amount The amount borrowed out
     **/
    event Borrow(address indexed reserve, address indexed user, uint256 amount);

    /**
     * @dev Emitted on repay()
     * @param reserve The address of the underlying asset of the reserve
     * @param user The beneficiary of the repayment, getting his debt reduced
     * @param repayer The address of the user initiating the repay(), providing the funds
     * @param amount The amount repaid
     **/
    event Repay(
        address indexed reserve,
        address indexed user,
        address indexed repayer,
        uint256 amount
    );

    /**
     * @dev Emitted when the pause is triggered.
     */
    event Paused();

    /**
     * @dev Emitted when the pause is lifted.
     */
    event Unpaused();

    /**
     * @dev Emitted when a borrower is liquidated. This event is emitted by the LendingPool via
     * LendingPoolCollateral manager using a DELEGATECALL
     * This allows to have the events in the generated ABI for LendingPool.
     * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of the liquidation
     * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
     * @param user The address of the borrower getting liquidated
     * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
     * @param liquidatedCollateralAmount The amount of collateral received by the liiquidator
     * @param liquidator The address of the liquidator
     * @param receivecToken `true` if the liquidators wants to receive the collateral cTokens, `false` if he wants
     * to receive the underlying collateral asset directly
     **/
    event LiquidationCall(
        address indexed collateralAsset,
        address indexed debtAsset,
        address indexed user,
        uint256 debtToCover,
        uint256 liquidatedCollateralAmount,
        address liquidator,
        bool receivecToken
    );

    /**
     * @dev Emitted when the state of a reserve is updated. NOTE: This event is actually declared
     * in the ReserveLogic library and emitted in the updateInterestRates() function. Since the function is internal,
     * the event will actually be fired by the LendingPool contract. The event is therefore replicated here so it
     * gets added to the LendingPool ABI
     * @param reserve The address of the underlying asset of the reserve
     * @param liquidityRate The new liquidity rate
     * @param stableBorrowRate The new stable borrow rate
     * @param variableBorrowRate The new variable borrow rate
     * @param liquidityIndex The new liquidity index
     * @param variableBorrowIndex The new variable borrow index
     **/
    event ReserveDataUpdated(
        address indexed reserve,
        uint256 liquidityRate,
        uint256 stableBorrowRate,
        uint256 variableBorrowRate,
        uint256 liquidityIndex,
        uint256 variableBorrowIndex
    );

    /**
     * @dev Mints an `amount` of cTokens to the `onBehalfOf`
     * @param asset The address of the underlying asset to mint
     * @param amount The amount to mint
     * @param user The address that will receive the cTokens
     **/
    function mintUnbacked(
        address asset,
        uint256 amount,
        address user
    ) external;

    /**
     * @dev Back the current unbacked underlying.
     **/
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

    /**
     * @dev Returns the user account data across all the reserves
     * @param user The address of the user
     * @return totalCollateralUSD the total collateral in USD of the user
     * @return totalDebtUSD the total debt in USD of the user
     * @return availableBorrowsUSD the borrowing power left of the user
     * @return currentLiquidationThreshold the liquidation threshold of the user
     * @return ltv the loan to value of the user
     * @return healthFactor the current health factor of the user
     **/
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

    function initReserve(
        IERC20 asset,
        address cTokenAddress,
        address variableDebtAddress,
        address interestRateStrategyAddress
    ) external;

    /**
     * @dev Returns the normalized income normalized income of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The reserve's normalized income
     */
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

    // /**
    //  * @dev Returns the state and configuration of the reserve
    //  * @param asset The address of the underlying asset of the reserve
    //  * @return The state of the reserve
    //  **/
    function getReserveData(address asset)
        external
        view
        returns (DataTypes.ReserveData memory);

    function getReservesList() external view returns (address[] memory);

    /**
     * @dev Returns the normalized variable debt per unit of asset
     * @param asset The address of the underlying asset of the reserve
     * @return The reserve normalized variable debt
     */
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
