local ESX = exports["es_extended"]:getSharedObject()

local gangColumns = nil

local function ensureGangColumns(cb)
    if gangColumns then
        cb(gangColumns)
        return
    end
    MySQL.query('SHOW COLUMNS FROM gangs', {}, function(cols)
        gangColumns = {}
        if cols then
            for i = 1, #cols do
                gangColumns[cols[i].Field] = true
            end
        end
        cb(gangColumns)
    end)
end

local function decodeSkills(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) == 'string' and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            return decoded
        end
    end
    return {}
end

local getMembersLevel
local getEupLevel

local function normalizeSkills(gangRow)
    local set = {}
    local list = decodeSkills(gangRow.unlocked_skills)
    for _, skill in ipairs(list) do
        set[skill] = true
    end
    if tonumber(gangRow.has_zones) and tonumber(gangRow.has_zones) > 0 then set["zones"] = true end

    local membersLevel = getMembersLevel(gangRow)
    for i = 1, membersLevel do
        set["members_"..i] = true
    end

    local eupLevel = getEupLevel(gangRow)
    for i = 1, eupLevel do
        set["eup_"..i] = true
    end
    set["start"] = true

    local out = {}
    for skill in pairs(set) do
        table.insert(out, skill)
    end
    return out
end

local function skillsContains(skills, target)
    for i = 1, #skills do
        if skills[i] == target then
            return true
        end
    end
    return false
end

local function addGangXp(gangId, amount, cb)
    ensureGangColumns(function(cols)
        if not cols["xp"] and not cols["level"] then
            if cb then cb(false) end
            return
        end
        MySQL.single('SELECT xp, level FROM gangs WHERE id = ?', {gangId}, function(row)
            local xp = tonumber(row and row.xp) or 0
            local level = tonumber(row and row.level) or 1
            local startLevel = level
            xp = xp + amount

            local leveledUp = false
            local needed = math.max(100, level * 100)
            while xp >= needed do
                xp = xp - needed
                level = level + 1
                needed = math.max(100, level * 100)
                leveledUp = true
            end

            if cols["xp"] and cols["level"] then
                MySQL.update('UPDATE gangs SET xp = ?, level = ? WHERE id = ?', {xp, level, gangId})
            elseif cols["xp"] then
                MySQL.update('UPDATE gangs SET xp = ? WHERE id = ?', {xp, gangId})
            elseif cols["level"] then
                MySQL.update('UPDATE gangs SET level = ? WHERE id = ?', {level, gangId})
            end

            local gainedLevels = math.max(0, level - startLevel)
            if gainedLevels > 0 and cols["skill_points"] then
                MySQL.update('UPDATE gangs SET skill_points = skill_points + ? WHERE id = ?', {gainedLevels, gangId})
            end

            if cb then cb(true, level, xp, leveledUp) end
        end)
    end)
end

local skillConfig = {
    zones = { column = "has_zones" }
}

local function syncZoneGangAccess(gangName)
    if type(gangName) ~= 'string' or gangName == '' then
        return
    end

    if GetResourceState('visualz_zones') == 'started' then
        pcall(function()
            exports["visualz_zones"]:RegisterGang(gangName)
        end)
    end

    if GetResourceState('at-bande') == 'started' then
        pcall(function()
            exports["at-bande"]:RegisterGang(gangName)
        end)
    end
end

local MEMBERS_MAX_LEVEL = 5
local EUP_MAX_LEVEL = 5
local MEMBER_SLOTS_PER_LEVEL = 5

local SKILL_POINT_COST = 1


local function parseLevelSkill(skillType, prefix, maxLevel)
    if type(skillType) ~= 'string' then return nil end
    local level = tonumber(skillType:match('^'..prefix..'_(%d+)$'))
    if not level or level < 1 or level > maxLevel then
        return nil
    end
    return level
end

getMembersLevel = function(gangRow)
    local level = tonumber(gangRow.members_level)
    if not level then
        local extra = tonumber(gangRow.extra_members) or 0
        if extra > 0 and extra < MEMBER_SLOTS_PER_LEVEL then
            level = 1
        else
            level = math.floor(extra / MEMBER_SLOTS_PER_LEVEL)
        end
    end
    if level < 0 then level = 0 end
    if level > MEMBERS_MAX_LEVEL then level = MEMBERS_MAX_LEVEL end
    return level
end

getEupLevel = function(gangRow)
    local level = tonumber(gangRow.eup_level)
    if not level then
        local legacy = tonumber(gangRow.has_eup) or 0
        level = math.floor(legacy)
    end
    if level < 0 then level = 0 end
    if level > EUP_MAX_LEVEL then level = EUP_MAX_LEVEL end
    return level
end

local missions = {}
local missionOrder = {}

local function registerMission(missionId, data)
    missionId = tonumber(missionId)
    if not missionId or missionId <= 0 or type(data) ~= 'table' then
        return false, 'invalid_args'
    end

    local title = tostring(data.title or ('Mission #'..missionId))
    local desc = tostring(data.desc or 'Fuldfør missionen i det tilknyttede script.')
    local sourceScript = tostring(data.source or 'Ukendt script')
    local rewardText = data.rewardText and tostring(data.rewardText) or nil
    local money = tonumber(data.money) or 0
    local xp = tonumber(data.xp) or 0

    missions[missionId] = {
        id = missionId,
        title = title,
        desc = desc,
        source = sourceScript,
        rewardText = rewardText,
        money = money,
        xp = xp
    }

    local exists = false
    for i = 1, #missionOrder do
        if missionOrder[i] == missionId then
            exists = true
            break
        end
    end
    if not exists then
        table.insert(missionOrder, missionId)
        table.sort(missionOrder)
    end

    return true
end

registerMission(201, {
    title = "Butiksrøveri",
    desc = "Fuldfør et butiksrøveri.",
    source = "NW-Storerobbery",
    money = 5000,
    xp = 50,
    rewardText = "Belønning gives ved fuldførelse."
})

registerMission(202, {
    title = "Skraldemand route",
    desc = "Fuldfør en skraldemand route.",
    source = "Trasherjob",
    money = 7500,
    xp = 25,
    rewardText = "Belønning gives ved fuldførelse."
})

registerMission(99, {
    title = "Hvidvask mission",
    desc = "Fuldfør en hvidvask.",
    source = "NW-Laundering",
    money = 0,
    xp = 10,
    rewardText = "Beløb afhænger af sorte penge."
})

