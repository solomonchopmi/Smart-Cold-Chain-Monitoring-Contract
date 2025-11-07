(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-INVALID-TEMPERATURE (err u102))
(define-constant ERR-SHIPMENT-NOT-FOUND (err u103))
(define-constant ERR-SHIPMENT-ALREADY-EXISTS (err u104))
(define-constant ERR-ORACLE-NOT-AUTHORIZED (err u105))
(define-constant ERR-INSURANCE-ALREADY-CLAIMED (err u106))
(define-constant ERR-SHIPMENT-ALREADY-DELIVERED (err u107))

(define-data-var next-shipment-id uint u1)

(define-map shipments
  { shipment-id: uint }
  {
    owner: principal,
    origin: (string-ascii 50),
    destination: (string-ascii 50),
    min-temp: int,
    max-temp: int,
    current-temp: int,
    created-at: uint,
    delivered-at: (optional uint),
    insurance-amount: uint,
    insurance-claimed: bool,
    violation-count: uint,
    status: (string-ascii 20)
  }
)

(define-map authorized-oracles principal bool)

(define-map temperature-readings
  { shipment-id: uint, reading-id: uint }
  {
    temperature: int,
    timestamp: uint,
    oracle: principal
  }
)

(define-map shipment-reading-count uint uint)

(define-public (authorize-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (map-set authorized-oracles oracle true)
    (ok true)
  )
)

(define-public (revoke-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (map-delete authorized-oracles oracle)
    (ok true)
  )
)

(define-public (create-shipment (origin (string-ascii 50)) (destination (string-ascii 50)) (min-temp int) (max-temp int) (insurance-amount uint))
  (let ((shipment-id (var-get next-shipment-id)))
    (begin
      (asserts! (< min-temp max-temp) ERR-INVALID-TEMPERATURE)
      (map-set shipments
        { shipment-id: shipment-id }
        {
          owner: tx-sender,
          origin: origin,
          destination: destination,
          min-temp: min-temp,
          max-temp: max-temp,
          current-temp: min-temp,
          created-at: stacks-block-height,
          delivered-at: none,
          insurance-amount: insurance-amount,
          insurance-claimed: false,
          violation-count: u0,
          status: "in-transit"
        }
      )
      (map-set shipment-reading-count shipment-id u0)
      (var-set next-shipment-id (+ shipment-id u1))
      (ok shipment-id)
    )
  )
)

(define-public (record-temperature (shipment-id uint) (temperature int))
  (let (
    (shipment (unwrap! (map-get? shipments { shipment-id: shipment-id }) ERR-SHIPMENT-NOT-FOUND))
    (reading-count (default-to u0 (map-get? shipment-reading-count shipment-id)))
    (is-violation (or (< temperature (get min-temp shipment)) (> temperature (get max-temp shipment))))
  )
    (begin
      (asserts! (default-to false (map-get? authorized-oracles tx-sender)) ERR-ORACLE-NOT-AUTHORIZED)
      (asserts! (is-eq (get status shipment) "in-transit") ERR-SHIPMENT-ALREADY-DELIVERED)
      
      (map-set temperature-readings
        { shipment-id: shipment-id, reading-id: reading-count }
        {
          temperature: temperature,
          timestamp: stacks-block-height,
          oracle: tx-sender
        }
      )
      
      (map-set shipment-reading-count shipment-id (+ reading-count u1))
      
      (map-set shipments
        { shipment-id: shipment-id }
        (merge shipment {
          current-temp: temperature,
          violation-count: (if is-violation (+ (get violation-count shipment) u1) (get violation-count shipment))
        })
      )
      
      (if is-violation
        (begin
          (try! (trigger-alert shipment-id temperature))
          (ok { violation: true, reading-id: reading-count })
        )
        (ok { violation: false, reading-id: reading-count })
      )
    )
  )
)

(define-public (deliver-shipment (shipment-id uint))
  (let ((shipment (unwrap! (map-get? shipments { shipment-id: shipment-id }) ERR-SHIPMENT-NOT-FOUND)))
    (begin
      (asserts! (is-eq tx-sender (get owner shipment)) ERR-NOT-AUTHORIZED)
      (asserts! (is-eq (get status shipment) "in-transit") ERR-SHIPMENT-ALREADY-DELIVERED)
      
      (map-set shipments
        { shipment-id: shipment-id }
        (merge shipment {
          delivered-at: (some stacks-block-height),
          status: "delivered"
        })
      )
      
      (ok true)
    )
  )
)

(define-public (claim-insurance (shipment-id uint))
  (let ((shipment (unwrap! (map-get? shipments { shipment-id: shipment-id }) ERR-SHIPMENT-NOT-FOUND)))
    (begin
      (asserts! (is-eq tx-sender (get owner shipment)) ERR-NOT-AUTHORIZED)
      (asserts! (not (get insurance-claimed shipment)) ERR-INSURANCE-ALREADY-CLAIMED)
      (asserts! (> (get violation-count shipment) u0) ERR-INVALID-TEMPERATURE)
      
      (map-set shipments
        { shipment-id: shipment-id }
        (merge shipment { insurance-claimed: true })
      )
      
      (ok (get insurance-amount shipment))
    )
  )
)

(define-private (trigger-alert (shipment-id uint) (temperature int))
  (let ((shipment (unwrap! (map-get? shipments { shipment-id: shipment-id }) ERR-SHIPMENT-NOT-FOUND)))
    (print {
      event: "temperature-violation",
      shipment-id: shipment-id,
      temperature: temperature,
      min-temp: (get min-temp shipment),
      max-temp: (get max-temp shipment),
      timestamp: stacks-block-height,
      owner: (get owner shipment)
    })
    (ok true)
  )
)

(define-read-only (get-shipment (shipment-id uint))
  (map-get? shipments { shipment-id: shipment-id })
)

(define-read-only (get-temperature-reading (shipment-id uint) (reading-id uint))
  (map-get? temperature-readings { shipment-id: shipment-id, reading-id: reading-id })
)

(define-read-only (get-shipment-reading-count (shipment-id uint))
  (default-to u0 (map-get? shipment-reading-count shipment-id))
)

(define-read-only (is-oracle-authorized (oracle principal))
  (default-to false (map-get? authorized-oracles oracle))
)

(define-read-only (get-violation-count (shipment-id uint))
  (match (map-get? shipments { shipment-id: shipment-id })
    shipment (get violation-count shipment)
    u0
  )
)

(define-read-only (is-insurance-eligible (shipment-id uint))
  (match (map-get? shipments { shipment-id: shipment-id })
    shipment (and (> (get violation-count shipment) u0) (not (get insurance-claimed shipment)))
    false
  )
)
