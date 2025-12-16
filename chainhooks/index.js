import { ChainhookEventObserver } from '@hirosystems/chainhook-client';
import { randomUUID } from 'crypto';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';

dotenv.config();

// Analytics storage (in production, use a database)
const analytics = {
  users: new Set(),
  totalVaults: 0,
  totalDeposits: 0,
  totalWithdrawals: 0,
  totalValueLocked: 0,
  totalValueWithdrawn: 0,
  activeTimeLocks: 0,
  emergencyRecoveries: 0,
  passkeyUpdates: 0,
  vaultCreations: [],
  deposits: [],
  withdrawals: [],
  securityEvents: []
};

// Save analytics to JSON file
function saveAnalytics() {
  const data = {
    ...analytics,
    users: Array.from(analytics.users),
    timestamp: new Date().toISOString(),
    uniqueUsers: analytics.users.size,
    avgVaultBalance: analytics.totalVaults > 0 ? analytics.totalValueLocked / analytics.totalVaults : 0
  };

  fs.writeFileSync(
    path.join(process.cwd(), 'analytics-data.json'),
    JSON.stringify(data, null, 2)
  );

  console.log(`📊 Analytics saved - Users: ${data.uniqueUsers}, Vaults: ${data.totalVaults}, TVL: ${(data.totalValueLocked / 1000000).toFixed(2)} STX`);
}

// Create predicates for vault events
function createVaultPredicates() {
  const contractId = process.env.VAULT_CONTRACT;
  const startBlock = parseInt(process.env.START_BLOCK) || 0;
  const network = process.env.NETWORK || 'testnet';

  return [
    {
      uuid: randomUUID(),
      name: 'vault-created-events',
      version: 1,
      chain: 'stacks',
      networks: {
        [network]: {
          if_this: {
            scope: 'contract_call',
            contract_identifier: contractId,
            method: 'create-vault'
          },
          then_that: {
            http_post: {
              url: `${process.env.EXTERNAL_BASE_URL}/chainhook/vault-created`,
              authorization_header: `Bearer ${process.env.SERVER_AUTH_TOKEN}`
            }
          },
          start_block: startBlock
        }
      }
    },
    {
      uuid: randomUUID(),
      name: 'deposit-events',
      version: 1,
      chain: 'stacks',
      networks: {
        [network]: {
          if_this: {
            scope: 'contract_call',
            contract_identifier: contractId,
            method: 'deposit-stx'
          },
          then_that: {
            http_post: {
              url: `${process.env.EXTERNAL_BASE_URL}/chainhook/deposit`,
              authorization_header: `Bearer ${process.env.SERVER_AUTH_TOKEN}`
            }
          },
          start_block: startBlock
        }
      }
    },
    {
      uuid: randomUUID(),
      name: 'withdrawal-events',
      version: 1,
      chain: 'stacks',
      networks: {
        [network]: {
          if_this: {
            scope: 'contract_call',
            contract_identifier: contractId,
            method: 'withdraw-with-passkey'
          },
          then_that: {
            http_post: {
              url: `${process.env.EXTERNAL_BASE_URL}/chainhook/withdrawal`,
              authorization_header: `Bearer ${process.env.SERVER_AUTH_TOKEN}`
            }
          },
          start_block: startBlock
        }
      }
    },
    {
      uuid: randomUUID(),
      name: 'timelock-events',
      version: 1,
      chain: 'stacks',
      networks: {
        [network]: {
          if_this: {
            scope: 'contract_call',
            contract_identifier: contractId,
            method: 'set-time-lock'
          },
          then_that: {
            http_post: {
              url: `${process.env.EXTERNAL_BASE_URL}/chainhook/timelock`,
              authorization_header: `Bearer ${process.env.SERVER_AUTH_TOKEN}`
            }
          },
          start_block: startBlock
        }
      }
    },
    {
      uuid: randomUUID(),
      name: 'passkey-update-events',
      version: 1,
      chain: 'stacks',
      networks: {
        [network]: {
          if_this: {
            scope: 'contract_call',
            contract_identifier: contractId,
            method: 'update-passkey'
          },
          then_that: {
            http_post: {
              url: `${process.env.EXTERNAL_BASE_URL}/chainhook/passkey-update`,
              authorization_header: `Bearer ${process.env.SERVER_AUTH_TOKEN}`
            }
          },
          start_block: startBlock
        }
      }
    },
    {
      uuid: randomUUID(),
      name: 'recovery-contact-events',
      version: 1,
      chain: 'stacks',
      networks: {
        [network]: {
          if_this: {
            scope: 'contract_call',
            contract_identifier: contractId,
            method: 'set-recovery-contact'
          },
          then_that: {
            http_post: {
              url: `${process.env.EXTERNAL_BASE_URL}/chainhook/recovery-contact`,
              authorization_header: `Bearer ${process.env.SERVER_AUTH_TOKEN}`
            }
          },
          start_block: startBlock
        }
      }
    },
    {
      uuid: randomUUID(),
      name: 'emergency-recovery-events',
      version: 1,
      chain: 'stacks',
      networks: {
        [network]: {
          if_this: {
            scope: 'contract_call',
            contract_identifier: contractId,
            method: 'emergency-recovery'
          },
          then_that: {
            http_post: {
              url: `${process.env.EXTERNAL_BASE_URL}/chainhook/emergency-recovery`,
              authorization_header: `Bearer ${process.env.SERVER_AUTH_TOKEN}`
            }
          },
          start_block: startBlock
        }
      }
    },
    {
      uuid: randomUUID(),
      name: 'withdrawal-limit-events',
      version: 1,
      chain: 'stacks',
      networks: {
        [network]: {
          if_this: {
            scope: 'contract_call',
            contract_identifier: contractId,
            method: 'update-withdrawal-limit'
          },
          then_that: {
            http_post: {
              url: `${process.env.EXTERNAL_BASE_URL}/chainhook/withdrawal-limit`,
              authorization_header: `Bearer ${process.env.SERVER_AUTH_TOKEN}`
            }
          },
          start_block: startBlock
        }
      }
    },
    {
      uuid: randomUUID(),
      name: 'vault-print-events',
      version: 1,
      chain: 'stacks',
      networks: {
        [network]: {
          if_this: {
            scope: 'print_event',
            contract_identifier: contractId,
            contains: 'event'
          },
          then_that: {
            http_post: {
              url: `${process.env.EXTERNAL_BASE_URL}/chainhook/print-event`,
              authorization_header: `Bearer ${process.env.SERVER_AUTH_TOKEN}`
            }
          },
          start_block: startBlock
        }
      }
    }
  ];
}

