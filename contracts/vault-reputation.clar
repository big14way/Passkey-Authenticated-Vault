;; vault-reputation.clar
;; Trust scoring and reputation system for vault owners and delegates
;; Integrates with Hiro Chainhooks for event monitoring

;; ========================================
;; Constants
;; ========================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u50001))
(define-constant ERR_INVALID_SCORE (err u50002))
(define-constant ERR_INVALID_ENDORSEMENT (err u50003))
(define-constant ERR_ENDORSEMENT_EXISTS (err u50004))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u50005))
(define-constant ERR_INVALID_DISPUTE (err u50006))
(define-constant ERR_DISPUTE_NOT_FOUND (err u50007))
(define-constant ERR_ALREADY_VOTED (err u50008))
(define-constant ERR_INVALID_BADGE (err u50009))

;; Reputation score weights
(define-constant WEIGHT_VAULT_CREATION u10)
(define-constant WEIGHT_SUCCESSFUL_DELEGATION u5)
(define-constant WEIGHT_ENDORSEMENT u15)
(define-constant WEIGHT_ACTIVE_DAYS u1)
(define-constant WEIGHT_DISPUTE_PENALTY u20)

;; Trust levels
(define-constant TRUST_LEVEL_NOVICE u0)
(define-constant TRUST_LEVEL_TRUSTED u100)
(define-constant TRUST_LEVEL_VETERAN u250)
(define-constant TRUST_LEVEL_EXPERT u500)
(define-constant TRUST_LEVEL_LEGENDARY u1000)

;; ========================================
;; Data Variables
;; ========================================

(define-data-var endorsement-counter uint u0)
(define-data-var dispute-counter uint u0)
(define-data-var badge-counter uint u0)
(define-data-var min-endorsement-reputation uint u50)

;; ========================================
;; Data Maps
;; ========================================

;; User reputation scores
(define-map user-reputation
    principal
    {
        total-score: uint,
        vault-creation-score: uint,
        delegation-score: uint,
        endorsement-score: uint,
        activity-score: uint,
        penalty-score: uint,
        trust-level: uint,
        vaults-created: uint,
        successful-delegations: uint,
        failed-delegations: uint,
        active-since: uint,
        last-updated: uint
    }
)

;; Detailed activity tracking
(define-map user-activity-stats
    principal
    {
        total-transactions: uint,
        total-volume: uint,
        active-days: uint,
        last-activity: uint,
        consecutive-days: uint,
        streak-bonus: uint
    }
)

;; Endorsements between users
(define-map endorsements
    { endorser: principal, endorsee: principal }
    {
        endorsement-id: uint,
        score: uint,
        reason: (string-utf8 256),
        endorsed-at: uint,
        revoked: bool,
        revoked-at: uint
    }
)

;; Endorsement counter per user
(define-map endorsement-counts
    principal
    {
        given: uint,
        received: uint,
        active-received: uint
    }
)

;; Reputation disputes
(define-map reputation-disputes
    uint
    {
        dispute-id: uint,
        subject: principal,
        filed-by: principal,
        reason: (string-utf8 512),
        evidence-hash: (optional (buff 32)),
        filed-at: uint,
        resolved-at: uint,
        resolution: (optional (string-utf8 256)),
        votes-support: uint,
        votes-oppose: uint,
        resolved: bool,
        penalty-applied: uint
    }
)

;; Dispute votes
(define-map dispute-votes
    { dispute-id: uint, voter: principal }
    {
        supports: bool,
        vote-weight: uint,
        voted-at: uint
    }
)

;; Achievement badges
(define-map achievement-badges
    uint
    {
        badge-id: uint,
        name: (string-ascii 64),
        description: (string-utf8 256),
        requirement-score: uint,
        requirement-type: (string-ascii 32),
        icon-uri: (string-ascii 256),
        created-at: uint
    }
)

;; User badges
(define-map user-badges
    { user: principal, badge-id: uint }
    {
        earned-at: uint,
        displayed: bool
    }
)

