// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "../dex/DexApp.sol";
import "../tokens/ERC20App.sol";

library LibTokenDexERC20 {
    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("token.constants.dex");
    struct TokenData {
        bool preorder;
    }    

    function domainStorage() internal pure returns (LibTokenDexERC20.TokenData storage ds) {
        bytes32 position = DOMAIN_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

}

contract TokenDexApp is ERC20App  {
   
    function setPreOrder(bool preorder) public {
        LibTokenDexERC20.TokenData storage ds = LibTokenDexERC20.domainStorage();
        ds.preorder = preorder;
    }

    function transfer(address recipient, uint256 amount) public override {
        LibTokenDexERC20.TokenData storage ds = LibTokenDexERC20.domainStorage();
        require(!ds.preorder, "Transfer blocked due to pre-order status.");

        super.transfer(recipient, amount);
    }
}

