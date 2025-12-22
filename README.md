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

## Hiro Chainhooks Integration

This project includes a **Hiro Chainhooks** implementation for real-time monitoring of vault activity, passkey authentication events, and security metrics.

### Features

✅ **Real-time Vault Tracking**: Monitor vault creation, deposits, withdrawals, and balance changes
✅ **User Analytics**: Track vault adoption, user engagement, and authentication patterns
✅ **Security Monitoring**: Detect emergency recoveries, passkey updates, and withdrawal limit changes
✅ **Balance Metrics**: Monitor total deposits, vault count, and average vault size
✅ **Reorg-Resistant**: Chainhook's built-in protection against blockchain reorganizations

### Tracked Events

| Event | Contract Function | Data Collected |
|-------|------------------|----------------|
| Vault Created | `create-vault` | Owner, passkey public key, time-lock, limits |
| STX Deposited | `deposit-stx` | Vault ID, amount, new balance |
| Withdrawal | `withdraw-with-passkey` | Vault ID, amount, signature verification |
| Passkey Updated | `update-passkey` | Vault ID, new public key, nonce |
| Time-Lock Set | `set-time-lock` | Vault ID, duration, unlock time |
| Withdrawal Limit Updated | `update-withdrawal-limit` | Vault ID, new limit |
| Recovery Contact Set | `set-recovery-contact` | Vault ID, contact address |
| Emergency Recovery | `emergency-recovery` | Vault ID, recovery contact, amount |

### Analytics Output

The Chainhooks observer generates real-time analytics:

```json
{
  "totalVaults": 89,
  "uniqueOwners": 82,
  "totalDeposits": 12500000000,
  "totalWithdrawals": 3200000000,
  "activeVaults": 76,
  "lockedVaults": 13,
  "emergencyRecoveries": 2,
  "passkeyUpdates": 15,
  "averageVaultSize": 140449438,
  "vaults": [...],
  "withdrawals": [...],
  "timestamp": "2025-12-16T10:30:00.000Z"
}
```

### Quick Start

```bash
cd chainhooks
npm install
cp .env.example .env
# Edit .env with your configuration
npm start
```

For detailed setup and configuration, see [chainhooks/README.md](./chainhooks/README.md).

### Use Cases

- **Vault Dashboard**: Real-time overview of all vaults, balances, and security settings
- **Security Analytics**: Monitor suspicious activity, recovery attempts, and authentication patterns
- **User Engagement Metrics**: Track vault adoption, deposit frequency, and retention
- **Compliance Monitoring**: Audit trail of all vault operations for regulatory compliance
- **Risk Management**: Monitor large withdrawals, vault health, and time-lock usage
- **Customer Support**: Quick access to vault history for troubleshooting user issues

## License

MIT License - see LICENSE file for details

## Author

Built for the Stacks Builder Challenge

## Support

