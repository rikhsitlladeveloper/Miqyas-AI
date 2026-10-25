# Textures for the lit furniture 3D

All downloaded pictures are **CC0 1.0 (public domain)**, from ambientCG and Poly Haven (the printed skinali is our own drawing). Downloaded on 25 Oct 2026 at
1K, colour map only. Each was colour-graded toward the mockup's decor colour (`modern-3d.html`, `WOOD` / `STONE`),
resized to 512 px (`512/`, strong phones) and 256 px (`256/`, weak phones) and saved as WebP. Fabrics are grey and
take their colour in the app (`Look.tint`).

| File (`512/`, `256/`) | Used as | Source | Author | Licence | Metres per repeat |
|---|---|---|---|---|---|
| `oak_halifax.webp` | Light natural oak, Halifax-like (rustic, knots) | Poly Haven `oak_wood_planks` — https://polyhaven.com/a/oak_wood_planks | Dimitrios Savva | CC0 | 1.2 |
| `oak_craft.webp` | Golden oak, Craft-like | Poly Haven `teak_veneer` — https://polyhaven.com/a/teak_veneer | Jenelle van Heerden | CC0 | 1.0 |
| `walnut.webp` | Walnut | Poly Haven `smoked_walnut_veneer` — https://polyhaven.com/a/smoked_walnut_veneer | Jenelle van Heerden | CC0 | 1.0 |
| `wenge.webp` | Dark oak / wenge | Poly Haven `black_oak_veneer` — https://polyhaven.com/a/black_oak_veneer | Jenelle van Heerden | CC0 | 1.0 |
| `marble_white.webp` | White marble (worktops, splashbacks) | ambientCG `Marble012` — https://ambientcg.com/view?id=Marble012 | ambientCG (Lennart Demes) | CC0 | 1.5 |
| `travertine.webp` | Beige onyx / travertine | ambientCG `Travertine009` — https://ambientcg.com/view?id=Travertine009 | ambientCG (Lennart Demes) | CC0 | 1.5 |
| `stone_dark.webp` | Dark stone with gold veins (veins recoloured) | ambientCG `Marble016` — https://ambientcg.com/view?id=Marble016 | ambientCG (Lennart Demes) | CC0 | 1.5 |
| `fabric_boucle.webp` | Bouclé upholstery (grey, tinted) | ambientCG `Carpet016` — https://ambientcg.com/view?id=Carpet016 | ambientCG (Lennart Demes) | CC0 | 0.5 |
| `fabric_weave.webp` | Woven fabric: mattress, linen (grey, tinted) | ambientCG `Fabric031` — https://ambientcg.com/view?id=Fabric031 | ambientCG (Lennart Demes) | CC0 | 0.35 |
| `floor_planks.webp` | Plank floor of a room with furniture | Poly Haven `laminate_floor_03` — https://polyhaven.com/a/laminate_floor_03 | Dario Barresi, Charlotte Baglioni | CC0 | 2.08 |
| `tile_subway.webp` | Subway tile splashback | ambientCG `Tiles010` — https://ambientcg.com/view?id=Tiles010 | ambientCG (Lennart Demes) | CC0 | 0.6 |
| `skinali_print.webp` | Printed skinali, "Chimyon mountains" (512 × 128, 256 × 64; tiles left to right, laid once up the panel) | Our own drawing (METRX), made with a Python script like the mockup's `drawPrint` | METRX | Ours, no licence needed | 2.4 × 0.6 |

Licences: https://polyhaven.com/license and https://docs.ambientcg.com/license/ (both CC0, no attribution required;
listed here anyway).

Wood pictures have the grain along their width (u). The app lays u along a board's long side, up a door and across a
drawer front (`geo/Furniture3D.kt` `obbFaces`). The metres per repeat are in `geo/Look.kt` `TEXTURES`.

The decors of the design presets (furniture `Decors.kt`) name these pictures through the alias table in
`geo/Look.kt` `TEXTURES` (the iPhone app keeps the same table):

| Decor id | Picture | Recoloured to |
|---|---|---|
| `oak_light` | `oak_halifax` | as drawn |
| `oak_tobacco` | `oak_halifax` | #7A5A40 (darker, warmer) |
| `oak_golden` | `oak_craft` | as drawn |
| `oak_dark` | `wenge` | #5A3F2E (a little lighter) |
| `walnut`, `wenge`, `marble_white`, `stone_dark`, `skinali_print` | the picture of that name | as drawn |
| `onyx_beige` | `travertine` | #E8DBC2 |
| `tile_white` | `tile_subway` | as drawn |
| `boucle` | `fabric_boucle` | grey, takes the fabric's colour |
| `velvet`, `fabric` | `fabric_weave` | grey, takes the fabric's colour |
| `fluted`, `fluted_glass` | none: drawn as ribs (geometry) | |

Adding a picture: put a 512 px and a 256 px WebP of the same name in `512/` and `256/`, add its id to `TEXTURES`
with the metres it covers, list it here; a board uses it through `Mat.tex`.
