    // SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IReentrancyGuardApp {


    function enableDisabledDomainReentrancyGuard(bool status) external;

    function enableDisabledFeatureReentrancyGuard(address feature, bool status) external;

    function enableDisabledFunctionReentrancyGuard(bytes4 functionSelector, bool status) external;

    function enableDisabledSenderReentrancyGuard(bool status) external;

    function isDomainReentrancyGuardEnabled() external view returns (bool);

    function isFeatureReentrancyGuardEnabled(address feature) external view returns (bool);

    function isFunctionReentrancyGuardEnabled(bytes4 functionSelector) external view returns (bool);

    function isSenderReentrancyGuardEnabled() external view returns (bool);    

    function getDomainLock() external view returns (uint256);

    function getFeatureLock(address feature) external view returns (uint256);

    function getFunctionLock(bytes4 functionSelector) external view returns (uint256);

    function getSenderLock(address sender) external view returns (uint256);    
   
}