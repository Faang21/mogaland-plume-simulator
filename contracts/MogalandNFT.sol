// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MogalandNFT
 * @dev NFT contract for Mogaland Plume Simulator
 * Features:
 * - Enumerable for easy wallet queries
 * - URI storage for metadata
 * - Owner-controlled minting (can be changed to allow user minting)
 * - Rarity system based on token ID
 */
contract MogalandNFT is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;
    
    // Base URI for token metadata
    string private _baseTokenURI;
    
    // Events
    event NFTMinted(address indexed to, uint256 indexed tokenId, string rarity);
    
    constructor() ERC721("Mogaland Learning NFT", "MOGA-NFT") Ownable(msg.sender) {
        _baseTokenURI = "ipfs://QmYourBaseURIHash/"; // Update with your IPFS hash
    }
    
    /**
     * @dev Mint a new NFT to the specified address
     * @param to Address to receive the NFT
     * @return tokenId The ID of the newly minted token
     */
    function mint(address to) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        
        // Set token URI based on rarity
        string memory rarity = getRarityFromTokenId(tokenId);
        string memory tokenURI = string(abi.encodePacked(rarity, ".json"));
        _setTokenURI(tokenId, tokenURI);
        
        emit NFTMinted(to, tokenId, rarity);
        return tokenId;
    }
    
    /**
     * @dev Batch mint NFTs to the specified address
     * @param to Address to receive the NFTs
     * @param amount Number of NFTs to mint
     */
    function batchMint(address to, uint256 amount) public onlyOwner {
        require(amount > 0 && amount <= 100, "Amount must be between 1 and 100");
        for (uint256 i = 0; i < amount; i++) {
            mint(to);
        }
    }
    
    /**
     * @dev Allow users to mint their own NFT (for learning rewards)
     * Can be called by anyone who has completed learning
     */
    function mintForSelf() public returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
        
        string memory rarity = getRarityFromTokenId(tokenId);
        string memory tokenURI = string(abi.encodePacked(rarity, ".json"));
        _setTokenURI(tokenId, tokenURI);
        
        emit NFTMinted(msg.sender, tokenId, rarity);
        return tokenId;
    }
    
    /**
     * @dev Get rarity based on token ID
     * @param tokenId The token ID to check
     * @return rarity string (Common, Rare, Epic, or Legendary)
     */
    function getRarityFromTokenId(uint256 tokenId) public pure returns (string memory) {
        uint256 mod = tokenId % 100;
        if (mod < 1) return "Legendary"; // 1% chance
        if (mod < 6) return "Epic";       // 5% chance
        if (mod < 21) return "Rare";      // 15% chance
        return "Common";                   // 79% chance
    }
    
    /**
     * @dev Set the base URI for token metadata
     * @param baseURI The new base URI
     */
    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }
    
    /**
     * @dev Get the base URI for token metadata
     * @return The base URI string
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
    
    // Required overrides for multiple inheritance
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
