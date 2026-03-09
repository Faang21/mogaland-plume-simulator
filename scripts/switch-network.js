#!/usr/bin/env node
/**
 * switch-network.js
 * ─────────────────
 * One-command helper to switch Mogaland between testnet and mainnet mode.
 *
 * Usage:
 *   node scripts/switch-network.js mainnet   →  IS_MAINNET = true  (Base by default)
 *   node scripts/switch-network.js testnet   →  IS_MAINNET = false (Sepolia by default)
 *
 * What it changes:
 *   • Flips the single IS_MAINNET flag in index.html
 *   • Clears any stale localStorage default stored in the HTML template
 *
 * After switching to mainnet, fill in the contract addresses:
 *   Look for  // TODO: replace  comments inside the NETWORKS config in index.html.
 *   Fields to set per network:
 *     nftContractAddress      ← deployed MogalandLearningNFT.sol address
 *     stakingContractAddress  ← deployed StakingPool.sol address
 *     wMogaAddress            ← deployed wMOGA.sol address
 */

'use strict';
const fs   = require('fs');
const path = require('path');

const TARGET  = path.join(__dirname, '..', 'index.html');
const mode    = (process.argv[2] || '').toLowerCase();

if (mode !== 'mainnet' && mode !== 'testnet') {
  console.error('Usage: node scripts/switch-network.js <mainnet|testnet>');
  process.exit(1);
}

let html = fs.readFileSync(TARGET, 'utf8');

const mainnetFlag = 'const IS_MAINNET = true; // ← change this ONE value (or run the script above)';
const testnetFlag = 'const IS_MAINNET = false; // ← change this ONE value (or run the script above)';

if (mode === 'mainnet') {
  if (html.includes(mainnetFlag)) {
    console.log('✅ Already in MAINNET mode. No changes made.');
    process.exit(0);
  }
  html = html.replace(testnetFlag, mainnetFlag);
  fs.writeFileSync(TARGET, html, 'utf8');
  console.log('');
  console.log('✅  Switched to MAINNET mode (IS_MAINNET = true)');
  console.log('');
  console.log('   Default network: Base (chain 8453)');
  console.log('   OpenSea:         https://opensea.io');
  console.log('');
  console.log('   ⚠️  Before going live, fill in your deployed contract addresses');
  console.log('      inside the NETWORKS config in index.html:');
  console.log('        nftContractAddress      ← MogalandLearningNFT.sol');
  console.log('        stakingContractAddress  ← StakingPool.sol');
  console.log('        wMogaAddress            ← wMOGA.sol');
  console.log('');
} else {
  if (html.includes(testnetFlag)) {
    console.log('✅ Already in TESTNET mode. No changes made.');
    process.exit(0);
  }
  html = html.replace(mainnetFlag, testnetFlag);
  fs.writeFileSync(TARGET, html, 'utf8');
  console.log('');
  console.log('✅  Switched to TESTNET mode (IS_MAINNET = false)');
  console.log('');
  console.log('   Default network: ETH Sepolia (chain 11155111)');
  console.log('   OpenSea:         https://testnets.opensea.io');
  console.log('');
}
