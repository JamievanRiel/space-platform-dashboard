-- The dashboard window.
--
-- storage.guis[player_index]      = { frame, table, empty, footer }
-- storage.filters[player_index]   = { problems_only }
-- storage.locations[player_index] = last window position

local platforms = require("scripts.platforms")
local format = require("scripts.format")

local FRAME = "space_platform_dashboard"
local SHORTCUT = "space-platform-dashboard"
local COLUMNS = 9

local gui = {}

local function filters(player_index)
  local f = storage.filters[player_index]
  if not f then
    f = { problems_only = false }
    storage.filters[player_index] = f
  end
  return f
end

local function health_color(ratio)
  if ratio >= 0.99 then
    return { r = 0.3, g = 0.85, b = 0.3 }
  elseif ratio >= 0.5 then
    return { r = 0.95, g = 0.8, b = 0.2 }
  end
  return { r = 0.95, g = 0.25, b = 0.2 }
end

local function header(t, caption, tooltip)
  t.add({ type = "label", style = "space_platform_dashboard_header", caption = caption, tooltip = tooltip })
end

local function problem_tooltip(info)
  local lines = { "" }
  for kind in pairs(info.problems) do
    if #lines > 1 then
      lines[#lines + 1] = "\n"
    end
    lines[#lines + 1] = { "space-platform-dashboard.problem-" .. kind }
  end
  return lines
end

local function add_row(t, info)
  local status, tooltip = "utility/status_working", { "space-platform-dashboard.status-ok" }
  if info.has_problem then
    status, tooltip = "utility/status_not_working", problem_tooltip(info)
  elseif info.paused or info.state == "no_schedule" or info.state == "waiting_for_starter_pack" then
    status, tooltip = "utility/status_yellow", { "space-platform-dashboard.state-" .. info.state }
  end
  t.add({ type = "sprite", sprite = status, tooltip = tooltip })

  local name = t.add({ type = "flow", direction = "vertical" })
  name.style.vertical_spacing = 0
  name.add({ type = "label", style = "bold_label", caption = info.name })
  local detail = info.status and { "entity-status." .. string.gsub(info.status, "_", "-") } or { "space-platform-dashboard.state-" .. info.state }
  if info.paused then
    detail = { "space-platform-dashboard.state-paused" }
  end
  local detail_label = name.add({ type = "label", caption = detail })
  detail_label.style.font = "default-small"
  detail_label.style.font_color = { r = 0.75, g = 0.75, b = 0.75 }

  local where = t.add({ type = "flow", direction = "vertical" })
  where.style.vertical_spacing = 2
  where.add({ type = "label", caption = platforms.location_text(info) })
  if info.connection then
    local bar = where.add({ type = "progressbar", style = "space_platform_dashboard_progress", value = info.connection.progress })
    bar.tooltip = { "space-platform-dashboard.progress-tooltip", format.percent(info.connection.progress), format.number(info.connection.length) }
    if info.connection.eta and not info.paused then
      local eta = where.add({ type = "label", caption = { "space-platform-dashboard.eta", format.duration(info.connection.eta) } })
      eta.style.font = "default-small"
    end
  elseif info.destination then
    local next_stop = where.add({ type = "label", caption = { "space-platform-dashboard.next-stop", info.destination } })
    next_stop.style.font = "default-small"
  end

  -- negative while a platform without thrust drifts back; the vanilla platform panel shows the same value
  t.add({ type = "label", caption = info.connection and { "space-platform-dashboard.speed", format.number(info.connection.speed) } or "–" })

  local hub = t.add({ type = "flow", direction = "horizontal" })
  hub.style.vertical_align = "center"
  if info.health then
    local bar = hub.add({ type = "progressbar", style = "space_platform_dashboard_health", value = info.health })
    bar.style.color = health_color(info.health)
    local label = format.percent(info.health)
    if info.damaged_tiles > 0 then
      label = { "space-platform-dashboard.hub-health-tiles", label, info.damaged_tiles }
    end
    hub.add({ type = "label", caption = label })
  else
    hub.add({ type = "label", caption = "–" })
  end

  local cargo = t.add({ type = "flow", direction = "horizontal" })
  cargo.style.vertical_align = "center"
  if info.slots then
    cargo.add({ type = "label", caption = { "space-platform-dashboard.slots", info.used, info.slots } }).style.minimal_width = 52
    for _, stack in pairs(info.top or {}) do
      cargo.add({
        type = "sprite-button",
        style = "space_platform_dashboard_item",
        sprite = "item/" .. stack.name,
        number = stack.count,
        quality = stack.quality,
        elem_tooltip = { type = "item-with-quality", name = stack.name, quality = stack.quality },
      })
    end
  end

  local missing = info.missing and #info.missing or 0
  local missing_label = t.add({ type = "label", caption = missing > 0 and tostring(missing) or "–" })
  if missing > 0 then
    local lines = { "", { "space-platform-dashboard.missing-tooltip" } }
    for i, item in pairs(info.missing) do
      if i > 10 then
        break
      end
      lines[#lines + 1] = "\n[item=" .. item.name .. "] " .. item.count
    end
    missing_label.tooltip = lines
    missing_label.style.font_color = { r = 1, g = 0.8, b = 0.3 }
  end

  t.add({ type = "label", caption = tostring(info.trips) })

  local actions = t.add({ type = "flow", direction = "horizontal" })
  actions.add({ type = "sprite-button", style = "frame_action_button", sprite = "utility/search", tooltip = { "space-platform-dashboard.view" }, tags = { action = "view", index = info.index } })
  actions.add({ type = "sprite-button", style = "frame_action_button", sprite = "space-platform-dashboard-pin", tooltip = { "space-platform-dashboard.pin" }, tags = { action = "pin", index = info.index } })
  actions.add({
    type = "sprite-button",
    style = "frame_action_button",
    sprite = info.paused and "space-platform-dashboard-play" or "space-platform-dashboard-pause",
    tooltip = { info.paused and "space-platform-dashboard.resume" or "space-platform-dashboard.pause" },
    tags = { action = "pause", index = info.index },
  })
end

local function sorted_infos(player)
  local f = filters(player.index)
  local list, total = {}, 0
  for _, info in pairs(storage.infos or {}) do
    if info.force_index == player.force_index then
      total = total + 1
      if not f.problems_only or info.has_problem then
        list[#list + 1] = info
      end
    end
  end
  table.sort(list, function(a, b)
    if a.has_problem ~= b.has_problem then
      return a.has_problem
    end
    if a.name ~= b.name then
      return a.name < b.name
    end
    return a.index < b.index
  end)
  return list, total
end

function gui.refresh(player)
  local state = storage.guis[player.index]
  if not (state and state.frame.valid) then
    return
  end
  local t = state.table
  t.clear()
  header(t, "")
  header(t, { "space-platform-dashboard.column-name" })
  header(t, { "space-platform-dashboard.column-location" })
  header(t, { "space-platform-dashboard.column-speed" })
  header(t, { "space-platform-dashboard.column-hub" })
  header(t, { "space-platform-dashboard.column-cargo" })
  header(t, { "space-platform-dashboard.column-missing" }, { "space-platform-dashboard.column-missing-tooltip" })
  header(t, { "space-platform-dashboard.column-trips" })
  header(t, "")
  local list, total = sorted_infos(player)
  for _, info in pairs(list) do
    add_row(t, info)
  end
  state.empty.visible = #list == 0
  state.footer.caption = { "space-platform-dashboard.footer", #list, total }
end

function gui.open(player)
  gui.close(player)
  local f = filters(player.index)
  local frame = player.gui.screen.add({ type = "frame", name = FRAME, direction = "vertical" })

  local titlebar = frame.add({ type = "flow", direction = "horizontal", style = "frame_header_flow" })
  titlebar.drag_target = frame
  titlebar.add({ type = "label", style = "frame_title", caption = { "space-platform-dashboard.title" }, ignored_by_interaction = true })
  local drag = titlebar.add({ type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = true })
  drag.style.height = 24
  drag.style.horizontally_stretchable = true
  drag.style.right_margin = 4
  titlebar.add({ type = "sprite-button", style = "close_button", sprite = "utility/close", tags = { action = "close" } })

  local inside = frame.add({ type = "frame", style = "inside_deep_frame", direction = "vertical" })
  local toolbar = inside.add({ type = "frame", style = "subheader_frame", direction = "horizontal" })
  toolbar.style.horizontally_stretchable = true
  local problems = toolbar.add({ type = "checkbox", state = f.problems_only, caption = { "space-platform-dashboard.problems-only" }, tags = { action = "problems-only" } })
  problems.style.left_margin = 8

  local scroll = inside.add({ type = "scroll-pane", style = "naked_scroll_pane", horizontal_scroll_policy = "never" })
  scroll.style.maximal_height = 640
  scroll.style.padding = 8
  local t = scroll.add({ type = "table", style = "space_platform_dashboard_table", column_count = COLUMNS })
  local empty = scroll.add({ type = "label", caption = { "space-platform-dashboard.empty" } })
  empty.style.padding = 8

  local footer = frame.add({ type = "label" })
  footer.style.top_margin = 4

  storage.guis[player.index] = { frame = frame, table = t, empty = empty, footer = footer }
  local location = storage.locations[player.index]
  if location then
    frame.location = location
  else
    frame.force_auto_center()
  end
  player.opened = frame
  player.set_shortcut_toggled(SHORTCUT, true)
  gui.refresh(player)
end

function gui.close(player)
  local state = storage.guis[player.index]
  storage.guis[player.index] = nil
  if state and state.frame.valid then
    storage.locations[player.index] = state.frame.location
    state.frame.destroy()
  end
  local leftover = player.gui.screen[FRAME]
  if leftover then
    leftover.destroy()
  end
  player.set_shortcut_toggled(SHORTCUT, false)
end

function gui.toggle(player)
  if storage.guis[player.index] then
    gui.close(player)
  else
    gui.open(player)
  end
end

function gui.refresh_all()
  for player_index in pairs(storage.guis) do
    local player = game.get_player(player_index)
    if player then
      gui.refresh(player)
    end
  end
end

--- Whether the player already has a pin on this entity.
local function pinned(player, entity)
  for _, pin in pairs(player.get_pins()) do
    for _, target in pairs(pin.targets or {}) do
      if target == entity then
        return true
      end
    end
  end
  return false
end

local function platform_of(player, index)
  local platform = player.force.platforms[index]
  return platform and platform.valid and platform or nil
end

function gui.on_click(event)
  local element = event.element
  local action = element.valid and element.tags.action
  if not action then
    return
  end
  local player = game.get_player(event.player_index)
  if action == "close" then
    gui.close(player)
    return
  end
  local platform = element.tags.index and platform_of(player, element.tags.index)
  if not platform then
    return
  end
  if action == "view" then
    if platform.hub and platform.hub.valid then
      player.centered_on = platform.hub
    elseif platform.surface then
      player.set_controller({ type = defines.controllers.remote, surface = platform.surface, position = { 0, 0 } })
    end
  elseif action == "pin" then
    if platform.hub and platform.hub.valid and pinned(player, platform.hub) then
      player.print({ "space-platform-dashboard.already-pinned", platform.name })
    elseif platform.hub and platform.hub.valid then
      player.add_pin({ entity = platform.hub, label = platform.name })
      player.print({ "space-platform-dashboard.pinned", platform.name })
    end
  elseif action == "pause" then
    platform.paused = not platform.paused
    platforms.refresh()
    gui.refresh_all()
  end
end

function gui.on_checked(event)
  local element = event.element
  if element.valid and element.tags.action == "problems-only" then
    filters(event.player_index).problems_only = element.state
    gui.refresh(game.get_player(event.player_index))
  end
end

function gui.on_closed(event)
  local element = event.element
  if element and element.valid and element.name == FRAME then
    gui.close(game.get_player(event.player_index))
  end
end

return gui
