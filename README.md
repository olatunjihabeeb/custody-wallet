# CustodyWallet - Multi-Signature Custody Smart Contract

A secure multi-signature custody wallet smart contract built on the Stacks blockchain using Clarity. This contract enables institutional-grade asset custody requiring multiple custodian approvals for all transactions.

## Features

- **Multi-Signature Security**: Requires multiple custodian approvals before executing any transaction
- **Configurable Threshold**: Set the minimum number of approvals required (e.g., 2-of-3, 3-of-5)
- **Institutional Controls**: Only designated custodians can submit, approve, and execute transactions
- **STX Asset Management**: Secure deposit, withdrawal, and balance tracking for STX tokens
- **Transaction Lifecycle**: Complete workflow from submission to approval to execution
- **Audit Trail**: Full transparency with transaction history and approval tracking

## Contract Architecture

### Data Structures

- **Custodians**: Mapping of authorized principals who can manage transactions
- **Pending Transactions**: Queue of submitted transactions awaiting approval
- **Transaction Approvals**: Record of which custodians have approved each transaction
- **Configuration**: Approval threshold and custodian count management

### Security Model

1. **Role-Based Access**: Only custodians can submit/approve transactions
2. **Threshold Enforcement**: Transactions require minimum approvals before execution
3. **Double-Spend Protection**: Prevents duplicate approvals and executions
4. **Balance Validation**: Ensures sufficient funds before transaction execution

## Usage Guide

### Initial Setup

1. **Deploy Contract**
   ```clarity
   ;; Contract deployment by owner
   ```

2. **Initialize Custodians**
   ```clarity
   (contract-call? .custody-wallet initialize-custodians 
     (list 'ST1CUSTODIAN1 'ST2CUSTODIAN2 'ST3CUSTODIAN3) 
     u2) ;; 2-of-3 threshold
   ```

### Daily Operations

#### Depositing Assets
Any user can deposit STX into the custody wallet:
```clarity
(contract-call? .custody-wallet deposit u1000000) ;; 1 STX in microSTX
```

#### Submitting Withdrawal
Only custodians can submit withdrawal requests:
```clarity
(contract-call? .custody-wallet submit-transaction 
  'ST1RECIPIENT 
  u500000) ;; 0.5 STX withdrawal
```

#### Approving Transaction
Other custodians approve the pending transaction:
```clarity
(contract-call? .custody-wallet approve-transaction u0) ;; Transaction ID 0
```

#### Executing Transaction
Once threshold is met, any custodian can execute:
```clarity
(contract-call? .custody-wallet execute-transaction u0)
```

## Function Reference

### Administrative Functions

| Function | Access | Description |
|----------|--------|-------------|
| `initialize-custodians` | Owner | Set initial custodians and approval threshold |
| `add-custodian` | Owner | Add new custodian to the wallet |
| `remove-custodian` | Owner | Remove custodian from the wallet |
| `update-threshold` | Owner | Change required approval count |

### Transaction Functions

| Function | Access | Description |
|----------|--------|-------------|
| `deposit` | Anyone | Deposit STX into custody wallet |
| `submit-transaction` | Custodians | Submit withdrawal request |
| `approve-transaction` | Custodians | Approve pending transaction |
| `execute-transaction` | Custodians | Execute approved transaction |

### Query Functions

| Function | Returns | Description |
|----------|---------|-------------|
| `is-custodian` | bool | Check if address is custodian |
| `get-transaction` | Transaction data | Get transaction details |
| `get-balance` | uint | Get current wallet balance |
| `get-custodian-count` | uint | Get number of custodians |
| `get-threshold` | uint | Get approval threshold |
| `has-approved` | bool | Check if custodian approved transaction |
| `get-approvals-needed` | optional uint | Get remaining approvals needed |

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | ERR_UNAUTHORIZED | Caller not authorized for this action |
| u101 | ERR_INVALID_CUSTODIAN | Invalid or non-existent custodian |
| u102 | ERR_INSUFFICIENT_APPROVALS | Not enough approvals to execute |
| u103 | ERR_TRANSACTION_NOT_FOUND | Transaction ID does not exist |
| u104 | ERR_ALREADY_APPROVED | Custodian already approved this transaction |
| u105 | ERR_ALREADY_EXECUTED | Transaction already executed |
| u106 | ERR_INVALID_THRESHOLD | Invalid approval threshold value |
| u107 | ERR_INSUFFICIENT_BALANCE | Not enough balance for transaction |

## Example Workflow

### Setting up 3-of-5 Custody Wallet

```clarity
;; 1. Initialize with 5 custodians, requiring 3 approvals
(contract-call? .custody-wallet initialize-custodians 
  (list 'ST1BANK1 'ST2BANK2 'ST3FUND1 'ST4FUND2 'ST5EXCHANGE) 
  u3)

;; 2. Deposit initial funds
(contract-call? .custody-wallet deposit u10000000) ;; 10 STX

;; 3. Custodian 1 submits withdrawal
(contract-call? .custody-wallet submit-transaction 'ST1CLIENT u2000000)
;; Returns: (ok u0) - Transaction ID 0

;; 4. Custodian 2 approves
(contract-call? .custody-wallet approve-transaction u0)

;; 5. Custodian 3 approves (reaches threshold)
(contract-call? .custody-wallet approve-transaction u0)

;; 6. Any custodian executes
(contract-call? .custody-wallet execute-transaction u0)
;; Transfers 2 STX to ST1CLIENT
```

## Security Considerations

### Best Practices
- Use hardware wallets or secure key management for custodian keys
- Regular security audits of custodian access
- Monitor all transaction submissions and approvals
- Implement off-chain governance for threshold changes

### Risk Management
- **Key Compromise**: Remove compromised custodians immediately
- **Threshold Planning**: Ensure threshold allows operations even with unavailable custodians
- **Recovery Procedures**: Plan for custodian key recovery scenarios

## Integration Examples

### Web3 Application Integration
```javascript
// Example using Stacks.js
import { openContractCall } from '@stacks/connect';

const submitTransaction = async (recipient, amount) => {
  const functionArgs = [
    principalCV(recipient),
    uintCV(amount)
  ];
  
  await openContractCall({
    contractAddress: 'ST1234567890ABCDEF',
    contractName: 'custody-wallet',
    functionName: 'submit-transaction',
    functionArgs,
  });
};
```

### Monitoring and Analytics
- Track approval times and patterns
- Monitor custodian activity and response rates
- Set up alerts for large transactions or unusual activity
- Generate compliance reports for regulatory requirements

## Testing

### Unit Tests
- Test all function access controls
- Verify threshold enforcement
- Check error conditions and edge cases
- Validate balance calculations

### Integration Tests
- End-to-end transaction workflows
- Multi-custodian coordination scenarios
- Stress testing with multiple concurrent transactions
