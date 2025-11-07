(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-INSPECTOR-NOT-AUTHORIZED (err u200))
(define-constant ERR-CERTIFICATE-EXISTS (err u201))
(define-constant ERR-INVALID-SCORE (err u202))
(define-constant ERR-SHIPMENT-NOT-FOUND (err u203))

(define-map authorized-inspectors principal bool)

(define-map quality-certificates
  { shipment-id: uint }
  {
    inspector: principal,
    certificate-type: (string-ascii 30),
    quality-score: uint,
    notes: (string-ascii 100),
    issued-at: uint,
    expiry-block: uint
  }
)

(define-map certificate-types
  (string-ascii 30)
  {
    min-score: uint,
    validity-blocks: uint,
    premium-multiplier: uint
  }
)

(define-data-var total-certificates uint u0)

(define-public (authorize-inspector (inspector principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (map-set authorized-inspectors inspector true)
    (ok true)
  )
)

(define-public (create-certificate-type (cert-type (string-ascii 30)) (min-score uint) (validity-blocks uint) (premium-multiplier uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (<= min-score u100) ERR-INVALID-SCORE)
    (map-set certificate-types cert-type {
      min-score: min-score,
      validity-blocks: validity-blocks,
      premium-multiplier: premium-multiplier
    })
    (ok true)
  )
)

(define-public (issue-certificate (shipment-id uint) (cert-type (string-ascii 30)) (quality-score uint) (notes (string-ascii 100)))
  (let (
    (cert-config (unwrap! (map-get? certificate-types cert-type) ERR-INVALID-SCORE))
    (current-cert (map-get? quality-certificates { shipment-id: shipment-id }))
  )
    (begin
      (asserts! (default-to false (map-get? authorized-inspectors tx-sender)) ERR-INSPECTOR-NOT-AUTHORIZED)
      (asserts! (is-none current-cert) ERR-CERTIFICATE-EXISTS)
      (asserts! (and (<= quality-score u100) (>= quality-score (get min-score cert-config))) ERR-INVALID-SCORE)
      
      (map-set quality-certificates
        { shipment-id: shipment-id }
        {
          inspector: tx-sender,
          certificate-type: cert-type,
          quality-score: quality-score,
          notes: notes,
          issued-at: stacks-block-height,
          expiry-block: (+ stacks-block-height (get validity-blocks cert-config))
        }
      )
      
      (var-set total-certificates (+ (var-get total-certificates) u1))
      (ok quality-score)
    )
  )
)

(define-read-only (get-certificate (shipment-id uint))
  (map-get? quality-certificates { shipment-id: shipment-id })
)

(define-read-only (is-certificate-valid (shipment-id uint))
  (match (map-get? quality-certificates { shipment-id: shipment-id })
    cert (> (get expiry-block cert) stacks-block-height)
    false
  )
)

(define-read-only (get-quality-premium (shipment-id uint))
  (match (map-get? quality-certificates { shipment-id: shipment-id })
    cert (match (map-get? certificate-types (get certificate-type cert))
      config (get premium-multiplier config)
      u100
    )
    u100
  )
)

(define-read-only (is-inspector-authorized (inspector principal))
  (default-to false (map-get? authorized-inspectors inspector))
)
