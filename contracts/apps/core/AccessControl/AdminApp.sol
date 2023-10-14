// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {LibDomain} from "../../../libraries/LibDomain.sol";

interface IAdminApp {
    function hasRole(bytes32 role, address account) external view returns (bool);

    function grantRole(bytes32 role, address account) external;

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
}

contract AdminApp is IAdminApp {
    bytes32 constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    modifier onlyAdminRole(bytes32 role){
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        require(hasRole(ds.roleAdmins[role], msg.sender), "AccessControl: sender must be an admin to set role");
        _;
    }

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: sender does not have required role");
        _;
    }

   modifier onlyRoleName(string memory role) {
        require(hasRole(keccak256(abi.encodePacked(role)), msg.sender), "AccessControl: sender does not have required role");
        _;
    }   

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed newAdminRole);
 

    function hasRole(bytes32 role, address account) public view returns (bool) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        return (ds.contractOwner == account || ds.superAdmin == account || ds.accessControl[role][account] || ds.accessControl[ds.roleAdmins[role]][account]);
    }

    function grantRole(bytes32 role, address account) public onlyAdminRole(role) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public onlyAdminRole(role) {
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

    function pauseDomain()  public onlyRole(PAUSER_ROLE)  {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        require(!ds.paused, "Already paused");
        ds.paused = true;
    }

    function unpauseDomain()  public onlyRole(PAUSER_ROLE)  {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        require(ds.paused, "Already unpaused");
        ds.paused = false;
    }

    function pauseFeatures(address[] memory _featureAddress)  public onlyRole(PAUSER_ROLE)  {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();        
        for (uint256 featureIndex; featureIndex < _featureAddress.length; featureIndex++) {
            if(!ds.pausedFeatures[_featureAddress[featureIndex]]){
                ds.pausedFeatures[_featureAddress[featureIndex]] = true;
            }
        }
    }

    function unpauseFeatures(address[] memory _featureAddress)  public onlyRole(PAUSER_ROLE)  {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();        
        for (uint256 featureIndex; featureIndex < _featureAddress.length; featureIndex++) {
            if(ds.pausedFeatures[_featureAddress[featureIndex]]){
                ds.pausedFeatures[_featureAddress[featureIndex]] = false;
            }
        }
    }     
}
