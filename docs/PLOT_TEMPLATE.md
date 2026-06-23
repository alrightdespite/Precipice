# PRECIPICE — `PLOT_TEMPLATE` Map Build State

Single-plot template for the idle chemistry tycoon: an industrial chemistry **lab building** (interior gameplay space) inside a fully built-out **exterior facility yard**. Built in Studio via the Roblox Studio MCP. **~1,347 parts.**

> This file documents the *built geometry/instance layout only*. Gameplay logic (PlotService, RevealController, etc.) lives in `src/` — see `docs/01_ARCHITECTURE.md`.

## Coordinate system

> ⚠ The template was repositioned in Studio since the early build; the live coords are **offset
> ≈ (+1.6 X, +4 Y, +7 Z)** from the "origin-centered" values quoted in older revisions of this doc.
> All tables below are the **live** values (re-verified 2026-06-23).

- Floor centered at **(1.6, 4.05, 7)**, **top surface Y ≈ 4.55**; interior ceiling underside ≈ Y 26.5.
- **+X = east, −X = west, +Z = north, −Z = south, +Y = up.**
- Floor is 120 (X) × 88 (Z); interior spans **X ≈ −58..61, Z ≈ −37..51**.
- **South (−Z, Z ≈ −37) = entrance/front + station terminals. North (+Z, Z ≈ 51) = mezzanine + silos.**

## Top-level tree

**Placement:** the template lives at **`workspace.Plots.PLOT_TEMPLATE`** (a `Plots` Folder in Workspace). `PlotService` clones it per player into the same `Plots` folder and renames the clone to the player's `userId`; `SlotController` resolves chambers at `workspace.Plots.<userId>.Lab.Chambers.<slotIndex>`. The template is **not** Rojo-synced (Workspace is Studio-only by design) — it must exist in the place file.

```
workspace.Plots (Folder)
└── PLOT_TEMPLATE (Model)   ← cloned per player → renamed to <userId>
    ├── Lab (Folder)            ← interior: shell, gameplay, decor
    │   ├── <shell parts>   Floor, Wall_N/E/W, Wall_S_L/R, Wall_S_Lintel,
    │   │                   Ceiling, LightPanel ×8 (all 8 now lit), LogoSign
    │   ├── WingLight (PointLight, direct child — spec rule)
    │   ├── Chambers (Folder)   ← 10 gameplay pedestals "1".."10" (5×2 grid)
    │   ├── Stations (Folder)   ← 5 walk-up terminals (Vault/Market/Syndicate/Leaderboard/Prestige)
    │   └── Detail (Folder)     ← all interior decor/equipment
    ├── Exterior (Folder)   ← yard, fences, tanks, roads, props
    ├── Roof (Part)         + Parapet_N/S/E/W
    ├── PlotBounds (Part)   ← invisible lot footprint (262×1×410); PlotService reads for tiling stride
    └── Spawn (SpawnLocation)   neutral, Duration 0, at (1.6,5,-27)
```

## Room shell (`Lab` direct children)

| Part | Size | Pos (live) | Notes |
|---|---|---|---|
| Floor | 120×1×88 | (1.6,4.05,7) | concrete |
| Wall_N | 120×22×1 | (1.6,15.55,51) | back wall (logo + catwalk) |
| Wall_E / Wall_W | 1×22×88 | (≈±59,15.55,7) | side walls |
| Wall_S_L / Wall_S_R | 54×22×1 | (-31.4 / 34.6, 15.55, -37) | south wall split for **doorway** |
| Wall_S_Lintel | 12×10×1 | (1.6,21.55,-37) | over the 12-wide entrance opening (X −4.4..7.6) |
| Ceiling | 120×1×88 | (1.6,≈27,7) | interior ceiling |
| Roof | 134×1×102 | overhang | overhanging exterior roof + parapet |
| LightPanel ×8 | 16×0.2×4 | Y26 grid | Neon troffers; **all 8 now carry PointLights** (B2.4, R34–36). 4 inner panels lit 2026-06-23 so the OpsZone floor reads. `RevealController` dims any `LightPanel` PointLight during a reveal. |
| LogoSign | 40×8×0.4 | (1.6,≈18,50) | interior **PRECIPICE** panel (teal), teal `LogoGlow` strip below |

## CHAMBERS (gameplay-critical — exact spec)

