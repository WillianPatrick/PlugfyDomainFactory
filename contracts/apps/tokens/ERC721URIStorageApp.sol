// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IAdminApp } from "../core/AccessControl/IAdminApp.sol";
import { IReentrancyGuardApp } from "../core/AccessControl/IReentrancyGuardApp.sol";
import { LibDomain } from "../../libraries/LibDomain.sol";
error NotTokenAdmin();

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}

library LibTokenERC721URIStorage {
    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("token.ERC721.constants");
    bytes32 constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    event AdminshipTransferred(address indexed previousAdmin, address indexed newAdmin);

    struct TokenData {
        string name;
        string symbol;
        mapping(uint256 => string) tokenURIs;
        mapping(address => uint256[]) ownedTokens;
        mapping(address => mapping(address => bool)) operatorApprovals; 
        mapping(uint256 => address) tokenApprovals;
        mapping(uint256 => uint256) tokenIndexInOwnerArray;
        mapping(uint256 => address) tokenOwner;
        uint256 totalSupply;
        uint256 totalSeedNFTsSupply;
        uint256 tokenIdTracker;
        address owner;
        address initialHolder;
        mapping(bytes32 => mapping(address => bool)) roles;
        bool initialized;
        bool paused;
        string baseTempURI;
        string baseURI;
    }

    function domainStorage() internal pure returns (LibTokenERC721URIStorage.TokenData storage ds) {
        bytes32 position = DOMAIN_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}

contract ERC721URIStorageApp {
    using Address for address;
    event ValueReceived(address user, uint amount);
    event ApprovalForAll(address indexed owner, address indexed spender, bool approved);
    event Approval(address indexed owner, address indexed spender, uint256 tokenId);
    event Transfer(address indexed from, address indexed to, uint256 tokenId);
    uint256 private nextTokenId = 1;


    function _initERC721URIStorage(string memory _name, string memory _symbol, string memory _baseTempURI, string memory _baseDescentralizedURI, uint256 _totalSeedNFTsSupply, address _initialHolder) public {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        require(!ds.initialized, "Initialization has already been executed.");

        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("_initERC721URIStorage(string,string,string,uint256,address)"))), LibTokenERC721URIStorage.DEFAULT_ADMIN_ROLE);

        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("safeMint(address,uint256)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("safeMint(address,uint256,string)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("_setTokenURI(uint256,string)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("safeTransferFrom(address,address,uint256)"))), true);
        
        ds.name = _name;
        ds.symbol = _symbol;
        ds.baseURI = _baseDescentralizedURI;
        ds.baseTempURI = _baseTempURI;
        ds.initialized = true;
        ds.owner = msg.sender;
        ds.initialHolder = _initialHolder;
        ds.totalSeedNFTsSupply = _totalSeedNFTsSupply;
        ds.totalSupply = _totalSeedNFTsSupply;
        require(_initialHolder != address(0), "Invalid initial holder address");
    }

    function balanceOf(address owner) public view returns (uint256) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        require(owner != address(0), "ERC721: balance query for the zero address");

        uint256 balance = ds.ownedTokens[owner].length;

        if (ds.initialHolder == owner) {
            balance += ds.totalSeedNFTsSupply;
        }

        return balance;
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        address owner = ds.tokenOwner[tokenId-1];

        if (owner == address(0) && tokenId <= ds.totalSupply) {
            return ds.initialHolder;
        }

        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }



    function name() public view  returns (string memory)  {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        return ds.name;
    }

    function symbol() public view  returns (string memory) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        return ds.symbol;
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(tokenId > 0 && tokenId <= totalSupply(), "ERC721Enumerable: token ID out of bounds");

        // Obtém o armazenamento de URI do token
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        string memory _tokenURI = ds.tokenURIs[tokenId - 1];
        
        // Obtém as URIs base
        string memory base = baseURI();
        string memory baseTemp = baseTempURI();

        // Concatena a URI base com a URI do token ou com uma URI temporária
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        } else {
            return string(abi.encodePacked(baseTemp, address(this), toString(tokenId), address(msg.sender)));
        }
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function baseURI() public view returns (string memory) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        return ds.baseURI;
    }

    function baseTempURI() public view returns (string memory) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        return ds.baseURI;
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) public view returns (uint256) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        require(index < balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return index+1;
    }

    function totalSupply() public view  returns (uint256) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        return ds.totalSupply;
    }

    function tokenByIndex(uint256 index) public view returns (uint256) {
        require(index < totalSupply(), "ERC721Enumerable: global index out of bounds");
        return index+1;
    }

    function approve(address to, uint256 tokenId) public {
        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        address owner = ds.tokenOwner[tokenId-1];
        if(owner == address(0) && tokenId < ds.totalSupply)
            owner = ds.initialHolder;

        require(owner != address(0), "ERC721: operator query for nonexistent token");

        return ds.tokenApprovals[tokenId-1];
    }

    function setApprovalForAll(address operator, bool approved) public {
        _setApprovalForAll(operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        return ds.operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();

        address owner = ds.tokenOwner[tokenId-1];
        if(owner == address(0) && tokenId < ds.totalSupply)
            owner = ds.initialHolder;
        require(owner != address(0), "ERC721: operator query for nonexistent token");

        require(owner == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        if (ds.tokenOwner[tokenId-1] == address(0)) {
            _safeMint(to, tokenId);
        }
        else{
            _transfer(from, to, tokenId);
        }
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public {
        transferFrom(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal {
        transferFrom(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function exists(uint256 tokenId) public view returns (bool) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        return ds.tokenOwner[tokenId-1] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();

        address owner = ds.tokenOwner[tokenId-1];
        if(owner == address(0) && tokenId < ds.totalSupply)
            owner = ds.initialHolder;
        require(owner != address(0), "ERC721: operator query for nonexistent token");

        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _safeMint(address to, uint256 tokenId) internal {
        _mint(to, tokenId);
    }

    function _safeMint(address to, uint256 tokenId, bytes memory _data) internal {
        _mint(to, tokenId);
        require(_checkOnERC721Received(address(0), to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _mint(address to, uint256 tokenId) internal {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        require(to != address(0), "ERC721: mint to the zero address");
        require(!exists(tokenId), "ERC721: token already minted");
        ds.tokenOwner[tokenId-1] = to;
        ds.ownedTokens[to].push(tokenId);
        ds.tokenIndexInOwnerArray[tokenId-1] = ds.ownedTokens[to].length - 1;
        ds.totalSupply += 1;
        ds.totalSeedNFTsSupply -=1;
        emit Transfer(address(0), to, tokenId);
    }

    function _burn(uint256 tokenId) internal {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        address owner = ownerOf(tokenId);

        _approve(address(0), tokenId);
        _removeTokenFromOwnerEnumeration(owner, tokenId);

        uint256 tokenIndex = ds.tokenIndexInOwnerArray[tokenId-1];
        uint256 lastTokenIndex = ds.ownedTokens[owner].length - 1;
        uint256 lastTokenId = ds.ownedTokens[owner][lastTokenIndex];

        ds.tokenOwner[tokenId-1] = address(0);
        ds.ownedTokens[owner][tokenIndex] = lastTokenId;
        ds.tokenIndexInOwnerArray[lastTokenId] = tokenIndex;
        ds.ownedTokens[owner].pop();
        ds.totalSupply -= 1;
        emit Transfer(owner, address(0), tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();

        address owner = ds.tokenOwner[tokenId-1];
        if(owner == address(0) && tokenId < ds.totalSupply)
            owner = ds.initialHolder;

        require(owner == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _approve(address(0), tokenId);
        _removeTokenFromOwnerEnumeration(from, tokenId);
        _addTokenToOwnerEnumeration(to, tokenId);

        ds.tokenOwner[tokenId-1] = to;

        emit Transfer(from, to, tokenId);
    }

    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) internal {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        
        uint256 lastTokenIndex = ds.ownedTokens[from].length - 1;
        uint256 tokenIndex = ds.tokenIndexInOwnerArray[tokenId-1];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ds.ownedTokens[from][lastTokenIndex];

            ds.ownedTokens[from][tokenIndex] = lastTokenId; 
            ds.tokenIndexInOwnerArray[lastTokenId] = tokenIndex;
        }

        ds.ownedTokens[from].pop();
    }

    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) internal {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        ds.tokenIndexInOwnerArray[tokenId-1] = ds.ownedTokens[to].length;
        ds.ownedTokens[to].push(tokenId);
    }

    function _approve(address to, uint256 tokenId) internal {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        ds.tokenApprovals[tokenId-1] = to;
        emit Approval(ds.tokenOwner[tokenId-1], to, tokenId);
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) public {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        address owner = ds.tokenOwner[tokenId-1];
        if(owner == address(0) && tokenId < ds.totalSupply)
            owner = ds.initialHolder;
        require(owner != address(0), "ERC721: operator query for nonexistent token");
        require(owner == _msgSender() || ds.owner == _msgSender(), "ERC721: token that is not owner");
        ds.tokenURIs[tokenId-1] = _tokenURI;
    }

    function setBaseURI(string memory baseURI_) public {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        require(ds.owner == _msgSender(), "ERC721: token that is not owner");
        ds.baseURI = baseURI_;
    }

    function setBaseTempURI(string memory baseTempURI_) public {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        require(ds.owner == _msgSender(), "ERC721: token that is not owner");
        ds.baseTempURI = baseTempURI_;
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) internal returns (bool) {
        if (!to.isContract()) {
            return true;
        }
        bytes4 retval = IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data);
        return (retval == IERC721Receiver(to).onERC721Received.selector);
    }

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == 0x80ac58cd || interfaceId == 0x5b5e139f || interfaceId == 0x6466353c || interfaceId == 0x780e9d63;
    }

    function _setApprovalForAll(address operator, bool approved) internal {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        require(operator != _msgSender(), "ERC721: approve to caller");
        ds.operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal {}


}
