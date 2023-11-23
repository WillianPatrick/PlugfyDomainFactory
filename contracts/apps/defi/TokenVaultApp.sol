// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../core/AccessControl/IAdminApp.sol";
import "../core/AccessControl/IReentrancyGuardApp.sol";

library LibVault {
    bytes32 constant VAULT_STORAGE_POSITION = keccak256("vault.feature.storage");

    struct Deposit {
        address depositor;
        address tokenAddress;
        uint256 amount;
    }

    struct VaultStorage {
        mapping(address => mapping(address => uint256)) deposits; // depositor => tokenAddress => amount
        bool initialized;
    }

    function vaultStorage() internal pure returns (VaultStorage storage vs) {
        bytes32 position = VAULT_STORAGE_POSITION;
        assembly {
            vs.slot := position
        }
    }
}

contract TokenVaultApp {
    using LibVault for LibVault.VaultStorage;

    bytes32 constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    bytes32 constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");
    bytes32 constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

    event Deposited(address indexed depositor, address indexed tokenAddress, uint256 amount);
    event Withdrawn(address indexed withdrawer, address indexed tokenAddress, uint256 amount);
    event AdminWithdrawn(address indexed admin, address indexed tokenAddress, uint256 amount);

    function _initTokenVaultApp() public {
        require(!LibVault.vaultStorage().initialized, "Initialization has already been executed.");

        IAdminApp(address(this)).setRoleAdmin(DEPOSITOR_ROLE, DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setRoleAdmin(WITHDRAWER_ROLE, DEFAULT_ADMIN_ROLE);

        IAdminApp(address(this)).grantRole(DEPOSITOR_ROLE, msg.sender);
        IAdminApp(address(this)).grantRole(WITHDRAWER_ROLE, msg.sender);

        // Protecting contract functions from reentrancy attacks
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("deposit(address,uint256)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("withdraw(address,uint256)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("adminWithdraw(address,uint256,address)"))), true);

        LibVault.vaultStorage().initialized = true;
    }

    function deposit(address tokenAddress, uint256 amount) public {
        IERC20 token = IERC20(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        LibVault.VaultStorage storage vs = LibVault.vaultStorage();
        vs.deposits[msg.sender][tokenAddress] += amount;

        emit Deposited(msg.sender, tokenAddress, amount);
    }

    function withdraw(address tokenAddress, uint256 amount) public {
        LibVault.VaultStorage storage vs = LibVault.vaultStorage();
        require(vs.deposits[msg.sender][tokenAddress] >= amount, "Insufficient balance");

        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(msg.sender, amount), "Transfer failed");

        vs.deposits[msg.sender][tokenAddress] -= amount;

        emit Withdrawn(msg.sender, tokenAddress, amount);
    }

    function adminWithdraw(address tokenAddress, uint256 amount, address destination) public {
        require(IAdminApp(address(this)).hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Only admin can perform this action");

        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(destination, amount), "Transfer failed");

        emit AdminWithdrawn(msg.sender, tokenAddress, amount);
    }

    function getBalance(address depositor, address tokenAddress) public view returns (uint256) {
        return LibVault.vaultStorage().deposits[depositor][tokenAddress];
    }
}
