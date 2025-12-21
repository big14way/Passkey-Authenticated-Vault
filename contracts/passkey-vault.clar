;; Passkey-Authenticated Vault
;; Uses Clarity 4 (Epoch 3.3) - Activated November 11, 2025
;; Features: secp256r1-verify for WebAuthn passkeys, stacks-block-time
;; Secure sBTC/STX savings with biometric/passkey withdrawals and time-locks

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_VAULT_NOT_FOUND (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_INVALID_SIGNATURE (err u103))
(define-constant ERR_TIME_LOCK_ACTIVE (err u104))
(define-constant ERR_INVALID_TIME_LOCK (err u105))
(define-constant ERR_VAULT_EXISTS (err u106))
(define-constant ERR_ZERO_AMOUNT (err u107))
(define-constant ERR_INVALID_PUBLIC_KEY (err u108))
(define-constant ERR_INVALID_WITHDRAWAL_LIMIT (err u109))
(define-constant ERR_RECOVERY_NOT_READY (err u110))
(define-constant ERR_NOT_RECOVERY_CONTACT (err u111))
(define-constant ERR_BATCH_LIMIT_EXCEEDED (err u112))
(define-constant ERR_VAULT_LOCKED (err u113))
(define-constant ERR_TOO_MANY_FAILED_ATTEMPTS (err u114))
(define-constant ERR_INVALID_AMOUNT (err u115))
(define-constant ERR_EMERGENCY_CONTACT_EXISTS (err u116))
(define-constant ERR_SHARED_ACCESS_EXISTS (err u117))
(define-constant ERR_SHARED_ACCESS_NOT_FOUND (err u118))
(define-constant ERR_SHARED_ACCESS_EXPIRED (err u119))
(define-constant ERR_SHARED_LIMIT_EXCEEDED (err u120))
(define-constant ERR_AUDIT_LOG_NOT_FOUND (err u121))
(define-constant ERR_INVALID_LOG_FILTER (err u122))
(define-constant ERR_INSURANCE_EXISTS (err u123))
(define-constant ERR_NO_INSURANCE (err u124))
(define-constant ERR_INSUFFICIENT_COVERAGE (err u125))
(define-constant ERR_CLAIM_ALREADY_EXISTS (err u126))
(define-constant ERR_CLAIM_NOT_FOUND (err u127))
(define-constant ERR_CLAIM_ALREADY_PROCESSED (err u128))

;; Minimum time-lock period (in seconds) - 1 hour
(define-constant MIN_TIME_LOCK u3600)
;; Maximum time-lock period (in seconds) - 365 days
(define-constant MAX_TIME_LOCK u31536000)

;; Minimum withdrawal limit (in microSTX) - 1 STX
(define-constant MIN_WITHDRAWAL_LIMIT u1000000)
;; Maximum withdrawal limit (in microSTX) - 1,000,000 STX
(define-constant MAX_WITHDRAWAL_LIMIT u1000000000000)

;; Data Variables
(define-data-var total-vaults uint u0)
(define-data-var total-deposits uint u0)
(define-data-var emergency-shutdown bool false)
(define-data-var inactivity-threshold uint u7776000)
(define-data-var max-daily-transactions uint u10)
(define-data-var total-withdrawals uint u0)
(define-data-var max-failed-attempts uint u5)
(define-data-var auto-lock-duration uint u86400)

;; Data Maps

;; Vault storage - maps vault-id to vault details
(define-map vaults
  { vault-id: uint }
  {
    owner: principal,
    passkey-public-key: (buff 33),  ;; Compressed secp256r1 public key
    stx-balance: uint,
    time-lock-until: uint,          ;; Unix timestamp
    created-at: uint,
    last-activity: uint,
    withdrawal-limit: uint,         ;; Daily withdrawal limit
    daily-withdrawn: uint,
    daily-reset-time: uint,
    auto-locked-until: uint,        ;; Auto-lock timestamp
    failed-attempts: uint           ;; Failed withdrawal attempts counter
  }
)

;; Map owner to their vault id
(define-map owner-vault
  { owner: principal }
  { vault-id: uint }
)

(define-map emergency-contacts
  { vault-id: uint }
  { contact: principal, set-at: uint, can-withdraw-after: uint }
)

;; Nonce tracking for replay protection
(define-map vault-nonces
  { vault-id: uint }
  { nonce: uint }
)

;; Emergency contacts for recovery
(define-map recovery-contacts
  { vault-id: uint }
  {
    contact: principal,
    can-recover-after: uint  ;; Timestamp after which recovery is possible
  }
)

;; Shared vault access for temporary multi-user permissions
(define-map shared-access
  { vault-id: uint, user: principal }
  {
    granted-at: uint,
    expires-at: uint,
    withdrawal-limit: uint,     ;; Per-withdrawal limit for shared user
    total-limit: uint,           ;; Total amount shared user can withdraw
    total-withdrawn: uint,       ;; Amount withdrawn so far
    can-deposit: bool            ;; Whether shared user can deposit
  }
)

;; Track all users with shared access to a vault
(define-map vault-shared-users
  { vault-id: uint }
  (list 10 principal)
)

;; ========================================
;; Audit Trail Data Structures
;; ========================================

(define-data-var audit-log-counter uint u0)
(define-data-var max-logs-per-vault uint u100)

;; Activity types for audit trail
(define-constant ACTIVITY_VAULT_CREATED u1)
(define-constant ACTIVITY_DEPOSIT u2)
(define-constant ACTIVITY_WITHDRAWAL u3)
(define-constant ACTIVITY_TIME_LOCK_SET u4)
(define-constant ACTIVITY_PASSKEY_UPDATED u5)
(define-constant ACTIVITY_RECOVERY_CONTACT_SET u6)
(define-constant ACTIVITY_EMERGENCY_RECOVERY u7)
(define-constant ACTIVITY_SHARED_ACCESS_GRANTED u8)
(define-constant ACTIVITY_SHARED_ACCESS_REVOKED u9)
(define-constant ACTIVITY_VAULT_LOCKED u10)
(define-constant ACTIVITY_FAILED_WITHDRAWAL u11)

;; Audit log entries
(define-map audit-logs
  { vault-id: uint, log-id: uint }
  {
    activity-type: uint,
    actor: principal,
    amount: uint,              ;; Amount involved (0 if not applicable)
    timestamp: uint,
    metadata: (string-ascii 128),  ;; Additional context
    success: bool
  }
)

;; Track log count per vault
(define-map vault-log-count
  { vault-id: uint }
  { count: uint, first-log-id: uint, last-log-id: uint }
)

;; Security alerts tracking
(define-map security-alerts
  { vault-id: uint, alert-id: uint }
  {
    alert-type: (string-ascii 64),
    severity: uint,  ;; 1=low, 2=medium, 3=high, 4=critical
    details: (string-ascii 128),
    triggered-at: uint,
    resolved: bool
  }
)

(define-data-var alert-counter uint u0)

;; ========================================
;; Vault Insurance System
;; ========================================

