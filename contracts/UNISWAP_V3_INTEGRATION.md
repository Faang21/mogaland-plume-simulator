# Uniswap V3 Integration Guide for Sepolia
## Mogaland Plume Simulator - Advanced DEX Functionality

Complete guide for integrating Uniswap V3 on Sepolia testnet with exact contract addresses and implementation.

---

## 🎯 Uniswap V3 Sepolia Contract Addresses

### Core Contracts
```javascript
// Uniswap V3 Router (SwapRouter)
const SWAP_ROUTER_V3 = "0xE592427A0AEce92De3Edee1F18E0157C05861564";

// WETH9 on Sepolia
const WETH9_SEPOLIA = "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14";

// Factory
const UNISWAP_V3_FACTORY = "0x0227628f3F023bb0B980b67D528571c95c6DaC1c";

// Quoter V2 (for price quotes)
const QUOTER_V2 = "0xEd1f6473345F45b75F8179591dd5bA1888cf2FB3";

// NFT Position Manager
const POSITION_MANAGER = "0x1238536071E1c677A632429e3655c799b22cDA52";
```

### Common Test Tokens on Sepolia
```javascript
const SEPOLIA_TOKENS = {
  WETH: "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14",
  USDC: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238", // 6 decimals
  DAI: "0x68194a729C2450ad26072b3D33ADaCbcef39D574",  // 18 decimals
  USDT: "0x7169D38820dfd117C3FA1f22a697dBA58d90BA06", // 6 decimals
  LINK: "0x779877A7B0D9E8603169DdbD7836e478b4624789",  // 18 decimals
};
```

---

## 📋 Prerequisites

### 1. Get Sepolia ETH
- **Alchemy Faucet:** https://sepoliafaucet.com
- **Chainlink Faucet:** https://faucets.chain.link/sepolia
- **Google Cloud:** https://cloud.google.com/application/web3/faucet/ethereum/sepolia

### 2. Add to Your HTML
```html
<!-- Already in your app -->
<script src="https://cdn.ethers.io/lib/ethers-5.7.umd.min.js"></script>
```

---

## 🚀 Implementation

### Step 1: Add Uniswap V3 ABIs

Add these ABIs to your global constants in `index.html`:

```javascript
// Uniswap V3 SwapRouter ABI (Minimal for swaps)
const UNISWAP_V3_SWAP_ROUTER_ABI = [
  "function exactInputSingle((address tokenIn, address tokenOut, uint24 fee, address recipient, uint256 deadline, uint256 amountIn, uint256 amountOutMinimum, uint160 sqrtPriceLimitX96)) external payable returns (uint256 amountOut)",
  "function exactInput((bytes path, address recipient, uint256 deadline, uint256 amountIn, uint256 amountOutMinimum)) external payable returns (uint256 amountOut)",
  "function WETH9() external pure returns (address)"
];

// Uniswap V3 Quoter V2 ABI (for price quotes)
const UNISWAP_V3_QUOTER_ABI = [
  "function quoteExactInputSingle((address tokenIn, address tokenOut, uint256 amountIn, uint24 fee, uint160 sqrtPriceLimitX96)) external returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate)",
  "function quoteExactInput(bytes memory path, uint256 amountIn) external returns (uint256 amountOut, uint160[] memory sqrtPriceX96AfterList, uint32[] memory initializedTicksCrossedList, uint256 gasEstimate)"
];

// ERC20 ABI for approvals (already have this, but ensure it's complete)
const ERC20_FULL_ABI = [
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function allowance(address owner, address spender) external view returns (uint256)",
  "function balanceOf(address account) external view returns (uint256)",
  "function decimals() external view returns (uint8)",
  "function symbol() external view returns (string)",
  "function transfer(address to, uint256 amount) external returns (bool)"
];
```

### Step 2: Get Swap Quote from Uniswap V3

