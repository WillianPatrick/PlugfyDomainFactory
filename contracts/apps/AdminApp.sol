// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../libraries/LibDomain.sol";
import "./AccessControlApp.sol";

contract AdminApp is AccessControlApp {

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed newAdminRole);

 
    function grantRole(bytes32 role, address account) public onlyRole(role) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public onlyRole(role) {
        _revokeRole(role, account);
    }

    function renounceRole(bytes32 role) public {
        _revokeRole(role, msg.sender);
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole) public onlyRole(role) {
        _setRoleAdmin(role, adminRole);
    }

    function _grantRole(bytes32 role, address account) internal {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        ds.accessControl[role][account] = true;
        emit RoleGranted(role, account, msg.sender);
    }

    function _revokeRole(bytes32 role, address account) internal {
        require(hasRole(role, account), "AccessControl: account does not have role");
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        ds.accessControl[role][account] = false;
        emit RoleRevoked(role, account, msg.sender);
    }

    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        ds.roleAdmins[role] = adminRole;
        emit RoleAdminChanged(role, adminRole);
    }
}