(define-data-var insurance-counter uint u0)
(define-data-var insurance-fund-balance uint u0)
(define-data-var base-premium-rate uint u100) ;; Base premium: 100 basis points (1%)
(define-data-var coverage-multiplier uint u10) ;; Coverage = 10x premium paid
(define-data-var claim-review-period uint u86400) ;; 24 hours for claim review
(define-data-var contract-principal principal tx-sender)

;; Insurance policies for vaults
(define-map vault-insurance
  { vault-id: uint }
  {
    active: bool,
    coverage-amount: uint,
    premium-paid: uint,
    start-time: uint,
    expiry-time: uint,  ;; Policy duration (e.g., 1 year)
    claims-count: uint,
    total-claimed: uint
  }
)

;; Insurance claims
(define-map insurance-claims
  { vault-id: uint, claim-id: uint }
  {
    claim-amount: uint,
    claim-reason: (string-ascii 128),
    claimed-at: uint,
    processed: bool,
    approved: bool,
    payout-amount: uint,
    processed-at: uint
  }
)

(define-map vault-claim-count
  { vault-id: uint }
  { count: uint }
)

;; Read-only functions

;; Get vault details
(define-read-only (get-vault (vault-id uint))
  (map-get? vaults { vault-id: vault-id })
)

;; Get vault by owner
(define-read-only (get-vault-by-owner (owner principal))
  (match (map-get? owner-vault { owner: owner })
    vault-data (get-vault (get vault-id vault-data))
    none
  )
)

;; Get current nonce for a vault
(define-read-only (get-nonce (vault-id uint))
  (default-to u0 
    (get nonce (map-get? vault-nonces { vault-id: vault-id }))
  )
)

;; Check if time-lock is active
(define-read-only (is-time-locked (vault-id uint))
  (match (get-vault vault-id)
    vault (> (get time-lock-until vault) (unwrap-panic (get-block-timestamp)))
    false
  )
)

;; Get current block timestamp using Clarity 4 stacks-block-time
(define-read-only (get-block-timestamp)
  (ok stacks-block-time)
)

;; Calculate remaining time-lock duration
(define-read-only (get-time-lock-remaining (vault-id uint))
  (match (get-vault vault-id)
    vault 
      (let ((current-time (unwrap-panic (get-block-timestamp)))
            (lock-until (get time-lock-until vault)))
        (if (> lock-until current-time)
          (ok (- lock-until current-time))
          (ok u0)
        )
      )
    (err ERR_VAULT_NOT_FOUND)
  )
)

;; Get total protocol stats
(define-read-only (get-protocol-stats)
  {
    total-vaults: (var-get total-vaults),
    total-deposits: (var-get total-deposits),
    emergency-shutdown: (var-get emergency-shutdown)
  }
)

;; Check daily withdrawal availability
(define-read-only (get-daily-withdrawal-available (vault-id uint))
  (match (get-vault vault-id)
    vault
      (let ((current-time (unwrap-panic (get-block-timestamp))))
        (if (> current-time (get daily-reset-time vault))
          ;; New day, full limit available
          (ok (get withdrawal-limit vault))
          ;; Same day, calculate remaining
          (ok (- (get withdrawal-limit vault) (get daily-withdrawn vault)))
        )
      )
    (err ERR_VAULT_NOT_FOUND)
  )
)

;; Get comprehensive vault analytics
(define-read-only (get-vault-analytics (vault-id uint))
  (match (get-vault vault-id)
    vault
      (let ((current-time (unwrap-panic (get-block-timestamp)))
            (time-locked (> (get time-lock-until vault) current-time))
            (days-since-creation (/ (- current-time (get created-at vault)) u86400))
            (days-since-activity (/ (- current-time (get last-activity vault)) u86400)))
        (ok {
          vault-id: vault-id,
          stx-balance: (get stx-balance vault),
          is-time-locked: time-locked,
          time-lock-remaining: (if time-locked (- (get time-lock-until vault) current-time) u0),
          withdrawal-limit: (get withdrawal-limit vault),
          daily-withdrawn: (get daily-withdrawn vault),
          daily-available: (unwrap-panic (get-daily-withdrawal-available vault-id)),
          days-since-creation: days-since-creation,
          days-since-activity: days-since-activity,
          current-nonce: (get-nonce vault-id)
        })
      )
    (err ERR_VAULT_NOT_FOUND)
  )
)

;; Check if recovery is possible for a vault
(define-read-only (can-recover (vault-id uint) (caller principal))
  (match (map-get? recovery-contacts { vault-id: vault-id })
    recovery-data
      (and
        (is-eq caller (get contact recovery-data))
        (>= (unwrap-panic (get-block-timestamp)) (get can-recover-after recovery-data))
      )
    false
  )
)

;; Check if vault is inactive
(define-read-only (is-vault-inactive (vault-id uint))
  (match (get-vault vault-id)
    vault
      (let ((current-time (unwrap-panic (get-block-timestamp)))
            (threshold (var-get inactivity-threshold)))
        (> (- current-time (get last-activity vault)) threshold))
    false
  )
)

;; Check if vault is auto-locked
(define-read-only (is-vault-auto-locked (vault-id uint))
  (match (get-vault vault-id)
    vault
      (let ((current-time (unwrap-panic (get-block-timestamp))))
        (> (get auto-locked-until vault) current-time))
    false
  )
)

;; Get failed attempts count
(define-read-only (get-failed-attempts (vault-id uint))
  (match (get-vault vault-id)
    vault (ok (get failed-attempts vault))
    (err ERR_VAULT_NOT_FOUND)
  )
)

;; Get auto-lock status and time remaining
(define-read-only (get-auto-lock-status (vault-id uint))
  (match (get-vault vault-id)
    vault
      (let ((current-time (unwrap-panic (get-block-timestamp)))
            (locked-until (get auto-locked-until vault)))
        (ok {
          is-locked: (> locked-until current-time),
          locked-until: locked-until,
          time-remaining: (if (> locked-until current-time) (- locked-until current-time) u0),
          failed-attempts: (get failed-attempts vault)
        })
      )
    (err ERR_VAULT_NOT_FOUND)
  )
)

;; Get vault health score (0-100)
(define-read-only (get-vault-health-score (vault-id uint))
  (match (get-vault vault-id)
    vault
      (let (
          (current-time (unwrap-panic (get-block-timestamp)))
          (has-balance (if (> (get stx-balance vault) u0) u25 u0))
          (has-time-lock (if (> (get time-lock-until vault) current-time) u25 u0))
          (has-withdrawal-limit (if (<= (get withdrawal-limit vault) u100000000) u25 u0))
          (recent-activity (if (< (- current-time (get last-activity vault)) u2592000) u25 u0)) ;; Active in last 30 days
        )
        (ok (+ (+ has-balance has-time-lock) (+ has-withdrawal-limit recent-activity)))
      )
    (err ERR_VAULT_NOT_FOUND)
  )
)

;; Get total value locked in contract
(define-read-only (get-total-value-locked)
  (ok (var-get total-deposits))
)

;; Check if vault has recovery contact set
(define-read-only (has-recovery-contact (vault-id uint))
  (is-some (map-get? recovery-contacts { vault-id: vault-id }))
)

