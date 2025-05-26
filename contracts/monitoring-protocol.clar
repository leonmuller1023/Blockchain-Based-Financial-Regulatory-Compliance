;; Monitoring Protocol Contract
;; Tracks compliance activities and submissions

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_ACTIVITY_NOT_FOUND (err u301))
(define-constant ERR_INVALID_SCORE (err u302))

;; Data Variables
(define-data-var next-activity-id uint u1)

;; Data Maps
(define-map compliance-activities
  { activity-id: uint }
  {
    institution-id: uint,
    requirement-id: uint,
    activity-type: (string-ascii 50),
    description: (string-ascii 300),
    submission-hash: (string-ascii 64),
    compliance-score: uint,
    submitted-at: uint,
    reviewed-at: (optional uint),
    reviewer: (optional principal)
  }
)

(define-map institution-compliance-scores
  { institution-id: uint }
  {
    total-score: uint,
    activities-count: uint,
    last-updated: uint
  }
)

;; Public Functions
(define-public (submit-compliance-activity
  (institution-id uint)
  (requirement-id uint)
  (activity-type (string-ascii 50))
  (description (string-ascii 300))
  (submission-hash (string-ascii 64)))
  (let ((activity-id (var-get next-activity-id)))
    (map-set compliance-activities
      { activity-id: activity-id }
      {
        institution-id: institution-id,
        requirement-id: requirement-id,
        activity-type: activity-type,
        description: description,
        submission-hash: submission-hash,
        compliance-score: u0,
        submitted-at: block-height,
        reviewed-at: none,
        reviewer: none
      }
    )

    (var-set next-activity-id (+ activity-id u1))
    (ok activity-id)
  )
)

(define-public (review-compliance-activity
  (activity-id uint)
  (compliance-score uint))
  (let ((activity (unwrap! (map-get? compliance-activities { activity-id: activity-id }) ERR_ACTIVITY_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= compliance-score u100) ERR_INVALID_SCORE)

    (map-set compliance-activities
      { activity-id: activity-id }
      (merge activity {
        compliance-score: compliance-score,
        reviewed-at: (some block-height),
        reviewer: (some tx-sender)
      })
    )

    ;; Update institution compliance score
    (update-institution-score (get institution-id activity) compliance-score)
    (ok true)
  )
)

;; Private Functions
(define-private (update-institution-score (institution-id uint) (new-score uint))
  (let ((current-scores (default-to { total-score: u0, activities-count: u0, last-updated: u0 }
                                   (map-get? institution-compliance-scores { institution-id: institution-id }))))
    (map-set institution-compliance-scores
      { institution-id: institution-id }
      {
        total-score: (+ (get total-score current-scores) new-score),
        activities-count: (+ (get activities-count current-scores) u1),
        last-updated: block-height
      }
    )
  )
)

;; Read-only Functions
(define-read-only (get-compliance-activity (activity-id uint))
  (map-get? compliance-activities { activity-id: activity-id })
)

(define-read-only (get-institution-compliance-score (institution-id uint))
  (map-get? institution-compliance-scores { institution-id: institution-id })
)

(define-read-only (calculate-average-score (institution-id uint))
  (match (map-get? institution-compliance-scores { institution-id: institution-id })
    scores (if (> (get activities-count scores) u0)
             (some (/ (get total-score scores) (get activities-count scores)))
             (some u0))
    none
  )
)
