// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDomain {
    enum AppManagerAction {Add, Replace, Remove, Pause}

    struct App {
        address appAddress;
        AppManagerAction action;
        bytes4[] functionSelectors;
    }

    event AppManagerExecuted(App[] _apps, address _init, bytes _calldata);

}