;; Get recovery contact info
(define-read-only (get-recovery-contact-info (vault-id uint))
  (map-get? recovery-contacts { vault-id: vault-id })
)

;; Get shared access info for a user
(define-read-only (get-shared-access (vault-id uint) (user principal))
  (map-get? shared-access { vault-id: vault-id, user: user })
)

;; Check if user has active shared access
(define-read-only (has-active-shared-access (vault-id uint) (user principal))
  (match (get-shared-access vault-id user)
    access-info
      (let ((current-time (unwrap-panic (get-block-timestamp))))
        (and
          (>= (get expires-at access-info) current-time)
          (< (get total-withdrawn access-info) (get total-limit access-info))
        )
      )
    false
  )
)

;; Get all users with shared access to a vault
(define-read-only (get-vault-shared-users (vault-id uint))
  (default-to (list) (map-get? vault-shared-users { vault-id: vault-id }))
)

;; Get shared user's remaining limit
(define-read-only (get-shared-access-remaining (vault-id uint) (user principal))
  (match (get-shared-access vault-id user)
    access-info
      (ok (- (get total-limit access-info) (get total-withdrawn access-info)))
    (err ERR_SHARED_ACCESS_NOT_FOUND)
  )
)

;; Private functions

;; Validate compressed secp256r1 public key format
;; Must be 33 bytes and start with 0x02 or 0x03
(define-private (is-valid-public-key (public-key (buff 33)))
  (let ((first-byte (unwrap! (element-at? public-key u0) false)))
    (and
      (is-eq (len public-key) u33)
      (or (is-eq first-byte 0x02) (is-eq first-byte 0x03))
    )
  )
)

;; Verify passkey signature using secp256r1-verify (Clarity 4, Epoch 3.3)
(define-private (verify-passkey-signature
    (message-hash (buff 32))
    (signature (buff 64))
    (public-key (buff 33)))
  (secp256r1-verify message-hash signature public-key)
)

;; Build message hash for withdrawal
(define-private (build-withdrawal-message (vault-id uint) (amount uint) (nonce uint))
  (sha256 (concat 
    (concat (unwrap-panic (to-consensus-buff? vault-id)) 
            (unwrap-panic (to-consensus-buff? amount)))
    (unwrap-panic (to-consensus-buff? nonce))
  ))
)

;; Update daily withdrawal tracking
(define-private (update-daily-withdrawal (vault-id uint) (amount uint))
  (match (get-vault vault-id)
    vault
      (let ((current-time (unwrap-panic (get-block-timestamp)))
            (one-day u86400))
        (if (> current-time (get daily-reset-time vault))
          ;; Reset daily counter
          (map-set vaults 
            { vault-id: vault-id }
            (merge vault {
              daily-withdrawn: amount,
              daily-reset-time: (+ current-time one-day),
              last-activity: current-time
            })
          )
          ;; Add to existing daily counter
          (map-set vaults 
            { vault-id: vault-id }
            (merge vault {
              daily-withdrawn: (+ (get daily-withdrawn vault) amount),
              last-activity: current-time
            })
          )
        )
      )
    false
  )
)

;; ========================================
;; Audit Trail Read-Only Functions
;; ========================================

;; Get specific audit log entry
(define-read-only (get-audit-log (vault-id uint) (log-id uint))
  (map-get? audit-logs { vault-id: vault-id, log-id: log-id })
)

;; Get vault log statistics
(define-read-only (get-vault-log-stats (vault-id uint))
  (default-to
    { count: u0, first-log-id: u0, last-log-id: u0 }
    (map-get? vault-log-count { vault-id: vault-id })
  )
)

;; Get security alert
(define-read-only (get-security-alert (vault-id uint) (alert-id uint))
  (map-get? security-alerts { vault-id: vault-id, alert-id: alert-id })
)

;; Get activity type name for readability
(define-read-only (get-activity-name (activity-type uint))
  (if (is-eq activity-type ACTIVITY_VAULT_CREATED) "VAULT_CREATED"
  (if (is-eq activity-type ACTIVITY_DEPOSIT) "DEPOSIT"
  (if (is-eq activity-type ACTIVITY_WITHDRAWAL) "WITHDRAWAL"
  (if (is-eq activity-type ACTIVITY_TIME_LOCK_SET) "TIME_LOCK_SET"
  (if (is-eq activity-type ACTIVITY_PASSKEY_UPDATED) "PASSKEY_UPDATED"
  (if (is-eq activity-type ACTIVITY_RECOVERY_CONTACT_SET) "RECOVERY_CONTACT_SET"
  (if (is-eq activity-type ACTIVITY_EMERGENCY_RECOVERY) "EMERGENCY_RECOVERY"
  (if (is-eq activity-type ACTIVITY_SHARED_ACCESS_GRANTED) "SHARED_ACCESS_GRANTED"
  (if (is-eq activity-type ACTIVITY_SHARED_ACCESS_REVOKED) "SHARED_ACCESS_REVOKED"
  (if (is-eq activity-type ACTIVITY_VAULT_LOCKED) "VAULT_LOCKED"
  (if (is-eq activity-type ACTIVITY_FAILED_WITHDRAWAL) "FAILED_WITHDRAWAL"
  "UNKNOWN")))))))))))
)

;; Get comprehensive vault audit summary
(define-read-only (get-vault-audit-summary (vault-id uint))
  (let
    (
      (stats (get-vault-log-stats vault-id))
    )
    {
      total-logs: (get count stats),
      first-log-id: (get first-log-id stats),
      last-log-id: (get last-log-id stats),
      audit-enabled: true
    }
  )
)

;; ========================================
;; Insurance Read-Only Functions
;; ========================================

;; Get vault insurance policy
(define-read-only (get-vault-insurance (vault-id uint))
  (map-get? vault-insurance { vault-id: vault-id })
)

;; Check if insurance is active
(define-read-only (is-insurance-active (vault-id uint))
  (match (get-vault-insurance vault-id)
    policy (and (get active policy) (> (get expiry-time policy) stacks-block-time))
    false)
)

;; Calculate premium for vault coverage
(define-read-only (calculate-premium (coverage-amount uint))
  (let
    (
      (rate (var-get base-premium-rate))
    )
    (/ (* coverage-amount rate) u10000)
  )
)

;; Get insurance claim
(define-read-only (get-insurance-claim (vault-id uint) (claim-id uint))
  (map-get? insurance-claims { vault-id: vault-id, claim-id: claim-id })
)

;; Get vault claim count
(define-read-only (get-vault-claims-count (vault-id uint))
  (default-to u0 (get count (map-get? vault-claim-count { vault-id: vault-id })))
)

;; Get insurance fund balance
(define-read-only (get-insurance-fund-balance)
  (var-get insurance-fund-balance)
)

;; Get remaining coverage
(define-read-only (get-remaining-coverage (vault-id uint))
  (match (get-vault-insurance vault-id)
    policy (- (get coverage-amount policy) (get total-claimed policy))
    u0)
)

