// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import { LibDomain } from "../../libraries/LibDomain.sol";

error NotTokenAdmin();


library LibTokenERC20 {
    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("token.constants");

    event AdminshipTransferred(address indexed previousAdmin, address indexed newAdmin);

    struct TokenData {
        string name;
        string symbol;
        uint8 decimals;

        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        uint256 totalSupply;
        address owner;
        mapping(bytes32 => mapping(address => bool)) roles;
        bool paused;
    }    

    function domainStorage() internal pure returns (LibTokenERC20.TokenData storage ds) {
        bytes32 position = DOMAIN_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

}


contract ERC20App {
    
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function _init(string memory _name, string memory _symbol, uint256 _totalSupply, uint8 _decimals) public {
        LibTokenERC20.TokenData storage ds = LibTokenERC20.domainStorage();
        ds.name = _name;
        ds.symbol = _symbol;
        ds.decimals = uint8(_decimals);
        ds.balances[msg.sender] = _totalSupply * 10 ** _decimals;
        ds.totalSupply = _totalSupply * 10 ** _decimals;
    }

    function name() public view  returns (string memory)  {
        LibTokenERC20.TokenData storage ds = LibTokenERC20.domainStorage();
        return ds.name;
    }

    function symbol() public view  returns (string memory) {
        LibTokenERC20.TokenData storage ds = LibTokenERC20.domainStorage();
        return ds.symbol;
    }

    function decimals() public view  returns (uint8) {
        LibTokenERC20.TokenData storage ds = LibTokenERC20.domainStorage();
        return ds.decimals;
    }

    function balanceOf(address account) public view  returns (uint256) {
        LibTokenERC20.TokenData storage ds = LibTokenERC20.domainStorage();
        return ds.balances[account];
    }

    function totalSupply() public view  returns (uint256) {
        LibTokenERC20.TokenData storage ds = LibTokenERC20.domainStorage();
        return ds.totalSupply;
    }

    function transfer(address recipient, uint256 amount)  public virtual{
        _transfer(msg.sender, recipient, amount);
    }

    function approve(address spender, uint256 amount) public virtual  returns (bool){
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual  returns (bool) {
        LibTokenERC20.TokenData storage ds = LibTokenERC20.domainStorage();
        uint256 currentAllowance = ds.allowances[sender][msg.sender];
        require(currentAllowance >= amount, "transfer amount exceeds allowance");
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, currentAllowance - amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) public virtual {
        require(sender != address(0), "transfer from the zero address");
        require(recipient != address(0), "transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        LibTokenERC20.TokenData storage ds = LibTokenERC20.domainStorage();
        require(ds.balances[sender] >= amount, "transfer amount exceeds balance");
        ds.balances[sender] = ds.balances[sender] - amount;
        ds.balances[recipient] = ds.balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "approve from the zero address");
        require(spender != address(0), "approve to the zero address");
        LibTokenERC20.TokenData storage ds = LibTokenERC20.domainStorage();
        require(ds.balances[owner] >= amount, "transfer amount exceeds balance");
        ds.allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function burn(uint256 amount) public virtual  {
        LibTokenERC20.TokenData storage ds = LibTokenERC20.domainStorage();
        require(ds.balances[msg.sender] >= amount, "burn amount exceeds balance");
        ds.balances[msg.sender] = ds.balances[msg.sender] - amount;
        ds.totalSupply = ds.totalSupply - amount;
        emit Transfer(msg.sender, address(0), amount);
    }
    
    function burnFrom(address account, uint256 amount) public virtual  {
        LibTokenERC20.TokenData storage ds = LibTokenERC20.domainStorage();
        uint256 currentAllowance = ds.allowances[account][msg.sender];
        require(currentAllowance >= amount, "transfer amount exceeds allowance");
        uint256 decreasedAllowance = ds.allowances[account][msg.sender] - amount;
        ds.allowances[account][msg.sender] = decreasedAllowance;
        _burn(account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "burn from the zero address");
        LibTokenERC20.TokenData storage ds = LibTokenERC20.domainStorage();
        require(ds.balances[account] >= amount, "burn amount exceeds balance");
        ds.balances[account] = ds.balances[account] - amount;
        ds.totalSupply = ds.totalSupply - amount;
        emit Transfer(account, address(0), amount);
    }


}