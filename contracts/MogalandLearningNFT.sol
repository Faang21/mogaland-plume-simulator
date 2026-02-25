// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MogalandLearningNFT
 * @dev NFT contract for Mogaland Learning achievement rewards.
 *
 * Awarded to players who complete learning modules (School / Library).
 * Features a rarity system:
 *   - Legendary : 1 %  (tokenId % 100 == 0)
 *   - Epic       : 5 %  (tokenId % 100 < 6)
 *   - Rare       : 15 % (tokenId % 100 < 21)
 *   - Common     : 79 %
 *
 * NOTE: Replace contract address in game.html when deploying to mainnet.
 *       The existing MogalandNFT.sol serves the same purpose — this file
 *       provides a clearly-named alternative for the learning system.
 */
contract MogalandLearningNFT is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    // Base URI for token metadata (update with your IPFS / arweave hash)
    string private _baseTokenURI;

    // Events
    event LearningNFTMinted(address indexed to, uint256 indexed tokenId, string rarity, string subject);

    constructor() ERC721("Mogaland Learning NFT", "MOGA-LEARN") Ownable(msg.sender) {
        _baseTokenURI = "ipfs://QmYourLearningBaseURIHash/"; // replace before mainnet
    }

    // ── Minting ──────────────────────────────────────────────────────────

    /**
     * @dev Mint a learning achievement NFT to a player.
     * @param to      Recipient (learning player)
     * @param subject Human-readable subject label (e.g. "Programming — School")
     * @return tokenId The newly minted token ID
     */
    function mintLearning(address to, string calldata subject)
        external onlyOwner returns (uint256)
    {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);

        string memory rarity = _getRarity(tokenId);
        string memory uri = string(abi.encodePacked(rarity, "_learning.json"));
        _setTokenURI(tokenId, uri);

        emit LearningNFTMinted(to, tokenId, rarity, subject);
        return tokenId;
    }

    /**
     * @dev Allow a player to self-mint after completing learning on-chain.
     *      Useful when the game verifies completion via a signed message.
     */
    function mintForSelf(string calldata subject) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);

        string memory rarity = _getRarity(tokenId);
        string memory uri = string(abi.encodePacked(rarity, "_learning.json"));
        _setTokenURI(tokenId, uri);

        emit LearningNFTMinted(msg.sender, tokenId, rarity, subject);
        return tokenId;
    }

    // ── Rarity ───────────────────────────────────────────────────────────

    function _getRarity(uint256 tokenId) internal pure returns (string memory) {
        uint256 mod = tokenId % 100;
        if (mod < 1)  return "Legendary";
        if (mod < 6)  return "Epic";
        if (mod < 21) return "Rare";
        return "Common";
    }

    function getRarity(uint256 tokenId) external pure returns (string memory) {
        return _getRarity(tokenId);
    }

    // ── Admin ─────────────────────────────────────────────────────────────

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
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