;; Get insurance policy info
(define-read-only (get-insurance-info (vault-id uint))
  (match (get-vault-insurance vault-id)
    policy {
      active: (get active policy),
      coverage-amount: (get coverage-amount policy),
      remaining-coverage: (- (get coverage-amount policy) (get total-claimed policy)),
      premium-paid: (get premium-paid policy),
      expiry-time: (get expiry-time policy),
      is-expired: (<= (get expiry-time policy) stacks-block-time),
      claims-count: (get claims-count policy),
      total-claimed: (get total-claimed policy)
    }
    {
      active: false,
      coverage-amount: u0,
      remaining-coverage: u0,
      premium-paid: u0,
      expiry-time: u0,
      is-expired: true,
      claims-count: u0,
      total-claimed: u0
    })
)

;; Public functions

;; Create a new vault with passkey
(define-public (create-vault 
    (passkey-public-key (buff 33))
    (time-lock-duration uint)
    (withdrawal-limit uint))
  (let (
      (vault-id (+ (var-get total-vaults) u1))
      (current-time (unwrap-panic (get-block-timestamp)))
    )
    ;; Validations
    (asserts! (is-none (map-get? owner-vault { owner: tx-sender })) ERR_VAULT_EXISTS)
    (asserts! (is-valid-public-key passkey-public-key) ERR_INVALID_PUBLIC_KEY)
    (asserts! (or (is-eq time-lock-duration u0)
                  (and (>= time-lock-duration MIN_TIME_LOCK)
                       (<= time-lock-duration MAX_TIME_LOCK)))
              ERR_INVALID_TIME_LOCK)
    (asserts! (and (>= withdrawal-limit MIN_WITHDRAWAL_LIMIT)
                   (<= withdrawal-limit MAX_WITHDRAWAL_LIMIT))
              ERR_INVALID_WITHDRAWAL_LIMIT)
    
    ;; Create vault
    (map-set vaults
      { vault-id: vault-id }
      {
        owner: tx-sender,
        passkey-public-key: passkey-public-key,
        stx-balance: u0,
        time-lock-until: (if (> time-lock-duration u0)
                           (+ current-time time-lock-duration)
                           u0),
        created-at: current-time,
        last-activity: current-time,
        withdrawal-limit: withdrawal-limit,
        daily-withdrawn: u0,
        daily-reset-time: (+ current-time u86400),
        auto-locked-until: u0,
        failed-attempts: u0
      }
    )
    
    ;; Map owner to vault
    (map-set owner-vault { owner: tx-sender } { vault-id: vault-id })
    
    ;; Initialize nonce
    (map-set vault-nonces { vault-id: vault-id } { nonce: u0 })
    
    ;; Update global counter
    (var-set total-vaults vault-id)

    (print {event: "vault-created", vault-id: vault-id, owner: tx-sender, time-lock: time-lock-duration})
    (ok vault-id)
  )
)

;; Deposit STX into vault
(define-public (deposit-stx (vault-id uint) (amount uint))
  (let (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (current-time (unwrap-panic (get-block-timestamp)))
    )
    ;; Validations
    (asserts! (is-eq (get owner vault) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (asserts! (not (var-get emergency-shutdown)) ERR_NOT_AUTHORIZED)

    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (unwrap-panic (as-contract? ((with-stx u0)) tx-sender))))

    ;; Update vault balance
    (map-set vaults
      { vault-id: vault-id }
      (merge vault {
        stx-balance: (+ (get stx-balance vault) amount),
        last-activity: current-time
      })
    )

    ;; Update total deposits
    (var-set total-deposits (+ (var-get total-deposits) amount))

    (print {event: "deposit", vault-id: vault-id, amount: amount, new-balance: (+ (get stx-balance vault) amount)})
    (ok true)
  )
)

;; Batch deposit - deposit into multiple vaults in one transaction
(define-public (batch-deposit (deposits (list 10 {vault-id: uint, amount: uint})))
  (let (
      (total-amount (fold + (map get-deposit-amount deposits) u0))
    )
    ;; Validate emergency shutdown
    (asserts! (not (var-get emergency-shutdown)) ERR_NOT_AUTHORIZED)

    ;; Process all deposits
    (fold process-single-deposit deposits (ok true))
  )
)

;; Helper function to extract amount from deposit tuple
(define-private (get-deposit-amount (deposit {vault-id: uint, amount: uint}))
  (get amount deposit)
)

;; Helper function to process a single deposit in batch
(define-private (process-single-deposit
    (deposit {vault-id: uint, amount: uint})
    (previous-result (response bool uint)))
  (match previous-result
    success (deposit-stx (get vault-id deposit) (get amount deposit))
    error (err error)
  )
)