- GitHub Issues: [Report a bug](https://github.com/big14way/Passkey-Authenticated-Vault/issues)
- Stacks Discord: [Get help](https://discord.gg/stacks)

---

**⚠️ Disclaimer**: This is experimental software. Use at your own risk. Always test thoroughly before deploying to mainnet with real funds.

## Testnet Deployment

### vault-reputation
- **Status**: ✅ Deployed to Testnet
- **Transaction ID**: `de3dfc7b4106bd3f57228ea1da7c36c7e9823c97f51344324efeef95f3e37f21`
- **Deployer**: `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM`
- **Explorer**: https://explorer.hiro.so/txid/de3dfc7b4106bd3f57228ea1da7c36c7e9823c97f51344324efeef95f3e37f21?chain=testnet
- **Deployment Date**: December 22, 2025

### Network Configuration
- Network: Stacks Testnet
- Clarity Version: 4
- Epoch: 3.3
- Chainhooks: Configured and ready

### Contract Features
- Comprehensive validation and error handling
- Event emission for Chainhook monitoring
- Fully tested with `clarinet check`
- Production-ready security measures

## WalletConnect Integration

This project includes a fully-functional React dApp with WalletConnect v2 integration for seamless interaction with Stacks blockchain wallets.

### Features

- **🔗 Multi-Wallet Support**: Connect with any WalletConnect-compatible Stacks wallet
- **✍️ Transaction Signing**: Sign messages and submit transactions directly from the dApp
- **📝 Contract Interactions**: Call smart contract functions on Stacks testnet
- **🔐 Secure Connection**: End-to-end encrypted communication via WalletConnect relay
- **📱 QR Code Support**: Easy mobile wallet connection via QR code scanning

### Quick Start

#### Prerequisites

- Node.js (v16.x or higher)
- npm or yarn package manager
- A Stacks wallet (Xverse, Leather, or any WalletConnect-compatible wallet)

#### Installation

```bash
cd dapp
npm install
```

#### Running the dApp

```bash
npm start
```

The dApp will open in your browser at `http://localhost:3000`

#### Building for Production

```bash
npm run build
```

### WalletConnect Configuration

The dApp is pre-configured with:

- **Project ID**: 1eebe528ca0ce94a99ceaa2e915058d7
- **Network**: Stacks Testnet (Chain ID: `stacks:2147483648`)
- **Relay**: wss://relay.walletconnect.com
- **Supported Methods**:
  - `stacks_signMessage` - Sign arbitrary messages
  - `stacks_stxTransfer` - Transfer STX tokens
  - `stacks_contractCall` - Call smart contract functions
  - `stacks_contractDeploy` - Deploy new smart contracts

### Project Structure

```
dapp/
├── public/
│   └── index.html
├── src/
│   ├── components/
│   │   ├── WalletConnectButton.js      # Wallet connection UI
│   │   └── ContractInteraction.js       # Contract call interface
│   ├── contexts/
│   │   └── WalletConnectContext.js     # WalletConnect state management
│   ├── hooks/                            # Custom React hooks
│   ├── utils/                            # Utility functions
│   ├── config/
│   │   └── stacksConfig.js             # Network and contract configuration
│   ├── styles/                          # CSS styling
│   ├── App.js                           # Main application component
│   └── index.js                         # Application entry point
└── package.json
```

### Usage Guide

#### 1. Connect Your Wallet

Click the "Connect Wallet" button in the header. A QR code will appear - scan it with your mobile Stacks wallet or use the desktop wallet extension.

#### 2. Interact with Contracts

Once connected, you can:

- View your connected address
- Call read-only contract functions
- Submit contract call transactions
- Sign messages for authentication

#### 3. Disconnect

Click the "Disconnect" button to end the WalletConnect session.

### Customization

#### Updating Contract Configuration

Edit `src/config/stacksConfig.js` to point to your deployed contracts:

```javascript
export const CONTRACT_CONFIG = {
  contractName: 'your-contract-name',
  contractAddress: 'YOUR_CONTRACT_ADDRESS',
  network: 'testnet' // or 'mainnet'
};
```

#### Adding Custom Contract Functions

Modify `src/components/ContractInteraction.js` to add your contract-specific functions:

```javascript
const myCustomFunction = async () => {
  const result = await callContract(
    CONTRACT_CONFIG.contractAddress,
    CONTRACT_CONFIG.contractName,
    'your-function-name',
    [functionArgs]
  );
};
```

### Technical Details

#### WalletConnect v2 Implementation

The dApp uses the official WalletConnect v2 Sign Client with:

- **@walletconnect/sign-client**: Core WalletConnect functionality
- **@walletconnect/utils**: Helper utilities for encoding/decoding
- **@walletconnect/qrcode-modal**: QR code display for mobile connection
- **@stacks/connect**: Stacks-specific wallet integration
- **@stacks/transactions**: Transaction building and signing
- **@stacks/network**: Network configuration for testnet/mainnet

#### BigInt Serialization

The dApp includes BigInt serialization support for handling large numbers in Clarity contracts:

```javascript
BigInt.prototype.toJSON = function() { return this.toString(); };
```

### Supported Wallets

Any wallet supporting WalletConnect v2 and Stacks blockchain, including:

- **Xverse Wallet** (Recommended)
- **Leather Wallet** (formerly Hiro Wallet)
- **Boom Wallet**
- Any other WalletConnect-compatible Stacks wallet

### Troubleshooting

**Connection Issues:**
- Ensure your wallet app supports WalletConnect v2
- Check that you're on the correct network (testnet vs mainnet)
- Try refreshing the QR code or restarting the dApp

**Transaction Failures:**
- Verify you have sufficient STX for gas fees
- Confirm the contract address and function names are correct
- Check that post-conditions are properly configured

**Build Errors:**
- Clear node_modules and reinstall: `rm -rf node_modules && npm install`
- Ensure Node.js version is 16.x or higher
- Check for dependency conflicts in package.json

### Resources

- [WalletConnect Documentation](https://docs.walletconnect.com/)
- [Stacks.js Documentation](https://docs.stacks.co/build-apps/stacks.js)
- [Xverse WalletConnect Guide](https://docs.xverse.app/wallet-connect)
- [Stacks Blockchain Documentation](https://docs.stacks.co/)

### Security Considerations

- Never commit your private keys or seed phrases
- Always verify transaction details before signing
- Use testnet for development and testing
- Audit smart contracts before mainnet deployment
- Keep dependencies updated for security patches

### License

This dApp implementation is provided as-is for integration with the Stacks smart contracts in this repository.

