// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibDomain } from "./libraries/LibDomain.sol";
import { IAppManager } from "./interfaces/IAppManager.sol";

error FunctionNotFound(bytes4 _functionSelector);

struct DomainArgs {
    address owner;
    address init;
    bytes initCalldata;
    //bytes32 storageKey; // Added this for dynamic storage    
}

contract Domain{    
    bool public pausedDomain;
    bool public removedDomain;
    uint256 public version;

    error PausedDomain();
    error PausedApp();
    error PausedFunction();

    constructor(IAppManager.App[] memory _appManager, DomainArgs memory _args) payable {
        LibDomain.setContractOwner(_args.owner);
        LibDomain.setAdmin(address(msg.sender));
        LibDomain.appManager(_appManager, _args.init, _args.initCalldata);
        version = 1;
        // Code can be added here to perform actions and set state variables.
    }

    // Find app for function that is called and execute the
    // function if a app is found and return any value.
    fallback() external payable {
        if(pausedDomain){
            revert PausedDomain();
        }

        LibDomain.DomainStorage storage ds;
        bytes32 position = LibDomain.DOMAIN_STORAGE_POSITION;
        // get domain storage
        assembly {
            ds.slot := position
        }

        bytes4 functionSelector = msg.sig;

        if (ds.functionRoles[functionSelector] != bytes32(0)) {
            require(ds.accessControl[functionSelector][msg.sender], "AccessControl: sender does not have access to this function");
        }
        address app = ds.appAddressAndSelectorPosition[msg.sig].appAddress;
        if(app == address(0)) {
            revert FunctionNotFound(msg.sig);
        }

        if(ds.pausedApps[app]) {
            revert PausedApp();
        }        
        // Execute external function from app using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
             // execute function call using the app
            let result := delegatecall(gas(), app, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
                case 0 {
                    revert(0, returndatasize())
                }
                default {
                    return(0, returndatasize())
                }
        }
    }

    receive() external payable {}
}
