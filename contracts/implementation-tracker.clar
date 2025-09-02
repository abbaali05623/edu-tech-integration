
;; title: Educational Technology Implementation Tracker
;; version: 1.0.0
;; summary: Tracks implementation progress, training completion, and performance metrics
;; description: A comprehensive system for managing technology implementation phases,
;;              monitoring performance metrics, and ensuring digital equity standards

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-NOT-FOUND (err u201))
(define-constant ERR-INVALID-STATUS (err u202))
(define-constant ERR-ALREADY-EXISTS (err u203))
(define-constant ERR-INVALID-METRIC (err u204))
(define-constant ERR-EQUITY-NOT-MET (err u205))
(define-constant ERR-INVALID-MILESTONE (err u206))

;; Implementation status constants
(define-constant IMPL-STATUS-PLANNED u1)
(define-constant IMPL-STATUS-IN-PROGRESS u2)
(define-constant IMPL-STATUS-TESTING u3)
(define-constant IMPL-STATUS-COMPLETED u4)
(define-constant IMPL-STATUS-OPTIMIZING u5)

;; Innovation status constants
(define-constant INNOVATION-PROPOSED u1)
(define-constant INNOVATION-REVIEWING u2)
(define-constant INNOVATION-APPROVED u3)
(define-constant INNOVATION-REJECTED u4)
(define-constant INNOVATION-IMPLEMENTED u5)

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Minimum equity score required for completion
(define-constant MIN-EQUITY-SCORE u75)

;; Data variables
(define-data-var implementation-counter uint u0)
(define-data-var innovation-counter uint u0)
(define-data-var total-implementations uint u0)

;; Implementation plan data structure
(define-map implementation-plans
  { plan-id: uint }
  {
    technology-assessment-id: uint,
    owner: principal,
    title: (string-ascii 100),
    description: (string-ascii 400),
    total-milestones: uint,
    completed-milestones: uint,
    status: uint,
    start-date: uint,
    target-completion: uint,
    actual-completion: (optional uint),
    budget-allocated: uint,
    budget-spent: uint,
    equity-score: uint,
    performance-score: uint,
    training-completed: bool,
    created-at: uint,
    updated-at: uint
  }
)

;; Milestone tracking
(define-map milestones
  { plan-id: uint, milestone-index: uint }
  {
    title: (string-ascii 80),
    description: (string-ascii 200),
    target-date: uint,
    completed: bool,
    completed-at: (optional uint),
    completion-notes: (optional (string-ascii 150))
  }
)

;; Performance metrics
(define-map performance-metrics
  { plan-id: uint, metric-id: uint }
  {
    metric-name: (string-ascii 50),
    value: uint,
    target-value: uint,
    measurement-date: uint,
    notes: (string-ascii 200)
  }
)

;; Innovation proposals
(define-map innovation-proposals
  { innovation-id: uint }
  {
    proposer: principal,
    related-plan-id: (optional uint),
    title: (string-ascii 100),
    description: (string-ascii 400),
    expected-impact: (string-ascii 200),
    implementation-effort: uint,
    status: uint,
    proposed-at: uint,
    reviewed-at: (optional uint),
    reviewer: (optional principal),
    review-notes: (optional (string-ascii 300))
  }
)

;; Training records
(define-map training-records
  { plan-id: uint, participant: principal }
  {
    completion-percentage: uint,
    completed-modules: uint,
    total-modules: uint,
    last-activity: uint,
    certification-earned: bool
  }
)

;; Private helper functions

;; Check if caller is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

;; Check if caller owns the implementation plan
(define-private (is-plan-owner (plan-id uint))
  (match (map-get? implementation-plans { plan-id: plan-id })
    plan-data (is-eq tx-sender (get owner plan-data))
    false
  )
)

;; Check if digital equity requirements are met
(define-private (verify-equity-requirements (equity-score uint))
  (>= equity-score MIN-EQUITY-SCORE)
)

;; Validate implementation status
(define-private (is-valid-implementation-status (status uint))
  (and (>= status IMPL-STATUS-PLANNED) (<= status IMPL-STATUS-OPTIMIZING))
)

;; Calculate overall performance score
(define-private (calculate-performance-score (plan-id uint))
  (let
    (
      (milestone-score (get-milestone-completion-score plan-id))
      (budget-score (get-budget-efficiency-score plan-id))
      (equity-score (get-plan-equity-score plan-id))
    )
    (/ (+ milestone-score budget-score equity-score) u3)
  )
)

;; Get milestone completion score for a plan
(define-private (get-milestone-completion-score (plan-id uint))
  (match (map-get? implementation-plans { plan-id: plan-id })
    plan-data
      (if (> (get total-milestones plan-data) u0)
        (/ (* (get completed-milestones plan-data) u100) (get total-milestones plan-data))
        u0
      )
    u0
  )
)

;; Get budget efficiency score
(define-private (get-budget-efficiency-score (plan-id uint))
  (match (map-get? implementation-plans { plan-id: plan-id })
    plan-data
      (let
        (
          (allocated (get budget-allocated plan-data))
          (spent (get budget-spent plan-data))
        )
        (if (> allocated u0)
          (if (<= spent allocated)
            (- u100 (/ (* (- allocated spent) u20) allocated))
            u50
          )
          u100
        )
      )
    u0
  )
)