;; Leaderboard positions (updated periodically)
(define-map leaderboard-positions
    principal
    {
        rank: uint,
        percentile: uint,
        last-updated: uint
    }
)

;; Reputation milestones
(define-map reputation-milestones
    { user: principal, milestone-id: uint }
    {
        milestone-type: (string-ascii 32),
        value: uint,
        achieved-at: uint,
        reward-claimed: bool
    }
)

(define-data-var milestone-counter uint u0)

;; Trust circles (groups of mutually trusted users)
(define-map trust-circles
    uint
    {
        circle-id: uint,
        name: (string-ascii 64),
        creator: principal,
        members: (list 50 principal),
        min-reputation: uint,
        created-at: uint,
        active: bool
    }
)

(define-data-var circle-counter uint u0)

;; ========================================
;; Read-Only Functions
;; ========================================

;; Get user reputation
(define-read-only (get-user-reputation (user principal))
    (default-to
        {
            total-score: u0,
            vault-creation-score: u0,
            delegation-score: u0,
            endorsement-score: u0,
            activity-score: u0,
            penalty-score: u0,
            trust-level: TRUST_LEVEL_NOVICE,
            vaults-created: u0,
            successful-delegations: u0,
            failed-delegations: u0,
            active-since: u0,
            last-updated: u0
        }
        (map-get? user-reputation user)
    )
)

;; Get user activity stats
(define-read-only (get-activity-stats (user principal))
    (default-to
        {
            total-transactions: u0,
            total-volume: u0,
            active-days: u0,
            last-activity: u0,
            consecutive-days: u0,
            streak-bonus: u0
        }
        (map-get? user-activity-stats user)
    )
)

;; Calculate trust level from score
(define-read-only (calculate-trust-level (score uint))
    (if (>= score TRUST_LEVEL_LEGENDARY)
        TRUST_LEVEL_LEGENDARY
        (if (>= score TRUST_LEVEL_EXPERT)
            TRUST_LEVEL_EXPERT
            (if (>= score TRUST_LEVEL_VETERAN)
                TRUST_LEVEL_VETERAN
                (if (>= score TRUST_LEVEL_TRUSTED)
                    TRUST_LEVEL_TRUSTED
                    TRUST_LEVEL_NOVICE
                )
            )
        )
    )
)

;; Get endorsement
(define-read-only (get-endorsement (endorser principal) (endorsee principal))
    (map-get? endorsements { endorser: endorser, endorsee: endorsee })
)

;; Get endorsement counts
(define-read-only (get-endorsement-counts (user principal))
    (default-to
        { given: u0, received: u0, active-received: u0 }
        (map-get? endorsement-counts user)
    )
)

;; Get dispute
(define-read-only (get-dispute (dispute-id uint))
    (map-get? reputation-disputes dispute-id)
)

;; Get dispute vote
(define-read-only (get-dispute-vote (dispute-id uint) (voter principal))
    (map-get? dispute-votes { dispute-id: dispute-id, voter: voter })
)

;; Get achievement badge
(define-read-only (get-badge (badge-id uint))
    (map-get? achievement-badges badge-id)
)

;; Check if user has badge
(define-read-only (has-badge (user principal) (badge-id uint))
    (is-some (map-get? user-badges { user: user, badge-id: badge-id }))
)

;; Get leaderboard position
(define-read-only (get-leaderboard-position (user principal))
    (map-get? leaderboard-positions user)
)

;; Get trust circle
(define-read-only (get-trust-circle (circle-id uint))
    (map-get? trust-circles circle-id)
)

;; Check if user can endorse (has minimum reputation)
(define-read-only (can-endorse (user principal))
    (let
        (
            (rep (get-user-reputation user))
        )
        (>= (get total-score rep) (var-get min-endorsement-reputation))
    )
)

;; ========================================
;; Public Functions - Reputation Management
;; ========================================

