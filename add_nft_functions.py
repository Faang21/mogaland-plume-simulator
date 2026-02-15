#!/usr/bin/env python3

# Read the file
with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Find where to insert new functions (after claimNFTRewards function)
insert_pos = content.find('function claimNFTRewards() {')
if insert_pos != -1:
    # Find the end of claimNFTRewards function
    brace_count = 0
    pos = content.find('{', insert_pos)
    i = pos
    while i < len(content):
        if content[i] == '{':
            brace_count += 1
        elif content[i] == '}':
            brace_count -= 1
            if brace_count == 0:
                insert_pos = i + 1
                break
        i += 1
    
    # Insert comprehensive NFT Web3 functions
    new_functions = '''

    // === NFT Web3 Integration Functions ===
    
    async function loadUserNFTs() {
      if (!provider || !userAddress) {
        console.log('[NFT] No wallet connected, using demo NFTs');
        return;
      }
      
      try {
        const nftContract = new ethers.Contract(NFT_CONTRACT_ADDRESS, NFT_ABI, provider);
        const balance = await nftContract.balanceOf(userAddress);
        
        userNFTs = [];
        for (let i = 0; i < balance.toNumber(); i++) {
          const tokenId = await nftContract.tokenOfOwnerByIndex(userAddress, i);
          const tokenURI = await nftContract.tokenURI(tokenId);
          userNFTs.push({
            id: tokenId.toString(),
            uri: tokenURI,
            rarity: getRarityFromTokenId(tokenId.toNumber()),
            apy: nftAPYs[getRarityFromTokenId(tokenId.toNumber())]
          });
        }
        
        console.log(`[NFT] Loaded ${userNFTs.length} NFTs from wallet`);
      } catch (error) {
        console.log('[NFT] Error loading NFTs, using demo mode:', error.message);
      }
    }
    
    function getRarityFromTokenId(tokenId) {
      const mod = tokenId % 100;
      if (mod < 50) return 'Common';
      if (mod < 80) return 'Rare';
      if (mod < 95) return 'Epic';
      return 'Legendary';
    }
    
    function generateNFTCardsFromWallet(isStaked) {
      let html = '';
      const nftsToShow = isStaked ? stakedNFTsData : [...userNFTs, ...mintedNFTs];
      
      if (nftsToShow.length === 0) {
        return `<div style="grid-column:1/-1; text-align:center; padding:40px; color:#64748b;">
          ${isStaked ? 'No staked NFTs' : 'No NFTs available. Complete 100 learning tasks to mint your first NFT!'}
        </div>`;
      }
      
      nftsToShow.forEach((nft, index) => {
        const nftId = isStaked ? nft.nftId : (nft.id || index);
        const rarity = isStaked ? nft.rarity : (nft.rarity || 'Common');
        const apy = isStaked ? nft.apy : (nft.apy || nftAPYs[rarity]);
        const rewards = isStaked ? calculateNFTRewards(nft) : 0;
        
        html += `
          <div class="nft-card" style="border: 2px solid ${isStaked ? '#10b981' : 'var(--border)'}; ${selectedNFTs.has(nftId) ? 'border-color:#60a5fa; transform:scale(1.04);' : ''}">
            ${isStaked ? '<div class="nft-staked-badge">STAKED</div>' : ''}
            <div class="nft-image-placeholder">
              MOGA #${String(nftId).padStart(4, '0')}
              ${isStaked ? `<div style="font-size:0.7em; margin-top:4px; color:#10b981;">+${apy}% APY</div>` : ''}
            </div>
            <div style="padding:16px;">
              <div style="display:flex; justify-content:space-between; margin-bottom:8px;">
                <div style="font-weight:bold;">MOGA #${String(nftId).padStart(4,'0')}</div>
                <div style="color:#c084fc;">${rarity}</div>
              </div>
              ${isStaked ? `
                <div style="font-size:0.85em; color:#10b981; margin-bottom:8px;">
                  📈 Rewards: ${rewards.toFixed(4)} USDC
                </div>
              ` : `
                <div style="font-size:0.85em; color:#60a5fa; margin-bottom:8px;">
                  APY: ${apy}%
                </div>
              `}
              <button class="btn-primary" style="${isStaked ? 'background:linear-gradient(90deg,var(--danger),#f87171);' : ''}" onclick="toggleSelectNFT('${nftId}')">
                ${selectedNFTs.has(nftId) ? (isStaked ? 'Deselect' : 'Selected ✓') : (isStaked ? 'Select to Unstake' : 'Select to Stake')}
              </button>
            </div>
          </div>
        `;
      });
      
      return html;
    }
    
    function calculateNFTRewards(stakedNFT) {
      const now = Date.now();
      const stakedDuration = (now - stakedNFT.stakedTime) / (1000 * 60 * 60 * 24); // days
      const dailyRate = stakedNFT.apy / 365 / 100; // Daily rate from APY
      const baseAmount = 100; // Assume 100 USDC equivalent staked value per NFT
      return stakedDuration * dailyRate * baseAmount;
    }
    
    function calculateTotalRewards() {
      let total = 0;
      stakedNFTsData.forEach(nft => {
        total += calculateNFTRewards(nft);
      });
      return total;
    }
    
    async function stakeSelectedNFTs() {
      if (selectedNFTs.size === 0) return showNotification("No NFTs selected!", true);
      
      if (!walletConnected && loginMethod !== 'wallet') {
        showNotification("Please connect your wallet to stake NFTs!", true);
        return;
      }
      
      // Check and process gas fee
      if (!processGasFee('NFT staking')) {
        return;
      }
      
      const selectedArray = Array.from(selectedNFTs);
      selectedArray.forEach(nftId => {
        const nft = [...userNFTs, ...mintedNFTs].find(n => (n.id || n) === nftId);
        if (nft) {
          stakedNFTsData.push({
            nftId: nft.id || nftId,
            rarity: nft.rarity || 'Common',
            apy: nft.apy || nftAPYs[nft.rarity || 'Common'],
            stakedTime: Date.now(),
            rewards: 0
          });
          
          // Remove from available
          const userIndex = userNFTs.findIndex(n => n.id === nftId);
          if (userIndex !== -1) userNFTs.splice(userIndex, 1);
          const mintedIndex = mintedNFTs.findIndex(n => n === nftId);
          if (mintedIndex !== -1) mintedNFTs.splice(mintedIndex, 1);
        }
      });
      
      const count = selectedNFTs.size;
      selectedNFTs.clear();
      showSection('nft');
      showNotification(`✅ Successfully staked ${count} NFT(s) | Gas: ${GAS_FEE_USDC} USDC`);
      console.log(`[NFT] Staked ${count} NFTs with gas fee`);
    }
    
    async function unstakeSelectedNFTs() {
      if (selectedNFTs.size === 0) return showNotification("No staked NFTs selected!", true);
      
      if (!walletConnected && loginMethod !== 'wallet') {
        showNotification("Please connect your wallet to unstake NFTs!", true);
        return;
      }
      
      // Check and process gas fee
      if (!processGasFee('NFT unstaking')) {
        return;
      }
      
      const selectedArray = Array.from(selectedNFTs);
      selectedArray.forEach(nftId => {
        const stakedIndex = stakedNFTsData.findIndex(n => n.nftId === nftId);
        if (stakedIndex !== -1) {
          const stakedNFT = stakedNFTsData[stakedIndex];
          
          // Return to available NFTs
          userNFTs.push({
            id: stakedNFT.nftId,
            rarity: stakedNFT.rarity,
            apy: stakedNFT.apy
          });
          
          stakedNFTsData.splice(stakedIndex, 1);
        }
      });
      
      const count = selectedNFTs.size;
      selectedNFTs.clear();
      showSection('nft');
      showNotification(`✅ Successfully unstaked ${count} NFT(s) | Gas: ${GAS_FEE_USDC} USDC`);
      console.log(`[NFT] Unstaked ${count} NFTs with gas fee`);
    }
    
    async function claimAllRewards() {
      if (stakedNFTsData.length === 0) {
        return showNotification("No staked NFTs!", true);
      }
      
      const totalRewards = calculateTotalRewards();
      if (totalRewards <= 0) {
        return showNotification("No rewards available yet!", true);
      }
      
      if (!walletConnected && loginMethod !== 'wallet') {
        showNotification("Please connect your wallet to claim rewards!", true);
        return;
      }
      
      // Check and process gas fee
      if (!processGasFee('NFT rewards claim')) {
        return;
      }
      
      // Transfer rewards from treasury
      if (transferFromTreasury(totalRewards)) {
        // Reset staking times after claim
        stakedNFTsData.forEach(nft => {
          nft.stakedTime = Date.now();
        });
        
        lastRewardClaim = Date.now();
        showSection('nft');
        showNotification(`✅ Claimed ${totalRewards.toFixed(4)} USDC rewards | Gas: ${GAS_FEE_USDC} USDC`);
        console.log(`[NFT] Claimed ${totalRewards.toFixed(4)} USDC rewards`);
      }
    }
    
    async function redeemPointsForUSDC() {
      if (mogalandPoints < 1000) {
        return showNotification("Need at least 1000 points to redeem!", true);
      }
      
      if (!walletConnected && loginMethod !== 'wallet') {
        showNotification("Please connect your wallet to redeem rewards!", true);
        return;
      }
      
      // Check and process gas fee
      if (!processGasFee('points redemption')) {
        return;
      }
      
      const usdcAmount = mogalandPoints / 1000; // 1000 points = 1 USDC
      
      // Transfer USDC from treasury
      if (transferFromTreasury(usdcAmount)) {
        mogalandPoints = 0;
        showSection('nft');
        showNotification(`✅ Redeemed points for ${usdcAmount.toFixed(2)} USDC | Gas: ${GAS_FEE_USDC} USDC`);
        console.log(`[NFT] Redeemed points for ${usdcAmount.toFixed(2)} USDC`);
      }
    }
    
    // Enhanced mintNFT with treasury gas fee
    async function mintNFTFromLearning() {
      if (completedTasks < 100) {
        showNotification("Complete all 100 tasks first!", true);
        return;
      }
      
      if (nftMinted) {
        showNotification("You've already minted your learning NFT!", false);
        return;
      }
      
      if (!provider || !userAddress) {
        showNotification("Please connect your wallet first!", true);
        return;
      }
      
      // Check and process gas fee
      if (!processGasFee('NFT minting')) {
        return;
      }
      
      try {
        showNotification("Minting your Learning Achievement NFT...", false);
        
        // For demo: Add to minted NFTs
        const newNFTId = Date.now() % 10000;
        const rarity = 'Epic'; // Learning achievement NFTs are Epic
        mintedNFTs.push({
          id: newNFTId,
          rarity: rarity,
          apy: nftAPYs[rarity],
          source: 'learning'
        });
        
        // Simulate minting time
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        nftMinted = true;
        
        // Minting revenue goes to treasury
        const mintPrice = 0.05; // 0.05 ETH mint price
        treasuryUSDCBalance += mintPrice * 2500; // Convert ETH to USDC (assuming 2500 USD/ETH)
        console.log(`[Treasury] Received ${mintPrice * 2500} USDC from NFT mint`);
        
        showNotification("🎉 Learning Achievement NFT minted! View in NFT Staking section", false);
        showSection('learning');
        
        // In production: Call actual smart contract
        // const nftContract = new ethers.Contract(NFT_CONTRACT_ADDRESS, NFT_ABI, signer);
        // const tx = await nftContract.mint(userAddress);
        // await tx.wait();
        
      } catch (error) {
        console.error('Minting error:', error);
        showNotification("Failed to mint NFT: " + error.message, true);
      }
    }'''
    
    content = content[:insert_pos] + new_functions + content[insert_pos:]

# Save
with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("NFT Web3 functions added successfully")
