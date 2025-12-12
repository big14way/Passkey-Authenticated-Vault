/**
 * Generate real secp256r1 (P-256) keys and signatures for testing
 * This script creates test fixtures with valid cryptographic signatures
 */

const crypto = require('crypto');

// Generate a new secp256r1 key pair
function generateKeyPair() {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ec', {
    namedCurve: 'P-256', // secp256r1 is also known as P-256
    publicKeyEncoding: {
      type: 'spki',
      format: 'der'
    },
    privateKeyEncoding: {
      type: 'pkcs8',
      format: 'der'
    }
  });

  return { publicKey, privateKey };
}

// Extract compressed public key (33 bytes) from DER format
function getCompressedPublicKey(publicKeyDER) {
  // DER encoded public key has the uncompressed key at the end (65 bytes: 0x04 + 32 bytes X + 32 bytes Y)
  // We need to compress it to 33 bytes (0x02/0x03 + 32 bytes X)

  // The uncompressed key starts after the DER headers (last 65 bytes)
  const uncompressed = publicKeyDER.slice(-65);

  if (uncompressed[0] !== 0x04) {
    throw new Error('Expected uncompressed public key format');
  }

  // Extract X and Y coordinates
  const x = uncompressed.slice(1, 33);
  const y = uncompressed.slice(33, 65);

  // Determine prefix based on Y coordinate (even = 0x02, odd = 0x03)
  const prefix = (y[y.length - 1] & 1) === 0 ? 0x02 : 0x03;

  // Create compressed key
  const compressed = Buffer.concat([Buffer.from([prefix]), x]);

  return compressed;
}

// Sign a message with the private key
function signMessage(message, privateKeyDER) {
  const sign = crypto.createSign('SHA256');
  sign.update(message);
  sign.end();

  // Sign and get signature in DER format
  const signatureDER = sign.sign({
    key: privateKeyDER,
    format: 'der',
    type: 'pkcs8'
  });

  // Convert DER signature to raw 64-byte format (r + s)
  // DER format: 0x30 [total-length] 0x02 [r-length] [r] 0x02 [s-length] [s]
  const rawSignature = derToRaw(signatureDER);

  return rawSignature;
}

// Convert DER encoded signature to raw 64-byte format
function derToRaw(derSignature) {
  let offset = 0;

  // Skip sequence tag and length
  if (derSignature[offset++] !== 0x30) {
    throw new Error('Invalid DER signature');
  }
  offset++; // Skip total length

  // Extract r
  if (derSignature[offset++] !== 0x02) {
    throw new Error('Invalid DER signature - expected INTEGER for r');
  }
  let rLength = derSignature[offset++];
  let r = derSignature.slice(offset, offset + rLength);
  offset += rLength;

  // Remove leading zero if present (DER padding)
  if (r[0] === 0x00) {
    r = r.slice(1);
  }

  // Pad r to 32 bytes if needed
  if (r.length < 32) {
    r = Buffer.concat([Buffer.alloc(32 - r.length, 0), r]);
  }

  // Extract s
  if (derSignature[offset++] !== 0x02) {
    throw new Error('Invalid DER signature - expected INTEGER for s');
  }
  let sLength = derSignature[offset++];
  let s = derSignature.slice(offset, offset + sLength);

  // Remove leading zero if present (DER padding)
  if (s[0] === 0x00) {
    s = s.slice(1);
  }

  // Pad s to 32 bytes if needed
  if (s.length < 32) {
    s = Buffer.concat([Buffer.alloc(32 - s.length, 0), s]);
  }

  // Combine r and s
  return Buffer.concat([r, s]);
}

