// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// A loupe is a small magnifying glass used to look at domains.
// These functions look at domains
interface IFeatureRoutes {
    /// These functions are expected to be called frequently
    /// by tools.

    struct Feature {
        address featureAddress;
        bytes4[] functionSelectors;
    }

    /// @notice Gets all apps addresses and their four byte function selectors.
    /// @return features_ features
    function features() external view returns (Feature[] memory features_);

    /// @notice Gets all the function selectors supported by a specific app.
    /// @param _features The app address.
    /// @return featureFunctionSelectors_
    function featureFunctionSelectors(address _features) external view returns (bytes4[] memory featureFunctionSelectors_);

    /// @notice Get all the app addresses used by domain
    /// @return featureAddresses_
    function featureAddresses() external view returns (address[] memory featureAddresses_);

    /// @notice Gets the app that supports the given selector.
    /// @dev If app is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return featureAddress_ The app address.
    function featureAddress(bytes4 _functionSelector) external view returns (address featureAddress_);
}
