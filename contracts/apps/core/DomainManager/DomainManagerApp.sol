// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Domain, DomainArgs, IFeatureManager } from "../../../Domain.sol";
import { IAdminApp } from "../AccessControl/AdminApp.sol";

library LibDomainManager {
    bytes32 constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("domain.manager.standard.storage");

    struct DomainStorage{
        address[] domains;
        mapping(address => uint256) domainsIdx;
        bool initialized;
        address[] domainWhiteListTokens;  
        mapping(address => uint256) domainWhiteListTokensIdx;   
        address[] domainBlackListTokens; 
        mapping(address => uint256) domainBlackListTokensIdx;
        address[] domainWhiteListAccount;        
        mapping(address => uint256) domainWhiteListAccountIdx;        
        address[] domainBlackListAccount;      
    }

    function domainStorage() internal pure returns (DomainStorage storage ds) {
        bytes32 position = DOMAIN_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }    
}

///implement Domain Factory Multi App based on Diamond Facet Cut implementions https://eips.ethereum.org/EIPS/eip-2535
contract DomainManagerApp  {

    event DomainCreated(address indexed domainAddress, address indexed owner);

    function _initDomainManagerApp() public {
        LibDomainManager.DomainStorage storage ds = LibDomainManager.domainStorage();
        require(!ds.initialized, "Initialization has already been executed.");

        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("_initDomainManagerApp()"))), LibDomainManager.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("createDomain(address,string,IFeatureManager.Feature[],DomainArgs)"))), LibDomainManager.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("getTotalDomains()"))), LibDomainManager.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("getDomainAddress(uint256)"))), LibDomainManager.DEFAULT_ADMIN_ROLE);

        ds.initialized = true;
    }

    function createDomain(address _parentDomain, string memory _domainName, IFeatureManager.Feature[] memory _features, DomainArgs memory _args) public returns (address) {
        LibDomainManager.DomainStorage storage ds = LibDomainManager.domainStorage();
        _args.owner = _args.owner == address(0) ? msg.sender : _args.owner;
        Domain domain = new Domain(_parentDomain, _domainName, _features, _args);
        ds.domainsIdx[address(domain)] = ds.domains.length;
        ds.domains.push(address(domain));

        IAdminApp(address(domain)).setRoleAdmin(LibDomainManager.DEFAULT_ADMIN_ROLE, LibDomainManager.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(domain)).grantRole(LibDomainManager.DEFAULT_ADMIN_ROLE, _args.owner);

        if(_parentDomain != address(0)){
            IAdminApp(address(domain)).grantRole(LibDomainManager.DEFAULT_ADMIN_ROLE, _parentDomain);
        }

        IAdminApp(address(domain)).grantRole(LibDomainManager.DEFAULT_ADMIN_ROLE, address(this));
        IAdminApp(address(domain)).grantRole(LibDomainManager.DEFAULT_ADMIN_ROLE, address(domain));
        IAdminApp(address(domain)).grantRole(LibDomainManager.DEFAULT_ADMIN_ROLE, address(msg.sender));
        emit DomainCreated(address(domain), _args.owner);
        return address(domain);
    }

    function getTotalDomains() external view returns (uint256) {
        return LibDomainManager.domainStorage().domains.length;
    }

    function getDomainAddress(uint256 _index) external view returns (address) {
        require(_index < LibDomainManager.domainStorage().domains.length, "Index out of bounds");
        return LibDomainManager.domainStorage().domains[_index];
    }
}
