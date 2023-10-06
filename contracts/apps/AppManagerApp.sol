// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IAppManager } from "../interfaces/IAppManager.sol";
import { LibDomain } from "../libraries/LibDomain.sol";

// Remember to add the loupe functions from AppManagerViewerApp to the domain.
// The loupe functions are required by the EIP2535 Domains standard

contract AppManagerApp is IAppManager {


    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _apps Contains the app addresses and function selectors
    /// @param _init The address of the contract or app to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function appManager(
        App[] calldata _apps,
        address _init,
        bytes calldata _calldata
    ) external override {
        LibDomain.enforceIsContractOwner();
        LibDomain.appManager(_apps, _init, _calldata);
    }    
}
