<div align="center">

# ⚡ EEL — Enhanced Execution Layer

**A developer power-tool for Garry's Mod.**
Run Lua from the console with smart variables, visual debugging, and context-aware autocomplete.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Garry's Mod](https://img.shields.io/badge/Garry's%20Mod-Addon-orange.svg)](#installation)

</div>

---

## 📋 Table of Contents

- [Features](#-features)
- [Smart Autocomplete](#-smart-autocomplete)
- [Environment Variables](#-environment-variables)
- [Commands](#-commands)
- [Debug Mode](#-debug-mode)
- [Permissions](#-permissions)
- [Installation](#-installation)
- [Contributing](#-contributing)
- [License](#-license)

---

## ✨ Features

Code run via `el_run` tries to return a value as an expression first, then falls back to a statement. Return values are printed with **type-aware formatting**:

| Type | Output |
|:--|:--|
| **Function** | Name and parameter list |
| **Vector** | In-world crosshair marker |
| **Entity** | Halo + label (works for serverside-only entities too) |
| **Color** | Inline color swatch `▉▉▉` in the console |
| **Table** | Recursive key/value dump |

<p align="center">
  <img src="https://github.com/user-attachments/assets/2989d9e1-32e5-4b6e-99c4-091d865901ab" width="700">
</p>

---

## 🔍 Smart Autocomplete

Typing `el_run` in the console opens a tab-complete dropdown that resolves identifier chains through `_G` and metatables — get completions for things like `NikNaks.` or `me:`.

- **Dot access** (`.`) — shows all members
- **Colon access** (`:`) — shows functions only, ranking `self`-taking methods highest
- **Syntax errors** — shown inline in the dropdown before you run the command

---

## 🧩 Environment Variables

The following shorthands are available in all `el_run` commands:

<details open>
<summary><b>Player & World</b></summary>

| Variable | Description |
|:--|:--|
| `me` / `self` | The player running the command |
| `wep` | Your active weapon |
| `ground` | The entity you're standing on |
| `world` | `Entity(0)` — the world entity |
| `map` | The current map name |

</details>

<details open>
<summary><b>Spatial</b></summary>

| Variable | Description |
|:--|:--|
| `here` | Your current position (Vector) |
| `there` | The position your crosshair is hitting (Vector) |
| `eye` | Your eye position (Vector) |
| `fwd` | The forward direction of your view (Vector) |
| `ang` | Your eye angles (Angle) |
| `vel` | Your current velocity (Vector) |

</details>

<details open>
<summary><b>Targeting</b></summary>

| Variable | Description |
|:--|:--|
| `trace` | Full eye-trace result table |
| `this` / `that` | The entity you're looking at |
| `hp` | Health of the aimed entity, or your own if looking at nothing |
| `near` | The nearest entity to your aim position |
| `nearme` | The nearest entity to your own position |

</details>

<details open>
<summary><b>Dynamic Lookups</b></summary>

| Pattern | Description |
|:--|:--|
| `ent<id>` | Entity by index — `ent42` → `Entity(42)` |
| `prox<distance>` | All entities near your aim within `distance` units (default 128) |
| `ply<name>` | Nearest player matching a partial name — `plyNak` |
| `p` | Shorthand print — `p(value)` works mid-expression |

</details>

> **Fuzzy entity lookup** — If an unknown variable is used, EEL searches the map for a matching entity in order: player names → entity classes → entity names → entity models → nearest match.

```lua
-- Teleports the player matching "nak" to your crosshair
el_run nak:SetPos(there)
```

---

## 🛠 Commands

### Execution

| Command | Description |
|:--|:--|
| `el_run <code>` | Run Lua **serverside** |
| `el_run_cl <code>` | Run Lua **clientside** |
| `el_time <code>` | Run serverside and print **execution time** |
| `el_time_cl <code>` | Clientside version of `el_time` |
| `el_sealed <code>` | Run in a **read-only** environment — `_G` is not modified |
| `el_sealed_cl <code>` | Clientside version of `el_sealed` |

### Lazy Mode

`el_lazy` fills in parentheses automatically and supports pipe chaining:

```lua
el_lazy here - eye + there | me:SetPos
-- equivalent to: el_run me:SetPos(here - eye + there)

el_lazy me:SetPos there
-- equivalent to: el_run me:SetPos(there)
```

| Command | Description |
|:--|:--|
| `el_lazy <code>` | Lazy execution **serverside** |
| `el_lazy_cl <code>` | Lazy execution **clientside** |

### Entity Utilities

| Command | Description |
|:--|:--|
| `el_ent_spawn <class> [amount]` | Spawn entities at your aim position (default 1, max 100) |
| `el_ent_remove_all <class>` | Remove all entities of the given class |
| `el_ent_sequence` | Print all sequences for the entity you're looking at |

---

## 🔎 Debug Mode

| Command | Description |
|:--|:--|
| `el_debug_mode [0/1]` | Toggle the clientside debug overlay |

When enabled, nearby entities are rendered with:

- **Collision mesh wireframe** — actual physics hull from the server, drawn as a cyan wireframe
- **Entity info overlay** — class, model, position, angles, velocity, physics state, animation data, health, render properties, materials, and more

<img width="694" height="632" alt="debugmode" src="https://github.com/user-attachments/assets/7e5c4660-958a-40f1-a3b7-16dc946832e0" />

---


## 🔒 Permissions

EEL integrates with [CAMI](https://github.com/glua/CAMI) for admin-mod compatibility. All commands require `superadmin` access by default, configurable through any CAMI-compatible admin mod.

---

## 📦 Installation

1. Download the [latest release](https://github.com/Nak2/Eel/archive/refs/heads/main.zip) (`.zip`)
2. Extract the contents
3. Move the folder into `garrysmod/addons/` so the path is:
   ```
   garrysmod/addons/eel/
   ```
4. Restart your server or client

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please [open an issue](https://github.com/Nak2/Eel/issues) first to discuss what you'd like to change.

---

## 📄 License

Licensed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html). See [LICENSE](LICENSE) for details.
