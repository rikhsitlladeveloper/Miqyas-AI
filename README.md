# Miqyas AI

Bluetooth laser measure + mobile app that turns a room into a plan, material list and signed quote in 15 minutes.
Built for measurers at furniture makers, stretch-ceiling and window installers, and renovation companies in Uzbekistan and Central Asia.

> O‘lcha. Chiz. Hisobla. — Measure. Draw. Quote.

## What is in this repo

| Path | What |
| --- | --- |
| `docs/functional-requirements.md` | Every function, F1–F14, with rules, release and acceptance test |
| `docs/app-spec-v1.md` | Technical spec for v1: screens, data model, Bluetooth layer, exports, stack |
| `docs/business-plan.md` | Market, model, pricing logic, scaling plan |
| `docs/suppliers.md` | Chinese OEM laser factories and outreach status |
| `docs/sync-workflow.md` | How GitHub, Notion and the design/docs stay in sync |
| `app/` | Flutter app (starts in Phase 2) |
| `CHANGELOG.md` | What changed, by date |

## Links

- Task board: Notion → *Miqyas AI — Project Plan* → *Miqyas Tasks*
- UI design: claude.ai canvas *Miqyas AI — App UI* (15 screens + web panel)
- Living docs: claude.ai docs *Miqyas AI — Functional Requirements*, *App Spec v1*

## Releases

| Release | Scope |
| --- | --- |
| v1 | One measurer, offline: laser → plan → areas → PDF/DXF → Telegram |
| v2 | Companies: accounts, sync, price list, quotes, orders, web panel, payments, voice input, material optimizer |
| v3 | AI: order check, photo/LiDAR/old-plan capture, hidden wires and pipes map |
