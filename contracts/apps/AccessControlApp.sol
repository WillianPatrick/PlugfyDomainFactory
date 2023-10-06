// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../libraries/LibDomain.sol";

contract AccessControlApp {

   modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: sender does not have required role");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        return (ds.contractOwner == account || ds.superAdmin == account || ds.accessControl[role][account] || ds.accessControl[ds.roleAdmins[role]][account]);
    }

    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        return ds.roleAdmins[role];
    }

    function setFunctionRole(bytes4 functionSelector, bytes32 role) external {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        require(hasRole(ds.roleAdmins[role], msg.sender), "AccessControl: sender must be an admin to set role");
        ds.functionRoles[functionSelector] = role;
    }

    function removeFunctionRole(bytes4 functionSelector) external {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        require(hasRole(ds.roleAdmins[ds.functionRoles[functionSelector]], msg.sender), "AccessControl: sender must be an admin to remove role");
        delete ds.functionRoles[functionSelector];
    }

}
