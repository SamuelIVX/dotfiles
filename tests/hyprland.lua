-- Compare Lua registration behavior with the pre-migration desktop contract.
package.path = "./.config/hypr/?.lua;" .. package.path
local state

-- Compare nested values in both directions so omissions and additions both fail.
local function equal(actual, expected, path)
    path = path or "value"
    assert(type(actual) == type(expected), path .. ": type differs")
    if type(expected) ~= "table" then
        assert(actual == expected, path .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
        return
    end
    for key, value in pairs(expected) do equal(actual[key], value, path .. "." .. tostring(key)) end
    for key in pairs(actual) do assert(expected[key] ~= nil, path .. ": unexpected key " .. tostring(key)) end
end

-- Flatten hl.config tables while preserving the structured border gradient value.
local function settings(value, prefix)
    for key, item in pairs(value) do
        local name = prefix and (prefix .. "." .. key) or key
        if type(item) == "table" and not item.colors then settings(item, name)
        else state.config[name] = item end
    end
end

-- Register only APIs used by this desktop; dispatcher construction cannot execute it.
local function reset()
    state = { config = {}, env = {}, binds = {}, curves = {}, animations = {}, rules = {}, exec = {}, events = {} }
    hl = {
        config = settings,
        env = function(key, value) state.env[key] = value end,
        monitor = function(value) assert(not state.monitor); state.monitor = value end,
        gesture = function(value) assert(not state.gesture); state.gesture = value end,
        device = function(value) assert(not state.device); state.device = value end,
        curve = function(name, value) assert(not state.curves[name]); state.curves[name] = value end,
        animation = function(value) table.insert(state.animations, value) end,
        window_rule = function(value) table.insert(state.rules, value) end,
        on = function(name, callback) assert(not state.events[name]); state.events[name] = callback end,
        exec_cmd = function(command) table.insert(state.exec, command) end,
        bind = function(key, action, options)
            assert(not state.binds[key], "duplicate binding: " .. key)
            state.binds[key] = { action = action, options = options or {} }
        end,
        dsp = { window = {} },
    }
    for _, name in ipairs({ "exec_cmd", "layout", "focus" }) do
        local action_name = name
        hl.dsp[name] = function(argument) return { action_name, argument } end
    end
    for _, name in ipairs({ "close", "fullscreen", "float", "pseudo", "move", "drag", "resize" }) do
        local action_name = "window." .. name
        hl.dsp.window[name] = function(argument) return { action_name, argument } end
    end
    for name in pairs(package.loaded) do
        if name:match("^conf%.") then package.loaded[name] = nil end
    end
    dofile(".config/hypr/hyprland.lua")
end

local expected_config = {
    ["general.gaps_in"] = 5, ["general.gaps_out"] = 16, ["general.border_size"] = 2,
    ["general.col.active_border"] = { colors = { "rgba(cba6f7ee)", "rgba(b4befeee)" }, angle = 45 },
    ["general.col.inactive_border"] = "rgba(313244aa)",
    ["general.resize_on_border"] = false, ["general.allow_tearing"] = false, ["general.layout"] = "dwindle",
    ["decoration.rounding"] = 10, ["decoration.rounding_power"] = 2,
    ["decoration.active_opacity"] = 1, ["decoration.inactive_opacity"] = 0.95,
    ["decoration.shadow.enabled"] = true, ["decoration.shadow.range"] = 8,
    ["decoration.shadow.render_power"] = 3, ["decoration.shadow.color"] = "rgba(11111bee)",
    ["decoration.blur.enabled"] = true, ["decoration.blur.size"] = 5,
    ["decoration.blur.passes"] = 2, ["decoration.blur.vibrancy"] = 0.1696,
    ["render.direct_scanout"] = 1, ["misc.force_default_wallpaper"] = 0,
    ["misc.disable_hyprland_logo"] = true, ["misc.disable_hyprland_guiutils_check"] = true, ["misc.vrr"] = 1,
    ["animations.enabled"] = true, ["dwindle.preserve_split"] = true, ["master.new_status"] = "master",
    ["input.kb_layout"] = "us", ["input.kb_variant"] = "", ["input.kb_model"] = "",
    ["input.kb_options"] = "", ["input.kb_rules"] = "", ["input.follow_mouse"] = 1,
    ["input.sensitivity"] = 0, ["input.touchpad.natural_scroll"] = false,
}
local expected_binds = {}

-- Record expected key/action pairs independently of the module's registration order.
local function bind(key, action, argument, options)
    expected_binds[key] = { action = { action, argument }, options = options or {} }
end
local commands = {
    ["SUPER + Return"] = "kitty", ["SUPER + F"] = "dolphin", ["SUPER + D"] = "rofi -show drun",
    ["SUPER + M"] = "~/.config/rofi/scripts/powermenu.sh",
    ["SUPER + Escape"] = "~/.config/rofi/scripts/powermenu.sh",
    ["SUPER + SHIFT + S"] = [[sh -c 'grimblast copysave area "$HOME/Pictures/Screenshots/$(date +%F_%H-%M-%S).png"']],
    ["SUPER + W"] = "firefox", ["SUPER + N"] = "swaync-client -t -sw", ["SUPER + C"] = "code",
    ["SUPER + SHIFT + W"] = "~/.config/rofi/scripts/wifi.sh",
    ["SUPER + SHIFT + B"] = "~/.config/rofi/scripts/bluetooth.sh",
    ["SUPER + SHIFT + A"] = "~/.config/rofi/scripts/wallpaper.sh", ["SUPER + L"] = "hyprlock",
    ["SUPER + G"] = "kitty --class floating-terminal -e lazygit",
    ["SUPER + SHIFT + Escape"] = "kitty --class floating-terminal -e btop",
    ["SUPER + A"] = "~/.config/hypr/scripts/wallpaper.sh --once",
    ["SUPER + SHIFT + R"] = "~/.config/hypr/scripts/reload.sh",
    ["SUPER + R"] = "~/.config/waybar/scripts/launch.sh",
    ["SUPER + SHIFT + V"] = "~/.config/rofi/scripts/clipboard_history.sh",
}
for key, command in pairs(commands) do bind(key, "exec_cmd", command) end
bind("SUPER + Q", "window.close")
bind("SUPER + SHIFT + F", "window.fullscreen", { mode = "fullscreen", action = "toggle" })
bind("SUPER + V", "window.float", { action = "toggle" })
bind("SUPER + Space", "window.float", { action = "toggle" })
bind("SUPER + P", "window.pseudo", { action = "toggle" })
bind("SUPER + J", "layout", "togglesplit")
for _, direction in ipairs({ "left", "right", "up", "down" }) do
    bind("SUPER + " .. direction, "focus", { direction = direction })
end
for key, workspace in pairs({ ["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5,
    ["6"] = 6, ["7"] = 7, ["8"] = 8, ["9"] = 9, ["0"] = 10 }) do
    bind("SUPER + " .. key, "focus", { workspace = workspace })
    bind("SUPER + SHIFT + " .. key, "window.move", { workspace = workspace, follow = true })
end
bind("SUPER + mouse_down", "focus", { workspace = "e+1" })
bind("SUPER + mouse_up", "focus", { workspace = "e-1" })
bind("SUPER + mouse:272", "window.drag")
bind("SUPER + mouse:273", "window.resize")
for key, command in pairs({
    XF86AudioRaiseVolume = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+",
    XF86AudioLowerVolume = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
    XF86AudioMute = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    XF86AudioMicMute = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
    XF86MonBrightnessUp = "brightnessctl -e4 -n2 set 5%+",
    XF86MonBrightnessDown = "brightnessctl -e4 -n2 set 5%-",
}) do bind(key, "exec_cmd", command, { locked = true, repeating = true }) end
for key, command in pairs({ XF86AudioNext = "next", XF86AudioPause = "play-pause",
    XF86AudioPlay = "play-pause", XF86AudioPrev = "previous" }) do
    bind(key, "exec_cmd", "playerctl " .. command, { locked = true })
end

reset()
equal(state.config, expected_config, "settings")
equal(state.env, { XCURSOR_SIZE = "24", HYPRCURSOR_SIZE = "24", GDK_BACKEND = "wayland,x11,*",
    QT_QPA_PLATFORM = "wayland;xcb", QT_AUTO_SCREEN_SCALE_FACTOR = "1",
    ELECTRON_OZONE_PLATFORM_HINT = "auto", CLUTTER_BACKEND = "wayland" }, "environment")
equal(state.monitor, { output = "", mode = "preferred", position = "auto", scale = "auto", vrr = 1 })
equal(state.gesture, { fingers = 3, direction = "horizontal", action = "workspace" })
equal(state.device, { name = "epic-mouse-v1", sensitivity = -0.5 })
equal(state.binds, expected_binds, "bindings")
local binding_count = 0
for _ in pairs(state.binds) do binding_count = binding_count + 1 end
assert(binding_count == 63)
local curves = { easeOutQuint = { {0.23, 1}, {0.32, 1} }, easeInOutCubic = { {0.65, 0.05}, {0.36, 1} },
    linear = { {0, 0}, {1, 1} }, almostLinear = { {0.5, 0.5}, {0.75, 1} }, quick = { {0.15, 0}, {0.1, 1} } }
local expected_curves = {}
for name, points in pairs(curves) do expected_curves[name] = { type = "bezier", points = points } end
equal(state.curves, expected_curves, "curves")
local animations = {
    {"global", 10, "default"}, {"border", 5.39, "easeOutQuint"}, {"windows", 4.79, "easeOutQuint"},
    {"windowsIn", 4.1, "easeOutQuint", "popin 87%"}, {"windowsOut", 1.49, "linear", "popin 87%"},
    {"fadeIn", 1.73, "almostLinear"}, {"fadeOut", 1.46, "almostLinear"}, {"fade", 3.03, "quick"},
    {"layers", 3.81, "easeOutQuint"}, {"layersIn", 4, "easeOutQuint", "fade"},
    {"layersOut", 1.5, "linear", "fade"}, {"fadeLayersIn", 1.79, "almostLinear"},
    {"fadeLayersOut", 1.39, "almostLinear"}, {"workspaces", 4, "easeOutQuint", "slidefade 20%"},
    {"zoomFactor", 7, "quick"},
}
local expected_animations = {}
for _, value in ipairs(animations) do
    table.insert(expected_animations, { leaf = value[1], enabled = true, speed = value[2], bezier = value[3], style = value[4] })
end
equal(state.animations, expected_animations, "animations")
equal(state.rules, {
    { name = "suppress-maximize-events", match = { class = ".*" }, suppress_event = "maximize" },
    { name = "floating-terminal", match = { class = "^(floating-terminal)$" }, float = true, size = "85% 85%", center = true },
    { name = "dialogs-and-pickers", match = { title = "^(Open File|Save File|Choose Files|Select a File|Confirm|Authentication|File Upload|Open Folder|Save As).*$" }, float = true, center = true },
    { name = "fix-xwayland-drags", match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false }, no_focus = true },
}, "rules")
equal(state.exec, {}, "evaluation must not launch commands")
assert(state.events["hyprland.start"])
assert(next(state.events, "hyprland.start") == nil)
state.events["hyprland.start"]()
equal(state.exec, {
    "nm-applet --indicator", "~/.config/waybar/scripts/launch.sh --start & awww-daemon", "swaync", "hypridle",
    "~/.config/hypr/scripts/wallpaper.sh", "wl-paste --watch cliphist store",
    "/usr/libexec/kf6/polkit-kde-authentication-agent-1",
}, "startup")
-- Hyprland clears user modules and registrations before each reload; emulate that boundary.
reset()
equal(state.binds, expected_binds, "bindings after reload")
equal(state.exec, {}, "reload must not launch commands")
print("Hyprland Lua preservation checks passed (63 bindings)")
