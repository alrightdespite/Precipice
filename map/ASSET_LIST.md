# Asset List

Status: Lab + exterior BUILT in Studio (Phase 12D) at `workspace.Plots.PLOT_TEMPLATE`. See `docs/PLOT_TEMPLATE.md`.

## Required models / VFX / SFX

| Asset | Type | Status |
|---|---|---|
| Lab interior | Model | **Built** — 6 chambers `"1"–"6"` + equipment (Phase 12D). Slots 7–10 (expanded lab) have no chamber yet. |
| Plot exterior shell | Model | **Built** — full facility yard (fence, silos, tanks, dock, roads). |
| Tier particle sets (T1–T7) | ParticleEmitter | **Built** — one `Burst` emitter per chamber; `RevealController` recolors per tier at runtime. |
| Spotlight VFX | Beam/Part | **Built** — `RevealSpot` SpotLight per chamber (driven by `RevealController`). |
| Reveal SFX (tier-scaled) | Sound | Not started (belongs to `RevealCard`, not the map). |
| Lab skins (Arctic Research, Carbon Black, Void) | Texture | Not started (future cosmetic). |
