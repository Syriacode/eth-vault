# Week 1 Mon — ETH Vault: deposit, withdraw, events (step-by-step guide)

**Goal:** build a small Solidity vault that holds ETH for many users, emits events, and survives a real
reentrancy attack, which you'll write yourself and then use to break the vault on purpose.

**Why this project:** a vault is the simplest contract that *holds other people's money*. Every stablecoin
redemption, bridge, and exchange withdrawal flow uses the same pattern you practice here.

| Job requirement (Coinbase, Stablecoins) | Where you practice it |
|---|---|
| Smart contracts that *safeguard* funds | Steps 1, 3 |
| Security mindset, known attack classes | Steps 3, 4 |
| *Well-tested code* | Steps 2, 3 (unit, fuzz, attack tests) |
| *Uses generative AI responsibly, with human oversight* | "You check" in every step, Step 4 rewind, Step 5 write-up |

**Claude Code technique today:**
- **`@` mentions:** type `@` and a path to put a file straight into your prompt, so Claude works from exactly that file.
- **Rewind (`Esc` `Esc`):** undo Claude's edits back to any earlier prompt.

**Time:** about 75–90 minutes. Everything runs locally with play money.

---

## How to use this guide with Claude Code

Every step has the same five parts:

- **Learn:** the concept, in a few sentences. Read it before prompting.
- **Prompt:** what to type into Claude Code. Use **plan mode** (`Shift+Tab` until the status bar shows
  `⏸ plan mode on`), read the plan, then approve it.
- **You check:** what *you* verify before accepting. Don't skip it.
- **Done when:** a command whose output proves the step works.
- **Commit:** the commit message to use. Ask Claude to commit, or run it yourself.

---

## Step 0 — Create the repo and add this guide (10 min)

**Learn.** Your `/new-project` skill (Day 0) creates the public repo, scaffolds Foundry, and pushes a first
commit with green CI. It asks before creating anything.

**Do it:** in Git Bash, go to the folder where you keep your project repos (**not** inside another git repo), then:

```bash
claude
```

**Prompt:**
> /new-project Week 1 Mon – ETH Vault

When it proposes a name, accept **`eth-vault`** (or pick your own and use it everywhere below). Approve the
`gh repo create` and `git push` prompts when they appear.

When it finishes, quit Claude Code (`/exit`), then:

```bash
cd eth-vault
```

Save **this file** as `GUIDE.md` in the `eth-vault` folder. Then:

```bash
claude
```

**Prompt:**
> Delete the sample Counter files: src/Counter.sol, test/Counter.t.sol, and script/Counter.s.sol.
> Then commit GUIDE.md and the deletions together.

**You check:** `git status` is clean and `git log --oneline` shows two commits.

**Done when:** `ls src test script` shows three empty folders.

**Commit:** `Add GUIDE.md and remove sample Counter`

---

## Step 1 — The vault contract (15 min)

**Learn.**
- A **`payable`** function can receive ETH. Inside it, `msg.value` is the amount sent, in **wei** (1 ETH = 10¹⁸ wei).
- A **`mapping(address => uint256)`** is a lookup table: every address starts at 0. That's where each user's balance lives.
- **Events** are logs that off-chain services (indexers, wallets, block explorers) read. Contracts can't read them.
  Marking a parameter `indexed` makes it searchable, for example "all deposits by Alice".
- Sending ETH uses `address.call{value: amount}("")`. It **hands control to the receiver**: if the receiver is a
  contract, its code runs in the middle of your function. That is the root of **reentrancy** (Steps 3–4).
- The defense is the **Checks → Effects → Interactions** order: check inputs, update your own state, and only *then*
  call out.

**Prompt (plan mode):**
> Create src/Vault.sol (pragma ^0.8.24, MIT license) with:
> - `mapping(address => uint256) public balanceOf`
> - events `Deposited(address indexed user, uint256 amount)` and `Withdrawn(address indexed user, uint256 amount)`
> - custom errors `ZeroAmount()`, `InsufficientBalance(uint256 requested, uint256 available)`, `TransferFailed()`
> - `deposit()` payable: revert ZeroAmount if msg.value is 0, add to the sender's balance, emit Deposited
> - `withdraw(uint256 amount)`: revert ZeroAmount if 0, revert InsufficientBalance if more than the balance,
>   then update the balance, emit Withdrawn, and only then send the ETH with call; revert TransferFailed if it fails
> - `withdrawAll()`: same pattern for the whole balance (revert ZeroAmount if it's 0)
> - no receive() or fallback, so plain ETH transfers are rejected
>
> Follow checks-effects-interactions in both withdraw functions. Don't write tests yet. Run forge build and forge fmt.

**You check:**
- In **both** withdraw functions, the balance changes **before** the `.call`. Point to the exact lines.
- The `.call` result is checked (`if (!ok) revert TransferFailed();`). Ask Claude: *"What happens if I ignore the return value of call?"*
- There's no `receive()`. Ask: *"Can ETH still end up in this contract without deposit()? How?"* (Keep the answer: it's Interview Q4.)

**Done when:** `forge build` prints `Compiler run successful!`

