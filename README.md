# FlakSystem for DCS World (MIST-based)

**FlakSystem.lua** is a modular, performance-conscious flak simulation library for DCS World that:
- Simulates WWII-style flak barrages without physical units
- Supports dynamic altitude tracking (e.g., bomber box altitudes)
- Activates based on enemy aircraft presence **or** flags
- Includes powerful tools for auto-zone scanning and flak corridor generation

This system requires the **MIST** scripting framework to function.

---

## Setup

### 1. Load Script Files in Mission
Use mission trigger actions in this order:

1. `DO SCRIPT FILE`: Load **MIST** (latest version)
2. `DO SCRIPT FILE`: Load **FlakSystem.lua**
3. `DO SCRIPT`: Call your setup functions (see below)

---

## Usage

### 2. Prefix Scan: Auto-activate zones from Mission Editor

In ME, define zones with names like:

```
Flak_1, Flak_2, Flak_AA_1, etc.
```

Then call:

```lua
FlakSystem.debug = true -- Optional for development
FlakSystem:scanZonesByPrefix("Flak_", {
    dynamicAltitude = true
})
```

Optional params:
- `altitude`: fixed height in meters
- `flagPrefix`: to activate each zone via flags (e.g. FlakFlag_1)
- `flag`: one shared flag for all
- `dynamicAltitude`: true to track aircraft altitude groups

---

### 3. Corridor Builder: Virtual flak between two points

Place 2 zones in ME: `Flak_Start`, `Flak_End`

Then call:

```lua
FlakSystem:buildCorridor("Flak_Start", "Flak_End", 3000, {
    namePrefix = "FlakCorridor_",
    dynamicAltitude = true,
    zoneRadius = 1000
})
```

Optional:
- `flagPrefix`: enables per-zone flag control (e.g. FlakZone_1, FlakZone_2)
- `altitude`: fixed altitude in meters
- `zoneRadius`: used for virtual flak zone spread
- `spacingMeters`: determines how many virtual zones between points

---

## Control Methods

| Control Style      | Method                                                |
|--------------------|--------------------------------------------------------|
| Enemy presence     | Omit `flag`/`flagPrefix` entirely                      |
| Shared flag        | Use `flag = "MyFlag"`                                  |
| Per-zone flags     | Use `flagPrefix = "ZoneFlag_"` (appends index)         |

---

## Manual Flak Zone Creation

For precise control or scripted generation, you can manually create each flak zone using `FlakSystem:newZone()`.

### 🔹 Example

```lua
local zone = FlakSystem:newZone("FlakZone_1", {
    altitude = 7000,             -- fixed altitude in meters
    dynamicAltitude = false,     -- or true to track aircraft groups
    flag = "FlakFlag_1"          -- optional flag name
})
zone:update()
```

### 🔹 Use Cases
- Zones created dynamically by script
- Zones needing unique altitudes or flags
- Missions with tight control over each zone's behavior

You may use this alongside `scanZonesByPrefix()` and `buildCorridor()` — they all work together.

---

## Performance Tips

- Keep `dynamicAltitude = true` for realism with bomber boxes
- Reduce `zoneRadius` and `spacing` to avoid framerate hits
- 
- FlakSystem.densityMultiplier can be lowered to reduce effects

---

## Advanced Configuration Options --> More details described in the scrpit itself.

All of the parameters below can be modified directly in the `FlakSystem.lua` script under the CONFIGURATION section.

These allow you to fine-tune realism, density, and performance based on your mission design.

### 🔧 FlakSystem Configuration Table

| Parameter                 | Default       | Description                                                                 |
|---------------------------|---------------|-----------------------------------------------------------------------------|
| `debug`                  | `false`       | Enables in-game debug messages if `true`. Always logs to DCS log.          |
| `densityFactor`          | `500`         | Base radius (in meters) used to scale flak explosion count.                |
| `densityMultiplier`      | `0.5`         | Multiplies final flak count per zone. Lower to improve FPS.                |
| `layerOffsets`           | `{ -100, 0, 100, 200 }` | Altitude offsets (meters) for flak burst layers. Add/remove layers here. |
| `interval`               | `0.5`         | How often (seconds) each zone re-triggers its flak bursts.                |
| `altitudeBinSize`        | `150`         | Resolution of dynamic altitude grouping (meters). Smaller = more precision.|

### 🛠 Tips for Customization

- Increase `densityFactor` or lower `densityMultiplier` to reduce flak volume.
- You can add more `layerOffsets` to simulate high/low spread (e.g., `{ -200, -100, 0, 100, 200, 300 }`)
- Set `interval = 1.0` or higher to reduce performance cost.
- Adjust `altitudeBinSize` based on expected bomber separation.

> 🔁 All these values apply globally. Per-zone custom overrides would require additional scripting logic, which is possible if needed.

## Development

Enable debug output:
```lua
FlakSystem.debug = true
```

This shows real-time zone creation, activations, and logs via `trigger.action.outText()` and `env.info`.

---

## Author Notes

Originally developed collaboratively with mission builders seeking:
- Realistic WWII-era flak behavior
- Minimal performance footprint
- Dynamic adaptation to bomber formations


---



