// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title wMOGA – Wrapped MOGA
 * @notice ERC-20 wrapper for the MOGA token, pegged 1 : 1.
 *
 * Wrapping & unwrapping
 * ─────────────────────
 *  • `wrap(amount)`   – deposit `amount` MOGA, receive the same amount of wMOGA.
 *  • `unwrap(amount)` – burn `amount` wMOGA, receive the same amount of MOGA back.
 *
 * Why wrap?
 * ─────────
 *  wMOGA is designed to be the primary staking and liquidity-pool unit on
 *  mainnet (Base / Arbitrum / EDU Chain).  Because wMOGA is a plain, vanilla
 *  ERC-20 it is compatible with every AMM (Aerodrome, Camelot, Uniswap V3 …),
 *  every staking contract, and every DEX aggregator — regardless of any
 *  non-standard features MOGA itself might carry.
 *
 * Deployment
 * ──────────
 *  1. Deploy `MogaToken.sol` first (or re-use an existing address).
 *  2. Deploy `wMOGA.sol`, passing the MOGA token address to the constructor.
 *  3. Users call `MOGA.approve(wMOGA_ADDRESS, amount)` then `wMOGA.wrap(amount)`.
 *  4. Set the wMOGA address in `index.html` under each network's config
 *     (`wMogaAddress` field) — this is all that is needed to enable the UI.
 *
 * Target networks
 * ───────────────
 *  Base mainnet   · Arbitrum One · EDU Chain Testnet / mainnet
 */
contract wMOGA is ERC20, Ownable {
    using SafeERC20 for IERC20;

    /// @notice The underlying MOGA token that is wrapped.
    IERC20 public immutable moga;

    // ── Events ────────────────────────────────────────────────────────────────

    event Wrapped(address indexed user, uint256 amount);
    event Unwrapped(address indexed user, uint256 amount);

    // ── Constructor ───────────────────────────────────────────────────────────

    /**
     * @param mogaToken Address of the deployed MOGA (MogaToken.sol) contract.
     */
    constructor(address mogaToken) ERC20("Wrapped MOGA", "wMOGA") Ownable(msg.sender) {
        require(mogaToken != address(0), "wMOGA: zero address");
        moga = IERC20(mogaToken);
    }

    // ── Core: wrap / unwrap ───────────────────────────────────────────────────

    /**
     * @notice Deposit `amount` MOGA and receive `amount` wMOGA (1 : 1).
     * @dev    Caller must call `moga.approve(address(this), amount)` beforehand.
     */
    function wrap(uint256 amount) external {
        require(amount > 0, "wMOGA: amount must be > 0");
        moga.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
        emit Wrapped(msg.sender, amount);
    }

    /**
     * @notice Burn `amount` wMOGA and receive `amount` MOGA back (1 : 1).
     */
    function unwrap(uint256 amount) external {
        require(amount > 0, "wMOGA: amount must be > 0");
        _burn(msg.sender, amount);
        moga.safeTransfer(msg.sender, amount);
        emit Unwrapped(msg.sender, amount);
    }

    // ── View ──────────────────────────────────────────────────────────────────

    /**
     * @notice Returns the total MOGA currently held (== total wMOGA supply).
     */
    function reserveBalance() external view returns (uint256) {
        return moga.balanceOf(address(this));
    }
}
