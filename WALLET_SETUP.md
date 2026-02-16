# Wallet Connection & Sepolia Setup Guide

## Overview
Mogaland-Plume Simulator now supports multiple wallet connections on the Ethereum Sepolia testnet. This guide will help you connect your wallet and get test ETH for transactions.

## Supported Wallets
- 🦊 **MetaMask** - Most popular Ethereum wallet
- ⚫ **OKX Wallet** - Multi-chain wallet with Sepolia support
- 🛡️ **Trust Wallet** - Mobile and browser extension
- 🔗 **WalletConnect v2** - Connect any WalletConnect-compatible mobile wallet

## Sepolia Testnet Configuration

### Network Details
- **Network Name**: Sepolia Testnet
- **Chain ID**: 11155111 (Hex: 0xaa36a7)
- **Currency Symbol**: ETH
- **Block Explorer**: https://sepolia.etherscan.io

### RPC Endpoints (Multiple for reliability)
1. https://1rpc.io/sepolia (Primary - fastest)
2. https://rpc.sepolia.org
3. https://ethereum-sepolia.publicnode.com
4. https://rpc2.sepolia.org

## How to Connect Your Wallet

### Method 1: Using the App (Automatic)
1. Visit the Mogaland-Plume Simulator
2. Click on your preferred wallet button (MetaMask, OKX, Trust Wallet, or WalletConnect)
3. The app will automatically:
   - Request account access
   - Detect your current network
   - Switch to Sepolia testnet (or add it if missing)
   - Display your balance

### Method 2: Manual Configuration (MetaMask)
1. Open MetaMask extension
2. Click on the network dropdown (top center)
3. Click "Add Network" or "Add a network manually"
4. Enter the following details:
   - Network Name: `Sepolia Testnet`
   - New RPC URL: `https://1rpc.io/sepolia`
   - Chain ID: `11155111`
   - Currency Symbol: `ETH`
   - Block Explorer URL: `https://sepolia.etherscan.io`
5. Click "Save"

### Method 3: Using ChainList (Fastest)
1. Visit [ChainList.org](https://chainlist.org)
2. Search for "Sepolia"
3. Click "Connect Wallet"
4. Approve the network addition in your wallet

## Getting Test ETH

You need test ETH to perform transactions on Sepolia testnet. Here are the best faucets:

### Recommended Faucets
1. **Sepolia Faucet** - https://sepoliafaucet.com
2. **Alchemy Sepolia Faucet** - https://www.alchemy.com/faucets/ethereum-sepolia (Alchemy login required)
3. **Infura Sepolia Faucet** - https://www.infura.io/faucet/sepolia
4. **QuickNode Faucet** - https://faucet.quicknode.com/ethereum/sepolia

### Tips for Getting Test ETH
- Most faucets require Twitter/GitHub authentication
- You can request 0.1-0.5 ETH per day
- Some faucets have waiting periods between requests
- The app will notify you if your balance is low (< 0.01 ETH)

## WalletConnect v2 Setup

### For Users
WalletConnect allows you to connect any mobile wallet that supports WalletConnect protocol:
1. Click "WalletConnect" button
2. Scan the QR code with your mobile wallet
3. Approve the connection in your wallet app
4. The app will automatically switch to Sepolia

### Configuration
The app is configured with a valid WalletConnect project ID from Reown (formerly WalletConnect Cloud).
- Project ID: `51e44cec955a70475db9cc1900283704`
- Dashboard: https://dashboard.reown.com

This allows unlimited connections and full WalletConnect v2 functionality.

## Troubleshooting

### "MetaMask not found"
- Install MetaMask from https://metamask.io
- Make sure the extension is enabled
- Refresh the page after installation

### "Wrong network" or "Switch to Sepolia"
- Click the notification to switch networks automatically
- Or manually switch in your wallet's network dropdown
- The app will auto-detect and prompt you

### "Connection failed"
- Make sure your wallet is unlocked
- Check that you approved the connection request
- Try refreshing the page and connecting again
- Check browser console for detailed error messages

### "Transaction failed"
- Ensure you have enough test ETH for gas fees
- Visit a faucet to get more test ETH
- Wait for the previous transaction to complete

### WalletConnect Issues
- Make sure your mobile wallet supports WalletConnect v2
- Check that both devices are on the same network (or use mobile data)
- Try clearing the app cache and reconnecting
- Some wallets may not support Sepolia - use MetaMask or OKX instead

## Features Requiring Wallet Connection

The following features require a connected wallet:
- ✅ Swap tokens (ETH, USDC, USDT, LINK, WBTC, AAVE, EURO)
- ✅ Bridge assets between networks
- ✅ Trade on prediction markets
- ✅ Mint and stake NFTs
- ✅ Participate in sports betting
- ✅ Send tokens to other addresses

## Security Notes

### What the App Can Do
- Read your wallet address
- Request transactions (which you must approve)
- Check your token balances
- Detect network changes

### What the App CANNOT Do
- Access your private keys
- Make transactions without your approval
- Access wallets other than the connected one
- Transfer funds without your explicit consent

### Best Practices
- Only use test networks for this app (Sepolia)
- Never enter your seed phrase anywhere
- Always verify transaction details before approving
- Use a separate wallet for testing
- Don't store real funds on testnet wallets

## Support

If you encounter issues:
1. Check the browser console (F12) for detailed error messages
2. Verify your wallet is on Sepolia testnet
3. Ensure you have sufficient test ETH
4. Try disconnecting and reconnecting your wallet
5. Clear your browser cache and reload

For persistent issues, please create an issue on the GitHub repository with:
- Wallet type and version
- Browser and version
- Error message from console
- Steps to reproduce

## Additional Resources

- [MetaMask Documentation](https://docs.metamask.io)
- [WalletConnect Documentation](https://docs.walletconnect.com)
- [Ethereum Sepolia Testnet Info](https://sepolia.dev)
- [Ethers.js Documentation](https://docs.ethers.org/v5/)