**Commit:** `Add Vault with deposit, withdraw, withdrawAll and events`

---

## Step 2 — Unit and fuzz tests, using `@` mentions (15 min)

**Learn (Claude Code).** Type `@` in the prompt and a path menu opens. Keep typing (`@src/Va`), then press
`Tab` or `Enter` to accept the path, and `Enter` again to send. The file's contents go straight into your
message, so Claude doesn't need a separate read step, and you control exactly which file it works from.
`@test/` (a folder) adds a file listing, not contents. You can mention several files in one prompt.

**Learn (Foundry).**
- `vm.deal(addr, amount)` gives an address ETH. `vm.prank(addr)` makes the **next call** come from `addr`;
  `vm.startPrank`/`vm.stopPrank` cover several calls.
- `vm.expectRevert(...)` asserts the next call reverts with a specific error.
- `vm.expectEmit(...)` then an `emit` line asserts the next call emits exactly that event.
- A test with parameters is a **fuzz test**: Foundry runs it 256 times with random inputs. Use `bound()` to keep inputs sensible.

**Prompt (plan mode).** Type the `@` paths with the menu, don't paste them:
> Write test/Vault.t.sol for @src/Vault.sol. Use makeAddr for alice and bob and give each 10 ether with vm.deal.
> Tests:
> 1. deposit updates balanceOf and the vault's ETH balance, and emits Deposited (use vm.expectEmit)
> 2. depositing 0 reverts with ZeroAmount
> 3. withdraw sends ETH back, reduces balanceOf, and emits Withdrawn
> 4. withdrawing more than your balance reverts with InsufficientBalance(requested, available), exact arguments
> 5. bob can't withdraw alice's ETH (InsufficientBalance with available = 0)
> 6. withdrawAll sets the balance to 0 and returns all the ETH
> 7. sending ETH directly to the vault with a low-level call fails
> 8. fuzz: deposit a bounded random amount (1 wei to 10 ether), withdraw a bounded random part of it,
>    and check balanceOf, the vault's balance, and alice's balance
>
> Run forge fmt, then forge test -vv, and show me the output.

**You check:**
- In the Claude Code output, look for a tool call that reads `src/Vault.sol`. There shouldn't be one: the `@` mention already put the file in your message.
- Test 7 asserts the low-level call returns `false`. Ask: *"Why does a low-level call return false instead of reverting my test, and how does vm.expectRevert behave with low-level calls?"*
- In the fuzz test, `bound` keeps the withdraw amount ≤ the deposit. Ask: *"What would happen without bound?"*

**Done when:** `forge test -vv` ends with `8 tests passed, 0 failed`, and the fuzz line shows `runs: 256`.

**Commit:** `Add unit and fuzz tests for Vault`

---

## Step 3 — Write a reentrancy attacker (15 min)

**Learn.** In 2016, **The DAO** lost about 3.6M ETH to this bug, which led to the Ethereum/Ethereum Classic split.
The attacker's contract has a `receive()` function. When the vault sends it ETH, `receive()` calls `withdraw`
**again**, before the vault has updated the balance. Each nested call sees the old balance and pays out again,
until the vault is empty.

Your vault updates the balance first, so the nested call sees 0 and reverts. That revert bubbles up, the
outer `.call` returns `false`, the vault reverts with `TransferFailed`, and the whole attack is undone.
The test proves it.

**Prompt (plan mode):**
> Create test/Reentrancy.t.sol with two contracts:
> 1. `Attacker`: stores the Vault; `attack()` is payable, deposits msg.value, then calls withdrawAll;
>    `receive()` calls vault.withdrawAll() again whenever the vault still holds at least 1 ether.
> 2. `ReentrancyTest`: in setUp, deploy the Vault and the Attacker, and have alice deposit 10 ether.
>    `test_ReentrancyAttackFails`: call `attacker.attack{value: 1 ether}()` inside `try ... {} catch {}`,
>    then `assertEq(address(vault).balance, 10 ether, "vault was drained")` and
>    `assertEq(address(attacker).balance, 0, "attacker kept stolen ETH")`.
>
> Use try/catch rather than expectRevert so that, if the vault is ever vulnerable, the failure message shows
> how much ETH was left. Run forge fmt and forge test -vv.

**You check:** ask Claude to explain, step by step, what happens in `test_ReentrancyAttackFails` from
`attack()` down to the final assert. Make sure you can explain *why* the nested `withdrawAll` reverts.

**Done when:** `forge test -vv` ends with `9 tests passed, 0 failed`.

> ℹ️ `forge build` may print a `note[screaming-snake-case-immutable]` lint note about the attacker's
> `vault` variable. It's a naming-style note, not an error. CI still passes.

**Commit:** `Add reentrancy attack test`

Commit **now**, before Step 4. Git is your safety net while you experiment.

---

## Step 4 — Break it on purpose, then rewind (10 min)

**Learn (Claude Code).** Claude Code saves a **checkpoint** every time you send a prompt. **Rewind** returns
your files (and optionally the conversation) to the moment just before any earlier prompt.

