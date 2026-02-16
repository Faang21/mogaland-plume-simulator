# Live Trading Charts Integration Guide
## Mogaland Plume Simulator - Real-Time Price Charts & Futures Trading

This guide explains how to integrate professional-grade live charts with real-time price data into the Mogaland Plume Simulator web application.

---

## 📊 Overview

### What You'll Build
- **Live Price Charts** with candlestick/OHLC data
- **Technical Indicators** (RSI, MACD, Moving Averages)
- **Real-Time Updates** via WebSocket connections
- **Trading Interface** for Long/Short positions
- **Multi-Timeframe** support (1m, 5m, 1h, 1d)

### Technology Stack
- **TradingView Lightweight Charts** - Fast, 35KB library
- **Binance WebSocket** - Real-time price feeds
- **Ethers.js** - Blockchain interactions (already in app)
- **Pure JavaScript** - No React needed (your app is vanilla JS)

---

## �� Quick Start Implementation

### Step 1: Add TradingView Charts Library

Add this to your `index.html` in the `<head>` section or before closing `</body>`:

```html
<!-- TradingView Lightweight Charts -->
<script src="https://unpkg.com/lightweight-charts@4.1.1/dist/lightweight-charts.standalone.production.js"></script>
```

### Step 2: Create Chart Container

Add this to your market/trading section HTML:

```html
<div id="tradingChartContainer" style="position: relative; width: 100%; height: 500px; background: #0f172a; border-radius: 12px; margin: 20px 0;">
  <!-- Chart will be rendered here -->
</div>

<!-- Chart Controls -->
<div style="display: flex; gap: 8px; margin: 12px 0; flex-wrap: wrap;">
  <button onclick="changeTimeframe('1m')" class="timeframe-btn">1m</button>
  <button onclick="changeTimeframe('5m')" class="timeframe-btn">5m</button>
  <button onclick="changeTimeframe('15m')" class="timeframe-btn">15m</button>
  <button onclick="changeTimeframe('1h')" class="timeframe-btn">1h</button>
  <button onclick="changeTimeframe('4h')" class="timeframe-btn">4h</button>
  <button onclick="changeTimeframe('1d')" class="timeframe-btn active">1d</button>
</div>
```

### Step 3: Initialize Chart

Add this JavaScript code to your `index.html` in the `<script>` section:

```javascript
// Trading Chart Configuration
let tradingChart = null;
let candlestickSeries = null;
let volumeSeries = null;
let priceWebSocket = null;
let currentSymbol = 'BTCUSDT';
let currentTimeframe = '1d';
let chartData = [];

// Initialize TradingView Chart
function initializeTradingChart() {
  const container = document.getElementById('tradingChartContainer');
  if (!container || typeof LightweightCharts === 'undefined') {
    console.error('Chart container or TradingView library not found');
    return;
  }
  
  // Create chart
  tradingChart = LightweightCharts.createChart(container, {
    width: container.clientWidth,
    height: 500,
    layout: {
      background: { color: '#0f172a' },
      textColor: '#d1d5db',
    },
    grid: {
      vertLines: { color: '#1e293b' },
      horzLines: { color: '#1e293b' },
    },
    crosshair: {
      mode: LightweightCharts.CrosshairMode.Normal,
    },
    rightPriceScale: {
      borderColor: '#334155',
    },
    timeScale: {
      borderColor: '#334155',
      timeVisible: true,
      secondsVisible: false,
    },
  });
  
  // Add candlestick series
  candlestickSeries = tradingChart.addCandlestickSeries({
    upColor: '#10b981',
    downColor: '#ef4444',
    borderUpColor: '#10b981',
    borderDownColor: '#ef4444',
    wickUpColor: '#10b981',
    wickDownColor: '#ef4444',
  });
  
  // Add volume series
  volumeSeries = tradingChart.addHistogramSeries({
    color: '#60a5fa',
    priceFormat: {
      type: 'volume',
    },
    priceScaleId: '',
    scaleMargins: {
      top: 0.8,
      bottom: 0,
    },
  });
  
  // Make chart responsive
  window.addEventListener('resize', () => {
    if (tradingChart && container) {
      tradingChart.applyOptions({ 
        width: container.clientWidth 
      });
    }
  });
  
  console.log('✅ Trading chart initialized');
}

// Fetch historical data from Binance
async function fetchHistoricalData(symbol, interval, limit = 100) {
  try {
    const url = `https://api.binance.com/api/v3/klines?symbol=${symbol}&interval=${interval}&limit=${limit}`;
    const response = await fetch(url);
    const data = await response.json();
    
    // Transform Binance data to TradingView format
    const candles = data.map(item => ({
      time: item[0] / 1000, // Convert to seconds
      open: parseFloat(item[1]),
      high: parseFloat(item[2]),
      low: parseFloat(item[3]),
      close: parseFloat(item[4]),
      volume: parseFloat(item[5])
    }));
    
    return candles;
  } catch (error) {
    console.error('Error fetching historical data:', error);
    return [];
  }
}

