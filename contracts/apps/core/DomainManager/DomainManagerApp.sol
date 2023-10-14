// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Domain, DomainArgs, IFeatureManager } from "../../../Domain.sol";
import { IAdminApp } from "../AccessControl/AdminApp.sol";

library LibDomainManager {
    bytes32 constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("domain.manager.standard.storage");

    struct DomainStorage{
        address owner;
        address[] domains;
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
    function createDomain(address _parentDomain, string memory _domainName, IFeatureManager.Feature[] memory _features, DomainArgs memory _args) public returns (address) {
        LibDomainManager.DomainStorage storage ds = LibDomainManager.domainStorage();
        _args.owner = _args.owner == address(0) ? msg.sender : _args.owner;
        
        Domain domain = new Domain(_parentDomain, _domainName, _features, _args);
        ds.domains.push(address(domain));

        // Grant the DEFAULT_ADMIN_ROLE to the owner
        IAdminApp(address(domain)).grantRole(LibDomainManager.DEFAULT_ADMIN_ROLE, _args.owner);

        // Grant the DEFAULT_ADMIN_ROLE to the Domain itself
        IAdminApp(address(domain)).grantRole(LibDomainManager.DEFAULT_ADMIN_ROLE, address(this));

        IAdminApp(address(domain)).grantRole(LibDomainManager.DEFAULT_ADMIN_ROLE, address(domain));

        emit DomainCreated(address(domain), _args.owner);
        return address(domain);
    }

    // Retrieve the total number of Domains created by this factory.
    function getTotalDomains() external view returns (uint256) {
        return LibDomainManager.domainStorage().domains.length;
    }

    // Retrieve the address of a specific Domain.
    function getDomainAddress(uint256 _index) external view returns (address) {
        require(_index < LibDomainManager.domainStorage().domains.length, "Index out of bounds");
        return LibDomainManager.domainStorage().domains[_index];
    }
}
