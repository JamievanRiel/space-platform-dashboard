-- Collects what the dashboard shows about each space platform and raises alerts for problems.
--
-- storage.platforms[index] = {
--   stall_since = tick the platform stopped moving while on a path,
--   ammo = { tick, empty } cached count of turrets without ammo,
--   alerts = { [kind] = hub entity },
-- }

local format = require("scripts.format")

local platforms = {}

local AMMO_INTERVAL = 300 -- ticks between turret scans per platform

local function reverse(enum)
  local names = {}
  for name, value in pairs(enum) do
    names[value] = name
  end
  return names
end

local STATE_NAMES = reverse(defines.space_platform_state)
local STATUS_NAMES = reverse(defines.entity_status)

local ALERTS = {
  damaged = { setting = "space-platform-dashboard-alert-damage", icon = { type = "item", name = "repair-pack" } },
  ["no-ammo"] = { setting = "space-platform-dashboard-alert-ammo", icon = { type = "item", name = "firearm-magazine" } },
  stalled = { setting = "space-platform-dashboard-alert-stalled", icon = { type = "item", name = "thruster" } },
  ["no-path"] = { setting = "space-platform-dashboard-alert-no-path", icon = { type = "item", name = "space-platform-hub" } },
}
platforms.ALERTS = ALERTS

local function state_of(index)
  local state = storage.platforms[index]
  if not state then
    state = { alerts = {} }
    storage.platforms[index] = state
  end
  return state
end

