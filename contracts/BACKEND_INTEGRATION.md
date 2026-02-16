# Backend Integration Guide (Server-Side Only)
## ⚠️ SECURITY CRITICAL - Private Key Management

This guide is for **backend/server-side** implementation ONLY. Your current web application should NEVER use this pattern.

---

## 🚨 CRITICAL SECURITY WARNING

### ❌ NEVER Do This:
- Store private keys in frontend JavaScript
- Commit private keys to GitHub
- Share private keys in any form
- Use private keys in browser code
- Put .env files in public folders

### ✅ ALWAYS Do This:
- Use external wallets (MetaMask, WalletConnect) for frontend
- Store private keys on secure backend servers only
- Use .env files for backend configuration
- Add .env to .gitignore
- Use separate wallets for development/production

---

## 🎯 When to Use Backend Integration

### Valid Use Cases:
1. **Automated Trading Bots** - Server executes trades automatically
2. **Treasury Management** - Backend manages protocol funds
3. **Relayers/Indexers** - Server monitors and relays transactions
4. **Batch Processing** - Server processes multiple transactions
5. **Admin Functions** - Backend-only administrative tasks

### Invalid Use Cases:
❌ User transactions in web app (use MetaMask instead)
❌ Swaps/bridges in frontend (use wallet connection)
❌ Any user-facing operations (always use external wallets)

---

## 📋 Backend Setup (Node.js)

### Step 1: Project Structure

```bash
your-backend/
├── .env                 # ⚠️ Never commit this!
├── .gitignore          # Must include .env
├── package.json
├── src/
│   ├── index.js        # Main backend server
│   ├── config.js       # Configuration
│   └── services/
│       ├── treasury.js # Treasury management
│       └── relayer.js  # Transaction relayer
└── README.md
```

### Step 2: Initialize Project

```bash
# Create new Node.js project
mkdir mogaland-backend
cd mogaland-backend
npm init -y

# Install dependencies
npm install ethers dotenv express
npm install --save-dev nodemon

# Create .env file
touch .env

# Add to .gitignore
echo ".env" >> .gitignore
echo "node_modules/" >> .gitignore
```

### Step 3: Configure .env File

Create `.env` file (⚠️ NEVER commit this):

```env
# Sepolia RPC URL
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY

# Private Key (⚠️ DEVELOPMENT WALLET ONLY!)
PRIVATE_KEY=your_private_key_here

# Contract Addresses
NFT_CONTRACT=0xa959f26847211f71A22aDb087EBe50E0743e7D66
TREASURY_WALLET=0xa959f26847211f71A22aDb087EBe50E0743e7D66

# App Configuration
PORT=3000
NODE_ENV=development

# ⚠️ WARNING: Only use test wallets with small amounts!
# ⚠️ Never use your main wallet's private key!
```

### Step 4: Create config.js

```javascript
require('dotenv').config();

module.exports = {
  // Network Configuration
  network: {
    rpcUrl: process.env.SEPOLIA_RPC_URL || 'https://rpc.sepolia.org',
    chainId: 11155111,
    name: 'Sepolia'
  },
  
  // Wallet Configuration
  wallet: {
    privateKey: process.env.PRIVATE_KEY
  },
  
  // Contract Addresses
  contracts: {
    nft: process.env.NFT_CONTRACT,
    treasury: process.env.TREASURY_WALLET
  },
  
  // Server Configuration
  server: {
    port: process.env.PORT || 3000,
    env: process.env.NODE_ENV || 'development'
  }
};
```

---

## 🔧 Backend Implementation Examples

### Example 1: Read Balance (Safe)

```javascript
const ethers = require('ethers');
const config = require('./config');

async function getBalance(address) {
  try {
    // Create provider
    const provider = new ethers.providers.JsonRpcProvider(config.network.rpcUrl);
    
    // Get balance (READ-ONLY, no private key needed)
    const balanceWei = await provider.getBalance(address);
    const balanceEth = ethers.utils.formatEther(balanceWei);
    
    console.log(`Balance: ${balanceEth} ETH`);
    return balanceEth;
    
  } catch (error) {
    console.error('Error getting balance:', error);
    throw error;
  }
}

// Usage
getBalance('0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb0')
  .then(balance => console.log('ETH Balance:', balance));
```

