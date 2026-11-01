// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract ReentrancyGuard {
    bool private _nonReentrant;
    constructor() { _nonReentrant = false; }
    modifier nonReentrant() {
        require(!_nonReentrant, "ReentrancyGuard: reentrant call");
        _nonReentrant = true;
        _;
        _nonReentrant = false;
    }
}
abstract contract Ownable {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() { _owner = msg.sender; emit OwnershipTransferred(address(0), _owner); }
    modifier onlyOwner() { require(_owner == msg.sender, "Ownable: caller is not the owner"); _; }
    function owner() public view returns (address) { return _owner; }
}

contract NFTLaunchpad is ReentrancyGuard, Ownable {
    struct Collection {
        address creator;
        string name;
        string symbol;
        uint256 totalSupply;
        uint256 minted;
        uint256 pricePerNFT;
        bool active;
    }
    Collection[] public collections;
    mapping(address => uint256[]) public creatorCollections;
    mapping(uint256 => mapping(address => uint256)) public collectionBalances;
    uint256 public collectionCount;

    event CollectionCreated(uint256 indexed cid, address indexed creator, string name, string symbol, uint256 supply, uint256 price);
    event NFTMinted(uint256 indexed cid, address indexed buyer, uint256 tokenId, uint256 paid);

    function createCollection(string memory name, string memory symbol, uint256 totalSupply, uint256 pricePerNFT)
        external onlyOwner nonReentrant returns (uint256) {
        require(totalSupply > 0, "Zero supply");
        require(pricePerNFT > 0, "Zero price");
        Collection storage c = collections.push();
        c.creator = msg.sender;
        c.name = name;
        c.symbol = symbol;
        c.totalSupply = totalSupply;
        c.minted = 0;
        c.pricePerNFT = pricePerNFT;
        c.active = true;
        uint256 cid = collections.length - 1;
        collectionCount = cid + 1;
        creatorCollections[msg.sender].push(cid);
        emit CollectionCreated(cid, msg.sender, name, symbol, totalSupply, pricePerNFT);
        return cid;
    }

    function mintNFT(uint256 cid) external payable nonReentrant {
        Collection storage c = collections[cid];
        require(c.active, "Collection inactive");
        require(c.minted < c.totalSupply, "Sold out");
        require(msg.value == c.pricePerNFT, "Incorrect price");
        c.minted += 1;
        uint256 tokenId = c.minted;
        collectionBalances[cid][msg.sender] += 1;
        emit NFTMinted(cid, msg.sender, tokenId, msg.value);
    }

    function getCollection(uint256 cid) external view returns (address creator, string memory name, string memory symbol, uint256 totalSupply, uint256 minted, uint256 price, bool active) {
        Collection storage c = collections[cid];
        return (c.creator, c.name, c.symbol, c.totalSupply, c.minted, c.pricePerNFT, c.active);
    }
    function balanceOf(uint256 cid, address user) external view returns (uint256) { return collectionBalances[cid][user]; }
}
