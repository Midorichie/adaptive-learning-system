;; contracts/adaptive-learning.clar
;; Main contract for the Adaptive Learning System

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-difficulty (err u101))
(define-constant err-invalid-score (err u102))

;; Data Variables
(define-data-var minimum-passing-score uint u70)
(define-data-var difficulty-levels uint u5)

;; Data Maps
(define-map student-profiles
    principal
    {
        current-level: uint,
        total-score: uint,
        assignments-completed: uint,
        last-assessment: uint
    }
)

(define-map difficulty-thresholds
    uint  ;; level
    {
        min-score: uint,
        max-score: uint,
        multiplier: uint
    }
)

;; Public Functions
(define-public (initialize-student)
    (begin
        (asserts! (is-none (map-get? student-profiles tx-sender)) (err u103))
        (ok (map-set student-profiles tx-sender {
            current-level: u1,
            total-score: u0,
            assignments-completed: u0,
            last-assessment: u0
        }))
    )
)

(define-public (submit-assessment (score uint))
    (let (
        (student-data (unwrap! (map-get? student-profiles tx-sender) (err u104)))
        (current-level (get current-level student-data))
    )
        (asserts! (<= score u100) err-invalid-score)
        (match (adjust-difficulty score current-level)
            success (ok success)
            error (err error)
        )
    )
)

;; Private Functions
(define-private (adjust-difficulty (score uint) (current-level uint))
    (let (
        (threshold (unwrap! (map-get? difficulty-thresholds current-level) err-invalid-difficulty))
    )
        (if (>= score (get min-score threshold))
            (increase-level current-level)
            (decrease-level current-level)
        )
    )
)

(define-private (increase-level (current-level uint))
    (if (< current-level (var-get difficulty-levels))
        (ok (map-set student-profiles tx-sender 
            (merge (unwrap-panic (map-get? student-profiles tx-sender))
                { current-level: (+ current-level u1) }
            )
        ))
        (ok true)
    )
)

(define-private (decrease-level (current-level uint))
    (if (> current-level u1)
        (ok (map-set student-profiles tx-sender 
            (merge (unwrap-panic (map-get? student-profiles tx-sender))
                { current-level: (- current-level u1) }
            )
        ))
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-student-profile (student principal))
    (map-get? student-profiles student)
)

(define-read-only (get-difficulty-threshold (level uint))
    (map-get? difficulty-thresholds level)
)