### Example 2: Send Transaction (Backend Only)

```javascript
const ethers = require('ethers');
const config = require('./config');

async function sendETH(toAddress, amountEth) {
  try {
    // ⚠️ THIS SHOULD ONLY RUN ON SECURE BACKEND SERVER
    
    // Create provider
    const provider = new ethers.providers.JsonRpcProvider(config.network.rpcUrl);
    
    // Create wallet from private key
    const wallet = new ethers.Wallet(config.wallet.privateKey, provider);
    
    // Check balance
    const balance = await wallet.getBalance();
    const requiredAmount = ethers.utils.parseEther(amountEth);
    
    if (balance.lt(requiredAmount)) {
      throw new Error('Insufficient balance');
    }
    
    // Send transaction
    const tx = await wallet.sendTransaction({
      to: toAddress,
      value: requiredAmount,
      // Gas settings (optional)
      gasLimit: 21000,
      gasPrice: await provider.getGasPrice()
    });
    
    console.log('Transaction sent:', tx.hash);
    
    // Wait for confirmation
    const receipt = await tx.wait();
    console.log('Transaction confirmed:', receipt.transactionHash);
    
    return receipt;
    
  } catch (error) {
    console.error('Error sending ETH:', error);
    throw error;
  }
}
```

### Example 3: Treasury Management Service

```javascript
// services/treasury.js
const ethers = require('ethers');
const config = require('../config');

class TreasuryService {
  constructor() {
    this.provider = new ethers.providers.JsonRpcProvider(config.network.rpcUrl);
    this.wallet = new ethers.Wallet(config.wallet.privateKey, this.provider);
  }
  
  async getBalance() {
    const balance = await this.wallet.getBalance();
    return ethers.utils.formatEther(balance);
  }
  
  async withdrawTo(recipientAddress, amount) {
    // ⚠️ Add authentication/authorization checks here!
    
    const tx = await this.wallet.sendTransaction({
      to: recipientAddress,
      value: ethers.utils.parseEther(amount)
    });
    
    return await tx.wait();
  }
  
  async distributeRewards(recipients, amounts) {
    // Batch process rewards distribution
    const transactions = [];
    
    for (let i = 0; i < recipients.length; i++) {
      const tx = await this.wallet.sendTransaction({
        to: recipients[i],
        value: ethers.utils.parseEther(amounts[i])
      });
      
      transactions.push(tx);
      
      // Wait for confirmation before next tx
      await tx.wait();
    }
    
    return transactions;
  }
}

module.exports = TreasuryService;
```

### Example 4: Express API Server

```javascript
// src/index.js
const express = require('express');
const ethers = require('ethers');
const config = require('./config');

const app = express();
app.use(express.json());

// Read-only endpoint (safe for public access)
app.get('/api/balance/:address', async (req, res) => {
  try {
    const provider = new ethers.providers.JsonRpcProvider(config.network.rpcUrl);
    const balance = await provider.getBalance(req.params.address);
    
    res.json({
      address: req.params.address,
      balance: ethers.utils.formatEther(balance),
      network: 'Sepolia'
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ⚠️ Protected endpoint (requires authentication)
app.post('/api/admin/send', async (req, res) => {
  // ⚠️ MUST add authentication middleware here!
  // Never expose this endpoint without proper security!
  
  try {
    const { to, amount } = req.body;
    
    // Validate input
    if (!ethers.utils.isAddress(to)) {
      return res.status(400).json({ error: 'Invalid address' });
    }
    
    const provider = new ethers.providers.JsonRpcProvider(config.network.rpcUrl);
    const wallet = new ethers.Wallet(config.wallet.privateKey, provider);
    
    const tx = await wallet.sendTransaction({
      to: to,
      value: ethers.utils.parseEther(amount)
    });
    
    const receipt = await tx.wait();
    
    res.json({
      success: true,
      txHash: receipt.transactionHash
    });
    
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(config.server.port, () => {
  console.log(`Backend server running on port ${config.server.port}`);
});
```

---

## 🔐 Security Best Practices

### 1. Private Key Management

