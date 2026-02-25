// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MogalandSkillNFT
 * @dev NFT contract for Mogaland Skill certificates.
 * Each skill learned in-game is represented as a soulbound-style ERC-721 NFT.
 * Skills: Basic Labor, Programming, Business Mgmt, Medicine, Engineering,
 *         Farming, Culinary Arts, Education, Security, Trading, Journalism, Firefighting
 *
 * NOTE: Replace contract address in game.html when deploying to mainnet.
 */
contract MogalandSkillNFT is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    // Skill ID → human-readable name mapping
    mapping(string => string) public skillNames;

    // Events
    event SkillNFTMinted(address indexed to, uint256 indexed tokenId, string skillId, string skillName);

    constructor() ERC721("Mogaland Skill NFT", "MOGA-SKILL") Ownable(msg.sender) {
        // Pre-populate skill ID → name map
        skillNames["basic"]  = "Basic Labor";
        skillNames["prog"]   = "Programming";
        skillNames["biz"]    = "Business Mgmt";
        skillNames["med"]    = "Medicine";
        skillNames["eng"]    = "Engineering";
        skillNames["farm"]   = "Farming";
        skillNames["chef"]   = "Culinary Arts";
        skillNames["teach"]  = "Education";
        skillNames["sec"]    = "Security";
        skillNames["trade"]  = "Trading";
        skillNames["report"] = "Journalism";
        skillNames["fire"]   = "Firefighting";
    }

    /**
     * @dev Mint a Skill NFT to a player upon completing skill training.
     *      Only callable by contract owner (game treasury/backend).
     * @param to      Recipient wallet address (the learning player)
     * @param skillId Short skill identifier (e.g. "prog", "med")
     * @param tokenURI IPFS or arweave URI pointing to skill metadata JSON
     * @return tokenId The newly minted token ID
     */
    function mintSkill(
        address to,
        string calldata skillId,
        string calldata tokenURI
    ) external onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        string memory name = bytes(skillNames[skillId]).length > 0
            ? skillNames[skillId]
            : skillId;
        emit SkillNFTMinted(to, tokenId, skillId, name);
        return tokenId;
    }

    /**
     * @dev Batch-mint multiple skill NFTs (for initial allocation or rewards).
     * @param to        Recipient wallet
     * @param skillIds  Array of skill IDs to mint
     * @param tokenURIs Corresponding metadata URIs
     */
    function batchMintSkills(
        address to,
        string[] calldata skillIds,
        string[] calldata tokenURIs
    ) external onlyOwner {
        require(skillIds.length == tokenURIs.length, "Length mismatch");
        require(skillIds.length <= 20, "Max 20 per batch");
        for (uint256 i = 0; i < skillIds.length; i++) {
            mintSkill(to, skillIds[i], tokenURIs[i]);
        }
    }

    /**
     * @dev Add or update a skill name (for future skill expansions).
     */
    function setSkillName(string calldata skillId, string calldata name)
        external onlyOwner
    {
        skillNames[skillId] = name;
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
