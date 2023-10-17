// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct roleAccount {
    string name;
    bytes32 role;
    address account;
}
interface IAdminApp {
    function hasRole(bytes32 role, address account) external view returns (bool);

    function grantRole(bytes32 role, address account) external;

    function getRoleHash(string memory name) external pure returns (bytes32);
    function revokeRole(bytes32 role, address account) external;

    function renounceRole(bytes32 role) external;

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external;

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function setFunctionRole(bytes4 functionSelector, bytes32 role) external;

    function removeFunctionRole(bytes4 functionSelector) external;

    function pauseDomain() external;

    function unpauseDomain() external;

    function pauseFeatures(address[] memory _featureAddress) external;

    function unpauseFeatures(address[] memory _featureAddress) external;

    function setReentrancyGuard(bytes4 _functionSelector, bool _enabled) external;
    
    function getReentrancyGuard(bytes4 _functionSelector) external view returns(bool);
}