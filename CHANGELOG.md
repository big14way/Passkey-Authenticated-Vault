# Changelog

All notable changes to the Passkey-Authenticated Vault project.

## [1.2.0] - 2025-12-12

### Clarity 4 Upgrade

#### Upgraded
- **Clarity Version**: Upgraded from Clarity 3 to **Clarity 4** (Epoch 3.3)
- **as-contract Migration**: Migrated all `as-contract` calls to `as-contract?` with proper STX allowances
  - Updated deposit function to use `as-contract?` with zero allowance
  - Updated withdrawal function with explicit STX transfer allowance
  - Updated emergency recovery with balance-based allowance
- **Test Framework**: Migrated from Deno-based tests to modern **vitest** framework
- **npm Package**: Added package.json, vitest.config.ts, and tsconfig.json for modern testing

#### Deployed
- **Testnet Deployment**: Successfully deployed to Stacks Testnet
  - Contract: `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.passkey-vault`
  - Transaction: `beee957e06ef10f0daf8aaff83b2cc3f0515c8120df4b810c4fa7c7ce94710ab`
  - Deployment Cost: 0.163880 STX
  - Network: Stacks Testnet (Clarity 4, Epoch 3.3)

#### Enhanced
- **Withdrawal Limit Validation**: Added constants for min (1 STX) and max (1M STX) withdrawal limits
- **Event Logging**: Enhanced print statements for all major contract operations
- **Emergency Shutdown**: Improved to block all operations including deposits

#### Testing
- **10 vitest test cases** - All passing on Clarity 4
- Test suite covers:
  - Vault creation with validation
  - Deposits (owner-only)
  - Public key format validation
  - Emergency shutdown behavior
  - Time-lock functionality
  - Nonce tracking

## [1.1.0] - 2025-12-12

### Critical Security Fixes

#### Fixed
- **Clarinet Configuration**: Changed `clarity_version` from 3 to 4 to properly support Clarity 4 features
- **Emergency Recovery Vulnerability**: Removed arbitrary `recipient` parameter from `emergency-recovery` function. Funds now only transfer to vault owner, preventing potential fund theft by compromised recovery contacts
- **Replay Attack in Update Passkey**: Added nonce to `update-passkey` message hash for replay protection
- **Public Key Validation**: Added strict validation for secp256r1 public keys (must be 33 bytes, start with 0x02 or 0x03)
- **Unauthorized Deposits**: Restricted deposits to vault owner only, preventing unauthorized deposits to vaults

### Added
- Real secp256r1 signature generation script (`scripts/generate-test-keys.js`)
- New test suite with real cryptographic signatures (`passkey-vault-real-signatures_test.ts`)
- 10 additional test cases covering:
  - Invalid public key format rejection
  - Owner-only deposit enforcement
  - Initial time-lock creation
  - Nonce tracking and replay protection
  - Emergency shutdown behavior
  - Time-lock calculations
- Comprehensive README documentation
- `.gitignore` file
- `CHANGELOG.md`

### Improved
- Test coverage: 27 comprehensive test cases
- Documentation with WebAuthn integration examples
- Error code reference table
- Architecture diagram
- Security considerations section

## [1.0.0] - 2025-12-11

### Initial Release

#### Features
- Passkey-authenticated withdrawals using `secp256r1-verify`
- Time-lock functionality using `stacks-block-time`
- Daily withdrawal limits
- Emergency recovery system
- Nonce-based replay protection
- Emergency shutdown capability

#### Contract Functions
- `create-vault` - Create new vault with passkey
- `deposit-stx` - Deposit STX into vault
- `withdraw-with-passkey` - Withdraw with signature
- `update-passkey` - Update passkey public key
- `set-time-lock` - Add time-lock protection
- `update-withdrawal-limit` - Modify daily limits
- `set-recovery-contact` - Configure emergency recovery
- `emergency-recovery` - Recovery contact withdrawal
- `emergency-shutdown-toggle` - Admin emergency control

#### Read-Only Functions
- `get-vault` - Retrieve vault details
- `get-vault-by-owner` - Find vault by owner
- `get-nonce` - Get current nonce
- `is-time-locked` - Check time-lock status
- `get-time-lock-remaining` - Calculate remaining time
- `get-daily-withdrawal-available` - Check daily limit
- `get-protocol-stats` - Protocol statistics
- `get-block-timestamp` - Current block time

#### Testing
- 17 initial test cases
- Basic functionality coverage
- Authorization checks
- Time-lock validation
