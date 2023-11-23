pragma solidity ^0.8.17;\n\n// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)



/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}\n\n// SPDX-License-Identifier: MIT


struct roleAccount {
    string name;
    bytes32 role;
    address account;
}
interface IAdminApp {
    function hasRole(bytes32 role, address account) external view returns (bool);

    function grantRole(bytes32 role, address account) external;

    function getRoleHash32(string memory str) external pure returns (bytes32);
    function getRoleHash4(string memory str) external pure returns (bytes4);
    function revokeRole(bytes32 role, address account) external;

    function renounceRole(bytes32 role) external;

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external;

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function setFunctionRole(bytes4 functionSelector, bytes32 role) external;

    function removeFunctionRole(bytes4 functionSelector, bool noError) external;

    function pauseDomain() external;

    function unpauseDomain() external;

    function pauseFeatures(address[] memory _featureAddress) external;

    function unpauseFeatures(address[] memory _featureAddress) external;

}\n\n// SPDX-License-Identifier: MIT


interface IReentrancyGuardApp {


    function enableDisabledDomainReentrancyGuard(bool status) external;

    function enableDisabledFeatureReentrancyGuard(address feature, bool status) external;

    function enableDisabledFunctionReentrancyGuard(bytes4 functionSelector, bool status) external;

    function enableDisabledSenderReentrancyGuard(bool status) external;

    function isDomainReentrancyGuardEnabled() external view returns (bool);

    function isFeatureReentrancyGuardEnabled(address feature) external view returns (bool);

    function isFunctionReentrancyGuardEnabled(bytes4 functionSelector) external view returns (bool);

    function isSenderReentrancyGuardEnabled() external view returns (bool);    

    function getDomainLock() external view returns (uint256);

    function getFeatureLock(address feature) external view returns (uint256);

    function getFunctionLock(bytes4 functionSelector) external view returns (uint256);

    function getSenderLock(address sender) external view returns (uint256);    
   
}\n\n// SPDX-License-Identifier: MIT






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