;; Withdraw STX with passkey authentication
(define-public (withdraw-with-passkey
    (vault-id uint)
    (amount uint)
    (signature (buff 64)))
  (let (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (current-nonce (get-nonce vault-id))
      (current-time (unwrap-panic (get-block-timestamp)))
      (message-hash (build-withdrawal-message vault-id amount current-nonce))
    )
    ;; Validations
    (asserts! (is-eq (get owner vault) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (asserts! (<= amount (get stx-balance vault)) ERR_INSUFFICIENT_BALANCE)
    (asserts! (<= (get time-lock-until vault) current-time) ERR_TIME_LOCK_ACTIVE)
    (asserts! (not (var-get emergency-shutdown)) ERR_NOT_AUTHORIZED)

    ;; Check auto-lock status
    (asserts! (<= (get auto-locked-until vault) current-time) ERR_VAULT_LOCKED)

    ;; Verify passkey signature - handle failed attempts
    (let ((signature-valid (verify-passkey-signature message-hash signature (get passkey-public-key vault))))
      (if signature-valid
        ;; Signature valid - reset failed attempts
        (map-set vaults
          { vault-id: vault-id }
          (merge vault { failed-attempts: u0 }))
        ;; Signature invalid - increment failed attempts and potentially lock
        (let ((new-failed-count (+ (get failed-attempts vault) u1)))
          (begin
            (map-set vaults
              { vault-id: vault-id }
              (merge vault {
                failed-attempts: new-failed-count,
                auto-locked-until: (if (>= new-failed-count (var-get max-failed-attempts))
                                    (+ current-time (var-get auto-lock-duration))
                                    (get auto-locked-until vault))
              }))
            (if (>= new-failed-count (var-get max-failed-attempts))
              (begin
                (print {event: "vault-auto-locked", vault-id: vault-id, failed-attempts: new-failed-count, locked-until: (+ current-time (var-get auto-lock-duration))})
                true)
              (begin
                (print {event: "failed-withdrawal-attempt", vault-id: vault-id, failed-attempts: new-failed-count})
                true)))))
      ;; Assert signature is valid after handling attempts
      (asserts! signature-valid ERR_INVALID_SIGNATURE))
    
    ;; Check daily limit
    (let ((available (unwrap! (get-daily-withdrawal-available vault-id) ERR_VAULT_NOT_FOUND)))
      (asserts! (<= amount available) ERR_INSUFFICIENT_BALANCE)
    )
    
    ;; Update nonce for replay protection
    (map-set vault-nonces { vault-id: vault-id } { nonce: (+ current-nonce u1) })
    
    ;; Update daily withdrawal tracking
    (update-daily-withdrawal vault-id amount)
    
    ;; Update vault balance
    (map-set vaults 
      { vault-id: vault-id }
      (merge vault {
        stx-balance: (- (get stx-balance vault) amount),
        last-activity: current-time
      })
    )
    
    ;; Update total deposits
    (var-set total-deposits (- (var-get total-deposits) amount))
    
    ;; Transfer STX to owner
    (try! (as-contract? ((with-stx amount))
      (unwrap-panic (stx-transfer? amount tx-sender (get owner vault)))
    ))

    (print {event: "withdrawal", vault-id: vault-id, amount: amount, nonce: current-nonce, remaining-balance: (- (get stx-balance vault) amount)})
    (ok true)
  )
)

;; Set new time-lock
(define-public (set-time-lock (vault-id uint) (duration uint))
  (let (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (current-time (unwrap-panic (get-block-timestamp)))
    )
    ;; Validations
    (asserts! (is-eq (get owner vault) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (and (>= duration MIN_TIME_LOCK) (<= duration MAX_TIME_LOCK)) ERR_INVALID_TIME_LOCK)
    
    ;; Update time-lock
    (map-set vaults
      { vault-id: vault-id }
      (merge vault {
        time-lock-until: (+ current-time duration),
        last-activity: current-time
      })
    )

    (print {event: "time-lock-set", vault-id: vault-id, duration: duration, locked-until: (+ current-time duration)})
    (ok true)
  )
)

;; Update passkey public key
(define-public (update-passkey (vault-id uint) (new-public-key (buff 33)) (signature (buff 64)))
  (let (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (current-nonce (get-nonce vault-id))
      (current-time (unwrap-panic (get-block-timestamp)))
      ;; Include nonce in message hash for replay protection
      (message-hash (sha256 (concat
        (concat (unwrap-panic (to-consensus-buff? vault-id))
                new-public-key)
        (unwrap-panic (to-consensus-buff? current-nonce))
      )))
    )
    ;; Validations
    (asserts! (is-eq (get owner vault) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-valid-public-key new-public-key) ERR_INVALID_PUBLIC_KEY)

    ;; Verify current passkey signature
    (asserts! (verify-passkey-signature
                message-hash
                signature
                (get passkey-public-key vault))
              ERR_INVALID_SIGNATURE)

    ;; Update nonce
    (map-set vault-nonces { vault-id: vault-id } { nonce: (+ current-nonce u1) })

    ;; Update passkey
    (map-set vaults
      { vault-id: vault-id }
      (merge vault {
        passkey-public-key: new-public-key,
        last-activity: current-time
      })
    )

    (print {event: "passkey-updated", vault-id: vault-id, nonce: current-nonce})
    (ok true)
  )
)

;; Set recovery contact
(define-public (set-recovery-contact (vault-id uint) (contact principal) (recovery-delay uint))
  (let (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (current-time (unwrap-panic (get-block-timestamp)))
    )
    ;; Validations
    (asserts! (is-eq (get owner vault) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (>= recovery-delay u604800) ERR_INVALID_TIME_LOCK) ;; Minimum 7 days
    
    ;; Set recovery contact
    (map-set recovery-contacts
      { vault-id: vault-id }
      {
        contact: contact,
        can-recover-after: (+ current-time recovery-delay)
      }
    )

    (print {event: "recovery-contact-set", vault-id: vault-id, contact: contact, can-recover-after: (+ current-time recovery-delay)})
    (ok true)
  )
)

;; Update withdrawal limit with validation
(define-public (update-withdrawal-limit (vault-id uint) (new-limit uint))
  (let (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (current-time (unwrap-panic (get-block-timestamp)))
    )
    ;; Validations
    (asserts! (is-eq (get owner vault) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (and (>= new-limit MIN_WITHDRAWAL_LIMIT)
                   (<= new-limit MAX_WITHDRAWAL_LIMIT))
              ERR_INVALID_WITHDRAWAL_LIMIT)

    ;; Update limit
    (map-set vaults
      { vault-id: vault-id }
      (merge vault {
        withdrawal-limit: new-limit,
        last-activity: current-time
      })
    )

    (print {event: "withdrawal-limit-updated", vault-id: vault-id, new-limit: new-limit})
    (ok true)
  )
)

;; Emergency withdrawal by recovery contact (after delay period)
;; Funds are always transferred to the vault owner for security
(define-public (emergency-recovery (vault-id uint))
  (let (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (recovery (unwrap! (map-get? recovery-contacts { vault-id: vault-id }) ERR_NOT_AUTHORIZED))
      (current-time (unwrap-panic (get-block-timestamp)))
    )
    ;; Validations
    (asserts! (is-eq (get contact recovery) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (>= current-time (get can-recover-after recovery)) ERR_TIME_LOCK_ACTIVE)

    ;; Transfer all funds to vault owner only (not arbitrary recipient)
    (let ((balance (get stx-balance vault)))
      (if (> balance u0)
        (begin
          ;; Update vault
          (map-set vaults
            { vault-id: vault-id }
            (merge vault {
              stx-balance: u0,
              last-activity: current-time
            })
          )
          ;; Transfer to vault owner only
          (try! (as-contract? ((with-stx balance))
            (unwrap-panic (stx-transfer? balance tx-sender (get owner vault)))
          ))
          (var-set total-deposits (- (var-get total-deposits) balance))
          (print {event: "emergency-recovery", vault-id: vault-id, amount: balance, recovered-by: tx-sender, owner: (get owner vault)})
          true
        )
        true
      )
    )

    (ok true)
  )
)

;; Admin: Emergency shutdown
(define-public (emergency-shutdown-toggle)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set emergency-shutdown (not (var-get emergency-shutdown)))
    (print {event: "emergency-shutdown-toggle", active: (var-get emergency-shutdown), by: tx-sender})
    (ok (var-get emergency-shutdown))
  )
)

;; Manually unlock vault (owner only)
(define-public (unlock-vault (vault-id uint))
  (let (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (current-time (unwrap-panic (get-block-timestamp)))
    )
    ;; Validations
    (asserts! (is-eq (get owner vault) tx-sender) ERR_NOT_AUTHORIZED)

    ;; Reset auto-lock and failed attempts
    (map-set vaults
      { vault-id: vault-id }
      (merge vault {
        auto-locked-until: u0,
        failed-attempts: u0,
        last-activity: current-time
      })
    )

    (print {event: "vault-manually-unlocked", vault-id: vault-id, by: tx-sender})
    (ok true)
  )
)

;; Admin: Configure auto-lock parameters
(define-public (set-auto-lock-config (max-attempts uint) (lock-duration uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> max-attempts u0) ERR_INVALID_AMOUNT)
    (asserts! (>= lock-duration u3600) ERR_INVALID_TIME_LOCK) ;; Minimum 1 hour
    (asserts! (<= lock-duration u604800) ERR_INVALID_TIME_LOCK) ;; Maximum 7 days

    (var-set max-failed-attempts max-attempts)
    (var-set auto-lock-duration lock-duration)

    (print {event: "auto-lock-config-updated", max-attempts: max-attempts, lock-duration: lock-duration})
    (ok true)
  )
)

(define-public (set-emergency-contact (vault-id uint) (contact principal) (wait-period uint))
  (let ((vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner vault)) ERR_NOT_AUTHORIZED)
    (asserts! (is-none (map-get? emergency-contacts { vault-id: vault-id })) ERR_EMERGENCY_CONTACT_EXISTS)
    (asserts! (>= wait-period u86400) ERR_INVALID_AMOUNT)
    (map-set emergency-contacts { vault-id: vault-id } {
      contact: contact,
      set-at: stacks-block-time,
      can-withdraw-after: (+ stacks-block-time wait-period)
    })
    (print {event: "emergency-contact-set", vault-id: vault-id, contact: contact, can-withdraw-after: (+ stacks-block-time wait-period)})
    (ok true)))

(define-public (emergency-withdraw (vault-id uint))
  (let ((vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
        (emergency-contact (unwrap! (map-get? emergency-contacts { vault-id: vault-id }) ERR_NOT_RECOVERY_CONTACT))
        (amount (get stx-balance vault)))
    (asserts! (is-eq tx-sender (get contact emergency-contact)) ERR_NOT_RECOVERY_CONTACT)
    (asserts! (>= stacks-block-time (get can-withdraw-after emergency-contact)) ERR_TIME_LOCK_ACTIVE)
    (asserts! (> amount u0) ERR_INSUFFICIENT_BALANCE)
    (map-set vaults { vault-id: vault-id } (merge vault { stx-balance: u0 }))
    (map-delete emergency-contacts { vault-id: vault-id })
    (print {event: "emergency-withdrawal", vault-id: vault-id, contact: tx-sender, amount: amount})
    (ok amount)))

;; Admin: Reset failed attempts for a vault (emergency use)
(define-public (admin-reset-failed-attempts (vault-id uint))
  (let (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)

    (map-set vaults
      { vault-id: vault-id }
      (merge vault {
        failed-attempts: u0,
        auto-locked-until: u0
      })
    )

    (print {event: "admin-reset-failed-attempts", vault-id: vault-id})
    (ok true)
  )
)

;; ========================================
;; Shared Vault Access Functions
;; ========================================

;; Grant shared access to another user
(define-public (grant-shared-access
    (vault-id uint)
    (user principal)
    (duration uint)
    (withdrawal-limit uint)
    (total-limit uint)
    (can-deposit bool))
  (let (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (current-time (unwrap-panic (get-block-timestamp)))
      (existing-users (get-vault-shared-users vault-id))
    )
    ;; Validations
    (asserts! (is-eq (get owner vault) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-none (get-shared-access vault-id user)) ERR_SHARED_ACCESS_EXISTS)
    (asserts! (> duration u0) ERR_INVALID_TIME_LOCK)
    (asserts! (<= duration u2592000) ERR_INVALID_TIME_LOCK) ;; Max 30 days
    (asserts! (> withdrawal-limit u0) ERR_INVALID_WITHDRAWAL_LIMIT)
    (asserts! (> total-limit u0) ERR_INVALID_WITHDRAWAL_LIMIT)
    (asserts! (<= withdrawal-limit total-limit) ERR_INVALID_WITHDRAWAL_LIMIT)

    ;; Create shared access
    (map-set shared-access
      { vault-id: vault-id, user: user }
      {
        granted-at: current-time,
        expires-at: (+ current-time duration),
        withdrawal-limit: withdrawal-limit,
        total-limit: total-limit,
        total-withdrawn: u0,
        can-deposit: can-deposit
      }
    )

    ;; Add user to shared users list
    (map-set vault-shared-users
      { vault-id: vault-id }
      (unwrap! (as-max-len? (append existing-users user) u10) ERR_BATCH_LIMIT_EXCEEDED)
    )

    (print {
      event: "shared-access-granted",
      vault-id: vault-id,
      user: user,
      expires-at: (+ current-time duration),
      withdrawal-limit: withdrawal-limit,
      total-limit: total-limit,
      can-deposit: can-deposit,
      timestamp: current-time
    })

    (ok true)
  )
)

;; Revoke shared access
(define-public (revoke-shared-access (vault-id uint) (user principal))
  (let (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (access-info (unwrap! (get-shared-access vault-id user) ERR_SHARED_ACCESS_NOT_FOUND))
    )
    ;; Validations
    (asserts! (is-eq (get owner vault) tx-sender) ERR_NOT_AUTHORIZED)

    ;; Remove shared access
    (map-delete shared-access { vault-id: vault-id, user: user })

    (print {
      event: "shared-access-revoked",
      vault-id: vault-id,
      user: user,
      total-withdrawn: (get total-withdrawn access-info),
      timestamp: stacks-block-time
    })

    (ok true)
  )
)

;; Shared user deposit to vault
(define-public (shared-deposit (vault-id uint) (amount uint))
  (let (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (access-info (unwrap! (get-shared-access vault-id tx-sender) ERR_SHARED_ACCESS_NOT_FOUND))
      (current-time (unwrap-panic (get-block-timestamp)))
    )
    ;; Validations
    (asserts! (get can-deposit access-info) ERR_NOT_AUTHORIZED)
    (asserts! (>= (get expires-at access-info) current-time) ERR_SHARED_ACCESS_EXPIRED)
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (asserts! (not (var-get emergency-shutdown)) ERR_NOT_AUTHORIZED)

    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (unwrap-panic (as-contract? ((with-stx u0)) tx-sender))))

    ;; Update vault balance
    (map-set vaults
      { vault-id: vault-id }
      (merge vault {
        stx-balance: (+ (get stx-balance vault) amount),
        last-activity: current-time
      })
    )

    ;; Update total deposits
    (var-set total-deposits (+ (var-get total-deposits) amount))

    (print {
      event: "shared-deposit",
      vault-id: vault-id,
      shared-user: tx-sender,
      amount: amount,
      new-balance: (+ (get stx-balance vault) amount),
      timestamp: current-time
    })

    (ok true)
  )
)

;; Shared user withdrawal from vault
(define-public (shared-withdraw (vault-id uint) (amount uint))
  (let (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (access-info (unwrap! (get-shared-access vault-id tx-sender) ERR_SHARED_ACCESS_NOT_FOUND))
      (current-time (unwrap-panic (get-block-timestamp)))
    )
    ;; Validations
    (asserts! (>= (get expires-at access-info) current-time) ERR_SHARED_ACCESS_EXPIRED)
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (asserts! (<= amount (get stx-balance vault)) ERR_INSUFFICIENT_BALANCE)
    (asserts! (<= amount (get withdrawal-limit access-info)) ERR_SHARED_LIMIT_EXCEEDED)
    (asserts! (<= (+ (get total-withdrawn access-info) amount) (get total-limit access-info)) ERR_SHARED_LIMIT_EXCEEDED)
    (asserts! (not (var-get emergency-shutdown)) ERR_NOT_AUTHORIZED)

    ;; Update shared access withdrawn amount
    (map-set shared-access
      { vault-id: vault-id, user: tx-sender }
      (merge access-info {
        total-withdrawn: (+ (get total-withdrawn access-info) amount)
      })
    )

    ;; Update vault balance
    (map-set vaults
      { vault-id: vault-id }
      (merge vault {
        stx-balance: (- (get stx-balance vault) amount),
        last-activity: current-time
      })
    )

    ;; Update total deposits
    (var-set total-deposits (- (var-get total-deposits) amount))

    ;; Transfer STX to shared user
    (try! (as-contract? ((with-stx amount))
      (unwrap-panic (stx-transfer? amount tx-sender tx-sender))
    ))

    (print {
      event: "shared-withdrawal",
      vault-id: vault-id,
      shared-user: tx-sender,
      amount: amount,
      remaining-balance: (- (get stx-balance vault) amount),
      total-withdrawn: (+ (get total-withdrawn access-info) amount),
      total-limit: (get total-limit access-info),
      timestamp: current-time
    })

    (ok true)
  )
)

;; ========================================
;; Audit Trail Public Functions
;; ========================================

;; Log vault activity (internal helper function pattern - made public for transparency)
(define-public (log-activity
  (vault-id uint)
  (activity-type uint)
  (amount uint)
  (metadata (string-ascii 128))
  (success bool))
  (let
    (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (log-id (var-get audit-log-counter))
      (current-time (unwrap-panic (get-block-timestamp)))
      (vault-stats (get-vault-log-stats vault-id))
    )
    ;; Verify vault exists
    (asserts! (is-some (get-vault vault-id)) ERR_VAULT_NOT_FOUND)

    ;; Create audit log entry
    (map-set audit-logs
      { vault-id: vault-id, log-id: log-id }
      {
        activity-type: activity-type,
        actor: tx-sender,
        amount: amount,
        timestamp: current-time,
        metadata: metadata,
        success: success
      }
    )

    ;; Update vault log count
    (map-set vault-log-count
      { vault-id: vault-id }
      {
        count: (+ (get count vault-stats) u1),
        first-log-id: (if (is-eq (get count vault-stats) u0)
                        log-id
                        (get first-log-id vault-stats)),
        last-log-id: log-id
      }
    )

    ;; Increment global counter
    (var-set audit-log-counter (+ log-id u1))

    ;; Emit Chainhook event
    (print {
      event: "activity-logged",
      vault-id: vault-id,
      log-id: log-id,
      activity-type: activity-type,
      activity-name: (get-activity-name activity-type),
      actor: tx-sender,
      amount: amount,
      metadata: metadata,
      success: success,
      timestamp: current-time
    })

    (ok log-id)
  )
)

;; Create security alert
(define-public (create-security-alert
  (vault-id uint)
  (alert-type (string-ascii 64))
  (severity uint)
  (details (string-ascii 128)))
  (let
    (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (alert-id (var-get alert-counter))
      (current-time (unwrap-panic (get-block-timestamp)))
    )
    ;; Verify vault exists
    (asserts! (is-some (get-vault vault-id)) ERR_VAULT_NOT_FOUND)

    ;; Verify severity is valid (1-4)
    (asserts! (and (>= severity u1) (<= severity u4)) ERR_INVALID_LOG_FILTER)

    ;; Only vault owner or contract owner can create alerts
    (asserts! (or
      (is-eq tx-sender (get owner vault))
      (is-eq tx-sender CONTRACT_OWNER)
    ) ERR_NOT_AUTHORIZED)

    ;; Create security alert
    (map-set security-alerts
      { vault-id: vault-id, alert-id: alert-id }
      {
        alert-type: alert-type,
        severity: severity,
        details: details,
        triggered-at: current-time,
        resolved: false
      }
    )

    ;; Increment alert counter
    (var-set alert-counter (+ alert-id u1))

    ;; Emit Chainhook event
    (print {
      event: "security-alert-created",
      vault-id: vault-id,
      alert-id: alert-id,
      alert-type: alert-type,
      severity: severity,
      severity-name: (if (is-eq severity u1) "low"
                      (if (is-eq severity u2) "medium"
                      (if (is-eq severity u3) "high"
                      "critical"))),
      details: details,
      triggered-at: current-time
    })

    (ok alert-id)
  )
)

;; Resolve security alert
(define-public (resolve-security-alert (vault-id uint) (alert-id uint))
  (let
    (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (alert (unwrap! (get-security-alert vault-id alert-id) ERR_AUDIT_LOG_NOT_FOUND))
    )
    ;; Only vault owner or contract owner can resolve alerts
    (asserts! (or
      (is-eq tx-sender (get owner vault))
      (is-eq tx-sender CONTRACT_OWNER)
    ) ERR_NOT_AUTHORIZED)

    ;; Mark alert as resolved
    (map-set security-alerts
      { vault-id: vault-id, alert-id: alert-id }
      (merge alert { resolved: true })
    )

    ;; Emit Chainhook event
    (print {
      event: "security-alert-resolved",
      vault-id: vault-id,
      alert-id: alert-id,
      alert-type: (get alert-type alert),
      resolved-by: tx-sender,
      timestamp: (unwrap-panic (get-block-timestamp))
    })

    (ok true)
  )
)

;; Admin: Configure audit settings
(define-public (set-audit-config (max-logs uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> max-logs u0) ERR_INVALID_LOG_FILTER)

    (var-set max-logs-per-vault max-logs)

    (print {
      event: "audit-config-updated",
      max-logs-per-vault: max-logs,
      timestamp: (unwrap-panic (get-block-timestamp))
    })

    (ok true)
  )
)

