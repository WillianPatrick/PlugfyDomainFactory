// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibERC20Constants } from "../../libraries/ERC20/LibConstants.sol";
import "../base/BaseConstantsApp.sol";

contract TokenERC20App  {

    function name() external view returns (string memory) {
        LibERC20Constants.ConstantsStates storage ds = LibERC20Constants.domainStorage();
        return ds.name;
    }

    function symbol() external view returns (string memory) {
        LibERC20Constants.ConstantsStates storage ds = LibERC20Constants.domainStorage();
        return ds.symbol;
    }

    function decimals() external view returns (uint8) {
        LibERC20Constants.ConstantsStates storage ds = LibERC20Constants.domainStorage();
        return ds.decimals;
    }

    function transferAdminship(address _newAdmin) external {
        LibERC20Constants.enforceIsTokenAdmin();
        LibERC20Constants.setTokenAdmin(_newAdmin);
    }     

}
