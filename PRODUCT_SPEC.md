# Product specification

Status: scope confirmed by founder on 2026-10-12. METRX is a working folder/name, not finalized branding.

## Purpose
Help builders record room dimensions, view room shells in 3D, prepare manually entered material and labor estimates, and share professional PDFs. Founder owns product decisions and building-domain validation; Claude implements. The claimed time savings and willingness to subscribe remain hypotheses to validate with other builders.

## Confirmed release scope
- Android and iPhone; Uzbek Latin, Uzbek Cyrillic, Russian, English. Report language is selectable independently of interface language.
- Projects contain floors and separate rooms. Rooms are not assembled into connected floor plans in this release.
- Room templates and sketch editor support straight/angled walls, irregular closed floor plans, doors/windows, rectangular columns/recesses, and different heights between rooms. Each room has a flat ceiling.
- Interior dimensions define the room. Wall thickness is entered separately. Openings have wall identity, width, height, offset from a defined wall start corner, and sill height where applicable.
- User selects a dimension, takes a measurement, reviews it and confirms. Manual input is always available. Distance alone never determines the wall or room shape.
- Interactive 3D shell with basic surface colors and saved report views.
- Material rows: name, unit, manually entered quantity and unit price; calculated line total. Labor rows: description and manually entered total charge. Sum material and labor subtotals into a grand total.
- Geometry calculates dimensions and areas only; changes never rewrite manual material quantities or labor charges. Report quantities are labeled as builder-entered, while dimensions/areas and monetary totals have their own provenance.
- Drafts are editable. Issuing a quote creates an immutable snapshot of geometry, views, rows, totals, currency, report language and parties. Revisions preserve older issued snapshots.
- One selected currency per project, configurable decimal precision, no exchange conversion. Freeze these values in issued snapshots.
- PDFs include builder/customer/project details, dimensioned room plans, selected 3D views, room measurements, materials, labor, totals and notes. Optional watermark logo omitted until founder supplies it.
- Offline creation, editing, storage, modeling, calculation, PDF generation and backup/restore. Cloud sync is deferred.
- Pilot has paid capabilities unlocked. Eventually subscription gates model/estimate creation and editing; expiry preserves basic measurement capture, viewing, backup and PDF export of saved work, including existing drafts. Online billing/entitlement policy is a separate pre-commercial-release task.

## Deferred
Curved walls, sloping roofs/ceilings, detailed stairs, furniture, realistic rendering, AI interior design, connected room assembly, shared price catalogs, automatic material takeoff, cloud sync, discounts, taxes and deposits.

## Implementation decisions
- Use metric geometry stored in millimeters and display suitable meters/square meters. These are initial implementation defaults, not hardware accuracy claims.
- Calculate money using decimal-safe arithmetic with explicit project precision; round each material line then sum. Persist inputs and calculated snapshot totals. Reject negative/non-finite values and invalid numeric text; allow legitimate zero-price rows.
- Use a single authoritative room model for editor, areas, 3D and report. Reject self-intersecting polygons, impossible openings and overlaps; explain corrective action rather than silently changing measurements.
- Sketch angles/vertices define irregular geometry. Side lengths alone cannot uniquely solve arbitrary polygons. Require sufficient constraints or explicit user adjustment and show unresolved dimensions.
- Atomic local writes, versioned schema and versioned backups. Restore validates the entire file before import, preserves existing data on failure and handles identifier collisions explicitly.
- Bundle translation dictionaries, fonts and renderer assets locally. Founder reviews translations, especially Uzbek scripts. No remote asset is required to open a saved project or generate a PDF.

## Hardware evidence and remaining uncertainty
Device ordered from https://mobile.yangkeduo.com/goods.html?ps=oGsobhHigU ; listing could not be retrieved. Exact purchased model/protocol and arrival date remain unverified.
Reference: https://github.com/MultiMote/fnirsi-ir40-webtool supports FNIRSI IR40 linear measurements; it is not proof of compatibility with the purchased unit.
Reference client uses BLE service 0xEE01, notify 0xEE02, write 0xEE03; a minimal 23-byte parser reads a big-endian uint16 at offset 14 and divides by 1000. Recheck upstream source and real packet captures before reuse. Preserve MIT notices if copying.
Separate manual, simulated and physical-device measurement providers. Mark simulated data visibly. Confirm actual service discovery, packet meaning, units, reference edge and disconnect behavior on arrival before claiming hardware support. Avoid unknown write commands.

## Completion
Release scope is complete only after the roadmap checks pass on physical iPhone and Android devices. The founder has an iPhone 16 Pro Max and reports access to Mac, Apple developer account and Android test equipment. Business pricing, hardware quality/returns and external pilot validation remain commercial work after the technical pilot.
