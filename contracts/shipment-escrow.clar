(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-ESCROW-NOT-FOUND (err u500))
(define-constant ERR-ESCROW-ALREADY-EXISTS (err u501))
(define-constant ERR-INSUFFICIENT-DEPOSIT (err u502))
(define-constant ERR-ALREADY-RELEASED (err u503))
(define-constant ERR-UNAUTHORIZED (err u504))
(define-constant ERR-INVALID-TIER (err u505))

(define-data-var total-escrowed uint u0)
(define-data-var total-released uint u0)

(define-map escrow-deposits
  { shipment-id: uint }
  {
    buyer: principal,
    carrier: principal,
    deposit-amount: uint,
    release-conditions: { max-violations: uint, performance-tier: uint },
    deposited-at: uint,
    released: bool,
    release-block: (optional uint)
  }
)

(define-map refund-tier-config
  uint
  { violation-threshold: uint, carrier-percentage: uint, buyer-percentage: uint }
)

(define-public (configure-refund-tier (tier-id uint) (violation-threshold uint) (carrier-pct uint) (buyer-pct uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (is-eq (+ carrier-pct buyer-pct) u100) ERR-INVALID-TIER)
    (map-set refund-tier-config tier-id {
      violation-threshold: violation-threshold,
      carrier-percentage: carrier-pct,
      buyer-percentage: buyer-pct
    })
    (ok true)
  )
)

(define-public (deposit-escrow (shipment-id uint) (carrier principal) (deposit-amount uint) (max-violations uint) (performance-tier uint))
  (let (
    (existing-escrow (map-get? escrow-deposits { shipment-id: shipment-id }))
  )
    (begin
      (asserts! (is-none existing-escrow) ERR-ESCROW-ALREADY-EXISTS)
      (asserts! (> deposit-amount u0) ERR-INSUFFICIENT-DEPOSIT)
      (map-set escrow-deposits { shipment-id: shipment-id } {
        buyer: tx-sender,
        carrier: carrier,
        deposit-amount: deposit-amount,
        release-conditions: { max-violations: max-violations, performance-tier: performance-tier },
        deposited-at: stacks-block-height,
        released: false,
        release-block: none
      })
      (var-set total-escrowed (+ (var-get total-escrowed) deposit-amount))
      (ok deposit-amount)
    )
  )
)

(define-public (release-escrow (shipment-id uint) (actual-violations uint))
  (let (
    (escrow-info (unwrap! (map-get? escrow-deposits { shipment-id: shipment-id }) ERR-ESCROW-NOT-FOUND))
    (refund-amounts (calculate-refund-amount (get deposit-amount escrow-info) actual-violations (get performance-tier (get release-conditions escrow-info))))
  )
    (begin
      (asserts! (or (is-eq tx-sender (get buyer escrow-info)) (is-eq tx-sender (get carrier escrow-info))) ERR-UNAUTHORIZED)
      (asserts! (not (get released escrow-info)) ERR-ALREADY-RELEASED)
      (map-set escrow-deposits { shipment-id: shipment-id }
        (merge escrow-info { released: true, release-block: (some stacks-block-height) }))
      (var-set total-released (+ (var-get total-released) (get deposit-amount escrow-info)))
      (ok refund-amounts)
    )
  )
)

(define-private (calculate-refund-amount (deposit-amount uint) (violations uint) (tier-id uint))
  (let (
    (tier-config (default-to { violation-threshold: u999, carrier-percentage: u100, buyer-percentage: u0 }
                  (map-get? refund-tier-config tier-id)))
    (carrier-amount (/ (* deposit-amount (get carrier-percentage tier-config)) u100))
    (buyer-amount (/ (* deposit-amount (get buyer-percentage tier-config)) u100))
  )
    (if (> violations (get violation-threshold tier-config))
      { carrier-amount: u0, buyer-amount: deposit-amount }
      { carrier-amount: carrier-amount, buyer-amount: buyer-amount }
    )
  )
)

(define-read-only (get-escrow-info (shipment-id uint))
  (map-get? escrow-deposits { shipment-id: shipment-id })
)

(define-read-only (get-total-escrowed)
  (var-get total-escrowed)
)

(define-read-only (get-refund-tier (tier-id uint))
  (map-get? refund-tier-config tier-id)
)
