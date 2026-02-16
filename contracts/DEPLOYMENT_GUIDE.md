# Smart Contract Deployment Guide
## Mogaland Plume Simulator - Sepolia Testnet

This guide will walk you through deploying the MogalandNFT smart contract to the Sepolia testnet using RemixIDE and MetaMask.

---

## Prerequisites

### 1. MetaMask Setup
- [ ] Install MetaMask browser extension: https://metamask.io/
- [ ] Create or import a wallet
- [ ] Add Sepolia testnet to MetaMask

**Add Sepolia Network Manually:**
- Network Name: `Ethereum Sepolia`
- RPC URL: `https://rpc.sepolia.org`
- Chain ID: `11155111`
- Currency Symbol: `ETH`
- Block Explorer: `https://sepolia.etherscan.io`

### 2. Get Sepolia Test ETH
You need Sepolia ETH to pay for gas fees when deploying contracts.

**Faucets:**
- https://sepoliafaucet.com
- https://www.infura.io/faucet/sepolia
- https://faucets.chain.link/sepolia
- Google Cloud Faucet (requires account)

**Amount needed:** At least 0.05 SepoliaETH for deployment

---

## Step-by-Step Deployment

### Step 1: Open RemixIDE

1. Go to https://remix.ethereum.org
2. You'll see the Remix interface with a file explorer on the left

### Step 2: Create New File

1. In the file explorer, right-click on `contracts` folder
2. Select `New File`
3. Name it: `MogalandNFT.sol`
4. Copy the entire contract code from `MogalandNFT.sol` and paste it into the file

### Step 3: Compile the Contract

1. Click on the **"Solidity Compiler"** tab (second icon in the left sidebar)
2. Select compiler version: `0.8.20` or higher
3. Click **"Compile MogalandNFT.sol"** button
4. Wait for compilation to complete
5. You should see a **green checkmark** ✅ indicating successful compilation

**Troubleshooting:**
- If you see errors about OpenZeppelin imports, Remix will automatically fetch them
- If compilation fails, check that the compiler version is 0.8.20 or higher

### Step 4: Configure Deployment Environment

1. Click on the **"Deploy & run transactions"** tab (third icon in the left sidebar)
2. In the **ENVIRONMENT** dropdown, select:
   - **"Injected Provider - MetaMask"**
3. MetaMask will pop up asking you to connect
4. **Sign the message** in MetaMask to connect
5. Verify you see:
   - Your wallet address
   - Network: "Sepolia (11155111)"
   - Your Sepolia ETH balance

**Important:** Make sure you're on Sepolia testnet, not Ethereum Mainnet!

### Step 5: Deploy the Contract

1. In the **CONTRACT** dropdown, select `MogalandNFT`
2. You'll see the contract ready to deploy with its constructor
3. Click the orange **"Deploy"** button
4. MetaMask will pop up with a transaction confirmation:
   - **Review the gas fee** (should be around 0.01-0.03 ETH on Sepolia)
   - Click **"Confirm"** to deploy

### Step 6: Wait for Deployment

1. The deployment may take 15-60 seconds
2. You'll see a message in the Remix console:
   ```
   creation of MogalandNFT pending...
   [block] from: 0x... to: MogalandNFT.(constructor) value: 0 wei
   ```
3. Once confirmed, you'll see:
   - A success message in the console
   - The contract appears under **"Deployed Contracts"** section

### Step 7: Copy Contract Address

1. In the **"Deployed Contracts"** section, you'll see your contract
2. Click the **copy icon** next to the contract address
3. **Save this address** - you'll need it to update the application!

Example: `0x1234567890abcdef1234567890abcdef12345678`

### Step 8: Verify Contract on Etherscan (Optional but Recommended)

1. Go to https://sepolia.etherscan.io
2. Search for your contract address
3. Go to the **"Contract"** tab
4. Click **"Verify and Publish"**
5. Follow the wizard:
   - Compiler Type: `Solidity (Single file)`
   - Compiler Version: `v0.8.20+commit...`
   - License Type: `MIT`
   - Paste your contract code
   - Include OpenZeppelin imports (Remix can help with flattening)

