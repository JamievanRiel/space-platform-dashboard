local MOD = "__space-platform-dashboard__"

data:extend({
  {
    type = "custom-input",
    name = "space-platform-dashboard-toggle",
    key_sequence = "CONTROL + SHIFT + U",
    action = "lua",
  },
  {
    type = "shortcut",
    name = "space-platform-dashboard",
    action = "lua",
    toggleable = true,
    associated_control_input = "space-platform-dashboard-toggle",
    icon = MOD .. "/graphics/shortcut-x56.png",
    icon_size = 56,
    small_icon = MOD .. "/graphics/shortcut-x24.png",
    small_icon_size = 24,
    order = "p[space-platform-dashboard]",
  },
  { type = "sprite", name = "space-platform-dashboard-pin", filename = MOD .. "/graphics/pin.png", size = 32, flags = { "gui-icon" } },
  { type = "sprite", name = "space-platform-dashboard-pause", filename = MOD .. "/graphics/pause.png", size = 32, flags = { "gui-icon" } },
  { type = "sprite", name = "space-platform-dashboard-play", filename = MOD .. "/graphics/play.png", size = 32, flags = { "gui-icon" } },
})

local styles = data.raw["gui-style"].default

styles.space_platform_dashboard_table = {
  type = "table_style",
  parent = "table_with_selection",
  horizontal_spacing = 12,
  vertical_spacing = 2,
  column_alignments = {
    { column = 4, alignment = "right" },
    { column = 7, alignment = "right" },
    { column = 8, alignment = "right" },
  },
}

styles.space_platform_dashboard_progress = {
  type = "progressbar_style",
  parent = "progressbar",
  width = 110,
  bar_width = 8,
}

styles.space_platform_dashboard_health = {
  type = "progressbar_style",
  parent = "progressbar",
  width = 70,
  bar_width = 8,
}

styles.space_platform_dashboard_header = {
  type = "label_style",
  parent = "bold_label",
  font_color = { r = 1, g = 0.9, b = 0.75 },
}

styles.space_platform_dashboard_item = {
  type = "button_style",
  parent = "slot_button",
  size = 32,
}