// Load chart data
async function loadChartData(symbol, timeframe) {
  try {
    showNotification('📊 Loading chart data...', false);
    
    // Map timeframes to Binance intervals
    const intervalMap = {
      '1m': '1m',
      '5m': '5m',
      '15m': '15m',
      '1h': '1h',
      '4h': '4h',
      '1d': '1d'
    };
    
    const interval = intervalMap[timeframe] || '1d';
    const candles = await fetchHistoricalData(symbol, interval, 500);
    
    if (candles.length === 0) {
      showNotification('⚠️ No chart data available', true);
      return;
    }
    
    // Update chart
    candlestickSeries.setData(candles);
    
    // Update volume
    const volumeData = candles.map(c => ({
      time: c.time,
      value: c.volume,
      color: c.close >= c.open ? '#10b98180' : '#ef444480'
    }));
    volumeSeries.setData(volumeData);
    
    // Store data for updates
    chartData = candles;
    
    // Fit content
    tradingChart.timeScale().fitContent();
    
    showNotification('✅ Chart loaded successfully', false);
    
    // Start WebSocket for real-time updates
    connectPriceWebSocket(symbol, interval);
    
  } catch (error) {
    console.error('Error loading chart data:', error);
    showNotification('❌ Failed to load chart: ' + error.message, true);
  }
}

// Connect to Binance WebSocket for real-time updates
function connectPriceWebSocket(symbol, interval) {
  // Close existing connection
  if (priceWebSocket) {
    priceWebSocket.close();
  }
  
  const wsUrl = `wss://stream.binance.com:9443/ws/${symbol.toLowerCase()}@kline_${interval}`;
  priceWebSocket = new WebSocket(wsUrl);
  
  priceWebSocket.onopen = () => {
    console.log('✅ WebSocket connected for', symbol, interval);
  };
  
  priceWebSocket.onmessage = (event) => {
    try {
      const message = JSON.parse(event.data);
      const kline = message.k;
      
      if (!kline) return;
      
      // Update chart with new candle
      const candle = {
        time: kline.t / 1000,
        open: parseFloat(kline.o),
        high: parseFloat(kline.h),
        low: parseFloat(kline.l),
        close: parseFloat(kline.c),
        volume: parseFloat(kline.v)
      };
      
      // Update candlestick
      candlestickSeries.update(candle);
      
      // Update volume
      volumeSeries.update({
        time: candle.time,
        value: candle.volume,
        color: candle.close >= candle.open ? '#10b98180' : '#ef444480'
      });
      
      // Update current price display
      updateCurrentPriceDisplay(candle.close, kline.x); // x = is candle closed
      
    } catch (error) {
      console.error('WebSocket message error:', error);
    }
  };
  
  priceWebSocket.onerror = (error) => {
    console.error('WebSocket error:', error);
    showNotification('⚠️ Price feed connection error', true);
  };
  
  priceWebSocket.onclose = () => {
    console.log('WebSocket disconnected');
    // Attempt reconnect after 5 seconds
    setTimeout(() => {
      if (currentSymbol && currentTimeframe) {
        connectPriceWebSocket(currentSymbol, currentTimeframe);
      }
    }, 5000);
  };
}

