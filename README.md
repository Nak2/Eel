# EEL - Easy Efficient Lua

EEL (Easy Efficient Lua) is an addon designed to make Garry's Mod addon development a breeze. With EEL, you can quickly run Lua commands, interact with entities, and automate repetitive tasks with ease. Whether you're a seasoned developer or just getting started, EEL provides powerful tools to streamline your workflow.

## Function Definitions
Functions executed via `el_run` and other Lua commands will attempt to return not only the result but also the function definition along with its parameters. This helps in understanding how the function operates and in debugging.
<p align="center">
  <img src="https://github.com/user-attachments/assets/2989d9e1-32e5-4b6e-99c4-091d865901ab">
</p>

## Lua Command Returns
EEL doesn't just execute commands—it also returns values. For example:
```
el_run this
```
Will return the entity you're looking at.
```
el_run this:GetColor()
```

Will return the color of the entity.

```
el_run this:GetBonePosition(1)
```

Will return two variables: an entity and an angle.

## Features

### `el_run` Command
The `el_run` command allows you to execute Lua code effortlessly. It’s semi-smart, meaning it will try to automatically resolve nil variables by mapping them to common references:

- `me` / `self` - The player who calls the function.
- `wep` - Your current weapon.
- `trace` - Eye-trace data.
- `this` / `that` - The entity you're looking at.
- `here` - Your current location.
- `there` - The location you're aiming at.
- `near` - The nearest entity to you.

If the command encounters an unknown variable, it will search in the following order:
1. Player names
2. Entity class names
3. Entity names
4. Entity models
5. Nearest matching entity

Example:
```
el_run nak:SetPos(there)
```

### `el_run_cl` Command

This is the clientside equivalent of el_run, enabling you to run Lua code on the client.

### `el_sealed` Command

The el_sealed command runs Lua code within a custom environment, giving you more control and isolation.

### `el_sealed_cl` Command

Clientside version of el_sealed.

### `el_lazy` Command

Feeling lazy? The el_lazy command automatically fills in parentheses for you. For example:
```
el_lazy me:SetPos there
```
Is the same as:
```
el_run me:SetPos(there)
```

### `el_lazy_cl` Command

Clientside version of el_lazy.

### 'el_delete_all <entity class>' Command

This command deletes all entities of a given class on the map. It also tries to autofill nearby entities for convenience.

### 'el_spawn <entity class> <amount>' Command

Spawns a specified number of entities. By default, it spawns one entity.

## Permission Management

EEL uses "CAMI" to integrate with admin-mods, giving you control over who can use these powerful commands. By default, these commands are only accessible by superadmins.

## Installation

1. Download the latest release as a `.zip` file.
2. Extract the contents of the `.zip` file.
3. Move the extracted folder into your Garry's Mod `addons` directory. <br>The final path should look like this: `garrysmod/addons/eel/`
4. Ensure that the `eel` folder contains the `lua` folder and other necessary files for the addon.
5. Restart your server or client to load the addon.

## Contributing

Feel free to fork this repository and submit pull requests. For major changes, please open an issue first to discuss what you would like to change.
License

## License

This project is licensed under the GNU General Public License v3.0. You can view the full license in the [LICENSE](LICENSE) file.

For more details, see [https://www.gnu.org/licenses/gpl-3.0.html](https://www.gnu.org/licenses/gpl-3.0.html).