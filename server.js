const express = require('express');
const path = require('path');
const https = require('https');
const http = require('http');
const QRCode = require('qrcode');
const { ethers } = require('ethers');

const app = express();
const PORT = 3000;
const HOST = '0.0.0.0';

app.use(express.json({ limit: '5mb' }));

const docsDir = path.join(__dirname, 'docs');

// Serve ethers UMD library to the client
app.get('/vendor/ethers.umd.min.js', (req, res) => {
  const ethersPath = path.join(__dirname, 'node_modules/ethers/dist/ethers.umd.min.js');
  res.sendFile(ethersPath);
});

// QR Code endpoint
app.get('/api/qr', async (req, res) => {
  try {
    const text = req.query.text || '';
    if (!text) {
      return res.status(400).send('Missing text parameter');
    }
    const svgString = await QRCode.toString(text, {
      type: 'svg',
      margin: 1,
      color: {
        dark: '#00D632',
        light: '#090B0E'
      }
    });
    res.setHeader('Content-Type', 'image/svg+xml');
    res.send(svgString);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Cache for market prices
let cachedPrices = null;
let lastPricesFetch = 0;

const defaultPrices = {
  ethereum: { usd: 2645.20, eur: 2435.10, gbp: 2038.50, usd_24h_change: 3.42 },
  bitcoin: { usd: 67840.00, eur: 62450.00, gbp: 52310.00, usd_24h_change: 1.85 },
  solana: { usd: 154.60, eur: 142.30, gbp: 119.10, usd_24h_change: 4.15 },
  'matic-network': { usd: 0.384, eur: 0.353, gbp: 0.296, usd_24h_change: -0.65 },
  arbitrum: { usd: 0.582, eur: 0.535, gbp: 0.448, usd_24h_change: 2.14 },
  optimism: { usd: 1.64, eur: 1.51, gbp: 1.26, usd_24h_change: 3.08 },
  chainlink: { usd: 11.55, eur: 10.62, gbp: 8.89, usd_24h_change: 1.22 },
  uniswap: { usd: 7.92, eur: 7.28, gbp: 6.10, usd_24h_change: 2.85 },
  tether: { usd: 1.00, eur: 0.92, gbp: 0.77, usd_24h_change: 0.01 },
  'usd-coin': { usd: 1.00, eur: 0.92, gbp: 0.77, usd_24h_change: 0.00 }
};

app.get('/api/prices', async (req, res) => {
  const now = Date.now();
  if (cachedPrices && now - lastPricesFetch < 60000) {
    return res.json(cachedPrices);
  }

  try {
    const url = 'https://api.coingecko.com/api/v3/simple/price?ids=ethereum,bitcoin,solana,matic-network,arbitrum,optimism,chainlink,uniswap,tether,usd-coin&vs_currencies=usd,eur,gbp&include_24hr_change=true';
    const response = await fetch(url, { headers: { 'Accept': 'application/json' }, signal: AbortSignal.timeout(4000) });
    if (response.ok) {
      const data = await response.json();
      cachedPrices = { ...defaultPrices, ...data };
      lastPricesFetch = now;
      return res.json(cachedPrices);
    }
  } catch (err) {
    // Fall back to default prices
  }

  cachedPrices = defaultPrices;
  res.json(cachedPrices);
});

// In-memory Sandbox blockchain state (Chain 1337)
const sandboxAccounts = new Map();
let sandboxBlockNumber = 19482100;
const sandboxTransactions = [];

function getSandboxBalance(addr) {
  const normalized = addr.toLowerCase();
  if (!sandboxAccounts.has(normalized)) {
    // Default initial balance for new demo accounts is 2.5 ETH
    sandboxAccounts.set(normalized, {
      balanceWei: ethers.parseEther('2.5'),
      nonce: 0
    });
  }
  return sandboxAccounts.get(normalized);
}

// Public RPC proxy and Sandbox router
app.post('/api/rpc', async (req, res) => {
  const { rpcUrl, chainId, method, params } = req.body;

  // Handle Sandbox Chain ID 1337 locally
  if (chainId === 1337 || !rpcUrl) {
    sandboxBlockNumber++;
    try {
      if (method === 'eth_blockNumber') {
        return res.json({ jsonrpc: '2.0', id: req.body.id || 1, result: '0x' + sandboxBlockNumber.toString(16) });
      }
      if (method === 'eth_chainId') {
        return res.json({ jsonrpc: '2.0', id: req.body.id || 1, result: '0x539' }); // 1337
      }
      if (method === 'eth_getBalance') {
        const addr = params[0];
        const state = getSandboxBalance(addr);
        return res.json({ jsonrpc: '2.0', id: req.body.id || 1, result: '0x' + state.balanceWei.toString(16) });
      }
      if (method === 'eth_gasPrice') {
        return res.json({ jsonrpc: '2.0', id: req.body.id || 1, result: '0x' + ethers.parseUnits('18', 'gwei').toString(16) });
      }
      if (method === 'eth_estimateGas') {
        return res.json({ jsonrpc: '2.0', id: req.body.id || 1, result: '0x5208' }); // 21,000 standard
      }
      if (method === 'eth_getTransactionCount') {
        const addr = params[0];
        const state = getSandboxBalance(addr);
        return res.json({ jsonrpc: '2.0', id: req.body.id || 1, result: '0x' + state.nonce.toString(16) });
      }
      if (method === 'eth_sendRawTransaction') {
        const rawTx = params[0];
        const parsed = ethers.Transaction.from(rawTx);
        const fromAddr = parsed.from.toLowerCase();
        const toAddr = (parsed.to || '').toLowerCase();
        const value = parsed.value || 0n;
        const gasCost = (parsed.gasLimit || 21000n) * (parsed.gasPrice || ethers.parseUnits('18', 'gwei'));

        const fromState = getSandboxBalance(fromAddr);
        const totalCost = value + gasCost;

        if (fromState.balanceWei < totalCost) {
          return res.status(400).json({
            jsonrpc: '2.0',
            id: req.body.id || 1,
            error: { code: -32000, message: 'insufficient funds for gas * price + value' }
          });
        }

        // Deduct from sender
        fromState.balanceWei -= totalCost;
        fromState.nonce += 1;

        // Credit to recipient
        if (toAddr) {
          const toState = getSandboxBalance(toAddr);
          toState.balanceWei += value;
        }

        const txHash = parsed.hash || ('0x' + Array.from({ length: 64 }, () => Math.floor(Math.random() * 16).toString(16)).join(''));
        const receipt = {
          transactionHash: txHash,
          blockNumber: '0x' + sandboxBlockNumber.toString(16),
          blockHash: '0x' + Array.from({ length: 64 }, () => Math.floor(Math.random() * 16).toString(16)).join(''),
          from: fromAddr,
          to: toAddr,
          gasUsed: '0x5208',
          status: '0x1',
          value: '0x' + value.toString(16)
        };
        sandboxTransactions.push(receipt);

        return res.json({ jsonrpc: '2.0', id: req.body.id || 1, result: txHash });
      }
      if (method === 'eth_getTransactionReceipt') {
        const txHash = params[0];
        const found = sandboxTransactions.find(t => t.transactionHash.toLowerCase() === (txHash || '').toLowerCase());
        return res.json({ jsonrpc: '2.0', id: req.body.id || 1, result: found || null });
      }

      return res.json({ jsonrpc: '2.0', id: req.body.id || 1, result: '0x0' });
    } catch (sandboxErr) {
      return res.status(500).json({ jsonrpc: '2.0', id: req.body.id || 1, error: { message: sandboxErr.message } });
    }
  }

  // Forward to real external RPC (Sepolia, Mainnet, Base, Arbitrum, Optimism, Polygon)
  try {
    const payload = JSON.stringify({
      jsonrpc: '2.0',
      id: req.body.id || Date.now(),
      method,
      params
    });

    const response = await fetch(rpcUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: payload,
      signal: AbortSignal.timeout(6000)
    });

    const result = await response.json();
    res.json(result);
  } catch (err) {
    res.status(502).json({
      jsonrpc: '2.0',
      id: req.body.id || 1,
      error: { code: -32603, message: `RPC Proxy Error: ${err.message}` }
    });
  }
});

// Faucet endpoint
app.post('/api/faucet', (req, res) => {
  const { address, chainId } = req.body;
  const isEthAddr = address && (ethers.isAddress(address) || ethers.isAddress(address.toLowerCase()));
  if (!isEthAddr) {
    return res.status(400).json({ error: 'Valid Ethereum address required' });
  }

  const normalized = address.toLowerCase();
  const state = getSandboxBalance(normalized);
  const addAmount = ethers.parseEther('1.5');
  state.balanceWei += addAmount;

  res.json({
    success: true,
    address,
    addedEth: '1.5',
    newBalanceEth: ethers.formatEther(state.balanceWei),
    message: chainId === 1337 
      ? '1.5 ETH added to Sandbox balance' 
      : 'For Sepolia/testnets, use official faucets (https://cloud.google.com/application/web3/faucet/ethereum/sepolia) or test on Sandbox network.'
  });
});

// Serve static client assets
app.use(express.static(docsDir, {
  extensions: ['html'],
  index: 'index.html'
}));

// Route fallbacks
app.get('/privacy', (req, res) => {
  res.sendFile(path.join(docsDir, 'privacy.html'));
});

app.get('/support', (req, res) => {
  res.sendFile(path.join(docsDir, 'support.html'));
});

// SPA fallback for any unmatched request
app.use((req, res) => {
  res.sendFile(path.join(docsDir, 'index.html'));
});

app.listen(PORT, HOST, () => {
  console.log(`VaultETH App server running on http://${HOST}:${PORT}`);
});
