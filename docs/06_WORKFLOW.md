# Workflow

## Session protocol (kills context-loss failures)

1. **Start**: Claude Code opens in repo root → reads `CLAUDE.md` automatically
2. **Orient**: read `docs/STATUS.md` (current state) + relevant `docs/specs/*.md` (what to build)
3. **Plan**: if the task touches more than 2 files, use plan mode first
4. **Execute**: write code; no more than one spec section per session
5. **Test**: `lune run tests/run` must be green before done
6. **Close**: update `STATUS.md` (done / next / open questions), commit with descriptive message, **end session**

Long sessions are the enemy. The repo carries state; conversations do not.

## Commit rules

- One commit per numbered task (per PHASE0_KICKOFF.md) or per spec section implemented
- Message format: `{type}: {short description}` — type ∈ {feat, fix, chore, docs, test, refactor}
- Never commit with failing tests
- Never commit hand-edited `src/shared/Data/*`

## STATUS.md discipline

`STATUS.md` is the working memory. Update it:
- At the start of a session (mark in-progress)
- At the end of a session (mark done, set next, log open questions)
- If direction changes mid-session (log the pivot)

## Task sizing rule

A task is one spec section or smaller. Signs a task is too big:
- It touches more than 3 service files
- It adds more than one feature vertically (e.g. "add MarketService AND patent dividends" → split)
- It requires reading more than 2 spec files to understand

When in doubt: split in STATUS.md, implement the first piece, commit, start a new session.

## Open questions protocol

When an implementation question arises mid-session:
1. Write the question into STATUS.md under "Open questions"
2. Make the reasonable call and document it in `docs/04_RULINGS.md`
3. Finish the task
4. Do NOT stop to re-read design doc §§ for design decisions — that's a separate session

## claude.ai's role

Design conversations, spreadsheet edits, ruling reviews only. Never a pipe in the build loop. If a design question surfaces during implementation, log it in STATUS.md and resolve it async. Decisions flow through files, not pasted prompts.
