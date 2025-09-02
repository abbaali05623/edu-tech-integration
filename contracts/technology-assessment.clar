
;; title: Educational Technology Assessment Contract
;; version: 1.0.0
;; summary: Manages technology evaluation and selection process for educational institutions
;; description: A comprehensive system for assessing educational technologies with equity scoring,
;;              multi-stakeholder reviews, and transparent decision tracking

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STATUS (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))
(define-constant ERR-INVALID-SCORE (err u104))
(define-constant ERR-ASSESSMENT-LOCKED (err u105))

;; Status constants
(define-constant STATUS-SUBMITTED u1)
(define-constant STATUS-UNDER-REVIEW u2)
(define-constant STATUS-APPROVED u3)
(define-constant STATUS-REJECTED u4)
(define-constant STATUS-IMPLEMENTED u5)

;; Contract owner - deployer has administrative privileges
(define-constant CONTRACT-OWNER tx-sender)

;; Data variables
(define-data-var assessment-counter uint u0)
(define-data-var total-assessments uint u0)

;; Assessment data structure
(define-map assessments
  { assessment-id: uint }
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    category: (string-ascii 50),
    cost-estimate: uint,
    equity-score: uint,
    accessibility-score: uint,
    status: uint,
    created-at: uint,
    updated-at: uint,
    total-reviews: uint,
    average-rating: uint,
    implementation-priority: uint
  }
)

;; Review data structure
(define-map reviews
  { assessment-id: uint, reviewer: principal }
  {
    rating: uint,
    accessibility-rating: uint,
    equity-impact: uint,
    implementation-feasibility: uint,
    cost-effectiveness: uint,
    comments: (string-ascii 300),
    reviewed-at: uint
  }
)

;; Authorized reviewers
(define-map authorized-reviewers
  { reviewer: principal }
  { authorized: bool, role: (string-ascii 30) }
)

;; Assessment status history for audit trail
(define-map status-history
  { assessment-id: uint, change-index: uint }
  {
    previous-status: uint,
    new-status: uint,
    changed-by: principal,
    changed-at: uint,
    reason: (string-ascii 200)
  }
)

;; Private helper functions

;; Check if caller is authorized to perform administrative actions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

;; Check if caller is authorized reviewer
(define-private (is-authorized-reviewer (reviewer principal))
  (default-to false (get authorized (map-get? authorized-reviewers { reviewer: reviewer })))
)

;; Validate assessment status
(define-private (is-valid-status (status uint))
  (and (>= status STATUS-SUBMITTED) (<= status STATUS-IMPLEMENTED))
)

;; Validate score range (1-100)
(define-private (is-valid-score (score uint))
  (and (>= score u1) (<= score u100))
)

;; Calculate equity score based on accessibility and cost factors
(define-private (calculate-equity-score (accessibility-score uint) (cost-estimate uint))
  (let
    (
      (accessibility-weight u60)
      (cost-weight u40)
      (normalized-cost (if (> cost-estimate u10000) u20 (- u100 (/ (* cost-estimate u8) u100))))
      (weighted-accessibility (/ (* accessibility-score accessibility-weight) u100))
      (weighted-cost (/ (* normalized-cost cost-weight) u100))
    )
    (+ weighted-accessibility weighted-cost)
  )
)

;; Public functions

;; Create new technology assessment
(define-public (create-assessment 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (category (string-ascii 50))
    (cost-estimate uint)
    (accessibility-score uint))
  (let
    (
      (assessment-id (+ (var-get assessment-counter) u1))
      (equity-score (calculate-equity-score accessibility-score cost-estimate))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-valid-score accessibility-score) ERR-INVALID-SCORE)
    (asserts! (is-none (map-get? assessments { assessment-id: assessment-id })) ERR-ALREADY-EXISTS)
    
    (map-set assessments
      { assessment-id: assessment-id }
      {
        proposer: tx-sender,
        title: title,
        description: description,
        category: category,
        cost-estimate: cost-estimate,
        equity-score: equity-score,
        accessibility-score: accessibility-score,
        status: STATUS-SUBMITTED,
        created-at: current-time,
        updated-at: current-time,
        total-reviews: u0,
        average-rating: u0,
        implementation-priority: u0
      }
    )
    
    (var-set assessment-counter assessment-id)
    (var-set total-assessments (+ (var-get total-assessments) u1))
    
    (ok assessment-id)
  )
)

