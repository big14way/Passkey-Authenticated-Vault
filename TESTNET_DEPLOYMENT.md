# Passkey Vault - Testnet Deployment Guide

## 🎉 Successfully Deployed!

The Passkey-Authenticated Vault contract has been successfully deployed to Stacks Testnet running **Clarity 4 (Epoch 3.3)**.

### Deployment Details

- **Contract Address**: `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.passkey-vault`
- **Transaction ID**: `beee957e06ef10f0daf8aaff83b2cc3f0515c8120df4b810c4fa7c7ce94710ab`
- **Network**: Stacks Testnet
- **Clarity Version**: 4
- **Epoch**: 3.3
- **Deployment Cost**: 0.163880 STX
- **Deployment Date**: December 12, 2025

### Quick Links

- **Explorer**: [View Contract](https://explorer.hiro.so/txid/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.passkey-vault?chain=testnet)
- **Transaction**: [View TX](https://explorer.hiro.so/txid/beee957e06ef10f0daf8aaff83b2cc3f0515c8120df4b810c4fa7c7ce94710ab?chain=testnet)
- **Hiro Platform**: [Interact with Contract](https://platform.hiro.so/sandbox/contract-call?chain=testnet)

## Testing the Contract

### 1. Verify Deployment

```bash
# Run the test script
bash test-contract-testnet.sh
```

Or manually:

```bash
# Check contract interface
curl "https://api.testnet.hiro.so/v2/contracts/interface/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM/passkey-vault"

# Get protocol stats
curl -X POST 'https://api.testnet.hiro.so/v2/contracts/call-read/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM/passkey-vault/get-protocol-stats' \
  -H 'Content-Type: application/json' \
  -d '{"sender":"ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM","arguments":[]}'
```

### 2. Create a Test Vault

#### Using Hiro Platform Sandbox

1. Go to: https://platform.hiro.so/sandbox/contract-call?chain=testnet
2. Enter contract: `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.passkey-vault`
3. Select function: `create-vault`
4. Fill in parameters:
   - **passkey-public-key** (buff 33): Your compressed secp256r1 public key
     - Example: `0x02aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`
   - **time-lock-duration** (uint): `0` (no lock) or seconds
   - **withdrawal-limit** (uint): `1000000000` (1000 STX in microSTX)
5. Connect wallet and submit transaction

#### Using Stacks CLI

```bash
stacks-cli call ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM passkey-vault create-vault \
  --testnet \
  --arg passkey-public-key:0x02aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  --arg time-lock-duration:0 \
  --arg withdrawal-limit:1000000000
```

### 3. Deposit STX

```bash
stacks-cli call ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM passkey-vault deposit-stx \
  --testnet \
  --arg vault-id:1 \
  --arg amount:100000000
```

### 4. Read Vault Data

```bash
# Get vault by ID
curl -X POST 'https://api.testnet.hiro.so/v2/contracts/call-read/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM/passkey-vault/get-vault' \
  -H 'Content-Type: application/json' \
  -d '{"sender":"ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM","arguments":["0x0100000000000000000000000000000001"]}'

# Get vault by owner
curl -X POST 'https://api.testnet.hiro.so/v2/contracts/call-read/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM/passkey-vault/get-vault-by-owner' \
  -H 'Content-Type: application/json' \
  -d '{"sender":"ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM","arguments":["0x051234..."]}'
```

## Contract Functions Available

### Public Functions

1. **create-vault** - Create a new vault
   - Parameters: `passkey-public-key (buff 33)`, `time-lock-duration (uint)`, `withdrawal-limit (uint)`
   - Returns: `vault-id`

2. **deposit-stx** - Deposit STX (owner only)
   - Parameters: `vault-id (uint)`, `amount (uint)`
   - Returns: `bool`

3. **withdraw-with-passkey** - Withdraw with signature
   - Parameters: `vault-id (uint)`, `amount (uint)`, `signature (buff 64)`
   - Returns: `bool`

4. **update-passkey** - Update passkey public key
   - Parameters: `vault-id (uint)`, `new-public-key (buff 33)`, `signature (buff 64)`
   - Returns: `bool`

5. **set-time-lock** - Add time-lock
   - Parameters: `vault-id (uint)`, `duration (uint)`
   - Returns: `bool`

6. **update-withdrawal-limit** - Change daily limit
   - Parameters: `vault-id (uint)`, `new-limit (uint)`
   - Returns: `bool`

7. **set-recovery-contact** - Set emergency contact
   - Parameters: `vault-id (uint)`, `contact (principal)`, `recovery-delay (uint)`
   - Returns: `bool`

8. **emergency-recovery** - Recovery withdrawal (to owner)
   - Parameters: `vault-id (uint)`
   - Returns: `bool`

### Read-Only Functions

- `get-vault (vault-id)` - Get vault details
- `get-vault-by-owner (owner)` - Find vault by owner
- `get-nonce (vault-id)` - Get current nonce
- `is-time-locked (vault-id)` - Check time-lock status
- `get-time-lock-remaining (vault-id)` - Get remaining time
- `get-daily-withdrawal-available (vault-id)` - Check daily limit
- `get-protocol-stats ()` - Get protocol statistics
- `get-block-timestamp ()` - Get current block time

## Clarity 4 Features Used

### 1. secp256r1-verify
Used for WebAuthn/passkey signature verification in withdrawals and passkey updates.

```clarity
(secp256r1-verify message-hash signature public-key)
```

### 2. stacks-block-time
On-chain timestamp for time-locks and activity tracking.

```clarity
(define-read-only (get-block-timestamp)
  (ok stacks-block-time)
)
```

### 3. as-contract? (Clarity 4)
Secure context switching with explicit asset allowances.

```clarity
(as-contract? ((with-stx amount))
  (unwrap-panic (stx-transfer? amount tx-sender recipient))
)
```

## Security Features

✅ **Owner-Only Deposits**: Only vault owners can deposit to their vaults
✅ **Public Key Validation**: Strict secp256r1 compressed key format (33 bytes, starts with 0x02/0x03)
✅ **Replay Protection**: Nonce-based signature verification prevents reuse
✅ **Time-Lock Enforcement**: Funds locked during active periods
✅ **Daily Limits**: Rate limiting prevents rapid fund extraction (1 STX - 1M STX)
✅ **Emergency Recovery Security**: Funds only transfer to vault owner
✅ **Emergency Shutdown**: Admin can pause all operations
✅ **Event Logging**: Print statements for all major operations

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 100 | ERR_NOT_AUTHORIZED | Caller not authorized |
| 101 | ERR_VAULT_NOT_FOUND | Vault does not exist |
| 102 | ERR_INSUFFICIENT_BALANCE | Insufficient balance or exceeds daily limit |
| 103 | ERR_INVALID_SIGNATURE | Invalid passkey signature |
| 104 | ERR_TIME_LOCK_ACTIVE | Withdrawal blocked by time-lock |
| 105 | ERR_INVALID_TIME_LOCK | Time-lock duration out of range |
| 106 | ERR_VAULT_EXISTS | Vault already exists for owner |
| 107 | ERR_ZERO_AMOUNT | Amount must be > 0 |
| 108 | ERR_INVALID_PUBLIC_KEY | Invalid public key format |
| 109 | ERR_INVALID_WITHDRAWAL_LIMIT | Withdrawal limit out of range |

## Monitoring

### Contract Activity

- **Explorer**: https://explorer.hiro.so/txid/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.passkey-vault?chain=testnet
- **Transactions**: https://api.testnet.hiro.so/extended/v1/address/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM/transactions

### Event Logs

The contract emits events for all major operations:
- `vault-created`
- `deposit`
- `withdrawal`
- `passkey-updated`
- `time-lock-set`
- `withdrawal-limit-updated`
- `recovery-contact-set`
- `emergency-recovery`
- `emergency-shutdown-toggle`

## Next Steps

1. ✅ Contract deployed and verified
2. 🔄 Create test vaults on testnet
3. 🔄 Test all functions with real transactions
4. 🔄 Monitor contract behavior
5. ⏳ Security audit (recommended before mainnet)
6. ⏳ Mainnet deployment

## Support

- **GitHub**: [Report Issues](https://github.com/big14way/Passkey-Authenticated-Vault/issues)
- **Stacks Discord**: [Get Help](https://discord.gg/stacks)
- **Documentation**: See [README.md](README.md)

---

**⚠️ Testnet Disclaimer**: This is a testnet deployment for testing purposes. Do not send real mainnet STX to this contract.
