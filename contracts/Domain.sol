// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibDomain } from "./libraries/LibDomain.sol";
import { IPackagerManager } from "./apps/core/PackagerManager/IPackagerManager.sol";

error FunctionNotFound(bytes4 _functionSelector);

struct DomainArgs {
    address owner;
    address init;
    bytes initCalldata;
    //bytes32 storageKey; // Added this for dynamic storage
}

contract Domain {

    constructor(address _parentDomain, string memory _domainName, IPackagerManager.Packager[] memory _packManager, DomainArgs memory _args) {
        LibDomain.setContractOwner(_args.owner);
        LibDomain.setSuperAdmin(address(msg.sender));
        LibDomain.domainStorage().parentDomain = _parentDomain;
        LibDomain.domainStorage().name = _domainName;
        LibDomain.packManager(_packManager, _args.init, _args.initCalldata);
    }

    // Find pack for function that is called and execute the
    // function if a pack is found and return any value.
    fallback() external payable {
        LibDomain.DomainStorage storage ds;
        bytes32 position = LibDomain.DOMAIN_STORAGE_POSITION;
        // get domain storage
        assembly {
            ds.slot := position
        }

        bytes4 functionSelector = msg.sig;

        require(!ds.paused, "DomainControl: This domain is currently paused and is not in operation");
        if (ds.functionRoles[functionSelector] != bytes32(0)) {
            require(ds.accessControl[functionSelector][msg.sender], "DomainControl: sender does not have access to this function");
        }
        address pack = ds.packAddressAndSelectorPosition[msg.sig].packAddress;
        if(pack == address(0)) {
            revert FunctionNotFound(msg.sig);
        }

        require(!ds.pausedPackagers[pack], "PackagerControl: This packager and functions are currently paused and not in operation");
        // Execute external function from pack using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
             // execute function call using the pack
            let result := delegatecall(gas(), pack, 0, calldatasize(), 0, 0)
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
