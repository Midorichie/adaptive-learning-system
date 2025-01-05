;; contracts/adaptive-learning.clar

;; Constants and Error Codes
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-difficulty (err u101))
(define-constant err-invalid-score (err u102))
(define-constant err-student-exists (err u103))
(define-constant err-student-not-found (err u104))
(define-constant err-invalid-subject (err u105))
(define-constant err-cooldown-period (err u106))
(define-constant err-invalid-subject-id (err u108))
(define-constant err-invalid-max-level (err u109))
(define-constant err-subject-exists (err u110))
(define-constant err-invalid-name (err u111))
(define-constant assessment-cooldown-blocks u10)

;; Constants for input validation
(define-constant max-subject-id u100)
(define-constant min-max-level u1)
(define-constant max-max-level u50)
(define-constant min-name-length u1)
(define-constant max-name-length u64)

;; Data Variables
(define-data-var minimum-passing-score uint u70)
(define-data-var difficulty-levels uint u5)
(define-data-var paused bool false)

;; Enhanced Data Maps
(define-map student-profiles
    principal
    {
        current-level: uint,
        total-score: uint,
        assignments-completed: uint,
        last-assessment-block: uint,
        subjects: (list 10 uint),
        achievements: (list 10 uint)
    }
)

(define-map difficulty-thresholds
    uint
    {
        min-score: uint,
        max-score: uint,
        multiplier: uint,
        required-achievements: uint
    }
)

(define-map subject-metadata
    uint
    {
        name: (string-ascii 64),
        max-level: uint,
        active: bool
    }
)

;; Private helper functions for validation
(define-private (is-valid-name (name (string-ascii 64)))
    (let (
        (name-length (len name))
    )
        (and
            (>= name-length min-name-length)
            (<= name-length max-name-length)
            ;; Check if first character is not a space
            (not (is-eq (unwrap-panic (element-at name u0)) " "))
        )
    )
)

;; Administrative Functions
(define-public (set-paused (new-paused bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set paused new-paused))
    )
)

(define-public (add-subject (subject-id uint) (name (string-ascii 64)) (max-level uint))
    (begin
        ;; Check authorization
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        ;; Validate subject-id
        (asserts! (<= subject-id max-subject-id) err-invalid-subject-id)
        (asserts! (is-none (map-get? subject-metadata subject-id)) err-subject-exists)
        
        ;; Validate name
        (asserts! (is-valid-name name) err-invalid-name)
        
        ;; Validate max-level
        (asserts! (and 
            (>= max-level min-max-level)
            (<= max-level max-max-level)
        ) err-invalid-max-level)
        
        ;; After all validation passes, proceed with setting the data
        (ok (map-set subject-metadata subject-id {
            name: name,
            max-level: max-level,
            active: true
        }))
    )
)

;; Enhanced Public Functions
(define-public (initialize-student)
    (begin
        (asserts! (not (var-get paused)) (err u107))
        (asserts! (is-none (map-get? student-profiles tx-sender)) err-student-exists)
        (ok (map-set student-profiles tx-sender {
            current-level: u1,
            total-score: u0,
            assignments-completed: u0,
            last-assessment-block: block-height,
            subjects: (list u0 u0 u0 u0 u0 u0 u0 u0 u0 u0),
            achievements: (list u0 u0 u0 u0 u0 u0 u0 u0 u0 u0)
        }))
    )
)

(define-public (submit-assessment (subject-id uint) (score uint))
    (let (
        (student-data (unwrap! (map-get? student-profiles tx-sender) err-student-not-found))
        (current-level (get current-level student-data))
        (last-assessment-block (get last-assessment-block student-data))
        (subject (unwrap! (map-get? subject-metadata subject-id) err-invalid-subject))
    )
        (asserts! (not (var-get paused)) (err u107))
        (asserts! (<= score u100) err-invalid-score)
        (asserts! (get active subject) err-invalid-subject)
        (asserts! (> block-height (+ last-assessment-block assessment-cooldown-blocks)) err-cooldown-period)
        
        (match (adjust-difficulty score current-level)
            success (ok (update-achievements tx-sender score))
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
                { 
                    current-level: (+ current-level u1),
                    assignments-completed: (+ (get assignments-completed (unwrap-panic (map-get? student-profiles tx-sender))) u1),
                    last-assessment-block: block-height
                }
            )
        ))
        (ok true)
    )
)

(define-private (decrease-level (current-level uint))
    (if (> current-level u1)
        (ok (map-set student-profiles tx-sender 
            (merge (unwrap-panic (map-get? student-profiles tx-sender))
                { 
                    current-level: (- current-level u1),
                    assignments-completed: (+ (get assignments-completed (unwrap-panic (map-get? student-profiles tx-sender))) u1),
                    last-assessment-block: block-height
                }
            )
        ))
        (ok true)
    )
)

(define-private (update-achievements (student principal) (score uint))
    (let (
        (profile (unwrap-panic (map-get? student-profiles student)))
        (current-achievements (get achievements profile))
    )
        (if (and (>= score u90) (is-eq (len current-achievements) u0))
            (map-set student-profiles student
                (merge profile { achievements: (unwrap-panic (as-max-len? (append current-achievements u1) u10)) })
            )
            true
        )
    )
)

;; Read-only Functions
(define-read-only (get-student-profile (student principal))
    (map-get? student-profiles student)
)

(define-read-only (get-difficulty-threshold (level uint))
    (map-get? difficulty-thresholds level)
)

(define-read-only (get-subject (subject-id uint))
    (map-get? subject-metadata subject-id)
)

(define-read-only (get-contract-state)
    (ok {
        paused: (var-get paused),
        minimum-passing-score: (var-get minimum-passing-score),
        difficulty-levels: (var-get difficulty-levels)
    })
)
