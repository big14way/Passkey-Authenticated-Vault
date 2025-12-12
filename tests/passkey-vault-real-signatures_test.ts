import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

/**
 * Tests with REAL secp256r1 signatures
 * Generated using Node.js crypto (P-256 curve)
 *
 * Run `node scripts/generate-test-keys.js` to generate new test keys
 */

// Real secp256r1 test keys and signatures
const TEST_PUBLIC_KEY = '0x02cabb4945ee7b00ff7da6cf4f105e0c984a509cd9dbea87e69b56c49fd733d4cd';
const TEST_PUBLIC_KEY_2 = '0x030c2a1331c6d328377efd3477c5b78099787e1c2e227ce6af126898057fd9af7c';

// Withdrawal: vault-id=1, amount=100000000 (100 STX), nonce=0
const TEST_SIGNATURE_1 = '0xef68d926e00856f83e0825835b1a71520a8a542402f13c0fc00ba43f98881a332550b79db4fe38d5735fcc1b10d7d7b56d4eeb03e3be59dc3cbb03a5c72d3199';

// Withdrawal: vault-id=1, amount=200000000 (200 STX), nonce=1
const TEST_SIGNATURE_2 = '0x65ee5777bc7786ba4f5844b52a95100e188f08956b212c85ea21a91260edfc74642e18ecf4a7f7ce19a54b494ddf56a43863f9355e60ebae9d97fbfd044b8c34';

// Update passkey: vault-id=1, new-key=TEST_PUBLIC_KEY_2, nonce=0
const TEST_SIGNATURE_3 = '0xb9862cd37b6e2ca022da1f3d810f0c50891e3774899154ffb9e560dbdff43404e4631a40fba8d42660ea5a10a3cf4047b744ac6c83cfdd1c0ce763300cfb59a3';

Clarinet.test({
    name: "Can withdraw with valid passkey signature",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            // Create vault with real public key
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PUBLIC_KEY),
                types.uint(0), // No time lock
                types.uint(1000000000) // 1000 STX daily limit
            ], wallet1.address),
            // Deposit funds
            Tx.contractCall('passkey-vault', 'deposit-stx', [
                types.uint(1),
                types.uint(500000000) // 500 STX
            ], wallet1.address),
            // Withdraw with real signature
            Tx.contractCall('passkey-vault', 'withdraw-with-passkey', [
                types.uint(1),
                types.uint(100000000), // 100 STX (matches signature)
                types.buff(TEST_SIGNATURE_1) // Real secp256r1 signature
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectOk().expectUint(1);
        block.receipts[1].result.expectOk().expectBool(true);
        block.receipts[2].result.expectOk().expectBool(true);

        // Verify balance updated
        let vaultResult = chain.callReadOnlyFn(
            'passkey-vault',
            'get-vault',
            [types.uint(1)],
            wallet1.address
        );

        const vault = vaultResult.result.expectSome().expectTuple();
        assertEquals(vault['stx-balance'], types.uint(400000000)); // 500 - 100 = 400
    }
});

Clarinet.test({
    name: "Cannot withdraw with invalid signature",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const WRONG_SIGNATURE = '0x' + '0'.repeat(128); // Invalid signature

        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PUBLIC_KEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'deposit-stx', [
                types.uint(1),
                types.uint(500000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'withdraw-with-passkey', [
                types.uint(1),
                types.uint(100000000),
                types.buff(WRONG_SIGNATURE) // Wrong signature
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk();
        block.receipts[2].result.expectErr().expectUint(103); // ERR_INVALID_SIGNATURE
    }
});

Clarinet.test({
    name: "Cannot reuse signature (replay protection)",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;

        let block1 = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PUBLIC_KEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'deposit-stx', [
                types.uint(1),
                types.uint(500000000)
            ], wallet1.address),
            // First withdrawal - should succeed
            Tx.contractCall('passkey-vault', 'withdraw-with-passkey', [
                types.uint(1),
                types.uint(100000000),
                types.buff(TEST_SIGNATURE_1) // nonce=0
            ], wallet1.address)
        ]);

        block1.receipts[2].result.expectOk();

        // Try to reuse the same signature
        let block2 = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'withdraw-with-passkey', [
                types.uint(1),
                types.uint(100000000),
                types.buff(TEST_SIGNATURE_1) // Same signature (nonce=0)
            ], wallet1.address)
        ]);

        // Should fail because nonce has incremented to 1
        block2.receipts[0].result.expectErr().expectUint(103); // ERR_INVALID_SIGNATURE
    }
});

