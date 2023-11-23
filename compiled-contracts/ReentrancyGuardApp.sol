pragma solidity ^0.8.17;\n\nimport { LibDomain } from "../../../libraries/LibDomain.sol";
import { IReentrancyGuardApp } from "./IReentrancyGuardApp.sol";
import { IAdminApp } from "./IAdminApp.sol";

library LibReentrancyGuard {
    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("security.reentrance.guard.standard.storage");

    struct DomainStorage{
        bool initialized;
    }

    function domainStorage() internal pure returns (DomainStorage storage ds) {
        bytes32 position = DOMAIN_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}

contract ReentrancyGuardApp is IReentrancyGuardApp{
    function _initReentrancyGuard() public {
        LibReentrancyGuard.DomainStorage storage ds = LibReentrancyGuard.domainStorage();
        require(!ds.initialized, "Initialization has already been executed.");

        //Setting up roles for specific functions
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("_initReentrancyGuard()"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("enableDisabledDomainReentrancyGuard(bool)"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("enableDisabledFeatureReentrancyGuard(address,bool)"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("enableDisabledFunctionReentrancyGuard(bytes4,bool)"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("enableDisabledSenderReentrancyGuard(bool)"))), LibDomain.DEFAULT_ADMIN_ROLE);

        // Protecting the contract's functions from reentrancy attacks
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("enableDisabledDomainReentrancyGuard(bool)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("enableDisabledFeatureReentrancyGuard(address,bool)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("enableDisabledFunctionReentrancyGuard(bytes4,bool)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("enableDisabledSenderReentrancyGuard(bool)"))), true);

        ds.initialized = true;
    }



    function enableDisabledDomainReentrancyGuard(bool status) public {
        bytes32 flagKey = keccak256(abi.encodePacked("domainGlobalReentrancyGuardEnabled"));
        bytes32 flagLock = keccak256(abi.encodePacked("domainGlobalReentrancyGuardLock"));        
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        assembly {
                sstore(add(ds.slot, flagKey), status)
                sstore(add(ds.slot, flagLock), 0)
        }          
    }

    function enableDisabledFeatureReentrancyGuard(address feature, bool status) public {
        bytes32 flagKey = keccak256(abi.encodePacked(feature, "featuresReentrancyGuardEnabled"));
        bytes32 flagLock = keccak256(abi.encodePacked(feature, "featuresReentrancyGuardLock"));
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        assembly {
                sstore(add(ds.slot, flagKey), status)
                sstore(add(ds.slot, flagLock), 0)
        }         
    }

    function enableDisabledFunctionReentrancyGuard(bytes4 functionSelector, bool status) public {
        bytes32 flagKey = keccak256(abi.encodePacked(functionSelector, "functionsReentrancyGuardEnabled"));
        bytes32 flagLock = keccak256(abi.encodePacked(functionSelector, "functionsReentrancyGuardLock"));
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        assembly {
                sstore(add(ds.slot, flagKey), status)
                sstore(add(ds.slot, flagLock), 0)
        }         
    }

    function enableDisabledSenderReentrancyGuard(bool status) public {
        bytes32 flagKey = keccak256(abi.encodePacked("senderReentrancyGuardEnabled"));
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        assembly {
                sstore(add(ds.slot, flagKey), status)
        }         
    }
   
    function isDomainReentrancyGuardEnabled() public view returns (bool) {
        bytes32 flagKey = keccak256(abi.encodePacked("domainGlobalReentrancyGuardEnabled")); 
        return bytesToBool(getPostionValue(flagKey));
    }

    function isFeatureReentrancyGuardEnabled(address feature) public view returns (bool) {
        bytes32 flagKey = keccak256(abi.encodePacked(feature, "featuresReentrancyGuardEnabled"));      
        return bytesToBool(getPostionValue(flagKey));
    }

    function isFunctionReentrancyGuardEnabled(bytes4 functionSelector) public view returns (bool) {
        bytes32 flagKey = keccak256(abi.encodePacked(functionSelector, "functionsReentrancyGuardEnabled"));       
        return bytesToBool(getPostionValue(flagKey));
    }

    function isSenderReentrancyGuardEnabled() public view returns (bool) {
        bytes32 flagKey = keccak256(abi.encodePacked("senderReentrancyGuardEnabled"));       
        return bytesToBool(getPostionValue(flagKey));
    }

    function getDomainLock() public view returns (uint256) {
        bytes32 flagLock = keccak256(abi.encodePacked("domainGlobalReentrancyGuardLock"));
        return bytesToUint256(getPostionValue(flagLock));
    }

    function getFeatureLock(address feature) public view returns (uint256) {
        bytes32 flagLock = keccak256(abi.encodePacked(feature, "featuresReentrancyGuardLock"));
        return bytesToUint256(getPostionValue(flagLock));
    }

    function getFunctionLock(bytes4 functionSelector) public view returns (uint256) {
        bytes32 flagLock = keccak256(abi.encodePacked(functionSelector, "functionsReentrancyGuardLock"));
        return bytesToUint256(getPostionValue(flagLock));
    }

    function getSenderLock(address sender)  public view returns (uint256) {
        bytes32 flagLock = keccak256(abi.encodePacked(sender, "senderReentrancyGuardLock"));
        return bytesToUint256(getPostionValue(flagLock));
    }

    function getPostionValue(bytes32 postionKey) internal view returns (bytes32) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        bytes32 _value;
        assembly {
            _value := sload(add(ds.slot, postionKey))
        }
        return _value;
    }    

    function bytesToUint256(bytes32 input) internal pure returns (uint256 output) {
        require(input.length == 32, "Requires 32 bytes.");
        assembly {
            output := mload(add(input, 32))
        }
    }

    function bytesToBool(bytes32 input) internal pure returns (bool output) {
        require(input.length == 32, "Requires 32 bytes.");
        uint256 result;
        assembly {
            result := mload(add(input, 32))
        }
        output = (result != 0);  // Convert to bool
    }


}