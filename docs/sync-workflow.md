# How everything stays in sync

Three places, each with one job. When they disagree, GitHub wins for specs and code; Notion wins for task status.

| Place | Holds | Who edits |
| --- | --- | --- |
| GitHub `miqyas-ai` | Specs (`docs/`), code (`app/`), changelog, issues and PRs | Rick, developers |
| Notion *Miqyas AI — Project Plan* | Phases, tasks (database *Miqyas Tasks*), weekly log | Rick, team |
| claude.ai docs and canvas | Drafting space: requirements, app spec, business plan, UI design | Rick with Claude |

## The rules

1. **IDs connect everything.** Every task in Notion has a Module (F1–F14, Business, Hardware). Every GitHub issue title starts with the same ID, e.g. `F4.5 Laser to wall`. Every commit that implements it mentions the ID.
2. **Spec change → GitHub first.** Edit the doc in claude.ai if useful, then commit the updated file in `docs/` with a message like `docs: F9 add USD currency (F9.6)`. Then update the Notion task.
3. **Task becomes code → link it.** When work starts, open a GitHub issue, paste its URL into the task's *GitHub* field in Notion, set Status = In progress.
4. **Done means merged.** A code task is Done only when its PR is merged to `main`. A business task is Done when the result is real (company registered, client paid).
5. **Design changes.** Update the claude.ai canvas, then note the change in `CHANGELOG.md` with the screen number.
6. **Weekly review (Monday, 30 min).**
   - Move Notion tasks; mark blockers.
   - Write 3 lines in the Notion weekly log: done, next, blocked.
   - Add a dated entry to `CHANGELOG.md` if specs or design changed.

## Branches and commits

- `main` — always releasable. `dev` — integration. Feature branches: `f4-room-editor`, `f2-ble-a100`.
- Commit prefixes: `feat:`, `fix:`, `docs:`, `test:`, `chore:`, each with the module ID.
- Tags: `v0.1.0` (skeleton) … `v1.0.0` (Play / TestFlight release).

## Asking Claude to sync

Say "sync Miqyas" and Claude will: read the latest claude.ai docs, update `docs/` and `CHANGELOG.md` in the repo, push, and update the matching Notion tasks and weekly log.