// Generate test fixtures
function generateTestFixtures() {
  console.log('Generating secp256r1 test fixtures...\n');

  // Generate key pair
  const { publicKey, privateKey } = generateKeyPair();
  const compressedPublicKey = getCompressedPublicKey(publicKey);

  console.log('Public Key (Compressed, 33 bytes):');
  console.log('0x' + compressedPublicKey.toString('hex'));
  console.log('');

  // Test message 1: Withdrawal (vault-id=1, amount=100000000, nonce=0)
  const vaultId1 = Buffer.from([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]);
  const amount1 = Buffer.from([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x05, 0xf5, 0xe1, 0x00]);
  const nonce1 = Buffer.from([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);

  const message1 = Buffer.concat([vaultId1, amount1, nonce1]);
  const messageHash1 = crypto.createHash('sha256').update(message1).digest();
  const signature1 = signMessage(messageHash1, privateKey);

  console.log('Test Case 1: Withdrawal');
  console.log('Message Hash: 0x' + messageHash1.toString('hex'));
  console.log('Signature (64 bytes): 0x' + signature1.toString('hex'));
  console.log('');

  // Test message 2: Different withdrawal (vault-id=1, amount=200000000, nonce=1)
  const amount2 = Buffer.from([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0b, 0xeb, 0xc2, 0x00]);
  const nonce2 = Buffer.from([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]);

  const message2 = Buffer.concat([vaultId1, amount2, nonce2]);
  const messageHash2 = crypto.createHash('sha256').update(message2).digest();
  const signature2 = signMessage(messageHash2, privateKey);

  console.log('Test Case 2: Withdrawal with different amount and nonce');
  console.log('Message Hash: 0x' + messageHash2.toString('hex'));
  console.log('Signature (64 bytes): 0x' + signature2.toString('hex'));
  console.log('');

  // Generate a second key pair for testing key updates
  const { publicKey: publicKey2 } = generateKeyPair();
  const compressedPublicKey2 = getCompressedPublicKey(publicKey2);

  console.log('Second Public Key (for update tests):');
  console.log('0x' + compressedPublicKey2.toString('hex'));
  console.log('');

  // Test message 3: Update passkey (vault-id=1, new-key, nonce=0)
  const message3 = Buffer.concat([vaultId1, compressedPublicKey2, nonce1]);
  const messageHash3 = crypto.createHash('sha256').update(message3).digest();
  const signature3 = signMessage(messageHash3, privateKey);

  console.log('Test Case 3: Update passkey');
  console.log('Message Hash: 0x' + messageHash3.toString('hex'));
  console.log('Signature (64 bytes): 0x' + signature3.toString('hex'));
  console.log('');

  // Output as TypeScript constants
  console.log('=== TypeScript Test Constants ===\n');
  console.log(`const TEST_PRIVATE_KEY_HEX = '${compressedPublicKey.toString('hex')}';`);
  console.log(`const TEST_PUBLIC_KEY = '0x${compressedPublicKey.toString('hex')}';`);
  console.log(`const TEST_PUBLIC_KEY_2 = '0x${compressedPublicKey2.toString('hex')}';`);
  console.log('');
  console.log('// Withdrawal: vault-id=1, amount=100000000 (100 STX), nonce=0');
  console.log(`const TEST_MESSAGE_HASH_1 = '0x${messageHash1.toString('hex')}';`);
  console.log(`const TEST_SIGNATURE_1 = '0x${signature1.toString('hex')}';`);
  console.log('');
  console.log('// Withdrawal: vault-id=1, amount=200000000 (200 STX), nonce=1');
  console.log(`const TEST_MESSAGE_HASH_2 = '0x${messageHash2.toString('hex')}';`);
  console.log(`const TEST_SIGNATURE_2 = '0x${signature2.toString('hex')}';`);
  console.log('');
  console.log('// Update passkey: vault-id=1, new-key=TEST_PUBLIC_KEY_2, nonce=0');
  console.log(`const TEST_MESSAGE_HASH_3 = '0x${messageHash3.toString('hex')}';`);
  console.log(`const TEST_SIGNATURE_3 = '0x${signature3.toString('hex')}';`);
}

// Run the generator
try {
  generateTestFixtures();
} catch (error) {
  console.error('Error generating test fixtures:', error);
  process.exit(1);
}
