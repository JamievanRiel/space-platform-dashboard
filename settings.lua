data:extend({
  { type = "bool-setting", name = "space-platform-dashboard-alert-damage", setting_type = "runtime-global", default_value = true, order = "a" },
  { type = "bool-setting", name = "space-platform-dashboard-alert-ammo", setting_type = "runtime-global", default_value = true, order = "b" },
  { type = "bool-setting", name = "space-platform-dashboard-alert-stalled", setting_type = "runtime-global", default_value = true, order = "c" },
  { type = "bool-setting", name = "space-platform-dashboard-alert-no-path", setting_type = "runtime-global", default_value = true, order = "d" },
  {
    type = "int-setting",
    name = "space-platform-dashboard-stall-seconds",
    setting_type = "runtime-global",
    default_value = 30,
    minimum_value = 5,
    maximum_value = 3600,
    order = "e",
  },
})