**10** pedestals in `Lab/Chambers`, named **"1"–"10"**, a **5×2 grid** inside the OpsZone
(re-laid 2026-06-23 — the old 3×2 + 4 grid-cloned extras put 7–9 in the spawn zone and 10 outside
the south wall). All at **Y 6.55**, labels face south toward the entering player.

- Columns (X): **−26.4, −12.4, 1.6, 15.6, 29.6** (14-stud spacing, ~5-stud footprint → 9-stud aisles)
- **Front row (Z −2):** `1` (−26.4), `2` (−12.4), `3` (1.6), `4` (15.6), `5` (29.6) — nearest spawn; `1` unlocks first
- **Back row (Z 18):** `6` (−26.4), `7` (−12.4), `8` (1.6), `9` (15.6), `10` (29.6)

The §8 personal slot cap can reach 10, so all 10 are on-floor, lit, and reachable.

Each pedestal Part contains the required runtime children:

- **`Pulse`** — PointLight, Brightness 0
- **`RevealSpot`** — SpotLight, Brightness 0, Angle 45, Face Top
- **`Burst`** — ParticleEmitter, Enabled false. Configured for the reveal pop (Rate 0, Lifetime 0.6–1.2, Speed 9–17, SpreadAngle 55, EmissionDirection Top, size pop-and-shrink, LightEmission 1). `RevealController` sets `Color` per tier and calls `:Emit(tier×8)`.
- **`RevealPrompt`** — ProximityPrompt, ActionText "Reveal", HoldDuration 0, MaxActivationDistance 50, RequiresLineOfSight false. ⚠ **Not wired to code** — reveal is UI-driven (`HomeScreen` button → `SlotController.reveal`). Present per spec; inert until a controller connects `ProximityPrompt.Triggered`.

Decor children: `Rim` (neon top), `Rib`×4 (teal accent strips), `Dome`+`DomeCap` (glass cylinder), `PedBase` (floor ring), `LabelPost`+`LabelPlate` (SurfaceGui **"CHAMBER 0n" + "● STANDBY"**, faces south toward the player).

Surrounded by a **hazard-stripe rectangle** (`Haz`) framing the **`OpsZone`** blue floor plate
(center (1.6,4.575,9), 66×38 → X −31.6..34.6, Z −10..28; comfortably frames the 5×2 grid) +
approach `Chevron` arrows from the south.

## STATIONS (`Lab/Stations`) — walk-up terminals

5 Models lining the **south wall** (Z −36, Y 6.25), flanking the doorway (door X −4.4..7.6), evenly
spaced and clear of the opening (re-spaced 2026-06-23). Each is styled like `Detail.ConsoleBody`,
with a `Prompt` (ProximityPrompt), a `Screen` SurfaceGui face, and a string attribute **`Screen`**
naming the HUD screen its E-prompt opens (read by `StationController`).

| Station | X | `Screen` attr |
|---|---|---|
| VaultStation | −22 | Vault (live-driven SurfaceGui: pellets + compound count) |
| MarketStation | −13 | Market |
| SyndicateStation | 11 | Syndicate |
| LeaderboardStation | 19 | Leaderboard |
| PrestigeStation | 27 | Prestige |

Walk in from spawn (Z −27) → stations are immediately left/right of the entrance; the chamber field
is straight ahead (north).

## Interior equipment (`Lab/Detail`) by zone