// Parse print event data
function parsePrintEvent(eventValue) {
  try {
    if (typeof eventValue === 'string') {
      return JSON.parse(eventValue);
    }
    return eventValue;
  } catch (error) {
    console.error('Error parsing print event:', error);
    return null;
  }
}

// Event handler
async function handleChainhookEvent(uuid, payload) {
  console.log(`\n🔔 Event received: ${uuid}`);

  try {
    // Process transactions in the payload
    if (payload.apply && payload.apply.length > 0) {
      for (const block of payload.apply) {
        console.log(`📦 Block ${block.block_identifier.index}`);

        for (const tx of block.transactions) {
          const sender = tx.metadata.sender;
          analytics.users.add(sender);

          // Process contract calls
          if (tx.metadata.kind?.data?.contract_call) {
            const contractCall = tx.metadata.kind.data.contract_call;
            const method = contractCall.function_name;

            console.log(`  → ${sender} called ${method}`);

            switch (method) {
              case 'create-vault':
                analytics.totalVaults++;
                analytics.vaultCreations.push({
                  owner: sender,
                  timestamp: new Date().toISOString(),
                  txid: tx.transaction_identifier.hash
                });
                console.log(`  🏦 Vault created`);
                break;

              case 'deposit-stx':
                analytics.totalDeposits++;
                analytics.deposits.push({
                  depositor: sender,
                  timestamp: new Date().toISOString(),
                  txid: tx.transaction_identifier.hash
                });
                console.log(`  💰 Deposit made`);
                break;

              case 'withdraw-with-passkey':
                analytics.totalWithdrawals++;
                analytics.withdrawals.push({
                  withdrawer: sender,
                  timestamp: new Date().toISOString(),
                  txid: tx.transaction_identifier.hash
                });
                console.log(`  💸 Withdrawal via passkey`);
                break;

              case 'set-time-lock':
                analytics.activeTimeLocks++;
                console.log(`  🔒 Time-lock set`);
                break;

              case 'update-passkey':
                analytics.passkeyUpdates++;
                analytics.securityEvents.push({
                  type: 'passkey-update',
                  user: sender,
                  timestamp: new Date().toISOString(),
                  txid: tx.transaction_identifier.hash
                });
                console.log(`  🔑 Passkey updated`);
                break;

              case 'set-recovery-contact':
                analytics.securityEvents.push({
                  type: 'recovery-contact-set',
                  user: sender,
                  timestamp: new Date().toISOString(),
                  txid: tx.transaction_identifier.hash
                });
                console.log(`  🆘 Recovery contact set`);
                break;

              case 'emergency-recovery':
                analytics.emergencyRecoveries++;
                analytics.securityEvents.push({
                  type: 'emergency-recovery',
                  recoverer: sender,
                  timestamp: new Date().toISOString(),
                  txid: tx.transaction_identifier.hash
                });
                console.log(`  🚨 Emergency recovery executed`);
                break;

              case 'update-withdrawal-limit':
                console.log(`  📊 Withdrawal limit updated`);
                break;
            }
          }

          // Process print events for detailed tracking
          if (tx.metadata.receipt?.events) {
            for (const event of tx.metadata.receipt.events) {
              if (event.type === 'SmartContractEvent') {
                const eventData = parsePrintEvent(event.data.value);

                if (eventData) {
                  // Track specific events from print statements
                  if (eventData.event === 'vault-created') {
                    const vaultId = eventData['vault-id'] || 0;
                    const timeLock = eventData['time-lock'] || 0;

                    console.log(`  ℹ️  Vault #${vaultId} created with ${timeLock / 3600}h time-lock`);
                  } else if (eventData.event === 'deposit') {
                    const vaultId = eventData['vault-id'] || 0;
                    const amount = eventData.amount || 0;
                    const newBalance = eventData['new-balance'] || 0;

                    analytics.totalValueLocked += amount;

                    console.log(`  ℹ️  Deposit: ${amount / 1000000} STX to Vault #${vaultId} (Balance: ${newBalance / 1000000} STX)`);
                  } else if (eventData.event === 'withdrawal') {
                    const vaultId = eventData['vault-id'] || 0;
                    const amount = eventData.amount || 0;
                    const remaining = eventData['remaining-balance'] || 0;

                    analytics.totalValueLocked -= amount;
                    analytics.totalValueWithdrawn += amount;

                    console.log(`  ℹ️  Withdrawal: ${amount / 1000000} STX from Vault #${vaultId} (Remaining: ${remaining / 1000000} STX)`);
                  } else if (eventData.event === 'time-lock-set') {
                    const vaultId = eventData['vault-id'] || 0;
                    const duration = eventData.duration || 0;

                    console.log(`  ℹ️  Time-lock set for Vault #${vaultId}: ${duration / 3600}h`);
                  } else if (eventData.event === 'passkey-updated') {
                    const vaultId = eventData['vault-id'] || 0;

                    console.log(`  ℹ️  Passkey updated for Vault #${vaultId}`);
                  } else if (eventData.event === 'emergency-recovery') {
                    const vaultId = eventData['vault-id'] || 0;
                    const amount = eventData.amount || 0;

                    console.log(`  ℹ️  Emergency recovery: ${amount / 1000000} STX from Vault #${vaultId}`);
                  } else if (eventData.event === 'withdrawal-limit-updated') {
                    const vaultId = eventData['vault-id'] || 0;
                    const newLimit = eventData['new-limit'] || 0;

                    console.log(`  ℹ️  Withdrawal limit updated for Vault #${vaultId}: ${newLimit / 1000000} STX/day`);
                  }
                }
              }
            }
          }
        }
      }

      // Save analytics after processing
      saveAnalytics();
    }

  } catch (error) {
    console.error('Error processing event:', error);
  }
}

