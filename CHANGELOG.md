# Changelog

All notable changes to the Passkey-Authenticated Vault project.

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
