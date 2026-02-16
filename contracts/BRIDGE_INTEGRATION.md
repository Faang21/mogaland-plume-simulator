# Bridge Integration Guide for ETH Sepolia
## Mogaland Plume Simulator - Cross-Chain Bridge

This guide explains how to integrate real cross-chain bridge functionality into the Mogaland Plume Simulator web application.

---

## 🌉 Overview

### What is a Bridge?
A blockchain bridge allows users to transfer assets (like ETH or tokens) from one blockchain network to another. For example, moving ETH from Sepolia to Base Sepolia or Optimism Sepolia.

### Current Implementation vs. Target
**Current:** Simulated bridge with treasury management
**Target:** Real cross-chain transfers using established bridge protocols

---

## 🎯 Supported Bridge Protocols

### 1. **Across Protocol** (Recommended)
- Fast, low-cost bridging
- Used by Uniswap
- Supports Sepolia testnet
- Great for production-ready apps

### 2. **Superbridge/Optimism SDK**
- Official Optimism bridge
- Move funds to/from Optimism Sepolia
- Well-documented and maintained

### 3. **Base Bridge**
- Official Base (Coinbase L2) bridge
- Sepolia ETH to Base Sepolia
- Integrated with Coinbase ecosystem

### 4. **LayerZero**
- Omnichain messaging protocol
- More complex but very flexible
- Good for advanced use cases

---

## 📋 Prerequisites

### 1. RPC Endpoints
```javascript
// Sepolia (Ethereum Testnet)
const SEPOLIA_RPC = "https://rpc.sepolia.org";
const SEPOLIA_CHAIN_ID = 11155111;

// Base Sepolia (L2)
const BASE_SEPOLIA_RPC = "https://sepolia.base.org";
const BASE_SEPOLIA_CHAIN_ID = 84532;

// Optimism Sepolia (L2)
const OPTIMISM_SEPOLIA_RPC = "https://sepolia.optimism.io";
const OPTIMISM_SEPOLIA_CHAIN_ID = 11155420;

// Arbitrum Sepolia (L2)
const ARBITRUM_SEPOLIA_RPC = "https://sepolia-rollup.arbitrum.io/rpc";
const ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
```

### 2. Get Test ETH
- **Sepolia Faucet:** https://sepoliafaucet.com
- **Base Sepolia Faucet:** https://www.coinbase.com/faucets/base-ethereum-goerli-faucet
- **Optimism Sepolia:** https://app.optimism.io/faucet
- **Arbitrum Sepolia:** https://faucet.quicknode.com/arbitrum/sepolia

---

## 🚀 Implementation Option 1: Across Protocol

### Step 1: Add Across SDK

Add to your `index.html` before closing `</body>` tag:

```html
<!-- Across Protocol SDK -->
<script src="https://unpkg.com/@across-protocol/sdk@latest/dist/across-sdk.umd.js"></script>
```

### Step 2: Bridge Contract Addresses (Sepolia)

```javascript
// Across Protocol Contracts on Sepolia
const ACROSS_SPOKE_POOL_SEPOLIA = "0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5";

// Supported L2 networks
const SUPPORTED_CHAINS = {
  SEPOLIA: {
    chainId: 11155111,
    name: "Ethereum Sepolia",
    spokePool: "0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5",
    rpc: "https://rpc.sepolia.org"
  },
  BASE_SEPOLIA: {
    chainId: 84532,
    name: "Base Sepolia",
    spokePool: "0x82B564983aE7274c86695917BBf8C99ECb6F0F8F",
    rpc: "https://sepolia.base.org"
  },
  OPTIMISM_SEPOLIA: {
    chainId: 11155420,
    name: "Optimism Sepolia",
    spokePool: "0x13fDa8ae5F446c6E93e4e86Eb45Aa857F092FE1c",
    rpc: "https://sepolia.optimism.io"
  }
};
```

### Step 3: Create Bridge Helper Functions

