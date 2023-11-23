// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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

}

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
   
}

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
} 
interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
} 
interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
} 
interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
} 
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
} 
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)





/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
} 
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)



/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
} 
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/ERC20.sol)







/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
} 


interface ITokenERC20 {
    function deposit() external payable;
    function approve(address spender, uint256 amount) external returns (bool);
    function burn(uint256 amount) external;
}

library LibDex {
    bytes32 constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("dex.standard.storage");
    

    struct Gateway {
        string name;
        address onlyReceiveSwapTokenAddres;     
        address owner; 
        bool enabled;                  
    }


    struct AirdropRule {
        uint256 balanceToken;
        uint256 factor;
    }    

    struct Router {
        string name;
        address router;
        bool enabled;
    }

    struct Quote {
        string routerName;
        address routerAddress;
        address tokenInAddress;
        uint256 tokenInAmount;
        uint256 receiveTokenAmount;
        uint256 deadline;
        uint256 slippageRate; 
        uint112 maxAvailableAmount;
        uint112 maxAvailableAmountReceiveToken;
    }

    struct Order {
        bool preOrder;
        uint256 amount;
        uint256 price;
        bool isSellOrder;
        bool isActive;
        address owner;
        uint256 burnTokensClose;
        address salesTokenAddress;
    }

    struct DexStorage{
        mapping(bytes32 => Gateway) gateways;
        mapping(bytes32 => mapping(address => Order[])) buyOrders;
        mapping(bytes32 => mapping(address => Order[])) sellOrders;
        mapping(bytes32 => mapping(address => uint256)) totalCapAcceptedToken;
        mapping(bytes32 => mapping(address => uint256)) totalShellOfferTokens;
        mapping(bytes32 => mapping(address => bool)) enabledMinSalesPriceTokenUnit;
        mapping(bytes32 => mapping(address => bool)) enabledMaxSalesPriceTokenUnit;        
        mapping(bytes32 => mapping(address => uint256)) minSalesPriceTokenUnit;
        mapping(bytes32 => mapping(address => uint256)) maxSalesPriceTokenUnit;
        mapping(bytes32 => mapping(address => uint256)) totalSoldTokens;
        mapping(bytes32 => mapping(address => uint256)) airdropAmount;
        mapping(bytes32 => mapping(address => mapping(address => uint256))) earnedTokens;
        mapping(bytes32 => mapping(address => mapping(address => uint256))) boughtTokens;
        mapping(bytes32 => mapping(address => uint256)) currentOrder;
        mapping(bytes32 => mapping(address => uint256)) tokensBurned;
        mapping(bytes32 => mapping(address => AirdropRule[])) airdropRules;
        mapping(bytes32 => mapping(address => address)) destination;     
        mapping(bytes32 => mapping(address => uint256)) preOrder;   
        mapping(bytes32 => Router[]) liquidityRouters;
        mapping(bytes32 => mapping(address => uint256)) liquidityRoutersIndex;       
        address wrappedNativeTokenAddress;
        bool initialized;
    }

    function domainStorage() internal pure returns (DexStorage storage ds) {
        bytes32 position = DOMAIN_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }     
}

