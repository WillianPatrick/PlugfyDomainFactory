// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibDomain } from "./libraries/LibDomain.sol";
import { IFeatureManager } from "./apps/core/FeatureManager/IFeatureManager.sol";

struct DomainArgs {
    address owner;
    address initAddress;
    bytes4 functionSelector;
    bytes initCalldata;
    bool forceInitialize;
}

contract Domain {

    constructor(address _parentDomain, string memory _domainName, IFeatureManager.Feature[] memory _featureManager, DomainArgs memory _args) {
        LibDomain.domainStorage().notEntered = true;
        LibDomain.setContractOwner(_args.owner);
        LibDomain.setSuperAdmin(address(msg.sender));
        LibDomain.domainStorage().parentDomain = _parentDomain;
        LibDomain.domainStorage().name = _domainName;
        LibDomain.featureManager(_featureManager, _args.initAddress, _args.functionSelector, _args.initCalldata, _args.forceInitialize);
    }

    function checkNonReentrant(bytes4 functionSelector) internal {
        require(LibDomain.domainStorage().notEntered, "ReentrancyGuard: reentrant call");
        if(LibDomain.domainStorage().selectorsReentrancyGuard[functionSelector]) {
            LibDomain.domainStorage().notEntered = false;
        }
    }

    fallback() external payable {
        checkNonReentrant(msg.sig);
        LibDomain.domainStorage().notEntered = true;
        delegateToFeature(msg.sig);
    }

    receive() external payable {
        checkNonReentrant(bytes4(keccak256(bytes("receive()"))));
        bytes4 receiveSelector = bytes4(keccak256(bytes("receive()")));
        LibDomain.domainStorage().notEntered = true;
        delegateToFeature(receiveSelector);
    }

    function delegateToFeature(bytes4 functionSelector) internal {
        LibDomain.DomainStorage storage ds;
        bytes32 position = LibDomain.DOMAIN_STORAGE_POSITION;
        // get domain storage
        assembly {
            ds.slot := position
        }

        require(!ds.paused || ds.superAdmin == msg.sender || ds.contractOwner == msg.sender, "DomainControl: This domain is currently paused and is not in operation");
        if (ds.functionRoles[functionSelector] != bytes32(0)) {
            require(ds.accessControl[functionSelector][msg.sender], "DomainControl: sender does not have access to this function");
        }
        address feature = ds.featureAddressAndSelectorPosition[functionSelector].featureAddress;
        if(feature == address(0)) {
            revert LibDomain.FunctionNotFound(functionSelector);
        }

        require(!ds.pausedFeatures[feature] || ds.superAdmin == msg.sender || ds.contractOwner == msg.sender, "FeatureControl: This feature and functions are currently paused and not in operation");
        // Execute external function from feature using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the feature
            let result := delegatecall(gas(), feature, 0, calldatasize(), 0, 0)
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

}
