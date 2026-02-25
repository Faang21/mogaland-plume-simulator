// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MogalandHouseNFT
 * @dev NFT contract for Mogaland in-game Houses.
 *
 * Each house in the pixel world (House, House 2 … House 15) is represented
 * as an ERC-721 token.  The on-chain record tracks:
 *   - owner address
 *   - house key (e.g. "House 5")
 *   - upgrade level (increased when player upgrades via in-game action)
 *   - listing status + asking price (for peer-to-peer market sales)
 *
 * Economy rules implemented in-contract:
 *   - Buy price  = listingPrice (set by current owner, min 100 USD equivalent)
 *   - Market sell = 70 % of current on-chain value (buy-back discount)
 *
 * NOTE: Replace contract address in game.html when deploying to mainnet.
 */
contract MogalandHouseNFT is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    struct HouseData {
        string  houseKey;    // in-game identifier, e.g. "House 5"
        uint8   level;       // upgrade level (1–20)
        bool    forSale;     // listed on market
        uint256 askingPrice; // price in wei (0 if not for sale)
    }

    mapping(uint256 => HouseData) public houseData;
    // Reverse lookup: houseKey → tokenId (1-based; 0 means unminted)
    mapping(string => uint256) private _keyToTokenId;

    // Market buy-back rate in basis points (7000 = 70 %)
    uint256 public buybackBps = 7000;

    // Events
    event HouseNFTMinted(address indexed to, uint256 indexed tokenId, string houseKey);
    event HouseListed(uint256 indexed tokenId, uint256 askingPrice);
    event HouseDelisted(uint256 indexed tokenId);
    event HouseSold(uint256 indexed tokenId, address indexed from, address indexed to, uint256 price);
    event HouseUpgraded(uint256 indexed tokenId, uint8 newLevel);

    constructor() ERC721("Mogaland House NFT", "MOGA-HOUSE") Ownable(msg.sender) {}

    // ── Minting ──────────────────────────────────────────────────────────

    /**
     * @dev Mint a house NFT to a player (called by owner/treasury at purchase time).
     * @param to       Recipient wallet address
     * @param houseKey In-game house identifier (e.g. "House 3")
     * @param tokenURI IPFS / arweave metadata URI
     */
    function mintHouse(
        address to,
        string calldata houseKey,
        string calldata tokenURI
    ) external onlyOwner returns (uint256) {
        require(_keyToTokenId[houseKey] == 0, "House already minted");
        uint256 tokenId = ++_nextTokenId; // start from 1
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        houseData[tokenId] = HouseData({
            houseKey: houseKey,
            level: 1,
            forSale: false,
            askingPrice: 0
        });
        _keyToTokenId[houseKey] = tokenId;
        emit HouseNFTMinted(to, tokenId, houseKey);
        return tokenId;
    }

    // ── Upgrade ──────────────────────────────────────────────────────────

    /**
     * @dev Upgrade a house level (owner of the game contract calls this after
     *      the player pays the upgrade fee in-game).
     */
    function upgradeHouse(uint256 tokenId) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(houseData[tokenId].level < 20, "Max level reached");
        houseData[tokenId].level++;
        emit HouseUpgraded(tokenId, houseData[tokenId].level);
    }

    // ── Marketplace ──────────────────────────────────────────────────────

    /**
     * @dev List a house for sale.  Only the current token owner may call this.
     * @param tokenId     Token to list
     * @param askingPrice Price in wei the owner wants
     */
    function listForSale(uint256 tokenId, uint256 askingPrice) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(askingPrice > 0, "Price must be > 0");
        houseData[tokenId].forSale = true;
        houseData[tokenId].askingPrice = askingPrice;
        emit HouseListed(tokenId, askingPrice);
    }

    /**
     * @dev Delist a house from sale.
     */
    function delist(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        houseData[tokenId].forSale = false;
        houseData[tokenId].askingPrice = 0;
        emit HouseDelisted(tokenId);
    }

    /**
     * @dev Purchase a listed house.  Buyer sends ETH; contract forwards
     *      payment to seller minus a 2.5 % platform fee retained by owner.
     */
    function buyHouse(uint256 tokenId) external payable {
        HouseData storage hd = houseData[tokenId];
        require(hd.forSale, "Not for sale");
        require(msg.value >= hd.askingPrice, "Insufficient payment");

        address seller = ownerOf(tokenId);
        require(seller != msg.sender, "Cannot buy own house");

        // Platform fee: 2.5 %
        uint256 fee = (hd.askingPrice * 250) / 10000;
        uint256 sellerAmount = hd.askingPrice - fee;

        hd.forSale = false;
        hd.askingPrice = 0;

        // Transfer NFT
        _transfer(seller, msg.sender, tokenId);

        // Pay seller
        (bool ok, ) = payable(seller).call{value: sellerAmount}("");
        require(ok, "Seller payment failed");

        // Refund overpayment
        if (msg.value > hd.askingPrice) {
            (bool refund, ) = payable(msg.sender).call{value: msg.value - hd.askingPrice}("");
            require(refund, "Refund failed");
        }

        emit HouseSold(tokenId, seller, msg.sender, hd.askingPrice);
    }

    /**
     * @dev Sell-back to market at buybackBps discount (e.g. 70 %).
     *      Owner (treasury) must fund the contract with ETH for buy-backs.
     */
    function sellToMarket(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        HouseData storage hd = houseData[tokenId];
        // Compute buy-back value from suggested price: 100 + level*5 USD
        // On testnet we approximate: 1 USD ≈ 0.000003 ETH
        uint256 suggestedWei = uint256(100 + hd.level * 5) * 3e12; // 0.000003 ETH per USD
        uint256 buybackWei = (suggestedWei * buybackBps) / 10000;
        require(address(this).balance >= buybackWei, "Market has insufficient funds");

        // Transfer NFT to contract (market holds it)
        _transfer(msg.sender, address(this), tokenId);
        hd.forSale = true;
        hd.askingPrice = suggestedWei; // re-list at full suggested price

        // Pay seller
        (bool ok, ) = payable(msg.sender).call{value: buybackWei}("");
        require(ok, "Buyback payment failed");

        emit HouseSold(tokenId, msg.sender, address(this), buybackWei);
    }

    // ── Admin ─────────────────────────────────────────────────────────────

    /**
     * @dev Update buy-back rate (owner only). E.g. 7000 = 70 %.
     */
    function setBuybackBps(uint256 bps) external onlyOwner {
        require(bps <= 10000, "Invalid bps");
        buybackBps = bps;
    }

    /**
     * @dev Withdraw accumulated platform fees.
     */
    function withdraw() external onlyOwner {
        (bool ok, ) = payable(owner()).call{value: address(this).balance}("");
        require(ok, "Withdraw failed");
    }

    receive() external payable {}

    // ── Helpers ───────────────────────────────────────────────────────────

    function tokenIdByKey(string calldata houseKey) external view returns (uint256) {
        return _keyToTokenId[houseKey];
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
