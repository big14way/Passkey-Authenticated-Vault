# Passkey-Authenticated Vault

A secure STX savings vault with biometric/passkey authentication using Clarity 4's new cryptographic features.

## Clarity 4 Features Used

1. **`secp256r1-verify`** - Enables WebAuthn/passkey signature verification for secure withdrawals
2. **`stacks-block-time`** - On-chain timestamp for time-locks and activity tracking

## Features

- 🔐 **Passkey Authentication**: Withdraw funds using device biometrics (Face ID, fingerprint, etc.)
- ⏰ **Time-Locks**: Lock funds for a specified duration (1 hour to 365 days)
- 📊 **Daily Withdrawal Limits**: Protect against rapid fund drainage
- 🆘 **Emergency Recovery**: Designate a trusted contact for account recovery
- 🔢 **Replay Protection**: Nonce-based signature verification prevents replay attacks
- 🛑 **Emergency Shutdown**: Admin can pause deposits in emergencies
- ✅ **Owner-Only Deposits**: Only vault owners can deposit to their vaults
- 🔒 **Public Key Validation**: Strict secp256r1 compressed key format validation

## 🚀 Live on Testnet!

**Contract Address**: `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.passkey-vault`
**Transaction**: [beee957e06ef10f0daf8aaff83b2cc3f0515c8120df4b810c4fa7c7ce94710ab](https://explorer.hiro.so/txid/beee957e06ef10f0daf8aaff83b2cc3f0515c8120df4b810c4fa7c7ce94710ab?chain=testnet)
**Explorer**: [View Contract](https://explorer.hiro.so/txid/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.passkey-vault?chain=testnet)

## Recent Security Fixes

### Critical Fixes (v1.1.0)
- ✅ Upgraded to **Clarity 4** with `as-contract?` migration
- ✅ Emergency recovery now only transfers to vault owner (prevents fund theft)
- ✅ Added nonce to update-passkey for replay protection
- ✅ Validated public key format (33 bytes, starts with 0x02 or 0x03)
- ✅ Restricted deposits to vault owner only
- ✅ Added withdrawal limit validation (1 STX - 1M STX)
- ✅ Enhanced emergency shutdown blocking all operations
- ✅ Event logging with print statements

### Test Coverage
- 10 comprehensive vitest test cases
- All tests passing on Clarity 4
- Security and edge case validation

## Contract Functions

### Vault Management
- `create-vault` - Create a new vault with passkey
- `deposit-stx` - Deposit STX into your vault (owner only)
- `withdraw-with-passkey` - Withdraw with passkey signature
- `update-passkey` - Update your passkey public key

### Security Features
- `set-time-lock` - Add time-lock to your vault
- `update-withdrawal-limit` - Change daily withdrawal limit
- `set-recovery-contact` - Add emergency recovery contact
- `emergency-recovery` - Recovery contact can withdraw to owner after delay

### Read-Only
- `get-vault` - Get vault details by ID
- `get-vault-by-owner` - Get vault by owner principal
- `get-nonce` - Get current nonce for replay protection
- `is-time-locked` - Check if vault is time-locked
- `get-time-lock-remaining` - Get remaining lock duration
- `get-daily-withdrawal-available` - Check available daily withdrawal
- `get-protocol-stats` - Get total vaults and deposits
- `get-block-timestamp` - Get current block timestamp

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) v1.7.0+
- Node.js 16+ (for test key generation)
- Deno (for running tests)

### Installation

```bash
git clone https://github.com/big14way/Passkey-Authenticated-Vault.git
cd Passkey-Authenticated-Vault
clarinet check
```

### Running Tests

```bash
# Install dependencies
npm install

# Run all tests with vitest
npm test

# Run with coverage
npm run test:report
```

### Deploy to Testnet

```bash
# Generate deployment plan
clarinet deployments generate --testnet --medium-cost

# Apply deployment
clarinet deployments apply --testnet --no-dashboard
```

## Testing on Testnet

### 1. Check Contract Deployment

```bash
# View contract on explorer
open "https://explorer.hiro.so/txid/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.passkey-vault?chain=testnet"

# Or check via API
curl "https://api.testnet.hiro.so/v2/contracts/interface/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM/passkey-vault"
```

### 2. Create a Test Vault

Using Stacks CLI or Hiro Platform:

```bash
# Using stacks-cli
stacks-cli call ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM passkey-vault create-vault \
  -t \
  --arg passkey-public-key:0x02aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  --arg time-lock-duration:0 \
  --arg withdrawal-limit:1000000000
```

Or via the [Hiro Platform Sandbox](https://platform.hiro.so/sandbox/contract-call?chain=testnet):
- Contract: `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.passkey-vault`
- Function: `create-vault`
- Parameters:
  - `passkey-public-key`: (buff 33 bytes) - Your compressed secp256r1 public key
  - `time-lock-duration`: (uint) - 0 for no lock, or seconds for lock
  - `withdrawal-limit`: (uint) - Daily limit in microSTX

### 3. Read Vault Data

```bash
# Get vault by ID
curl -X POST "https://api.testnet.hiro.so/v2/contracts/call-read/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM/passkey-vault/get-vault" \
  -H "Content-Type: application/json" \
  -d '{
    "sender": "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
    "arguments": ["0x0100000000000000000000000000000001"]
  }'

# Get protocol stats
curl -X POST "https://api.testnet.hiro.so/v2/contracts/call-read/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM/passkey-vault/get-protocol-stats" \
  -H "Content-Type: application/json" \
  -d '{
    "sender": "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
    "arguments": []
  }'
```

### 4. Monitor Contract Activity

- **Explorer**: https://explorer.hiro.so/txid/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.passkey-vault?chain=testnet
- **API Transactions**: https://api.testnet.hiro.so/extended/v1/address/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM/transactions

## Usage Example

### 1. Create a Vault

```clarity
(contract-call? .passkey-vault create-vault
    0x02... ;; Your passkey public key (33-byte compressed secp256r1)
    u86400  ;; 1-day time lock (or u0 for no lock)
    u1000000000) ;; 1000 STX daily limit
```

**Public Key Requirements:**
- Must be exactly 33 bytes
- Must start with `0x02` or `0x03` (compressed format)
- Must be a valid secp256r1 (P-256) public key

### 2. Deposit STX

```clarity
(contract-call? .passkey-vault deposit-stx
    u1           ;; vault-id
    u500000000)  ;; Deposit 500 STX
```

**Note:** Only the vault owner can deposit to their vault.

### 3. Withdraw with Passkey

```clarity
(contract-call? .passkey-vault withdraw-with-passkey
    u1 ;; vault-id
    u100000000 ;; amount (100 STX)
    0x...) ;; passkey signature (64 bytes)
```

**Message Format for Signing:**
```
message = vault-id || amount || nonce
hash = sha256(message)
signature = sign(hash, private-key)
```

The nonce increments after each withdrawal to prevent replay attacks.

## Testing with Real Signatures

### Generate Test Keys

Run the key generator script to create real secp256r1 keys and signatures:

```bash
node scripts/generate-test-keys.js
```

This will output:
- Compressed public keys (33 bytes)
- Valid secp256r1 signatures (64 bytes)
- Pre-computed message hashes
- TypeScript constants for testing

### Test Files

1. **passkey-vault_test.ts** - Basic functionality tests (27 tests)
   - Vault creation and management
   - Authorization checks
   - Time-locks and limits
   - Edge cases

2. **passkey-vault-real-signatures_test.ts** - Real signature tests (9 tests)
   - Valid signature verification
   - Replay protection
   - Nonce tracking
   - Invalid signature rejection
   - Daily limit enforcement

## Frontend Integration

To integrate with WebAuthn passkeys:

```javascript
// 1. Create credential (registration)
const credential = await navigator.credentials.create({
    publicKey: {
        challenge: new Uint8Array(32),
        rp: { name: "Passkey Vault", id: "example.com" },
        user: {
            id: userIdBuffer,
            name: "user@example.com",
            displayName: "User"
        },
        pubKeyCredParams: [
            { type: "public-key", alg: -7 } // ES256 (secp256r1/P-256)
        ],
        authenticatorSelection: {
            authenticatorAttachment: "platform", // For biometrics
            userVerification: "required"
        }
    }
});

// 2. Extract public key from credential
const publicKey = extractPublicKeyFromCredential(credential);
// Convert to 33-byte compressed format
const compressedKey = compressPublicKey(publicKey);

// 3. Create vault with public key
await contractCall('passkey-vault', 'create-vault', [
    bufferCV(compressedKey),
    uintCV(86400),
    uintCV(1000000000)
]);

// 4. Sign withdrawal (authentication)
const vaultId = 1;
const amount = 100000000;
const nonce = await contractReadOnly('get-nonce', [uintCV(vaultId)]);

// Build message: vault-id || amount || nonce
const message = buildWithdrawalMessage(vaultId, amount, nonce);
const messageHash = sha256(message);

const assertion = await navigator.credentials.get({
    publicKey: {
        challenge: messageHash,
        allowCredentials: [{ type: "public-key", id: credentialId }],
        userVerification: "required"
    }
});

// 5. Extract signature and submit
const signature = extractSignature(assertion);
await contractCall('withdraw-with-passkey', [
    uintCV(vaultId),
    uintCV(amount),
    bufferCV(signature)
]);
```

### Helper Functions for Frontend

```javascript
// Convert uncompressed (65-byte) to compressed (33-byte) public key
function compressPublicKey(uncompressed) {
    const x = uncompressed.slice(1, 33);
    const y = uncompressed.slice(33, 65);
    const prefix = (y[y.length - 1] & 1) === 0 ? 0x02 : 0x03;
    return new Uint8Array([prefix, ...x]);
}

// Build message for withdrawal signing
function buildWithdrawalMessage(vaultId, amount, nonce) {
    // Convert to 16-byte big-endian buffers (Clarity uint format)
    const vaultIdBuf = uintToBuffer(vaultId);
    const amountBuf = uintToBuffer(amount);
    const nonceBuf = uintToBuffer(nonce);
    return concatBuffers([vaultIdBuf, amountBuf, nonceBuf]);
}

// Extract signature from WebAuthn assertion
function extractSignature(assertion) {
    const authData = new Uint8Array(assertion.response.authenticatorData);
    const signature = new Uint8Array(assertion.response.signature);

    // WebAuthn signatures are in DER format, need to convert to raw (r + s)
    return derToRaw(signature);
}
```

## Security Considerations

### ✅ Implemented Security Features

- **Passkey Storage**: Public keys stored on-chain; private keys remain in secure hardware
- **Replay Protection**: Nonce increments prevent signature reuse
- **Time-Lock Enforcement**: Funds locked during active time-lock period
- **Daily Limits**: Rate limiting prevents rapid fund extraction
- **Recovery Delay**: Minimum 7-day delay before recovery contact access
- **Owner-Only Deposits**: Prevents unauthorized deposits to vaults
- **Public Key Validation**: Strict format validation prevents malformed keys
- **Emergency Recovery Security**: Funds only transfer to vault owner

### ⚠️ Important Notes

1. **Passkey Security**: Relies on device security and WebAuthn implementation
2. **Key Management**: Lost passkeys can only be recovered via recovery contact
3. **Gas Costs**: Signature verification consumes more gas than traditional auth
4. **Browser Support**: Requires WebAuthn-compatible browser and device
5. **Withdrawal Limits**: Set appropriate daily limits based on use case

## Architecture

```
┌─────────────────┐
│   User Device   │
│  (Face ID/PIN)  │
└────────┬────────┘
         │ WebAuthn
         │ Signature
         ▼
┌─────────────────┐
│   Frontend      │
│  (Web/Mobile)   │
└────────┬────────┘
         │ Stacks TX
         ▼
┌─────────────────────────────────────┐
│   Passkey-Vault Smart Contract     │
│                                     │
│  - secp256r1-verify                │
│  - Time-locks (stacks-block-time)  │
│  - Daily limits                     │
│  - Nonce tracking                   │
│  - Emergency recovery               │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│  Stacks Chain   │
│  (STX Storage)  │
└─────────────────┘
```

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 100 | ERR_NOT_AUTHORIZED | Caller not authorized for this action |
| 101 | ERR_VAULT_NOT_FOUND | Vault does not exist |
| 102 | ERR_INSUFFICIENT_BALANCE | Insufficient balance or exceeds daily limit |
| 103 | ERR_INVALID_SIGNATURE | Invalid passkey signature |
| 104 | ERR_TIME_LOCK_ACTIVE | Withdrawal blocked by active time-lock |
| 105 | ERR_INVALID_TIME_LOCK | Time-lock duration outside valid range |
| 106 | ERR_VAULT_EXISTS | Vault already exists for this owner |
| 107 | ERR_ZERO_AMOUNT | Amount must be greater than zero |
| 108 | ERR_INVALID_PUBLIC_KEY | Invalid public key format |

## Development

### Project Structure

```
passkey-vault/
├── contracts/
│   └── passkey-vault.clar       # Main contract
├── tests/
│   ├── passkey-vault_test.ts    # Basic tests
│   └── passkey-vault-real-signatures_test.ts  # Real signature tests
├── scripts/
│   └── generate-test-keys.js    # Test key generator
├── settings/
│   └── Devnet.toml              # Network config
├── Clarinet.toml                # Project config
└── README.md
```

### Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Running Security Tests

```bash
# Check contract syntax
clarinet check

# Run all tests
clarinet test

# Check code coverage
clarinet coverage
```

## Roadmap

- [ ] Multi-signature support
- [ ] sBTC integration
- [ ] Vault sharing/delegation
- [ ] Time-based withdrawal schedules
- [ ] Integration with hardware wallets
- [ ] Mobile app with native biometrics

## Resources

- [Clarity 4 Documentation](https://docs.stacks.co/clarity/overview)
- [WebAuthn Specification](https://www.w3.org/TR/webauthn/)
- [secp256r1 (P-256) Curve](https://neuromancer.sk/std/secg/secp256r1)
- [Stacks Documentation](https://docs.stacks.co/)

## License

MIT License - see LICENSE file for details

## Author

Built for the Stacks Builder Challenge

## Support

- GitHub Issues: [Report a bug](https://github.com/big14way/Passkey-Authenticated-Vault/issues)
- Stacks Discord: [Get help](https://discord.gg/stacks)

---

**⚠️ Disclaimer**: This is experimental software. Use at your own risk. Always test thoroughly before deploying to mainnet with real funds.
