# Passkey Vault Chainhooks Integration

Real-time event tracking and analytics for the Passkey-Authenticated Vault platform. Monitors vault operations, deposits, withdrawals, and security features using Stacks Chainhooks.

## Features

### Event Tracking

This integration monitors all key Passkey Vault events:

1. **Vault Operations**
   - **Vault Creation** (`create-vault`) - New vault initialization with passkey
   - **Deposits** (`deposit-stx`) - STX deposits into vaults
   - **Withdrawals** (`withdraw-with-passkey`) - Passkey-authenticated withdrawals
   - Tracks total value locked (TVL)
   - Monitors vault balances

2. **Security Features**
   - **Time-Locks** (`set-time-lock`) - Withdrawal delay settings
   - **Passkey Updates** (`update-passkey`) - Changing authentication keys
   - **Recovery Contacts** (`set-recovery-contact`) - Emergency recovery setup
   - **Emergency Recovery** (`emergency-recovery`) - Recovery contact withdrawals
   - **Withdrawal Limits** (`update-withdrawal-limit`) - Daily limit adjustments

3. **Passkey Authentication**
   - Uses WebAuthn/FIDO2 passkeys (biometric, security keys)
   - Clarity 4 `secp256r1-verify` for signature validation
   - Nonce-based replay protection
   - Secure key rotation

4. **Analytics Metrics**
   - Total vaults created
   - Total value locked and withdrawn
   - Active time-locks
   - Security event tracking
   - User adoption metrics

### Analytics Collected

The integration tracks comprehensive metrics:

- **Users**: Unique vault owners
- **Vaults**: Total vaults created
- **TVL**: Total value locked in all vaults
- **Deposits/Withdrawals**: Transaction counts and volumes
- **Security Events**: Passkey updates, recovery operations
- **Time-Locks**: Active withdrawal restrictions
- **Average Vault Balance**: TVL / vault count

## Setup

### Prerequisites

- Node.js 18+ and npm
- Access to a Stacks Chainhook node (Hiro Platform or self-hosted)
- The Passkey Vault contract deployed on Stacks testnet/mainnet

### Installation

1. Navigate to the chainhooks directory:
```bash
cd passkey-vault/chainhooks
```

2. Install dependencies:
```bash
npm install
```

3. Copy and configure environment variables:
```bash
cp .env.example .env
```

4. Edit `.env` with your configuration:
```env
# Chainhook Node Configuration
CHAINHOOK_NODE_URL=http://localhost:20456

# Server Configuration
SERVER_HOST=0.0.0.0
SERVER_PORT=3002
SERVER_AUTH_TOKEN=your-secret-token-here
EXTERNAL_BASE_URL=http://localhost:3002

# Contract Configuration
VAULT_CONTRACT=ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.passkey-vault

# Starting block height
START_BLOCK=0

# Network
NETWORK=testnet
```

### Running the Observer

Start the Chainhook observer:

```bash
npm start
```

For development with auto-reload:

```bash
npm run dev
```

## Contract Events

### Monitored Functions

| Function | Description | Security | Fee |
|----------|-------------|----------|-----|
| `create-vault` | Create new vault | Passkey required | None |
| `deposit-stx` | Deposit STX | Owner only | None |
| `withdraw-with-passkey` | Withdraw with auth | Passkey signature | None |
| `set-time-lock` | Set withdrawal delay | Owner only | None |
| `update-passkey` | Change passkey | Current passkey | None |
| `set-recovery-contact` | Set recovery | Owner only | None |
| `emergency-recovery` | Recover funds | Recovery contact | None |
| `update-withdrawal-limit` | Change daily limit | Owner only | None |

### Print Events Tracked

The contract emits detailed print events:

```clarity
{event: "vault-created", vault-id: uint, owner: principal, time-lock: uint}
{event: "deposit", vault-id: uint, amount: uint, new-balance: uint}
{event: "withdrawal", vault-id: uint, amount: uint, nonce: uint, remaining-balance: uint}
{event: "time-lock-set", vault-id: uint, duration: uint, locked-until: uint}
{event: "passkey-updated", vault-id: uint, nonce: uint}
{event: "recovery-contact-set", vault-id: uint, contact: principal, can-recover-after: uint}
{event: "emergency-recovery", vault-id: uint, amount: uint, recovered-by: principal, owner: principal}
{event: "withdrawal-limit-updated", vault-id: uint, new-limit: uint}
```

## Analytics Output

Analytics data is saved to `analytics-data.json`:

