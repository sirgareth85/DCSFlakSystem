
# 📘 Changelog – FlakSystem

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/).

---

## [v1.0.0] – Initial Release

### ✨ Features
- Virtual flak simulation using in-world explosions (no physical units)
- Dynamic altitude tracking based on dominant enemy group
- Fixed altitude support per zone
- Flag-controlled or enemy presence-based activation logic
- Auto-scan zones using a name prefix (e.g., "Flak_Zone_1")
- Corridor builder between two zones with configurable spacing
- Multi-layer flak bursts via configurable altitude offsets
- Flak density scaling and interval control
- In-game debug output and persistent log tracing

### 🧰 Requirements
- Requires MIST scripting framework (latest stable)

### 🔧 Configuration
- Global parameters for tuning density, altitude precision, and flak timing
- Simple override system using `FlakSystem.debug`, `FlakSystem.densityMultiplier`, etc.

---

## Upcoming
- Coalition-agnostic detection (BLUE/RED selectable)
- Per-zone configuration overrides
- Optional smoke effects (performance aware)
- Mission builder helper functions