- **Ceiling services:** `Beam`×5, `Truss`×5, `Duct`×2 + `DuctHanger`/`Diffuser`×14, `SprinklerMain`+`SprinklerDrop`/`Head`×9, `TrofferFrame`×8, wall `Panel`×13 + `Mullion`×14.
- **Overhead bridge crane:** `CraneRunwayN/S`, `CraneGirder`, `CraneTrolley`, `CraneCable`, `CraneHook`, `CraneEndN/S`.
- **Columns ×4** (X±40, Z±30): `Column`, `ColCap`, `ColPlate`, `ColHaz`, `ColConduit`, `ColJBox`.
- **West tank farm (interior):** `Tank`×4 (14 tall, X−53) + `TankBase`/`TankRib`/`TankCap`/`LiquidBand`(neon)/`Gauge`/ladder(`LadderRail`+`Rung`)/`SteamPt`(ParticleEmitter), `Manifold`+`ManifoldValve`×4.
- **East bay:** `FumeHood`+`FumeGlass`+`FumeStack`, `Bench`×2+`BenchTop`+glassware (`Flask`/`Beaker`/`Apparatus`), `Cabinet`×4 (electrical) +`CabVent`/`CabLED`, safety station (`FirstAid`+cross, `Eyewash`Post/Bowl/Sign).
- **Pump skids ×4** (side aisles): `SkidBase`, `PumpMotor`, `PumpBody`, `PumpRiser`, `PumpSuction`, `PumpGauge`.
- **Mixing vessels ×3** (corners): `MixPad`, `MixVessel`, `MixBand`(neon), `MixTop`, `MixMotor`, `MixPipe`. Plus **jib crane** (`JibPost`/`JibArm`/`JibCable`/`JibHook`).
- **South wall:** `ConsoleBody`×2 + `Screen` (animated SurfaceGui) flanking the door; `Locker`×6; `ExitSign`.
- **Storage:** `Barrel`×4, `Crate`×4, `Drum`×8 on `Pallet`×2.
- **Mezzanine (North, Y11):** `CatwalkDeck` (120 long) + `CatToe` + `CatLeg`×4, `HandRail`/`MidRail`/`RailPost`×19. **Straight staircase** (east): `Tread`×15, `Riser`×19, `Stringer_L/R`, `Rail_L/R`, `Newel`, `StairLanding`, `LandRail`/`LandMid`/`LandPost`. (A control booth that was here was removed by request.)
- **Floor markings:** `Lane` (flush walkways), `Chevron`×4, `GrateFrame`+`Slot`×2 (drains, relocated to clear aisles), `WallTray`×2 (cable trays), `WGauge`×2, bay signage.

## Exterior facility (`Exterior`) by zone

- **Ground (layered, no z-fight):** `Grass` (2000², top Y−0.05) < `Compound` (260² concrete, top Y0) < `Apron` < `Curb_*`. The default baseplate was **deleted** (it z-fought the lot).
- **Entrance (South):** `FacadeSign` (PRECIPICE, enlarged — SurfaceGui PixelsPerStud 22 so TextScaled fills) + `SignGlow`, **taller vestibule/airlock** (`VestFloor`/`VestWall_E/W`/`VestRoof` canopy + `CanopyPost`×2 + `CanopyFascia`), outer doorway (`VestOuter_L/R/Lintel`, `VJamb_*`), `EntryRamp`, `DoorPanel_L/R`, `WallPack`×2 lights.
- **Gate/plaza:** `GatePostBox`×2 + `GateHeader` (manual edit), `GatePanel` (sliding) + `GateTrack`/`Roller`/`Brace`, `GateSign`×2, guard booth (`Booth*`), `Monument` sign, `FlagPole`×3, `Bollard`×11, `Planter`×4 + `Shrub`/`Soil`.
- **Parking (SW):** `ParkLot` + `StallLine`×6, tanker truck (`TruckChassis`/`TruckCab`/`TankerBody`/`Ring`/`Hatch`/`Wheel`), 2 cars (`CarBody`/`Cabin`/`Glass`/`Wheel`).
- **West tank farm (exterior):** `FTank`×2 + caps/bands/pipe inside `Berm`×4 containment, pipe rack (`RackLeg`×8/`RackBeam`×12/`RackPipe`×3), `Transformer`+`Bushing`+`XfmrSign`.
- **North:** `Silo`×3 (`SiloBody`/`Dome`/`Skirt`/`Rib`/`Vent`/`Discharge`/`Valve`/ladder), `CoolTower` (+fan blades/ring/pipe), `PumpHouse`+`PHRoof`, flare stack (`FlareStack`+`FlareTip`/`FlareFlame`(neon)/`FlareLeg`).
- **East dock:** `DockPad`+`DockEdge`+`DockBumper`×4+`DockLeveler`, `Trailer`+`TrailerRib`×11, forklift (`Fk*`), `DockPallet`+`Crate`×2, `Condenser`×3+`CondFan`.
- **Containers (SE):** `Container`×3 stacked + `ContBand`/`ContCorner`×24/`ContDoor`.
- **Roof:** `RTU`×3+`RTUFan`×6+`RTUDuct`, `Stack`×3+`StackCap`, `RoofHatch`, `RoofRail`×4 (parapet rail), `Mast`+arms+`MastBeacon` (red neon), satellite `Dish`+`DishMount`/`Feed`, `RoofCornerPost`×4 (manual edit).
- **Perimeter:** `FencePost`×48 + `FencePanel`×51 + `FenceCornerPost`×4 (manual edit) + `Barbed`×12 wire, `SecCam`×4 (`CamBody`/`CamMount`), flood `PolePost`×5/`PoleHead`/`PoleLens` (+PointLight).
- **Road:** `Road` (off-site, south) + `RoadDash`×14/`LaneDash`/`Curb_R*`/`RoadPole`×2+`RoadLamp`, `Manhole`×3, `Driveway`.
- **Trees ×11:** `Trunk` + `Canopy`/`Canopy2` (overlapping spheres = full crown).