;; Initialize user reputation
(define-public (initialize-reputation (user principal))
    (let
        (
            (existing-rep (get-user-reputation user))
        )
        ;; Only initialize if user doesn't have reputation yet
        (asserts! (is-eq (get total-score existing-rep) u0) (ok false))

        (map-set user-reputation user {
            total-score: u0,
            vault-creation-score: u0,
            delegation-score: u0,
            endorsement-score: u0,
            activity-score: u0,
            penalty-score: u0,
            trust-level: TRUST_LEVEL_NOVICE,
            vaults-created: u0,
            successful-delegations: u0,
            failed-delegations: u0,
            active-since: stacks-block-time,
            last-updated: stacks-block-time
        })

        (map-set user-activity-stats user {
            total-transactions: u0,
            total-volume: u0,
            active-days: u0,
            last-activity: u0,
            consecutive-days: u0,
            streak-bonus: u0
        })

        (print {
            event: "reputation-initialized",
            user: user,
            timestamp: stacks-block-time
        })

        (ok true)
    )
)

;; Record vault creation (increases reputation)
(define-public (record-vault-creation (user principal))
    (let
        (
            (rep (get-user-reputation user))
            (new-vault-score (+ (get vault-creation-score rep) WEIGHT_VAULT_CREATION))
            (new-total (+ (get total-score rep) WEIGHT_VAULT_CREATION))
            (new-trust-level (calculate-trust-level new-total))
        )
        ;; In production, verify caller is vault contract

        (map-set user-reputation user
            (merge rep {
                vault-creation-score: new-vault-score,
                total-score: new-total,
                trust-level: new-trust-level,
                vaults-created: (+ (get vaults-created rep) u1),
                last-updated: stacks-block-time
            })
        )

        (print {
            event: "vault-creation-recorded",
            user: user,
            new-score: new-total,
            trust-level: new-trust-level,
            vaults-created: (+ (get vaults-created rep) u1),
            timestamp: stacks-block-time
        })

        (ok new-total)
    )
)

;; Record successful delegation
(define-public (record-delegation-success (user principal))
    (let
        (
            (rep (get-user-reputation user))
            (new-delegation-score (+ (get delegation-score rep) WEIGHT_SUCCESSFUL_DELEGATION))
            (new-total (+ (get total-score rep) WEIGHT_SUCCESSFUL_DELEGATION))
            (new-trust-level (calculate-trust-level new-total))
        )
        (map-set user-reputation user
            (merge rep {
                delegation-score: new-delegation-score,
                total-score: new-total,
                trust-level: new-trust-level,
                successful-delegations: (+ (get successful-delegations rep) u1),
                last-updated: stacks-block-time
            })
        )

        (print {
            event: "delegation-success-recorded",
            user: user,
            new-score: new-total,
            trust-level: new-trust-level,
            timestamp: stacks-block-time
        })

        (ok new-total)
    )
)

;; Record failed delegation (neutral, just tracking)
(define-public (record-delegation-failure (user principal))
    (let
        (
            (rep (get-user-reputation user))
        )
        (map-set user-reputation user
            (merge rep {
                failed-delegations: (+ (get failed-delegations rep) u1),
                last-updated: stacks-block-time
            })
        )

        (print {
            event: "delegation-failure-recorded",
            user: user,
            failed-delegations: (+ (get failed-delegations rep) u1),
            timestamp: stacks-block-time
        })

        (ok true)
    )
)

