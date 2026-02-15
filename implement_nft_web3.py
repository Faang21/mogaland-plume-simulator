#!/usr/bin/env python3
import re

# Read the file
with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add NFT contract configuration and login method tracking after treasury config
treasury_config_end = content.find('const GAS_FEE_USDC = 0.01; // 0.01 USDC per action')
if treasury_config_end != -1:
    insert_pos = content.find('\n', treasury_config_end) + 1
    nft_config = '''    let treasuryUSDCBalance = 1000000; // 1M USDC starting balance
    
    // NFT Contract Configuration (Same as treasury for this implementation)
    const NFT_CONTRACT_ADDRESS = "0xa959f26847211f71A22aDb087EBe50E0743e7D66";
    const NFT_ABI = [
      "function balanceOf(address owner) view returns (uint256)",
      "function tokenOfOwnerByIndex(address owner, uint256 index) view returns (uint256)",
      "function tokenURI(uint256 tokenId) view returns (string)",
      "function mint(address to) returns (uint256)",
      "function ownerOf(uint256 tokenId) view returns (address)"
    ];
    
    // Login method tracking
    let loginMethod = null; // 'wallet', 'email', or 'x'
    let walletConnected = false;
    let socialConnected = false;
    
'''
    content = content[:insert_pos] + nft_config + content[insert_pos:]

# 2. Update NFT staking variables section
nft_vars_pattern = r'let stakedNFTs = 0;\s*let nftRewards = 0;\s*let selectedNFTs = new Set\(\);'
nft_vars_replacement = '''let stakedNFTs = 0;
    let nftRewards = 0;
    let selectedNFTs = new Set();
    let userNFTs = []; // User's actual NFTs from wallet
    let mintedNFTs = []; // NFTs minted from learning
    let nftAPYs = {
      'Common': 5,
      'Rare': 10,
      'Epic': 15,
      'Legendary': 20
    };
    let stakedNFTsData = []; // [{nftId, apy, stakedTime, rewards}]
    let lastRewardClaim = Date.now();'''

content = re.sub(nft_vars_pattern, nft_vars_replacement, content)

# 3. Update enterDashboard to track login method
enter_dashboard_pattern = r'function enterDashboard\(method\) \{'
enter_dashboard_replacement = '''function enterDashboard(method) {
      loginMethod = method.toLowerCase();
      if (method === 'Wallet' || method === 'MetaMask' || method === 'OKX' || method === 'WalletConnect') {
        loginMethod = 'wallet';
        walletConnected = true;
      } else if (method === 'Email') {
        loginMethod = 'email';
      } else if (method === 'X') {
        loginMethod = 'x';
      }
      console.log(`[Login] Method: ${loginMethod}, Wallet: ${walletConnected}`);'''

content = re.sub(enter_dashboard_pattern, enter_dashboard_replacement, content)

# Save the modified content
with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Phase 1: Configuration and login tracking added")