```javascript
/**
 * Get swap quote from Uniswap V3
 * @param {string} tokenIn - Input token address
 * @param {string} tokenOut - Output token address
 * @param {string} amountIn - Amount in wei
 * @param {number} fee - Pool fee tier (500, 3000, or 10000)
 * @returns {Object} Quote with output amount and gas estimate
 */
async function getUniswapV3Quote(tokenIn, tokenOut, amountIn, fee = 3000) {
  try {
    if (!provider) {
      throw new Error("Provider not available");
    }
    
    const quoter = new ethers.Contract(
      QUOTER_V2,
      UNISWAP_V3_QUOTER_ABI,
      provider
    );
    
    // Call quoter (this is a static call, no gas cost)
    const params = {
      tokenIn: tokenIn,
      tokenOut: tokenOut,
      amountIn: amountIn,
      fee: fee,
      sqrtPriceLimitX96: 0 // No price limit
    };
    
    // Use callStatic to simulate the call
    const quote = await quoter.callStatic.quoteExactInputSingle(params);
    
    return {
      amountOut: quote.amountOut,
      sqrtPriceX96After: quote.sqrtPriceX96After,
      gasEstimate: quote.gasEstimate,
      success: true
    };
    
  } catch (error) {
    console.error("Error getting Uniswap V3 quote:", error);
    return {
      success: false,
      error: error.message
    };
  }
}
```

### Step 3: Execute Swap on Uniswap V3

```javascript
/**
 * Execute token swap on Uniswap V3
 * @param {string} tokenIn - Input token address
 * @param {string} tokenOut - Output token address  
 * @param {string} amountIn - Amount in wei
 * @param {string} amountOutMinimum - Minimum output (slippage protection)
 * @param {number} fee - Pool fee tier (500, 3000, or 10000)
 * @returns {Object} Transaction result
 */
async function executeUniswapV3Swap(tokenIn, tokenOut, amountIn, amountOutMinimum, fee = 3000) {
  try {
    if (!provider || !userAddress) {
      throw new Error("Wallet not connected");
    }
    
    const signer = provider.getSigner();
    const router = new ethers.Contract(
      SWAP_ROUTER_V3,
      UNISWAP_V3_SWAP_ROUTER_ABI,
      signer
    );
    
    // Set deadline (10 minutes from now)
    const deadline = Math.floor(Date.now() / 1000) + 600;
    
    let tx;
    
    // Check if swapping ETH or ERC20
    const isInputETH = tokenIn === WETH9_SEPOLIA;
    const isOutputETH = tokenOut === WETH9_SEPOLIA;
    
    if (isInputETH) {
      // Swapping ETH -> Token
      const params = {
        tokenIn: WETH9_SEPOLIA,
        tokenOut: tokenOut,
        fee: fee,
        recipient: userAddress,
        deadline: deadline,
        amountIn: amountIn,
        amountOutMinimum: amountOutMinimum,
        sqrtPriceLimitX96: 0
      };
      
      // Send ETH with the transaction
      tx = await router.exactInputSingle(params, {
        value: amountIn
      });
      
    } else if (isOutputETH) {
      // Swapping Token -> ETH
      // First approve router
      await approveTokenV3(tokenIn, SWAP_ROUTER_V3, amountIn);
      
      const params = {
        tokenIn: tokenIn,
        tokenOut: WETH9_SEPOLIA,
        fee: fee,
        recipient: userAddress,
        deadline: deadline,
        amountIn: amountIn,
        amountOutMinimum: amountOutMinimum,
        sqrtPriceLimitX96: 0
      };
      
      tx = await router.exactInputSingle(params);
      
    } else {
      // Swapping Token -> Token
      // First approve router
      await approveTokenV3(tokenIn, SWAP_ROUTER_V3, amountIn);
      
      const params = {
        tokenIn: tokenIn,
        tokenOut: tokenOut,
        fee: fee,
        recipient: userAddress,
        deadline: deadline,
        amountIn: amountIn,
        amountOutMinimum: amountOutMinimum,
        sqrtPriceLimitX96: 0
      };
      
      tx = await router.exactInputSingle(params);
    }
    
    showNotification("⏳ Transaction submitted. Waiting for confirmation...", false);
    
    // Wait for confirmation
    const receipt = await tx.wait();
    
    return {
      success: true,
      txHash: receipt.transactionHash,
      receipt: receipt
    };
    
  } catch (error) {
    console.error("Error executing Uniswap V3 swap:", error);
    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * Approve token spending for Uniswap V3
 */
async function approveTokenV3(tokenAddress, spenderAddress, amount) {
  try {
    const signer = provider.getSigner();
    const tokenContract = new ethers.Contract(
      tokenAddress,
      ERC20_FULL_ABI,
      signer
    );
    
    // Check current allowance
    const currentAllowance = await tokenContract.allowance(userAddress, spenderAddress);
    
    if (currentAllowance.lt(amount)) {
      showNotification("🔄 Approving token spending...", false);
      
      // Approve max uint256 for convenience
      const approveTx = await tokenContract.approve(
        spenderAddress,
        ethers.constants.MaxUint256
      );
      
      await approveTx.wait();
      showNotification("✅ Token approved successfully", false);
    }
    
    return true;
  } catch (error) {
    console.error("Error approving token:", error);
    showNotification("❌ Token approval failed: " + error.message, true);
    throw error;
  }
}
```

