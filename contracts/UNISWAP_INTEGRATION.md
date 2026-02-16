# Uniswap V2 Integration Guide
## Mogaland Plume Simulator - Web Application

This guide explains how to integrate real Uniswap V2 token swapping into the web-based Mogaland Plume Simulator.

---

## Understanding the Current vs. Target Implementation

### Current Implementation (Simulated)
- Swap uses hardcoded exchange rates
- Transactions processed through treasury
- No real blockchain swap execution

### Target Implementation (Uniswap V2)
- Real token swaps via Uniswap V2 Router
- Live price discovery from liquidity pools
- Actual blockchain transactions
- Slippage protection

---

## Uniswap V2 on Sepolia Testnet

### Contract Addresses (Sepolia)

```javascript
// Uniswap V2 Core Contracts on Sepolia
const UNISWAP_V2_ROUTER = "0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008";
const UNISWAP_V2_FACTORY = "0x7E0987E5b3a30e3f2828572Bc659CD85bD85d45b";

// Common Test Tokens on Sepolia
const WETH_SEPOLIA = "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9";
const USDC_SEPOLIA = "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238";
const DAI_SEPOLIA = "0x68194a729C2450ad26072b3D33ADaCbcef39D574";
```

---

## Implementation Steps

### Step 1: Add Uniswap V2 Router ABI

Add this to your `index.html` in the global constants section:

```javascript
// Uniswap V2 Router ABI (minimal for swaps)
const UNISWAP_V2_ROUTER_ABI = [
  "function getAmountsOut(uint amountIn, address[] memory path) public view returns (uint[] memory amounts)",
  "function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts)",
  "function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) external payable returns (uint[] memory amounts)",
  "function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts)",
  "function WETH() external pure returns (address)"
];

// ERC20 Token ABI (for approvals)
const ERC20_ABI_EXTENDED = [
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function allowance(address owner, address spender) external view returns (uint256)",
  "function balanceOf(address account) external view returns (uint256)",
  "function decimals() external view returns (uint8)",
  "function symbol() external view returns (string)"
];
```

### Step 2: Create Uniswap Helper Functions

