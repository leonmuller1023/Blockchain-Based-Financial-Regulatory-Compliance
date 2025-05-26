;; Compliance Requirements Contract
;; Records and manages regulatory obligations

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_REQUIREMENT_EXISTS (err u201))
(define-constant ERR_REQUIREMENT_NOT_FOUND (err u202))

;; Data Variables
(define-data-var next-requirement-id uint u1)

;; Data Maps
(define-map compliance-requirements
  { requirement-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    regulation-type: (string-ascii 50),
    compliance-deadline: uint,
    severity: (string-ascii 20),
    created-at: uint,
    created-by: principal
  }
)

(define-map institution-requirements
  { institution-id: uint, requirement-id: uint }
  {
    assigned-at: uint,
    status: (string-ascii 20),
    due-date: uint,
    assigned-by: principal
  }
)

;; Public Functions
(define-public (create-requirement
  (title (string-ascii 100))
  (description (string-ascii 500))
  (regulation-type (string-ascii 50))
  (compliance-deadline uint)
  (severity (string-ascii 20)))
  (let ((requirement-id (var-get next-requirement-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set compliance-requirements
      { requirement-id: requirement-id }
      {
        title: title,
        description: description,
        regulation-type: regulation-type,
        compliance-deadline: compliance-deadline,
        severity: severity,
        created-at: block-height,
        created-by: tx-sender
      }
    )

    (var-set next-requirement-id (+ requirement-id u1))
    (ok requirement-id)
  )
)

(define-public (assign-requirement-to-institution
  (institution-id uint)
  (requirement-id uint)
  (due-date uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? compliance-requirements { requirement-id: requirement-id })) ERR_REQUIREMENT_NOT_FOUND)

    (map-set institution-requirements
      { institution-id: institution-id, requirement-id: requirement-id }
      {
        assigned-at: block-height,
        status: "assigned",
        due-date: due-date,
        assigned-by: tx-sender
      }
    )
    (ok true)
  )
)

(define-public (update-requirement-status
  (institution-id uint)
  (requirement-id uint)
  (new-status (string-ascii 20)))
  (let ((assignment (unwrap! (map-get? institution-requirements { institution-id: institution-id, requirement-id: requirement-id }) ERR_REQUIREMENT_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set institution-requirements
      { institution-id: institution-id, requirement-id: requirement-id }
      (merge assignment { status: new-status })
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-requirement (requirement-id uint))
  (map-get? compliance-requirements { requirement-id: requirement-id })
)

(define-read-only (get-institution-requirement (institution-id uint) (requirement-id uint))
  (map-get? institution-requirements { institution-id: institution-id, requirement-id: requirement-id })
)

(define-read-only (get-next-requirement-id)
  (var-get next-requirement-id)
)