// Update current price display
function updateCurrentPriceDisplay(price, isClosed) {
  const priceEl = document.getElementById('currentPriceDisplay');
  if (priceEl) {
    priceEl.textContent = `$${price.toFixed(2)}`;
    
    // Add visual indicator for updates
    if (!isClosed) {
      priceEl.style.animation = 'pulse 0.5s';
      setTimeout(() => {
        priceEl.style.animation = '';
      }, 500);
    }
  }
}

// Change timeframe
window.changeTimeframe = function(timeframe) {
  currentTimeframe = timeframe;
  
  // Update button states
  document.querySelectorAll('.timeframe-btn').forEach(btn => {
    btn.classList.remove('active');
  });
  event.target.classList.add('active');
  
  // Reload chart data
  loadChartData(currentSymbol, timeframe);
}

// Change symbol
window.changeSymbol = function(symbol) {
  currentSymbol = symbol;
  loadChartData(symbol, currentTimeframe);
}

// Add technical indicators
function addMovingAverage(period, color) {
  if (chartData.length === 0) return;
  
  const ma = calculateMA(chartData, period);
  const maSeries = tradingChart.addLineSeries({
    color: color,
    lineWidth: 2,
    title: `MA${period}`
  });
  
  maSeries.setData(ma);
  return maSeries;
}

// Calculate Simple Moving Average
function calculateMA(data, period) {
  const ma = [];
  for (let i = period - 1; i < data.length; i++) {
    let sum = 0;
    for (let j = 0; j < period; j++) {
      sum += data[i - j].close;
    }
    ma.push({
      time: data[i].time,
      value: sum / period
    });
  }
  return ma;
}

// Add RSI indicator
function addRSI(period = 14) {
  if (chartData.length === 0) return;
  
  const rsi = calculateRSI(chartData, period);
  
  // Create separate pane for RSI
  const rsiSeries = tradingChart.addLineSeries({
    color: '#8b5cf6',
    lineWidth: 2,
    priceScaleId: 'rsi',
  });
  
  tradingChart.priceScale('rsi').applyOptions({
    scaleMargins: {
      top: 0.9,
      bottom: 0.01,
    },
  });
  
  rsiSeries.setData(rsi);
  return rsiSeries;
}

// Calculate RSI
function calculateRSI(data, period) {
  const rsi = [];
  const changes = [];
  
  for (let i = 1; i < data.length; i++) {
    changes.push(data[i].close - data[i - 1].close);
  }
  
  for (let i = period; i < changes.length; i++) {
    let gains = 0;
    let losses = 0;
    
    for (let j = i - period; j < i; j++) {
      if (changes[j] > 0) gains += changes[j];
      else losses -= changes[j];
    }
    
    const avgGain = gains / period;
    const avgLoss = losses / period;
    const rs = avgGain / (avgLoss || 1);
    const rsiValue = 100 - (100 / (1 + rs));
    
    rsi.push({
      time: data[i + 1].time,
      value: rsiValue
    });
  }
  
  return rsi;
}
```

### Step 4: Add Trading Functionality

```javascript
// Open Long Position (Buy)
window.openLongPosition = async function() {
  if (!userAddress || !provider) {
    showNotification("⚠️ Please connect wallet first!", true);
    connectWalletFromApp();
    return;
  }
  
  const amount = parseFloat(document.getElementById('positionAmount')?.value) || 0;
  const leverage = parseInt(document.getElementById('leverageSelect')?.value) || 1;
  
  if (amount <= 0) {
    showNotification('Please enter a valid amount!', true);
    return;
  }
  
  // Get current price from chart
  const currentPrice = chartData[chartData.length - 1]?.close || 0;
  
  // Request wallet confirmation
  const confirmed = await requestWalletConfirmation('Open LONG Position', {
    amount: `${amount} USDC (${leverage}x leverage)`,
    from: `${currentSymbol} @ $${currentPrice.toFixed(2)} - UP ⬆️`,
    gasLimit: GAS_LIMITS.TRADE
  });
  
  if (!confirmed) {
    showNotification('❌ Trade cancelled by user', true);
    return;
  }
  
  // Check sufficient balance
  if (amount > tradingUSDCBalance) {
    showNotification(`Insufficient balance! You have ${tradingUSDCBalance.toFixed(2)} USDC`, true);
    return;
  }
  
  // Process gas fee
  if (!processGasFee('trade')) {
    return;
  }
  
  // Create position
  const position = {
    id: Date.now(),
    symbol: currentSymbol,
    type: 'long',
    amount: amount,
    leverage: leverage,
    entryPrice: currentPrice,
    timestamp: Date.now(),
    status: 'open'
  };
  
  // Deduct from balance
  tradingUSDCBalance -= amount;
  updateTradingBalance();
  
  // Store position
  if (!window.openPositions) window.openPositions = [];
  window.openPositions.push(position);
  
  // Show marker on chart
  addTradeMarker(position);
  
  showNotification(
    `✅ LONG position opened<br>
    ${amount} USDC @ $${currentPrice.toFixed(2)} (${leverage}x)<br>
    Symbol: ${currentSymbol}`,
    false
  );
  
  // Update positions display
  displayOpenPositions();
}

