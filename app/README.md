# app/

Flutter app goes here (Phase 2). Structure and rules: `../docs/app-spec-v1.md` §7.

```
lib/
  domain/    pure Dart: models, RoomGeometry, DXF/JSON writers (unit-tested)
  data/      drift database, repositories, settings
  ble/       LaserDevice interface, drivers (fake, zhenbing_a100), scanner
  features/  projects, project, room_editor, room_summary, device, export, settings
  export/    PDF/PNG renderers, share helper
```
