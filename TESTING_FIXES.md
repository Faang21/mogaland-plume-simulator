# Testing Guide for Trading Volume and NFT Reward Claim Fixes

## Overview
This document provides manual testing steps to verify the bug fixes for:
1. Trading volume leaderboard tracking
2. NFT staking reward claim functionality

## Prerequisites
- Connected wallet (MetaMask or WalletConnect)
- Some test ETH for gas fees
- USDC balance for trading

## Test 1: Trading Volume Tracking

### Test 1.1: Crypto Trading Volume
1. Navigate to the Crypto trading tab
2. Select an asset (e.g., BTC)
3. Open a position with amount X USDC (e.g., 100 USDC)
4. Click "Trading Volume Leaderboard" button
5. **Expected**: Your crypto volume should show X USDC
6. Close the position
7. Click "Trading Volume Leaderboard" button again
8. **Expected**: Your crypto volume should now show 2X USDC (open + close)

### Test 1.2: Sports Betting Volume
1. Navigate to the Sports tab
2. Select a team
3. Place a bet with amount Y USDC (e.g., 50 USDC)
4. Click "Trading Volume Leaderboard" button
5. **Expected**: Your sports volume should show Y USDC
6. Wait 15 seconds for the bet to settle automatically
7. Click "Trading Volume Leaderboard" button again
8. **Expected**: Your sports volume should now show 2Y USDC (open + settle)

### Test 1.3: Multiple Categories
1. Trade in different categories (crypto, stocks, commodities, forex, sports)
2. Open and close positions in each category
3. Click "Trading Volume Leaderboard" button
4. **Expected**: 
   - Each category should show correct volume
   - Total volume should be sum of all categories
   - Both opening and closing trades should be counted

## Test 2: NFT Reward Claim

### Test 2.1: Initial Reward Accumulation
1. Navigate to NFT Staking section
2. Mint an NFT if you don't have one (complete learning tasks)
3. Stake the NFT
4. Wait a few minutes for rewards to accumulate
5. Note the reward amount shown

### Test 2.2: Claim and Verify Reset
1. Click "Claim Rewards" button
2. Confirm the gas fee transaction
3. **Expected**: 
   - Notification shows claimed amount
   - Gas fee transaction is sent
   - Reward counter resets to 0 or near 0
4. Wait 1-2 minutes
5. Check reward amount again
6. **Expected**: Rewards should be very small (based on 1-2 minutes of staking)
7. **Bug Fixed**: Previously, rewards would immediately show the same large amount because staking times weren't reset

### Test 2.3: Multiple Claims
1. Stake multiple NFTs if available
2. Wait for rewards to accumulate
3. Claim rewards (should reset all staking times)
4. Wait another period
5. Claim rewards again
6. **Expected**: Second claim should only include rewards from the time after first claim

## Verification Points

### Trading Volume
- [x] Opening positions tracked
- [x] Closing positions tracked
- [x] Sports bets opening tracked
- [x] Sports bets settling tracked
- [x] Category stored in position objects
- [x] Correct category used when closing
- [x] localStorage persistence works
- [x] Leaderboard displays correct totals

### NFT Rewards
- [x] Rewards accumulate over time
- [x] Claim sends gas fee transaction
- [x] Claim resets reward counter
- [x] Staking times reset in stakedNFTsData
- [x] Updated data saved to localStorage
- [x] Rewards don't immediately recalculate to previous amount
- [x] Future rewards based on new staking time

## Console Logs to Check

### Trading Volume
Look for console logs like:
```
[Volume] crypto: +100.00 USDC | Total: 100.00 USDC | Claimable: 0.1000 USDC
[Volume] crypto: +100.00 USDC | Total: 200.00 USDC | Claimable: 0.2000 USDC
```

### NFT Rewards
Look for console logs like:
```
[NFT] Claimed 5.43 PLUME rewards with gas fee. Reset staking times for 2 NFTs.
```

## Known Expected Behavior

1. **Volume rewards rate**: 0.1% of trading volume (1000 USDC volume = 1 USDC reward)
2. **NFT staking APY**: Varies by rarity (Common: 5%, Rare: 10%, Epic: 15%, Legendary: 20%)
3. **Gas fees**: All transactions require small gas fees (0.00001 ETH typical)
4. **Sports bets**: Auto-settle after 15 seconds
5. **Category fallback**: If category not stored in old positions, uses currentTab or 'crypto'

## Troubleshooting

### Trading Volume Not Updating
- Check console for "[Volume]" logs
- Verify wallet is connected
- Ensure positions are fully opened/closed (check for transaction confirmation)
- Check localStorage for `tradingVolume_${address}` key

### NFT Rewards Not Resetting
- Check console for staking time reset log
- Verify wallet is connected
- Check localStorage for `stakedNFTs_${address}` key
- Ensure gas fee transaction was successful

## Success Criteria

✅ **Fix 1 - Trading Volume**: 
- Both opening and closing trades tracked
- All categories tracked correctly
- Leaderboard shows accurate totals

✅ **Fix 2 - NFT Rewards**: 
- Rewards reset after claim
- No immediate recalculation
- Staking times properly reset and persisted
