// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// The functions in AppManagerViewerApp MUST be added to a domain.
// The EIP-2535 Domain standard requires these functions.

import { LibDomain } from  "../libraries/LibDomain.sol";
import { IAppManagerViewer } from "../interfaces/IAppManagerViewer.sol";

contract AppManagerViewerApp is IAppManagerViewer {
    

    // Domain Loupe Functions
    ////////////////////////////////////////////////////////////////////
    /// These functions are expected to be called frequently by tools.
    //
    // struct App {
    //     address appAddress;
    //     bytes4[] functionSelectors;
    // }
    /// @notice Gets all apps and their selectors.
    /// @return apps_ App
    function apps() external override view returns (App[] memory apps_) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        uint256 selectorCount = ds.selectors.length;
        // create an array set to the maximum size possible
        apps_ = new App[](selectorCount);
        // create an array for counting the number of selectors for each app
        uint16[] memory numAppSelectors = new uint16[](selectorCount);
        // total number of apps
        uint256 numApps;
        // loop through function selectors
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = ds.selectors[selectorIndex];
            address appAddress_ = ds.appAddressAndSelectorPosition[selector].appAddress;
            bool continueLoop = false;
            // find the functionSelectors array for selector and add selector to it
            for (uint256 appIndex; appIndex < numApps; appIndex++) {
                if (apps_[appIndex].appAddress == appAddress_) {
                    apps_[appIndex].functionSelectors[numAppSelectors[appIndex]] = selector;                                   
                    numAppSelectors[appIndex]++;
                    continueLoop = true;
                    break;
                }
            }
            // if functionSelectors array exists for selector then continue loop
            if (continueLoop) {
                continueLoop = false;
                continue;
            }
            // create a new functionSelectors array for selector
            apps_[numApps].appAddress = appAddress_;
            apps_[numApps].functionSelectors = new bytes4[](selectorCount);
            apps_[numApps].functionSelectors[0] = selector;
            numAppSelectors[numApps] = 1;
            numApps++;
        }
        for (uint256 appIndex; appIndex < numApps; appIndex++) {
            uint256 numSelectors = numAppSelectors[appIndex];
            bytes4[] memory selectors = apps_[appIndex].functionSelectors;
            // setting the number of selectors
            assembly {
                mstore(selectors, numSelectors)
            }
        }
        // setting the number of apps
        assembly {
            mstore(apps_, numApps)
        }
    }

    /// @notice Gets all the function selectors supported by a specific app.
    /// @param _app The app address.
    /// @return _appFunctionSelectors The selectors associated with a app address.
    function appFunctionSelectors(address _app) external override view returns (bytes4[] memory _appFunctionSelectors) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        uint256 selectorCount = ds.selectors.length;
        uint256 numSelectors;
        _appFunctionSelectors = new bytes4[](selectorCount);
        // loop through function selectors
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = ds.selectors[selectorIndex];
            address appAddress_ = ds.appAddressAndSelectorPosition[selector].appAddress;
            if (_app == appAddress_) {
                _appFunctionSelectors[numSelectors] = selector;
                numSelectors++;
            }
        }
        // Set the number of selectors in the array
        assembly {
            mstore(_appFunctionSelectors, numSelectors)
        }
    }

    /// @notice Get all the app addresses used by a domain.
    /// @return appAddresses_
    function appAddresses() external override view returns (address[] memory appAddresses_) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        uint256 selectorCount = ds.selectors.length;
        // create an array set to the maximum size possible
        appAddresses_ = new address[](selectorCount);
        uint256 numApps;
        // loop through function selectors
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = ds.selectors[selectorIndex];
            address appAddress_ = ds.appAddressAndSelectorPosition[selector].appAddress;
            bool continueLoop = false;
            // see if we have collected the address already and break out of loop if we have
            for (uint256 appIndex; appIndex < numApps; appIndex++) {
                if (appAddress_ == appAddresses_[appIndex]) {
                    continueLoop = true;
                    break;
                }
            }
            // continue loop if we already have the address
            if (continueLoop) {
                continueLoop = false;
                continue;
            }
            // include address
            appAddresses_[numApps] = appAddress_;
            numApps++;
        }
        // Set the number of app addresses in the array
        assembly {
            mstore(appAddresses_, numApps)
        }
    }

    /// @notice Gets the app address that supports the given selector.
    /// @dev If app is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return appAddress_ The app address.
    function appAddress(bytes4 _functionSelector) external override view returns (address appAddress_) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        appAddress_ = ds.appAddressAndSelectorPosition[_functionSelector].appAddress;
    }
}