;; Update activity stats
(define-public (record-activity (user principal) (volume uint))
    (let
        (
            (stats (get-activity-stats user))
            (rep (get-user-reputation user))
            (current-time stacks-block-time)
            (last-activity (get last-activity stats))
            (days-diff (if (> last-activity u0)
                (/ (- current-time last-activity) u86400)
                u0))
            (is-consecutive (and (> last-activity u0) (<= days-diff u1)))
            (new-consecutive (if is-consecutive
                (+ (get consecutive-days stats) u1)
                u1))
            (streak-bonus (if (>= new-consecutive u7) u10 u0))
            (new-activity-score (+ (get activity-score rep) WEIGHT_ACTIVE_DAYS streak-bonus))
            (new-total (+ (+ (get total-score rep) WEIGHT_ACTIVE_DAYS) streak-bonus))
        )
        (map-set user-activity-stats user {
            total-transactions: (+ (get total-transactions stats) u1),
            total-volume: (+ (get total-volume stats) volume),
            active-days: (+ (get active-days stats) u1),
            last-activity: current-time,
            consecutive-days: new-consecutive,
            streak-bonus: streak-bonus
        })

        (map-set user-reputation user
            (merge rep {
                activity-score: new-activity-score,
                total-score: new-total,
                trust-level: (calculate-trust-level new-total),
                last-updated: current-time
            })
        )

        (print {
            event: "activity-recorded",
            user: user,
            volume: volume,
            consecutive-days: new-consecutive,
            streak-bonus: streak-bonus,
            new-score: new-total,
            timestamp: current-time
        })

        (ok true)
    )
)

;; ========================================
;; Public Functions - Endorsements
;; ========================================

;; Endorse another user
(define-public (endorse-user (endorsee principal) (score uint) (reason (string-utf8 256)))
    (let
        (
            (endorser tx-sender)
            (endorser-rep (get-user-reputation endorser))
            (endorsee-rep (get-user-reputation endorsee))
            (endorsement-id (+ (var-get endorsement-counter) u1))
            (endorser-counts (get-endorsement-counts endorser))
            (endorsee-counts (get-endorsement-counts endorsee))
        )
        ;; Validate endorser has sufficient reputation
        (asserts! (can-endorse endorser) ERR_INSUFFICIENT_REPUTATION)

        ;; Validate endorsement doesn't exist
        (asserts! (is-none (get-endorsement endorser endorsee)) ERR_ENDORSEMENT_EXISTS)

        ;; Validate score
        (asserts! (and (> score u0) (<= score u10)) ERR_INVALID_SCORE)

        ;; Validate not self-endorsement
        (asserts! (not (is-eq endorser endorsee)) ERR_INVALID_ENDORSEMENT)

        ;; Calculate endorsement value based on endorser's reputation
        (let
            (
                (endorsement-value (* score (get trust-level endorser-rep)))
                (scaled-value (/ endorsement-value u100))
            )
            ;; Create endorsement
            (map-set endorsements
                { endorser: endorser, endorsee: endorsee }
                {
                    endorsement-id: endorsement-id,
                    score: score,
                    reason: reason,
                    endorsed-at: stacks-block-time,
                    revoked: false,
                    revoked-at: u0
                }
            )

            ;; Update endorsement counts
            (map-set endorsement-counts endorser
                (merge endorser-counts {
                    given: (+ (get given endorser-counts) u1)
                })
            )

            (map-set endorsement-counts endorsee
                (merge endorsee-counts {
                    received: (+ (get received endorsee-counts) u1),
                    active-received: (+ (get active-received endorsee-counts) u1)
                })
            )

            ;; Update endorsee's reputation
            (map-set user-reputation endorsee
                (merge endorsee-rep {
                    endorsement-score: (+ (get endorsement-score endorsee-rep) scaled-value),
                    total-score: (+ (get total-score endorsee-rep) scaled-value),
                    trust-level: (calculate-trust-level (+ (get total-score endorsee-rep) scaled-value)),
                    last-updated: stacks-block-time
                })
            )

            (var-set endorsement-counter endorsement-id)

            (print {
                event: "user-endorsed",
                endorsement-id: endorsement-id,
                endorser: endorser,
                endorsee: endorsee,
                score: score,
                endorsement-value: scaled-value,
                new-endorsee-score: (+ (get total-score endorsee-rep) scaled-value),
                reason: reason,
                timestamp: stacks-block-time
            })

            (ok endorsement-id)
        )
    )
)

