pragma solidity ^0.8.17;

import {LibDomain} from "../../../libraries/LibDomain.sol";
import {IReentrancyGuardApp} from "./IReentrancyGuardApp.sol";


contract ReentrancyGuardApp is IReentrancyGuardApp{

    function enableDisabledDomainReentrancyGuard(bool status) public {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        ds.domainReentrancyGuardEnabled = status;
        bytes32 domainGuardKey = keccak256(abi.encodePacked("domainGlobalReentrancyGuardEnabled"));
        assembly {
                sstore(add(ds.slot, domainGuardKey), status)
        }          
    }

    function enableDisabledFeatureReentrancyGuard(address feature, bool status) public {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        bytes32 featureGuardKey = keccak256(abi.encodePacked(feature, "featuresReentrancyGuardEnabled"));
        ds.featuresReentrancyGuardEnabled[keccak256(abi.encodePacked(feature))] = status;
        assembly {
                sstore(add(ds.slot, featureGuardKey), status)
        }         
    }

    function enableDisabledFunctionReentrancyGuard(bytes4 functionSelector, bool status) public {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        bytes32 functionGuardKey = keccak256(abi.encodePacked(functionSelector, "functionsReentrancyGuardEnabled"));
        ds.functionsReentrancyGuardEnabled[functionSelector] = status;
        assembly {
                sstore(add(ds.slot, functionGuardKey), status)
        }         
    }

   
    function isDomainReentrancyGuardEnabled() public view returns (bool) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        return ds.domainReentrancyGuardEnabled;
    }

    function isFeatureReentrancyGuardEnabled(address feature) public view returns (bool) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        bytes32 featureGuardKey = keccak256(abi.encodePacked(feature));
        return ds.featuresReentrancyGuardEnabled[featureGuardKey];
    }

    function isFunctionReentrancyGuardEnabled(bytes4 functionSelector) public view returns (bool) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        return ds.functionsReentrancyGuardEnabled[functionSelector];
    }

    function getDomainLock() public view returns (uint256) {
        bytes32 domainGuardLock = keccak256(abi.encodePacked("domainGlobalReentrancyGuardLock"));
        return getLockValue(domainGuardLock);
    }

    function getFeatureLock(address feature) public view returns (uint256) {
        bytes32 featureGuardLock = keccak256(abi.encodePacked(feature, "featuresReentrancyGuardLock"));
        return getLockValue(featureGuardLock);
    }

    function getFunctionLock(bytes4 functionSelector) public view returns (uint256) {
        bytes32 functionGuardLock = keccak256(abi.encodePacked(functionSelector, "functionsReentrancyGuardLock"));
        return getLockValue(functionGuardLock);
    }

    function getLockValue(bytes32 lockKey) internal view returns (uint256) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        uint256 lockValue;
        assembly {
            lockValue := sload(add(ds.slot, lockKey))
        }
        return lockValue;
    }
}