- Open it: with the prompt box **empty**, press `Esc` twice. (If that doesn't work in your terminal, type `/rewind`.)
- Pick the prompt you want to go back to, then choose:
  - **Restore code**: undo the file edits, keep the conversation. Claude still remembers what happened.
  - **Restore conversation**: rewind the chat, keep the files as they are.
  - **Restore code and conversation**: both.
- **Limits:** it only undoes edits Claude made with its file-editing tools, not changes from shell commands
  (`rm`, `mv`, a script). It isn't a replacement for git.

**Prompt (no plan mode needed):**
> Break @src/Vault.sol on purpose: in withdrawAll only, move the ETH transfer (the call and its check) above
> `balanceOf[msg.sender] = 0` and the emit. Don't touch the tests. Then run
> `forge test --match-contract Reentrancy -vv` and explain the result.

**You check:** you should see

```text
[FAIL: vault was drained: 0 != 10000000000000000000] test_ReentrancyAttackFails()
```

The attacker took alice's 10 ETH plus its own 1 ETH back. Now see the attack yourself. Type this in the prompt
(the leading `!` runs it as a shell command):

```text
!forge test --match-test test_ReentrancyAttackFails -vvvv
```

Scroll the trace: you'll see `withdrawAll` nested inside `receive` again and again, ten levels deep.

**Now rewind:**
1. Make sure the prompt box is empty, press `Esc` `Esc`.
2. Select the prompt that starts with *"Break @src/Vault.sol on purpose"*.
3. Choose **Restore code** (you want Claude to keep the lesson in the conversation).
4. Check:

```text
!git status
```

It should say `nothing to commit, working tree clean`: the rewind put Vault.sol back exactly as you committed it.

```text
!forge test
```

`9 tests passed, 0 failed`.

**Optional (5 min): a surprising one.** Ask Claude to predict first, then try it:
> Predict, then test: if I make the same mistake in withdraw(amount) instead — send the ETH first, then
> `balanceOf[msg.sender] -= amount` — would the attack drain the vault? Write a temporary attacker for
> withdraw(1 ether) in a new test file and run it with -vvv.

You'll see `panic: arithmetic underflow or overflow (0x11)` and the vault stays full. Solidity 0.8's checked
math accidentally saves you here, but `= 0` in `withdrawAll` (or an `unchecked` block) doesn't get that
protection. That's Interview Q2. Then rewind again with **Restore code** and confirm `git status` is clean.
(If Claude deleted the temporary file with a shell command, rewind won't bring that back, which is fine here.
Run `git status` and delete any leftover file yourself.)

**Done when:** `git status` is clean and all 9 tests pass.

**Commit:** nothing. The point of this step is that there's nothing to commit.

---

## Step 5 — README, INTERVIEW.md, push, green CI (15 min)

**Prompt 1 (README):**
> Update @README.md: replace the "Design decisions" TODO with short bullets on: checks-effects-interactions,
> why call instead of transfer, custom errors, why there's no receive(), and events with indexed users.
> Replace the "Known limitations" TODO with: no reentrancy guard (only CEI), no pause, accounting relies on
> balanceOf rather than address(this).balance, and force-sent ETH gets stuck. Don't touch the
> "How I used Claude Code" section.

**Prompt 2 (INTERVIEW.md):**
> Fill in @INTERVIEW.md with these 5 questions and short model answers (5–8 sentences each), based on this code:
> 1. Walk me through checks-effects-interactions in withdrawAll. What breaks if you swap the order, and what real hack is this?
> 2. When I broke withdraw(amount) the same way, the attack failed with panic 0x11, but breaking withdrawAll drained the vault. Why? Should you rely on that?
> 3. Why use call{value:} instead of transfer() or send(), and what does that force you to do?
> 4. The vault has no receive(). Can its ETH balance still be higher than the sum of all deposits? What does that mean for accounting?
> 5. Before mainnet, what would you add for defense in depth? Cover reentrancy guards (including transient storage), cross-function and read-only reentrancy, and pausing.

**You check:** read every answer. Rewrite at least one in your own words. If an answer says something you
can't explain out loud, ask Claude about it until you can.

**Write "How I used Claude Code" yourself** in `README.md`: where `@` mentions helped, what you checked by hand,
the break-and-rewind experiment, and anything Claude got wrong.

**Done when:**

```bash
forge fmt --check && forge build && forge test -vv
```

all pass. Then commit and push (Claude will ask before `git push`):

**Commit:** `Add README design notes and interview Q&A`

Then check CI:

```text
!gh run list --branch main --limit 1
```

Wait until the newest run shows success (a ✓, or `completed` / `success`); re-run the command every
few seconds while it says `in_progress`. If it fails, open it with `!gh run view <id> --log-failed`, then ask
Claude to fix it.

---

## When you're done

Tell the roadmap chat **"done"**. It will review the repo, run the tests, and tick this row in the roadmap.

## Level up

**Commit before you experiment, then rewind to undo the experiment.** Rewind is fast and also rewinds Claude's
memory when you want it to, but it only tracks Claude's file edits. Git covers everything else. Together they
make "let's try breaking it" cheap, so you'll do it more often. And when a prompt is *about* a file, `@` it:
Claude then works from the exact file you meant instead of guessing which one.
