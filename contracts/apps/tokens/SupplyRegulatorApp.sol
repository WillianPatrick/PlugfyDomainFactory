// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibBalances } from "../../libraries/ERC20/LibBalances.sol";
import { ERC20App } from "../../libraries/tokens/ERC20App.sol";

contract SupplyRegulatorApp {
    
    function mint(address _account, uint256 _amount) external {
        ERC20App.enforceIsTokenAdmin();
        LibBalances.mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external {
        ERC20App.enforceIsTokenAdmin();
        LibBalances.burn(_account, _amount);
    }
}