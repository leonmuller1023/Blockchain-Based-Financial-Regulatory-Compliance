;; Institution Verification Contract
;; Validates and manages financial entities

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSTITUTION_EXISTS (err u101))
(define-constant ERR_INSTITUTION_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Data Variables
(define-data-var next-institution-id uint u1)

;; Data Maps
(define-map institutions
  { institution-id: uint }
  {
    name: (string-ascii 100),
    license-number: (string-ascii 50),
    institution-type: (string-ascii 30),
    status: (string-ascii 20),
    verified-at: uint,
    verifier: principal
  }
)

(define-map institution-by-license
  { license-number: (string-ascii 50) }
  { institution-id: uint }
)

;; Public Functions
(define-public (register-institution
  (name (string-ascii 100))
  (license-number (string-ascii 50))
  (institution-type (string-ascii 30)))
  (let ((institution-id (var-get next-institution-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? institution-by-license { license-number: license-number })) ERR_INSTITUTION_EXISTS)

    (map-set institutions
      { institution-id: institution-id }
      {
        name: name,
        license-number: license-number,
        institution-type: institution-type,
        status: "pending",
        verified-at: block-height,
        verifier: tx-sender
      }
    )

    (map-set institution-by-license
      { license-number: license-number }
      { institution-id: institution-id }
    )

    (var-set next-institution-id (+ institution-id u1))
    (ok institution-id)
  )
)

(define-public (verify-institution (institution-id uint))
  (let ((institution (unwrap! (map-get? institutions { institution-id: institution-id }) ERR_INSTITUTION_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set institutions
      { institution-id: institution-id }
      (merge institution { status: "verified", verified-at: block-height, verifier: tx-sender })
    )
    (ok true)
  )
)

(define-public (suspend-institution (institution-id uint))
  (let ((institution (unwrap! (map-get? institutions { institution-id: institution-id }) ERR_INSTITUTION_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set institutions
      { institution-id: institution-id }
      (merge institution { status: "suspended", verified-at: block-height, verifier: tx-sender })
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-institution (institution-id uint))
  (map-get? institutions { institution-id: institution-id })
)

(define-read-only (get-institution-by-license (license-number (string-ascii 50)))
  (match (map-get? institution-by-license { license-number: license-number })
    entry (map-get? institutions { institution-id: (get institution-id entry) })
    none
  )
)

(define-read-only (is-institution-verified (institution-id uint))
  (match (map-get? institutions { institution-id: institution-id })
    institution (is-eq (get status institution) "verified")
    false
  )
)
