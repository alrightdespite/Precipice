# PRECIPICE — `PLOT_TEMPLATE` Map Build State

Single-plot template for the idle chemistry tycoon: an industrial chemistry **lab building** (interior gameplay space) inside a fully built-out **exterior facility yard**. Built in Studio via the Roblox Studio MCP. **~1,384 parts.**

> This file documents the *built geometry/instance layout only*. Gameplay logic (PlotService, RevealController, etc.) lives in `src/` — see `docs/01_ARCHITECTURE.md`.

## Coordinate system

- Building centered on world origin. **Floor top = Y 0.5**, ceiling underside Y 22.5.
- **+X = east, −X = west, +Z = north, −Z = south, +Y = up.**
- Interior inner walls at X ±60, Z ±44 (≈120 × 88 stud floor, 22 tall).
- **South (−Z) = entrance/front. North (+Z) = mezzanine + silos.**

## Top-level tree

**Placement:** the template lives at **`workspace.Plots.PLOT_TEMPLATE`** (a `Plots` Folder in Workspace). `PlotService` clones it per player into the same `Plots` folder and renames the clone to the player's `userId`; `SlotController` resolves chambers at `workspace.Plots.<userId>.Lab.Chambers.<slotIndex>`. The template is **not** Rojo-synced (Workspace is Studio-only by design) — it must exist in the place file.

```
workspace.Plots (Folder)
└── PLOT_TEMPLATE (Model)   ← cloned per player → renamed to <userId>
    ├── Lab (Folder)            ← interior: shell, gameplay, decor
    │   ├── <shell parts>   Floor, Wall_N/E/W, Wall_S_L/R, Wall_S_Lintel,
    │   │                   Ceiling, LightPanel ×8, LogoSign
    │   ├── WingLight (PointLight, direct child — spec rule)
    │   ├── Chambers (Folder)   ← 6 gameplay pedestals "1".."6"
    │   └── Detail (Folder)     ← all interior decor/equipment
    ├── Exterior (Folder)   ← yard, fences, tanks, roads, props
    ├── Roof (Part)         + Parapet_N/S/E/W
    └── Spawn (SpawnLocation)   neutral, Duration 0, at (0,1,-34)
```

## Room shell (`Lab` direct children)

| Part | Size | Pos | Notes |
|---|---|---|---|
| Floor | 120×1×88 | (0,0,0) | concrete |
| Wall_N | 120×22×1 | (0,12,44) | back wall (logo + catwalk) |
| Wall_E / Wall_W | 1×22×88 | (±60,12,0) | side walls |
| Wall_S_L / Wall_S_R | 54×22×1 | (±33,12,-44) | south wall split for **doorway** |
| Wall_S_Lintel | 12×10×1 | (0,18,-44) | over the 12-wide × 12-tall entrance opening |
| Ceiling | 120×1×88 | (0,23,0) | interior ceiling |
| Roof | 134×1×102 | (0,24,0) | overhanging exterior roof + parapet |
| LightPanel ×8 | 16×0.2×4 | Y22 grid | Neon troffers; 4 carry PointLights |
| LogoSign | 40×8×0.4 | (0,18,43) | interior PRECIPICE panel — **blank** (text removed by request), teal `LogoGlow` strip below |

## CHAMBERS (gameplay-critical — exact spec)

6 pedestals in `Lab/Chambers`, named **"1"–"6"**, 3×2 grid:

- Back row (Z+11): **1** (−22,2,11), **2** (0,2,11), **3** (22,2,11)
- Front row (Z−9): **4** (−22,2,−9), **5** (0,2,−9), **6** (22,2,−9)

Each pedestal Part contains the required runtime children:

