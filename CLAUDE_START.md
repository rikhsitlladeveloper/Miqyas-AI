# First prompt for Claude Code

Work in this project folder. Read PRODUCT_SPEC.md and BUILD_PLAN.md before changing code. They define the founder-approved product and the milestone acceptance checks.

Implement milestone 1 only: a complete rectangular-room workflow with manual/simulated measurements, room shell, estimates, offline persistence, quote revisions, PDF and backup/restore. The broader geometry belongs to later milestones.

First inspect the actual workspace and installed development tools. Preserve existing work. Use the technical direction in BUILD_PLAN.md, verify current official package documentation and compatible versions, and identify any concrete environment blocker. Then implement in small runnable increments; begin by proving the offline 3D rendering and report image capture route before building a large editor.

Keep geometry, decimal monetary arithmetic and immutable quote snapshots independently testable. Use the numeric fixture and behavioral acceptance checks in BUILD_PLAN.md. Bundle renderer assets/fonts and translations for offline use. Keep physical BLE behind an unimplemented adapter until the exact device is verified; simulation must be explicitly labeled. Pilot entitlements are unlocked and no payment backend is needed now.

Proceed autonomously with routine implementation choices within scope. Ask only when missing information prevents correct implementation; document other assumptions. Never claim physical-device testing, successful Bluetooth integration or visual inspection unless performed. Avoid adding automatic material quantities, cloud services, furniture, AI design or payment integration.

Finish with: working code, actual test results, exact commands to run/build on the available platforms, remaining physical-device checks and a concise list of blockers. Save these in IMPLEMENTATION_STATUS.md. If a native build cannot run in this environment, finish all independently testable work and give the precise Mac/device steps needed. Do not substitute a static screen mockup for the working workflow.
