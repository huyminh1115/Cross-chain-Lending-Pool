// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

/**
 * @title IPriceOracleGetter interface
 * @notice Interface for the Trava price oracle.
 **/

interface IPriceOracleGetter {
    /**
     * @dev Sets the fallbackOracle
     * @param fallbackOracle The address of the fallbackOracle
     **/
    function setFallbackOracle(address fallbackOracle) external;

    /**
     * @dev External function called by the governance to set or replace sources of assets
     * @param assets The addresses of the assets
     **/
    function setAssetSources(
        address[] calldata assets,
        address[] calldata sources
    ) external;

    /**
     * @dev returns the asset price in USD
     * @param asset the address of the asset
     * @return the USD price of the asset
     **/
    function getAssetPrice(address asset) external view returns (uint256);

    /**
     * @dev returns the list of prices from a list of assets addresses
     * @param assets the list of assets addresses
     * @return memory The list USD price of the assets
     **/
    function getAssetsPrices(address[] calldata assets)
        external
        view
        returns (uint256[] memory);

    /**
     * @dev returns the address of the source for an asset address
     * @param asset The address of the asset
     * @return address The address of the source
     **/
    function getSourceOfAsset(address asset) external view returns (address);

    /**
     * @dev returns the address of the fallback oracle
     * @return the address of the fallback oracle
     **/
    function getFallbackOracle() external view returns (address);
}
