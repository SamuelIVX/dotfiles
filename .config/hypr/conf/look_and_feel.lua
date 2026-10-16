-- Preserve Catppuccin Mocha decoration and the existing rendering policy.
hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 16,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(cba6f7ee)", "rgba(b4befeee)" }, angle = 45 },
            inactive_border = "rgba(313244aa)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 0.95,
        shadow = { enabled = true, range = 8, render_power = 3, color = "rgba(11111bee)" },
        blur = { enabled = true, size = 5, passes = 2, vibrancy = 0.1696 },
    },
    render = { direct_scanout = 1 },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_hyprland_guiutils_check = true,
        vrr = 1,
    },
})