// Start the observer
async function start() {
  console.log('🚀 Starting Passkey Vault Chainhook Observer\n');

  const serverOptions = {
    hostname: process.env.SERVER_HOST,
    port: parseInt(process.env.SERVER_PORT),
    auth_token: process.env.SERVER_AUTH_TOKEN,
    external_base_url: process.env.EXTERNAL_BASE_URL
  };

  const chainhookOptions = {
    base_url: process.env.CHAINHOOK_NODE_URL
  };

  const predicates = createVaultPredicates();

  console.log(`📡 Server: ${serverOptions.external_base_url}`);
  console.log(`🔗 Chainhook Node: ${chainhookOptions.base_url}`);
  console.log(`📋 Monitoring ${predicates.length} event types\n`);
  console.log(`📝 Contract: ${process.env.VAULT_CONTRACT}\n`);

  const observer = new ChainhookEventObserver(serverOptions, chainhookOptions);

  try {
    await observer.start(predicates, handleChainhookEvent);
    console.log('✅ Observer started successfully!\n');
    console.log('Tracking:');
    console.log('  - Vault creation and management');
    console.log('  - STX deposits and withdrawals');
    console.log('  - Passkey authentication (secp256r1)');
    console.log('  - Time-locks and security features');
    console.log('  - Emergency recovery operations');
    console.log('  - Daily withdrawal limits\n');
    console.log('Waiting for events...\n');
  } catch (error) {
    console.error('❌ Failed to start observer:', error.message);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n\n👋 Shutting down gracefully...');
  saveAnalytics();
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n\n👋 Shutting down gracefully...');
  saveAnalytics();
  process.exit(0);
});

// Start the observer
start().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