;; ========================================
;; Insurance Public Functions
;; ========================================

;; Purchase insurance for a vault
(define-public (purchase-insurance (vault-id uint) (coverage-amount uint) (duration uint))
  (let
    (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (premium (calculate-premium coverage-amount))
      (current-time stacks-block-time)
    )
    ;; Validations
    (asserts! (is-eq tx-sender (get owner vault)) ERR_NOT_AUTHORIZED)
    (asserts! (is-none (get-vault-insurance vault-id)) ERR_INSURANCE_EXISTS)
    (asserts! (> coverage-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= duration u2592000) ERR_INVALID_AMOUNT) ;; Min 30 days

    ;; Transfer premium to insurance fund
    (unwrap! (stx-transfer? premium tx-sender (var-get contract-principal)) ERR_INSUFFICIENT_BALANCE)

    ;; Create insurance policy
    (map-set vault-insurance
      { vault-id: vault-id }
      {
        active: true,
        coverage-amount: coverage-amount,
        premium-paid: premium,
        start-time: current-time,
        expiry-time: (+ current-time duration),
        claims-count: u0,
        total-claimed: u0
      }
    )

    ;; Update fund balance
    (var-set insurance-fund-balance (+ (var-get insurance-fund-balance) premium))

    ;; Log activity
    (try! (log-activity vault-id u12 coverage-amount "insurance-purchased" true))

    (print {
      event: "insurance-purchased",
      vault-id: vault-id,
      coverage-amount: coverage-amount,
      premium-paid: premium,
      expiry-time: (+ current-time duration),
      timestamp: current-time
    })

    (ok true)
  )
)

