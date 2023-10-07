// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { LibDomain } from "../../../libraries/LibDomain.sol";


library LibPackagerStore {
    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("packager.store.standard.storage");

    struct Storage {
        address[] packagers;
        - Private on roles
        - Features
        - Bundles (Features Kits or Apps)
        
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

contract PackagerStoreAppInit {    

    function init(address owner) external {
        LibPackagerStore.Storage storage ds = LibPackagerStore.domainStorage();
        ds.owner = msg.sender;
        // 1. Create each app dynamically
        ds.packagerManagerInstance = new PackagerManagerApp();
        ds.packagerRoutesInstance = new PackagerRoutesApp();
        ds.adminInstance = new OwnershipApp();
        ds.adminApp = new AdminApp();        
    }
}
///implement Domain Factory Multi App based on Diamond Facet Cut implementions https://eips.ethereum.org/EIPS/eip-2535
contract PackagerStoreApp is IPackagerStore, AdminApp {

}