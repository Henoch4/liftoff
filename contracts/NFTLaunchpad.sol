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
    mapping(uint256 => uint256) public collectionRevenue;
    string public constant name="LIFTOFF";
    string public constant symbol="LIFT";
    uint256 public tokenCount;
    mapping(uint256=>address) private tokenOwners;
    mapping(uint256=>uint256) public tokenCollection;
    mapping(address=>uint256) private nftBalances;
    mapping(uint256=>address) public getApproved;
    mapping(address=>mapping(address=>bool)) public isApprovedForAll;
    event Transfer(address indexed from,address indexed to,uint256 indexed tokenId);
    event Approval(address indexed owner,address indexed approved,uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner,address indexed operator,bool approved);

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
        uint256 tokenId = tokenCount++;
        tokenOwners[tokenId]=msg.sender;tokenCollection[tokenId]=cid;nftBalances[msg.sender]++;
        collectionBalances[cid][msg.sender] += 1;
        collectionRevenue[cid] += msg.value;
        emit NFTMinted(cid, msg.sender, tokenId, msg.value);
        emit Transfer(address(0),msg.sender,tokenId);
    }

    function withdrawRevenue(uint256 cid) external nonReentrant {
        require(collections[cid].creator == msg.sender, "Not creator");
        uint256 amount = collectionRevenue[cid];
        require(amount > 0, "No revenue");
        collectionRevenue[cid] = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "Withdraw failed");
    }

    function ownerOf(uint256 tokenId) public view returns(address){address holder=tokenOwners[tokenId];require(holder!=address(0),"Unknown token");return holder;}
    function balanceOf(address who) external view returns(uint256) { require(who!=address(0),"Zero owner");return nftBalances[who]; }
    function supportsInterface(bytes4 id) external pure returns(bool) { return id==0x01ffc9a7||id==0x80ac58cd; }
    function approve(address to,uint256 tokenId) external { address holder=tokenOwners[tokenId];require(holder!=address(0)&&(msg.sender==holder||isApprovedForAll[holder][msg.sender]),"Not authorized");getApproved[tokenId]=to;emit Approval(holder,to,tokenId); }
    function setApprovalForAll(address operator,bool approved) external { require(operator!=msg.sender,"Self approval");isApprovedForAll[msg.sender][operator]=approved;emit ApprovalForAll(msg.sender,operator,approved); }
    function transferFrom(address from,address to,uint256 tokenId) public nonReentrant { _move(from,to,tokenId); }
    function _move(address from,address to,uint256 tokenId) private { require(from!=address(0)&&tokenOwners[tokenId]==from&&to!=address(0),"Invalid transfer");require(msg.sender==from||getApproved[tokenId]==msg.sender||isApprovedForAll[from][msg.sender],"Not authorized");delete getApproved[tokenId];tokenOwners[tokenId]=to;nftBalances[from]--;nftBalances[to]++;uint256 cid=tokenCollection[tokenId];collectionBalances[cid][from]--;collectionBalances[cid][to]++;emit Transfer(from,to,tokenId); }
    function safeTransferFrom(address from,address to,uint256 tokenId) external nonReentrant { _safe(from,to,tokenId,""); }
    function safeTransferFrom(address from,address to,uint256 tokenId,bytes calldata data) external nonReentrant { _safe(from,to,tokenId,data); }
    function _safe(address from,address to,uint256 tokenId,bytes memory data) private { _move(from,to,tokenId);if(to.code.length>0){(bool ok,bytes memory reply)=to.call(abi.encodeWithSignature("onERC721Received(address,address,uint256,bytes)",msg.sender,from,tokenId,data));require(ok&&reply.length>=32&&abi.decode(reply,(bytes4))==0x150b7a02,"Unsafe recipient");} }

    function getCollection(uint256 cid) external view returns (address creator, string memory name, string memory symbol, uint256 totalSupply, uint256 minted, uint256 price, bool active) {
        Collection storage c = collections[cid];
        return (c.creator, c.name, c.symbol, c.totalSupply, c.minted, c.pricePerNFT, c.active);
    }
    function balanceOf(uint256 cid, address user) external view returns (uint256) { return collectionBalances[cid][user]; }
}
