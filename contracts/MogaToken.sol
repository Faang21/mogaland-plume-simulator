// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @title MogaToken
 * @dev Universal ERC-20 token with full wallet, DEX scanner, Farcaster, and Uniswap compatibility.
 *
 * Implements:
 *   - ERC-20 standard            → readable by all wallets, DEX scanners, Uniswap
 *   - ERC-165 interface detection → wallets can detect token type automatically
 *   - EIP-2612 permit             → gasless Uniswap approvals (no extra tx needed)
 *   - EIP-7572 contractURI        → on-chain JSON metadata for Farcaster, DEX logos,
 *                                   and wallet token-list discovery
 *
 * Deployment args:
 *   name_        — full token name,  e.g. "Moga Moon"
 *   symbol_      — ticker symbol,    e.g. "MGMOON"
 *   totalSupply_ — initial supply in whole tokens (scaled to 18 decimals internally)
 *   owner_       — receives entire initial supply and admin rights
 *   contractURI_ — data:application/json;base64,… or HTTPS/IPFS URL
 *                  pointing to a JSON object with at minimum:
 *                    { "name", "symbol", "description", "image" }
 */
contract MogaToken is ERC20, ERC20Permit, Ownable, ERC165 {

    // ERC-20 interface ID (used by wallets for auto-detection)
    bytes4 private constant _INTERFACE_ID_ERC20 = type(IERC20).interfaceId;

    // EIP-7572: contract-level metadata URI
    string private _contractURI;

    // EIP-7572 event — DEX scanners and Farcaster clients watch for this
    event ContractURIUpdated(string newURI);

    /**
     * @param name_        Token name (shown in wallets and DEX scanners)
     * @param symbol_      Token ticker (e.g. "MGMOON")
     * @param totalSupply_ Supply in whole tokens; will be minted to owner_ with 18 decimals
     * @param owner_       Address receiving the full initial supply and owner role
     * @param contractURI_ Metadata URI (base64 data URI or IPFS/HTTPS)
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        address owner_,
        string memory contractURI_
    )
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        Ownable(owner_)
    {
        require(bytes(name_).length > 0,   "MogaToken: name required");
        require(bytes(symbol_).length > 0, "MogaToken: symbol required");
        require(totalSupply_ > 0,          "MogaToken: supply must be > 0");
        require(owner_ != address(0),      "MogaToken: invalid owner");

        _contractURI = contractURI_;
        _mint(owner_, totalSupply_ * (10 ** decimals()));
    }

    // ─── EIP-7572: Contract-level metadata ──────────────────────────────────

    /**
     * @dev Returns the contract-level metadata URI.
     *      Farcaster, DexScreener, DexTools, and Uniswap token-list tooling
     *      fetch this to display the token name, symbol, logo, and description.
     *      Recommended format (base64-encoded JSON):
     *      {
     *        "name": "<token name>",
     *        "symbol": "<ticker>",
     *        "description": "<description>",
     *        "image": "<logo URL or base64 data URI>"
     *      }
     */
    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    /**
     * @dev Update the contract metadata URI (owner only).
     *      Use this to update the logo or description after deployment.
     */
    function setContractURI(string calldata newURI) external onlyOwner {
        _contractURI = newURI;
        emit ContractURIUpdated(newURI);
    }

    // ─── ERC-165: Interface detection ────────────────────────────────────────

    /**
     * @dev Wallets and aggregators call this to verify the token type.
     *      Returns true for ERC-20 (IERC20) and the base ERC-165 interface.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165)
        returns (bool)
    {
        return
            interfaceId == _INTERFACE_ID_ERC20 ||
            super.supportsInterface(interfaceId);
    }

    // ─── Owner utilities ─────────────────────────────────────────────────────

    /**
     * @dev Mint additional tokens to any address (owner only).
     *      Useful for rewards, staking incentives, or liquidity programs.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Burn tokens from the caller's balance.
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
