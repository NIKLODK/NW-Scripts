CreateThread(function()
    -- Vent til spillet er loaded
    while not NetworkIsSessionStarted() do
        Wait(0)
    end

    -- Fjern dispatch services (police, ambulance, fire)
    for i = 1, 15 do
        EnableDispatchService(i, false)
    end

    -- Fjern wanted level
    SetMaxWantedLevel(0)

    -- Gør så NPC'er ignorerer spilleren
    local playerPed = PlayerPedId()
    SetPedRelationshipGroupHash(playerPed, GetHashKey("PLAYER"))

    -- Gør gang-relations passive
    local gangs = {
        "AMBIENT_GANG_LOST",
        "AMBIENT_GANG_MEXICAN",
        "AMBIENT_GANG_FAMILY",
        "AMBIENT_GANG_BALLAS",
        "AMBIENT_GANG_MARABUNTE",
        "AMBIENT_GANG_CULT",
        "AMBIENT_GANG_SALVA",
        "AMBIENT_GANG_WEICHENG",
        "AMBIENT_GANG_HILLBILLY",
        "AMBIENT_GANG_BIKER"
    }

    for _, gang in ipairs(gangs) do
        SetRelationshipBetweenGroups(1, GetHashKey(gang), GetHashKey("PLAYER")) -- Respect
        SetRelationshipBetweenGroups(1, GetHashKey("PLAYER"), GetHashKey(gang))
    end

    -- Slå combat fra for NPC'er
    SetEveryoneIgnorePlayer(playerPed, true)
    SetPoliceIgnorePlayer(playerPed, true)

    -- Loop der konstant holder det slået fra
    while true do
        Wait(1000)

        -- Ingen emergency NPC'er
        SetCreateRandomCops(false)
        SetCreateRandomCopsNotOnScenarios(false)
        SetCreateRandomCopsOnScenarios(false)

        -- NPC'er angriber ikke
        SetPlayerWantedLevel(playerPed, 0, false)
        SetPlayerWantedLevelNow(playerPed, false)
    end
end)
