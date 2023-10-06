// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibDomain } from "../libraries/LibDomain.sol";

contract OwnershipApp {
    function transferOwnership(address _newOwner) external {
        LibDomain.enforceIsContractOwner();
        LibDomain.setContractOwner(_newOwner);
    }

    function owner() external view returns (address owner_) {
        owner_ = LibDomain.contractOwner();
    }
}
