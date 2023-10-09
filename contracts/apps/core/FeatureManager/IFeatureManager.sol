// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFeatureManager {
    enum FeatureManagerAction {Add, Replace, Remove, Pause, Ignored}

    struct Feature {
        address featureAddress;
        FeatureManagerAction action;
        bytes4[] functionSelectors;
    }

    event FeatureManagerExecuted(Feature[] _features, address _init, bytes _calldata);

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _features Contains the app addresses and function selectors
    /// @param _init The address of the contract or app to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function FeatureManager(
        Feature[] calldata _features,
        address _init,
        bytes calldata _calldata
    ) external;        
}
