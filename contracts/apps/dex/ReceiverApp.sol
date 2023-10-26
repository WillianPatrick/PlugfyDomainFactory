// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Receiver {
    function onERC20Receive(address from, uint256 amount) external returns (bool);
}

library RceiverManager {
    bytes32 constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("receiver.manager.standard.storage");

    struct DomainStorage{
        bool initialized;
        mapping(address => uint256) tokenBalances;      
        mapping(address => mapping(address => uint256)) tokenSenderBalances;         
        mapping(address => mapping(bytes32 => uint256)) tokenRoleBalances;     
    }

    function domainStorage() internal pure returns (DomainStorage storage ds) {
        bytes32 position = DOMAIN_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }    
}
contract ReceiverApp {

    event TokensReceived(address tokenAddress, address indexed from, uint256 amount);

    function _initReceiverApp() public {
        RceiverManager.DomainStorage storage ds = RceiverManager.domainStorage();
        require(!ds.initialized, "Initialization has already been executed.");
        ds.initialized = true;
    }

    receive() external payable {
        emit TokensReceived(address(0), msg.sender, msg.value);  
    }

    function receiveERC20(address tokenAddress, uint256 amount) external {
        IERC20 token = IERC20(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        RceiverManager.DomainStorage storage ds = RceiverManager.domainStorage();
        ds.tokenBalances[tokenAddress] += amount;
        ds.tokenSenderBalances[tokenAddress][msg.sender] += amount;
        emit TokensReceived(tokenAddress, msg.sender, amount);
    } 

    function getTokenBalance(address tokenAddress) public returns (uint256){
        RceiverManager.DomainStorage storage ds = RceiverManager.domainStorage();
        return ds.tokenBalances[tokenAddress];
    }

    function getSenderTokenBalance(address tokenAddress, address from) public returns (uint256){
        RceiverManager.DomainStorage storage ds = RceiverManager.domainStorage();
        return ds.tokenSenderBalances[tokenAddress][from];
    }    
}
