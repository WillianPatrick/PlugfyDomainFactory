// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// A loupe is a small magnifying glass used to look at domains.
// These functions look at domains
interface IAppManagerViewer {
    /// These functions are expected to be called frequently
    /// by tools.

    struct App {
        address appAddress;
        bytes4[] functionSelectors;
    }

    /// @notice Gets all apps addresses and their four byte function selectors.
    /// @return apps_ Apps
    function apps() external view returns (App[] memory apps_);

    /// @notice Gets all the function selectors supported by a specific app.
    /// @param _app The app address.
    /// @return appFunctionSelectors_
    function appFunctionSelectors(address _app) external view returns (bytes4[] memory appFunctionSelectors_);

    /// @notice Get all the app addresses used by domain
    /// @return appAddresses_
    function appAddresses() external view returns (address[] memory appAddresses_);

    /// @notice Gets the app that supports the given selector.
    /// @dev If app is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return appAddress_ The app address.
    function appAddress(bytes4 _functionSelector) external view returns (address appAddress_);
}