;; Revoke endorsement
(define-public (revoke-endorsement (endorsee principal))
    (let
        (
            (endorser tx-sender)
            (endorsement (unwrap! (get-endorsement endorser endorsee) ERR_INVALID_ENDORSEMENT))
            (endorsee-rep (get-user-reputation endorsee))
            (endorsee-counts (get-endorsement-counts endorsee))
            (endorser-rep (get-user-reputation endorser))
            (endorsement-value (/ (* (get score endorsement) (get trust-level endorser-rep)) u100))
        )
        (asserts! (not (get revoked endorsement)) ERR_INVALID_ENDORSEMENT)

        ;; Update endorsement
        (map-set endorsements
            { endorser: endorser, endorsee: endorsee }
            (merge endorsement {
                revoked: true,
                revoked-at: stacks-block-time
            })
        )

        ;; Update endorsee counts
        (map-set endorsement-counts endorsee
            (merge endorsee-counts {
                active-received: (if (> (get active-received endorsee-counts) u0)
                    (- (get active-received endorsee-counts) u1)
                    u0)
            })
        )

        ;; Reduce endorsee's score
        (map-set user-reputation endorsee
            (merge endorsee-rep {
                endorsement-score: (if (>= (get endorsement-score endorsee-rep) endorsement-value)
                    (- (get endorsement-score endorsee-rep) endorsement-value)
                    u0),
                total-score: (if (>= (get total-score endorsee-rep) endorsement-value)
                    (- (get total-score endorsee-rep) endorsement-value)
                    u0),
                trust-level: (calculate-trust-level
                    (if (>= (get total-score endorsee-rep) endorsement-value)
                        (- (get total-score endorsee-rep) endorsement-value)
                        u0)),
                last-updated: stacks-block-time
            })
        )

        (print {
            event: "endorsement-revoked",
            endorser: endorser,
            endorsee: endorsee,
            endorsement-value: endorsement-value,
            timestamp: stacks-block-time
        })

        (ok true)
    )
)

;; ========================================
;; Public Functions - Disputes
;; ========================================

;; File reputation dispute
(define-public (file-dispute (subject principal) (reason (string-utf8 512)) (evidence-hash (optional (buff 32))))
    (let
        (
            (filer tx-sender)
            (dispute-id (+ (var-get dispute-counter) u1))
            (filer-rep (get-user-reputation filer))
        )
        ;; Validate filer has sufficient reputation
        (asserts! (>= (get total-score filer-rep) u50) ERR_INSUFFICIENT_REPUTATION)

        ;; Validate not self-dispute
        (asserts! (not (is-eq filer subject)) ERR_INVALID_DISPUTE)

        (map-set reputation-disputes dispute-id {
            dispute-id: dispute-id,
            subject: subject,
            filed-by: filer,
            reason: reason,
            evidence-hash: evidence-hash,
            filed-at: stacks-block-time,
            resolved-at: u0,
            resolution: none,
            votes-support: u0,
            votes-oppose: u0,
            resolved: false,
            penalty-applied: u0
        })

        (var-set dispute-counter dispute-id)

        (print {
            event: "dispute-filed",
            dispute-id: dispute-id,
            subject: subject,
            filed-by: filer,
            reason: reason,
            timestamp: stacks-block-time
        })

        (ok dispute-id)
    )
)

;; Vote on dispute
(define-public (vote-on-dispute (dispute-id uint) (supports bool))
    (let
        (
            (voter tx-sender)
            (dispute (unwrap! (get-dispute dispute-id) ERR_DISPUTE_NOT_FOUND))
            (voter-rep (get-user-reputation voter))
            (vote-weight (get trust-level voter-rep))
        )
        ;; Validate dispute not resolved
        (asserts! (not (get resolved dispute)) ERR_INVALID_DISPUTE)

        ;; Validate voter hasn't voted
        (asserts! (is-none (get-dispute-vote dispute-id voter)) ERR_ALREADY_VOTED)

        ;; Validate voter has reputation
        (asserts! (> vote-weight u0) ERR_INSUFFICIENT_REPUTATION)

        ;; Record vote
        (map-set dispute-votes
            { dispute-id: dispute-id, voter: voter }
            {
                supports: supports,
                vote-weight: vote-weight,
                voted-at: stacks-block-time
            }
        )

        ;; Update dispute votes
        (map-set reputation-disputes dispute-id
            (merge dispute {
                votes-support: (if supports
                    (+ (get votes-support dispute) vote-weight)
                    (get votes-support dispute)),
                votes-oppose: (if (not supports)
                    (+ (get votes-oppose dispute) vote-weight)
                    (get votes-oppose dispute))
            })
        )

        (print {
            event: "dispute-vote-cast",
            dispute-id: dispute-id,
            voter: voter,
            supports: supports,
            vote-weight: vote-weight,
            timestamp: stacks-block-time
        })

        (ok true)
    )
)