```javascript
// Get bridge quote (estimated time and fees)
async function getBridgeQuote(fromChain, toChain, amount) {
  try {
    if (!provider) {
      console.error("Provider not available");
      return null;
    }
    
    const fromChainConfig = SUPPORTED_CHAINS[fromChain];
    const toChainConfig = SUPPORTED_CHAINS[toChain];
    
    if (!fromChainConfig || !toChainConfig) {
      throw new Error("Unsupported chain");
    }
    
    // Convert amount to wei
    const amountWei = ethers.utils.parseEther(amount.toString());
    
    // Get suggested fees (simplified for this example)
    // In production, use Across API: https://across.to/api/suggested-fees
    const estimatedTime = "5-10 minutes"; // Typical Across bridge time
    const estimatedFee = amountWei.mul(10).div(10000); // 0.1% fee
    const totalAmount = amountWei.add(estimatedFee);
    
    return {
      fromChain: fromChainConfig.name,
      toChain: toChainConfig.name,
      amount: ethers.utils.formatEther(amountWei),
      fee: ethers.utils.formatEther(estimatedFee),
      total: ethers.utils.formatEther(totalAmount),
      estimatedTime: estimatedTime
    };
  } catch (error) {
    console.error("Error getting bridge quote:", error);
    return null;
  }
}

// Execute bridge transaction using Across Protocol
async function executeBridge(fromChain, toChain, amount) {
  try {
    if (!provider || !userAddress) {
      throw new Error("Wallet not connected");
    }
    
    const signer = provider.getSigner();
    const fromChainConfig = SUPPORTED_CHAINS[fromChain];
    const toChainConfig = SUPPORTED_CHAINS[toChain];
    
    // Verify we're on the correct network
    const network = await provider.getNetwork();
    if (network.chainId !== fromChainConfig.chainId) {
      // Request network switch
      await switchNetwork(fromChainConfig.chainId);
    }
    
    // Spoke Pool ABI (minimal for deposits)
    const spokePoolABI = [
      "function deposit(address recipient, address originToken, uint256 amount, uint256 destinationChainId, int64 relayerFeePct, uint32 quoteTimestamp) payable"
    ];
    
    const spokePool = new ethers.Contract(
      fromChainConfig.spokePool,
      spokePoolABI,
      signer
    );
    
    // Convert amount to wei
    const amountWei = ethers.utils.parseEther(amount.toString());
    
    // Calculate relayer fee (0.1% = 100 basis points)
    const relayerFeePct = ethers.BigNumber.from("100"); // 0.1%
    
    // Get current timestamp
    const quoteTimestamp = Math.floor(Date.now() / 1000);
    
    // Execute deposit (bridge)
    const tx = await spokePool.deposit(
      userAddress, // recipient
      ethers.constants.AddressZero, // ETH is represented as zero address
      amountWei,
      toChainConfig.chainId,
      relayerFeePct,
      quoteTimestamp,
      { value: amountWei } // Send ETH with transaction
    );
    
    // Wait for confirmation
    const receipt = await tx.wait();
    
    return {
      success: true,
      txHash: receipt.transactionHash,
      fromChain: fromChainConfig.name,
      toChain: toChainConfig.name,
      amount: amount
    };
    
  } catch (error) {
    console.error("Error executing bridge:", error);
    return {
      success: false,
      error: error.message
    };
  }
}

// Switch network in MetaMask
async function switchNetwork(chainId) {
  try {
    await window.ethereum.request({
      method: 'wallet_switchEthereumChain',
      params: [{ chainId: ethers.utils.hexValue(chainId) }],
    });
  } catch (switchError) {
    // Chain not added to MetaMask
    if (switchError.code === 4902) {
      const chainConfig = Object.values(SUPPORTED_CHAINS).find(c => c.chainId === chainId);
      if (chainConfig) {
        await window.ethereum.request({
          method: 'wallet_addEthereumChain',
          params: [{
            chainId: ethers.utils.hexValue(chainId),
            chainName: chainConfig.name,
            nativeCurrency: { name: 'ETH', symbol: 'ETH', decimals: 18 },
            rpcUrls: [chainConfig.rpc],
            blockExplorerUrls: [chainConfig.explorer || '']
          }],
        });
      }
    } else {
      throw switchError;
    }
  }
}

// Check bridge status (simplified)
async function checkBridgeStatus(txHash, fromChain) {
  try {
    // In production, use Across API to track bridge status
    // https://across.to/api/deposits/status?hash={txHash}
    
    const fromChainConfig = SUPPORTED_CHAINS[fromChain];
    const explorerUrl = fromChainConfig.explorer || `https://sepolia.etherscan.io`;
    
    return {
      status: "pending",
      message: "Bridge in progress. This may take 5-10 minutes.",
      explorerLink: `${explorerUrl}/tx/${txHash}`
    };
  } catch (error) {
    console.error("Error checking bridge status:", error);
    return null;
  }
}
```

### Step 4: Update Bridge UI Function

Replace the existing `confirmBridge` function in your `index.html`:

```javascript
window.confirmBridge = async function() {
  // Check wallet connection
  if (!userAddress || !provider) {
    showNotification("⚠️ Please connect wallet first!", true);
    connectWalletFromApp();
    return;
  }
  
  const amount = parseFloat(document.getElementById('bridgeAmount')?.value || 0);
  const fromChainSelect = document.getElementById('fromChain');
  const toChainSelect = document.getElementById('toChain');
  
  if (!fromChainSelect || !toChainSelect) {
    showNotification("⚠️ Please select source and destination chains", true);
    return;
  }
  
  const fromChain = fromChainSelect.value;
  const toChain = toChainSelect.value;
  
  if (amount <= 0) {
    showNotification('Please enter an amount to bridge', true);
    return;
  }
  
  if (fromChain === toChain) {
    showNotification('⚠️ Source and destination chains must be different', true);
    return;
  }
  
  try {
    // Get quote
    showNotification('🔄 Getting bridge quote...', false);
    const quote = await getBridgeQuote(fromChain, toChain, amount);
    
    if (!quote) {
      showNotification('⚠️ Unable to get bridge quote', true);
      return;
    }
    
    // Request wallet confirmation
    const confirmed = await requestWalletConfirmation('Bridge Tokens (Across Protocol)', {
      amount: `${amount} ETH`,
      from: quote.fromChain,
      to: quote.toChain,
      gasLimit: GAS_LIMITS.BRIDGE
    });
    
    if (!confirmed) {
      showNotification('❌ Bridge cancelled by user', true);
      return;
    }
    
    // Execute bridge
    showNotification('🌉 Initiating bridge transaction...', false);
    const result = await executeBridge(fromChain, toChain, amount);
    
    if (result.success) {
      showNotification(
        `✅ Bridge transaction submitted!<br>
        ${result.amount} ETH from ${result.fromChain} to ${result.toChain}<br>
        <small>Estimated time: 5-10 minutes</small><br>
        <a href="https://sepolia.etherscan.io/tx/${result.txHash}" target="_blank" style="color:#60a5fa;">
          View on Etherscan
        </a>`,
        false
      );
      
      // Optionally check status after delay
      setTimeout(async () => {
        const status = await checkBridgeStatus(result.txHash, fromChain);
        if (status) {
          showNotification(status.message, false);
        }
      }, 30000); // Check after 30 seconds
      
      // Refresh balances
      if (typeof fetchRealBalances === 'function') {
        await fetchRealBalances();
      }
    } else {
      showNotification('❌ Bridge failed: ' + result.error, true);
    }
    
  } catch (error) {
    console.error('Bridge error:', error);
    showNotification('❌ Bridge transaction failed: ' + error.message, true);
  }
}
```

### Step 5: Update Bridge UI to Show Real Networks

Update your bridge section HTML to include real L2 options:

```html
<select id="fromChain" style="...">
  <option value="SEPOLIA">Ethereum Sepolia</option>
  <option value="BASE_SEPOLIA">Base Sepolia</option>
  <option value="OPTIMISM_SEPOLIA">Optimism Sepolia</option>
