Config = {
    Debug = false,
    CommandName = "vehmenu",
    Keybind = {
        enabled = true,
        key = "U" -- The Key to opening the menu if enabled.
    },
    Translation = {
        ["tip_focus_mode"] = "Tip: Højre klik for at fokuser på gui.",
        ["tab_windows"] = "Vinduer",
        ["tab_seats"] = "Sæder",
        ["tab_miscellaneous"] = "Andet",
        ["tab_doors"] = "Døre",
    }
}

Functions = {
    HasKeys = function()
        return true
    end
}