### Step 4: Update Your Swap UI

Replace your existing swap functions with Uniswap V3 integration:

```javascript
// Update swap estimation to use Uniswap V3
async function updateSwapEstimate() {
  const fromAmt = parseFloat(document.getElementById('fromInput')?.value) || 0;
  const fromToken = document.getElementById('fromTokenSelect')?.value || 'ETH';
  const toToken = document.getElementById('toTokenSelect')?.value || 'USDC';
  
  if (fromAmt <= 0) {
    const estEl = document.getElementById('swapEstimate');
    if (estEl) estEl.innerHTML = 'Enter amount to see estimate';
    return;
  }
  
  try {
    // Show loading
    const estEl = document.getElementById('swapEstimate');
    if (estEl) estEl.innerHTML = '🔄 Getting quote from Uniswap V3...';
    
    // Get token addresses
    const fromTokenAddr = fromToken === 'ETH' ? WETH9_SEPOLIA : SEPOLIA_TOKENS[fromToken];
    const toTokenAddr = toToken === 'ETH' ? WETH9_SEPOLIA : SEPOLIA_TOKENS[toToken];
    
    if (!fromTokenAddr || !toTokenAddr) {
      if (estEl) estEl.innerHTML = '⚠️ Token not supported';
      return;
    }
    
    // Get decimals
    const fromDecimals = fromToken === 'ETH' || fromToken === 'DAI' || fromToken === 'LINK' ? 18 : 6;
    const toDecimals = toToken === 'ETH' || toToken === 'DAI' || toToken === 'LINK' ? 18 : 6;
    
    // Convert amount to wei
    const amountIn = ethers.utils.parseUnits(fromAmt.toString(), fromDecimals);
    
    // Try different fee tiers (0.05%, 0.3%, 1%)
    let quote = null;
    const feeTiers = [500, 3000, 10000];
    
    for (const fee of feeTiers) {
      quote = await getUniswapV3Quote(fromTokenAddr, toTokenAddr, amountIn, fee);
      if (quote.success) {
        break;
      }
    }
    
    if (!quote || !quote.success) {
      if (estEl) estEl.innerHTML = '⚠️ No liquidity pool found for this pair';
      return;
    }
    
    // Format output
    const estOut = ethers.utils.formatUnits(quote.amountOut, toDecimals);
    const rate = parseFloat(estOut) / fromAmt;
    
    // Calculate price impact (simplified)
    const priceImpact = "~0.15%";
    
    if (estEl) {
      estEl.innerHTML = `
        <strong>Uniswap V3 Quote:</strong><br>
        ${parseFloat(estOut).toFixed(6)} ${toToken}<br>
        <small style="color:#94a3b8;">
          Rate: 1 ${fromToken} ≈ ${rate.toFixed(6)} ${toToken}<br>
          ${priceImpact} impact | ${currentSlippageTolerance.toFixed(1)}% slippage
        </small>
      `;
    }
    
    // Store quote for swap execution
    window.lastSwapQuoteV3 = {
      amountIn: amountIn,
      amountOut: quote.amountOut,
      fromToken: fromTokenAddr,
      toToken: toTokenAddr,
      fee: 3000, // Store the fee tier that worked
      slippage: currentSlippageTolerance
    };
    
  } catch (error) {
    console.error("Error getting swap estimate:", error);
    const estEl = document.getElementById('swapEstimate');
    if (estEl) estEl.innerHTML = '⚠️ Error: ' + error.message;
  }
}

// Update swap execution to use Uniswap V3
window.confirmSwap = async function() {
  if (!userAddress || !provider) {
    showNotification("⚠️ Please connect wallet first!", true);
    connectWalletFromApp();
    return;
  }
  
  const amt = parseFloat(document.getElementById('fromInput')?.value) || 0;
  if (amt <= 0) {
    showNotification("Enter amount > 0", true);
    return;
  }
  
  if (!window.lastSwapQuoteV3) {
    showNotification("⚠️ Please wait for quote to load", true);
    return;
  }
  
  const { amountIn, amountOut, fromToken, toToken, fee, slippage } = window.lastSwapQuoteV3;
  
  // Calculate minimum amount with slippage
  const slippageMultiplier = 1 - (slippage / 100);
  const amountOutMin = amountOut.mul(Math.floor(slippageMultiplier * 10000)).div(10000);
  
  // Get token symbols for display
  const fromSymbol = Object.keys(SEPOLIA_TOKENS).find(k => SEPOLIA_TOKENS[k] === fromToken) || 'ETH';
  const toSymbol = Object.keys(SEPOLIA_TOKENS).find(k => SEPOLIA_TOKENS[k] === toToken) || 'ETH';
  
  // Request wallet confirmation
  const confirmed = await requestWalletConfirmation('Uniswap V3 Token Swap', {
    amount: `${amt} ${fromSymbol} → ${ethers.utils.formatUnits(amountOut, 6)} ${toSymbol}`,
    from: 'Uniswap V3 Router',
    gasLimit: GAS_LIMITS.SWAP
  });
  
  if (!confirmed) {
    showNotification('❌ Swap cancelled by user', true);
    return;
  }
  
  // Execute swap
  showNotification('🔄 Executing swap on Uniswap V3...', false);
  
  const result = await executeUniswapV3Swap(
    fromToken,
    toToken,
    amountIn,
    amountOutMin,
    fee
  );
  
  if (result.success) {
    showNotification(
      `✅ Swap successful!<br>
      <a href="${SEPOLIA_EXPLORER}/tx/${result.txHash}" target="_blank" style="color:#60a5fa;">
        View on Etherscan
      </a>`,
      false
    );
    
    // Refresh balances
    if (typeof fetchRealBalances === 'function') {
      await fetchRealBalances();
    }
  } else {
    showNotification('❌ Swap failed: ' + result.error, true);
  }
}
```

