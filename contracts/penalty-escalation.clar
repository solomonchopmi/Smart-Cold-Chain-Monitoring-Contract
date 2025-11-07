(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-SHIPMENT-NOT-FOUND (err u400))
(define-constant ERR-INVALID-SEVERITY (err u401))
(define-constant ERR-PENALTY-ALREADY-PAID (err u402))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u403))

(define-data-var total-penalties-collected uint u0)
(define-data-var base-penalty-rate uint u100)

(define-map penalty-records
  { shipment-id: uint, violation-sequence: uint }
  { severity-level: uint, penalty-amount: uint, recorded-at: uint, paid: bool }
)

(define-map shipment-penalty-tracking
  { shipment-id: uint }
  { total-violations: uint, total-penalties: uint, last-violation-block: uint, escalation-multiplier: uint }
)

(define-map severity-config
  uint
  { base-multiplier: uint, description: (string-ascii 30) }
)

(define-public (configure-severity (severity-level uint) (base-multiplier uint) (description (string-ascii 30)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (<= severity-level u5) ERR-INVALID-SEVERITY)
    (map-set severity-config severity-level { base-multiplier: base-multiplier, description: description })
    (ok true)
  )
)

(define-public (record-violation-penalty (shipment-id uint) (severity-level uint) (stakeholder principal))
  (let (
    (tracking (default-to { total-violations: u0, total-penalties: u0, last-violation-block: u0, escalation-multiplier: u100 }
              (map-get? shipment-penalty-tracking { shipment-id: shipment-id })))
    (severity-config-data (unwrap! (map-get? severity-config severity-level) ERR-INVALID-SEVERITY))
    (blocks-since-last (if (> (get last-violation-block tracking) u0)
                           (- stacks-block-height (get last-violation-block tracking))
                           u1000))
    (escalation-factor (if (< blocks-since-last u144) (+ (get escalation-multiplier tracking) u50) u100))
    (penalty-amount (/ (* (* (var-get base-penalty-rate) (get base-multiplier severity-config-data)) escalation-factor) u10000))
  )
    (begin
      (map-set penalty-records
        { shipment-id: shipment-id, violation-sequence: (get total-violations tracking) }
        { severity-level: severity-level, penalty-amount: penalty-amount, recorded-at: stacks-block-height, paid: false }
      )
      
      (map-set shipment-penalty-tracking
        { shipment-id: shipment-id }
        { total-violations: (+ (get total-violations tracking) u1),
          total-penalties: (+ (get total-penalties tracking) penalty-amount),
          last-violation-block: stacks-block-height,
          escalation-multiplier: escalation-factor }
      )
      
      (ok penalty-amount)
    )
  )
)

(define-public (pay-penalty (shipment-id uint) (violation-sequence uint) (payment-amount uint))
  (let (
    (penalty-record (unwrap! (map-get? penalty-records { shipment-id: shipment-id, violation-sequence: violation-sequence }) ERR-SHIPMENT-NOT-FOUND))
  )
    (begin
      (asserts! (not (get paid penalty-record)) ERR-PENALTY-ALREADY-PAID)
      (asserts! (>= payment-amount (get penalty-amount penalty-record)) ERR-INSUFFICIENT-PAYMENT)
      (map-set penalty-records { shipment-id: shipment-id, violation-sequence: violation-sequence }
        (merge penalty-record { paid: true }))
      (var-set total-penalties-collected (+ (var-get total-penalties-collected) payment-amount))
      (ok payment-amount)
    )
  )
)

(define-read-only (get-penalty-record (shipment-id uint) (violation-sequence uint))
  (map-get? penalty-records { shipment-id: shipment-id, violation-sequence: violation-sequence })
)

(define-read-only (get-shipment-penalty-summary (shipment-id uint))
  (map-get? shipment-penalty-tracking { shipment-id: shipment-id })
)

(define-read-only (get-total-penalties-collected)
  (var-get total-penalties-collected)
)
