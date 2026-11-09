# eth-vault

A minimal Solidity vault for depositing and withdrawing ETH with events and reentrancy protection

Part of my [learning roadmap](https://github.com/Syriacode/Mini-Blockchain/blob/main/ROADMAP.md).

| | |
|---|---|
| Language | solidity |
| Claude Code technique practiced | `@file` mentions; **rewind** (Esc Esc) |

## Run it

```bash
forge build
forge test -vv
forge fmt --check
```

## Design decisions

- **Checks-effects-interactions.** Both `withdraw` and `withdrawAll` validate input, update `balanceOf` and emit the event before sending ETH. A re-entering call sees the already-reduced balance and reverts. `test/Reentrancy.t.sol` proves it: with the order reversed in `withdrawAll`, the attacker drains the vault.
- **`call` instead of `transfer`.** `transfer` forwards only 2300 gas, which can break smart-contract wallets (multisigs, proxies) and depends on opcode gas costs that have changed before. `call` forwards all gas, so reentrancy safety has to come from CEI rather than a gas limit. The return value is always checked (`TransferFailed`).
- **Custom errors.** `ZeroAmount`, `InsufficientBalance(requested, available)` and `TransferFailed` are cheaper than revert strings, and they carry data. Tests match the exact arguments.
- **No `receive()` or `fallback()`.** Plain ETH transfers revert, so ETH can't arrive without being credited to someone. The only way in is `deposit()`.
- **Events with `indexed` users.** `Deposited` and `Withdrawn` index the `user` so off-chain tools can filter by address (for example, "all of Alice's withdrawals"). `amount` stays unindexed in the event data.

## Known limitations

- **No reentrancy guard, only CEI.** There's no `nonReentrant` modifier as a second layer. A future change that breaks the order would be exploitable, as the deliberate break in `withdrawAll` showed.
- **No pause.** There's no owner and no emergency stop, so if a bug is found, the contract can't be halted.
- **Accounting relies on `balanceOf`, not `address(this).balance`.** The vault never reads its own ETH balance. User balances are the source of truth, and the contract's ETH balance may be higher than their sum.
- **Force-sent ETH gets stuck.** ETH can still arrive without `deposit()`, for example via `selfdestruct` or sent to the address before deployment. It isn't credited to anyone and there's no way to withdraw it.