local MISSION_START_INTERVAL_SECONDS = 15 * 60
local MISSION_FULL_CLEAR_COOLDOWN_SECONDS = 60 * 60
local gangMissionStates = {}

local function formatSeconds(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then
        return string.format('%dt %dm', h, m)
    end
    return string.format('%02d:%02d', m, s)
end

local function getGangMissionState(gangId)
    local state = gangMissionStates[gangId]
    if not state then
        state = {
            activeMissionId = 0,
            nextMissionAt = 0,
            cycleCooldownUntil = 0,
            completed = {}
        }
        gangMissionStates[gangId] = state
    end
    return state
end

local function normalizeMissionState(state)
    local now = os.time()
    if state.cycleCooldownUntil and state.cycleCooldownUntil > 0 and now >= state.cycleCooldownUntil then
        state.cycleCooldownUntil = 0
        state.nextMissionAt = 0
        state.activeMissionId = 0
        state.completed = {}
    end
    if state.nextMissionAt and state.nextMissionAt > 0 and now >= state.nextMissionAt and (not state.activeMissionId or state.activeMissionId == 0) then
        state.nextMissionAt = 0
    end
end

local function allCycleMissionsCompleted(state)
    if #missionOrder == 0 then
        return false
    end
    for missionId, _ in pairs(missions) do
        if not state.completed[missionId] then
            return false
        end
    end
    return true
end

local function buildMissionCatalog()
    local out = {}
    for i = 1, #missionOrder do
        local missionId = missionOrder[i]
        local mission = missions[missionId]
        if mission then
            out[#out + 1] = {
                id = mission.id,
                title = mission.title,
                desc = mission.desc,
                rewardText = mission.rewardText
            }
        end
    end
    return out
end

local function buildMissionStatePayload(gangId)
    local state = getGangMissionState(gangId)
    normalizeMissionState(state)
    local completed = {}
    for missionId, done in pairs(state.completed) do
        if done then
            table.insert(completed, missionId)
        end
    end
    table.sort(completed)
    return {
        missions = buildMissionCatalog(),
        completedMissionIds = completed,
        activeMissionId = tonumber(state.activeMissionId) or 0,
        nextMissionAt = tonumber(state.nextMissionAt) or 0,
        cycleCooldownUntil = tonumber(state.cycleCooldownUntil) or 0,
        missionIntervalSeconds = MISSION_START_INTERVAL_SECONDS,
        cycleCooldownSeconds = MISSION_FULL_CLEAR_COOLDOWN_SECONDS
    }
end

local CREATE_GANG_RANKS_TABLE_SQL = [[
    CREATE TABLE IF NOT EXISTS gang_ranks (
        id INT NOT NULL AUTO_INCREMENT,
        gang_id INT NOT NULL,
        rank_name VARCHAR(24) NOT NULL,
        rank_order INT NOT NULL,
        can_invite TINYINT(1) NOT NULL DEFAULT 0,
        can_start_mission TINYINT(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (id),
        UNIQUE KEY uq_gang_rank_name (gang_id, rank_name),
        UNIQUE KEY uq_gang_rank_order (gang_id, rank_order),
        KEY idx_gang_ranks_gang (gang_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

MySQL.query(CREATE_GANG_RANKS_TABLE_SQL)

local rankColumns = nil

local function ensureRankColumns(cb)
    if rankColumns then
        cb(rankColumns)
        return
    end

    MySQL.query(CREATE_GANG_RANKS_TABLE_SQL, {}, function()
    MySQL.query('SHOW COLUMNS FROM gang_ranks', {}, function(cols)
        local found = {}
        if cols then
            for i = 1, #cols do
                found[cols[i].Field] = true
            end
        end

        local alterParts = {}
        if not found['can_invite'] then
            alterParts[#alterParts + 1] = 'ADD COLUMN can_invite TINYINT(1) NOT NULL DEFAULT 0'
        end
        if not found['can_start_mission'] then
            alterParts[#alterParts + 1] = 'ADD COLUMN can_start_mission TINYINT(1) NOT NULL DEFAULT 0'
        end

        if #alterParts > 0 then
            MySQL.query('ALTER TABLE gang_ranks '..table.concat(alterParts, ', '), {}, function()
                rankColumns = nil
                ensureRankColumns(cb)
            end)
            return
        end

        rankColumns = found
        cb(rankColumns)
    end)
    end)
end

local DEFAULT_GANG_RANKS = {
    { name = "Ejer", can_invite = 1, can_start_mission = 1, locked = true },
    { name = "Næstkommanderende", can_invite = 1, can_start_mission = 1 },
    { name = "Medlem", can_invite = 0, can_start_mission = 0 }
}

local function trimString(value)
    value = tostring(value or "")
    return value:match("^%s*(.-)%s*$")
end

local function normalizeRankName(rankName)
    local normalized = trimString(rankName):gsub("%s+", " ")
    if normalized == "" then
        return nil
    end
    if #normalized > 24 then
        normalized = normalized:sub(1, 24)
    end
    return normalized
end

local function loadGangRanks(gangId, cb)
    ensureRankColumns(function()
        MySQL.query('SELECT rank_name, rank_order, can_invite, can_start_mission FROM gang_ranks WHERE gang_id = ? ORDER BY rank_order ASC', { gangId }, function(rows)
            rows = rows or {}
            table.sort(rows, function(a, b)
                return (tonumber(a.rank_order) or 0) < (tonumber(b.rank_order) or 0)
            end)
            cb(rows)
        end)
    end)
end

local function ensureGangRanks(gangId, cb)
    loadGangRanks(gangId, function(rows)
        if #rows > 0 then
            cb(rows)
            return
        end

        local pending = #DEFAULT_GANG_RANKS
        if pending == 0 then
            cb({})
            return
        end

        for index, rankData in ipairs(DEFAULT_GANG_RANKS) do
            MySQL.insert('INSERT INTO gang_ranks (gang_id, rank_name, rank_order, can_invite, can_start_mission) VALUES (?, ?, ?, ?, ?)', {
                gangId,
                rankData.name,
                index,
                tonumber(rankData.can_invite) or 0,
                tonumber(rankData.can_start_mission) or 0
            }, function()
                pending = pending - 1
                if pending == 0 then
                    loadGangRanks(gangId, cb)
                end
            end)
        end
    end)
end

local function toDbBool(value)
    if value == true then
        return true
    end
    if value == false or value == nil then
        return false
    end

    local num = tonumber(value)
    if num ~= nil then
        return num > 0
    end

    if type(value) == 'string' then
        local lowered = string.lower(value)
        return lowered == 'true' or lowered == 'yes' or lowered == 'on'
    end

    return false
end

local function mapRanksForClient(rows)
    local out = {}
    for i = 1, #rows do
        local row = rows[i]
        out[#out + 1] = {
            name = row.rank_name,
            order = tonumber(row.rank_order) or i,
            canInvite = toDbBool(row.can_invite),
            canStartMission = toDbBool(row.can_start_mission),
            locked = (row.rank_name == 'Ejer')
        }
    end
    return out
end

local function mapRankNames(rows)
    local names = {}
    for i = 1, #rows do
        names[#names + 1] = rows[i].rank_name
    end
    return names
end

local function findRankIndex(rankNames, rankName)
    for i = 1, #rankNames do
        if rankNames[i] == rankName then
            return i
        end
    end
    return nil
end

local function findRankRow(rows, rankName)
    local target = string.lower(tostring(rankName or ''))
    for i = 1, #rows do
        if string.lower(rows[i].rank_name or '') == target then
            return rows[i], i
        end
    end
    return nil, nil
end

local function getGangContextForPlayer(xPlayer, cb)
    if not xPlayer then
        cb(nil, nil, false)
        return
    end

    MySQL.scalar('SELECT gang_id FROM users WHERE identifier = ?', { xPlayer.identifier }, function(gangId)
        gangId = tonumber(gangId)
        if not gangId or gangId == 0 then
            cb(nil, nil, false)
            return
        end

        MySQL.single('SELECT id, owner, name FROM gangs WHERE id = ?', { gangId }, function(gang)
            if not gang then
                cb(nil, nil, false)
                return
            end
            cb(gangId, gang, gang.owner == xPlayer.identifier)
        end)
    end)
end

local function hasGangPermission(xPlayer, permissionColumn, cb)
    getGangContextForPlayer(xPlayer, function(gangId, gangData, isOwner)
        if not gangId or not gangData then
            cb(nil, nil, false, false, nil)
            return
        end

        if isOwner then
            cb(gangId, gangData, true, true, 'Ejer')
            return
        end

        MySQL.single('SELECT rank FROM members WHERE identifier = ? AND gang_id = ?', {
            xPlayer.identifier, gangId
        }, function(memberRow)
            local memberRank = memberRow and memberRow.rank or nil
            if not memberRank then
                cb(gangId, gangData, false, false, nil)
                return
            end

            ensureGangRanks(gangId, function(rows)
                local allowed = false
                for i = 1, #rows do
                    local row = rows[i]
                    if row.rank_name == memberRank then
                        allowed = toDbBool(row[permissionColumn])
                        break
                    end
                end
                cb(gangId, gangData, false, allowed, memberRank)
            end)
        end)
    end)
end

local function getPlayerGangId(identifier, cb)
    MySQL.scalar('SELECT gang_id FROM users WHERE identifier = ?', {identifier}, function(gangId)
        gangId = tonumber(gangId)
        if not gangId or gangId == 0 then
            cb(nil)
            return
        end
        cb(gangId)
    end)
end

-- Hent bande data (Level, Navn, Join Code osv.)
ESX.RegisterServerCallback('NW-Bande:getGangData', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.single('SELECT g.* FROM gangs g INNER JOIN users u ON u.gang_id = g.id WHERE u.identifier = ?', {
        xPlayer.identifier
    }, function(result)
        if result then
            result.unlocked_skills = normalizeSkills(result)
            if result.skill_points == nil then result.skill_points = 0 end
        end
        cb(result)
    end)
end)

-- Hent medlemmer til tabletten
ESX.RegisterServerCallback('gangSystem:getMembers', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    -- Vi tjekker users tabellen for at se om spilleren overhovedet har en bande
    MySQL.scalar('SELECT gang_id FROM users WHERE identifier = ?', {xPlayer.identifier}, function(gangId)
        -- Hvis de er "unemployed" (gang_id er NULL eller 0), returnerer vi en tom liste med det samme
        if not gangId or gangId == 0 then 
            return cb({}) 
        end

        -- Nu henter vi fra den RIGTIGE tabel: 'members' (som vi oprettede tidligere)
        MySQL.query('SELECT name, identifier, rank FROM members WHERE gang_id = ?', {gangId}, function(results)
            local members = {}
            if results then
                for i=1, #results do
                    local isOnline = (ESX.GetPlayerFromIdentifier(results[i].identifier) ~= nil)
                    table.insert(members, {
                        name = results[i].name,
                        rank = results[i].rank,
                        identifier = results[i].identifier,
                        online = isOnline
                    })
                end
            end
            cb(members)
        end)
    end)
end)

ESX.RegisterServerCallback('NW-Bande:getGangRanks', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    getGangContextForPlayer(xPlayer, function(gangId)
        if not gangId then
            cb({ success = false, ranks = {} })
            return
        end

        ensureGangRanks(gangId, function(rows)
            cb({ success = true, ranks = mapRanksForClient(rows) })
        end)
    end)
end)

ESX.RegisterServerCallback('NW-Bande:createGangRank', function(source, cb, rankName)
    local xPlayer = ESX.GetPlayerFromId(source)
    local normalizedName = normalizeRankName(rankName)

    if not normalizedName then
        TriggerClientEvent('lation_ui:notify', source, {title = 'Fejl', message = 'Indtast et gyldigt rangnavn.', type = 'error'})
        cb({ success = false })
        return
    end

    getGangContextForPlayer(xPlayer, function(gangId, gangData, isOwner)
        if not gangId or not gangData then
            cb({ success = false })
            return
        end

        if not isOwner then
            TriggerClientEvent('lation_ui:notify', source, {title = 'Fejl', message = 'Kun bandeejeren kan oprette ranks.', type = 'error'})
            cb({ success = false })
            return
        end

        ensureGangRanks(gangId, function(rows)
            if #rows >= 12 then
                TriggerClientEvent('lation_ui:notify', source, {title = 'Fejl', message = 'Maks antal ranks er nået.', type = 'error'})
                cb({ success = false })
                return
            end

            local lowerName = string.lower(normalizedName)
            for i = 1, #rows do
                if string.lower(rows[i].rank_name) == lowerName then
                    TriggerClientEvent('lation_ui:notify', source, {title = 'Fejl', message = 'Rang findes allerede.', type = 'error'})
                    cb({ success = false })
                    return
                end
            end

            local insertOrder = #rows + 1
            for i = 1, #rows do
                if string.lower(rows[i].rank_name) == 'medlem' then
                    insertOrder = tonumber(rows[i].rank_order) or i
                    break
                end
            end

            MySQL.update('UPDATE gang_ranks SET rank_order = rank_order + 1 WHERE gang_id = ? AND rank_order >= ?', {
                gangId, insertOrder
            }, function()
                MySQL.insert('INSERT INTO gang_ranks (gang_id, rank_name, rank_order, can_invite, can_start_mission) VALUES (?, ?, ?, ?, ?)', {
                    gangId, normalizedName, insertOrder, 0, 0
                }, function(insertId)
                    if not insertId then
                        TriggerClientEvent('lation_ui:notify', source, {title = 'Fejl', message = 'Kunne ikke oprette rang.', type = 'error'})
                        cb({ success = false })
                        return
                    end

                    ensureGangRanks(gangId, function(updatedRows)
                        TriggerClientEvent('lation_ui:notify', source, {title = 'Bekræftet', message = 'Rang oprettet: '..normalizedName, type = 'success'})
                        cb({ success = true, ranks = mapRanksForClient(updatedRows) })
                    end)
                end)
            end)
        end)
    end)
end)

ESX.RegisterServerCallback('NW-Bande:deleteGangRank', function(source, cb, rankName)
    local xPlayer = ESX.GetPlayerFromId(source)
    local normalizedName = normalizeRankName(rankName)
    if not normalizedName then
        cb({ success = false })
        return
    end

    getGangContextForPlayer(xPlayer, function(gangId, gangData, isOwner)
        if not gangId or not gangData then
            cb({ success = false })
            return
        end

        if not isOwner then
            TriggerClientEvent('lation_ui:notify', source, {title = 'Fejl', message = 'Kun bandeejeren kan slette ranks.', type = 'error'})
            cb({ success = false })
            return
        end

        ensureGangRanks(gangId, function(rows)
            local rankRow, rankIndex = findRankRow(rows, normalizedName)
            if not rankRow then
                cb({ success = false })
                return
            end

            if rankRow.rank_name == 'Ejer' then
                TriggerClientEvent('lation_ui:notify', source, {title = 'Fejl', message = 'Ejer-rank kan ikke slettes.', type = 'error'})
                cb({ success = false })
                return
            end

            if #rows <= 2 then
                TriggerClientEvent('lation_ui:notify', source, {title = 'Fejl', message = 'Der skal være mindst to ranks i banden.', type = 'error'})
                cb({ success = false })
                return
            end

            local fallback = rows[math.min(rankIndex + 1, #rows)] or rows[math.max(rankIndex - 1, 1)]
            local fallbackName = fallback and fallback.rank_name or 'Medlem'
            if fallbackName == rankRow.rank_name then
                fallbackName = 'Medlem'
            end

            local removedOrder = tonumber(rankRow.rank_order) or rankIndex
            MySQL.update('UPDATE members SET rank = ? WHERE gang_id = ? AND rank = ?', {
                fallbackName, gangId, rankRow.rank_name
            }, function()
                MySQL.update('DELETE FROM gang_ranks WHERE gang_id = ? AND rank_name = ?', {
                    gangId, rankRow.rank_name
                }, function(affectedRows)
                    if not affectedRows or affectedRows < 1 then
                        cb({ success = false })
                        return
                    end

                    MySQL.update('UPDATE gang_ranks SET rank_order = rank_order - 1 WHERE gang_id = ? AND rank_order > ?', {
                        gangId, removedOrder
                    }, function()
                        ensureGangRanks(gangId, function(updatedRows)
                            TriggerClientEvent('lation_ui:notify', source, {title = 'Bekræftet', message = 'Rang slettet: '..rankRow.rank_name, type = 'success'})
                            cb({ success = true, ranks = mapRanksForClient(updatedRows) })
                        end)
                    end)
                end)
            end)
        end)
    end)
end)

ESX.RegisterServerCallback('NW-Bande:setRankPermission', function(source, cb, rankName, permissionKey, allowed)
    local xPlayer = ESX.GetPlayerFromId(source)
    local normalizedName = normalizeRankName(rankName)
    local key = tostring(permissionKey or '')
    local column = nil
    if key == 'invite' then column = 'can_invite' end
    if key == 'mission' then column = 'can_start_mission' end
    if not normalizedName or not column then
        cb({ success = false })
        return
    end

    getGangContextForPlayer(xPlayer, function(gangId, gangData, isOwner)
        if not gangId or not gangData then
            cb({ success = false })
            return
        end

        if not isOwner then
            TriggerClientEvent('lation_ui:notify', source, {title = 'Fejl', message = 'Kun bandeejeren kan ændre permissions.', type = 'error'})
            cb({ success = false })
            return
        end

        ensureGangRanks(gangId, function(rows)
            local rankRow = findRankRow(rows, normalizedName)
            if not rankRow then
                cb({ success = false })
                return
            end

            if rankRow.rank_name == 'Ejer' then
                TriggerClientEvent('lation_ui:notify', source, {title = 'Fejl', message = 'Ejer har altid fulde rettigheder.', type = 'info'})
                cb({ success = false })
                return
            end

            local value = toDbBool(allowed) and 1 or 0
            MySQL.update('UPDATE gang_ranks SET '..column..' = ? WHERE gang_id = ? AND rank_name = ?', {
                value, gangId, rankRow.rank_name
            }, function(affectedRows)
                if affectedRows == nil then
                    cb({ success = false })
                    return
                end

                ensureGangRanks(gangId, function(updatedRows)
                    cb({ success = true, ranks = mapRanksForClient(updatedRows) })
                end)
            end)
        end)
    end)
end)

ESX.RegisterServerCallback('NW-Bande:moveGangRank', function(source, cb, rankName, direction)
    local xPlayer = ESX.GetPlayerFromId(source)
    local normalizedName = normalizeRankName(rankName)
    direction = tostring(direction or '')
    if not normalizedName or (direction ~= 'up' and direction ~= 'down') then
        cb({ success = false })
        return
    end

    getGangContextForPlayer(xPlayer, function(gangId, gangData, isOwner)
        if not gangId or not gangData then
            cb({ success = false })
            return
        end

        if not isOwner then
            TriggerClientEvent('lation_ui:notify', source, {title = 'Fejl', message = 'Kun bandeejeren kan flytte ranks.', type = 'error'})
            cb({ success = false })
            return
        end

        ensureGangRanks(gangId, function(rows)
            local currentRow, currentIndex = findRankRow(rows, normalizedName)
            if not currentRow then
                cb({ success = false })
                return
            end

            if currentRow.rank_name == 'Ejer' then
                TriggerClientEvent('lation_ui:notify', source, {title = 'Fejl', message = 'Ejer-rank kan ikke flyttes.', type = 'error'})
                cb({ success = false })
                return
            end

            local targetIndex = direction == 'up' and (currentIndex - 1) or (currentIndex + 1)
            if targetIndex < 1 or targetIndex > #rows then
                cb({ success = false })
                return
            end

            local targetRow = rows[targetIndex]
            if not targetRow or targetRow.rank_name == 'Ejer' then
                cb({ success = false })
                return
            end

            local currentOrder = tonumber(currentRow.rank_order) or currentIndex
            local targetOrder = tonumber(targetRow.rank_order) or targetIndex
            MySQL.update('UPDATE gang_ranks SET rank_order = -1 WHERE gang_id = ? AND rank_name = ?', {
                gangId, targetRow.rank_name
            }, function()
                MySQL.update('UPDATE gang_ranks SET rank_order = ? WHERE gang_id = ? AND rank_name = ?', {
                    targetOrder, gangId, currentRow.rank_name
                }, function()
                    MySQL.update('UPDATE gang_ranks SET rank_order = ? WHERE gang_id = ? AND rank_name = ?', {
                        currentOrder, gangId, targetRow.rank_name
                    }, function()
                        ensureGangRanks(gangId, function(updatedRows)
                            cb({ success = true, ranks = mapRanksForClient(updatedRows) })
                        end)
                    end)
                end)
            end)
        end)
    end)
end)

ESX.RegisterServerCallback('NW-Bande:changeRank', function(source, cb, targetIdentifier, direction)
    local xPlayer = ESX.GetPlayerFromId(source)
    targetIdentifier = tostring(targetIdentifier or '')
    direction = tostring(direction or '')

    if targetIdentifier == '' or (direction ~= 'up' and direction ~= 'down') then
        cb({ success = false })
        return
    end

    getGangContextForPlayer(xPlayer, function(gangId, gangData, isOwner)
        if not gangId or not gangData then
            cb({ success = false })
            return
        end

        if not isOwner then
            TriggerClientEvent('lation_ui:notify', source, {title = 'Fejl', message = 'Kun bandeejeren kan ændre ranks.', type = 'error'})
            cb({ success = false })
            return
        end

        if targetIdentifier == xPlayer.identifier then
            TriggerClientEvent('lation_ui:notify', source, {title = 'Fejl', message = 'Du kan ikke ændre din egen rank.', type = 'error'})
            cb({ success = false })
            return
        end

        if targetIdentifier == gangData.owner then
            TriggerClientEvent('lation_ui:notify', source, {title = 'Fejl', message = 'Ejerens rank kan ikke ændres.', type = 'error'})
            cb({ success = false })
            return
        end

        MySQL.single('SELECT identifier, rank FROM members WHERE identifier = ? AND gang_id = ?', {
            targetIdentifier, gangId
        }, function(member)
            if not member then
                cb({ success = false })
                return
            end

            ensureGangRanks(gangId, function(rankRows)
                local rankNames = mapRankNames(rankRows)
                local currentIndex = findRankIndex(rankNames, member.rank) or #rankNames
                local newIndex = (direction == 'up') and (currentIndex - 1) or (currentIndex + 1)

                if newIndex < 1 or newIndex > #rankNames then
                    TriggerClientEvent('lation_ui:notify', source, {title = 'Info', message = 'Rank kan ikke ændres mere i den retning.', type = 'info'})
                    cb({ success = false })
                    return
                end

                local newRank = rankNames[newIndex]
                if newRank == 'Ejer' then
                    TriggerClientEvent('lation_ui:notify', source, {title = 'Fejl', message = 'Ingen kan promoveres til Ejer.', type = 'error'})
                    cb({ success = false })
                    return
                end

                MySQL.update('UPDATE members SET rank = ? WHERE identifier = ? AND gang_id = ?', {
                    newRank, targetIdentifier, gangId
                }, function(affectedRows)
                    if not affectedRows or affectedRows < 1 then
                        cb({ success = false })
                        return
                    end

                    TriggerClientEvent('lation_ui:notify', source, {title = 'Bekræftet', message = 'Rank opdateret til '..newRank, type = 'success'})
                    cb({ success = true, rank = newRank })
                end)
            end)
        end)
    end)
end)

-- Opret Bande
RegisterNetEvent('NW-Bande:server:createGang', function(name)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local code = tostring(math.random(111111, 999999))
    local charName = xPlayer.getName()
    
    if xPlayer.getAccount('money').money >= 50000 then
        -- 1. Opret banden i gangs
        MySQL.insert('INSERT INTO gangs (name, owner, join_code) VALUES (?, ?, ?)', {
        name, xPlayer.identifier, code

        }, function(id)
            if id then
            xPlayer.removeAccountMoney('money', 50000)
            
            -- 2. Opdater spillerens gang_id i users
            MySQL.update('UPDATE users SET gang_id = ? WHERE identifier = ?', {id, xPlayer.identifier})

            -- 3. Tilføj spilleren som "Ejer" i members tabellen
            MySQL.insert('INSERT INTO members (identifier, name, gang_id, rank) VALUES (?, ?, ?, ?)', {
                xPlayer.identifier, charName, id, "Ejer"
            })
            ensureGangRanks(id, function() end)
            TriggerClientEvent('lation_ui:notify', src, {title = 'Bekræftet', message = 'Banden er blevet oprettet!', type = 'success'})
        end
    end)
else
    TriggerClientEvent('lation_ui:notify', src, {title = 'Fejl...', message = 'Du mangler penge', type = 'error'})
    end
end)

ESX.RegisterServerCallback('NW-Bande:invitePlayer', function(source, cb, targetId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    targetId = tonumber(targetId)

    if not xPlayer or not targetId then
        cb({ success = false })
        return
    end

    if targetId == src then
        TriggerClientEvent('lation_ui:notify', src, {title = 'Fejl...', message = 'Du kan ikke invitere dig selv.', type = 'error'})
        cb({ success = false })
        return
    end

    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if not targetPlayer then
        TriggerClientEvent('lation_ui:notify', src, {title = 'Fejl...', message = 'Spiller-ID blev ikke fundet online.', type = 'error'})
        cb({ success = false })
        return
    end

    hasGangPermission(xPlayer, 'can_invite', function(gangId, gangData, isOwner, hasPermission)
        if not gangId or not gangData then
            TriggerClientEvent('lation_ui:notify', src, {title = 'Fejl...', message = 'Du er ikke i en bande.', type = 'error'})
            cb({ success = false })
            return
        end

        if not isOwner and not hasPermission then
            TriggerClientEvent('lation_ui:notify', src, {title = 'Fejl...', message = 'Din rank har ikke adgang til at invitere.', type = 'error'})
            cb({ success = false })
            return
        end

        MySQL.scalar('SELECT gang_id FROM users WHERE identifier = ?', {targetPlayer.identifier}, function(targetGangId)
            targetGangId = tonumber(targetGangId)
            if targetGangId and targetGangId ~= 0 then
                TriggerClientEvent('lation_ui:notify', src, {title = 'Fejl...', message = 'Spilleren er allerede i en bande.', type = 'error'})
                cb({ success = false })
                return
            end

            local targetName = targetPlayer.getName()
            MySQL.update('DELETE FROM members WHERE identifier = ?', {targetPlayer.identifier}, function()
                MySQL.update('UPDATE users SET gang_id = ? WHERE identifier = ?', {gangId, targetPlayer.identifier}, function()
                    MySQL.insert('INSERT INTO members (identifier, name, gang_id, rank) VALUES (?, ?, ?, ?)', {
                        targetPlayer.identifier, targetName, gangId, "Medlem"
                    }, function()
                        TriggerClientEvent('lation_ui:notify', src, {title = 'Bekræftet', message = targetName..' er nu inviteret til banden.', type = 'success'})
                        TriggerClientEvent('lation_ui:notify', targetId, {title = 'Bande invitation', message = 'Du er blevet inviteret til '..gangData.name, type = 'success'})
                        cb({ success = true })
                    end)
                end)
            end)
        end)
    end)
end)

RegisterNetEvent('NW-Bande:server:leaveGang', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    -- 1. Find deres gang_id
    MySQL.scalar('SELECT gang_id FROM users WHERE identifier = ?', {xPlayer.identifier}, function(gangId)
        if gangId then
            -- 2. Fjern dem fra members tabellen
            MySQL.update('DELETE FROM members WHERE identifier = ? AND gang_id = ?', {xPlayer.identifier, gangId})
            
            -- 3. Nulstil deres gang_id i users tabellen
            MySQL.update('UPDATE users SET gang_id = NULL WHERE identifier = ?', {xPlayer.identifier})
            
            TriggerClientEvent('lation_ui:notify', src, {title = 'Fejl...', message = 'Du forlod banden!', type = 'error'})
        end
    end)
end)

-- Slet Bande
RegisterNetEvent('NW-Bande:server:deleteGang', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    MySQL.scalar('SELECT gang_id FROM users WHERE identifier = ?', {xPlayer.identifier}, function(gangId)
        if gangId then
            MySQL.single('SELECT owner FROM gangs WHERE id = ?', {gangId}, function(gang)
                if gang and gang.owner == xPlayer.identifier then
                    -- 1. Slet banden (Cascade sletter members hvis du satte Foreign Key rigtigt)
                    MySQL.update('DELETE FROM gangs WHERE id = ?', {gangId}, function()
                        -- 2. Fjern gang_id fra alle i users
                        MySQL.update('UPDATE users SET gang_id = NULL WHERE gang_id = ?', {gangId})
                        -- 3. Slet alle medlemmer fra members tabellen
                        MySQL.update('DELETE FROM members WHERE gang_id = ?', {gangId})
                        MySQL.update('DELETE FROM gang_ranks WHERE gang_id = ?', {gangId})
                        
                        TriggerClientEvent('esx:showNotification', src, 'Banden er slettet.')
                    end)
                else
                    TriggerClientEvent('lation_ui:notify', src, {title = 'Fejl...', message = 'Du har ikke tidladelser til dette!', type = 'error'})
                end
            end)
        end
    end)
end)

-- Spark Medlem
RegisterNetEvent('NW-Bande:server:kickMember', function(targetIdentifier)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not targetIdentifier then return end
    if targetIdentifier == xPlayer.identifier then
        TriggerClientEvent('lation_ui:notify', src, {title = 'Fejl...', message = 'Du kan ikke smide dig selv ud!', type = 'error'})
        return
    end

    -- Tjek om den der sparker har rettigheder (valgfrit tjek)
    MySQL.scalar('SELECT gang_id FROM users WHERE identifier = ?', {xPlayer.identifier}, function(gangId)
        if gangId then
            -- Fjern fra members og nulstil gang_id i users
            MySQL.update('DELETE FROM members WHERE identifier = ? AND gang_id = ?', {targetIdentifier, gangId})
            MySQL.update('UPDATE users SET gang_id = NULL WHERE identifier = ?', {targetIdentifier})
            
            TriggerClientEvent('lation_ui:notify', src, {title = 'Bekræftet', message = 'Spilleren er blevet smidt ud af banden', type = 'success'})
            
            -- Hvis spilleren er online, giv besked
            local targetPlayer = ESX.GetPlayerFromIdentifier(targetIdentifier)
            if targetPlayer then
                TriggerClientEvent('lation_ui:notify', targetPlayer.source, {title = 'Fejl...', message = 'Du er blevet smidt ud af banden!', type = 'error'})
            end
        end
    end)
end)

-- SYSTEM
local function handleBuySkill(src, skillType, cb)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then
        if cb then cb({success = false}) end
        return
    end

    local membersLevel = parseLevelSkill(skillType, 'members', MEMBERS_MAX_LEVEL)
    local eupLevel = parseLevelSkill(skillType, 'eup', EUP_MAX_LEVEL)
    local cfg = skillConfig[skillType]

    if not cfg and not membersLevel and not eupLevel then
        TriggerClientEvent('lation_ui:notify', src, {title = 'Fejl', message = 'Ugyldig skill!', type = 'error'})
        if cb then cb({success = false}) end
        return
    end

    MySQL.scalar('SELECT gang_id FROM users WHERE identifier = ?', {xPlayer.identifier}, function(gangId)
        if not gangId then
            TriggerClientEvent('lation_ui:notify', src, {title = 'Fejl', message = 'Du er ikke i en bande!', type = 'error'})
            if cb then cb({success = false}) end
            return
        end

        MySQL.single('SELECT * FROM gangs WHERE id = ?', {gangId}, function(gangRow)
            if not gangRow then
                if cb then cb({success = false}) end
                return
            end

            ensureGangColumns(function(cols)
                if not cols['skill_points'] then
                    TriggerClientEvent('lation_ui:notify', src, {title = 'Fejl', message = 'skill_points mangler i databasen.', type = 'error'})
                    if cb then cb({success = false}) end
                    return
                end

                local points = tonumber(gangRow.skill_points) or 0
                local cost = SKILL_POINT_COST
                if points < cost then
                    TriggerClientEvent('lation_ui:notify', src, {title = 'Fejl', message = 'Ikke nok skill points!', type = 'error'})
                    if cb then cb({success = false, points = points}) end
                    return
                end

                local skills = normalizeSkills(gangRow)

                if membersLevel then
                    local currentLevel = getMembersLevel(gangRow)
                    if membersLevel ~= currentLevel + 1 then
                        TriggerClientEvent('lation_ui:notify', src, {title = 'Fejl', message = 'Medlemmer skal købes i rækkefølge.', type = 'error'})
                        if cb then cb({success = false, points = points}) end
                        return
                    end

                    points = points - cost
                    local extraMembers = membersLevel * MEMBER_SLOTS_PER_LEVEL
                    if cols['members_level'] then
                        MySQL.update('UPDATE gangs SET members_level = ?, extra_members = ?, skill_points = ? WHERE id = ?', {membersLevel, extraMembers, points, gangId})
                    elseif cols['extra_members'] then
                        MySQL.update('UPDATE gangs SET extra_members = ?, skill_points = ? WHERE id = ?', {extraMembers, points, gangId})
                    else
                        MySQL.update('UPDATE gangs SET skill_points = ? WHERE id = ?', {points, gangId})
                    end

                    if cols['unlocked_skills'] then
                        table.insert(skills, skillType)
                        MySQL.update('UPDATE gangs SET unlocked_skills = ? WHERE id = ?', {json.encode(skills), gangId})
                    end

                    TriggerClientEvent('lation_ui:notify', src, {title = 'Opgraderet', message = 'Du har låst op for: '..skillType, type = 'success'})
                    if cb then cb({success = true, points = points}) end
                    return
                end

                if eupLevel then
                    local currentLevel = getEupLevel(gangRow)
                    if eupLevel ~= currentLevel + 1 then
                        TriggerClientEvent('lation_ui:notify', src, {title = 'Fejl', message = 'EUP skal købes i rækkefølge.', type = 'error'})
                        if cb then cb({success = false, points = points}) end
                        return
                    end

                    points = points - cost
                    if cols['eup_level'] then
                        MySQL.update('UPDATE gangs SET eup_level = ?, skill_points = ? WHERE id = ?', {eupLevel, points, gangId})
                    end
                    if cols['has_eup'] then
                        MySQL.update('UPDATE gangs SET has_eup = ? WHERE id = ?', {eupLevel, gangId})
                    end
                    if cols['unlocked_skills'] then
                        table.insert(skills, skillType)
                        MySQL.update('UPDATE gangs SET unlocked_skills = ? WHERE id = ?', {json.encode(skills), gangId})
                    end

                    TriggerClientEvent('lation_ui:notify', src, {title = 'Opgraderet', message = 'Du har låst op for: '..skillType, type = 'success'})
                    if cb then cb({success = true, points = points}) end
                    return
                end

                if cfg then
                    if skillsContains(skills, skillType) then
                        TriggerClientEvent('lation_ui:notify', src, {title = 'Info', message = 'Skill allerede købt.', type = 'info'})
                        if cb then cb({success = false, points = points}) end
                        return
                    end

                    points = points - cost
                    MySQL.update('UPDATE gangs SET skill_points = ? WHERE id = ?', {points, gangId})
                    if cols['unlocked_skills'] then
                        table.insert(skills, skillType)
                        MySQL.update('UPDATE gangs SET unlocked_skills = ? WHERE id = ?', {json.encode(skills), gangId})
                    end

                    local columnName = cfg.column
                    if columnName and cols[columnName] then
                        MySQL.update('UPDATE gangs SET '..columnName..' = 1 WHERE id = ?', {gangId})
                    end

                    if skillType == 'zones' then
                        syncZoneGangAccess(gangRow.name)
                    end

                    TriggerClientEvent('lation_ui:notify', src, {title = 'Opgraderet', message = 'Du har låst op for: '..skillType, type = 'success'})
                    if cb then cb({success = true, points = points}) end
                end
            end)
        end)
    end)
end

RegisterNetEvent('NW-Bande:server:buySkill', function(skillType)
    handleBuySkill(source, skillType, nil)
end)

ESX.RegisterServerCallback('NW-Bande:buySkill', function(source, cb, skillType)
    handleBuySkill(source, skillType, cb)
end)

local LAUNDER_RESOURCE = 'NW-Laundering'
local completeGangMissionInternal

RegisterNetEvent('NW-Bande:server:setGangMissionActive', function(isActive)
    local src = source
    if exports[LAUNDER_RESOURCE] and exports[LAUNDER_RESOURCE].setGangMissionActive then
        exports[LAUNDER_RESOURCE]:setGangMissionActive(src, isActive and true or false)
    else
        print('[NW-Bande] NW-Laundering export ikke fundet: setGangMissionActive')
    end
end)

RegisterNetEvent('nw-bande:completedLaundry', function(targetSrc, dirtyAmount)
    local src = tonumber(targetSrc)
    if not src then return end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local dirty = tonumber(dirtyAmount) or 0
    if dirty <= 0 then return end

    MySQL.scalar('SELECT gang_id FROM users WHERE identifier = ?', {xPlayer.identifier}, function(gangId)
        if not gangId then return end
        local xp = math.max(1, math.floor(dirty / 1000))
        addGangXp(gangId, xp)
    end)

    completeGangMissionInternal(src, 99)
end)

local function startGangMission(src, missionId, cb)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then
        if cb then cb({success = false}) end
        return
    end

    missionId = tonumber(missionId)
    local mission = missions[missionId]
    if #missionOrder == 0 then
        TriggerClientEvent('lation_ui:notify', src, {title = 'Mission', message = 'Ingen missioner er konfigureret.', type = 'error'})
        if cb then cb({success = false}) end
        return
    end
    if not mission then
        TriggerClientEvent('lation_ui:notify', src, {title = 'Mission', message = 'Ugyldig mission.', type = 'error'})
        if cb then cb({success = false}) end
        return
    end

    hasGangPermission(xPlayer, 'can_start_mission', function(gangId, _, isOwner, hasPermission)
        if not gangId then
            TriggerClientEvent('lation_ui:notify', src, {title = 'Mission', message = 'Du er ikke i en bande.', type = 'error'})
            if cb then cb({success = false}) end
            return
        end

        if not isOwner and not hasPermission then
            TriggerClientEvent('lation_ui:notify', src, {title = 'Mission', message = 'Din rank må ikke starte missioner.', type = 'error'})
            if cb then cb({success = false, state = buildMissionStatePayload(gangId)}) end
            return
        end

        local state = getGangMissionState(gangId)
        normalizeMissionState(state)
        local now = os.time()

        if state.cycleCooldownUntil and state.cycleCooldownUntil > now then
            local remaining = state.cycleCooldownUntil - now
            TriggerClientEvent('lation_ui:notify', src, {title = 'Mission', message = 'Alle missioner er klaret. Næste runde om '..formatSeconds(remaining)..'.', type = 'error'})
            if cb then cb({success = false, state = buildMissionStatePayload(gangId)}) end
            return
        end

        if state.completed[missionId] then
            TriggerClientEvent('lation_ui:notify', src, {title = 'Mission', message = 'Denne mission er allerede fuldført i denne runde.', type = 'info'})
            if cb then cb({success = false, state = buildMissionStatePayload(gangId)}) end
            return
        end

        if state.activeMissionId and state.activeMissionId ~= 0 then
            TriggerClientEvent('lation_ui:notify', src, {title = 'Mission', message = 'I har allerede en aktiv mission.', type = 'error'})
            if cb then cb({success = false, state = buildMissionStatePayload(gangId)}) end
            return
        end

        if state.nextMissionAt and state.nextMissionAt > now then
            local remaining = state.nextMissionAt - now
            TriggerClientEvent('lation_ui:notify', src, {title = 'Mission', message = 'Vent '..formatSeconds(remaining)..' før næste mission.', type = 'error'})
            if cb then cb({success = false, state = buildMissionStatePayload(gangId)}) end
            return
        end

        state.activeMissionId = missionId
        state.nextMissionAt = now + MISSION_START_INTERVAL_SECONDS

        TriggerClientEvent('lation_ui:notify', src, {title = 'Mission Startet', message = mission.title..' er nu aktiv. Fuldfør via '..mission.source..'.', type = 'success'})
        if cb then cb({success = true, state = buildMissionStatePayload(gangId)}) end
    end)
end

completeGangMissionInternal = function(src, missionId)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    missionId = tonumber(missionId)
    local mission = missions[missionId]
    if not mission then return end

    getPlayerGangId(xPlayer.identifier, function(gangId)
        if not gangId then return end

        local state = getGangMissionState(gangId)
        normalizeMissionState(state)
        local now = os.time()

        if state.cycleCooldownUntil and state.cycleCooldownUntil > now then
            return
        end

        if state.activeMissionId ~= missionId then
            return
        end

        if state.completed[missionId] then
            return
        end

        state.completed[missionId] = true
        state.activeMissionId = 0

        if mission.money and mission.money > 0 then
            xPlayer.addAccountMoney('money', mission.money)
        end

        if mission.xp and mission.xp > 0 then
            addGangXp(gangId, mission.xp, function(saved, newLevel, _, leveledUp)
                if saved and leveledUp then
                    TriggerClientEvent('lation_ui:notify', src, {title = 'Level Up', message = 'Banden steg til level '..newLevel..'!', type = 'success'})
                end
            end)
        end

        if allCycleMissionsCompleted(state) then
            state.completed = {}
            state.cycleCooldownUntil = now + MISSION_FULL_CLEAR_COOLDOWN_SECONDS
            state.nextMissionAt = state.cycleCooldownUntil
            TriggerClientEvent('lation_ui:notify', src, {title = 'Mission', message = 'Alle missioner fuldført. Ny runde om 1 time.', type = 'success'})
        else
            TriggerClientEvent('lation_ui:notify', src, {title = 'Mission', message = 'Mission fuldført: +'..mission.money..' DKK og +'..mission.xp..' XP', type = 'success'})
        end
    end)
end

ESX.RegisterServerCallback('NW-Bande:getMissionState', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb({success = false})
        return
    end

    getPlayerGangId(xPlayer.identifier, function(gangId)
        if not gangId then
            cb({success = false})
            return
        end
        cb({success = true, state = buildMissionStatePayload(gangId)})
    end)
end)

ESX.RegisterServerCallback('NW-Bande:startMission', function(source, cb, missionId)
    startGangMission(source, missionId, cb)
end)

RegisterNetEvent('NW-Bande:server:startMission', function(missionId)
    startGangMission(source, missionId, nil)
end)

RegisterNetEvent('NW-Bande:server:completeMission', function(missionId)
    completeGangMissionInternal(source, missionId)
end)

exports('CompleteGangMission', function(playerSource, missionId)
    completeGangMissionInternal(tonumber(playerSource), tonumber(missionId))
end)

exports('RegisterGangMission', function(missionId, data)
    if type(missionId) == 'table' and data == nil then
        data = missionId
        missionId = data.id
    end

    local ok, reason = registerMission(missionId, data)
    if not ok then
        return false, reason
    end
    return true
end)

