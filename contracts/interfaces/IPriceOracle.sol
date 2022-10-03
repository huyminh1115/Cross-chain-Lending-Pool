pragma solidity ^0.8.0;

interface IPriceOracleGetter {
    function setFallbackOracle(address fallbackOracle) external;

    /**
     * assets The addresses of the assets
     **/
    function setAssetSources(
        address[] calldata assets,
        address[] calldata sources
    ) external;

    /**
     * asset the address of the asset
     * the USD price of the asset
     **/
    function getAssetPrice(address asset) external view returns (uint256);

    /**
     * assets the list of assets addresses
     * memory The list USD price of the assets
     **/
    function getAssetsPrices(address[] calldata assets)
        external
        view
        returns (uint256[] memory);

    /**
     * returns the address of the source for an asset address
     * asset The address of the asset
     * address The address of the source
     **/
    function getSourceOfAsset(address asset) external view returns (address);

    /**
     * returns the address of the fallback oracle
     * the address of the fallback oracle
     **/
    function getFallbackOracle() external view returns (address);
}
