pragma solidity ^0.8.0;

import {IERC20} from "./interfaces/IERC20.sol";
import {DataTypes} from "./libraries/types/DataTypes.sol";
import {ValidationLogic} from "./libraries/logic/ValidationLogic.sol";
import {cToken} from "./cToken.sol";
import {GenericLogic} from "./libraries/logic/GenericLogic.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {LendingPoolStorage} from "./LendingPoolStorage.sol";
import {PriceOracle} from "./PriceOracle.sol";
import {debtToken} from "./debtToken.sol";
import {ReserveInterestRateStrategy} from "./ReserveInterestRateStrategy.sol";
import {ReserveLogic} from "./libraries/logic/ReserveLogic.sol";
import {DepositLogic} from "./libraries/logic/DepositLogic.sol";
import {BorrowLogic} from "./libraries/logic/BorrowLogic.sol";
import {LiquidationManager} from "./libraries/logic/LiquidationManager.sol";
import {BridgeLogic} from "./libraries/logic/BridgeLogic.sol";
import {UserConfiguration} from "./libraries/configuration/UserConfiguration.sol";
import {ReserveConfiguration} from "./libraries/configuration/ReserveConfiguration.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract LendingPool is ILendingPool, LendingPoolStorage {
    using ReserveLogic for DataTypes.ReserveData;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;

    modifier whenNotPaused() {
        _whenNotPaused();
        _;
    }

    modifier onlyLendingPoolConfigurator() {
        _onlyLendingPoolConfigurator();
        _;
    }

    /**
     * @dev Only bridge can call functions marked by this modifier.
     **/
    modifier onlyBridge() {
        _onlyBridge();
        _;
    }

    function _whenNotPaused() internal view {
        require(!_paused, "LP_IS_PAUSED");
    }

    function _onlyBridge() internal view {
        require(_isBridge[msg.sender] == true, "CALLER_NOT_BRIDGE");
    }

    function _onlyLendingPoolConfigurator() internal view {
        require(
            _lendingPoolConfigurator == msg.sender,
            "LP_CALLER_NOT_LENDING_POOL_CONFIGURATOR"
        );
    }

    constructor(address lendingPoolConfigurator, address priceOracle) {
        _lendingPoolConfigurator = lendingPoolConfigurator;
        _priceOracle = priceOracle;
    }

    function setPriceOracle(address priceOracle)
        external
        onlyLendingPoolConfigurator
    {
        _priceOracle = priceOracle;
    }

    function setBridge(address bridgeAddress, bool state)
        external
        onlyLendingPoolConfigurator
    {
        _isBridge[bridgeAddress] = state;
    }

    function mintUnbacked(
        address asset,
        uint256 amount,
        address user
    ) external virtual override onlyBridge {
        BridgeLogic.executeMintUnbacked(
            _reserves,
            _bridgeUnbacked[msg.sender],
            _totalUnbacked[msg.sender],
            _usersConfig[user],
            _lastDebtNumber[msg.sender],
            DataTypes.ExecuteMintUnbackedParams({
                asset: asset,
                amount: amount,
                user: user
            })
        );
        _lastDebtNumber[msg.sender]++;

        emit MintUnbacked(asset, msg.sender, user, amount);
    }

    function getUnbacked(address bridge, address asset)
        external
        view
        returns (uint256)
    {
        return _totalUnbacked[bridge][asset];
    }

    function backUnbacked(
        address asset,
        uint256 amount,
        uint256[] memory unbackedList
    ) external virtual override onlyBridge {
        BridgeLogic.executeBackUnbacked(
            _reserves,
            _bridgeUnbacked[msg.sender],
            _totalUnbacked[msg.sender],
            _isBacked[msg.sender],
            _lastDebtNumber[msg.sender],
            unbackedList,
            DataTypes.ExecuteBackUnbackedParams({asset: asset, amount: amount})
        );
    }

    function setUnbackedCap(address _asset, uint256 _unbackedCap)
        external
        override
        onlyLendingPoolConfigurator
    {
        _reserves[_asset].unbackedCap = _unbackedCap;
    }

    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf
    ) external override whenNotPaused {
        DepositLogic.executeDeposit(
            _reserves,
            _usersConfig[onBehalfOf],
            DataTypes.ExecuteDepositParams({
                asset: asset,
                amount: amount,
                onBehalfOf: onBehalfOf
            })
        );
        emit Deposit(asset, msg.sender, onBehalfOf, amount);
    }

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external override whenNotPaused returns (uint256) {
        uint256 amountToWithdraw = DepositLogic.executeWithdraw(
            _reserves,
            _reservesList,
            _usersConfig[msg.sender],
            DataTypes.ExecuteWithdrawParams({
                asset: asset,
                amount: amount,
                to: to,
                reservesCount: _reservesCount,
                oracle: _priceOracle
            })
        );
        emit Withdraw(asset, msg.sender, to, amountToWithdraw);
        return amountToWithdraw;
    }

    function borrow(address asset, uint256 amount)
        external
        override
        whenNotPaused
    {
        DataTypes.ReserveData storage reserve = _reserves[asset];

        BorrowLogic.executeBorrow(
            _reserves,
            _reservesList,
            _usersConfig[msg.sender],
            DataTypes.ExecuteBorrowParams({
                asset: asset,
                user: msg.sender,
                amount: amount,
                oracle: _priceOracle,
                reservesCount: _reservesCount,
                releaseUnderlying: true
            })
        );

        emit Borrow(asset, msg.sender, amount);
    }

    function repay(
        address asset,
        uint256 amount,
        address onBehalfOf
    ) external override whenNotPaused returns (uint256) {
        uint256 paybackAmount = BorrowLogic.executeRepay(
            _reserves,
            _reservesList,
            _usersConfig[onBehalfOf],
            DataTypes.ExecuteRepayParams({
                asset: asset,
                amount: amount,
                onBehalfOf: onBehalfOf
            })
        );
        emit Repay(asset, onBehalfOf, msg.sender, paybackAmount);
        return paybackAmount;
    }

    function liquidate(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveTToken
    ) external override whenNotPaused {
        uint256 liquidatedCollateralAmount;
        (debtToCover, liquidatedCollateralAmount) = LiquidationManager
            .executeLiquidation(
                _reserves,
                _reservesList,
                _usersConfig,
                DataTypes.ExecuteLiquidateParams({
                    collateralAsset: collateralAsset,
                    debtAsset: debtAsset,
                    user: user,
                    oracle: _priceOracle,
                    debtToCover: debtToCover,
                    receiveTToken: receiveTToken,
                    reservesCount: _reservesCount
                })
            );

        emit LiquidationCall(
            collateralAsset,
            debtAsset,
            user,
            debtToCover,
            liquidatedCollateralAmount,
            msg.sender,
            receiveTToken
        );
    }

    function initReserve(
        IERC20 asset,
        address cTokenAddress,
        address debtTokenAddress,
        address reserveInterestRateStrategyAddress
    ) external override onlyLendingPoolConfigurator {
        cToken _cToken = cToken(cTokenAddress);
        debtToken _debtToken = debtToken(debtTokenAddress);
        ReserveInterestRateStrategy reserveInterestRateStrategy = ReserveInterestRateStrategy(
                reserveInterestRateStrategyAddress
            );
        _reserves[address(asset)].init(
            _cToken,
            _debtToken,
            reserveInterestRateStrategy
        );
        _addReserveToList(address(asset));
    }

    function getReserveNormalizedIncome(address asset)
        external
        view
        virtual
        override
        returns (uint256)
    {
        return _reserves[asset].getNormalizedIncome();
    }

    function getUserAccountData(address user)
        external
        view
        override
        returns (
            uint256 totalCollateralUSD,
            uint256 totalDebtUSD,
            uint256 availableBorrowsUSD,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        (
            totalCollateralUSD,
            totalDebtUSD,
            ltv,
            currentLiquidationThreshold,
            healthFactor
        ) = GenericLogic.calculateUserAccountData(
            user,
            _reserves,
            _usersConfig[user],
            _reservesList,
            _reservesCount,
            _priceOracle
        );
        availableBorrowsUSD = GenericLogic.calculateAvailableBorrowsUSD(
            totalCollateralUSD,
            totalDebtUSD,
            ltv
        );
    }

    /**
     * @dev Returns the configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The configuration of the reserve
     **/
    function getConfiguration(address asset)
        external
        view
        override
        returns (DataTypes.ReserveConfigurationMap memory)
    {
        return _reserves[asset].configuration;
    }

    /**
     * @dev Sets the configuration bitmap of the reserve as a whole
     * - Only callable by the LendingPoolConfigurator contract
     * @param asset The address of the underlying asset of the reserve
     * @param configuration The new configuration bitmap
     **/
    function setConfiguration(address asset, uint256 configuration)
        external
        onlyLendingPoolConfigurator
    {
        _reserves[asset].configuration.data = configuration;
    }

    /**
     * @dev Returns the configuration of the user across all the reserves
     * @param user The user address
     * @return The configuration of the user
     **/
    function getUserConfiguration(address user)
        external
        view
        override
        returns (DataTypes.UserConfigurationMap memory)
    {
        return _usersConfig[user];
    }

    function finalizeTransfer(
        address asset,
        address from,
        address to,
        uint256 amount,
        uint256 balanceFromBefore,
        uint256 balanceToBefore
    ) external override whenNotPaused {
        require(
            msg.sender == _reserves[asset].cTokenAddress,
            "CALLER_MUST_BE_AN_CTOKEN"
        );

        ValidationLogic.validateTransfer(
            from,
            _reserves,
            _usersConfig[from],
            _reservesList,
            _reservesCount,
            _priceOracle
        );

        uint256 reserveId = _reserves[asset].id;

        if (from != to) {
            if (balanceFromBefore - (amount) == 0) {
                DataTypes.UserConfigurationMap
                    storage fromConfig = _usersConfig[from];
                fromConfig.setUsingAsCollateral(reserveId, false);
            }

            if (balanceToBefore == 0 && amount != 0) {
                DataTypes.UserConfigurationMap storage toConfig = _usersConfig[
                    to
                ];
                toConfig.setUsingAsCollateral(reserveId, true);
            }
        }
    }

    function getPriceOracle() external view returns (address) {
        return _priceOracle;
    }

    function getReserveData(address asset)
        external
        view
        override
        returns (DataTypes.ReserveData memory)
    {
        return _reserves[asset];
    }

    function getReserveNormalizedVariableDebt(address asset)
        external
        view
        override
        returns (uint256)
    {
        return _reserves[asset].getNormalizedDebt();
    }

    function getReservesList()
        external
        view
        override
        returns (address[] memory)
    {
        address[] memory _activeReserves = new address[](_reservesCount);

        for (uint256 i = 0; i < _reservesCount; i++) {
            _activeReserves[i] = _reservesList[i];
        }
        return _activeReserves;
    }

    function setReserveInterestRateStrategyAddress(
        address asset,
        address rateStrategyAddress
    ) external override onlyLendingPoolConfigurator {
        _reserves[asset].interestRateStrategyAddress = rateStrategyAddress;
    }

    function setPause(bool val) external override onlyLendingPoolConfigurator {
        _paused = val;
        if (_paused) {
            emit Paused();
        } else {
            emit Unpaused();
        }
    }

    function paused() external view override returns (bool) {
        return _paused;
    }

    function _addReserveToList(address asset) internal {
        uint256 reservesCount = _reservesCount;

        bool reserveAlreadyAdded = _reserves[asset].id != 0 ||
            _reservesList[0] == asset;

        if (!reserveAlreadyAdded) {
            _reserves[asset].id = uint8(reservesCount);
            _reservesList[reservesCount] = asset;

            _reservesCount = reservesCount + 1;
        }
    }
}