- **`Pulse`** — PointLight, Brightness 0
- **`RevealSpot`** — SpotLight, Brightness 0, Angle 45, Face Top
- **`Burst`** — ParticleEmitter, Enabled false. Configured for the reveal pop (Rate 0, Lifetime 0.6–1.2, Speed 9–17, SpreadAngle 55, EmissionDirection Top, size pop-and-shrink, LightEmission 1). `RevealController` sets `Color` per tier and calls `:Emit(tier×8)`.
- **`RevealPrompt`** — ProximityPrompt, ActionText "Reveal", HoldDuration 0, MaxActivationDistance 50, RequiresLineOfSight false. ⚠ **Not wired to code** — reveal is UI-driven (`HomeScreen` button → `SlotController.reveal`). Present per spec; inert until a controller connects `ProximityPrompt.Triggered`.

Decor children: `Rim` (neon top), `Rib`×4 (teal accent strips), `Dome`+`DomeCap` (glass cylinder), `PedBase` (floor ring), `LabelPost`+`LabelPlate` (SurfaceGui **"CHAMBER 0n" + "● STANDBY"**, faces south toward the player).

Surrounded by a **hazard-stripe rectangle** (`Haz` ×102, exact rect X±33 Z−17..21) framing the **`OpsZone`** blue floor plate (66×38) + approach `Chevron` arrows.

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

- Daytime: `Brightness 2.6`, `ClockTime 13.5`, `Ambient (96,96,104)`, `OutdoorAmbient (140,140,150)`, fog far.
- **16 active PointLights** (reduced from 41 to kill flicker): 4 interior troffers, 5+2 yard floods, 2 wall packs, booth, monument, dock, road.
- Chamber `Pulse`/`RevealSpot` are Brightness 0 (driven at runtime during a reveal).

## Palette / materials

Greys (walls `(70,70,76)`, floor concrete `(82,82,86)`), **teal accent `(0,180,200)`** (chambers, signage, neon), **safety yellow `(224,182,32)`** (hazard/rails), Neon for glow strips + liquid bands, Glass for domes/windows, DiamondPlate for catwalk/stairs/treads.

## Spec rules baked in

1. `PLOT_TEMPLATE` is a **Model inside `workspace.Plots`** (a Folder); `Lab` is a **Folder** inside the model. `PlotService` clones the template per player.
2. Chambers folder holds pedestals named **"1"–"6"**, each with `Pulse`/`RevealSpot`/`Burst`/`RevealPrompt`. (`RevealController` resolves SpotLight/PointLight/ParticleEmitter by **class**, so those three names are free; `RevealPrompt` is inert — see chambers note.)
3. `WingLight` is a **PointLight, direct child of `Lab`** (required: `RevealController` dims PointLights named `WingLight` found via `lab:GetChildren()`). ⚠ A Folder has no transform, so it emits no actual light — the reveal-dim beat is currently invisible (real lab light comes from the `LightPanel` troffers, which the reveal doesn't touch). Left per the code contract; making the dim visible needs a code+map change (RevealController would search recursively and the WingLights would live on parts).
4. `Spawn` = neutral SpawnLocation, Duration 0, center-rear at (0,1,−34) inside the entrance. (The place's default baseplate spawn was removed so this one is authoritative.)
5. Interior decor isolated in `Lab/Detail`; exterior in `Exterior` — gameplay scripts should only touch `Lab/Chambers`.

## Totals / verification

- **1,384 parts**, 16 active lights, 6 chambers / 6 prompts, 1 spawn.
- Verified walkable (spawn → chambers → stairs → catwalk), doorway passable, layered ground (no baseplate z-fight), no major part interpenetration (overlap scan clean aside from intentional foliage overlaps).

## Reference screenshot camera angles

Captures aren't stored in-repo (MCP returns them inline only). To reproduce in Studio, paste into the command bar:
`workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(<pos>), Vector3.new(<look>))`

| View | Camera pos | Look at |
|---|---|---|
| Aerial (whole site) | (160,140,185) | (0,4,0) |
| Interior gameplay floor | (0,16,-36) | (0,5,10) |
| Entrance facade | (34,16,-86) | (0,10,-48) |
| Chamber close-up | (-22,4,-16) | (-22,3.5,-9) |
