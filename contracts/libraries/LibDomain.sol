// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IDomain } from "../interfaces/IDomain.sol";
import { IAppManager } from "../interfaces/IAppManager.sol";

error NoSelectorsGivenToAdd();
error NotContractOwner(address _user, address _contractOwner);
error NoSelectorsProvidedForApp(address _appAddress);
error CannotAddSelectorsToZeroAddress(bytes4[] _selectors);
error NoBytecodeAtAddress(address _contractAddress, string _message);
error IncorrectAppManagerAction(uint8 _action);
error CannotAddFunctionToAppThatAlreadyExists(bytes4 _selector);
error CannotReplaceFunctionsFromAppWithZeroAddress(bytes4[] _selectors);
error CannotReplaceImmutableFunction(bytes4 _selector);
error CannotReplaceFunctionWithTheSameFunctionFromTheSameApp(bytes4 _selector);
error CannotReplaceFunctionThatDoesNotExists(bytes4 _selector);
error RemoveAppAddressMustBeZeroAddress(address _appAddress);
error CannotRemoveFunctionThatDoesNotExist(bytes4 _selector);
error CannotRemoveImmutableFunction(bytes4 _selector);
error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);
error NotTokenAdmin(address currentAdminAddress);

library LibDomain {
    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("domain.standard.domain.storage");
    bytes32 constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    event OwnershipTransferred(address previousOwner, address _newOwner);
    event AdminshipTransferred(address indexed previousAdmin, address indexed newAdmin);

    function enforceIsTokenAdmin() internal view {
        if(msg.sender != domainStorage(DOMAIN_STORAGE_POSITION).superAdmin) {
            revert NotTokenAdmin(domainStorage(DOMAIN_STORAGE_POSITION).superAdmin);
        }        
    }

    function enforceIsTokenAdmin(bytes32 storageKey) internal view {
        if(msg.sender != domainStorage(storageKey).superAdmin) {
            revert NotTokenAdmin(domainStorage(storageKey).superAdmin);
        }        
    }

    function setAdmin(address _newAdmin, bytes32 storageKey) internal {
        address previousAdmin = domainStorage(storageKey).superAdmin;
        domainStorage(storageKey).superAdmin = _newAdmin;
        domainStorage(storageKey).accessControl[DEFAULT_ADMIN_ROLE][_newAdmin] = true;
        //domainStorage(storageKey).roleAdmins[DEFAULT_ADMIN_ROLE] = _newAdmin;
        emit AdminshipTransferred(previousAdmin, _newAdmin);
    }

    function setAdmin(address _newAdmin) internal {
        setAdmin(_newAdmin, DOMAIN_STORAGE_POSITION);
    }    

    struct AppAddressAndSelectorPosition {
        address appAddress;
        uint16 selectorPosition;
    }

    struct DomainStorage {
        mapping(bytes4 => AppAddressAndSelectorPosition) appAddressAndSelectorPosition;
        bytes4[] selectors;
        mapping(address => bool) pausedApps;
        mapping(bytes4 => bool) pausedSelectors;
        address contractOwner;
        address superAdmin;
        mapping(bytes32 => mapping(address => bool)) accessControl;
        mapping(bytes32 => bytes32) roleAdmins; 
        mapping(bytes4 => bytes32) functionRoles;
        mapping(bytes32 => mapping(bytes32 => bytes32)) roles;
    }

    function domainStorage() internal pure returns (DomainStorage storage ds) {
        bytes32 position = DOMAIN_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }    

    function domainStorage(bytes32 storageKey) internal pure returns (DomainStorage storage ds) {
        bytes32 position = storageKey;
        assembly {
            ds.slot := position
        }
    }

    function setContractOwner(address _newOwner, bytes32 storageKey) internal {
        DomainStorage storage ds = domainStorage(storageKey);
        address previousOwner = ds.contractOwner;
        domainStorage(storageKey).contractOwner = _newOwner;
        domainStorage(storageKey).accessControl[DEFAULT_ADMIN_ROLE][_newOwner] = true;   
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function setContractOwner(address _newOwner) internal {
        setContractOwner(_newOwner, DOMAIN_STORAGE_POSITION);
    }    

    function contractOwner(bytes32 storageKey) internal view returns (address contractOwner_) {
        contractOwner_ = domainStorage(storageKey).contractOwner;
    }

    function contractOwner() internal view returns (address contractOwner_) {
        contractOwner_ = domainStorage(DOMAIN_STORAGE_POSITION).contractOwner;
    }   

    function contractAdmin(bytes32 storageKey) internal view returns (address contractAdmin_) {
        contractAdmin_ = domainStorage(storageKey).superAdmin;
    }   

    function contractAdmin() internal view returns (address contractAdmin_) {
        contractAdmin_ = domainStorage(DOMAIN_STORAGE_POSITION).superAdmin;
    }   

    function enforceIsContractOwner(bytes32 storageKey) internal view {
        if(msg.sender != domainStorage(storageKey).contractOwner && msg.sender != domainStorage(storageKey).superAdmin) {
            revert NotContractOwner(msg.sender, domainStorage(storageKey).contractOwner);
        }        
    }

    function enforceIsContractOwner() internal view {
        enforceIsContractOwner(DOMAIN_STORAGE_POSITION);
    }    

    event AppManagerExecuted(IAppManager.App[] _apps, address _init, bytes _calldata);

    function appManager(
        IAppManager.App[] memory _apps,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 appIndex; appIndex < _apps.length; appIndex++) {
            bytes4[] memory functionSelectors = _apps[appIndex].functionSelectors;
            address AppAddress = _apps[appIndex].appAddress;

            if(functionSelectors.length == 0) {
                revert NoSelectorsProvidedForApp(AppAddress);
            }

            IAppManager.AppManagerAction action = _apps[appIndex].action;
            if (action == IDomain.AppManagerAction.Add) {
                addFunctions(AppAddress, functionSelectors);
            } else if (action == IDomain.AppManagerAction.Replace) {
                replaceFunctions(AppAddress, functionSelectors);
            } else if (action == IDomain.AppManagerAction.Remove) {
                removeFunctions(AppAddress, functionSelectors);
            } else {
                revert IncorrectAppManagerAction(uint8(action));
            }
        }

        emit AppManagerExecuted(_apps, _init, _calldata);
        initializeAppManager(_init, _calldata);
    }

    function addFunctions(address _AppAddress, bytes4[] memory _functionSelectors) internal {  
        if(_AppAddress == address(0)) {
            revert CannotAddSelectorsToZeroAddress(_functionSelectors);
        }
        DomainStorage storage ds = domainStorage(DOMAIN_STORAGE_POSITION);
        uint16 selectorCount = uint16(ds.selectors.length);                
        enforceHasContractCode(_AppAddress, "LibAppManager: Add app has no code");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldAppAddress = ds.appAddressAndSelectorPosition[selector].appAddress;
            if(oldAppAddress != address(0)) {
                //revert CannotAddFunctionToDomainThatAlreadyExists(selector);
                continue;
            }            
            ds.appAddressAndSelectorPosition[selector] = AppAddressAndSelectorPosition(_AppAddress, selectorCount);
            ds.selectors.push(selector);
            selectorCount++;
        }
    }

    function replaceFunctions(address _AppAddress, bytes4[] memory _functionSelectors) internal {       
        DomainStorage storage ds = domainStorage(DOMAIN_STORAGE_POSITION);
        if(_AppAddress == address(0)) {
            revert CannotReplaceFunctionsFromAppWithZeroAddress(_functionSelectors);
        }
        enforceHasContractCode(_AppAddress, "LibAppManager: Replace app has no code");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldAppAddress = ds.appAddressAndSelectorPosition[selector].appAddress;
            // can't replace immutable functions -- functions defined directly in the domain in this case
            if(oldAppAddress == address(this)) {
                revert CannotReplaceImmutableFunction(selector);
            }
            if(oldAppAddress == _AppAddress) {
                revert CannotReplaceFunctionWithTheSameFunctionFromTheSameApp(selector);
            }
            if(oldAppAddress == address(0)) {
                revert CannotReplaceFunctionThatDoesNotExists(selector);
            }
            // replace old app address
            ds.appAddressAndSelectorPosition[selector].appAddress = _AppAddress;
        }
    }

    function removeFunctions(address _AppAddress, bytes4[] memory _functionSelectors) internal {        
        DomainStorage storage ds = domainStorage(DOMAIN_STORAGE_POSITION);
        uint256 selectorCount = ds.selectors.length;
        if(_AppAddress != address(0)) {
            revert RemoveAppAddressMustBeZeroAddress(_AppAddress);
        }        
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            AppAddressAndSelectorPosition memory oldAppAddressAndSelectorPosition = ds.appAddressAndSelectorPosition[selector];
            if(oldAppAddressAndSelectorPosition.appAddress == address(0)) {
                revert CannotRemoveFunctionThatDoesNotExist(selector);
            }
            
            
            // can't remove immutable functions -- functions defined directly in the domain
            if(oldAppAddressAndSelectorPosition.appAddress == address(this)) {
                revert CannotRemoveImmutableFunction(selector);
            }
            // replace selector with last selector
            selectorCount--;
            if (oldAppAddressAndSelectorPosition.selectorPosition != selectorCount) {
                bytes4 lastSelector = ds.selectors[selectorCount];
                ds.selectors[oldAppAddressAndSelectorPosition.selectorPosition] = lastSelector;
                ds.appAddressAndSelectorPosition[lastSelector].selectorPosition = oldAppAddressAndSelectorPosition.selectorPosition;
            }
            // delete last selector
            ds.selectors.pop();
            delete ds.appAddressAndSelectorPosition[selector];
        }
    }

    function initializeAppManager(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            return;
        }
        enforceHasContractCode(_init, "LibAppManager: _init address has no code");        
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