## Lighting

- Daytime: `Brightness 3.0`, `ClockTime 14.5`, `Ambient (70,70,70)`, `OutdoorAmbient (70,70,70)`, fog far.
- **20 active PointLights**: **8 interior troffers** (all 8 `LightPanel`s now lit — the 4 inner panels
  were given lights 2026-06-23 so the OpsZone gameplay floor reads, prior 4 corner-only left it dark),
  5+2 yard floods, 2 wall packs, booth, monument, dock, road.
- Chamber `Pulse`/`RevealSpot` are Brightness 0 (driven at runtime during a reveal). `RevealController`
  dims all `LightPanel` PointLights to 20% during a reveal (captures + restores each light's base).

## Palette / materials

Greys (walls `(70,70,76)`, floor concrete `(82,82,86)`), **teal accent `(0,180,200)`** (chambers, signage, neon), **safety yellow `(224,182,32)`** (hazard/rails), Neon for glow strips + liquid bands, Glass for domes/windows, DiamondPlate for catwalk/stairs/treads.

## Spec rules baked in

1. `PLOT_TEMPLATE` is a **Model inside `workspace.Plots`** (a Folder); `Lab` is a **Folder** inside the model. `PlotService` clones the template per player.
2. Chambers folder holds pedestals named **"1"–"10"**, each with `Pulse`/`RevealSpot`/`Burst`/`RevealPrompt`. (`RevealController` resolves SpotLight/PointLight/ParticleEmitter by **class**, so those three names are free; `RevealPrompt` is inert — see chambers note.)
3. **Reveal-dim** = `RevealController.isAmbientLabLight` dims every PointLight whose `Parent.Name == "LightPanel"` (plus any `WingLight`) to 20%, capturing + restoring each light's base brightness. So the dim beat now uses the real troffer lights (all 8 `LightPanel`s). The legacy `WingLight` (PointLight direct-child of `Lab`) has no transform → emits no light; kept only for the name match, no longer load-bearing.
4. `Spawn` = neutral SpawnLocation, Duration 0, at **(1.6,5,−27)** inside the entrance. (The place's default baseplate spawn was removed so this one is authoritative.)
5. Interior decor isolated in `Lab/Detail`; exterior in `Exterior` — gameplay scripts touch `Lab/Chambers` (resolve by name) and `Lab/Stations` (read the `Screen` attribute).

## Totals / verification

- **1,347 parts**, 20 active lights, **10 chambers** / 15 ProximityPrompts (10 chamber RevealPrompts +
  5 station Prompts), **5 stations**, 1 spawn, 1 PlotBounds.
- Verified walkable (spawn → all 10 chambers → all 5 stations → stairs → catwalk), doorway passable,
  layered ground (no baseplate z-fight). Overlap scan clean: min chamber-chamber distance 14 (footprint
  ~5); no real intruders in the OpsZone gameplay volume (only the flat ground slabs beneath the floor).

## Reference screenshot camera angles

Captures aren't stored in-repo (MCP returns them inline only). To reproduce in Studio, paste into the command bar:
`workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(<pos>), Vector3.new(<look>))`

| View | Camera pos | Look at |
|---|---|---|
| Aerial (whole site) | (170,150,195) | (2,4,-40) |
| Interior — chamber field (all 10) | (1.6,20,-33) | (1.6,3,14) |
| Interior — station wall (south) | (1.6,11,-8) | (1.6,6,-37) |
| Interior — chamber field eye-level | (1.6,13,-26) | (1.6,5,12) |
