// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Domain } from "../Domain.sol";
import { IFeatureManager } from "../apps/core/FeatureManager/IFeatureManager.sol";

import { IFeatureRoutes } from "../apps/core/FeatureManager/IFeatureRoutes.sol";

error NoSelectorsGivenToAdd();
error NotContractOwner(address _user, address _contractOwner);
error NoSelectorsProvidedForFeature(address _featureAddress);
error CannotAddSelectorsToZeroAddress(bytes4[] _selectors);
error NoBytecodeAtAddress(address _contractAddress, string _message);
error IncorrectFeatureManagerAction(uint8 _action);
error CannotAddFunctionToFeatureThatAlreadyExists(bytes4 _selector);
error CannotReplaceFunctionsFromFeatureWithZeroAddress(bytes4[] _selectors);
error CannotReplaceImmutableFunction(bytes4 _selector);
error CannotReplaceFunctionWithTheSameFunctionFromTheSameFeature(bytes4 _selector);
error CannotReplaceFunctionThatDoesNotExists(bytes4 _selector);
error RemoveFeatureAddressMustBeZeroAddress(address _featureAddress);
error CannotRemoveFunctionThatDoesNotExist(bytes4 _selector);
error CannotRemoveImmutableFunction(bytes4 _selector);
error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);
error NotTokenAdmin(address currentAdminAddress);

