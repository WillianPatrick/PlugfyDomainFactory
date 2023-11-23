pragma solidity ^0.8.17;\n\n// SPDX-License-Identifier: MIT


// The functions in FeatureManagerViewerFeature MUST be added to a domain.
// The EIP-2535 Domain standard requires these functions.

import { LibDomain } from  "../../../libraries/LibDomain.sol";
import { IFeatureRoutes } from "./IFeatureRoutes.sol";

contract FeatureRoutesApp is IFeatureRoutes {
    

    // Domain Loupe Functions
    ////////////////////////////////////////////////////////////////////
    /// These functions are expected to be called frequently by tools.
    //
    // struct Feature {
    //     address featureAddress;
    //     bytes4[] functionSelectors;
    // }
    /// @notice Gets all features and their selectors.
    /// @return features_ Feature
    function features() external override view returns (Feature[] memory features_) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        uint256 selectorCount = ds.selectors.length;
        // create an array set to the maximum size possible
        features_ = new Feature[](selectorCount);
        // create an array for counting the number of selectors for each feature
        uint16[] memory numFeatureSelectors = new uint16[](selectorCount);
        // total number of features
        uint256 numFeatures;
        // loop through function selectors
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = ds.selectors[selectorIndex];
            address featureAddress_ = ds.featureAddressAndSelectorPosition[selector].featureAddress;
            bool continueLoop = false;
            // find the functionSelectors array for selector and add selector to it
            for (uint256 featureIndex; featureIndex < numFeatures; featureIndex++) {
                if (features_[featureIndex].featureAddress == featureAddress_) {
                    features_[featureIndex].functionSelectors[numFeatureSelectors[featureIndex]] = selector;                                   
                    numFeatureSelectors[featureIndex]++;
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
            features_[numFeatures].featureAddress = featureAddress_;
            features_[numFeatures].functionSelectors = new bytes4[](selectorCount);
            features_[numFeatures].functionSelectors[0] = selector;
            numFeatureSelectors[numFeatures] = 1;
            numFeatures++;
        }
        for (uint256 featureIndex; featureIndex < numFeatures; featureIndex++) {
            uint256 numSelectors = numFeatureSelectors[featureIndex];
            bytes4[] memory selectors = features_[featureIndex].functionSelectors;
            // setting the number of selectors
            assembly {
                mstore(selectors, numSelectors)
            }
        }
        // setting the number of features
        assembly {
            mstore(features_, numFeatures)
        }
    }

    /// @notice Gets all the function selectors supported by a specific feature.
    /// @param _feature The feature address.
    /// @return _featureFunctionSelectors The selectors associated with a feature address.
    function featureFunctionSelectors(address _feature) external override view returns (bytes4[] memory _featureFunctionSelectors) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        uint256 selectorCount = ds.selectors.length;
        uint256 numSelectors;
        _featureFunctionSelectors = new bytes4[](selectorCount);
        // loop through function selectors
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = ds.selectors[selectorIndex];
            address featureAddress_ = ds.featureAddressAndSelectorPosition[selector].featureAddress;
            if (_feature == featureAddress_) {
                _featureFunctionSelectors[numSelectors] = selector;
                numSelectors++;
            }
        }
        // Set the number of selectors in the array
        assembly {
            mstore(_featureFunctionSelectors, numSelectors)
        }
    }

    /// @notice Get all the feature addresses used by a domain.
    /// @return featureAddresses_
    function featureAddresses() external override view returns (address[] memory featureAddresses_) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        uint256 selectorCount = ds.selectors.length;
        // create an array set to the maximum size possible
        featureAddresses_ = new address[](selectorCount);
        uint256 numFeatures;
        // loop through function selectors
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = ds.selectors[selectorIndex];
            address featureAddress_ = ds.featureAddressAndSelectorPosition[selector].featureAddress;
            bool continueLoop = false;
            // see if we have collected the address already and break out of loop if we have
            for (uint256 featureIndex; featureIndex < numFeatures; featureIndex++) {
                if (featureAddress_ == featureAddresses_[featureIndex]) {
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
            featureAddresses_[numFeatures] = featureAddress_;
            numFeatures++;
        }
        // Set the number of feature addresses in the array
        assembly {
            mstore(featureAddresses_, numFeatures)
        }
    }

    /// @notice Gets the feature address that supports the given selector.
    /// @dev If feature is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return featureAddress_ The feature address.
    function featureAddress(bytes4 _functionSelector) external override view returns (address featureAddress_) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        featureAddress_ = ds.featureAddressAndSelectorPosition[_functionSelector].featureAddress;
    }
}