;; File insurance claim
(define-public (file-insurance-claim (vault-id uint) (claim-amount uint) (reason (string-ascii 128)))
  (let
    (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (policy (unwrap! (get-vault-insurance vault-id) ERR_NO_INSURANCE))
      (current-time stacks-block-time)
      (claim-count (get-vault-claims-count vault-id))
      (claim-id (+ claim-count u1))
    )
    ;; Validations
    (asserts! (is-eq tx-sender (get owner vault)) ERR_NOT_AUTHORIZED)
    (asserts! (get active policy) ERR_NO_INSURANCE)
    (asserts! (> (get expiry-time policy) current-time) ERR_NO_INSURANCE)
    (asserts! (> claim-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= (+ (get total-claimed policy) claim-amount) (get coverage-amount policy)) ERR_INSUFFICIENT_COVERAGE)

    ;; Create claim record
    (map-set insurance-claims
      { vault-id: vault-id, claim-id: claim-id }
      {
        claim-amount: claim-amount,
        claim-reason: reason,
        claimed-at: current-time,
        processed: false,
        approved: false,
        payout-amount: u0,
        processed-at: u0
      }
    )

    ;; Update claim count
    (map-set vault-claim-count
      { vault-id: vault-id }
      { count: claim-id }
    )

    ;; Log activity
    (try! (log-activity vault-id u13 claim-amount reason true))

    (print {
      event: "insurance-claim-filed",
      vault-id: vault-id,
      claim-id: claim-id,
      claim-amount: claim-amount,
      reason: reason,
      timestamp: current-time
    })

    (ok claim-id)
  )
)

