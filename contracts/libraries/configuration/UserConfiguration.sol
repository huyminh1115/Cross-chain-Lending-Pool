// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {DataTypes} from "../types/DataTypes.sol";

library UserConfiguration {
    uint256 internal constant BORROWING_MASK =
        0x5555555555555555555555555555555555555555555555555555555555555555;

    /**
     * Sets if the user is borrowing the reserve identified by reserveIndex
     * self The configuration object
     * reserveIndex The index of the reserve in the bitmap
     * borrowing True if the user is borrowing the reserve, false otherwise
     **/
    function setBorrowing(
        DataTypes.UserConfigurationMap storage self,
        uint256 reserveIndex,
        bool borrowing
    ) internal {
        require(reserveIndex < 128, "UL_INVALID_INDEX");
        self.data =
            (self.data & ~(1 << (reserveIndex * 2))) |
            (uint256(borrowing ? 1 : 0) << (reserveIndex * 2));
    }

    /**
     * Sets if the user is using as collateral the reserve identified by reserveIndex
     * self The configuration object
     * reserveIndex The index of the reserve in the bitmap
     * usingAsCollateral True if the user is usin the reserve as collateral, false otherwise
     **/
    function setUsingAsCollateral(
        DataTypes.UserConfigurationMap storage self,
        uint256 reserveIndex,
        bool usingAsCollateral
    ) internal {
        require(reserveIndex < 128, "UL_INVALID_INDEX");
        self.data =
            (self.data & ~(1 << (reserveIndex * 2 + 1))) |
            (uint256(usingAsCollateral ? 1 : 0) << (reserveIndex * 2 + 1));
    }

    /**
     * Used to validate if a user has been using the reserve for borrowing or as collateral
     * self The configuration object
     * reserveIndex The index of the reserve in the bitmap
     * Return True if the user has been using a reserve for borrowing or as collateral, false otherwise
     **/
    function isUsingAsCollateralOrBorrowing(
        DataTypes.UserConfigurationMap memory self,
        uint256 reserveIndex
    ) internal pure returns (bool) {
        require(reserveIndex < 128, "UL_INVALID_INDEX");
        return (self.data >> (reserveIndex * 2)) & 3 != 0;
    }

    /**
     * Used to validate if a user has been using the reserve for borrowing
     * self The configuration object
     * reserveIndex The index of the reserve in the bitmap
     * Return True if the user has been using a reserve for borrowing, false otherwise
     **/
    function isBorrowing(
        DataTypes.UserConfigurationMap memory self,
        uint256 reserveIndex
    ) internal pure returns (bool) {
        require(reserveIndex < 128, "UL_INVALID_INDEX");
        return (self.data >> (reserveIndex * 2)) & 1 != 0;
    }

    /**
     * Used to validate if a user has been using the reserve as collateral
     * self The configuration object
     * reserveIndex The index of the reserve in the bitmap
     * Return True if the user has been using a reserve as collateral, false otherwise
     **/
    function isUsingAsCollateral(
        DataTypes.UserConfigurationMap memory self,
        uint256 reserveIndex
    ) internal pure returns (bool) {
        require(reserveIndex < 128, "UL_INVALID_INDEX");
        return (self.data >> (reserveIndex * 2 + 1)) & 1 != 0;
    }

    /**
     * Used to validate if a user has been borrowing from any reserve
     * self The configuration object
     * Return True if the user has been borrowing any reserve, false otherwise
     **/
    function isBorrowingAny(DataTypes.UserConfigurationMap memory self)
        internal
        pure
        returns (bool)
    {
        return self.data & BORROWING_MASK != 0;
    }

    /**
     * Used to validate if a user has not been using any reserve
     * self The configuration object
     * Return True if the user has been borrowing any reserve, false otherwise
     **/
    function isEmpty(DataTypes.UserConfigurationMap memory self)
        internal
        pure
        returns (bool)
    {
        return self.data == 0;
    }
}
