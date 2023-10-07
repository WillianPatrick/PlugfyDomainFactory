// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Domain } from "../Domain.sol";
import { IPackagerManager } from "../apps/core/PackagerManager/IPackagerManager.sol";

import { IPackagerRoutes } from "../apps/core/PackagerManager/IPackagerRoutes.sol";

error NoSelectorsGivenToAdd();
error NotContractOwner(address _user, address _contractOwner);
error NoSelectorsProvidedForPackager(address _packAddress);
error CannotAddSelectorsToZeroAddress(bytes4[] _selectors);
error NoBytecodeAtAddress(address _contractAddress, string _message);
error IncorrectPackagerManagerAction(uint8 _action);
error CannotAddFunctionToPackagerThatAlreadyExists(bytes4 _selector);
error CannotReplaceFunctionsFromPackagerWithZeroAddress(bytes4[] _selectors);
error CannotReplaceImmutableFunction(bytes4 _selector);
error CannotReplaceFunctionWithTheSameFunctionFromTheSamePackager(bytes4 _selector);
error CannotReplaceFunctionThatDoesNotExists(bytes4 _selector);
error RemovePackagerAddressMustBeZeroAddress(address _packAddress);
error CannotRemoveFunctionThatDoesNotExist(bytes4 _selector);
error CannotRemoveImmutableFunction(bytes4 _selector);
error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);
error NotTokenAdmin(address currentAdminAddress);

library LibDomain {
    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("domain.standard.storage");
    bytes32 constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");

    event OwnershipTransferred(address previousOwner, address _newOwner);
    event AdminshipTransferred(address indexed previousAdmin, address indexed newAdmin);
    event PackagerManagerExecuted(IPackagerManager.Packager[] _packs, address _init, bytes _calldata);

    struct PackagerAddressAndSelectorPosition {
        address packAddress;
        uint16 selectorPosition;
    }

    struct DomainStorage {
        address parentDomain;
        string name;
        address[] domains;
        mapping(address => uint256) domainIdx;
        mapping(bytes4 => PackagerAddressAndSelectorPosition) packAddressAndSelectorPosition;
        bytes4[] selectors;
        mapping(address => bool) pausedPackagers;
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



    function packManager(
        IPackagerManager.Packager[] memory _packs,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 packIndex; packIndex < _packs.length; packIndex++) {
            bytes4[] memory functionSelectors = _packs[packIndex].functionSelectors;
            address PackagerAddress = _packs[packIndex].packAddress;

            if(functionSelectors.length == 0) {
                revert NoSelectorsProvidedForPackager(PackagerAddress);
            }

            IPackagerManager.PackagerManagerAction action = _packs[packIndex].action;
            if (action == IPackagerManager.PackagerManagerAction.Add) {
                addFunctions(PackagerAddress, functionSelectors);
            } else if (action == IPackagerManager.PackagerManagerAction.Replace) {
                replaceFunctions(PackagerAddress, functionSelectors);
            } else if (action == IPackagerManager.PackagerManagerAction.Remove) {
                removeFunctions(PackagerAddress, functionSelectors);
            } else {
                revert IncorrectPackagerManagerAction(uint8(action));
            }
        }

        emit PackagerManagerExecuted(_packs, _init, _calldata);
        initializePackagerManager(_init, _calldata);
    }

    function addFunctions(address _PackagerAddress, bytes4[] memory _functionSelectors) internal {  
        if(_PackagerAddress == address(0)) {
            revert CannotAddSelectorsToZeroAddress(_functionSelectors);
        }
        DomainStorage storage ds = domainStorage();
        uint16 selectorCount = uint16(ds.selectors.length);                
        enforceHasContractCode(_PackagerAddress, "LibPackagerManager: Add pack has no code");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldPackagerAddress = ds.packAddressAndSelectorPosition[selector].packAddress;
            if(oldPackagerAddress != address(0)) {
                //revert CannotAddFunctionToDomainThatAlreadyExists(selector);
                continue;
            }            
            ds.packAddressAndSelectorPosition[selector] = PackagerAddressAndSelectorPosition(_PackagerAddress, selectorCount);
            ds.selectors.push(selector);
            selectorCount++;
        }
    }

    function replaceFunctions(address _PackagerAddress, bytes4[] memory _functionSelectors) internal {       
        DomainStorage storage ds = domainStorage();
        if(_PackagerAddress == address(0)) {
            revert CannotReplaceFunctionsFromPackagerWithZeroAddress(_functionSelectors);
        }
        enforceHasContractCode(_PackagerAddress, "LibPackagerManager: Replace pack has no code");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldPackagerAddress = ds.packAddressAndSelectorPosition[selector].packAddress;
            // can't replace immutable functions -- functions defined directly in the domain in this case
            if(oldPackagerAddress == address(this)) {
                revert CannotReplaceImmutableFunction(selector);
            }
            if(oldPackagerAddress == _PackagerAddress) {
                revert CannotReplaceFunctionWithTheSameFunctionFromTheSamePackager(selector);
            }
            if(oldPackagerAddress == address(0)) {
                revert CannotReplaceFunctionThatDoesNotExists(selector);
            }
            // replace old pack address
            ds.packAddressAndSelectorPosition[selector].packAddress = _PackagerAddress;
        }
    }

    function removeFunctions(address _PackagerAddress, bytes4[] memory _functionSelectors) internal {        
        DomainStorage storage ds = domainStorage();
        uint256 selectorCount = ds.selectors.length;
        if(_PackagerAddress != address(0)) {
            revert RemovePackagerAddressMustBeZeroAddress(_PackagerAddress);
        }        
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            PackagerAddressAndSelectorPosition memory oldPackagerAddressAndSelectorPosition = ds.packAddressAndSelectorPosition[selector];
            if(oldPackagerAddressAndSelectorPosition.packAddress == address(0)) {
                revert CannotRemoveFunctionThatDoesNotExist(selector);
            }
            
            
            // can't remove immutable functions -- functions defined directly in the domain
            if(oldPackagerAddressAndSelectorPosition.packAddress == address(this)) {
                revert CannotRemoveImmutableFunction(selector);
            }
            // replace selector with last selector
            selectorCount--;
            if (oldPackagerAddressAndSelectorPosition.selectorPosition != selectorCount) {
                bytes4 lastSelector = ds.selectors[selectorCount];
                ds.selectors[oldPackagerAddressAndSelectorPosition.selectorPosition] = lastSelector;
                ds.packAddressAndSelectorPosition[lastSelector].selectorPosition = oldPackagerAddressAndSelectorPosition.selectorPosition;
            }
            // delete last selector
            ds.selectors.pop();
            delete ds.packAddressAndSelectorPosition[selector];
        }
    }

    function initializePackagerManager(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            return;
        }
        enforceHasContractCode(_init, "LibPackagerManager: _init address has no code");        
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
