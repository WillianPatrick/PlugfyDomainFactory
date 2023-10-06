// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { Domain, DomainArgs } from "./Domain.sol";
import { IDomain } from "./interfaces/IDomain.sol";
import { IAppManager } from "./interfaces/IAppManager.sol";
import { AppManagerApp } from "./apps/AppManagerApp.sol";
import { AppManagerViewerApp } from "./apps/AppManagerViewerApp.sol";
import { OwnershipApp } from "./apps/OwnershipApp.sol";
import { AdminApp, AccessControlApp } from "./apps/AdminApp.sol";


///implement Domain Factory Multi App based on Diamond Facet Cut implementions https://eips.ethereum.org/EIPS/eip-2535
contract DomainFactory {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    event DomainCreated(address indexed domainAddress, address indexed owner);
    address private _owner;
    address[] public domains;
    AppManagerApp public appManagerApp;
    AppManagerViewerApp public domainLoupeApp;
    OwnershipApp public ownershipApp;
    AdminApp public adminApp;

    modifier onlyOwner() {
        require(msg.sender == _owner, "Not contract owner");
        _;
    }

    constructor() {
        _owner = msg.sender;
        // 1. Create each app dynamically
        appManagerApp = new AppManagerApp();
        domainLoupeApp = new AppManagerViewerApp();
        ownershipApp = new OwnershipApp();
        adminApp = new AdminApp();
    }

    function createDomain(DomainArgs memory _args) public onlyOwner returns (address) {
        _args.owner = _args.owner == address(0) ? msg.sender : _args.owner;
        
        // 2. Configure the Domain with the basic functionalities of the apps
        IAppManager.App[] memory apps = new IAppManager.App[](5);

        // AppManagerApp selectors
        bytes4[] memory appManagerSelectors = new bytes4[](1);
        appManagerSelectors[0] = IAppManager.appManager.selector;
        apps[0] = IDomain.App({
            appAddress: address(appManagerApp),
            action: IDomain.AppManagerAction.Add,
            functionSelectors: appManagerSelectors
        });

        // AppManagerViewerApp selectors
        bytes4[] memory domainLoupeSelectors = new bytes4[](4);
        domainLoupeSelectors[0] = AppManagerViewerApp.apps.selector;
        domainLoupeSelectors[1] = AppManagerViewerApp.appFunctionSelectors.selector;
        domainLoupeSelectors[2] = AppManagerViewerApp.appAddresses.selector;
        domainLoupeSelectors[3] = AppManagerViewerApp.appAddress.selector;
        apps[1] = IDomain.App({
            appAddress: address(domainLoupeApp),
            action: IDomain.AppManagerAction.Add,
            functionSelectors: domainLoupeSelectors
        });

        // OwnershipApp selectors
        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = OwnershipApp.transferOwnership.selector;
        ownershipSelectors[1] = OwnershipApp.owner.selector;
        apps[2] = IDomain.App({
            appAddress: address(ownershipApp),
            action: IDomain.AppManagerAction.Add,
            functionSelectors: ownershipSelectors
        });

        // AdminApp selectors
        bytes4[] memory adminSelectors = new bytes4[](4);
        adminSelectors[0] = AdminApp.grantRole.selector;
        adminSelectors[1] = AdminApp.revokeRole.selector;
        adminSelectors[2] = AdminApp.renounceRole.selector;
        adminSelectors[3] = AdminApp.setRoleAdmin.selector;
        apps[3] = IDomain.App({
            appAddress: address(adminApp),
            action: IDomain.AppManagerAction.Add,
            functionSelectors: adminSelectors
        });

        // AccessControlApp selectors
        bytes4[] memory accessControlSelectors = new bytes4[](5);  // Updated size to 5
        accessControlSelectors[0] = AccessControlApp.hasRole.selector;
        accessControlSelectors[1] = AccessControlApp.getRoleAdmin.selector;
        accessControlSelectors[2] = AccessControlApp.setFunctionRole.selector;
        accessControlSelectors[3] = AccessControlApp.removeFunctionRole.selector; // Added selector
        apps[4] = IDomain.App({
            appAddress: address(adminApp),
            action: IDomain.AppManagerAction.Add,
            functionSelectors: accessControlSelectors
        });



        // 3. Register the functionalities in the newly created Domain
        Domain domain = new Domain(apps, _args);
        domains.push(address(domain));

        // Grant the DEFAULT_ADMIN_ROLE to the owner
        AdminApp(address(domain)).grantRole(DEFAULT_ADMIN_ROLE, _args.owner);

        // Grant the DEFAULT_ADMIN_ROLE to the Domain itself
        AdminApp(address(domain)).grantRole(DEFAULT_ADMIN_ROLE, address(this));

        AdminApp(address(domain)).grantRole(DEFAULT_ADMIN_ROLE, address(domain));

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
