#!/usr/bin/env python3
import re

# Read the file
with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Find and replace the entire NFT section content
# Look for the NFT section rendering
nft_section_start = content.find("else if (id === 'nft') {")
if nft_section_start != -1:
    # Find the end of this section (next else or closing brace)
    brace_count = 0
    pos = content.find('{', nft_section_start)
    start_content = pos + 1
    i = pos
    while i < len(content):
        if content[i] == '{':
            brace_count += 1
        elif content[i] == '}':
            brace_count -= 1
            if brace_count == 0:
                end_content = i
                break
        i += 1
    
    new_nft_section = '''
        loadUserNFTs(); // Load NFTs from wallet
        content.innerHTML = `
          <h2 style="text-align:center; margin:40px 0; color:#60a5fa;">NFT Staking</h2>
          <p style="text-align:center; font-size:1.2em; color:#94a3b8; margin-bottom:16px;">
            Stake your Mogaland NFTs and earn USDC Sepolia rewards
          </p>
          <p style="text-align:center; font-size:0.9em; color:#64748b; margin-bottom:32px;">
            NFT Contract: ${NFT_CONTRACT_ADDRESS.slice(0,6)}...${NFT_CONTRACT_ADDRESS.slice(-4)} | 
            <a href="https://testnets.opensea.io/assets/sepolia/${NFT_CONTRACT_ADDRESS}" target="_blank" style="color:#60a5fa;">View on OpenSea</a>
          </p>

          <div class="stats-grid">
            <div class="stats-card">
              <h4>Your NFTs</h4>
              <div class="stats-value" style="color:#60a5fa;">${userNFTs.length + mintedNFTs.length}</div>
            </div>
            <div class="stats-card">
              <h4>Staked NFTs</h4>
              <div class="stats-value" style="color:#10b981;">${stakedNFTsData.length}</div>
            </div>
            <div class="stats-card">
              <h4>Claimable Rewards</h4>
              <div class="stats-value" style="color:#fbbf24;">${calculateTotalRewards().toFixed(4)} USDC</div>
            </div>
            <div class="stats-card">
              <h4>Learning Points</h4>
              <div class="stats-value" style="color:#c084fc;">${mogalandPoints}</div>
            </div>
          </div>

          ${!walletConnected && loginMethod !== 'wallet' ? `
            <div style="background:rgba(239,68,68,0.1); border:1px solid #ef4444; border-radius:12px; padding:20px; margin:20px 0; text-align:center;">
              <p style="color:#ef4444; font-size:1.1em; margin-bottom:12px;">⚠️ Wallet Not Connected</p>
              <p style="color:#94a3b8; margin-bottom:16px;">Connect your wallet to interact with NFTs</p>
              <button class="btn-primary" onclick="showWalletOptions()">Connect Wallet</button>
            </div>
          ` : ''}

          <div style="display:flex; justify-content:space-between; align-items:center; margin:32px 0 16px;">
            <h3 style="color:#60a5fa;">Available NFTs (${userNFTs.length + mintedNFTs.length})</h3>
            ${mogalandPoints >= 1000 ? `
              <button class="btn-primary" style="background:linear-gradient(90deg,#c084fc,#a855f7);" onclick="redeemPointsForUSDC()">
                🎁 Redeem ${mogalandPoints} Points → ${(mogalandPoints/1000).toFixed(2)} USDC
              </button>
            ` : `
              <span style="color:#64748b;">Need 1000+ points to redeem</span>
            `}
          </div>
          
          <div style="display:grid; grid-template-columns:repeat(auto-fill, minmax(240px, 1fr)); gap:20px; margin-bottom:60px;">
            ${generateNFTCardsFromWallet(false)}
          </div>

          <h3 style="color:#60a5fa; margin:32px 0 16px;">Staked NFTs (${stakedNFTsData.length})</h3>
          <div style="display:grid; grid-template-columns:repeat(auto-fill, minmax(240px, 1fr)); gap:20px;">
            ${generateNFTCardsFromWallet(true)}
          </div>

          <div style="position:fixed; bottom:90px; left:50%; transform:translateX(-50%); background:rgba(15,23,42,0.95); backdrop-filter:blur(10px); border:1px solid var(--border); border-radius:60px; padding:12px 32px; display:flex; gap:16px; z-index:90; box-shadow:0 8px 30px rgba(0,0,0,0.6);">
            <button class="btn-primary" style="padding:14px 28px;" onclick="stakeSelectedNFTs()">Stake Selected</button>
            <button class="btn-primary" style="background:linear-gradient(90deg,var(--danger),#f87171); padding:14px 28px;" onclick="unstakeSelectedNFTs()">Unstake</button>
            <button class="btn-primary" style="background:linear-gradient(90deg,#10b981,#34d399); padding:14px 28px;" onclick="claimAllRewards()">Claim Rewards</button>
          </div>
          
          <p style="text-align:center; margin-top:40px; color:#64748b; font-size:0.9em;">
            ⛽ Gas Fee: ${GAS_FEE_USDC} USDC per transaction | APY varies by NFT rarity
          </p>
        `;'''
    
    # Replace the content between braces
    content = content[:start_content] + new_nft_section + content[end_content:]

# Save
with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("NFT section UI updated with Web3 integration")
