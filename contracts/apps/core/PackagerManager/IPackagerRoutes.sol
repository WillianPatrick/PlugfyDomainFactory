// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// A loupe is a small magnifying glass used to look at domains.
// These functions look at domains
interface IPackagerRoutes {
    /// These functions are expected to be called frequently
    /// by tools.

    struct Packager {
        address packAddress;
        bytes4[] functionSelectors;
    }

    /// @notice Gets all apps addresses and their four byte function selectors.
    /// @return packs_ packagers
    function packagers() external view returns (Packager[] memory packs_);

    /// @notice Gets all the function selectors supported by a specific app.
    /// @param _packs The app address.
    /// @return packFunctionSelectors_
    function packFunctionSelectors(address _packs) external view returns (bytes4[] memory packFunctionSelectors_);

    /// @notice Get all the app addresses used by domain
    /// @return packAddresses_
    function packAddresses() external view returns (address[] memory packAddresses_);

    /// @notice Gets the app that supports the given selector.
    /// @dev If app is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return packAddress_ The app address.
    function packAddress(bytes4 _functionSelector) external view returns (address packAddress_);
}
