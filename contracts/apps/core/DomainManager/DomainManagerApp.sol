// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { LibDomain } from "../../../libraries/LibDomain.sol";
import { Domain, DomainArgs } from "../../../Domain.sol";
import { IDomainManager } from "./IDomainManager.sol";
import { AdminApp } from "../AccessControl/AdminApp.sol";
import { OwnershipApp } from "../AccessControl/OwnershipApp.sol";
import { PackagerManagerApp } from "../PackagerManager/PackagerManagerApp.sol";
import { PackagerRoutesApp } from "../PackagerManager/PackagerRoutesApp.sol";


library LibDomainManager {
    bytes32 constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("domain.manager.standard.storage");

    struct Storage {
        address owner;
        address[] domains;
        
        PackagerManagerApp packagerManagerInstance;
        PackagerRoutesApp packagerRoutesInstance;
        AdminApp adminInstance;
        OwnershipApp ownershipInstance;
    }

    function domainStorage() internal pure returns (Storage storage ds) {
        bytes32 position = DOMAIN_STORAGE_POSITION;
        assembly {
            ds.slot := position
        } 
    }
}

contract DomainManagerAppInit {    

    function init(address owner) external {
        LibDomainManager.Storage storage ds = LibDomainManager.domainStorage();
        ds.owner = msg.sender;
        // 1. Create each app dynamically
        ds.packagerManagerInstance = new PackagerManagerApp();
        ds.packagerRoutesInstance = new PackagerRoutesApp();
        ds.adminInstance = new OwnershipApp();
        ds.adminApp = new AdminApp();        
    }
}
///implement Domain Factory Multi App based on Diamond Facet Cut implementions https://eips.ethereum.org/EIPS/eip-2535
contract DomainManagerApp is IDomainManager, AdminApp {

    event DomainCreated(address indexed domainAddress, address indexed owner);

    modifier onlyOwner() {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        require(msg.sender == ds.owner, "Not contract owner");
        _;
    }

    function createDomain(DomainArgs memory _args) public onlyOwner returns (address) {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();
        _args.owner = _args.owner == address(0) ? msg.sender : _args.owner;
        
        // 2. Configure the Domain with the basic functionalities of the apps
        PackagerManagerApp.Packager[] memory apps = new PackagerManagerApp.Packager[](5);

        // PackagerManagerApp selectors
        bytes4[] memory packManagerSelectors = new bytes4[](1);
        packManagerSelectors[0] = PackagerManagerApp.packagerManager.selector;
        apps[0] = PackagerManagerApp.Packager({
            appAddress: address(ds.packagerManagerInstance),
            action: PackagerManagerApp.PackagerManagerAction.Add,
            functionSelectors: packManagerSelectors
        });

        // PackagerManagerViewerApp selectors
        bytes4[] memory domainLoupeSelectors = new bytes4[](4);
        domainLoupeSelectors[0] = PackagerManagerViewerApp.apps.selector;
        domainLoupeSelectors[1] = PackagerManagerViewerApp.appFunctionSelectors.selector;
        domainLoupeSelectors[2] = PackagerManagerViewerApp.appAddresses.selector;
        domainLoupeSelectors[3] = PackagerManagerViewerApp.appAddress.selector;
        apps[1] = IPackagerManager.App({
            appAddress: address(domainLoupeApp),
            action: IPackagerManager.PackagerManagerAction.Add,
            functionSelectors: domainLoupeSelectors
        });

        // OwnershipApp selectors
        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = OwnershipApp.transferOwnership.selector;
        ownershipSelectors[1] = OwnershipApp.owner.selector;
        apps[2] = IPackagerManager.App({
            appAddress: address(ownershipApp),
            action: IPackagerManager.PackagerManagerAction.Add,
            functionSelectors: ownershipSelectors
        });

        // AdminApp selectors
        bytes4[] memory adminSelectors = new bytes4[](4);
        adminSelectors[0] = AdminApp.grantRole.selector;
        adminSelectors[1] = AdminApp.revokeRole.selector;
        adminSelectors[2] = AdminApp.renounceRole.selector;
        adminSelectors[3] = AdminApp.setRoleAdmin.selector;
        apps[3] = IPackagerManager.App({
            appAddress: address(adminApp),
            action: IPackagerManager.PackagerManagerAction.Add,
            functionSelectors: adminSelectors
        });

        // AccessControlApp selectors
        bytes4[] memory accessControlSelectors = new bytes4[](5);  // Updated size to 5
        accessControlSelectors[0] = AccessControlApp.hasRole.selector;
        accessControlSelectors[1] = AccessControlApp.getRoleAdmin.selector;
        accessControlSelectors[2] = AccessControlApp.setFunctionRole.selector;
        accessControlSelectors[3] = AccessControlApp.removeFunctionRole.selector; // Added selector
        apps[4] = IPackagerManager.App({
            appAddress: address(adminApp),
            action: IPackagerManager.PackagerManagerAction.Add,
            functionSelectors: accessControlSelectors
        });



        // 3. Register the functionalities in the newly created Domain
        Domain domain = new Domain(apps, _args);
        domains.push(address(domain));

        // Grant the DEFAULT_ADMIN_ROLE to the owner
        AdminApp(address(domain)).grantRole(LibDomainManager.DEFAULT_ADMIN_ROLE, _args.owner);

        // Grant the DEFAULT_ADMIN_ROLE to the Domain itself
        AdminApp(address(domain)).grantRole(LibDomainManager.DEFAULT_ADMIN_ROLE, address(this));

        AdminApp(address(domain)).grantRole(LibDomainManager.DEFAULT_ADMIN_ROLE, address(domain));

        emit DomainCreated(address(domain), _args.owner);
        return address(domain);
    }

    // Retrieve the total number of Domains created by this factory.
    function getTotalDomains() external view returns (uint256) {
        return domains.length;
    }

    // Retrieve the address of a specific Domain.
    function getDomainAddress(uint256 _index) external view returns (address) {
        require(_index < domains.length, "Index out of bounds");
        return domains[_index];
    }
}
