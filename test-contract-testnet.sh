#!/bin/bash

echo "=== Testing Passkey Vault on Testnet ==="
echo ""
echo "Contract: ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.passkey-vault"
echo "Network: Stacks Testnet"
echo ""

echo "1. Getting protocol stats..."
curl -X POST 'https://api.testnet.hiro.so/v2/contracts/call-read/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM/passkey-vault/get-protocol-stats' \
  -H 'Content-Type: application/json' \
  -d '{"sender":"ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM","arguments":[]}' 2>/dev/null | python3 -m json.tool
echo ""

echo "2. Getting block timestamp..."
curl -X POST 'https://api.testnet.hiro.so/v2/contracts/call-read/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM/passkey-vault/get-block-timestamp' \
  -H 'Content-Type: application/json' \
  -d '{"sender":"ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM","arguments":[]}' 2>/dev/null | python3 -m json.tool
echo ""

echo "3. Contract deployment info..."
echo "Transaction ID: beee957e06ef10f0daf8aaff83b2cc3f0515c8120df4b810c4fa7c7ce94710ab"
echo "Explorer: https://explorer.hiro.so/txid/beee957e06ef10f0daf8aaff83b2cc3f0515c8120df4b810c4fa7c7ce94710ab?chain=testnet"
echo ""

echo "=== Test Complete ==="
echo ""
echo "To interact with the contract:"
echo "  - Hiro Platform: https://platform.hiro.so/sandbox/contract-call?chain=testnet"
echo "  - Contract Address: ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.passkey-vault"
