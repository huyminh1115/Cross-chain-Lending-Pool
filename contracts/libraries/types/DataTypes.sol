pragma solidity ^0.8.0;

library DataTypes {
    // refer to the whitepaper, section 1.1 basic concepts for a formal description of these properties.
    struct ReserveData {
        //stores the reserve configuration
        ReserveConfigurationMap configuration;
        //the liquidity index. Expressed in ray
        uint128 liquidityIndex;
        //variable borrow index. Expressed in ray
        uint128 borrowIndex;
        //the current supply rate. Expressed in ray
        uint128 currentLiquidityRate;
        //the current variable borrow rate. Expressed in ray
        uint128 currentBorrowRate;
        //timestamp of last update
        uint40 lastUpdateTimestamp;
        //tokens addresses
        address cTokenAddress;
        //variableDebtToken address
        address debtTokenAddress;
        //address of the interest rate strategy
        address interestRateStrategyAddress;
        //the id of the reserve. Represents the position in the list of the active reserves
        uint8 id;
        // the outstanding unbacked aTokens minted through the bridging feature
        uint256 unbacked;
        // Unbacked mint cap
        uint256 unbackedCap;
    }

    struct ReserveConfigurationMap {
        //bit 0-15: LTV
        //bit 16-31: Liq. threshold
        //bit 32-47: Liq. bonus
        //bit 48-55: Decimals
        //bit 56: Reserve is active
        //bit 57-63: reserved
        //bit 64-79: reserve factor
        uint256 data;
    }

    struct UnBackedInfor {
        uint256 cTokenAmount;
        uint256 oldIndex;
    }

    struct UserConfigurationMap {
        uint256 data;
    }

    struct ExecuteDepositParams {
        address asset;
        uint256 amount;
        address onBehalfOf;
    }

    struct ExecuteBorrowParams {
        address asset;
        address user;
        uint256 amount;
        address oracle;
        uint256 reservesCount;
        bool releaseUnderlying;
    }

    struct ExecuteRepayParams {
        address asset;
        uint256 amount;
        address onBehalfOf;
    }

    struct ExecuteWithdrawParams {
        address asset;
        uint256 amount;
        address to;
        uint256 reservesCount;
        address oracle;
    }

    struct ExecuteLiquidateParams {
        address collateralAsset;
        address debtAsset;
        address user;
        address oracle;
        uint256 debtToCover;
        bool receiveTToken;
        uint256 reservesCount;
    }

    struct ExecuteMintUnbackedParams {
        address asset;
        uint256 amount;
        address user;
    }

    struct ExecuteBackUnbackedParams {
        address asset;
        uint256 amount;
    }
}
