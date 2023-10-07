// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// The functions in PackagerManagerViewerPackager MUST be added to a domain.
// The EIP-2535 Domain standard requires these functions.

import { LibDomain } from  "../../../libraries/LibDomain.sol";
import { IPackagerRoutes } from "./IPackagerRoutes.sol";

contract PackagerRoutesApp is IPackagerRoutes {
    

    // Domain Loupe Functions
    ////////////////////////////////////////////////////////////////////
    /// These functions are expected to be called frequently by tools.
    //
    // struct Packager {
    //     address packAddress;
    //     bytes4[] functionSelectors;
    // }
    /// @notice Gets all packs and their selectors.
    /// @return packs_ Packager
    function packagers() external override view returns (Packager[] memory packs_) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        uint256 selectorCount = ds.selectors.length;
        // create an array set to the maximum size possible
        packs_ = new Packager[](selectorCount);
        // create an array for counting the number of selectors for each pack
        uint16[] memory numPackagerSelectors = new uint16[](selectorCount);
        // total number of packs
        uint256 numPackagers;
        // loop through function selectors
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = ds.selectors[selectorIndex];
            address packAddress_ = ds.packAddressAndSelectorPosition[selector].packAddress;
            bool continueLoop = false;
            // find the functionSelectors array for selector and add selector to it
            for (uint256 packIndex; packIndex < numPackagers; packIndex++) {
                if (packs_[packIndex].packAddress == packAddress_) {
                    packs_[packIndex].functionSelectors[numPackagerSelectors[packIndex]] = selector;                                   
                    numPackagerSelectors[packIndex]++;
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
            packs_[numPackagers].packAddress = packAddress_;
            packs_[numPackagers].functionSelectors = new bytes4[](selectorCount);
            packs_[numPackagers].functionSelectors[0] = selector;
            numPackagerSelectors[numPackagers] = 1;
            numPackagers++;
        }
        for (uint256 packIndex; packIndex < numPackagers; packIndex++) {
            uint256 numSelectors = numPackagerSelectors[packIndex];
            bytes4[] memory selectors = packs_[packIndex].functionSelectors;
            // setting the number of selectors
            assembly {
                mstore(selectors, numSelectors)
            }
        }
        // setting the number of packs
        assembly {
            mstore(packs_, numPackagers)
        }
    }

    /// @notice Gets all the function selectors supported by a specific pack.
    /// @param _pack The pack address.
    /// @return _packFunctionSelectors The selectors associated with a pack address.
    function packFunctionSelectors(address _pack) external override view returns (bytes4[] memory _packFunctionSelectors) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        uint256 selectorCount = ds.selectors.length;
        uint256 numSelectors;
        _packFunctionSelectors = new bytes4[](selectorCount);
        // loop through function selectors
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = ds.selectors[selectorIndex];
            address packAddress_ = ds.packAddressAndSelectorPosition[selector].packAddress;
            if (_pack == packAddress_) {
                _packFunctionSelectors[numSelectors] = selector;
                numSelectors++;
            }
        }
        // Set the number of selectors in the array
        assembly {
            mstore(_packFunctionSelectors, numSelectors)
        }
    }

    /// @notice Get all the pack addresses used by a domain.
    /// @return packAddresses_
    function packAddresses() external override view returns (address[] memory packAddresses_) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        uint256 selectorCount = ds.selectors.length;
        // create an array set to the maximum size possible
        packAddresses_ = new address[](selectorCount);
        uint256 numPackagers;
        // loop through function selectors
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = ds.selectors[selectorIndex];
            address packAddress_ = ds.packAddressAndSelectorPosition[selector].packAddress;
            bool continueLoop = false;
            // see if we have collected the address already and break out of loop if we have
            for (uint256 packIndex; packIndex < numPackagers; packIndex++) {
                if (packAddress_ == packAddresses_[packIndex]) {
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
            packAddresses_[numPackagers] = packAddress_;
            numPackagers++;
        }
        // Set the number of pack addresses in the array
        assembly {
            mstore(packAddresses_, numPackagers)
        }
    }

    /// @notice Gets the pack address that supports the given selector.
    /// @dev If pack is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return packAddress_ The pack address.
    function packAddress(bytes4 _functionSelector) external override view returns (address packAddress_) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        packAddress_ = ds.packAddressAndSelectorPosition[_functionSelector].packAddress;
    }
}