library LibDomain {
    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("domain.standard.storage");
    bytes32 constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");

    event OwnershipTransferred(address previousOwner, address _newOwner);
    event AdminshipTransferred(address indexed previousAdmin, address indexed newAdmin);
    event FeatureManagerExecuted(IFeatureManager.Feature[] _features, address _init, bytes _calldata);

    struct FeatureAddressAndSelectorPosition {
        address featureAddress;
        uint16 selectorPosition;
    }

    struct DomainStorage {
        address parentDomain;
        string name;
        address[] domains;
        mapping(address => uint256) domainIdx;
        mapping(bytes4 => FeatureAddressAndSelectorPosition) featureAddressAndSelectorPosition;
        bytes4[] selectors;
        mapping(address => bool) pausedFeatures;
        mapping(bytes4 => bool) pausedSelectors;
        address contractOwner;
        address superAdmin;
        mapping(bytes32 => mapping(address => bool)) accessControl;
        mapping(bytes32 => bytes32) roleAdmins; 
        mapping(bytes4 => bytes32) functionRoles;
        mapping(bytes32 => mapping(bytes32 => bytes32)) roles;
        bool paused;
    }


    function enforceIsTokenSuperAdmin() internal view {
        if(msg.sender != domainStorage().superAdmin) {
            revert NotTokenAdmin(domainStorage().superAdmin);
        }        
    }

    function setSuperAdmin(address _newAdmin) internal {
        enforceIsContractOwnerAdmin();
        address previousAdmin = domainStorage().superAdmin;
        domainStorage().superAdmin = _newAdmin;
        domainStorage().accessControl[DEFAULT_ADMIN_ROLE][_newAdmin] = true;
        emit AdminshipTransferred(previousAdmin, _newAdmin);
    }

    function domainStorage() internal pure returns (DomainStorage storage ds) {
        bytes32 position = DOMAIN_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }    

    function domainSecureStorage(bytes32 storageKey) internal pure returns (DomainStorage storage ds) {
        bytes32 position = storageKey;
        assembly {
            ds.slot := position
        }
    }

    function setContractOwner(address _newOwner) internal {
        enforceIsContractOwnerAdmin();
        DomainStorage storage ds = domainStorage();
        address previousOwner = ds.contractOwner;
        domainStorage().contractOwner = _newOwner;
        domainStorage().accessControl[DEFAULT_ADMIN_ROLE][_newOwner] = true;   
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function contractOwner() internal view returns (address contractOwner_) {
        contractOwner_ = domainStorage().contractOwner;
    }

    function contractSuperAdmin() internal view returns (address contractAdmin_) {
        contractAdmin_ = domainStorage().superAdmin;
    }   

    function enforceIsContractOwnerAdmin() internal view {
        if(address(0) != domainStorage().contractOwner  && address(0) != domainStorage().superAdmin && msg.sender != domainStorage().contractOwner && msg.sender != domainStorage().superAdmin) {
            revert NotContractOwner(msg.sender, domainStorage().contractOwner);
        }        
    } 

    function enforceIsContractOwner() internal view {
        if(address(0) != domainStorage().contractOwner  && address(0) != domainStorage().superAdmin &&msg.sender != domainStorage().contractOwner) {
            revert NotContractOwner(msg.sender, domainStorage().contractOwner);
        }        
    }     



    function featureManager(
        IFeatureManager.Feature[] memory _features,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 featureIndex; featureIndex < _features.length; featureIndex++) {
            bytes4[] memory functionSelectors = _features[featureIndex].functionSelectors;
            address FeatureAddress = _features[featureIndex].featureAddress;

            if(functionSelectors.length == 0) {
                revert NoSelectorsProvidedForFeature(FeatureAddress);
            }

            IFeatureManager.FeatureManagerAction action = _features[featureIndex].action;
            if (action == IFeatureManager.FeatureManagerAction.Add) {
                addFunctions(FeatureAddress, functionSelectors);
            } else if (action == IFeatureManager.FeatureManagerAction.Replace) {
                replaceFunctions(FeatureAddress, functionSelectors);
            } else if (action == IFeatureManager.FeatureManagerAction.Remove) {
                removeFunctions(FeatureAddress, functionSelectors);
            } else {
                revert IncorrectFeatureManagerAction(uint8(action));
            }
        }

        emit FeatureManagerExecuted(_features, _init, _calldata);
        initializeFeatureManager(_init, _calldata);
    }

    function addFunctions(address _FeatureAddress, bytes4[] memory _functionSelectors) internal {  
        if(_FeatureAddress == address(0)) {
            revert CannotAddSelectorsToZeroAddress(_functionSelectors);
        }
        DomainStorage storage ds = domainStorage();
        uint16 selectorCount = uint16(ds.selectors.length);                
        enforceHasContractCode(_FeatureAddress, "LibFeatureManager: Add feature has no code");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFeatureAddress = ds.featureAddressAndSelectorPosition[selector].featureAddress;
            if(oldFeatureAddress != address(0)) {
                //revert CannotAddFunctionToDomainThatAlreadyExists(selector);
                continue;
            }            
            ds.featureAddressAndSelectorPosition[selector] = FeatureAddressAndSelectorPosition(_FeatureAddress, selectorCount);
            ds.selectors.push(selector);
            selectorCount++;
        }
    }

    function replaceFunctions(address _FeatureAddress, bytes4[] memory _functionSelectors) internal {       
        DomainStorage storage ds = domainStorage();
        if(_FeatureAddress == address(0)) {
            revert CannotReplaceFunctionsFromFeatureWithZeroAddress(_functionSelectors);
        }
        enforceHasContractCode(_FeatureAddress, "LibFeatureManager: Replace feature has no code");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFeatureAddress = ds.featureAddressAndSelectorPosition[selector].featureAddress;
            // can't replace immutable functions -- functions defined directly in the domain in this case
            if(oldFeatureAddress == address(this)) {
                revert CannotReplaceImmutableFunction(selector);
            }
            if(oldFeatureAddress == _FeatureAddress) {
                revert CannotReplaceFunctionWithTheSameFunctionFromTheSameFeature(selector);
            }
            if(oldFeatureAddress == address(0)) {
                revert CannotReplaceFunctionThatDoesNotExists(selector);
            }
            // replace old feature address
            ds.featureAddressAndSelectorPosition[selector].featureAddress = _FeatureAddress;
        }
    }

    function removeFunctions(address _FeatureAddress, bytes4[] memory _functionSelectors) internal {        
        DomainStorage storage ds = domainStorage();
        uint256 selectorCount = ds.selectors.length;
        if(_FeatureAddress != address(0)) {
            revert RemoveFeatureAddressMustBeZeroAddress(_FeatureAddress);
        }        
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            FeatureAddressAndSelectorPosition memory oldFeatureAddressAndSelectorPosition = ds.featureAddressAndSelectorPosition[selector];
            if(oldFeatureAddressAndSelectorPosition.featureAddress == address(0)) {
                revert CannotRemoveFunctionThatDoesNotExist(selector);
            }
            
            
            // can't remove immutable functions -- functions defined directly in the domain
            if(oldFeatureAddressAndSelectorPosition.featureAddress == address(this)) {
                revert CannotRemoveImmutableFunction(selector);
            }
            // replace selector with last selector
            selectorCount--;
            if (oldFeatureAddressAndSelectorPosition.selectorPosition != selectorCount) {
                bytes4 lastSelector = ds.selectors[selectorCount];
                ds.selectors[oldFeatureAddressAndSelectorPosition.selectorPosition] = lastSelector;
                ds.featureAddressAndSelectorPosition[lastSelector].selectorPosition = oldFeatureAddressAndSelectorPosition.selectorPosition;
            }
            // delete last selector
            ds.selectors.pop();
            delete ds.featureAddressAndSelectorPosition[selector];
        }
    }

    function initializeFeatureManager(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            return;
        }
        enforceHasContractCode(_init, "LibFeatureManager: _init address has no code");        
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                // bubble up error
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            } else {
                revert InitializationFunctionReverted(_init, _calldata);
            }
        }        
    }

    function enforceHasContractCode(address _contract, string memory _errorMessage) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        if(contractSize == 0) {
            revert NoBytecodeAtAddress(_contract, _errorMessage);
        }        
    }
}