;; Resolve dispute (admin or DAO function)
(define-public (resolve-dispute (dispute-id uint) (resolution (string-utf8 256)) (apply-penalty uint))
    (let
        (
            (dispute (unwrap! (get-dispute dispute-id) ERR_DISPUTE_NOT_FOUND))
            (subject (get subject dispute))
            (subject-rep (get-user-reputation subject))
        )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (not (get resolved dispute)) ERR_INVALID_DISPUTE)

        ;; Update dispute
        (map-set reputation-disputes dispute-id
            (merge dispute {
                resolved: true,
                resolved-at: stacks-block-time,
                resolution: (some resolution),
                penalty-applied: apply-penalty
            })
        )

        ;; Apply penalty to subject's reputation
        (if (> apply-penalty u0)
            (map-set user-reputation subject
                (merge subject-rep {
                    penalty-score: (+ (get penalty-score subject-rep) apply-penalty),
                    total-score: (if (>= (get total-score subject-rep) apply-penalty)
                        (- (get total-score subject-rep) apply-penalty)
                        u0),
                    trust-level: (calculate-trust-level
                        (if (>= (get total-score subject-rep) apply-penalty)
                            (- (get total-score subject-rep) apply-penalty)
                            u0)),
                    last-updated: stacks-block-time
                })
            )
            true
        )

        (print {
            event: "dispute-resolved",
            dispute-id: dispute-id,
            subject: subject,
            resolution: resolution,
            penalty-applied: apply-penalty,
            new-subject-score: (if (>= (get total-score subject-rep) apply-penalty)
                (- (get total-score subject-rep) apply-penalty)
                u0),
            timestamp: stacks-block-time
        })

        (ok true)
    )
)

;; ========================================
;; Admin Functions
;; ========================================

;; Create achievement badge
(define-public (create-badge
    (name (string-ascii 64))
    (description (string-utf8 256))
    (requirement-score uint)
    (requirement-type (string-ascii 32))
    (icon-uri (string-ascii 256)))
    (let
        (
            (badge-id (+ (var-get badge-counter) u1))
        )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)

        (map-set achievement-badges badge-id {
            badge-id: badge-id,
            name: name,
            description: description,
            requirement-score: requirement-score,
            requirement-type: requirement-type,
            icon-uri: icon-uri,
            created-at: stacks-block-time
        })

        (var-set badge-counter badge-id)

        (print {
            event: "badge-created",
            badge-id: badge-id,
            name: name,
            requirement-score: requirement-score,
            timestamp: stacks-block-time
        })

        (ok badge-id)
    )
)

;; Award badge to user
(define-public (award-badge (user principal) (badge-id uint))
    (let
        (
            (badge (unwrap! (get-badge badge-id) ERR_INVALID_BADGE))
            (user-rep (get-user-reputation user))
        )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (>= (get total-score user-rep) (get requirement-score badge)) ERR_INSUFFICIENT_REPUTATION)
        (asserts! (not (has-badge user badge-id)) ERR_INVALID_BADGE)

        (map-set user-badges
            { user: user, badge-id: badge-id }
            {
                earned-at: stacks-block-time,
                displayed: true
            }
        )

        (print {
            event: "badge-awarded",
            user: user,
            badge-id: badge-id,
            badge-name: (get name badge),
            timestamp: stacks-block-time
        })

        (ok true)
    )
)