```javascript
// Get swap quote from Uniswap V2
async function getUniswapQuote(amountIn, tokenIn, tokenOut) {
  try {
    if (!provider) {
      console.error("Provider not available");
      return null;
    }
    
    const routerContract = new ethers.Contract(
      UNISWAP_V2_ROUTER,
      UNISWAP_V2_ROUTER_ABI,
      provider
    );
    
    // Build path
    const path = [tokenIn, tokenOut];
    
    // Get quote
    const amounts = await routerContract.getAmountsOut(amountIn, path);
    
    // Return expected output amount
    return amounts[1];
  } catch (error) {
    console.error("Error getting Uniswap quote:", error);
    return null;
  }
}

// Execute Uniswap V2 swap
async function executeUniswapSwap(amountIn, amountOutMin, tokenIn, tokenOut, slippageTolerance = 0.5) {
  try {
    if (!provider || !userAddress) {
      throw new Error("Wallet not connected");
    }
    
    const signer = provider.getSigner();
    const routerContract = new ethers.Contract(
      UNISWAP_V2_ROUTER,
      UNISWAP_V2_ROUTER_ABI,
      signer
    );
    
    // Build path
    const path = [tokenIn, tokenOut];
    
    // Set deadline (20 minutes from now)
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20;
    
    let tx;
    
    if (tokenIn === WETH_SEPOLIA) {
      // Swapping ETH -> Token
      tx = await routerContract.swapExactETHForTokens(
        amountOutMin,
        path,
        userAddress,
        deadline,
        { value: amountIn }
      );
    } else if (tokenOut === WETH_SEPOLIA) {
      // Swapping Token -> ETH
      // First approve router to spend tokens
      await approveToken(tokenIn, UNISWAP_V2_ROUTER, amountIn);
      
      tx = await routerContract.swapExactTokensForETH(
        amountIn,
        amountOutMin,
        path,
        userAddress,
        deadline
      );
    } else {
      // Swapping Token -> Token
      // First approve router to spend tokens
      await approveToken(tokenIn, UNISWAP_V2_ROUTER, amountIn);
      
      tx = await routerContract.swapExactTokensForTokens(
        amountIn,
        amountOutMin,
        path,
        userAddress,
        deadline
      );
    }
    
    // Wait for transaction confirmation
    const receipt = await tx.wait();
    
    return {
      success: true,
      txHash: receipt.transactionHash,
      receipt: receipt
    };
    
  } catch (error) {
    console.error("Error executing Uniswap swap:", error);
    return {
      success: false,
      error: error.message
    };
  }
}

// Approve token spending
async function approveToken(tokenAddress, spenderAddress, amount) {
  try {
    const signer = provider.getSigner();
    const tokenContract = new ethers.Contract(
      tokenAddress,
      ERC20_ABI_EXTENDED,
      signer
    );
    
    // Check current allowance
    const currentAllowance = await tokenContract.allowance(userAddress, spenderAddress);
    
    if (currentAllowance.lt(amount)) {
      // Need approval
      showNotification("🔄 Approving token spending...", false);
      
      const approveTx = await tokenContract.approve(
        spenderAddress,
        ethers.constants.MaxUint256 // Approve max for convenience
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

### Step 3: Update Swap Estimation Function

Replace the existing `updateSwapEstimate()` with Uniswap integration:

```javascript
async function updateSwapEstimate() {
  const fromAmt = parseFloat(document.getElementById('fromInput')?.value) || 0;
  const fromToken = document.getElementById('fromTokenSelect')?.value || 'ETH';
  const toToken = document.getElementById('toTokenSelect')?.value || 'USDC';
  
  if (fromAmt <= 0) {
    const estEl = document.getElementById('swapEstimate');
    if (estEl) estEl.innerHTML = 'Enter amount to see estimate';
    return;
  }
  
  // Token address mapping
  const tokenAddresses = {
    'ETH': WETH_SEPOLIA,
    'USDC': USDC_SEPOLIA,
    'DAI': DAI_SEPOLIA,
    // Add more tokens as needed
  };
  
  const fromTokenAddr = tokenAddresses[fromToken];
  const toTokenAddr = tokenAddresses[toToken];
  
  if (!fromTokenAddr || !toTokenAddr) {
    const estEl = document.getElementById('swapEstimate');
    if (estEl) estEl.innerHTML = 'Token not supported for swap';
    return;
  }
  
  try {
    // Show loading
    const estEl = document.getElementById('swapEstimate');
    if (estEl) estEl.innerHTML = '🔄 Getting quote from Uniswap...';
    
    // Get decimals for the token
    const fromDecimals = fromToken === 'ETH' ? 18 : 6; // Adjust based on token
    const toDecimals = toToken === 'ETH' ? 18 : 6;
    
    // Convert to wei/smallest unit
    const amountIn = ethers.utils.parseUnits(fromAmt.toString(), fromDecimals);
    
    // Get quote from Uniswap
    const amountOut = await getUniswapQuote(amountIn, fromTokenAddr, toTokenAddr);
    
    if (!amountOut) {
      if (estEl) estEl.innerHTML = '⚠️ Unable to get quote. Pool may not exist.';
      return;
    }
    
    // Convert to readable format
    const estOut = ethers.utils.formatUnits(amountOut, toDecimals);
    const rate = parseFloat(estOut) / fromAmt;
    
    // Calculate price impact (simplified)
    const impact = "~0.12% impact";
    
    if (estEl) {
      estEl.innerHTML = `
        <strong>Uniswap V2 Quote:</strong><br>
        ${parseFloat(estOut).toFixed(4)} ${toToken}<br>
        <small style="color:#94a3b8;">
          Rate: 1 ${fromToken} ≈ ${rate.toFixed(4)} ${toToken}<br>
          ${impact} (${currentSlippageTolerance.toFixed(1)}% tolerance)
        </small>
      `;
    }
    
    // Store for use in swap
    window.lastSwapQuote = {
      amountIn: amountIn,
      amountOut: amountOut,
      fromToken: fromTokenAddr,
      toToken: toTokenAddr,
      slippage: currentSlippageTolerance
    };
    
  } catch (error) {
    console.error("Error getting swap estimate:", error);
    const estEl = document.getElementById('swapEstimate');
    if (estEl) estEl.innerHTML = '⚠️ Error getting quote: ' + error.message;
  }
}
```

### Step 4: Update Swap Execution

Replace the `confirmSwap` function:

```javascript
window.confirmSwap = async function() {
  // Check wallet connection
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
  
  if (!window.lastSwapQuote) {
    showNotification("⚠️ Please wait for quote to load", true);
    return;
  }
  
  const { amountIn, amountOut, fromToken, toToken, slippage } = window.lastSwapQuote;
  
  // Calculate minimum amount with slippage
  const slippageMultiplier = 1 - (slippage / 100);
  const amountOutMin = amountOut.mul(Math.floor(slippageMultiplier * 100)).div(100);
  
  // Request wallet confirmation
  const confirmed = await requestWalletConfirmation('Uniswap V2 Token Swap', {
    amount: `${amt} ${fromToken} → ${ethers.utils.formatUnits(amountOut, 6)} ${toToken}`,
    from: 'Uniswap V2 Router',
    gasLimit: GAS_LIMITS.SWAP
  });
  
  if (!confirmed) {
    showNotification('❌ Swap cancelled by user', true);
    return;
  }
  
  // Execute swap
  showNotification('🔄 Executing swap on Uniswap V2...', false);
  
  const result = await executeUniswapSwap(
    amountIn,
    amountOutMin,
    fromToken,
    toToken,
    slippage
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

## Testing Your Uniswap Integration

### 1. Get Test Tokens

First, you need test tokens on Sepolia:

**Get WETH (Wrapped ETH):**
- Use the WETH contract to wrap your SepoliaETH
- Or get from a Sepolia faucet that provides WETH

**Get USDC/DAI:**
- Use Sepolia faucets that provide test ERC20 tokens
- Or mint from test token contracts

### 2. Test Swap Flow

1. **Connect Wallet** → MetaMask on Sepolia
2. **Select Tokens** → e.g., ETH → USDC
3. **Enter Amount** → e.g., 0.01 ETH
4. **View Quote** → Should show Uniswap quote
5. **Approve Token** (if needed) → Confirm in MetaMask
6. **Execute Swap** → Confirm transaction
7. **View Result** → Check transaction on Etherscan

---

## Important Notes

### Liquidity Pools
- Not all token pairs have liquidity on Sepolia
- You may need to add liquidity first
- Popular pairs: WETH/USDC, WETH/DAI

### Gas Costs
- Token approval: ~50,000 gas
- Swap execution: ~150,000-200,000 gas
- Total: ~0.001-0.003 SepoliaETH

### Slippage Protection
- Default: 0.5%
- Adjust for volatile pairs or low liquidity
- Too low = transaction may fail
- Too high = potential for loss

---

## Advanced: Android APK Implementation (Future)

For future Android development, here's the structure:

### Dependencies (build.gradle)
```gradle
dependencies {
    implementation 'org.web3j:core:5.0.0'
    implementation 'com.walletconnect:android-core:1.0.0'
    implementation 'androidx.lifecycle:lifecycle-viewmodel-ktx:2.6.1'
}
```

### Kotlin Example
```kotlin
class SwapViewModel : ViewModel() {
    private val web3j = Web3j.build(HttpService("https://rpc.sepolia.org"))
    private val routerAddress = "0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008"
    
    suspend fun getSwapQuote(amountIn: BigInteger, path: List<String>): BigInteger {
        val router = UniswapV2Router02.load(
            routerAddress,
            web3j,
            credentials,
            DefaultGasProvider()
        )
        
        val amounts = router.getAmountsOut(amountIn, path).send()
        return amounts[1]
    }
    
    suspend fun executeSwap(
        amountIn: BigInteger,
        amountOutMin: BigInteger,
        path: List<String>,
        deadline: BigInteger
    ): String {
        val router = UniswapV2Router02.load(
            routerAddress,
            web3j,
            credentials,
            DefaultGasProvider()
        )
        
        val tx = router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            userAddress,
            deadline
        ).send()
        
        return tx.transactionHash
    }
}
```

---

## Security Best Practices

✅ Always use slippage protection
✅ Validate token addresses
✅ Check allowances before approval
✅ Display gas estimates to users
✅ Never store private keys in the app
✅ Use external wallets (MetaMask, WalletConnect)
✅ Test thoroughly on testnet before mainnet

---

## Resources

- **Uniswap V2 Docs:** https://docs.uniswap.org/contracts/v2/overview
- **web3j Documentation:** https://docs.web3j.io/
- **WalletConnect:** https://walletconnect.com/
- **Sepolia Explorer:** https://sepolia.etherscan.io/

---

## Support

If you encounter issues:
- Check if liquidity exists for the token pair
- Verify token addresses are correct
- Ensure sufficient gas in wallet
- Check slippage tolerance settings

**Happy Swapping! 🚀**
