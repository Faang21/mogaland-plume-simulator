// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MogalandTreasury
 * @dev Treasury contract for Mogaland Plume Simulator
 * Features:
 * - Auto-receive ETH via receive() fallback
 * - Admin (CEO) can inject ETH directly
 * - Admin (CEO) can inject USDC (or any ERC-20)
 * - Balance queries for ETH and any ERC-20
 * - Compatible with EVM chains: Plume, EDU, Base, Sepolia
 */
contract MogalandTreasury is Ownable {

    // ─── Events ────────────────────────────────────────────────────────────────
    event ETHReceived(address indexed from, uint256 amount);
    event ETHInjected(address indexed admin, uint256 amount);
    event ERC20Injected(address indexed admin, address indexed token, uint256 amount);
    event ETHWithdrawn(address indexed to, uint256 amount);
    event ERC20Withdrawn(address indexed token, address indexed to, uint256 amount);

    // ─── Constructor ───────────────────────────────────────────────────────────
    constructor() Ownable(msg.sender) {}

    // ─── Auto-receive ETH ─────────────────────────────────────────────────────

    /**
     * @dev Auto-receive ETH from any address (wallet connect deposits, gas fees, etc.)
     */
    receive() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }

    /**
     * @dev Fallback for calls with data to this contract
     */
    fallback() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }

    // ─── Admin: Inject Funds ──────────────────────────────────────────────────

    /**
     * @dev CEO/Admin injects ETH into the treasury
     * Only callable by the contract owner (admin/CEO)
     */
    function injectETH() external payable onlyOwner {
        require(msg.value > 0, "MogalandTreasury: amount must be > 0");
        emit ETHInjected(msg.sender, msg.value);
    }

    /**
     * @dev CEO/Admin injects ERC-20 tokens (e.g. USDC) into the treasury
     * Requires prior ERC-20 approval: token.approve(treasuryAddress, amount)
     * @param token  ERC-20 token contract address (e.g. USDC on Sepolia)
     * @param amount Amount of tokens to inject (in token's smallest unit)
     */
    function injectERC20(address token, uint256 amount) external onlyOwner {
        require(token != address(0), "MogalandTreasury: invalid token address");
        require(amount > 0, "MogalandTreasury: amount must be > 0");
        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(success, "MogalandTreasury: ERC-20 transfer failed");
        emit ERC20Injected(msg.sender, token, amount);
    }

    // ─── Admin: Withdraw Funds ────────────────────────────────────────────────

    /**
     * @dev Owner withdraws ETH from the treasury
     * @param to     Recipient address
     * @param amount Amount of ETH in wei
     */
    function withdrawETH(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "MogalandTreasury: invalid recipient");
        require(amount > 0 && amount <= address(this).balance, "MogalandTreasury: invalid amount");
        (bool success, ) = to.call{value: amount}("");
        require(success, "MogalandTreasury: ETH transfer failed");
        emit ETHWithdrawn(to, amount);
    }

    /**
     * @dev Owner withdraws ERC-20 tokens from the treasury
     * @param token  ERC-20 token contract address
     * @param to     Recipient address
     * @param amount Amount of tokens (in token's smallest unit)
     */
    function withdrawERC20(address token, address to, uint256 amount) external onlyOwner {
        require(token != address(0), "MogalandTreasury: invalid token address");
        require(to != address(0), "MogalandTreasury: invalid recipient");
        require(amount > 0, "MogalandTreasury: amount must be > 0");
        bool success = IERC20(token).transfer(to, amount);
        require(success, "MogalandTreasury: ERC-20 transfer failed");
        emit ERC20Withdrawn(token, to, amount);
    }

    // ─── Views ────────────────────────────────────────────────────────────────

    /**
     * @dev Returns the current ETH balance held by this treasury
     */
    function getETHBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Returns the current ERC-20 token balance held by this treasury
     * @param token ERC-20 token contract address
     */
    function getERC20Balance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
