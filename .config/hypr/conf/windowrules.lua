-- Preserve named application rules, geometry strings, and XWayland drag matching.
hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})
hl.window_rule({
    name = "floating-terminal",
    match = { class = "^(floating-terminal)$" },
    float = true,
    size = "85% 85%",
    center = true,
})
hl.window_rule({
    name = "dialogs-and-pickers",
    match = { title = "^(Open File|Save File|Choose Files|Select a File|Confirm|Authentication|File Upload|Open Folder|Save As).*$" },
    float = true,
    center = true,
})
hl.window_rule({
    name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})
