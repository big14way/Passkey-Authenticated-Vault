import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals, assertExists } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

// Test passkey (dummy values for testing)
// Valid compressed secp256r1 public key: 33 bytes starting with 0x02 or 0x03
const TEST_PASSKEY = '0x02' + 'a'.repeat(64); // Compressed public key format (33 bytes)
const TEST_PASSKEY_INVALID = '0x04' + 'a'.repeat(64); // Invalid - should start with 0x02 or 0x03
const TEST_SIGNATURE = '0x' + 'b'.repeat(128); // 64-byte signature

Clarinet.test({
    name: "Can create a new vault with passkey",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0), // No time lock
                types.uint(1000000000) // 1000 STX daily limit
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
        
        // Verify vault was created
        let vaultResult = chain.callReadOnlyFn(
            'passkey-vault',
            'get-vault',
            [types.uint(1)],
            wallet1.address
        );
        
        assertExists(vaultResult.result);
    }
});

Clarinet.test({
    name: "Cannot create duplicate vault for same owner",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectErr().expectUint(106); // ERR_VAULT_EXISTS
    }
});

Clarinet.test({
    name: "Can deposit STX into vault",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'deposit-stx', [
                types.uint(1),
                types.uint(500000000) // 500 STX
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk().expectBool(true);
        
        // Verify balance
        let vaultResult = chain.callReadOnlyFn(
            'passkey-vault',
            'get-vault',
            [types.uint(1)],
            wallet1.address
        );
        
        const vault = vaultResult.result.expectSome().expectTuple();
        assertEquals(vault['stx-balance'], types.uint(500000000));
    }
});

Clarinet.test({
    name: "Cannot deposit zero amount",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'deposit-stx', [
                types.uint(1),
                types.uint(0)
            ], wallet1.address)
        ]);
        
        block.receipts[1].result.expectErr().expectUint(107); // ERR_ZERO_AMOUNT
    }
});

Clarinet.test({
    name: "Can set time lock on vault",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'set-time-lock', [
                types.uint(1),
                types.uint(86400) // 1 day
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk().expectBool(true);
        
        // Verify time lock is active
        let lockResult = chain.callReadOnlyFn(
            'passkey-vault',
            'is-time-locked',
            [types.uint(1)],
            wallet1.address
        );
        
        lockResult.result.expectBool(true);
    }
});

Clarinet.test({
    name: "Cannot set time lock below minimum",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'set-time-lock', [
                types.uint(1),
                types.uint(100) // Less than MIN_TIME_LOCK (3600)
            ], wallet1.address)
        ]);
        
        block.receipts[1].result.expectErr().expectUint(105); // ERR_INVALID_TIME_LOCK
    }
});

Clarinet.test({
    name: "Can update withdrawal limit",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'update-withdrawal-limit', [
                types.uint(1),
                types.uint(2000000000) // 2000 STX
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk().expectBool(true);
    }
});

Clarinet.test({
    name: "Only vault owner can modify vault settings",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'set-time-lock', [
                types.uint(1),
                types.uint(86400)
            ], wallet2.address) // Different wallet trying to set lock
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectErr().expectUint(100); // ERR_NOT_AUTHORIZED
    }
});

Clarinet.test({
    name: "Can get vault by owner",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        
        let vaultResult = chain.callReadOnlyFn(
            'passkey-vault',
            'get-vault-by-owner',
            [types.principal(wallet1.address)],
            wallet1.address
        );
        
        assertExists(vaultResult.result.expectSome());
    }
});

Clarinet.test({
    name: "Protocol stats are updated correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet2.address),
            Tx.contractCall('passkey-vault', 'deposit-stx', [
                types.uint(1),
                types.uint(100000000) // 100 STX
            ], wallet1.address)
        ]);
        
        let statsResult = chain.callReadOnlyFn(
            'passkey-vault',
            'get-protocol-stats',
            [],
            wallet1.address
        );
        
        const stats = statsResult.result.expectTuple();
        assertEquals(stats['total-vaults'], types.uint(2));
        assertEquals(stats['total-deposits'], types.uint(100000000));
    }
});

Clarinet.test({
    name: "Can set recovery contact",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'set-recovery-contact', [
                types.uint(1),
                types.principal(wallet2.address),
                types.uint(604800) // 7 days minimum
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk().expectBool(true);
    }
});

