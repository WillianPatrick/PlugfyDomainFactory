pragma solidity ^0.8.17;

import {LibDomain} from "../../../libraries/LibDomain.sol";
import {IReentrancyGuardApp} from "./IReentrancyGuardApp.sol";


contract ReentrancyGuardApp is IReentrancyGuardApp{

    function enableDisabledDomainReentrancyGuard(bool status) public {
        bytes32 domainGuardKey = keccak256(abi.encodePacked("domainGlobalReentrancyGuardEnabled"));
        bytes32 domainGuardLock = keccak256(abi.encodePacked("domainGlobalReentrancyGuardLock"));        
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        assembly {
                sstore(add(ds.slot, domainGuardKey), status)
                sstore(add(ds.slot, domainGuardLock), 0)
        }          
    }

    function enableDisabledFeatureReentrancyGuard(address feature, bool status) public {
        bytes32 featureGuardKey = keccak256(abi.encodePacked(feature, "featuresReentrancyGuardEnabled"));
        bytes32 featureGuardLock = keccak256(abi.encodePacked(feature, "featuresReentrancyGuardLock"));
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        assembly {
                sstore(add(ds.slot, featureGuardKey), status)
                sstore(add(ds.slot, featureGuardLock), 0)
        }         
    }

    function enableDisabledFunctionReentrancyGuard(bytes4 functionSelector, bool status) public {
        bytes32 functionGuardKey = keccak256(abi.encodePacked(functionSelector, "functionsReentrancyGuardEnabled"));
        bytes32 functionGuardLock = keccak256(abi.encodePacked(functionSelector, "functionsReentrancyGuardLock"));
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        assembly {
                sstore(add(ds.slot, functionGuardKey), status)
                sstore(add(ds.slot, functionGuardLock), 0)
        }         
    }

   
    function isDomainReentrancyGuardEnabled() public view returns (bool) {
        bytes32 domainGuardKey = keccak256(abi.encodePacked("domainGlobalReentrancyGuardEnabled")); 
        return bytesToBool(getPostionValue(domainGuardKey));
    }

    function isFeatureReentrancyGuardEnabled(address feature) public view returns (bool) {
        bytes32 featureGuardKey = keccak256(abi.encodePacked(feature, "featuresReentrancyGuardEnabled"));      
        return bytesToBool(getPostionValue(featureGuardKey));
    }

    function isFunctionReentrancyGuardEnabled(bytes4 functionSelector) public view returns (bool) {
        bytes32 functionGuardKey = keccak256(abi.encodePacked(functionSelector, "functionsReentrancyGuardEnabled"));       
        return bytesToBool(getPostionValue(functionGuardKey));
    }


    function getDomainLock() public view returns (uint256) {
        bytes32 domainGuardLock = keccak256(abi.encodePacked("domainGlobalReentrancyGuardLock"));
        return bytesToUint256(getPostionValue(domainGuardLock));
    }

    function getFeatureLock(address feature) public view returns (uint256) {
        bytes32 featureGuardLock = keccak256(abi.encodePacked(feature, "featuresReentrancyGuardLock"));
        return bytesToUint256(getPostionValue(featureGuardLock));
    }

    function getFunctionLock(bytes4 functionSelector) public view returns (uint256) {
        bytes32 functionGuardLock = keccak256(abi.encodePacked(functionSelector, "functionsReentrancyGuardLock"));
        return bytesToUint256(getPostionValue(functionGuardLock));
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
