# Space Platform Dashboard

All your space platforms in one table. Open it with the rocket button in the shortcut bar or **Ctrl + Shift + U**.

## Per platform

- **Location**: the planet it orbits, or the route it is travelling with a progress bar and the **arrival time**.
- **Speed** in km/s, the same value the vanilla platform panel shows.
- **Hub** health and damaged foundation tiles.
- **Cargo**: used slots and the three largest stacks.
- **Missing**: construction materials the hub is requesting for ghosts (hover for the list).
- **Trips** completed, and the hub status (paused, waiting in orbit, not enough thrust, ...).

Platforms with a problem are listed first; tick *Only problems* to hide the rest.

## Actions

**Show** the platform in remote view, **pin** its hub, or **pause/resume** it.

## Alerts (each can be turned off in the mod settings)

- **Damaged**: the hub lost health or foundation tiles are damaged.
- **Stalled**: the platform wants to leave or travel but lacks thrust for longer than 30 seconds (adjustable).
- **No path** to the destination.
- **Turrets without ammo** while travelling between planets.

## Remote interface

```lua
remote.call("space-platform-dashboard", "get_platforms") -- everything the dashboard shows, per platform
remote.call("space-platform-dashboard", "open", player_index)
```

Requires Factorio 2.1 and Space Age. MIT license.
