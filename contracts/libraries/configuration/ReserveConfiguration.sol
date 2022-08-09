// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {DataTypes} from "../types/DataTypes.sol";

/**
 * @title ReserveConfiguration library
 * @notice Implements the bitmap logic to handle the reserve configuration
 */
library ReserveConfiguration {
    uint256 constant LTV_MASK =                   0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000; // prettier-ignore
    uint256 constant LIQUIDATION_THRESHOLD_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFF; // prettier-ignore
    uint256 constant LIQUIDATION_BONUS_MASK =     0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFF; // prettier-ignore
    uint256 constant DECIMALS_MASK =              0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFF; // prettier-ignore
    uint256 constant ACTIVE_MASK =                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant RESERVE_FACTOR_MASK =        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFF; // prettier-ignore

    /// @dev For the LTV, the start bit is 0 (up to 15), hence no bitshifting is needed
    uint256 constant LIQUIDATION_THRESHOLD_START_BIT_POSITION = 16;
    uint256 constant LIQUIDATION_BONUS_START_BIT_POSITION = 32;
    uint256 constant RESERVE_DECIMALS_START_BIT_POSITION = 48;
    uint256 constant IS_ACTIVE_START_BIT_POSITION = 56;
    uint256 constant RESERVE_FACTOR_START_BIT_POSITION = 64;

    uint256 constant MAX_VALID_LTV = 65535;
    uint256 constant MAX_VALID_LIQUIDATION_THRESHOLD = 65535;
    uint256 constant MAX_VALID_LIQUIDATION_BONUS = 65535;
    uint256 constant MAX_VALID_DECIMALS = 255;
    uint256 constant MAX_VALID_RESERVE_FACTOR = 65535;

    /**
     * @dev Sets the Loan to Value of the reserve
     * @param self The reserve configuration
     * @param ltv the new ltv
     **/
    function setLtv(DataTypes.ReserveConfigurationMap memory self, uint256 ltv)
        internal
        pure
    {
        require(ltv <= MAX_VALID_LTV, "RC_INVALID_LTV");

        self.data = (self.data & LTV_MASK) | ltv;
    }

    /**
     * @dev Gets the Loan to Value of the reserve
     * @param self The reserve configuration
     * @return The loan to value
     **/
    function getLtv(DataTypes.ReserveConfigurationMap storage self)
        internal
        view
        returns (uint256)
    {
        return self.data & ~LTV_MASK;
    }

    /**
     * @dev Sets the liquidation threshold of the reserve
     * @param self The reserve configuration
     * @param threshold The new liquidation threshold
     **/
    function setLiquidationThreshold(
        DataTypes.ReserveConfigurationMap memory self,
        uint256 threshold
    ) internal pure {
        require(
            threshold <= MAX_VALID_LIQUIDATION_THRESHOLD,
            "RC_INVALID_LIQ_THRESHOLD"
        );

        self.data =
            (self.data & LIQUIDATION_THRESHOLD_MASK) |
            (threshold << LIQUIDATION_THRESHOLD_START_BIT_POSITION);
    }

    /**
     * @dev Gets the liquidation threshold of the reserve
     * @param self The reserve configuration
     * @return The liquidation threshold
     **/
    function getLiquidationThreshold(
        DataTypes.ReserveConfigurationMap storage self
    ) internal view returns (uint256) {
        return
            (self.data & ~LIQUIDATION_THRESHOLD_MASK) >>
            LIQUIDATION_THRESHOLD_START_BIT_POSITION;
    }

    /**
     * @dev Sets the liquidation bonus of the reserve
     * @param self The reserve configuration
     * @param bonus The new liquidation bonus
     **/
    function setLiquidationBonus(
        DataTypes.ReserveConfigurationMap memory self,
        uint256 bonus
    ) internal pure {
        require(bonus <= MAX_VALID_LIQUIDATION_BONUS, "RC_INVALID_LIQ_BONUS");

        self.data =
            (self.data & LIQUIDATION_BONUS_MASK) |
            (bonus << LIQUIDATION_BONUS_START_BIT_POSITION);
    }

    /**
     * @dev Gets the liquidation bonus of the reserve
     * @param self The reserve configuration
     * @return The liquidation bonus
     **/
    function getLiquidationBonus(DataTypes.ReserveConfigurationMap storage self)
        internal
        view
        returns (uint256)
    {
        return
            (self.data & ~LIQUIDATION_BONUS_MASK) >>
            LIQUIDATION_BONUS_START_BIT_POSITION;
    }

    /**
     * @dev Sets the decimals of the underlying asset of the reserve
     * @param self The reserve configuration
     * @param decimals The decimals
     **/
    function setDecimals(
        DataTypes.ReserveConfigurationMap memory self,
        uint256 decimals
    ) internal pure {
        require(decimals <= MAX_VALID_DECIMALS, "RC_INVALID_DECIMALS");

        self.data =
            (self.data & DECIMALS_MASK) |
            (decimals << RESERVE_DECIMALS_START_BIT_POSITION);
    }

    /**
     * @dev Gets the decimals of the underlying asset of the reserve
     * @param self The reserve configuration
     * @return The decimals of the asset
     **/
    function getDecimals(DataTypes.ReserveConfigurationMap storage self)
        internal
        view
        returns (uint256)
    {
        return
            (self.data & ~DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION;
    }

    /**
     * @dev Sets the active state of the reserve
     * @param self The reserve configuration
     * @param active The active state
     **/
    function setActive(
        DataTypes.ReserveConfigurationMap memory self,
        bool active
    ) internal pure {
        self.data =
            (self.data & ACTIVE_MASK) |
            (uint256(active ? 1 : 0) << IS_ACTIVE_START_BIT_POSITION);
    }

    /**
     * @dev Gets the active state of the reserve
     * @param self The reserve configuration
     * @return The active state
     **/
    function getActive(DataTypes.ReserveConfigurationMap storage self)
        internal
        view
        returns (bool)
    {
        return (self.data & ~ACTIVE_MASK) != 0;
    }

    /**
     * @dev Sets the reserve factor of the reserve
     * @param self The reserve configuration
     * @param reserveFactor The reserve factor
     **/
    function setReserveFactor(
        DataTypes.ReserveConfigurationMap memory self,
        uint256 reserveFactor
    ) internal pure {
        require(
            reserveFactor <= MAX_VALID_RESERVE_FACTOR,
            "RC_INVALID_RESERVE_FACTOR"
        );

        self.data =
            (self.data & RESERVE_FACTOR_MASK) |
            (reserveFactor << RESERVE_FACTOR_START_BIT_POSITION);
    }

    /**
     * @dev Gets the reserve factor of the reserve
     * @param self The reserve configuration
     * @return The reserve factor
     **/
    function getReserveFactor(DataTypes.ReserveConfigurationMap storage self)
        internal
        view
        returns (uint256)
    {
        return
            (self.data & ~RESERVE_FACTOR_MASK) >>
            RESERVE_FACTOR_START_BIT_POSITION;
    }

    /**
     * @dev Gets the configuration paramters of the reserve
     * @param self The reserve configuration
     * @return The state params representing ltv, liquidation threshold, liquidation bonus, the reserve decimals
     **/
    function getParams(DataTypes.ReserveConfigurationMap storage self)
        internal
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 dataLocal = self.data;

        return (
            dataLocal & ~LTV_MASK,
            (dataLocal & ~LIQUIDATION_THRESHOLD_MASK) >>
                LIQUIDATION_THRESHOLD_START_BIT_POSITION,
            (dataLocal & ~LIQUIDATION_BONUS_MASK) >>
                LIQUIDATION_BONUS_START_BIT_POSITION,
            (dataLocal & ~DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION,
            (dataLocal & ~RESERVE_FACTOR_MASK) >>
                RESERVE_FACTOR_START_BIT_POSITION
        );
    }
}