--- Missing construction materials requested by the hub: { { name, quality, count } ... }
local function missing_materials(hub)
  local missing = {}
  local points = hub.get_logistic_point()
  if not points then
    return missing
  end
  if points.object_name then
    points = { points }
  end
  for _, point in pairs(points) do
    for _, section in pairs(point.sections) do
      if section.type == defines.logistic_section_type.request_missing_materials_controlled then
        for _, filter in pairs(section.filters) do
          if filter.value and filter.min and filter.min > 0 then
            missing[#missing + 1] = { name = filter.value.name, quality = filter.value.quality, count = filter.min }
          end
        end
      end
    end
  end
  return missing
end

local function turrets_without_ammo(platform, state)
  local cache = state.ammo
  if cache and game.tick - cache.tick < AMMO_INTERVAL then
    return cache.empty
  end
  local empty = 0
  if platform.surface then
    for _, turret in pairs(platform.surface.find_entities_filtered({ type = "ammo-turret" })) do
      local inventory = turret.get_inventory(defines.inventory.turret_ammo)
      if inventory and inventory.is_empty() then
        empty = empty + 1
      end
    end
  end
  state.ammo = { tick = game.tick, empty = empty }
  return empty
end

--- Everything the dashboard shows about one platform.
function platforms.info(platform)
  local state = state_of(platform.index)
  local info = {
    index = platform.index,
    name = platform.name,
    state = STATE_NAMES[platform.state],
    paused = platform.paused,
    trips = platform.completed_trips,
    damaged_tiles = #platform.damaged_tiles,
    deleting = platform.scheduled_for_deletion > 0,
    problems = {},
  }

  local location = platform.space_location
  local connection = platform.space_connection
  if location then
    info.location = location.name
  elseif connection then
    local speed = platform.speed -- km per tick
    local distance = platform.distance or 0 -- 0 at connection.from, 1 at connection.to
    -- a connection is used in both directions; coming from its "to" end the platform travels from 1 back to 0
    local last = platform.last_visited_space_location
    local reversed = last ~= nil and last.name == connection.to.name
    local progress = reversed and (1 - distance) or distance
    info.connection = {
      from = reversed and connection.to.name or connection.from.name,
      to = reversed and connection.from.name or connection.to.name,
      progress = progress,
      length = connection.length,
      speed = speed * 60, -- km/s
    }
    if speed > 0 then
      info.connection.eta = (1 - progress) * connection.length / speed / 60 -- seconds
    end
  end

  local schedule = platform.schedule
  if schedule and schedule.records and schedule.records[schedule.current] then
    info.destination = schedule.records[schedule.current].station
  end

  local hub = platform.hub
  if hub and hub.valid then
    info.health = hub.get_health_ratio()
    info.status = STATUS_NAMES[hub.status]
    local inventory = hub.get_inventory(defines.inventory.hub_main)
    if inventory then
      info.slots = #inventory
      info.used = #inventory - inventory.count_empty_stacks(true, true)
      local contents = inventory.get_contents()
      table.sort(contents, function(a, b)
        return a.count > b.count
      end)
      info.top = {}
      for i = 1, math.min(3, #contents) do
        info.top[i] = contents[i]
      end
    end
    info.missing = missing_materials(hub)
    info.empty_turrets = turrets_without_ammo(platform, state)
  end

  -- problems
  if (info.health and info.health < 1) or info.damaged_tiles > 0 then
    info.problems.damaged = true
  end
  if connection and (info.empty_turrets or 0) > 0 then
    info.problems["no-ammo"] = true
  end
  -- stalled: it wants to leave or travel, but lacks thrust (stuck in orbit) or stopped moving on its way
  local states = defines.space_platform_state
  local trying = not platform.paused and (platform.state == states.on_the_path or platform.state == states.waiting_for_departure)
  local stuck = info.status == "not_enough_thrust" or (connection and platform.state == states.on_the_path and platform.speed <= 1e-4)
  if trying and stuck then
    state.stall_since = state.stall_since or game.tick
    if game.tick - state.stall_since >= settings.global["space-platform-dashboard-stall-seconds"].value * 60 then
      info.problems.stalled = true
    end
  else
    state.stall_since = nil
  end
  if platform.state == defines.space_platform_state.no_path then
    info.problems["no-path"] = true
  end
  info.has_problem = next(info.problems) ~= nil
  return info
end

--- Where the platform is, as a localised string.
function platforms.location_text(info)
  if info.location then
    return { "space-platform-dashboard.in-orbit", prototypes.space_location[info.location].localised_name }
  elseif info.connection then
    return {
      "space-platform-dashboard.travelling",
      prototypes.space_location[info.connection.from].localised_name,
      prototypes.space_location[info.connection.to].localised_name,
    }
  end
  return { "space-platform-dashboard.state-" .. (info.state or "unknown") }
end

local function alert_message(kind, info)
  if kind == "damaged" then
    return { "space-platform-dashboard.alert-damaged", info.name, format.percent(info.health or 1), info.damaged_tiles }
  elseif kind == "no-ammo" then
    return { "space-platform-dashboard.alert-no-ammo", info.name, info.empty_turrets }
  elseif kind == "stalled" then
    return { "space-platform-dashboard.alert-stalled", info.name }
  end
  return { "space-platform-dashboard.alert-no-path", info.name }
end

--- Adds, refreshes or removes the alerts of one platform.
function platforms.update_alerts(platform, info)
  local state = state_of(platform.index)
  local hub = platform.hub
  for kind, alert in pairs(ALERTS) do
    local active = info.problems[kind] and settings.global[alert.setting].value and hub and hub.valid
    local current = state.alerts[kind]
    if active then
      platform.force.add_custom_alert(hub, alert.icon, alert_message(kind, info), true)
      state.alerts[kind] = hub
    elseif current then
      if current.valid then
        platform.force.remove_alert({ entity = current, type = defines.alert_type.custom, icon = alert.icon })
      end
      state.alerts[kind] = nil
    end
  end
end

--- Infos of all platforms of all forces, refreshed once per second; also updates the alerts.
function platforms.refresh()
  local infos = {}
  local seen = {}
  for _, force in pairs(game.forces) do
    for index, platform in pairs(force.platforms) do
      if platform.valid then
        local info = platforms.info(platform)
        info.force_index = force.index
        infos[#infos + 1] = info
        platforms.update_alerts(platform, info)
        info.alerts = {}
        for kind in pairs(state_of(index).alerts) do
          info.alerts[#info.alerts + 1] = kind
        end
        seen[index] = true
      end
    end
  end
  for index in pairs(storage.platforms) do
    if not seen[index] then
      storage.platforms[index] = nil
    end
  end
  storage.infos = infos
  return infos
end

return platforms
