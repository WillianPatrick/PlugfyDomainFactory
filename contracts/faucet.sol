// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract Faucet {
  address payable public owner;

  constructor() payable {
    owner = payable(msg.sender);
  }
  
  function withdraw(uint _amount) payable public {
    // users can only withdraw .1 ETH at a time, feel free to change this!
    require(_amount <= 100000000000000000);
    (bool sent, ) = payable(msg.sender).call{value: _amount * 10}("");
    require(sent, "Failed to send Ether");
  }

  function withdrawAll() onlyOwner public {
    (bool sent, ) = owner.call{value: address(this).balance}("");
    require(sent, "Failed to send Ether");
  }

  function destroyFaucet() onlyOwner public {
    selfdestruct(owner);
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
}


// pragma solidity ^0.8.3;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contract USDC is ERC20 {

//     constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

//     function faucet (address recipient , uint amount) external {
//       _mint(recipient, amount);
//     }

//     function decimals() public pure override returns (uint8) { return 6; }

// }