contract DexApp  {

    modifier onlyOwnerGateway(bytes32 gatewayId) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        require(ds.gateways[gatewayId].owner == msg.sender, "Gateway owner access required");
        _;
    }

    modifier onlyOwnerOrder(bytes32 gatewayId, address salesTokenAddress, uint256 orderIndex ) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        require(ds.sellOrders[gatewayId][salesTokenAddress][orderIndex].owner == msg.sender, "Order owner access required");
        _;
    }    
    
  
    event GatewayCreated(bytes32 gatewayId, string gatewayName);
    event OrderCreated(address indexed owner, address salesTokenAddress, uint256 amount, uint256 price, bool isSellOrder);
    event OrderCanceled(address indexed owner, uint256 orderIndex);
    event OrderExecuted(address indexed buyer, address indexed seller, uint256 amount, uint256 price);
    event TokensClaimed(address indexed claimer, uint256 amount);
    event Log(uint256 message);
    function _initDex(address _nativeTokenAddress) public {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        require(!ds.initialized, "Initialization has already been executed.");
        ds.wrappedNativeTokenAddress = _nativeTokenAddress;

        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("_initDex()"))), LibDex.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("createGateway(string,address,LibDex.Router[])"))), LibDex.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("setTokenDestination(bytes32,address,address)"))), LibDex.DEFAULT_ADMIN_ROLE);


        ds.initialized = true;
        IReentrancyGuardApp(address(this)).enableDisabledDomainReentrancyGuard(true);
    }

    function getCurrentOrder(bytes32 gatewayId, address salesTokenAddress) public view returns (uint256){
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        return ds.currentOrder[gatewayId][salesTokenAddress];
    }

    function totalShellOfferTokens(bytes32 gatewayId, address salesTokenAddress) public view returns (uint256){
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        return ds.totalShellOfferTokens[gatewayId][salesTokenAddress];
    }

    function createGateway(string memory _gatewayName, address _onlyReceiveSwapTokenAddres, LibDex.Router[] memory _routers) public returns (bytes32) {
        bytes32 gatewayId = keccak256(abi.encodePacked(_gatewayName));
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];

        gateway.name = _gatewayName;
        gateway.onlyReceiveSwapTokenAddres = _onlyReceiveSwapTokenAddres;
        gateway.enabled = true;
        gateway.owner = msg.sender;

        for (uint256 i = 0; i < _routers.length; i++) {
            ds.liquidityRouters[gatewayId].push(_routers[i]);
            ds.liquidityRoutersIndex[gatewayId][_routers[i].router] = ds.liquidityRouters[gatewayId].length - 1;
        }

        emit GatewayCreated(gatewayId, _gatewayName);
        return gatewayId;
    }

    function gatewayExists(bytes32 gatewayId) external view returns (bool) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];        
        return gateway.enabled; 
    }

    function isPreOrder(bytes32 gatewayId, address salesTokenAddress) external view returns (bool) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        return ds.preOrder[gatewayId][salesTokenAddress] > 0;
    }

    function totalCapAcceptedToken(bytes32 gatewayId, address salesTokenAddress) external view returns (uint256) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        return ds.totalCapAcceptedToken[gatewayId][salesTokenAddress];
    }


    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    function addAirDropAmount(bytes32 gatewayId, address salesTokenAddress, uint256 amount) onlyOwnerGateway(gatewayId) external returns (uint256) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        ERC20(salesTokenAddress).transferFrom(msg.sender, address(this), amount);
        ds.airdropAmount[gatewayId][salesTokenAddress] += amount;
        return ds.airdropAmount[gatewayId][salesTokenAddress];
    }

    function removeAirDropAmount(bytes32 gatewayId, address salesTokenAddress, uint256 amount) onlyOwnerGateway(gatewayId) external returns (uint256) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        ERC20(salesTokenAddress).transferFrom(address(this), msg.sender, amount);
        ds.airdropAmount[gatewayId][salesTokenAddress] -= amount;
        return ds.airdropAmount[gatewayId][salesTokenAddress];
    }    

    function getMaxAvailableAmount(bytes32 gatewayId, address router, address tokenIn) external view returns (uint112 r0, uint112 r1) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];
        address pairAddress = IUniswapV2Factory(IUniswapV2Router02(ds.liquidityRouters[gatewayId][ds.liquidityRoutersIndex[gatewayId][address(router)]].router).factory()).getPair(gateway.onlyReceiveSwapTokenAddres, tokenIn);
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        return (reserve0, reserve1);
    }

    function setEnabledMinSalesPriceTokenUnit(bytes32 gatewayId, address salesTokenAddress, bool enabled) onlyOwnerGateway(gatewayId) external {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        ds.enabledMinSalesPriceTokenUnit[gatewayId][salesTokenAddress] = enabled;
    }
    function setEnabledMaxSalesPriceTokenUnit(bytes32 gatewayId, address salesTokenAddress, bool enabled) onlyOwnerGateway(gatewayId) external {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        ds.enabledMaxSalesPriceTokenUnit[gatewayId][salesTokenAddress] = enabled;
    }    

    function setMinSalesPriceTokenUnit(bytes32 gatewayId, address salesTokenAddress, uint256 price) onlyOwnerGateway(gatewayId) external  {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        ds.minSalesPriceTokenUnit[gatewayId][salesTokenAddress] = price;
    }

    function setMaxSalesPriceTokenUnit(bytes32 gatewayId, address salesTokenAddress, uint256 price) onlyOwnerGateway(gatewayId) external {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        ds.maxSalesPriceTokenUnit[gatewayId][salesTokenAddress] = price;
    }    

    function getMinSalesPriceTokenUnit(bytes32 gatewayId, address salesTokenAddress) external view returns (uint256) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        return ds.minSalesPriceTokenUnit[gatewayId][salesTokenAddress];
    }

    function getMaxSalesPriceTokenUnit(bytes32 gatewayId, address salesTokenAddress) external view returns (uint256) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        return ds.maxSalesPriceTokenUnit[gatewayId][salesTokenAddress];
    }    
        

    function getSwapQuote(bytes32 gatewayId, address tokenIn, uint256 tokenInAmount) external view returns (LibDex.Quote[] memory) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];        
        LibDex.Quote[] memory quotesTemp = new LibDex.Quote[](ds.liquidityRouters[gatewayId].length);
        uint256 count = 0;
        for (uint i = 0; i < ds.liquidityRouters[gatewayId].length; i++) {
            if (ds.liquidityRouters[gatewayId][i].enabled) {
                address[] memory path = new address[](2);
                path[0] = tokenIn;
                path[1] = gateway.onlyReceiveSwapTokenAddres;

                uint112 maxAvailableAmount = 0;
                uint112 maxAvailableAmountReceiveToken = 0;
                try this.getMaxAvailableAmount(gatewayId, ds.liquidityRouters[gatewayId][i].router, tokenIn) returns (uint112 reserve0, uint112 reserve1){
                    maxAvailableAmount = reserve1;
                    maxAvailableAmountReceiveToken = reserve0;
                } catch {
                    maxAvailableAmount = 0; 
                    maxAvailableAmountReceiveToken = 0;
                }

                uint256[] memory amountsOut;
                uint256 receiveTokenAmount;
                uint256 slippageRate;
                try IUniswapV2Router02(ds.liquidityRouters[gatewayId][i].router).getAmountsOut(tokenInAmount, path) returns (uint256[] memory result) {
                    amountsOut = result;
                    receiveTokenAmount = amountsOut[1] * 10**(ERC20(tokenIn).decimals() - ERC20(gateway.onlyReceiveSwapTokenAddres).decimals());

                    if (amountsOut[1] > receiveTokenAmount && amountsOut[1] != 0) {
                        slippageRate = ((amountsOut[1] - receiveTokenAmount) * 10**(ERC20(tokenIn).decimals() - ERC20(gateway.onlyReceiveSwapTokenAddres).decimals())) / amountsOut[1];
                    } else {
                        slippageRate = 0;
                    }

                } catch {
                    continue; 
                }

                LibDex.Quote memory quote = LibDex.Quote({
                    routerName: ds.liquidityRouters[gatewayId][i].name,
                    routerAddress: ds.liquidityRouters[gatewayId][i].router,
                    tokenInAddress: tokenIn,
                    tokenInAmount: tokenInAmount,
                    deadline: block.timestamp + 15 seconds,
                    receiveTokenAmount: receiveTokenAmount,
                    slippageRate: slippageRate,
                    maxAvailableAmount: maxAvailableAmount,
                    maxAvailableAmountReceiveToken: maxAvailableAmountReceiveToken
                });
                quotesTemp[count] = quote;
                count++;
            }
        }

        LibDex.Quote[] memory validQuotes = new LibDex.Quote[](count);
        for (uint i = 0; i < count; i++) {
            validQuotes[i] = quotesTemp[i];
        }

        return validQuotes;
    }

    function swapNativeToken(bytes32 gatewayId, address salesTokenAddress, address airdropOriginAddress) external payable  {
        this.swapTokenWithRouter(gatewayId, salesTokenAddress, address(0), address(0), msg.value, msg.sender, airdropOriginAddress);
    }   

    function swapNativeTokenWithRouter(bytes32 gatewayId, address salesTokenAddress, address quoteRouter, address airdropOriginAddress) external payable  {
        this.swapTokenWithRouter(gatewayId, salesTokenAddress, address(0), quoteRouter, msg.value, msg.sender, airdropOriginAddress);
    }

    function swapToken(bytes32 gatewayId, address salesTokenAddress, address tokenIn, uint256 amountIn, address toAddress, address airdropOriginAddress) external {
        this.swapTokenWithRouter(gatewayId, salesTokenAddress, tokenIn, address(0), amountIn, toAddress, airdropOriginAddress);
    }

    function processAirdrop(bytes32 gatewayId, address salesTokenAddress, address airdropOriginAddress, uint256 salesAmount) internal{
        if(airdropOriginAddress != address(0) && salesAmount  > 0) {
            LibDex.DexStorage storage ds = LibDex.domainStorage();            
            uint256 originBalance = ERC20(salesTokenAddress).balanceOf(airdropOriginAddress);
            uint256 airDropBase = this.getAirdropFactor(gatewayId, salesTokenAddress, originBalance);            
            if(airDropBase > 0){
                uint256 airdropAmount = salesAmount / airDropBase;
                airdropAmount = ds.airdropAmount[gatewayId][salesTokenAddress] >= airdropAmount ? airdropAmount : ds.airdropAmount[gatewayId][salesTokenAddress];
                if(airdropAmount > 0) {
                    IERC20(salesTokenAddress).approve(airdropOriginAddress, airdropAmount);
                    IERC20(salesTokenAddress).transferFrom(address(this), airdropOriginAddress, airdropAmount);
                    ds.airdropAmount[gatewayId][salesTokenAddress] -= airdropAmount;
                }
            }
        }
    }

    function swapTokenWithRouter(bytes32 gatewayId, address salesTokenAddress, address tokenIn, address router, uint256 amountIn, address toAddress, address airdropOriginAddress) external {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];

        require(amountIn > 0, "Need to send native token value to swap");
        require(ds.sellOrders[gatewayId][salesTokenAddress].length > 0, "There are no token offers at the moment, please try again later.");

        // Swap mechanism
        address swapRouter;
        LibDex.Quote[] memory quotes;

        uint256 remainingValueInAcceptedToken= 0;
        if (tokenIn != gateway.onlyReceiveSwapTokenAddres && ds.wrappedNativeTokenAddress != gateway.onlyReceiveSwapTokenAddres) {
            quotes = this.getSwapQuote(gatewayId, tokenIn == address(0) ? ds.wrappedNativeTokenAddress : tokenIn, amountIn);
            require(quotes.length > 0, "Unable to get quote from liquidity pool");

            if (router == address(0)) {
                swapRouter = quotes[0].routerAddress;
            } else {
                swapRouter = ds.liquidityRouters[gatewayId][ds.liquidityRoutersIndex[gatewayId][router]].router;
            }

            require(swapRouter != address(0), "There is no liquidity needed in the selected pool.");

            if (tokenIn == address(0)) {
                tokenIn = ds.wrappedNativeTokenAddress;
                ITokenERC20(ds.wrappedNativeTokenAddress).deposit{value: amountIn}();
            }
            else{
                ERC20(tokenIn).transferFrom(toAddress, address(this), amountIn);
            }
            ERC20(tokenIn).approve(swapRouter, amountIn);

            address[] memory path = new address[](2);
            path[0] = tokenIn;
            path[1] = gateway.onlyReceiveSwapTokenAddres;

            remainingValueInAcceptedToken= IUniswapV2Router02(swapRouter).swapExactTokensForTokens(
                amountIn,
                0,
                path,
                address(this),
                block.timestamp + 5 minutes
                )[1];
        } else {
            if (tokenIn == address(0)) {
                tokenIn = ds.wrappedNativeTokenAddress;
            }else{
                ERC20(tokenIn).transferFrom(toAddress, address(this), amountIn);
            }
            remainingValueInAcceptedToken= amountIn;
        }

        require(remainingValueInAcceptedToken> 0, "Balance inaccepted token not enough for the exchange.");
        uint256 diffTokenDecimals = ERC20(salesTokenAddress).decimals() - ERC20(gateway.onlyReceiveSwapTokenAddres).decimals();

        while (remainingValueInAcceptedToken> 0 && ds.sellOrders[gatewayId][salesTokenAddress].length > 0) {
            LibDex.Order storage order = ds.sellOrders[gatewayId][salesTokenAddress][0];
            uint256 orderValueInAcceptedToken= (order.amount / 10**ERC20(salesTokenAddress).decimals()) * (order.price / 10**diffTokenDecimals);
            if (orderValueInAcceptedToken<= remainingValueInAcceptedToken) {

                if(order.preOrder){     
                    if(ds.preOrder[gatewayId][salesTokenAddress] > 0){                    
                        ERC20(gateway.onlyReceiveSwapTokenAddres).transfer(ds.destination[gatewayId][salesTokenAddress],  orderValueInAcceptedToken);
                    }
                    else{
                        ERC20(gateway.onlyReceiveSwapTokenAddres).transfer(order.owner,  orderValueInAcceptedToken);
                    }
                }

                ds.totalCapAcceptedToken[gatewayId][salesTokenAddress] += orderValueInAcceptedToken;
                IERC20(order.salesTokenAddress).approve(toAddress, order.amount);
                IERC20(order.salesTokenAddress).transferFrom(address(this), toAddress, order.amount); 
                processAirdrop(gatewayId, salesTokenAddress, airdropOriginAddress, order.amount); 
                ds.totalSoldTokens[gatewayId][salesTokenAddress] += order.amount;
                ds.totalShellOfferTokens[gatewayId][salesTokenAddress] -= order.amount;
                remainingValueInAcceptedToken-= orderValueInAcceptedToken;
                if(order.preOrder){
                    ds.preOrder[gatewayId][salesTokenAddress]--;
                }
                if (order.burnTokensClose > 0) {
                    if (ds.preOrder[gatewayId][salesTokenAddress] == 0 && ds.airdropAmount[gatewayId][salesTokenAddress] > 0) {
                        order.burnTokensClose += ds.airdropAmount[gatewayId][salesTokenAddress];
                        ds.airdropAmount[gatewayId][salesTokenAddress] = 0;                        
                    }                   
                    ITokenERC20(order.salesTokenAddress).burn(order.burnTokensClose); 
                    ds.tokensBurned[gatewayId][salesTokenAddress] += order.burnTokensClose;
                    order.burnTokensClose = 0;
                }

                ds.currentOrder[gatewayId][salesTokenAddress]++;

                for (uint i = 0; i < ds.sellOrders[gatewayId][salesTokenAddress].length - 1; i++) {
                    ds.sellOrders[gatewayId][salesTokenAddress][i] = ds.sellOrders[gatewayId][salesTokenAddress][i + 1];
                }
                ds.sellOrders[gatewayId][salesTokenAddress].pop();
            } else {
                if (remainingValueInAcceptedToken> 0) { 
                    uint256 partialOrderAmount = (remainingValueInAcceptedToken / (order.price / 10**diffTokenDecimals)) * 10**ERC20(order.salesTokenAddress).decimals();
                    ds.totalCapAcceptedToken[gatewayId][salesTokenAddress] += remainingValueInAcceptedToken;
                    IERC20(order.salesTokenAddress).approve(toAddress, partialOrderAmount);
                    IERC20(order.salesTokenAddress).transferFrom(address(this), toAddress, partialOrderAmount);
                    processAirdrop(gatewayId, salesTokenAddress, airdropOriginAddress, partialOrderAmount); 
                    ds.totalSoldTokens[gatewayId][salesTokenAddress] += partialOrderAmount;
                    ds.totalShellOfferTokens[gatewayId][salesTokenAddress] -= partialOrderAmount;
                    order.amount -= partialOrderAmount;
                    if(order.preOrder){     
                        if(ds.preOrder[gatewayId][salesTokenAddress] > 0){                       
                            ERC20(gateway.onlyReceiveSwapTokenAddres).transfer(ds.destination[gatewayId][salesTokenAddress],  remainingValueInAcceptedToken);                         
                        }
                        else{  
                            ERC20(gateway.onlyReceiveSwapTokenAddres).transfer(order.owner,  remainingValueInAcceptedToken);     
                        }
                    }                    
                }
                remainingValueInAcceptedToken= 0;
            }           
        }

        if (remainingValueInAcceptedToken > 0) {
            ERC20(gateway.onlyReceiveSwapTokenAddres).transfer(toAddress, remainingValueInAcceptedToken);            
        }

        if (ds.preOrder[gatewayId][salesTokenAddress] == 0) {
            IAdminApp(address(this)).removeFunctionRole(bytes4(keccak256(bytes("transfer(address,uint256)"))), true);  
            IAdminApp(address(this)).removeFunctionRole(bytes4(keccak256(bytes("transferFrom(address,address,uint256)"))), true); 
            IAdminApp(address(this)).removeFunctionRole(bytes4(keccak256(bytes("approve(address,uint256)"))), true); 
            IAdminApp(address(this)).removeFunctionRole(bytes4(keccak256(bytes("burn(uint256)"))), true); 
            IAdminApp(address(this)).removeFunctionRole(bytes4(keccak256(bytes("burnFrom(address,uint256)"))), true);                         
            IAdminApp(address(this)).removeFunctionRole(bytes4(keccak256(bytes("createPurchOrder(bytes32,address,bool,uint256,uint256,uint256)"))), true);                          
        }          
    }

    function getAirdropBalance(bytes32 gatewayId, address salesTokenAddress) external view returns (uint256) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        return ds.airdropAmount[gatewayId][salesTokenAddress]; 
    }

    function getAirdropFactor(bytes32 gatewayId, address salesTokenAddress, uint256 balance) external view returns (uint256) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        LibDex.AirdropRule[] memory rules = ds.airdropRules[gatewayId][salesTokenAddress];

        uint256 currentfactor = 0;
        for (uint256 i = 0; i < rules.length; i++) {
            if (balance >= rules[i].balanceToken) {
                currentfactor = rules[i].factor;
            }
        }
        return currentfactor; 
    }

    function setAirdropFactor(bytes32 gatewayId, address salesTokenAddress, uint256 balanceToken, uint256 factor) onlyOwnerGateway(gatewayId) external {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        LibDex.AirdropRule[] storage rules = ds.airdropRules[gatewayId][salesTokenAddress];

        bool updated;
        for (uint256 i = 0; i < rules.length && !updated; i++) {
            if (balanceToken == rules[i].balanceToken) {
                rules[i].factor = factor;
                updated = true;
            }
        }
        if(!updated){
            LibDex.AirdropRule memory newRule = LibDex.AirdropRule({
                balanceToken: balanceToken,
                factor: factor
            });
            rules.push(newRule);
        }
    }

    function setTokenDestination(bytes32 gatewayId, address salesTokenAddress, address payable _destination) onlyOwnerGateway(gatewayId) public {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        ds.destination[gatewayId][salesTokenAddress] = _destination;
    }

    function createPurchOrder(bytes32 gatewayId, address salesTokenAddress, bool preOrder, uint256 amount, uint256 price, uint256 tokenBurnedOnClose) public  {
        LibDex.Order memory order = LibDex.Order({
            preOrder: preOrder,
            amount: amount,
            price: price,
            isSellOrder: true,
            isActive: true,
            owner: msg.sender,
            burnTokensClose: tokenBurnedOnClose,
            salesTokenAddress: salesTokenAddress
        });

        LibDex.DexStorage storage ds = LibDex.domainStorage();  
        if(!order.preOrder && ds.preOrder[gatewayId][salesTokenAddress] == 0 && ds.enabledMinSalesPriceTokenUnit[gatewayId][salesTokenAddress]){
            require(price >= ds.minSalesPriceTokenUnit[gatewayId][salesTokenAddress], "The unit selling price must be greater than or equal to the minimum selling price");
        }

        if(!order.preOrder && ds.preOrder[gatewayId][salesTokenAddress] == 0 && ds.enabledMaxSalesPriceTokenUnit[gatewayId][salesTokenAddress]){
            require(price >= ds.maxSalesPriceTokenUnit[gatewayId][salesTokenAddress], "The unit selling price must be less than or equal to the maximum selling price");
        }        

        if(order.preOrder){
            require(ds.gateways[gatewayId].owner == msg.sender, "Only gateway owner create pre orders");
        }else{
            require(ds.preOrder[gatewayId][salesTokenAddress] == 0, "Cannot create orders until all cycles pre-seed are completed");
        }

        ERC20(salesTokenAddress).transferFrom(msg.sender, address(this), amount+tokenBurnedOnClose);

        if(preOrder){
            ds.preOrder[gatewayId][salesTokenAddress]++;
            IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("transfer(address,uint256)"))), LibDex.DEFAULT_ADMIN_ROLE);    
            IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("transferFrom(address,address,uint256)"))), LibDex.DEFAULT_ADMIN_ROLE);  
            IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("approve(address,uint256)"))), LibDex.DEFAULT_ADMIN_ROLE);  
            IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("burn(uint256)"))), LibDex.DEFAULT_ADMIN_ROLE);  
            IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("burnFrom(address,uint256)"))), LibDex.DEFAULT_ADMIN_ROLE);       
            IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("createPurchOrder(bytes32,address,bool,uint256,uint256,uint256)"))), LibDex.DEFAULT_ADMIN_ROLE);  
        }

        bool inserted = false;
        LibDex.Order[] memory shellOrders = ds.sellOrders[gatewayId][salesTokenAddress];
        for (uint i = 0; i < shellOrders.length; i++) {
            if (ds.sellOrders[gatewayId][salesTokenAddress][i].price > price) {
                ds.sellOrders[gatewayId][salesTokenAddress].push();
                LibDex.Order[] memory _shellOrders = ds.sellOrders[gatewayId][salesTokenAddress];
                for (uint j = _shellOrders.length - 1; j > i; j--) {
                    ds.sellOrders[gatewayId][salesTokenAddress][j] = ds.sellOrders[gatewayId][salesTokenAddress][j - 1];
                }
                ds.sellOrders[gatewayId][salesTokenAddress][i] = order;
                inserted = true;
                break;
            }
        }

        if (!inserted) {
            ds.sellOrders[gatewayId][salesTokenAddress].push(order);
        }

        ds.totalShellOfferTokens[gatewayId][salesTokenAddress] += amount;

        emit OrderCreated(order.owner, salesTokenAddress, amount, price, true); 
    }

    function cancelOrder(bytes32 gatewayId, address salesTokenAddress, uint256 orderIndex, bool isSellOrder) public {
        LibDex.DexStorage storage ds = LibDex.domainStorage();  
        LibDex.Order storage order = isSellOrder ? ds.sellOrders[gatewayId][salesTokenAddress][orderIndex] : ds.buyOrders[gatewayId][salesTokenAddress][orderIndex];
        require(order.owner == msg.sender, "Only the owner can cancel the order");
        if (order.isSellOrder) {
            ERC20(order.salesTokenAddress).transfer(msg.sender, order.amount+order.burnTokensClose);
        }

        if(order.preOrder){
            ds.preOrder[gatewayId][salesTokenAddress]--;
        }
        if (order.isSellOrder) {
            for (uint i = orderIndex; i < ds.sellOrders[gatewayId][salesTokenAddress].length - 1; i++) {
                ds.sellOrders[gatewayId][salesTokenAddress][i] = ds.sellOrders[gatewayId][salesTokenAddress][i + 1];
            }
            ds.sellOrders[gatewayId][salesTokenAddress].pop();
        } else {
            for (uint i = orderIndex; i < ds.buyOrders[gatewayId][salesTokenAddress].length - 1; i++) {
                ds.buyOrders[gatewayId][salesTokenAddress][i] = ds.buyOrders[gatewayId][salesTokenAddress][i + 1];
            }
            ds.buyOrders[gatewayId][salesTokenAddress].pop();
        }

        emit OrderCanceled(msg.sender, orderIndex);
    }

    function getSalesOrder(bytes32 gatewayId, address salesTokenAddress) public  view returns (LibDex.Order memory){
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        return ds.sellOrders[gatewayId][salesTokenAddress][0];
    }

    function getActiveBuyOrders(bytes32 gatewayId, address salesTokenAddress) public view returns (LibDex.Order[] memory) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        uint256 activeCount = 0;
        for (uint256 i = 0; i < ds.buyOrders[gatewayId][salesTokenAddress].length; i++) {
            if (ds.buyOrders[gatewayId][salesTokenAddress][i].isActive) {
                activeCount++;
            }
        }
        
        LibDex.Order[] memory activeOrders = new LibDex.Order[](activeCount);
        uint256 j = 0;
        for (uint256 i = 0; i < ds.buyOrders[gatewayId][salesTokenAddress].length; i++) {
            if(ds.buyOrders[gatewayId][salesTokenAddress][i].isActive) {
                activeOrders[j] = ds.buyOrders[gatewayId][salesTokenAddress][i];
                j++;
            }
        }
        return activeOrders;
    }

    function getActiveSellOrders(bytes32 gatewayId, address salesTokenAddress) public view returns (LibDex.Order[] memory) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        uint256 activeCount = 0;
        for (uint256 i = 0; i < ds.sellOrders[gatewayId][salesTokenAddress].length; i++) {
            if (ds.sellOrders[gatewayId][salesTokenAddress][i].isActive) {
                activeCount++;
            }
        }
        
        LibDex.Order[] memory activeOrders = new LibDex.Order[](activeCount);
        uint256 j = 0;
        for (uint256 i = 0; i < ds.sellOrders[gatewayId][salesTokenAddress].length; i++) {
            if (ds.sellOrders[gatewayId][salesTokenAddress][i].isActive) {
                activeOrders[j] = ds.sellOrders[gatewayId][salesTokenAddress][i];
                j++;
            }
        }
        return activeOrders;
    }
}