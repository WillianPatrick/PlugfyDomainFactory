// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPackagerManager {
    enum PackagerManagerAction {Add, Replace, Remove, Pause}

    struct Packager {
        address packAddress;
        PackagerManagerAction action;
        bytes4[] functionSelectors;
    }

    event PackagerManagerExecuted(Packager[] _packs, address _init, bytes _calldata);

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _packs Contains the app addresses and function selectors
    /// @param _init The address of the contract or app to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function packagerManager(
        Packager[] calldata _packs,
        address _init,
        bytes calldata _calldata
    ) external;        
}
