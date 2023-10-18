    // SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IReentrancyGuardApp {
    function enableDomainReentrancyGuard() external;

    function disableDomainReentrancyGuard() external;

    function setFeatureReentrancyGuard(bytes32 featureHash, bool status)  external;
    function setFunctionReentrancyGuard(bytes4 functionSelector, bool status)  external;

    function isDomainReentrancyGuardEnabled() external  view returns (bool);
    function isFeatureReentrancyGuardEnabled(bytes32 featureHash) external view returns (bool);

    function isFunctionReentrancyGuardEnabled(bytes4 functionSelector) external view returns (bool);
}