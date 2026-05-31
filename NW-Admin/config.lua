Config = {}

Config.OpenCommand = 'adminpanel'
Config.DefaultKey = 'F10'
Config.MenuPosition = 'top-right'

Config.RequireAce = false
Config.AcePermission = 'nwadmin.use'

Config.AllowedGroups = {
    superadmin = true,
    admin = true,
    mod = true
}

Config.Messages = {
    noPermission = 'Du har ikke adgang til adminpanelet.',
    playerNotFound = 'Spilleren blev ikke fundet.',
    inventoryUnavailable = 'ox_inventory er ikke startet.',
    actionDone = 'Handling udfort.',
    actionFailed = 'Handlingen fejlede.'
}
