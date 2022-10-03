pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ReserveConfiguration} from "./libraries/configuration/ReserveConfiguration.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {PercentageMath} from "./libraries/math/PercentageMath.sol";
import {DataTypes} from "./libraries/types/DataTypes.sol";
import {debtToken} from "./debtToken.sol";
import {cToken} from "./cToken.sol";

/**
 * @title LendingPoolConfigurator contract
 * @author Trava
 * Implements the configuration methods for the Trava protocol
 **/

contract LendingPoolConfigurator {
    using PercentageMath for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    struct InitReserveInput {
        address tTokenImpl;
        address variableDebtTokenImpl;
        uint8 underlyingAssetDecimals;
        address interestRateStrategyAddress;
        address underlyingAsset;
        address treasury;
        string underlyingAssetName;
        string tTokenName;
        string tTokenSymbol;
        string variableDebtTokenName;
        string variableDebtTokenSymbol;
        uint256 baseLTVAsCollateral;
        uint256 liquidationThreshold;
        uint256 liquidationBonus;
        uint256 reserveFactor;
    }

    uint256 internal _providerId;
    address public _poolOwner;

    ILendingPool internal pool;

    modifier onlyPoolOwner() {
        require(_poolOwner == msg.sender, "CALLER_NOT_POOL_ADMIN_OR_OWNER");
        _;
    }

    constructor() {
        _poolOwner = msg.sender;
    }

    function setLendingPool(ILendingPool _pool) external onlyPoolOwner {
        pool = _pool;
    }

    /**
     * Initializes reserves in batch
     * It includes 3 steps: _initReserve, _configureReserveAsCollateral, _setReserveFactor
     * input The InitReserveInput, see the detail in ILendingPoolConfigurator
     **/
    function batchInitReserve(InitReserveInput[] calldata input)
        external
        onlyPoolOwner
    {
        ILendingPool cachedPool = pool;
        for (uint256 i = 0; i < input.length; i++) {
            _initReserve(cachedPool, input[i]);
            _configureReserveAsCollateral(
                input[i].underlyingAsset,
                input[i].baseLTVAsCollateral,
                input[i].liquidationThreshold,
                input[i].liquidationBonus
            );
            _setReserveFactor(input[i].underlyingAsset, input[i].reserveFactor);
        }
    }

    /**
     * Initializes reserve
     **/
    function _initReserve(ILendingPool _pool, InitReserveInput calldata input)
        internal
    {
        address tTokenProxyAddress = _initTokenWithProxy(
            input.tTokenImpl,
            abi.encodeWithSelector(
                cToken.initialize.selector,
                _pool,
                input.treasury,
                input.underlyingAsset,
                input.underlyingAssetDecimals,
                input.tTokenName,
                input.tTokenSymbol
            )
        );
        address variableDebtTokenProxyAddress = _initTokenWithProxy(
            input.variableDebtTokenImpl,
            abi.encodeWithSelector(
                debtToken.initialize.selector,
                _pool,
                input.underlyingAsset,
                input.underlyingAssetDecimals,
                input.variableDebtTokenName,
                input.variableDebtTokenSymbol
            )
        );
        require(
            input.underlyingAsset != address(0),
            "underlyingAsset is address 0"
        );
        require(
            tTokenProxyAddress != address(0),
            "tTokenProxyAddress is address 0"
        );
        require(
            variableDebtTokenProxyAddress != address(0),
            "variableDebtTokenProxyAddress is address 0"
        );
        IERC20 asset = IERC20(input.underlyingAsset);

        _pool.initReserve(
            asset,
            tTokenProxyAddress,
            variableDebtTokenProxyAddress,
            input.interestRateStrategyAddress
        );
        DataTypes.ReserveConfigurationMap memory currentConfig = _pool
            .getConfiguration(input.underlyingAsset);
        currentConfig.setDecimals(input.underlyingAssetDecimals);
        currentConfig.setActive(true);
        _pool.setConfiguration(input.underlyingAsset, currentConfig.data);
    }

    /**
     * Configures the reserve collateralization parameters
     * all the values are expressed in percentages with two decimals of precision. A valid value is 10000, which means 100.00%
     * asset The address of the underlying asset of the reserve
     * ltv The loan to value of the asset when used as collateral
     * liquidationThreshold The threshold at which loans using this asset as collateral will be considered undercollateralized
     * liquidationBonus The bonus liquidators receive to liquidate this asset. The values is always above 100%. A value of 105%
     * means the liquidator will receive a 5% bonus
     **/
    function _configureReserveAsCollateral(
        address asset,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    ) internal {
        DataTypes.ReserveConfigurationMap memory currentConfig = pool
            .getConfiguration(asset);

        //validation of the parameters: the LTV can
        //only be lower or equal than the liquidation threshold
        //(otherwise a loan against the asset would cause instantaneous liquidation)
        require(ltv <= liquidationThreshold, "LPC_INVALID_CONFIGURATION");

        if (liquidationThreshold != 0) {
            //liquidation bonus must be bigger than 100.00%, otherwise the liquidator would receive less
            //collateral than needed to cover the debt
            require(
                liquidationBonus > PercentageMath.PERCENTAGE_FACTOR,
                "LPC_INVALID_CONFIGURATION"
            );

            //if threshold * bonus is less than PERCENTAGE_FACTOR, it's guaranteed that at the moment
            //a loan is taken there is enough collateral available to cover the liquidation bonus
            require(
                liquidationThreshold.percentMul(liquidationBonus) <=
                    PercentageMath.PERCENTAGE_FACTOR,
                "LPC_INVALID_CONFIGURATION"
            );
        } else {
            require(liquidationBonus == 0, "LPC_INVALID_CONFIGURATION");
            //if the liquidation threshold is being set to 0,
            // the reserve is being disabled as collateral. To do so,
            //we need to ensure no liquidity is deposited
            _checkNoLiquidity(asset);
        }

        currentConfig.setLtv(ltv);
        currentConfig.setLiquidationThreshold(liquidationThreshold);
        currentConfig.setLiquidationBonus(liquidationBonus);

        pool.setConfiguration(asset, currentConfig.data);
    }

    function configureReserveAsCollateral(
        address asset,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    ) external onlyPoolOwner {
        _configureReserveAsCollateral(
            asset,
            ltv,
            liquidationThreshold,
            liquidationBonus
        );
    }

    /**
     * Activates a reserve
     * asset The address of the underlying asset of the reserve
     **/
    function activateReserve(address asset) external onlyPoolOwner {
        DataTypes.ReserveConfigurationMap memory currentConfig = pool
            .getConfiguration(asset);

        currentConfig.setActive(true);

        pool.setConfiguration(asset, currentConfig.data);
    }

    /**
     * Deactivates a reserve
     * asset The address of the underlying asset of the reserve
     **/
    function deactivateReserve(address asset) external onlyPoolOwner {
        _checkNoLiquidity(asset);

        DataTypes.ReserveConfigurationMap memory currentConfig = pool
            .getConfiguration(asset);

        currentConfig.setActive(false);

        pool.setConfiguration(asset, currentConfig.data);
    }

    /**
     * Updates the reserve factor of a reserve
     * asset The address of the underlying asset of the reserve
     * reserveFactor The new reserve factor of the reserve
     **/
    function _setReserveFactor(address asset, uint256 reserveFactor) internal {
        DataTypes.ReserveConfigurationMap memory currentConfig = pool
            .getConfiguration(asset);

        currentConfig.setReserveFactor(reserveFactor);

        pool.setConfiguration(asset, currentConfig.data);
    }

    function setReserveFactor(address asset, uint256 reserveFactor)
        external
        onlyPoolOwner
    {
        _setReserveFactor(asset, reserveFactor);
    }

    /**
     * Sets the interest rate strategy of a reserve
     * asset The address of the underlying asset of the reserve
     * rateStrategyAddress The new address of the interest strategy contract
     **/
    function setReserveInterestRateStrategyAddress(
        address asset,
        address rateStrategyAddress
    ) external onlyPoolOwner {
        pool.setReserveInterestRateStrategyAddress(asset, rateStrategyAddress);
    }

    /**
     * pauses or unpauses all the actions of the protocol, including tToken transfers
     * val true if protocol needs to be paused, false otherwise
     **/
    function setPoolPause(bool val) external onlyPoolOwner {
        pool.setPause(val);
    }

    function _initTokenWithProxy(
        address implementation,
        bytes memory initParams
    ) internal returns (address) {
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            implementation,
            address(this),
            initParams
        );
        return address(proxy);
    }

    function _checkNoLiquidity(address asset) internal view {
        DataTypes.ReserveData memory reserveData = pool.getReserveData(asset);

        uint256 availableLiquidity = IERC20(asset).balanceOf(
            reserveData.cTokenAddress
        );

        require(
            availableLiquidity == 0 && reserveData.currentLiquidityRate == 0,
            "LPC_RESERVE_LIQUIDITY_NOT_0"
        );
    }

    function setUnbackedCap(address _asset, uint256 _unbackedCap)
        external
        onlyPoolOwner
    {
        pool.setUnbackedCap(_asset, _unbackedCap);
    }

    function setBridge(address bridgeAddress, bool state)
        external
        onlyPoolOwner
    {
        pool.setBridge(bridgeAddress, state);
    }
}
