// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/apps/core/AccessControl/AccessControlApp.sol";

error NotTokenAdmin();

library LibTokenERC20 {
    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("token.constants");

    event AdminshipTransferred(address indexed previousAdmin, address indexed newAdmin);

    struct ConstantsStates {
        string name;
        string symbol;
        uint8 decimals;
        address admin;
    }

    function domainStorage() internal pure returns (ConstantsStates storage ds) {
        bytes32 position = DOMAIN_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function enforceIsTokenAdmin() internal view {
        if(msg.sender != domainStorage().admin) {
            revert NotTokenAdmin();
        }        
    }

    function setTokenAdmin(address _newAdmin) internal {
        ConstantsStates storage ds = domainStorage();
        address previousAdmin = ds.admin;
        ds.admin = _newAdmin;
        emit AdminshipTransferred(previousAdmin, _newAdmin);
    }
}


contract ERC20App is Pausable, ERC20Burnable, AccessControlApp {

    constructor(string memory name, string memory symbol, uint256 totalSupply, uint256 decimals) ERC20(name, symbol) {
        ConstantsStates storage ds = LibTokenERC20.domainStorage();
        ds.name = name;
        ds.symbol = symbol;
        ds.decimals = uint8(decimals);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        ds.balances[msg.sender] = totalSupply * 10 ** decimals;
        ds.totalSupply = totalSupply * 10 ** decimals;
    }


    function name() external view returns (string memory) {
        ConstantsStates storage ds = LibTokenERC20.domainStorage();
        return ds.name;
    }

    function symbol() external view returns (string memory) {
        ConstantsStates storage ds = LibTokenERC20.domainStorage();
        return ds.symbol;
    }

    function decimals() external view returns (uint8) {
        ConstantsStates storage ds = LibTokenERC20.domainStorage();
        return ds.decimals;
    }

    function transferAdminship(address _newAdmin) external {
        LibTokenERC20.enforceIsTokenAdmin();
        LibTokenERC20.setTokenAdmin(_newAdmin);
    }     

    function pause() public onlyRole(PAUSER_ROLE) {
        ConstantsStates storage ds = LibTokenERC20.domainStorage();
        require(!ds.paused, "Already paused");
        ds.paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        ConstantsStates storage ds = LibTokenERC20.domainStorage();
        require(ds.paused, "Already unpaused");
        ds.paused = false;
        emit Unpaused(msg.sender);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal whenNotPaused override {
        super._beforeTokenTransfer(from, to, amount);
    }

    function balanceOf(address account) public view override returns (uint256) {
        ConstantsStates storage ds = LibTokenERC20.domainStorage();
        return ds.balances[account];
    }

    function totalSupply() public view override returns (uint256) {
        ConstantsStates storage ds = LibTokenERC20.domainStorage();
        return ds.totalSupply;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        ConstantsStates storage ds = LibTokenERC20.domainStorage();
        return ds.allowances[owner][spender];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        ConstantsStates storage ds = LibTokenERC20.domainStorage();
        uint256 currentAllowance = ds.allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual override{
        require(sender != address(0), "transfer from the zero address");
        require(recipient != address(0), "transfer to the zero address");
        ConstantsStates storage ds = LibTokenERC20.domainStorage();
        ds.balances[sender] = ds.balances[sender] - amount;
        ds.balances[recipient] = ds.balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual override{
        require(owner != address(0), "approve from the zero address");
        require(spender != address(0), "approve to the zero address");
        ConstantsStates storage ds = LibTokenERC20.domainStorage();
        ds.allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function burn(uint256 amount) public virtual override {
        ConstantsStates storage ds = LibTokenERC20.domainStorage();
        require(ds.balances[msg.sender] >= amount, "burn amount exceeds balance");
        ds.balances[msg.sender] = ds.balances[msg.sender] - amount;
        ds.totalSupply = ds.totalSupply - amount;
        emit Transfer(msg.sender, address(0), amount);
    }
    
    function burnFrom(address account, uint256 amount) public virtual override {
        uint256 decreasedAllowance = allowance(account, _msgSender()) - amount;
        ConstantsStates storage ds = LibTokenERC20.domainStorage();
        ds.allowances[account][_msgSender()] = decreasedAllowance;
        _burn(account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual override{
        require(account != address(0), "burn from the zero address");
        ConstantsStates storage ds = LibTokenERC20.domainStorage();
        ds.balances[account] = ds.balances[account] - amount;
        ds.totalSupply = ds.totalSupply - amount;
        emit Transfer(account, address(0), amount);
    }


}