// Open Short Position (Sell)
window.openShortPosition = async function() {
  if (!userAddress || !provider) {
    showNotification("⚠️ Please connect wallet first!", true);
    connectWalletFromApp();
    return;
  }
  
  const amount = parseFloat(document.getElementById('positionAmount')?.value) || 0;
  const leverage = parseInt(document.getElementById('leverageSelect')?.value) || 1;
  
  if (amount <= 0) {
    showNotification('Please enter a valid amount!', true);
    return;
  }
  
  const currentPrice = chartData[chartData.length - 1]?.close || 0;
  
  // Request wallet confirmation
  const confirmed = await requestWalletConfirmation('Open SHORT Position', {
    amount: `${amount} USDC (${leverage}x leverage)`,
    from: `${currentSymbol} @ $${currentPrice.toFixed(2)} - DOWN ⬇️`,
    gasLimit: GAS_LIMITS.TRADE
  });
  
  if (!confirmed) {
    showNotification('❌ Trade cancelled by user', true);
    return;
  }
  
  if (amount > tradingUSDCBalance) {
    showNotification(`Insufficient balance! You have ${tradingUSDCBalance.toFixed(2)} USDC`, true);
    return;
  }
  
  if (!processGasFee('trade')) {
    return;
  }
  
  const position = {
    id: Date.now(),
    symbol: currentSymbol,
    type: 'short',
    amount: amount,
    leverage: leverage,
    entryPrice: currentPrice,
    timestamp: Date.now(),
    status: 'open'
  };
  
  tradingUSDCBalance -= amount;
  updateTradingBalance();
  
  if (!window.openPositions) window.openPositions = [];
  window.openPositions.push(position);
  
  addTradeMarker(position);
  
  showNotification(
    `✅ SHORT position opened<br>
    ${amount} USDC @ $${currentPrice.toFixed(2)} (${leverage}x)<br>
    Symbol: ${currentSymbol}`,
    false
  );
  
  displayOpenPositions();
}

// Add trade marker on chart
function addTradeMarker(position) {
  if (!candlestickSeries) return;
  
  const marker = {
    time: position.timestamp / 1000,
    position: position.type === 'long' ? 'belowBar' : 'aboveBar',
    color: position.type === 'long' ? '#10b981' : '#ef4444',
    shape: position.type === 'long' ? 'arrowUp' : 'arrowDown',
    text: `${position.type.toUpperCase()} @ $${position.entryPrice.toFixed(2)}`
  };
  
  const existingMarkers = candlestickSeries.markers() || [];
  candlestickSeries.setMarkers([...existingMarkers, marker]);
}

