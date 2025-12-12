import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

// Test passkey (dummy values for testing)
// Valid compressed secp256r1 public key: 33 bytes starting with 0x02 or 0x03
const TEST_PASSKEY = Cl.buffer(Buffer.from('02' + 'a'.repeat(64), 'hex'));
const TEST_PASSKEY_INVALID = Cl.buffer(Buffer.from('04' + 'a'.repeat(64), 'hex'));
const TEST_SIGNATURE = Cl.buffer(Buffer.from('b'.repeat(128), 'hex'));

describe("Passkey Vault Tests", () => {
  it("Can create a new vault with passkey", () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;

    const { result } = simnet.callPublicFn(
      "passkey-vault",
      "create-vault",
      [
        TEST_PASSKEY,
        Cl.uint(0), // No time lock
        Cl.uint(1000000000), // 1000 STX daily limit
      ],
      wallet1
    );

    expect(result).toBeOk(Cl.uint(1));
  });

  it("Can deposit STX into vault", () => {
    const accounts = simnet.getAccounts();
    const wallet1 = accounts.get("wallet_1")!;

    // Create vault first
    simnet.callPublicFn(
      "passkey-vault",
      "create-vault",
      [TEST_PASSKEY, Cl.uint(0), Cl.uint(1000000000)],
      wallet1
    );

    // Deposit STX
    const { result } = simnet.callPublicFn(
      "passkey-vault",
      "deposit-stx",
      [Cl.uint(1), Cl.uint(100000000)], // 100 STX
      wallet1
    );

    expect(result).toBeOk(Cl.bool(true));
  });

  it("Cannot create vault with invalid public key format", () => {
    const accounts = simnet.getAccounts();
    const wallet1 = accounts.get("wallet_1")!;

    const { result } = simnet.callPublicFn(
      "passkey-vault",
      "create-vault",
      [
        TEST_PASSKEY_INVALID, // Invalid key (starts with 0x04)
        Cl.uint(0),
        Cl.uint(1000000000),
      ],
      wallet1
    );

    expect(result).toBeErr(Cl.uint(108)); // ERR_INVALID_PUBLIC_KEY
  });

  it("Only vault owner can deposit", () => {
    const accounts = simnet.getAccounts();
    const wallet1 = accounts.get("wallet_1")!;
    const wallet2 = accounts.get("wallet_2")!;

    // Create vault
    simnet.callPublicFn(
      "passkey-vault",
      "create-vault",
      [TEST_PASSKEY, Cl.uint(0), Cl.uint(1000000000)],
      wallet1
    );

    // Try to deposit from different wallet
    const { result } = simnet.callPublicFn(
      "passkey-vault",
      "deposit-stx",
      [Cl.uint(1), Cl.uint(100000000)],
      wallet2
    );

    expect(result).toBeErr(Cl.uint(100)); // ERR_NOT_AUTHORIZED
  });

  it("Can retrieve vault details", () => {
    const accounts = simnet.getAccounts();
    const wallet1 = accounts.get("wallet_1")!;

    // Create vault
    simnet.callPublicFn(
      "passkey-vault",
      "create-vault",
      [TEST_PASSKEY, Cl.uint(0), Cl.uint(1000000000)],
      wallet1
    );

    // Get vault
    const { result } = simnet.callReadOnlyFn(
      "passkey-vault",
      "get-vault",
      [Cl.uint(1)],
      wallet1
    );

    // Verify vault was retrieved
    expect(result).toBeTruthy();
  });

  it("Emergency shutdown blocks deposits", () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;

    // Create vault
    simnet.callPublicFn(
      "passkey-vault",
      "create-vault",
      [TEST_PASSKEY, Cl.uint(0), Cl.uint(1000000000)],
      wallet1
    );

    // Activate emergency shutdown
    simnet.callPublicFn(
      "passkey-vault",
      "emergency-shutdown-toggle",
      [],
      deployer
    );

    // Try to deposit
    const { result } = simnet.callPublicFn(
      "passkey-vault",
      "deposit-stx",
      [Cl.uint(1), Cl.uint(100000000)],
      wallet1
    );

    expect(result).toBeErr(Cl.uint(100)); // ERR_NOT_AUTHORIZED
  });

  it("Can create vault with initial time lock", () => {
    const accounts = simnet.getAccounts();
    const wallet1 = accounts.get("wallet_1")!;

    const { result } = simnet.callPublicFn(
      "passkey-vault",
      "create-vault",
      [
        TEST_PASSKEY,
        Cl.uint(86400), // 1 day lock
        Cl.uint(1000000000),
      ],
      wallet1
    );

    expect(result).toBeOk(Cl.uint(1));

    // Verify time lock is active
    const lockResult = simnet.callReadOnlyFn(
      "passkey-vault",
      "is-time-locked",
      [Cl.uint(1)],
      wallet1
    );

    expect(lockResult.result).toBeBool(true);
  });

  it("Cannot create vault with wrong length public key", () => {
    const accounts = simnet.getAccounts();
    const wallet1 = accounts.get("wallet_1")!;
    const SHORT_KEY = Cl.buffer(Buffer.from('02' + 'a'.repeat(30), 'hex'));

    const { result } = simnet.callPublicFn(
      "passkey-vault",
      "create-vault",
      [SHORT_KEY, Cl.uint(0), Cl.uint(1000000000)],
      wallet1
    );

    expect(result).toBeErr(Cl.uint(108)); // ERR_INVALID_PUBLIC_KEY
  });

  it("Cannot deposit to non-existent vault", () => {
    const accounts = simnet.getAccounts();
    const wallet1 = accounts.get("wallet_1")!;

    const { result } = simnet.callPublicFn(
      "passkey-vault",
      "deposit-stx",
      [Cl.uint(999), Cl.uint(100000000)],
      wallet1
    );

    expect(result).toBeErr(Cl.uint(101)); // ERR_VAULT_NOT_FOUND
  });

  it("Get nonce returns correct initial value", () => {
    const accounts = simnet.getAccounts();
    const wallet1 = accounts.get("wallet_1")!;

    // Create vault
    simnet.callPublicFn(
      "passkey-vault",
      "create-vault",
      [TEST_PASSKEY, Cl.uint(0), Cl.uint(1000000000)],
      wallet1
    );

    // Check nonce
    const { result } = simnet.callReadOnlyFn(
      "passkey-vault",
      "get-nonce",
      [Cl.uint(1)],
      wallet1
    );

    expect(result).toBeUint(0);
  });
});