```javascript
// ✅ GOOD: Load from environment
const privateKey = process.env.PRIVATE_KEY;

// ❌ BAD: Hardcoded in code
const privateKey = "0x1234..."; // NEVER DO THIS!
```

### 2. Use Dedicated Wallets

```javascript
// ✅ GOOD: Use separate wallets for different purposes
const developmentWallet = process.env.DEV_PRIVATE_KEY;
const productionWallet = process.env.PROD_PRIVATE_KEY;

// ❌ BAD: Using your personal wallet
// Don't risk your main funds!
```

### 3. Add Authentication

```javascript
// ✅ GOOD: Protect admin endpoints
const authenticateAdmin = (req, res, next) => {
  const apiKey = req.headers['x-api-key'];
  
  if (apiKey !== process.env.ADMIN_API_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  next();
};

app.post('/api/admin/send', authenticateAdmin, async (req, res) => {
  // Protected endpoint
});
```

### 4. Rate Limiting

```javascript
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

app.use('/api/', limiter);
```

### 5. Input Validation

```javascript
// ✅ GOOD: Validate all inputs
function validateSendRequest(to, amount) {
  if (!ethers.utils.isAddress(to)) {
    throw new Error('Invalid address');
  }
  
  const amountNum = parseFloat(amount);
  if (isNaN(amountNum) || amountNum <= 0) {
    throw new Error('Invalid amount');
  }
  
  if (amountNum > 10) { // Max 10 ETH per transaction
    throw new Error('Amount exceeds limit');
  }
  
  return true;
}
```

---

## 📝 .gitignore Example

```gitignore
# Environment variables (⚠️ CRITICAL!)
.env
.env.local
.env.development
.env.production

# Node modules
node_modules/

# Logs
logs/
*.log

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Build
dist/
build/
```

---

## 🧪 Testing Backend

```javascript
// test/treasury.test.js
const TreasuryService = require('../services/treasury');

describe('Treasury Service', () => {
  let treasury;
  
  beforeEach(() => {
    // Use testnet wallet for testing
    process.env.PRIVATE_KEY = 'test_private_key';
    treasury = new TreasuryService();
  });
  
  it('should get balance', async () => {
    const balance = await treasury.getBalance();
    expect(balance).toBeDefined();
  });
  
  // Add more tests...
});
```

---

## ⚠️ REMEMBER

### For Your Web Application:
✅ **Use MetaMask** for all user transactions
✅ **Use WalletConnect** for mobile wallet support
✅ **Never store** private keys in frontend
✅ **Always request** user confirmation for transactions
✅ **Display gas fees** before confirmation

### For Backend Services:
✅ **Use .env** for configuration
✅ **Add .env to .gitignore** immediately
✅ **Use test wallets** with small amounts
✅ **Add authentication** to all admin endpoints
✅ **Validate all inputs** thoroughly
✅ **Log all transactions** for auditing
✅ **Monitor for** suspicious activity

---

## 📚 Additional Resources

- **Ethers.js Docs:** https://docs.ethers.org/
- **Node.js Security:** https://nodejs.org/en/docs/guides/security/
- **Express Security:** https://expressjs.com/en/advanced/best-practice-security.html
- **dotenv:** https://github.com/motdotla/dotenv

---

## ✅ Final Checklist

Before deploying backend:
- [ ] All private keys in .env
- [ ] .env added to .gitignore
- [ ] Authentication on admin endpoints
- [ ] Rate limiting implemented
- [ ] Input validation on all endpoints
- [ ] Using testnet for development
- [ ] Monitoring/logging set up
- [ ] Error handling implemented
- [ ] Documentation complete

---

## 🎯 Summary

**Your Web Application:**
- ✅ Already uses MetaMask (correct approach)
- ✅ No private keys in frontend
- ✅ Users control their own funds
- ✅ Secure and decentralized

**Backend (If Needed):**
- ⚠️ Only for automated tasks
- ⚠️ Requires secure server environment
- ⚠️ Never expose private keys
- ⚠️ Implement strong authentication

**The pattern you shared is valid for backend services but should NEVER be used in your web frontend!**

**Your current implementation is correct - keep using MetaMask! 🦊✅**