</select>

<select id="toChain" style="...">
  <option value="BASE_SEPOLIA">Base Sepolia</option>
  <option value="OPTIMISM_SEPOLIA">Optimism Sepolia</option>
  <option value="SEPOLIA">Ethereum Sepolia</option>
</select>
```

---

## 🚀 Implementation Option 2: Official L2 Bridges

### Optimism SDK (For Optimism Sepolia)

#### Step 1: Install Dependencies (for build systems)
```bash
npm install @eth-optimism/sdk ethers
```

#### Step 2: Bridge to Optimism
```javascript
const { CrossChainMessenger, MessageStatus } = require('@eth-optimism/sdk');

async function bridgeToOptimism(amount) {
  const l1Provider = new ethers.providers.JsonRpcProvider("https://rpc.sepolia.org");
  const l2Provider = new ethers.providers.JsonRpcProvider("https://sepolia.optimism.io");
  
  const l1Signer = provider.getSigner(); // Your connected wallet
  
  const messenger = new CrossChainMessenger({
    l1ChainId: 11155111, // Sepolia
    l2ChainId: 11155420, // Optimism Sepolia
    l1SignerOrProvider: l1Signer,
    l2SignerOrProvider: l2Provider,
  });
  
  // Deposit ETH to L2
  const tx = await messenger.depositETH(ethers.utils.parseEther(amount));
  await tx.wait();
  
  // Wait for L2 confirmation (takes ~1 minute)
  await messenger.waitForMessageStatus(tx.hash, MessageStatus.RELAYED);
  
  return tx.hash;
}
```

### Base Bridge (For Base Sepolia)

#### Use Base's Native Bridge Contract
```javascript
const BASE_BRIDGE_ADDRESS = "0x49048044D57e1C92A77f79988d21Fa8fAF74E97e";