// Display open positions
function displayOpenPositions() {
  const container = document.getElementById('openPositionsContainer');
  if (!container || !window.openPositions) return;
  
  const currentPrice = chartData[chartData.length - 1]?.close || 0;
  
  container.innerHTML = '<h3>Open Positions</h3>';
  
  window.openPositions.filter(p => p.status === 'open').forEach(position => {
    // Calculate P&L
    let pnl;
    if (position.type === 'long') {
      pnl = (currentPrice - position.entryPrice) / position.entryPrice * 100 * position.leverage;
    } else {
      pnl = (position.entryPrice - currentPrice) / position.entryPrice * 100 * position.leverage;
    }
    
    const pnlUSDC = (position.amount * pnl) / 100;
    const pnlColor = pnl >= 0 ? '#10b981' : '#ef4444';
    
    const div = document.createElement('div');
    div.style.cssText = 'padding: 12px; border: 1px solid #334155; border-radius: 8px; margin: 8px 0; background: #1e293b;';
    div.innerHTML = `
      <div style="display: flex; justify-content: space-between; align-items: center;">
        <div>
          <strong style="color: ${position.type === 'long' ? '#10b981' : '#ef4444'};">
            ${position.type.toUpperCase()} ${position.symbol}
          </strong><br>
          <small>Entry: $${position.entryPrice.toFixed(2)} | ${position.leverage}x</small><br>
          <small>Amount: ${position.amount} USDC</small>
        </div>
        <div style="text-align: right;">
          <div style="font-size: 1.2em; font-weight: bold; color: ${pnlColor};">
            ${pnl >= 0 ? '+' : ''}${pnl.toFixed(2)}%
          </div>
          <div style="color: ${pnlColor};">
            ${pnlUSDC >= 0 ? '+' : ''}${pnlUSDC.toFixed(2)} USDC
          </div>
          <button onclick="closePosition(${position.id})" style="margin-top: 8px; padding: 6px 12px; background: #ef4444; color: white; border: none; border-radius: 6px; cursor: pointer;">
            Close
          </button>
        </div>
      </div>
    `;
    container.appendChild(div);
  });
}

// Close position
window.closePosition = function(positionId) {
  if (!window.openPositions) return;
  
  const position = window.openPositions.find(p => p.id === positionId);
  if (!position) return;
  
  const currentPrice = chartData[chartData.length - 1]?.close || 0;
  
  // Calculate P&L
  let pnl;
  if (position.type === 'long') {
    pnl = (currentPrice - position.entryPrice) / position.entryPrice * 100 * position.leverage;
  } else {
    pnl = (position.entryPrice - currentPrice) / position.entryPrice * 100 * position.leverage;
  }
  
  const pnlUSDC = (position.amount * pnl) / 100;
  const finalAmount = position.amount + pnlUSDC;
  
  // Update balance
  tradingUSDCBalance += finalAmount;
  updateTradingBalance();
  
  // Mark position as closed
  position.status = 'closed';
  position.exitPrice = currentPrice;
  position.pnl = pnlUSDC;
  
  showNotification(
    `Position closed!<br>
    P&L: ${pnl >= 0 ? '+' : ''}${pnl.toFixed(2)}% (${pnlUSDC >= 0 ? '+' : ''}${pnlUSDC.toFixed(2)} USDC)`,
    pnl >= 0 ? false : true
  );
  
  // Refresh display
  displayOpenPositions();
}

// Initialize chart on page load
window.addEventListener('DOMContentLoaded', () => {
  // Wait a bit for TradingView library to load
  setTimeout(() => {
    initializeTradingChart();
    loadChartData('BTCUSDT', '1d');
  }, 1000);
});
```

---

## 📈 Advanced Features

### Add More Technical Indicators

```javascript
// Add Bollinger Bands
function addBollingerBands(period = 20, stdDev = 2) {
  const bb = calculateBollingerBands(chartData, period, stdDev);
  
  const upperBand = tradingChart.addLineSeries({
    color: '#3b82f6',
    lineWidth: 1,
    lineStyle: 2, // Dashed
  });
  
  const lowerBand = tradingChart.addLineSeries({
    color: '#3b82f6',
    lineWidth: 1,
    lineStyle: 2,
  });
  
  upperBand.setData(bb.upper);
  lowerBand.setData(bb.lower);
  
  return { upper: upperBand, lower: lowerBand };
}

// Calculate Bollinger Bands
function calculateBollingerBands(data, period, stdDev) {
  const ma = calculateMA(data, period);
  const upper = [];
  const lower = [];
  
  for (let i = 0; i < ma.length; i++) {
    const dataIndex = i + period - 1;
    let sum = 0;
    
    for (let j = 0; j < period; j++) {
      const diff = data[dataIndex - j].close - ma[i].value;
      sum += diff * diff;
    }
    
    const variance = sum / period;
    const sd = Math.sqrt(variance);
    
    upper.push({
      time: ma[i].time,
      value: ma[i].value + (stdDev * sd)
    });
    
    lower.push({
      time: ma[i].time,
      value: ma[i].value - (stdDev * sd)
    });
  }
  
  return { upper, lower };
}
```

### Multiple Symbol Support

```html
<select id="symbolSelect" onchange="changeSymbol(this.value)" style="...">
  <option value="BTCUSDT">BTC/USDT</option>
  <option value="ETHUSDT">ETH/USDT</option>
  <option value="BNBUSDT">BNB/USDT</option>
  <option value="SOLUSDT">SOL/USDT</option>
  <option value="ADAUSDT">ADA/USDT</option>
  <option value="DOGEUSDT">DOGE/USDT</option>
