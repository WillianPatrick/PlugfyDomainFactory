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
        uint256 tokenIdTracker;
        address owner;
        mapping(bytes32 => mapping(address => bool)) roles;
        bool initialized;
        bool paused;
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
    event ApprovalForAll(address indexed owner, address indexed spender, bool aproved);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    uint256 private nextTokenId = 1;
    function _initERC721URIStorage(string memory _name, string memory _symbol, string memory _baseURI, uint256 _initialSupply, address _initialHolder) public {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        require(!ds.initialized, "Initialization has already been executed.");

        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("_initERC721URIStorage(string,string,string,uint256,address)"))), LibTokenERC721URIStorage.DEFAULT_ADMIN_ROLE);

        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("safeMint(address,uint256)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("safeMint(address,uint256,string)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("_setTokenURI(uint256,string)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("safeTransferFrom(address,address,uint256)"))), true);
        
        ds.name = _name;
        ds.symbol = _symbol;
        ds.baseURI = _baseURI;
        ds.initialized = true;
        ds.owner = msg.sender;
        ds.totalSupply = _initialSupply;

        require(_initialHolder != address(0), "Invalid initial holder address");
        _mintQuantity(_initialHolder, _initialSupply);
    }

    function setBaseURI(string memory newBaseURI) public {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        ds.baseURI = newBaseURI;
    }

    function baseURI() public view returns (string memory) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        return ds.baseURI;
    }

    function name() public view  returns (string memory)  {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        return ds.name;
    }

    function symbol() public view  returns (string memory) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        return ds.symbol;
    }

    function totalSupply() public view  returns (uint256) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        return ds.totalSupply;
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        string memory _tokenURI = ds.tokenURIs[tokenId];
        string memory base = baseURI();
        
        if (bytes(base).length == 0) {
            return _tokenURI;
        }

        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return string(abi.encodePacked(base, tokenId));
    }

    function updateTokenURI(uint256 tokenId, string memory _tokenURI) public {
        _setTokenURI(tokenId, _tokenURI);
    }

    function _mint(address to) internal {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        require(to != address(0), "ERC721: mint to the zero address");
        uint256 tokenId = nextTokenId;
        require(ds.tokenOwner[tokenId] == address(0), "ERC721: token already minted");
        ds.tokenOwner[tokenId] = to;
        ds.ownedTokens[to].push(tokenId);
        ds.tokenIndexInOwnerArray[tokenId] = ds.ownedTokens[to].length - 1;
        nextTokenId++;
        emit Transfer(address(0), to, 1);
    }

    function _mintQuantity(address to, uint256 quantity) internal {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        require(to != address(0), "ERC721: mint to the zero address");

        for (uint256 index = 0; index < quantity; index++) {
            uint256 tokenId = nextTokenId;
            require(ds.tokenOwner[tokenId] == address(0), "ERC721: token already minted");
            ds.tokenOwner[tokenId] = to;
            ds.ownedTokens[to].push(tokenId);
            ds.tokenIndexInOwnerArray[tokenId] = ds.ownedTokens[to].length - 1;
            nextTokenId++;
        }
        
        emit Transfer(address(0), to, quantity);
    }

    function safeMint(address to) public {
        _mint(to);
    }

    function safeMint(address to, uint256 tokenId, string memory _tokenURI) public {
        _mint(to);
        _setTokenURI(tokenId, _tokenURI);
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        require(ds.tokenOwner[tokenId] != address(0), "ERC721URIStorage: URI set of nonexistent token");
        ds.tokenURIs[tokenId] = _tokenURI;
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();

        require(ds.tokenOwner[tokenId] == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _approve(address(0), tokenId);
        _removeTokenFromOwnerEnumeration(from, tokenId);
        _addTokenToOwnerEnumeration(to, tokenId);

        ds.tokenOwner[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    

    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) internal {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();

        uint256 lastTokenIndex = ds.ownedTokens[from].length - 1;
        uint256 tokenIndex = ds.tokenIndexInOwnerArray[tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ds.ownedTokens[from][lastTokenIndex];

            ds.ownedTokens[from][tokenIndex] = lastTokenId; 
            ds.tokenIndexInOwnerArray[lastTokenId] = tokenIndex;
        }

        ds.ownedTokens[from].pop();
    }

    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) internal {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        ds.tokenIndexInOwnerArray[tokenId] = ds.ownedTokens[to].length;
        ds.ownedTokens[to].push(tokenId);
    }

    function _approve(address to, uint256 tokenId) internal {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        ds.tokenApprovals[tokenId] = to;
        emit Approval(ds.tokenOwner[tokenId], to, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        require(ds.tokenOwner[tokenId] != address(0), "ERC721: operator query for nonexistent token");
        address owner = ds.tokenOwner[tokenId];
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        require(ds.tokenOwner[tokenId] != address(0), "ERC721: approved query for nonexistent token");
        return ds.tokenApprovals[tokenId];
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        return ds.operatorApprovals[owner][operator];
    }

    function setApprovalForAll(address operator, bool approved) public {
        LibTokenERC721URIStorage.TokenData storage ds = LibTokenERC721URIStorage.domainStorage();
        require(operator != _msgSender(), "ERC721: approve to caller");

        ds.operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }
}
