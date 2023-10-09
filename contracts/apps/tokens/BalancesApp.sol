// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibBalances } from "../../libraries/ERC20/LibBalances.sol";

library LibBalances {
    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("token.balances");

    event Transfer(address indexed from, address indexed to, uint256 value);

    struct BalancesStates {
        mapping(address => uint256) balances;
        uint256 totalSupply;
    }

    function domainStorage() internal pure returns (BalancesStates storage ds) {
        bytes32 position = DOMAIN_STORAGE_POSITION;
        assembly {
            ds.slot := position
        } 
    }

    function transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        BalancesStates storage ds = domainStorage();
        require(from != address(0), "transfer from the zero address");
        require(to != address(0), "transfer to the zero address");

        uint256 fromBalance = ds.balances[from];
        require(fromBalance >= amount, "transfer amount exceeds balance");
        unchecked {
            ds.balances[from] = fromBalance - amount;
            ds.balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function mint(address account, uint256 amount) internal {
        BalancesStates storage ds = domainStorage();
        require(account != address(0), "mint to the zero address");
        ds.totalSupply += amount;
        unchecked {
            ds.balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function burn(address account, uint256 amount) internal {
        BalancesStates storage ds = domainStorage();
        require(account != address(0), "burn from the zero address");
        uint256 accountBalance = ds.balances[account];
        require(accountBalance >= amount, "burn amount exceeds balance");
        unchecked {
            ds.balances[account] = accountBalance - amount;
            ds.totalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
    }
}

contract BalancesApp {

    function totalSupply() external view returns (uint256) {
        LibBalances.BalancesStates storage ds = LibBalances.domainStorage();
        return ds.totalSupply;
    }

    function balanceOf(address _account) external view returns (uint256) {
        LibBalances.BalancesStates storage ds = LibBalances.domainStorage();
        return ds.balances[_account];
    }

    function transfer(address _to, uint256 _amount) external returns (bool) {
        address owner = msg.sender;
        LibBalances.transfer(owner, _to, _amount);
        return true;
    }
}