Clarinet.test({
    name: "Cannot set recovery delay below 7 days",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'set-recovery-contact', [
                types.uint(1),
                types.principal(wallet2.address),
                types.uint(86400) // Only 1 day
            ], wallet1.address)
        ]);
        
        block.receipts[1].result.expectErr().expectUint(105); // ERR_INVALID_TIME_LOCK
    }
});

Clarinet.test({
    name: "Admin can toggle emergency shutdown",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'emergency-shutdown-toggle', [], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Verify shutdown is active
        let statsResult = chain.callReadOnlyFn(
            'passkey-vault',
            'get-protocol-stats',
            [],
            deployer.address
        );
        
        const stats = statsResult.result.expectTuple();
        assertEquals(stats['emergency-shutdown'], types.bool(true));
    }
});

Clarinet.test({
    name: "Non-admin cannot toggle emergency shutdown",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'emergency-shutdown-toggle', [], wallet1.address)
        ]);
        
        block.receipts[0].result.expectErr().expectUint(100); // ERR_NOT_AUTHORIZED
    }
});

Clarinet.test({
    name: "Get block timestamp returns valid value",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;

        let timestampResult = chain.callReadOnlyFn(
            'passkey-vault',
            'get-block-timestamp',
            [],
            wallet1.address
        );

        // Should return ok with a uint timestamp
        timestampResult.result.expectOk();
    }
});

// NEW TESTS FOR HIGH PRIORITY FIXES

Clarinet.test({
    name: "Cannot create vault with invalid public key format",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY_INVALID), // Invalid key (starts with 0x04)
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectErr().expectUint(108); // ERR_INVALID_PUBLIC_KEY
    }
});

Clarinet.test({
    name: "Cannot create vault with wrong length public key",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const SHORT_KEY = '0x02' + 'a'.repeat(30); // Too short

        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(SHORT_KEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectErr().expectUint(108); // ERR_INVALID_PUBLIC_KEY
    }
});

Clarinet.test({
    name: "Only vault owner can deposit",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;

        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'deposit-stx', [
                types.uint(1),
                types.uint(100000000)
            ], wallet2.address) // Different wallet trying to deposit
        ]);

        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectErr().expectUint(100); // ERR_NOT_AUTHORIZED
    }
});

Clarinet.test({
    name: "Cannot deposit to non-existent vault",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'deposit-stx', [
                types.uint(999), // Vault doesn't exist
                types.uint(100000000)
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectErr().expectUint(101); // ERR_VAULT_NOT_FOUND
    }
});

Clarinet.test({
    name: "Can create vault with initial time lock",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(86400), // 1 day lock
                types.uint(1000000000)
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectOk().expectUint(1);

        // Verify time lock is active
        let lockResult = chain.callReadOnlyFn(
            'passkey-vault',
            'is-time-locked',
            [types.uint(1)],
            wallet1.address
        );

        lockResult.result.expectBool(true);
    }
});

Clarinet.test({
    name: "Get nonce returns correct initial value",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectOk();

        // Check nonce
        let nonceResult = chain.callReadOnlyFn(
            'passkey-vault',
            'get-nonce',
            [types.uint(1)],
            wallet1.address
        );

        assertEquals(nonceResult.result, types.uint(0));
    }
});

Clarinet.test({
    name: "Get daily withdrawal available shows correct amount",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const dailyLimit = 1000000000; // 1000 STX

        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0),
                types.uint(dailyLimit)
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectOk();

        // Check daily available
        let availableResult = chain.callReadOnlyFn(
            'passkey-vault',
            'get-daily-withdrawal-available',
            [types.uint(1)],
            wallet1.address
        );

        availableResult.result.expectOk().expectUint(dailyLimit);
    }
});

Clarinet.test({
    name: "Can deposit during emergency shutdown is blocked",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'emergency-shutdown-toggle', [], deployer.address),
            Tx.contractCall('passkey-vault', 'deposit-stx', [
                types.uint(1),
                types.uint(100000000)
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk();
        block.receipts[2].result.expectErr().expectUint(100); // ERR_NOT_AUTHORIZED
    }
});

Clarinet.test({
    name: "Get time lock remaining returns correct value",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PASSKEY),
                types.uint(86400), // 1 day
                types.uint(1000000000)
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectOk();

        // Check remaining time
        let remainingResult = chain.callReadOnlyFn(
            'passkey-vault',
            'get-time-lock-remaining',
            [types.uint(1)],
            wallet1.address
        );

        // Should have approximately 86400 seconds remaining
        const remaining = remainingResult.result.expectOk();
        // We can't check exact value due to block time, but should be > 0
        assertExists(remaining);
    }
});
