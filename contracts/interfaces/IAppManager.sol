// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IDomain } from "./IDomain.sol";

interface IAppManager is IDomain {    


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
    ) external;        
}
