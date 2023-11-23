pragma solidity ^0.8.17;\n\n// SPDX-License-Identifier: MIT


import { IFeatureManager } from "./IFeatureManager.sol";
import { LibDomain } from "../../../libraries/LibDomain.sol";

// Remember to add the loupe functions from AppManagerViewerApp to the domain.
// The loupe functions are required by the EIP2535 Domains standard

contract FeatureManagerApp is IFeatureManager {


    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _features Contains the app addresses and function selectors
    /// @param _initAddress The address of the contract or app to execute _calldata
    /// @param _functionSelector the selector on features registred or init address informed pointer to execute on initialize feature
    /// @param _calldata A function call, including function selector and arguments _calldata is executed with delegatecall on _init
    /// @param _force Force initialize
    function FeatureManager(
        Feature[] calldata _features,
        address _initAddress,
        bytes4 _functionSelector,
        bytes calldata _calldata,
        bool _force
    ) external override {
        LibDomain.enforceIsContractOwnerAdmin();
        LibDomain.featureManager(_features, _initAddress, _functionSelector, _calldata, _force);
    }    
}