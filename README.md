# EEL - Enhanced Execution Layer

EEL is a Garry's Mod addon built for developers. It lets you run Lua directly from the console with smart shorthand variables, visual debugging, and tab-autocomplete that understands your codebase.

## Execution and Returns

Code run via `el_run` tries to return a value as an expression first, then falls back to a statement. The return value is printed with type-aware formatting:

- **Functions** — printed with their name and parameter list
- **Vectors** — visualized in-world as a crosshair marker
- **Entities** — highlighted with a halo and label, even serverside-only entities
- **Colors** — rendered as an inline color swatch `▉▉▉` in the console
- **Tables** — printed recursively with keys and values

<p align="center">
  <img src="https://github.com/user-attachments/assets/2989d9e1-32e5-4b6e-99c4-091d865901ab">
</p>

## Smart Autocomplete

Typing `el_run` in the console opens a tab-complete dropdown. It resolves identifier chains through `_G` and metatables, so you get completions for things like `NikNaks.` or `me:`. Colon access (`:`) only shows functions, with methods that take `self` as the first parameter ranked highest.

If your input contains a syntax error, the error is shown inline in the dropdown — no need to run the command to find out.

## Environment Variables

The following shorthand variables are available in all `el_run` commands:

| Variable | Description |
|---|---|
| `me` / `self` | The player running the command |
| `wep` | Your active weapon |
| `trace` | Full eye-trace result table |
| `this` / `that` | The entity you're looking at |
| `here` | Your current position (Vector) |
| `there` | The position your crosshair is hitting (Vector) |
| `eye` | Your eye position (Vector) |
| `fwd` | The forward direction of your view (Vector) |
| `ang` | Your eye angles (Angle) |
| `vel` | Your current velocity (Vector) |
| `ground` | The entity you're standing on |
| `hp` | Health of the entity you're looking at, or your own if looking at nothing |
| `near` | The nearest entity to your aim position |
| `nearme` | The nearest entity to your own position |
| `map` | The current map name |
| `world` | `Entity(0)` — the world entity |
| `p` | Shorthand print: `p(value)` works mid-expression |
| `ent<id>` | Entity by index — `ent42` is `Entity(42)`, `ent0` is the world |
| `prox<distance>` | All entities near your aim position within `distance` units (default 128) |
| `ply<name>` | Finds the nearest player matching the partial name — e.g. `plyNak` |

If an unknown variable is used, EEL searches the map for a matching entity in this order:
1. Player names
2. Entity class names
3. Entity names
4. Entity models
5. Returns the nearest match

**Example:**
```
el_run nak:SetPos(there)
```

## Commands

### `el_run <code>`
Run Lua serverside.

### `el_run_cl <code>`
Clientside equivalent of `el_run`.

### `el_time <code>`
Run Lua serverside and print the execution time.

### `el_time_cl <code>`
Clientside equivalent of `el_time`.


### `el_sealed <code>`
Runs code in a read-only environment — assignments are blocked, so `_G` is not modified. Useful for safe inspection.

### `el_sealed_cl <code>`
Clientside version of `el_sealed`.

### `el_lazy <code>`
Fills in parentheses automatically so you can skip typing them. Also supports pipes to chain operations:

```
el_lazy here - eye + there | me:SetPos
```

Is equivalent to:

```
el_run me:SetPos(here - eye + there)
```
```
el_lazy me:SetPos there
```
Is equivalent to:
```
el_run me:SetPos(there)
```

### `el_lazy_cl <code>`
Clientside version of `el_lazy`.

### `el_delete_all <class>`
Removes all entities of the given class.

### `el_spawn <class> [amount]`
Spawns one or more entities of the given class at your aim position. Defaults to 1 if no amount is given, capped at 100.

## Permission Management

EEL integrates with [CAMI](https://github.com/glua/CAMI) for compatibility with admin mods. All commands require the `superadmin` access level by default, but can be configured through any CAMI-compatible admin mod.

## Installation

1. Download the latest release as a `.zip` [file](https://github.com/Nak2/Eel/archive/refs/heads/main.zip).
2. Extract the contents.
3. Move the extracted folder into your `garrysmod/addons/` directory so the final path is `garrysmod/addons/eel/`.
4. Restart your server or client.

## Contributing

Feel free to fork and submit pull requests. For major changes, please open an issue first to discuss what you'd like to change.

## License

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file or [https://www.gnu.org/licenses/gpl-3.0.html](https://www.gnu.org/licenses/gpl-3.0.html) for details.
