## Contract

The implemented MultiSigWallet contract can be found in /contracts/MultiSigWallet.sol

## Test

The implemented tests can be found in /tests/multiSignWallet.test.js

# Purpose

It’s an opportunity to prove you can build well designed and scalable backend architectures. We also want to gauge your knowledge of the Ethereum blockchain. The assessment is based on real work you’d be doing if you joined Openfort.

## The assessment

- Design and implement a secure multi-sig wallet contract:
- Define the number of signatories required to execute a transaction (e.g. 2 out of 3).
- Define the list of signatories and their addresses.
- Implement the functionality to add/remove signatures.
- Implement the functionality to execute a transaction after the required number of signatures have been obtained.
- Implement the functionality to cancel a transaction before it has been executed.

Extra points for:

- Implementing a way to recover the wallet in case of loss of private keys.
- Support for WebAuthn (FIDO2) as a second factor of authentication for signing transactions.
- Access control for actions that can be taken by signatories (e.g. add/remove signatories, execute/cancel transactions).

## Stack

Deployment in any EVM based blockchain (e.g. Ethereum, Binance Smart Chain, Polygon, etc) is fine.