;; Get plan equity score
(define-private (get-plan-equity-score (plan-id uint))
  (default-to u0 (get equity-score (map-get? implementation-plans { plan-id: plan-id })))
)

;; Public functions

;; Create new implementation plan
(define-public (create-implementation-plan
    (technology-assessment-id uint)
    (title (string-ascii 100))
    (description (string-ascii 400))
    (total-milestones uint)
    (target-completion uint)
    (budget-allocated uint)
    (equity-score uint))
  (let
    (
      (plan-id (+ (var-get implementation-counter) u1))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (verify-equity-requirements equity-score) ERR-EQUITY-NOT-MET)
    (asserts! (> total-milestones u0) ERR-INVALID-MILESTONE)
    (asserts! (> target-completion current-time) ERR-INVALID-METRIC)
    (asserts! (is-none (map-get? implementation-plans { plan-id: plan-id })) ERR-ALREADY-EXISTS)
    
    (map-set implementation-plans
      { plan-id: plan-id }
      {
        technology-assessment-id: technology-assessment-id,
        owner: tx-sender,
        title: title,
        description: description,
        total-milestones: total-milestones,
        completed-milestones: u0,
        status: IMPL-STATUS-PLANNED,
        start-date: current-time,
        target-completion: target-completion,
        actual-completion: none,
        budget-allocated: budget-allocated,
        budget-spent: u0,
        equity-score: equity-score,
        performance-score: u0,
        training-completed: false,
        created-at: current-time,
        updated-at: current-time
      }
    )
    
    (var-set implementation-counter plan-id)
    (var-set total-implementations (+ (var-get total-implementations) u1))
    
    (ok plan-id)
  )
)

