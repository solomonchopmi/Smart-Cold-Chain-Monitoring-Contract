(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-INSUFFICIENT-DEPOSIT (err u300))
(define-constant ERR-SHIPMENT-NOT-FOUND (err u301))
(define-constant ERR-MILESTONE-NOT-FOUND (err u302))
(define-constant ERR-REWARD-ALREADY-CLAIMED (err u303))
(define-constant ERR-INSUFFICIENT-BALANCE (err u304))

(define-data-var reward-pool-balance uint u0)
(define-data-var total-milestones-achieved uint u0)

(define-map shipment-deposits
  { shipment-id: uint }
  { deposit-amount: uint, milestones-achieved: uint, rewards-claimed: bool }
)

(define-map milestone-config
  (string-ascii 20)
  { reward-percentage: uint, required-readings: uint }
)

(define-map stakeholder-performance
  principal
  { total-rewards: uint, milestones-completed: uint, perfect-streaks: uint }
)

(define-map milestone-achievements
  { shipment-id: uint, milestone-type: (string-ascii 20) }
  { achiever: principal, reward-amount: uint, achieved-at: uint }
)

(define-public (configure-milestone (milestone-type (string-ascii 20)) (reward-percentage uint) (required-readings uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (<= reward-percentage u100) ERR-INSUFFICIENT-DEPOSIT)
    (map-set milestone-config milestone-type {
      reward-percentage: reward-percentage,
      required-readings: required-readings
    })
    (ok true)
  )
)

(define-public (create-reward-deposit (shipment-id uint) (deposit-amount uint))
  (begin
    (asserts! (> deposit-amount u1000) ERR-INSUFFICIENT-DEPOSIT)
    (map-set shipment-deposits { shipment-id: shipment-id } {
      deposit-amount: deposit-amount,
      milestones-achieved: u0,
      rewards-claimed: false
    })
    (var-set reward-pool-balance (+ (var-get reward-pool-balance) deposit-amount))
    (ok deposit-amount)
  )
)

(define-public (achieve-milestone (shipment-id uint) (milestone-type (string-ascii 20)) (stakeholder principal))
  (let (
    (deposit-info (unwrap! (map-get? shipment-deposits { shipment-id: shipment-id }) ERR-SHIPMENT-NOT-FOUND))
    (milestone-info (unwrap! (map-get? milestone-config milestone-type) ERR-MILESTONE-NOT-FOUND))
    (reward-amount (/ (* (get deposit-amount deposit-info) (get reward-percentage milestone-info)) u100))
    (stakeholder-stats (default-to { total-rewards: u0, milestones-completed: u0, perfect-streaks: u0 }
                       (map-get? stakeholder-performance stakeholder)))
  )
    (begin
      (asserts! (<= reward-amount (var-get reward-pool-balance)) ERR-INSUFFICIENT-BALANCE)
      
      (map-set milestone-achievements
        { shipment-id: shipment-id, milestone-type: milestone-type }
        { achiever: stakeholder, reward-amount: reward-amount, achieved-at: stacks-block-height }
      )
      
      (map-set shipment-deposits
        { shipment-id: shipment-id }
        (merge deposit-info { milestones-achieved: (+ (get milestones-achieved deposit-info) u1) })
      )
      
      (map-set stakeholder-performance stakeholder {
        total-rewards: (+ (get total-rewards stakeholder-stats) reward-amount),
        milestones-completed: (+ (get milestones-completed stakeholder-stats) u1),
        perfect-streaks: (+ (get perfect-streaks stakeholder-stats) u1)
      })
      
      (var-set reward-pool-balance (- (var-get reward-pool-balance) reward-amount))
      (var-set total-milestones-achieved (+ (var-get total-milestones-achieved) u1))
      
      (print {
        event: "milestone-achieved",
        shipment-id: shipment-id,
        milestone-type: milestone-type,
        stakeholder: stakeholder,
        reward-amount: reward-amount
      })
      
      (ok reward-amount)
    )
  )
)

(define-read-only (get-stakeholder-performance (stakeholder principal))
  (default-to { total-rewards: u0, milestones-completed: u0, perfect-streaks: u0 }
              (map-get? stakeholder-performance stakeholder))
)

(define-read-only (get-milestone-achievement (shipment-id uint) (milestone-type (string-ascii 20)))
  (map-get? milestone-achievements { shipment-id: shipment-id, milestone-type: milestone-type })
)

(define-read-only (get-reward-pool-balance)
  (var-get reward-pool-balance)
)

(define-read-only (get-shipment-deposit-info (shipment-id uint))
  (map-get? shipment-deposits { shipment-id: shipment-id })
)
