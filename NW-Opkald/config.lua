Config = {}

-- Framework: "auto", "qb", "esx", eller "none"
Config.Framework = "auto"

-- Jobs der IKKE skal trigge skud-opkald (fx politi, sheriff, etc.)
Config.AllowlistedJobs = {
    police = true,
    sheriff = true
}

-- Anti-spam cooldown per spiller (sekunder)
Config.CallCooldownSeconds = 120

-- Debounce paa client-side (millisekunder)
Config.ClientShotDebounceMs = 3000

-- Besked der sendes til tabletten
Config.CallPrefix = "Skud affyrt"