;; Update milestone completion
(define-public (update-milestone
    (plan-id uint)
    (milestone-index uint)
    (title (string-ascii 80))
    (description (string-ascii 200))
    (target-date uint)
    (completed bool)
    (completion-notes (optional (string-ascii 150))))
  (let
    (
      (plan-data (unwrap! (map-get? implementation-plans { plan-id: plan-id }) ERR-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (or (is-plan-owner plan-id) (is-contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (<= milestone-index (get total-milestones plan-data)) ERR-INVALID-MILESTONE)
    
    ;; Update milestone record
    (map-set milestones
      { plan-id: plan-id, milestone-index: milestone-index }
      {
        title: title,
        description: description,
        target-date: target-date,
        completed: completed,
        completed-at: (if completed (some current-time) none),
        completion-notes: completion-notes
      }
    )
    
    ;; Update implementation plan milestone count if newly completed
    (if completed
      (let
        (
          (current-milestone (map-get? milestones { plan-id: plan-id, milestone-index: milestone-index }))
          (was-completed (default-to false (get completed current-milestone)))
        )
        (if (not was-completed)
          (map-set implementation-plans
            { plan-id: plan-id }
            (merge plan-data {
              completed-milestones: (+ (get completed-milestones plan-data) u1),
              updated-at: current-time,
              performance-score: (calculate-performance-score plan-id)
            })
          )
          true
        )
      )
      true
    )
    
    (ok true)
  )
)

;; Record performance metric
(define-public (record-performance-metric
    (plan-id uint)
    (metric-id uint)
    (metric-name (string-ascii 50))
    (value uint)
    (target-value uint)
    (notes (string-ascii 200)))
  (let
    (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (or (is-plan-owner plan-id) (is-contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? implementation-plans { plan-id: plan-id })) ERR-NOT-FOUND)
    
    (map-set performance-metrics
      { plan-id: plan-id, metric-id: metric-id }
      {
        metric-name: metric-name,
        value: value,
        target-value: target-value,
        measurement-date: current-time,
        notes: notes
      }
    )
    
    (ok true)
  )
)

;; Complete training for implementation
(define-public (complete-training
    (plan-id uint)
    (participant principal)
    (completion-percentage uint)
    (completed-modules uint)
    (total-modules uint)
    (certification-earned bool))
  (let
    (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (or (is-plan-owner plan-id) (is-contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? implementation-plans { plan-id: plan-id })) ERR-NOT-FOUND)
    (asserts! (<= completion-percentage u100) ERR-INVALID-METRIC)
    (asserts! (<= completed-modules total-modules) ERR-INVALID-METRIC)
    
    (map-set training-records
      { plan-id: plan-id, participant: participant }
      {
        completion-percentage: completion-percentage,
        completed-modules: completed-modules,
        total-modules: total-modules,
        last-activity: current-time,
        certification-earned: certification-earned
      }
    )
    
    ;; Update implementation plan training status if fully completed
    (if (is-eq completion-percentage u100)
      (let
        (
          (plan-data (unwrap-panic (map-get? implementation-plans { plan-id: plan-id })))
        )
        (map-set implementation-plans
          { plan-id: plan-id }
          (merge plan-data {
            training-completed: true,
            updated-at: current-time
          })
        )
      )
      true
    )
    
    (ok true)
  )
)

;; Propose innovation or improvement
(define-public (propose-innovation
    (related-plan-id (optional uint))
    (title (string-ascii 100))
    (description (string-ascii 400))
    (expected-impact (string-ascii 200))
    (implementation-effort uint))
  (let
    (
      (innovation-id (+ (var-get innovation-counter) u1))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (<= implementation-effort u100) ERR-INVALID-METRIC)
    
    (map-set innovation-proposals
      { innovation-id: innovation-id }
      {
        proposer: tx-sender,
        related-plan-id: related-plan-id,
        title: title,
        description: description,
        expected-impact: expected-impact,
        implementation-effort: implementation-effort,
        status: INNOVATION-PROPOSED,
        proposed-at: current-time,
        reviewed-at: none,
        reviewer: none,
        review-notes: none
      }
    )
    
    (var-set innovation-counter innovation-id)
    
    (ok innovation-id)
  )
)

;; Review and approve innovation
(define-public (review-innovation
    (innovation-id uint)
    (approved bool)
    (review-notes (string-ascii 300)))
  (let
    (
      (innovation-data (unwrap! (map-get? innovation-proposals { innovation-id: innovation-id }) ERR-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (new-status (if approved INNOVATION-APPROVED INNOVATION-REJECTED))
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status innovation-data) INNOVATION-PROPOSED) ERR-INVALID-STATUS)
    
    (map-set innovation-proposals
      { innovation-id: innovation-id }
      (merge innovation-data {
        status: new-status,
        reviewed-at: (some current-time),
        reviewer: (some tx-sender),
        review-notes: (some review-notes)
      })
    )
    
    (ok true)
  )
)

;; Update implementation plan status
(define-public (update-implementation-status
    (plan-id uint)
    (new-status uint))
  (let
    (
      (plan-data (unwrap! (map-get? implementation-plans { plan-id: plan-id }) ERR-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (or (is-plan-owner plan-id) (is-contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-implementation-status new-status) ERR-INVALID-STATUS)
    
    ;; Verify equity requirements for completion
    (if (is-eq new-status IMPL-STATUS-COMPLETED)
      (asserts! (verify-equity-requirements (get equity-score plan-data)) ERR-EQUITY-NOT-MET)
      true
    )
    
    (map-set implementation-plans
      { plan-id: plan-id }
      (merge plan-data {
        status: new-status,
        updated-at: current-time,
        actual-completion: (if (is-eq new-status IMPL-STATUS-COMPLETED) (some current-time) (get actual-completion plan-data))
      })
    )
    
    (ok true)
  )
)

;; Update budget spending
(define-public (update-budget-spent (plan-id uint) (amount uint))
  (let
    (
      (plan-data (unwrap! (map-get? implementation-plans { plan-id: plan-id }) ERR-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (or (is-plan-owner plan-id) (is-contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (<= amount (get budget-allocated plan-data)) ERR-INVALID-METRIC)
    
    (map-set implementation-plans
      { plan-id: plan-id }
      (merge plan-data {
        budget-spent: amount,
        updated-at: current-time,
        performance-score: (calculate-performance-score plan-id)
      })
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get implementation plan details
(define-read-only (get-implementation-plan (plan-id uint))
  (map-get? implementation-plans { plan-id: plan-id })
)

;; Get milestone details
(define-read-only (get-milestone (plan-id uint) (milestone-index uint))
  (map-get? milestones { plan-id: plan-id, milestone-index: milestone-index })
)

;; Get performance metric
(define-read-only (get-performance-metric (plan-id uint) (metric-id uint))
  (map-get? performance-metrics { plan-id: plan-id, metric-id: metric-id })
)

;; Get innovation proposal
(define-read-only (get-innovation-proposal (innovation-id uint))
  (map-get? innovation-proposals { innovation-id: innovation-id })
)

;; Get training record
(define-read-only (get-training-record (plan-id uint) (participant principal))
  (map-get? training-records { plan-id: plan-id, participant: participant })
)

;; Get total implementations
(define-read-only (get-total-implementations)
  (var-get total-implementations)
)

;; Get implementation count by status using fold
(define-read-only (get-implementation-count-by-status (target-status uint))
  (let
    (
      (result (fold count-implementations-fold (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20) { target: target-status, count: u0, max-id: (var-get implementation-counter) }))
    )
    (get count result)
  )
)

;; Helper for counting implementations by status
(define-private (count-implementations-fold (id uint) (data { target: uint, count: uint, max-id: uint }))
  (if (<= id (get max-id data))
    (match (map-get? implementation-plans { plan-id: id })
      plan-data
        (if (is-eq (get status plan-data) (get target data))
          { target: (get target data), count: (+ (get count data) u1), max-id: (get max-id data) }
          data
        )
      data
    )
    data
  )
)

;; Verify digital equity compliance for a plan
(define-read-only (verify-digital-equity (plan-id uint))
  (match (map-get? implementation-plans { plan-id: plan-id })
    plan-data (verify-equity-requirements (get equity-score plan-data))
    false
  )
)

;; Get total innovation proposals
(define-read-only (get-total-innovations)
  (var-get innovation-counter)
)