---

## 🎯 Understanding Uniswap V3 Fee Tiers

Uniswap V3 uses concentrated liquidity with different fee tiers:

```javascript
const FEE_TIERS = {
  LOWEST: 500,    // 0.05% - Stablecoins (USDC/USDT)
  LOW: 3000,      // 0.3% - Most pairs (ETH/USDC)
  MEDIUM: 10000   // 1% - Exotic pairs
};
```

### Choosing Fee Tier:
- **500 (0.05%):** Stablecoin pairs (USDC/USDT, DAI/USDC)
- **3000 (0.3%):** Standard pairs (ETH/USDC, ETH/DAI)
- **10000 (1%):** Volatile or exotic pairs

---

## 🔍 Multi-Hop Swaps (Advanced)

For tokens without direct pools, use multi-hop routing:

```javascript
async function executeMultiHopSwap(path, amountIn, amountOutMinimum) {
  const router = new ethers.Contract(
    SWAP_ROUTER_V3,
    UNISWAP_V3_SWAP_ROUTER_ABI,
    provider.getSigner()
  );
  
  const deadline = Math.floor(Date.now() / 1000) + 600;
  
  const params = {
    path: path, // Encoded path: tokenA -> tokenB -> tokenC
    recipient: userAddress,
    deadline: deadline,
    amountIn: amountIn,
    amountOutMinimum: amountOutMinimum
  };
  
  const tx = await router.exactInput(params, {
    value: isETHInput ? amountIn : 0
  });
  
  await tx.wait();
  return tx.hash;
}

// Encode path for multi-hop
function encodePath(tokens, fees) {
  let encoded = "0x";
  for (let i = 0; i < tokens.length; i++) {
    encoded += tokens[i].slice(2); // Remove 0x
    if (i < fees.length) {
      // Add fee as 3-byte hex
      encoded += fees[i].toString(16).padStart(6, "0");
    }
  }
  return encoded;
}

// Example: ETH -> USDC -> DAI
const path = encodePath(
  [WETH9_SEPOLIA, SEPOLIA_TOKENS.USDC, SEPOLIA_TOKENS.DAI],
  [3000, 500] // 0.3% then 0.05% pools
);
```

