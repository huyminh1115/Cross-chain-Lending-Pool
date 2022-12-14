// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IChainlinkAggregator} from "./interfaces/IChainlinkAggregator.sol";

/// @title PriceOracle
/// @notice Proxy smart contract to get the price of an asset from a price source, with Chainlink Aggregator
///         smart contracts as primary option
/// - If the returned price by a Chainlink aggregator is <= 0, the call is forwarded to a fallbackOracle
/// - Owned by the governance system, allowed to add sources for assets, replace them
///   and change the fallbackOracle
contract PriceOracle is Ownable {
    event AssetSourceUpdated(address indexed asset, address indexed source);
    event FallbackOracleUpdated(address indexed fallbackOracle);

    mapping(address => IChainlinkAggregator) private assetsSources;
    PriceOracle private _fallbackOracle;

    /// @notice Constructor
    /// @param assets The addresses of the assets
    /// @param sources The address of the source of each asset
    /// @param fallbackOracle The address of the fallback oracle to use if the data of an
    ///        aggregator is not consistent
    constructor(
        address[] memory assets,
        address[] memory sources,
        address fallbackOracle
    ) {
        _setFallbackOracle(fallbackOracle);
        _setAssetsSources(assets, sources);
    }

    /// @notice External function called by the governance to set or replace sources of assets
    /// @param assets The addresses of the assets
    /// @param sources The address of the source of each asset
    function setAssetSources(
        address[] calldata assets,
        address[] calldata sources
    ) external onlyOwner {
        _setAssetsSources(assets, sources);
    }

    /// @notice Sets the fallbackOracle
    /// - Callable only by the governance
    /// @param fallbackOracle The address of the fallbackOracle
    function setFallbackOracle(address fallbackOracle) external onlyOwner {
        _setFallbackOracle(fallbackOracle);
    }

    /// @notice Internal function to set the sources for each asset
    /// @param assets The addresses of the assets
    /// @param sources The address of the source of each asset
    function _setAssetsSources(
        address[] memory assets,
        address[] memory sources
    ) internal {
        require(assets.length == sources.length, "INCONSISTENT_PARAMS_LENGTH");
        for (uint256 i = 0; i < assets.length; i++) {
            assetsSources[assets[i]] = IChainlinkAggregator(sources[i]);
            emit AssetSourceUpdated(assets[i], sources[i]);
        }
    }

    /// @notice Internal function to set the fallbackOracle
    /// @param fallbackOracle The address of the fallbackOracle
    function _setFallbackOracle(address fallbackOracle) internal {
        _fallbackOracle = PriceOracle(fallbackOracle);
        emit FallbackOracleUpdated(fallbackOracle);
    }

    /// @notice Gets an asset price by address
    /// @param asset The asset address
    function getAssetPrice(address asset) public view returns (uint256) {
        IChainlinkAggregator source = assetsSources[asset];

        if (address(source) == address(0)) {
            return _fallbackOracle.getAssetPrice(asset);
        } else {
            int256 price = IChainlinkAggregator(source).latestAnswer();
            if (price > 0) {
                return uint256(price);
            } else {
                return _fallbackOracle.getAssetPrice(asset);
            }
        }
    }

    /// @notice Gets a list of prices from a list of assets addresses
    /// @param assets The list of assets addresses
    function getAssetsPrices(address[] calldata assets)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory prices = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            prices[i] = getAssetPrice(assets[i]);
        }
        return prices;
    }

    /// @notice Gets the address of the source for an asset address
    /// @param asset The address of the asset
    /// @return address The address of the source
    function getSourceOfAsset(address asset) external view returns (address) {
        return address(assetsSources[asset]);
    }

    /// @notice Gets the address of the fallback oracle
    /// @return address The addres of the fallback oracle
    function getFallbackOracle() external view returns (address) {
        return address(_fallbackOracle);
    }
}
