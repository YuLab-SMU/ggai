# <Plan title>

> Status: active | completed | abandoned.
> Date opened: YYYY-MM-DD. Owner: <name>.

**Goal:** One sentence stating the outcome this plan delivers.

**Why now:** What forced the scope? Link the ADR, dev log, or TODO item that motivated this.

**Architecture:** One paragraph on the shape of the change. What is being touched, what is intentionally not being touched.

**Out of scope:** A short list. Pre-empt scope creep.

**Tech stack:** R, packages, external services.

**Verification:** How will we know this plan delivered? Concrete checks.

---

## Progress tracking

**Status legend**
- `[ ]` Not started
- `[~]` In progress
- `[x]` Completed
- `[!]` Blocked
- `[-]` Cancelled

**Plan maintenance rules**
- Update immediately after landing a task or sub-step.
- Record the verification command / observed behavior when marking `[x]`.
- If scope shifts, append a `Scope Change` note rather than silently changing completed work.

**Overall progress**
- [ ] Task 1: ...
- [ ] Task 2: ...
- [ ] Task 3: ...

---

### Task 1: <name>

**Status:** `[ ]`

**Files**
- Create: ...
- Modify: ...
- Test: ...

**Intent**
- Why this task exists; what failure mode it closes.

**Checklist**
- [ ] Step 1
- [ ] Step 2
- [ ] Step 3

**Verification**
- Command(s) to run.
- Expected observable behavior.

---

### Task 2: <name>

...

---

## Scope changes

_(append-only; never edit completed tasks above)_

- YYYY-MM-DD — what changed and why.

## Closing notes

Filled in when the plan moves to `done/`. Summary of what landed, links to the closing dev log and CHANGELOG entry.