async function bridgeToBase(amount) {
  const baseBridgeABI = [
    "function depositETH(uint32 _minGasLimit, bytes calldata _extraData) payable"
  ];
  
  const bridge = new ethers.Contract(
    BASE_BRIDGE_ADDRESS,
    baseBridgeABI,
    provider.getSigner()
  );
  
  const amountWei = ethers.utils.parseEther(amount.toString());
  
  const tx = await bridge.depositETH(
    200000, // min gas limit on L2
    "0x", // extra data (empty for simple transfers)
    { value: amountWei }
  );
  
  await tx.wait();
  return tx.hash;
}
```

---

## 🔍 Bridge Status Tracking

### Using Across API

```javascript
async function trackAcrossBridge(depositId) {
  try {
    const response = await fetch(
      `https://across.to/api/deposits/status?depositId=${depositId}`
    );
    const data = await response.json();
    
    return {
      status: data.status, // pending, filled, finalized
      fillTx: data.fillTx, // Transaction hash on destination chain
      fillTime: data.fillTime
    };
  } catch (error) {
    console.error("Error tracking bridge:", error);
    return null;
  }
}
```

### Display Bridge History

```javascript
async function displayBridgeHistory() {
  if (!userAddress) return;
  
  const historyContainer = document.getElementById('bridgeHistory');
  historyContainer.innerHTML = '<h3>Bridge History</h3>';
  
  // Fetch from localStorage or API
  const history = JSON.parse(localStorage.getItem('bridgeHistory') || '[]');
  
  history.forEach(item => {
    const div = document.createElement('div');
    div.innerHTML = `
      <div style="padding: 12px; border: 1px solid #334155; border-radius: 8px; margin: 8px 0;">
        <strong>${item.amount} ETH</strong><br>
        ${item.fromChain} → ${item.toChain}<br>
        Status: ${item.status}<br>
        <a href="https://sepolia.etherscan.io/tx/${item.txHash}" target="_blank">View TX</a>
      </div>
    `;
    historyContainer.appendChild(div);
  });
}
```

---

## ⚠️ Important Considerations

### 1. Bridge Times
- **L1 → L2:** Usually 1-10 minutes
- **L2 → L1:** Can take 7 days for finality (security period)
- **L2 → L2:** Usually 5-15 minutes via Across

### 2. Gas Costs
```
Sepolia → Base: ~0.0005-0.002 ETH
Sepolia → Optimism: ~0.0005-0.002 ETH
L2 → L1: Higher (~0.005-0.01 ETH on testnet)
```

### 3. Minimum Amounts
Most bridges have minimum transfer amounts:
- Across: Usually 0.001 ETH minimum
- Native bridges: Varies by L2

### 4. Network Switching
Always verify the user is on the correct network before executing bridge transactions:

```javascript
const currentChainId = (await provider.getNetwork()).chainId;
if (currentChainId !== expectedChainId) {
  await switchNetwork(expectedChainId);
}
```

---

## 🧪 Testing Your Bridge

### Test Flow:
1. **Get Sepolia ETH** from faucet
2. **Connect wallet** to app
3. **Select networks** (e.g., Sepolia → Base Sepolia)
4. **Enter amount** (start with 0.01 ETH)
5. **Review quote** (fees, time estimate)
6. **Confirm transaction** in MetaMask
7. **Wait for bridge** (monitor status)
8. **Switch to destination network** in MetaMask
9. **Verify balance** increased on L2

### Verify on Explorer:
- **Sepolia:** https://sepolia.etherscan.io
- **Base Sepolia:** https://sepolia.basescan.org
- **Optimism Sepolia:** https://sepolia-optimism.etherscan.io

---

## 🛡️ Security Best Practices

✅ **Verify bridge contracts** - Only use official addresses
✅ **Check allowances** - For ERC-20 tokens
✅ **Validate chain IDs** - Ensure correct network
✅ **Display all fees** - Show users total cost
✅ **Set reasonable limits** - Min/max transfer amounts
✅ **Handle errors gracefully** - Don't lose user funds
✅ **Test thoroughly** - Use testnet before mainnet
✅ **Monitor bridge status** - Keep users informed

---

## 📚 Additional Resources

### Documentation
- **Across Protocol:** https://docs.across.to/
- **Optimism Bridge:** https://docs.optimism.io/builders/app-developers/bridging/standard-bridge
- **Base Bridge:** https://docs.base.org/tools/bridges
- **LayerZero:** https://layerzero.network/developers

### Tools
- **Across SDK:** https://github.com/across-protocol/sdk
- **Optimism SDK:** https://github.com/ethereum-optimism/optimism
- **Bridge Aggregators:** https://socket.tech/ (for multi-bridge support)

### Faucets
- **Sepolia:** https://sepoliafaucet.com
- **Base Sepolia:** https://www.coinbase.com/faucets/base-ethereum-goerli-faucet
- **Optimism Sepolia:** https://app.optimism.io/faucet

---

## 🚀 Production Deployment

### Before Mainnet:
1. ✅ Thoroughly test on all testnets
2. ✅ Verify all contract addresses
3. ✅ Implement proper error handling
4. ✅ Add bridge status tracking
5. ✅ Set up monitoring/alerts
6. ✅ Document user flows
7. ✅ Prepare support documentation

### Mainnet Considerations:
- Use mainnet contract addresses
- Monitor gas prices (much higher on mainnet)
- Implement fee estimation
- Add slippage protection
- Consider insurance/guarantees
- Set up customer support

---

## ✨ Summary

This guide provides multiple options for integrating real bridge functionality:

1. **Across Protocol** - Best for production, fast, reliable
2. **Native L2 Bridges** - Official bridges for specific L2s
3. **Custom Implementation** - Full control but more complex

Choose based on your needs:
- **Quick start?** → Use Across Protocol
- **Specific L2?** → Use native bridge
- **Full control?** → Build custom solution

**Happy Bridging! 🌉🚀**