;; Add review to assessment
(define-public (add-review
    (assessment-id uint)
    (rating uint)
    (accessibility-rating uint)
    (equity-impact uint)
    (implementation-feasibility uint)
    (cost-effectiveness uint)
    (comments (string-ascii 300)))
  (let
    (
      (assessment-data (unwrap! (map-get? assessments { assessment-id: assessment-id }) ERR-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-authorized-reviewer tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-score rating) ERR-INVALID-SCORE)
    (asserts! (is-valid-score accessibility-rating) ERR-INVALID-SCORE)
    (asserts! (is-valid-score equity-impact) ERR-INVALID-SCORE)
    (asserts! (is-valid-score implementation-feasibility) ERR-INVALID-SCORE)
    (asserts! (is-valid-score cost-effectiveness) ERR-INVALID-SCORE)
    (asserts! (is-eq (get status assessment-data) STATUS-UNDER-REVIEW) ERR-INVALID-STATUS)
    
    (map-set reviews
      { assessment-id: assessment-id, reviewer: tx-sender }
      {
        rating: rating,
        accessibility-rating: accessibility-rating,
        equity-impact: equity-impact,
        implementation-feasibility: implementation-feasibility,
        cost-effectiveness: cost-effectiveness,
        comments: comments,
        reviewed-at: current-time
      }
    )
    
    ;; Update assessment with new review count and average
    (let
      (
        (new-review-count (+ (get total-reviews assessment-data) u1))
        (current-total (+ (* (get average-rating assessment-data) (get total-reviews assessment-data)) rating))
        (new-average (/ current-total new-review-count))
      )
      (map-set assessments
        { assessment-id: assessment-id }
        (merge assessment-data {
          total-reviews: new-review-count,
          average-rating: new-average,
          updated-at: current-time
        })
      )
    )
    
    (ok true)
  )
)

;; Update assessment status
(define-public (update-assessment-status
    (assessment-id uint)
    (new-status uint)
    (reason (string-ascii 200)))
  (let
    (
      (assessment-data (unwrap! (map-get? assessments { assessment-id: assessment-id }) ERR-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (current-status (get status assessment-data))
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-status new-status) ERR-INVALID-STATUS)
    (asserts! (not (is-eq current-status new-status)) ERR-INVALID-STATUS)
    
    ;; Record status change in history
    (map-set status-history
      { assessment-id: assessment-id, change-index: (get total-reviews assessment-data) }
      {
        previous-status: current-status,
        new-status: new-status,
        changed-by: tx-sender,
        changed-at: current-time,
        reason: reason
      }
    )
    
    ;; Update assessment status
    (map-set assessments
      { assessment-id: assessment-id }
      (merge assessment-data {
        status: new-status,
        updated-at: current-time
      })
    )
    
    (ok true)
  )
)

;; Authorize new reviewer
(define-public (authorize-reviewer (reviewer principal) (role (string-ascii 30)))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (map-set authorized-reviewers
      { reviewer: reviewer }
      { authorized: true, role: role }
    )
    (ok true)
  )
)

;; Revoke reviewer authorization
(define-public (revoke-reviewer (reviewer principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (map-delete authorized-reviewers { reviewer: reviewer })
    (ok true)
  )
)

;; Read-only functions

;; Get assessment details
(define-read-only (get-assessment (assessment-id uint))
  (map-get? assessments { assessment-id: assessment-id })
)

;; Get review details
(define-read-only (get-review (assessment-id uint) (reviewer principal))
  (map-get? reviews { assessment-id: assessment-id, reviewer: reviewer })
)

;; Get assessment status history
(define-read-only (get-status-history (assessment-id uint) (change-index uint))
  (map-get? status-history { assessment-id: assessment-id, change-index: change-index })
)

;; Check if reviewer is authorized
(define-read-only (check-reviewer-authorization (reviewer principal))
  (is-authorized-reviewer reviewer)
)

;; Get total number of assessments
(define-read-only (get-total-assessments)
  (var-get total-assessments)
)

;; Get assessment status count for specific status
(define-read-only (get-status-count (target-status uint))
  (let
    (
      (total (var-get assessment-counter))
    )
    (fold count-assessments-with-status (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20) { target: target-status, count: u0, max-id: total })
  )
)

;; Helper for counting assessments by status
(define-private (count-assessments-with-status (id uint) (data { target: uint, count: uint, max-id: uint }))
  (if (<= id (get max-id data))
    (match (map-get? assessments { assessment-id: id })
      assessment-data
        (if (is-eq (get status assessment-data) (get target data))
          { target: (get target data), count: (+ (get count data) u1), max-id: (get max-id data) }
          data
        )
      data
    )
    data
  )
)

;; Calculate average equity score for approved assessments
(define-read-only (get-average-equity-score)
  (let
    (
      (result (fold calculate-equity-average (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20) { total-score: u0, count: u0, max-id: (var-get assessment-counter) }))
    )
    (if (> (get count result) u0) (/ (get total-score result) (get count result)) u0)
  )
)

;; Helper for calculating average equity score
(define-private (calculate-equity-average (id uint) (data { total-score: uint, count: uint, max-id: uint }))
  (if (<= id (get max-id data))
    (match (map-get? assessments { assessment-id: id })
      assessment-data
        (if (is-eq (get status assessment-data) STATUS-APPROVED)
          { 
            total-score: (+ (get total-score data) (get equity-score assessment-data)), 
            count: (+ (get count data) u1), 
            max-id: (get max-id data) 
          }
          data
        )
      data
    )
    data
  )
)
