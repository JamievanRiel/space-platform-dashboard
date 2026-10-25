-- Space Platform Dashboard: all space platforms in one table, with alerts for platforms in trouble.

local platforms = require("scripts.platforms")
local gui = require("scripts.gui")

local REFRESH_INTERVAL = 60

local function init_storage()
  storage.platforms = storage.platforms or {}
  storage.guis = storage.guis or {}
  storage.filters = storage.filters or {}
  storage.locations = storage.locations or {}
end

script.on_init(init_storage)

script.on_configuration_changed(function()
  init_storage()
  for _, player in pairs(game.players) do
    gui.close(player)
  end
end)

script.on_nth_tick(REFRESH_INTERVAL, function()
  platforms.refresh()
  gui.refresh_all()
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name == "space-platform-dashboard" then
    gui.toggle(game.get_player(event.player_index))
  end
end)

script.on_event("space-platform-dashboard-toggle", function(event)
  gui.toggle(game.get_player(event.player_index))
end)

--- Only GUI events of elements created by this mod (other mods may use the same tag names).
local function own(handler)
  return function(event)
    local element = event.element
    if element and element.valid and element.get_mod() == script.mod_name then
      handler(event)
    end
  end
end

script.on_event(defines.events.on_gui_click, own(gui.on_click))
script.on_event(defines.events.on_gui_checked_state_changed, own(gui.on_checked))
script.on_event(defines.events.on_gui_closed, own(gui.on_closed))

script.on_event(defines.events.on_player_left_game, function(event)
  gui.close(game.get_player(event.player_index)) -- otherwise a frozen window is waiting after rejoining
end)

script.on_event(defines.events.on_player_removed, function(event)
  storage.guis[event.player_index] = nil
  storage.filters[event.player_index] = nil
  storage.locations[event.player_index] = nil
end)

-- Alerts are only removed for connected players. Drop this mod's alerts when somebody joins; the ones that are
-- still valid come back within a second.
script.on_event(defines.events.on_player_joined_game, function(event)
  local player = game.get_player(event.player_index)
  for _, by_type in pairs(player.get_alerts({ type = defines.alert_type.custom })) do
    for _, alerts in pairs(by_type) do
      for _, alert in pairs(alerts) do
        local key = type(alert.message) == "table" and alert.message[1]
        if type(key) == "string" and string.sub(key, 1, 31) == "space-platform-dashboard.alert-" and alert.target then
          player.remove_alert({ entity = alert.target, type = defines.alert_type.custom, icon = alert.icon })
        end
      end
    end
  end
end)

remote.add_interface("space-platform-dashboard", {
  --- What the dashboard knows about every platform, refreshed on the spot.
  get_platforms = function()
    return platforms.refresh()
  end,
  open = function(player_index)
    local player = game.get_player(player_index)
    if player then
      platforms.refresh()
      gui.open(player)
    end
  end,
})
