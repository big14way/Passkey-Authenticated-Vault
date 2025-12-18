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
    daily-reset-time: uint
  }
)

;; Map owner to their vault id
(define-map owner-vault
  { owner: principal }
  { vault-id: uint }
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
        daily-reset-time: (+ current-time u86400)
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
    
    ;; Verify passkey signature using Clarity 4 secp256r1-verify
    (asserts! (verify-passkey-signature 
                message-hash 
                signature 
                (get passkey-public-key vault)) 
              ERR_INVALID_SIGNATURE)
    
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