---

## Step 9: Update Application with Contract Address

After successful deployment, update the contract address in your application:

### Edit `index.html`:

Find line ~2734 and update:
```javascript
const NFT_CONTRACT_ADDRESS = "0xYOUR_DEPLOYED_CONTRACT_ADDRESS";
```

Replace `0xYOUR_DEPLOYED_CONTRACT_ADDRESS` with the actual address you got from step 7.

---

## Testing Your Deployed Contract

### Test in Remix

1. Under **"Deployed Contracts"**, expand your contract
2. You'll see all public functions
3. Try these functions:

**Test getRarityFromTokenId:**
- Input: `0`
- Output: Should return "Legendary"
- Input: `5`
- Output: Should return "Epic"
- Input: `20`
- Output: Should return "Rare"
- Input: `50`
- Output: Should return "Common"

**Test mintForSelf** (if you want to test minting):
- Click `mintForSelf` button
- Confirm transaction in MetaMask
- Wait for confirmation
- Check `balanceOf` with your address - should show `1`

### Test in Your Application

1. Open your Mogaland Plume Simulator
2. Connect your MetaMask wallet
3. Go to the NFT section
4. The application should now recognize your deployed contract
5. Try minting an NFT through the application

---

## Gas Costs (Approximate)

- **Contract Deployment:** 0.01-0.03 SepoliaETH
- **Minting Single NFT:** 0.001-0.003 SepoliaETH
- **Batch Minting (10 NFTs):** 0.005-0.015 SepoliaETH

---

## Troubleshooting

### Problem: "Gas estimation failed"
**Solution:** 
- Increase your Sepolia ETH balance
- Try again with a slightly higher gas limit

### Problem: "Contract not found" in application
**Solution:**
- Verify you updated the contract address in `index.html`
- Check that the contract is deployed on Sepolia (not another network)
- Verify the address is correct (no typos)

### Problem: "balanceOf call failed"
**Solution:**
- This is normal if no NFTs have been minted yet
- The application now handles this gracefully
- Try minting an NFT first

### Problem: MetaMask not connecting to Remix
**Solution:**
- Refresh the Remix page
- Disconnect and reconnect MetaMask
- Clear browser cache
- Check that you selected "Injected Provider - MetaMask"

---

## Advanced: Using Hardhat for Deployment (Alternative Method)

If you prefer using Hardhat instead of Remix:

### 1. Install Hardhat
```bash
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
```

### 2. Initialize Hardhat Project
```bash
npx hardhat init
```

### 3. Create Deployment Script
Create `scripts/deploy.js`:
```javascript
const hre = require("hardhat");

async function main() {
  const MogalandNFT = await hre.ethers.getContractFactory("MogalandNFT");
  const nft = await MogalandNFT.deploy();
  await nft.waitForDeployment();
  
  console.log("MogalandNFT deployed to:", await nft.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
```

### 4. Configure hardhat.config.js
```javascript
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: "0.8.20",
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "https://rpc.sepolia.org",
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
```

### 5. Deploy
```bash
npx hardhat run scripts/deploy.js --network sepolia
```

---

## Security Reminders

⚠️ **NEVER share your private keys or seed phrase**
⚠️ **NEVER commit private keys to GitHub**
⚠️ **Always use testnet for development and testing**
⚠️ **Keep your MetaMask seed phrase in a secure location**

---

## Next Steps

After successfully deploying:

1. ✅ Update contract address in application
2. ✅ Test NFT minting functionality
3. ✅ Verify contract on Etherscan
4. ✅ Set up metadata on IPFS
5. ✅ Test with different wallets
6. ✅ Monitor gas costs

---

## Support

If you encounter issues:
- Check Remix documentation: https://remix-ide.readthedocs.io
- Ethereum Sepolia testnet status: https://sepolia.dev
- MetaMask support: https://metamask.zendesk.com

---

**Congratulations! You've successfully deployed your smart contract to Sepolia! 🎉**