;; Process insurance claim (admin function)
(define-public (process-claim (vault-id uint) (claim-id uint) (approved bool))
  (let
    (
      (claim (unwrap! (get-insurance-claim vault-id claim-id) ERR_CLAIM_NOT_FOUND))
      (policy (unwrap! (get-vault-insurance vault-id) ERR_NO_INSURANCE))
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (current-time stacks-block-time)
      (payout (if approved (get claim-amount claim) u0))
    )
    ;; Validations
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (not (get processed claim)) ERR_CLAIM_ALREADY_PROCESSED)
    (asserts! (>= current-time (+ (get claimed-at claim) (var-get claim-review-period))) ERR_INVALID_AMOUNT)

    ;; If approved, transfer payout to vault owner
    (if approved
      (begin
        (unwrap! (stx-transfer? payout (var-get contract-principal) (get owner vault)) ERR_INSUFFICIENT_BALANCE)

        ;; Update policy
        (map-set vault-insurance
          { vault-id: vault-id }
          (merge policy {
            claims-count: (+ (get claims-count policy) u1),
            total-claimed: (+ (get total-claimed policy) payout)
          })
        )

        ;; Update fund balance
        (var-set insurance-fund-balance (- (var-get insurance-fund-balance) payout))
      )
      true
    )

    ;; Update claim record
    (map-set insurance-claims
      { vault-id: vault-id, claim-id: claim-id }
      (merge claim {
        processed: true,
        approved: approved,
        payout-amount: payout,
        processed-at: current-time
      })
    )

    ;; Log activity
    (try! (log-activity vault-id u14 payout (if approved "claim-approved" "claim-rejected") true))

    (print {
      event: "insurance-claim-processed",
      vault-id: vault-id,
      claim-id: claim-id,
      approved: approved,
      payout-amount: payout,
      timestamp: current-time
    })

    (ok payout)
  )
)

;; Renew insurance policy
(define-public (renew-insurance (vault-id uint) (duration uint))
  (let
    (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (policy (unwrap! (get-vault-insurance vault-id) ERR_NO_INSURANCE))
      (premium (calculate-premium (get coverage-amount policy)))
      (current-time stacks-block-time)
    )
    ;; Validations
    (asserts! (is-eq tx-sender (get owner vault)) ERR_NOT_AUTHORIZED)
    (asserts! (>= duration u2592000) ERR_INVALID_AMOUNT) ;; Min 30 days

    ;; Transfer premium
    (unwrap! (stx-transfer? premium tx-sender (var-get contract-principal)) ERR_INSUFFICIENT_BALANCE)

    ;; Renew policy
    (map-set vault-insurance
      { vault-id: vault-id }
      (merge policy {
        active: true,
        premium-paid: (+ (get premium-paid policy) premium),
        expiry-time: (+ current-time duration)
      })
    )

    ;; Update fund balance
    (var-set insurance-fund-balance (+ (var-get insurance-fund-balance) premium))

    (print {
      event: "insurance-renewed",
      vault-id: vault-id,
      premium-paid: premium,
      new-expiry: (+ current-time duration),
      timestamp: current-time
    })

    (ok true)
  )
)

;; Cancel insurance (partial refund)
(define-public (cancel-insurance (vault-id uint))
  (let
    (
      (vault (unwrap! (get-vault vault-id) ERR_VAULT_NOT_FOUND))
      (policy (unwrap! (get-vault-insurance vault-id) ERR_NO_INSURANCE))
      (current-time stacks-block-time)
      (time-remaining (if (> (get expiry-time policy) current-time)
        (- (get expiry-time policy) current-time)
        u0))
      (total-duration (- (get expiry-time policy) (get start-time policy)))
      (refund (/ (* (get premium-paid policy) time-remaining) total-duration))
    )
    ;; Validations
    (asserts! (is-eq tx-sender (get owner vault)) ERR_NOT_AUTHORIZED)
    (asserts! (get active policy) ERR_NO_INSURANCE)
    (asserts! (> refund u0) ERR_INVALID_AMOUNT)

    ;; Transfer refund
    (unwrap! (stx-transfer? refund (var-get contract-principal) tx-sender) ERR_INSUFFICIENT_BALANCE)

    ;; Deactivate policy
    (map-set vault-insurance
      { vault-id: vault-id }
      (merge policy { active: false })
    )

    ;; Update fund balance
    (var-set insurance-fund-balance (- (var-get insurance-fund-balance) refund))

    (print {
      event: "insurance-cancelled",
      vault-id: vault-id,
      refund-amount: refund,
      timestamp: current-time
    })

    (ok refund)
  )
)

;; Admin: Set insurance parameters
(define-public (set-insurance-params (premium-rate uint) (multiplier uint) (review-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= premium-rate u10000) ERR_INVALID_AMOUNT)
    (asserts! (> multiplier u0) ERR_INVALID_AMOUNT)

    (var-set base-premium-rate premium-rate)
    (var-set coverage-multiplier multiplier)
    (var-set claim-review-period review-period)

    (print {
      event: "insurance-params-updated",
      premium-rate: premium-rate,
      multiplier: multiplier,
      review-period: review-period,
      timestamp: stacks-block-time
    })

    (ok true)
  )
)
