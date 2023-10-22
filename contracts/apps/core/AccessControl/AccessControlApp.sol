// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../../libraries/LibDomain.sol";

contract AccessControlApp {

   modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: sender does not have required role");
        _;
    }

   modifier onlyRoleName(string memory role) {
        require(hasRole(keccak256(abi.encodePacked(role)), msg.sender), "AccessControl: sender does not have required role");
        _;
    }    

    function hasRole(bytes32 role, address account) public view returns (bool) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        return (ds.contractOwner == account || ds.superAdmin == account || ds.accessControl[role][account] || ds.accessControl[ds.roleAdmins[role]][account]);
    }

}
