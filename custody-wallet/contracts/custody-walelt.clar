;; CustodyWallet - Multi-signature custody wallet for institutional assets
;; Requires multiple custodian approvals for transactions

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_CUSTODIAN (err u101))
(define-constant ERR_INSUFFICIENT_APPROVALS (err u102))
(define-constant ERR_TRANSACTION_NOT_FOUND (err u103))
(define-constant ERR_ALREADY_APPROVED (err u104))
(define-constant ERR_ALREADY_EXECUTED (err u105))
(define-constant ERR_INVALID_THRESHOLD (err u106))
(define-constant ERR_INSUFFICIENT_BALANCE (err u107))

;; Data structures
(define-map custodians principal bool)
(define-map transaction-approvals 
  { tx-id: uint, custodian: principal } 
  bool)

(define-data-var custodian-count uint u0)
(define-data-var approval-threshold uint u2)
(define-data-var next-tx-id uint u0)

;; Transaction structure
(define-map pending-transactions uint {
  recipient: principal,
  amount: uint,
  approvals: uint,
  executed: bool,
  created-at: uint
})

;; Events
(define-data-var contract-balance uint u0)

;; Initialize contract with initial custodians
(define-public (initialize-custodians (initial-custodians (list 10 principal)) (threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (and (> threshold u0) (<= threshold (len initial-custodians))) ERR_INVALID_THRESHOLD)
    (var-set approval-threshold threshold)
    (fold add-custodian-helper initial-custodians true)
    (ok true)))

(define-private (add-custodian-helper (custodian principal) (prev-result bool))
  (begin
    (map-set custodians custodian true)
    (var-set custodian-count (+ (var-get custodian-count) u1))
    prev-result))

;; Add a new custodian (only contract owner)
(define-public (add-custodian (new-custodian principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? custodians new-custodian)) ERR_INVALID_CUSTODIAN)
    (map-set custodians new-custodian true)
    (var-set custodian-count (+ (var-get custodian-count) u1))
    (ok true)))

;; Remove a custodian (only contract owner)
(define-public (remove-custodian (custodian principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (default-to false (map-get? custodians custodian)) ERR_INVALID_CUSTODIAN)
    (map-delete custodians custodian)
    (var-set custodian-count (- (var-get custodian-count) u1))
    (ok true)))

;; Update approval threshold (only contract owner)
(define-public (update-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (and (> new-threshold u0) (<= new-threshold (var-get custodian-count))) ERR_INVALID_THRESHOLD)
    (var-set approval-threshold new-threshold)
    (ok true)))

;; Deposit STX to the custody wallet
(define-public (deposit (amount uint))
  (let ((current-balance (var-get contract-balance)))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set contract-balance (+ current-balance amount))
    (ok amount)))

;; Submit a withdrawal transaction (only custodians)
(define-public (submit-transaction (recipient principal) (amount uint))
  (let ((tx-id (var-get next-tx-id)))
    (begin
      (asserts! (default-to false (map-get? custodians tx-sender)) ERR_UNAUTHORIZED)
      (asserts! (<= amount (var-get contract-balance)) ERR_INSUFFICIENT_BALANCE)
      
      (map-set pending-transactions tx-id {
        recipient: recipient,
        amount: amount,
        approvals: u1,
        executed: false,
        created-at: block-height
      })
      
      (map-set transaction-approvals { tx-id: tx-id, custodian: tx-sender } true)
      (var-set next-tx-id (+ tx-id u1))
      (ok tx-id))))

;; Approve a pending transaction (only custodians)
(define-public (approve-transaction (tx-id uint))
  (let ((tx-data (unwrap! (map-get? pending-transactions tx-id) ERR_TRANSACTION_NOT_FOUND)))
    (begin
      (asserts! (default-to false (map-get? custodians tx-sender)) ERR_UNAUTHORIZED)
      (asserts! (not (get executed tx-data)) ERR_ALREADY_EXECUTED)
      (asserts! (is-none (map-get? transaction-approvals { tx-id: tx-id, custodian: tx-sender })) ERR_ALREADY_APPROVED)
      
      (map-set transaction-approvals { tx-id: tx-id, custodian: tx-sender } true)
      (map-set pending-transactions tx-id 
        (merge tx-data { approvals: (+ (get approvals tx-data) u1) }))
      
      (ok true))))

;; Execute approved transaction
(define-public (execute-transaction (tx-id uint))
  (let ((tx-data (unwrap! (map-get? pending-transactions tx-id) ERR_TRANSACTION_NOT_FOUND)))
    (begin
      (asserts! (default-to false (map-get? custodians tx-sender)) ERR_UNAUTHORIZED)
      (asserts! (not (get executed tx-data)) ERR_ALREADY_EXECUTED)
      (asserts! (>= (get approvals tx-data) (var-get approval-threshold)) ERR_INSUFFICIENT_APPROVALS)
      (asserts! (<= (get amount tx-data) (var-get contract-balance)) ERR_INSUFFICIENT_BALANCE)
      
      (try! (as-contract (stx-transfer? (get amount tx-data) tx-sender (get recipient tx-data))))
      (var-set contract-balance (- (var-get contract-balance) (get amount tx-data)))
      
      (map-set pending-transactions tx-id 
        (merge tx-data { executed: true }))
      
      (ok (get amount tx-data)))))

;; Read-only functions

;; Check if address is custodian
(define-read-only (is-custodian (address principal))
  (default-to false (map-get? custodians address)))

;; Get transaction details
(define-read-only (get-transaction (tx-id uint))
  (map-get? pending-transactions tx-id))

;; Get contract balance
(define-read-only (get-balance)
  (var-get contract-balance))

;; Get custodian count
(define-read-only (get-custodian-count)
  (var-get custodian-count))

;; Get approval threshold
(define-read-only (get-threshold)
  (var-get approval-threshold))

;; Get next transaction ID
(define-read-only (get-next-tx-id)
  (var-get next-tx-id))

;; Check if custodian has approved transaction
(define-read-only (has-approved (tx-id uint) (custodian principal))
  (default-to false (map-get? transaction-approvals { tx-id: tx-id, custodian: custodian })))

;; Get required approvals remaining for transaction
(define-read-only (get-approvals-needed (tx-id uint))
  (match (map-get? pending-transactions tx-id)
    tx-data (let ((current-approvals (get approvals tx-data))
                  (threshold (var-get approval-threshold)))
              (if (>= current-approvals threshold)
                (some u0)
                (some (- threshold current-approvals))))
    none))