Clarinet.test({
    name: "Can withdraw with new nonce after first withdrawal",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;

        let block1 = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PUBLIC_KEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'deposit-stx', [
                types.uint(1),
                types.uint(500000000)
            ], wallet1.address),
            // First withdrawal with nonce=0
            Tx.contractCall('passkey-vault', 'withdraw-with-passkey', [
                types.uint(1),
                types.uint(100000000),
                types.buff(TEST_SIGNATURE_1)
            ], wallet1.address)
        ]);

        block1.receipts[2].result.expectOk();

        // Verify nonce incremented
        let nonceResult = chain.callReadOnlyFn(
            'passkey-vault',
            'get-nonce',
            [types.uint(1)],
            wallet1.address
        );
        assertEquals(nonceResult.result, types.uint(1));

        // Second withdrawal with nonce=1
        let block2 = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'withdraw-with-passkey', [
                types.uint(1),
                types.uint(200000000), // Different amount
                types.buff(TEST_SIGNATURE_2) // Signature for nonce=1
            ], wallet1.address)
        ]);

        block2.receipts[0].result.expectOk().expectBool(true);

        // Verify final balance
        let vaultResult = chain.callReadOnlyFn(
            'passkey-vault',
            'get-vault',
            [types.uint(1)],
            wallet1.address
        );

        const vault = vaultResult.result.expectSome().expectTuple();
        assertEquals(vault['stx-balance'], types.uint(200000000)); // 500 - 100 - 200 = 200
    }
});

Clarinet.test({
    name: "Cannot withdraw with signature for wrong amount",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PUBLIC_KEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'deposit-stx', [
                types.uint(1),
                types.uint(500000000)
            ], wallet1.address),
            // Try to withdraw different amount than signed
            Tx.contractCall('passkey-vault', 'withdraw-with-passkey', [
                types.uint(1),
                types.uint(200000000), // Different amount (signature is for 100000000)
                types.buff(TEST_SIGNATURE_1)
            ], wallet1.address)
        ]);

        block.receipts[2].result.expectErr().expectUint(103); // ERR_INVALID_SIGNATURE
    }
});

Clarinet.test({
    name: "Can update passkey with valid signature",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PUBLIC_KEY),
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            // Update to new passkey
            Tx.contractCall('passkey-vault', 'update-passkey', [
                types.uint(1),
                types.buff(TEST_PUBLIC_KEY_2), // New key
                types.buff(TEST_SIGNATURE_3) // Signed with old key
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk().expectBool(true);

        // Verify key was updated
        let vaultResult = chain.callReadOnlyFn(
            'passkey-vault',
            'get-vault',
            [types.uint(1)],
            wallet1.address
        );

        const vault = vaultResult.result.expectSome().expectTuple();
        assertEquals(vault['passkey-public-key'], types.buff(TEST_PUBLIC_KEY_2));
    }
});

Clarinet.test({
    name: "Cannot withdraw when time-locked",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            // Create vault with time lock
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PUBLIC_KEY),
                types.uint(86400), // 1 day lock
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'deposit-stx', [
                types.uint(1),
                types.uint(500000000)
            ], wallet1.address),
            // Try to withdraw while locked
            Tx.contractCall('passkey-vault', 'withdraw-with-passkey', [
                types.uint(1),
                types.uint(100000000),
                types.buff(TEST_SIGNATURE_1)
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk();
        block.receipts[2].result.expectErr().expectUint(104); // ERR_TIME_LOCK_ACTIVE
    }
});

Clarinet.test({
    name: "Cannot withdraw more than daily limit",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PUBLIC_KEY),
                types.uint(0),
                types.uint(50000000) // Only 50 STX daily limit
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'deposit-stx', [
                types.uint(1),
                types.uint(500000000)
            ], wallet1.address),
            // Try to withdraw 100 STX (exceeds limit)
            Tx.contractCall('passkey-vault', 'withdraw-with-passkey', [
                types.uint(1),
                types.uint(100000000),
                types.buff(TEST_SIGNATURE_1)
            ], wallet1.address)
        ]);

        block.receipts[2].result.expectErr().expectUint(102); // ERR_INSUFFICIENT_BALANCE (daily limit)
    }
});

Clarinet.test({
    name: "Cannot withdraw with signature from wrong public key",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            // Create vault with different public key
            Tx.contractCall('passkey-vault', 'create-vault', [
                types.buff(TEST_PUBLIC_KEY_2), // Different key
                types.uint(0),
                types.uint(1000000000)
            ], wallet1.address),
            Tx.contractCall('passkey-vault', 'deposit-stx', [
                types.uint(1),
                types.uint(500000000)
            ], wallet1.address),
            // Try to use signature from TEST_PUBLIC_KEY
            Tx.contractCall('passkey-vault', 'withdraw-with-passkey', [
                types.uint(1),
                types.uint(100000000),
                types.buff(TEST_SIGNATURE_1) // Signed with wrong key
            ], wallet1.address)
        ]);

        block.receipts[2].result.expectErr().expectUint(103); // ERR_INVALID_SIGNATURE
    }
});
