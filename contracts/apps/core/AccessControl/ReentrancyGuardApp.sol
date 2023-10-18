pragma solidity ^0.8.17;

import {LibDomain} from "../../../libraries/LibDomain.sol";

contract ReentrancyGuardApp{
    function enableDomainReentrancyGuard() public {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();      
        ds.domainReentrancyGuardEnabled = true;
    }

    function disableDomainReentrancyGuard() public {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();      
        ds.domainReentrancyGuardEnabled = false;
    }

    function setFeatureReentrancyGuard(bytes32 featureHash, bool status) public {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();      
        ds.featuresReentrancyGuardEnabled[featureHash] = status;
    }

    function setFunctionReentrancyGuard(bytes4 functionSelector, bool status) public {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();      
        ds.functionsReentrancyGuardEnabled[functionSelector] = status;
    }

    function isDomainReentrancyGuardEnabled() public view returns (bool) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();      
        return ds.domainReentrancyGuardEnabled;
    }

    function isFeatureReentrancyGuardEnabled(bytes32 featureHash) public view returns (bool) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();      
        return ds.featuresReentrancyGuardEnabled[featureHash];
    }

    function isFunctionReentrancyGuardEnabled(bytes4 functionSelector) public view returns (bool) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();      
        return ds.functionsReentrancyGuardEnabled[functionSelector];
    }
}