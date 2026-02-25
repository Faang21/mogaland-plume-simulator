// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MogalandCarNFT
 * @dev NFT contract for Mogaland in-game Cars.
 *
 * Each car in the pixel world is represented as an ERC-721 token.
 * The on-chain record tracks:
 *   - owner address
 *   - car ID (e.g. "car1", "car2")
 *   - car name (e.g. "GoCar Sedan")
 *   - listing status + asking price (for peer-to-peer market sales)
 *
 * Economy rules:
 *   - Buy price  = CAR_NFT_PRICE ($50 USD equivalent)
 *   - Market sell = 60% of buy price (as enforced by game.html buyback logic)
 *   - One car per wallet enforced on-chain via _ownerCar mapping
 *
 * NOTE: Replace contract address in game.html when deploying to mainnet.
 */
contract MogalandCarNFT is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    struct CarData {
        string carId;       // in-game identifier, e.g. "car1"
        string carName;     // human-readable name, e.g. "GoCar Sedan"
        bool   forSale;     // listed on market
        uint256 askingPrice; // price in wei (0 if not for sale)
    }

    mapping(uint256 => CarData) public carData;
    // Reverse lookup: carId → tokenId (1-based; 0 means unminted)
    mapping(string => uint256) private _idToTokenId;
    // One car per wallet
    mapping(address => uint256) private _ownerCar; // owner → tokenId (0 = none)

    // Car type → name mapping
    mapping(string => string) public carNames;

    // Events
    event CarNFTMinted(address indexed to, uint256 indexed tokenId, string carId, string carName);
    event CarListed(uint256 indexed tokenId, uint256 askingPrice);
    event CarDelisted(uint256 indexed tokenId);
    event CarSold(uint256 indexed tokenId, address indexed from, address indexed to, uint256 price);

    constructor() ERC721("Mogaland Car NFT", "MOGA-CAR") Ownable(msg.sender) {
        // Pre-populate car ID → name map (mirrors game.html CAR_TYPES)
        carNames["car1"] = "GoCar Sedan";
        carNames["car2"] = "Beach Cruiser";
        carNames["car3"] = "Yellow Cab";
        carNames["car4"] = "Sports Racer";
        carNames["car5"] = "Family Van";
    }

    // ── Minting ──────────────────────────────────────────────────────────

    /**
     * @dev Mint a car NFT to a player (called by owner/treasury at purchase time).
     *      Enforces one car per wallet.
     * @param to       Recipient wallet address
     * @param carId    In-game car identifier (e.g. "car1")
     * @param tokenURI IPFS / arweave metadata URI
     */
    function mintCar(
        address to,
        string calldata carId,
        string calldata tokenURI
    ) external onlyOwner returns (uint256) {
        require(_ownerCar[to] == 0, "Wallet already owns a car");
        require(_idToTokenId[carId] == 0, "Car already minted");
        uint256 tokenId = ++_nextTokenId; // start from 1
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        string memory name = bytes(carNames[carId]).length > 0 ? carNames[carId] : carId;
        carData[tokenId] = CarData({
            carId: carId,
            carName: name,
            forSale: false,
            askingPrice: 0
        });
        _idToTokenId[carId] = tokenId;
        _ownerCar[to] = tokenId;
        emit CarNFTMinted(to, tokenId, carId, name);
        return tokenId;
    }

    /**
     * @dev Add or update a car name (for future car types).
     */
    function setCarName(string calldata carId, string calldata name)
        external onlyOwner
    {
        carNames[carId] = name;
    }

    /**
     * @dev List a car for sale.
     * @param tokenId     The token to list
     * @param askingPrice Price in wei
     */
    function listForSale(uint256 tokenId, uint256 askingPrice) external {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        require(askingPrice > 0, "Price must be > 0");
        carData[tokenId].forSale = true;
        carData[tokenId].askingPrice = askingPrice;
        emit CarListed(tokenId, askingPrice);
    }

    /**
     * @dev Remove a car listing.
     */
    function delist(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        carData[tokenId].forSale = false;
        carData[tokenId].askingPrice = 0;
        emit CarDelisted(tokenId);
    }

    /**
     * @dev Buy a listed car from its current owner.
     */
    function buyCar(uint256 tokenId) external payable {
        CarData storage cd = carData[tokenId];
        require(cd.forSale, "Car not for sale");
        require(msg.value >= cd.askingPrice, "Insufficient payment");
        require(_ownerCar[msg.sender] == 0, "Buyer already owns a car");
        address seller = ownerOf(tokenId);
        cd.forSale = false;
        cd.askingPrice = 0;
        _ownerCar[seller] = 0;
        _ownerCar[msg.sender] = tokenId;
        _transfer(seller, msg.sender, tokenId);
        payable(seller).transfer(msg.value);
        emit CarSold(tokenId, seller, msg.sender, msg.value);
    }

    /**
     * @dev Get the tokenId owned by a wallet (0 if none).
     */
    function carOf(address owner) external view returns (uint256) {
        return _ownerCar[owner];
    }

    // ── Required overrides ────────────────────────────────────────────────

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