</select>
```

---

## 🔧 Alternative Data Sources

### 1. CoinGecko API (Free, No API Key)
```javascript
async function fetchCoinGeckoData(coinId) {
  const url = `https://api.coingecko.com/api/v3/coins/${coinId}/ohlc?vs_currency=usd&days=30`;
  const response = await fetch(url);
  const data = await response.json();
  
  return data.map(item => ({
    time: item[0] / 1000,
    open: item[1],
    high: item[2],
    low: item[3],
    close: item[4]
  }));
}
```

### 2. Moralis API (Requires API Key)
```javascript
const MORALIS_API_KEY = 'your-api-key';

async function fetchMoralisData(token) {
  const url = `https://deep-index.moralis.io/api/v2/erc20/${token}/ohlcv?chain=eth`;
  const response = await fetch(url, {
    headers: { 'X-API-Key': MORALIS_API_KEY }
  });
  const data = await response.json();
  return data;
}
```

---

## 🎨 Styling

Add this CSS to make buttons look good:

```css
.timeframe-btn {
  padding: 8px 16px;
  background: #1e293b;
  color: #94a3b8;
  border: 1px solid #334155;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s;
  font-size: 14px;
  font-weight: 500;
}

.timeframe-btn:hover {
  background: #334155;
  color: white;
}

.timeframe-btn.active {
  background: #3b82f6;
  color: white;
  border-color: #3b82f6;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.6; }
}
```

---

## 🧪 Testing Your Implementation

### Test Checklist:
- [ ] Chart loads with historical data
- [ ] Real-time updates work via WebSocket
- [ ] Timeframe switching works
- [ ] Symbol switching works
- [ ] Long position opens correctly
- [ ] Short position opens correctly
- [ ] P&L calculates correctly
- [ ] Positions close properly
- [ ] Chart is responsive
- [ ] No console errors

### Debug Tips:
```javascript
// Add logging
console.log('Current price:', chartData[chartData.length - 1]?.close);
console.log('Open positions:', window.openPositions);
console.log('WebSocket status:', priceWebSocket?.readyState);
```

---

## 🚀 Production Considerations

### Performance Optimization:
1. **Limit historical data** to last 500 candles
2. **Throttle updates** (max 1 per second)
3. **Use worker threads** for calculations
4. **Lazy load** indicators

### Error Handling:
```javascript
// Reconnect on disconnect
priceWebSocket.onerror = () => {
  setTimeout(() => reconnectWebSocket(), 5000);
};

// Fallback to REST API if WebSocket fails
if (!priceWebSocket || priceWebSocket.readyState !== 1) {
  fetchDataViaREST();
}
```

### Security:
- ✅ Validate all user inputs
- ✅ Check balance before trades
- ✅ Require wallet confirmation
- ✅ Implement position limits
- ✅ Add stop-loss functionality

---

## 📚 Resources

- **TradingView Docs:** https://tradingview.github.io/lightweight-charts/
- **Binance API:** https://binance-docs.github.io/apidocs/
- **WebSocket Guide:** https://developer.mozilla.org/en-US/docs/Web/API/WebSocket
- **Technical Indicators:** https://www.investopedia.com/

---

## ✨ Summary

You now have:
1. ✅ Professional TradingView charts
2. ✅ Real-time price updates via WebSocket
3. ✅ Multiple timeframes (1m to 1d)
4. ✅ Technical indicators (MA, RSI, BB)
5. ✅ Long/Short trading functionality
6. ✅ P&L tracking
7. ✅ Position management
8. ✅ Responsive design

**Happy Trading! 📈🚀**