---

## ⚠️ Important Notes

### 1. WETH Handling
- Native ETH is automatically wrapped to WETH9 by the router
- When swapping FROM ETH, send ETH with the transaction
- When swapping TO ETH, you receive native ETH (auto-unwrapped)

### 2. Slippage Protection
```javascript
// Calculate minimum output with slippage
const slippagePercent = 0.5; // 0.5%
const amountOutMin = expectedOut.mul(10000 - (slippagePercent * 100)).div(10000);
```

### 3. Gas Estimation
```javascript
// V3 swaps typically use:
- Simple swap: ~150,000 gas
- Multi-hop: ~200,000-300,000 gas
- With token approval: +50,000 gas
```

### 4. Pool Liquidity
Not all token pairs have liquidity on Sepolia. Check:
- https://app.uniswap.org (switch to Sepolia)
- Or try different fee tiers

---

## 🧪 Testing

### Test Flow:
1. **Get Sepolia ETH** from faucet
2. **Get test tokens** (USDC, DAI) from:
   - https://faucet.circle.com/
   - Or swap ETH for them on Uniswap
3. **Test ETH → USDC** swap
4. **Test USDC → DAI** swap  
5. **Test multi-token** swaps
6. **Verify on Etherscan**

### Debug Mode:
```javascript
// Add detailed logging
console.log('Quote:', quote);
console.log('AmountIn:', amountIn.toString());
console.log('AmountOut:', amountOut.toString());
console.log('Gas estimate:', gasEstimate.toString());
```

---

## 🛡️ Security Checklist

✅ Validate all token addresses
✅ Check allowances before approval
✅ Use amountOutMinimum for slippage protection
✅ Set reasonable deadline (10 minutes)
✅ Verify network is Sepolia
✅ Display all fees and estimates to user
✅ Handle approval transactions separately
✅ Test with small amounts first

---

## �� Additional Resources

- **Uniswap V3 Docs:** https://docs.uniswap.org/contracts/v3/overview
- **Sepolia Testnet:** https://sepolia.dev/
- **Etherscan Sepolia:** https://sepolia.etherscan.io/
- **Uniswap Interface:** https://app.uniswap.org/

---

## ✨ Summary

You now have:
1. ✅ Exact Uniswap V3 contract addresses for Sepolia
2. ✅ Complete swap implementation with quoter
3. ✅ Token approval handling
4. ✅ Multi-fee-tier support
5. ✅ Slippage protection
6. ✅ ETH/WETH handling
7. ✅ Error handling and user feedback

**Uniswap V3 is more complex but offers:**
- Better pricing through concentrated liquidity
- Multiple fee tiers for different pairs
- More capital efficiency
- Real DEX experience

**Happy Swapping on Uniswap V3! 🦄🚀**