```json
{
  "users": ["ST1...", "ST2..."],
  "uniqueUsers": 42,
  "totalVaults": 156,
  "totalDeposits": 892,
  "totalWithdrawals": 445,
  "totalValueLocked": 500000000000,
  "totalValueWithdrawn": 250000000000,
  "avgVaultBalance": 3205128205,
  "activeTimeLocks": 78,
  "emergencyRecoveries": 2,
  "passkeyUpdates": 23,
  "vaultCreations": [
    {
      "owner": "ST...",
      "timestamp": "2024-01-15T10:30:00.000Z",
      "txid": "0x..."
    }
  ],
  "deposits": [...],
  "withdrawals": [...],
  "securityEvents": [...],
  "timestamp": "2024-01-15T12:00:00.000Z"
}
```

## Key Metrics

### Vault Statistics

- **Total Vaults**: Number of vaults created
- **Active Vaults**: Vaults with non-zero balance
- **TVL**: Total STX locked across all vaults
- **Average Balance**: Mean vault balance

### Security Metrics

- **Time-Locks**: Vaults with active withdrawal delays
- **Passkey Updates**: Key rotation frequency
- **Emergency Recoveries**: Recovery operations executed
- **Daily Limits**: Withdrawal limit enforcement

### Usage Patterns

- **Deposit Frequency**: Average deposits per vault
- **Withdrawal Patterns**: Timing and amounts
- **Security Adoption**: % vaults with time-locks/recovery

## Use Cases

### DeFi Analytics
- Track total value locked in vaults
- Monitor deposit/withdrawal trends
- Analyze user retention

### Security Monitoring
- Track passkey rotation frequency
- Monitor emergency recovery usage
- Identify suspicious patterns

### Product Insights
- Most popular security features
- Average vault balances
- User adoption metrics

### Risk Management
- Track time-lock adoption
- Monitor large withdrawals
- Identify potential issues

## Architecture

The integration uses the Hiro Chainhook Event Observer to:

1. Register predicates for vault contract functions
2. Listen for on-chain events in real-time
3. Parse transaction data and print events
4. Aggregate vault and security metrics
5. Persist analytics with graceful shutdown

## Troubleshooting

### Observer won't start
- Verify Chainhook node URL is accessible
- Check contract address matches deployment
- Ensure START_BLOCK is valid

### Missing vault events
- Confirm contract is deployed and active
- Verify network setting matches deployment
- Check Chainhook node sync status

### TVL calculation issues
- Ensure all deposits/withdrawals are captured
- Verify balance tracking logic
- Check for reorg handling

## Production Considerations

For production deployments:

1. **Database Integration**: Use PostgreSQL for vault state tracking
2. **Balance Reconciliation**: Periodically sync with on-chain state
3. **Security Alerts**: Monitor unusual withdrawal patterns
4. **User Dashboard**: Real-time vault balance and activity
5. **Backup & Recovery**: Secure analytics data storage
6. **API Layer**: Expose metrics via REST/GraphQL

## Passkey Authentication

This vault uses WebAuthn/FIDO2 passkeys for secure, user-friendly authentication:

### Benefits
- **Biometric Auth**: Face ID, Touch ID, Windows Hello
- **Hardware Keys**: YubiKey, Titan Security Key
- **Phishing Resistant**: Cryptographic signatures
- **No Passwords**: Better UX and security

### Clarity 4 Integration
Uses `secp256r1-verify` for:
- Validating ECDSA signatures from passkeys
- Nonce-based replay protection
- Secure key rotation

### Security Model
1. **Vault Creation**: User registers passkey public key
2. **Withdrawal**: User signs message with passkey
3. **Verification**: Contract validates secp256r1 signature
4. **Nonce Increment**: Prevents replay attacks

## Security Features

### Time-Locks
- Configurable withdrawal delays (1 hour to 365 days)
- Protection against compromised keys
- Can be updated by vault owner

### Daily Withdrawal Limits
- Configurable limits (1 STX to 1M STX per day)
- Automatic reset after 24 hours
- Protection against large unauthorized withdrawals

### Recovery Contacts
- Trusted contact for emergency recovery
- Requires waiting period (7+ days)
- Funds always go to vault owner (not contact)

### Emergency Shutdown
- Admin can pause all operations
- Protection during security incidents
- Deposits/withdrawals blocked when active

## Contract Information

- **Contract**: `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.passkey-vault`
- **Network**: Stacks Testnet
- **Clarity Version**: 4 (Epoch 3.3)
- **Features**: `secp256r1-verify`, `stacks-block-time`

## Resources

- [Stacks Chainhooks Documentation](https://docs.hiro.so/chainhooks)
- [Passkey Vault Contract](../contracts/passkey-vault.clar)
- [WebAuthn Specification](https://www.w3.org/TR/webauthn/)
- [Hiro Platform](https://platform.hiro.so/)

## License

MIT
