local DB = lib.require('server.db')
local Utils = lib.require('shared.utils')
local Auth = lib.require('server.auth')

local function broadcastBossMenus()
  local menus = DB.getBossMenus()
  TriggerClientEvent('nw_jobscreator:client:setBossMenus', -1, menus)
end

lib.callback.register('nw_jobscreator:cb:getBossMenus', function(_src)
  return DB.getBossMenus()
end)

lib.callback.register('nw_jobscreator:cb:getJobGrades', function(_src, jobName)
  if not Utils.isValidName(jobName) then return nil end
  return DB.fetchGrades(jobName)
end)

local function getESX()
  if GetResourceState('es_extended') ~= 'started' then return nil end
  local ok, obj = pcall(function()
    return exports['es_extended']:getSharedObject()
  end)
  if ok then return obj end
  return nil
end

local function getSocietyAccountName(jobName)
  local prefix = (Config.Society and Config.Society.accountPrefix) or 'society_'
  return prefix .. jobName
end

local function getSharedSocietyAccount(jobName)
  if not (Config.Society and Config.Society.enabled) then return nil end
  if GetResourceState('esx_addonaccount') ~= 'started' then return nil end

  local p = promise.new()
  TriggerEvent('esx_addonaccount:getSharedAccount', getSocietyAccountName(jobName), function(account)
    p:resolve(account)
  end)
  return Citizen.Await(p)
end

local function getNearestBossMenu(src, jobName)
  local ped = GetPlayerPed(src)
  if not ped or ped == 0 then return nil, nil end
  local pCoords = GetEntityCoords(ped)

  local nearest, nearestDist
  for _, menu in ipairs(DB.getBossMenus()) do
    if menu.job == jobName then
      local d = #(pCoords - vector3(menu.x, menu.y, menu.z))
      if not nearestDist or d < nearestDist then
        nearestDist = d
        nearest = menu
      end
    end
  end
  return nearest, nearestDist
end

local function hasBossPerm(src, xPlayer, menu, field)
  if Auth.isAdmin(src) then return true end
  if not xPlayer or not xPlayer.job or not menu then return false end
  if xPlayer.job.name ~= menu.job then return false end
  local grade = tonumber(xPlayer.job.grade) or 0
  local required = tonumber(menu[field]) or tonumber(menu.min_grade) or 0
  return grade >= required
end

lib.callback.register('nw_jobscreator:cb:getSocietyBalance', function(src, jobName)
  if not Utils.isValidName(jobName) then return nil end
  local ESX = getESX()
  if not ESX then return nil end
  local xPlayer = ESX.GetPlayerFromId(src)
  if not xPlayer or not xPlayer.job or xPlayer.job.name ~= jobName then return nil end

  local menu, dist = getNearestBossMenu(src, jobName)
  if not menu or (dist or 9999.0) > 5.0 then return nil end
  if not hasBossPerm(src, xPlayer, menu, 'money_min_grade') then return nil end

  local account = getSharedSocietyAccount(jobName)
  if not account then return nil end
  return account.money or 0
end)

RegisterNetEvent('nw_jobscreator:server:societyWithdraw', function(jobName, amount)
  local src = source
  if not Utils.isValidName(jobName) then return end
  amount = tonumber(amount)
  if not amount or amount <= 0 then return end

  local ESX = getESX()
  if not ESX then return end
  local xPlayer = ESX.GetPlayerFromId(src)
  if not xPlayer or not xPlayer.job or xPlayer.job.name ~= jobName then return end

  local menu, dist = getNearestBossMenu(src, jobName)
  if not menu or (dist or 9999.0) > 5.0 or not hasBossPerm(src, xPlayer, menu, 'money_min_grade') then
    TriggerClientEvent('nw_jobscreator:client:notify', src, 'Ingen adgang.', 'error')
    return
  end

  local account = getSharedSocietyAccount(jobName)
  if not account then
    TriggerClientEvent('nw_jobscreator:client:notify', src, 'Firmakonto mangler.', 'error')
    return
  end
  if (account.money or 0) < amount then
    TriggerClientEvent('nw_jobscreator:client:notify', src, 'Ikke nok firmapenge.', 'error')
    return
  end

  account.removeMoney(amount)
  local moneySource = (Config.Society and Config.Society.moneySource) or 'cash'
  if moneySource == 'bank' and xPlayer.addAccountMoney then
    xPlayer.addAccountMoney('bank', amount)
  else
    xPlayer.addMoney(amount)
  end

  TriggerClientEvent('nw_jobscreator:client:notify', src, 'Hævet.', 'success')
end)

RegisterNetEvent('nw_jobscreator:server:societyDeposit', function(jobName, amount)
  local src = source
  if not Utils.isValidName(jobName) then return end
  amount = tonumber(amount)
  if not amount or amount <= 0 then return end

  local ESX = getESX()
  if not ESX then return end
  local xPlayer = ESX.GetPlayerFromId(src)
  if not xPlayer or not xPlayer.job or xPlayer.job.name ~= jobName then return end

  local menu, dist = getNearestBossMenu(src, jobName)
  if not menu or (dist or 9999.0) > 5.0 or not hasBossPerm(src, xPlayer, menu, 'money_min_grade') then
    TriggerClientEvent('nw_jobscreator:client:notify', src, 'Ingen adgang.', 'error')
    return
  end

  local account = getSharedSocietyAccount(jobName)
  if not account then
    TriggerClientEvent('nw_jobscreator:client:notify', src, 'Firmakonto mangler.', 'error')
    return
  end

  local moneySource = (Config.Society and Config.Society.moneySource) or 'cash'
  if moneySource == 'bank' and xPlayer.getAccount and xPlayer.removeAccountMoney then
    local bank = xPlayer.getAccount('bank')
    if not bank or (bank.money or 0) < amount then
      TriggerClientEvent('nw_jobscreator:client:notify', src, 'Ikke nok penge.', 'error')
      return
    end
    xPlayer.removeAccountMoney('bank', amount)
  else
    if xPlayer.getMoney() < amount then
      TriggerClientEvent('nw_jobscreator:client:notify', src, 'Ikke nok penge.', 'error')
      return
    end
    xPlayer.removeMoney(amount)
  end

  account.addMoney(amount)
  TriggerClientEvent('nw_jobscreator:client:notify', src, 'Indsat.', 'success')
end)

local function ident(s)
  if type(s) ~= 'string' or s:match('^[%w_]+$') == nil then
    error(('invalid sql identifier: %s'):format(tostring(s)))
  end
  return ('`%s`'):format(s)
end

local function usersTableCfg()
  return Config.UsersTable or {
    table = 'users',
    identifier = 'identifier',
    job = 'job',
    jobGrade = 'job_grade',
    firstname = 'firstname',
    lastname = 'lastname',
    name = 'name'
  }
end

local usersColCache
local function usersHasColumn(tableNameRaw, colName)
  usersColCache = usersColCache or {}
  usersColCache[tableNameRaw] = usersColCache[tableNameRaw] or {}
  if usersColCache[tableNameRaw][colName] ~= nil then
    return usersColCache[tableNameRaw][colName]
  end
  local ok, res = pcall(function()
    return MySQL.query.await('SHOW COLUMNS FROM ' .. ident(tableNameRaw) .. ' LIKE ?', { colName })
  end)
  local has = ok and res and #res > 0
  usersColCache[tableNameRaw][colName] = has
  return has
end

local function getEmployeesForJob(jobName)
  local cfg = usersTableCfg()
  local t = cfg.table
  local fields = {
    ident(cfg.identifier) .. ' AS identifier',
    ident(cfg.jobGrade) .. ' AS grade',
  }

  if usersHasColumn(t, cfg.firstname) then
    fields[#fields + 1] = ident(cfg.firstname) .. ' AS firstname'
  end
  if usersHasColumn(t, cfg.lastname) then
    fields[#fields + 1] = ident(cfg.lastname) .. ' AS lastname'
  end
  if usersHasColumn(t, cfg.name) then
    fields[#fields + 1] = ident(cfg.name) .. ' AS name'
  end

  local query = ('SELECT %s FROM %s WHERE %s = ? ORDER BY %s DESC'):format(
    table.concat(fields, ', '),
    ident(t),
    ident(cfg.job),
    ident(cfg.jobGrade)
  )

  local rows = MySQL.query.await(query, { jobName }) or {}
  local result = {}
  for _, r in ipairs(rows) do
    local display = r.name
    if (not display or display == '') and r.firstname and r.lastname then
      display = (r.firstname .. ' ' .. r.lastname)
    end
    if not display or display == '' then
      display = r.identifier
    end
    result[#result + 1] = {
      identifier = r.identifier,
      name = display,
      grade = tonumber(r.grade) or 0,
      online = false
    }
  end
  return result
end

local function markOnlineEmployees(jobName, employees)
  local ESX = getESX()
  if not ESX or type(ESX.GetPlayers) ~= 'function' then return employees end

  local onlineByIdentifier = {}
  local function put(key, payload)
    if key and key ~= '' then
      onlineByIdentifier[key] = payload
    end
  end
  for _, pid in ipairs(ESX.GetPlayers()) do
    local xP = ESX.GetPlayerFromId(pid)
    if xP and xP.job and xP.job.name == jobName then
      local payload = { source = pid, playerName = GetPlayerName(pid) }

      -- Prefer ESX identifier, but also index all player identifiers (license/steam/discord/etc).
      local identifier = xP.identifier
      if not identifier and type(xP.getIdentifier) == 'function' then
        local ok, value = pcall(function() return xP.getIdentifier() end)
        if ok then identifier = value end
      end
      put(identifier, payload)

      -- Also index stripped variants (e.g. "license:abcd" -> "abcd") to support servers storing raw values.
      if identifier then
        local stripped = identifier:match('^[^:]+:(.+)$')
        put(stripped, payload)
      end

      local count = GetNumPlayerIdentifiers(pid)
      for i = 0, count - 1 do
        local id = GetPlayerIdentifier(pid, i)
        put(id, payload)
        local stripped = id and id:match('^[^:]+:(.+)$')
        put(stripped, payload)
      end
    end
  end

  for _, e in ipairs(employees) do
    local on = onlineByIdentifier[e.identifier]
    if not on then
      local stripped = e.identifier and e.identifier:match('^[^:]+:(.+)$')
      if stripped then on = onlineByIdentifier[stripped] end
    end
    if on then
      e.online = true
      e.source = on.source
      e.playerName = on.playerName
    end
  end

  return employees
end

local function isEmployeeOfJob(identifier, jobName)
  local cfg = usersTableCfg()
  local job = MySQL.scalar.await(
    ('SELECT %s FROM %s WHERE %s = ? LIMIT 1'):format(
      ident(cfg.job),
      ident(cfg.table),
      ident(cfg.identifier)
    ),
    { identifier }
  )
  return job == jobName
end

local function getPermittedBossContext(src, jobName, field)
  local ESX = getESX()
  if not ESX then return nil, nil end
  local xPlayer = ESX.GetPlayerFromId(src)
  if not xPlayer or not xPlayer.job or xPlayer.job.name ~= jobName then return nil, nil end

  local menu, dist = getNearestBossMenu(src, jobName)
  if not menu or (dist or 9999.0) > 5.0 then return nil, nil end
  if not hasBossPerm(src, xPlayer, menu, field) then return nil, nil end

  return xPlayer, menu
end

lib.callback.register('nw_jobscreator:cb:getEmployees', function(src, jobName)
  if not Utils.isValidName(jobName) then return nil end
  local xPlayer = nil
  if not Auth.isAdmin(src) then
    xPlayer = select(1, getPermittedBossContext(src, jobName, 'employees_min_grade'))
    if not xPlayer then return nil end
  end

  local employees = getEmployeesForJob(jobName)
  return markOnlineEmployees(jobName, employees)
end)

lib.callback.register('nw_jobscreator:cb:getOnlinePlayers', function(src, jobName)
  if not Utils.isValidName(jobName) then return nil end
  -- Hiring candidates: only for users who can manage employees for that job (or admins).
  if not Auth.isAdmin(src) then
    local xPlayer = select(1, getPermittedBossContext(src, jobName, 'employees_min_grade'))
    if not xPlayer then return nil end
  end
  local ESX = getESX()
  if not ESX or type(ESX.GetPlayers) ~= 'function' then return nil end

  local list = {}
  for _, pid in ipairs(ESX.GetPlayers()) do
    local xP = ESX.GetPlayerFromId(pid)
    if xP then
      list[#list + 1] = {
        source = pid,
        name = GetPlayerName(pid),
        identifier = xP.identifier,
        job = xP.job and xP.job.name or nil
      }
    end
  end
  return list
end)

RegisterNetEvent('nw_jobscreator:server:setEmployeeGrade', function(jobName, identifier, newGrade)
  local src = source
  if not Utils.isValidName(jobName) then return end
  if type(identifier) ~= 'string' or identifier == '' then return end
  newGrade = tonumber(newGrade)
  if not newGrade or newGrade < 0 then return end

  if not Auth.isAdmin(src) then
    local xPlayer = select(1, getPermittedBossContext(src, jobName, 'employees_min_grade'))
    if not xPlayer then
      TriggerClientEvent('nw_jobscreator:client:notify', src, 'Ingen adgang.', 'error')
      return
    end
    if not isEmployeeOfJob(identifier, jobName) then
      TriggerClientEvent('nw_jobscreator:client:notify', src, 'Personen er ikke ansat.', 'error')
      return
    end
  end

  local ESX = getESX()
  if ESX then
    -- If player is online, update via ESX API (also updates DB).
    if type(ESX.GetPlayers) == 'function' then
      for _, pid in ipairs(ESX.GetPlayers()) do
        local xP = ESX.GetPlayerFromId(pid)
        if xP and (xP.identifier == identifier) then
          if xP.setJob then
            xP.setJob(jobName, newGrade)
            TriggerClientEvent('nw_jobscreator:client:notify', src, 'Ansat opdateret.', 'success')
            return
          end
        end
      end
    end
  end

  -- Offline fallback: update users table.
  local cfg = usersTableCfg()
  MySQL.update.await(
    ('UPDATE %s SET %s = ?, %s = ? WHERE %s = ?'):format(
      ident(cfg.table),
      ident(cfg.job),
      ident(cfg.jobGrade),
      ident(cfg.identifier)
    ),
    { jobName, newGrade, identifier }
  )
  TriggerClientEvent('nw_jobscreator:client:notify', src, 'Ansat opdateret (offline).', 'success')
end)

RegisterNetEvent('nw_jobscreator:server:fireEmployee', function(identifier)
  local src = source
  if type(identifier) ~= 'string' or identifier == '' then return end

  -- Admins can fire anyone; bosses can only fire employees while near a boss menu for their job.
  local ESX = getESX()
  if not ESX then return end

  local unemployedJob = (Config.Society and Config.Society.unemployedJob) or 'unemployed'
  local unemployedGrade = tonumber((Config.Society and Config.Society.unemployedGrade) or 0) or 0

  if not Auth.isAdmin(src) then
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not xPlayer.job then return end
    local jobName = xPlayer.job.name
    local boss = select(1, getPermittedBossContext(src, jobName, 'employees_min_grade'))
    if not boss then
      TriggerClientEvent('nw_jobscreator:client:notify', src, 'Ingen adgang.', 'error')
      return
    end
    if not isEmployeeOfJob(identifier, jobName) then
      TriggerClientEvent('nw_jobscreator:client:notify', src, 'Personen er ikke ansat.', 'error')
      return
    end
  end

  -- Online?
  if type(ESX.GetPlayers) == 'function' then
    for _, pid in ipairs(ESX.GetPlayers()) do
      local xP = ESX.GetPlayerFromId(pid)
      if xP and xP.identifier == identifier and xP.setJob then
        xP.setJob(unemployedJob, unemployedGrade)
        TriggerClientEvent('nw_jobscreator:client:notify', src, 'Ansat fyret.', 'success')
        return
      end
    end
  end

  -- Offline fallback.
  local cfg = usersTableCfg()
  MySQL.update.await(
    ('UPDATE %s SET %s = ?, %s = ? WHERE %s = ?'):format(
      ident(cfg.table),
      ident(cfg.job),
      ident(cfg.jobGrade),
      ident(cfg.identifier)
    ),
    { unemployedJob, unemployedGrade, identifier }
  )
  TriggerClientEvent('nw_jobscreator:client:notify', src, 'Ansat fyret (offline).', 'success')
end)

RegisterNetEvent('nw_jobscreator:server:hireEmployee', function(jobName, targetSrc, grade)
  local src = source
  if not Utils.isValidName(jobName) then return end
  targetSrc = tonumber(targetSrc)
  grade = tonumber(grade) or 0
  if not targetSrc then return end
  if grade < 0 then grade = 0 end

  local ESX = getESX()
  if not ESX then return end

  if not Auth.isAdmin(src) then
    local xPlayer = select(1, getPermittedBossContext(src, jobName, 'employees_min_grade'))
    if not xPlayer then
      TriggerClientEvent('nw_jobscreator:client:notify', src, 'Ingen adgang.', 'error')
      return
    end
  end

  local target = ESX.GetPlayerFromId(targetSrc)
  if not target or not target.setJob then
    TriggerClientEvent('nw_jobscreator:client:notify', src, 'Spilleren er ikke online.', 'error')
    return
  end

  target.setJob(jobName, grade)
  TriggerClientEvent('nw_jobscreator:client:notify', src, 'Ansat.', 'success')
  TriggerClientEvent('nw_jobscreator:client:notify', targetSrc, ('Du blev ansat som %s.'):format(jobName), 'success')
end)

RegisterNetEvent('nw_jobscreator:server:createBossMenu', function(entry)
  local src = source
  if not Auth.isAdmin(src) then return end
  if type(entry) ~= 'table' then return end

  local label = Utils.trim(entry.label or 'Boss-menu')
  local job = Utils.trim(entry.job or '')
  local minGrade = tonumber(entry.min_grade) or 0
  local moneyMinGrade = tonumber(entry.money_min_grade) or 0
  local employeesMinGrade = tonumber(entry.employees_min_grade) or 0
  local ui = entry.ui == 'lation_ui' and 'lation_ui' or 'ox_lib'
  local openType = entry.open_type == 'target' and 'target' or 'text'
  local radius = tonumber(entry.radius) or (Config.BossMenus.defaultZoneRadius or 1.5)
  local icon = entry.icon and Utils.trim(entry.icon) or nil

  if not Utils.isValidLabel(label) then
    TriggerClientEvent('nw_jobscreator:client:notify', src, 'Ugyldig label.', 'error')
    return
  end
  if not Utils.isValidName(job) then
    TriggerClientEvent('nw_jobscreator:client:notify', src, 'Ugyldigt job.', 'error')
    return
  end
  if minGrade < 0 then minGrade = 0 end
  if moneyMinGrade < 0 then moneyMinGrade = 0 end
  if employeesMinGrade < 0 then employeesMinGrade = 0 end

  local x, y, z = tonumber(entry.x), tonumber(entry.y), tonumber(entry.z)
  if not x or not y or not z then
    TriggerClientEvent('nw_jobscreator:client:notify', src, 'Ugyldige koordinater.', 'error')
    return
  end

  local id = DB.createBossMenu({
    label = label,
    job = job,
    min_grade = minGrade,
    money_min_grade = moneyMinGrade,
    employees_min_grade = employeesMinGrade,
    ui = ui,
    open_type = openType,
    x = x, y = y, z = z,
    radius = radius,
    icon = icon
  })

  TriggerClientEvent('nw_jobscreator:client:notify', src, ('Boss-menu oprettet (id %s).'):format(id), 'success')
  TriggerEvent('nw_jobscreator:server:refreshCache')
end)

RegisterNetEvent('nw_jobscreator:server:deleteBossMenu', function(id)
  local src = source
  if not Auth.isAdmin(src) then return end
  id = tonumber(id)
  if not id then return end
  DB.deleteBossMenu(id)
  TriggerClientEvent('nw_jobscreator:client:notify', src, 'Boss-menu slettet.', 'success')
  TriggerEvent('nw_jobscreator:server:refreshCache')
end)

local function canBossEditSalary(src, jobName)
  if Auth.isAdmin(src) then return true end
  if GetResourceState('es_extended') ~= 'started' then return false end

  local ok, ESX = pcall(function()
    return exports['es_extended']:getSharedObject()
  end)
  if not ok or not ESX then return false end

  local xPlayer = ESX.GetPlayerFromId(src)
  if not xPlayer or not xPlayer.job or xPlayer.job.name ~= jobName then return false end

  -- Must be close to a configured boss menu for this job and meet min grade.
  local ped = GetPlayerPed(src)
  if not ped or ped == 0 then return false end
  local pCoords = GetEntityCoords(ped)

  for _, menu in ipairs(DB.getBossMenus()) do
    if menu.job == jobName then
      local minGrade = tonumber(menu.employees_min_grade) or tonumber(menu.min_grade) or 0
      if (tonumber(xPlayer.job.grade) or 0) >= minGrade then
        local mCoords = vector3(menu.x, menu.y, menu.z)
        if #(pCoords - mCoords) <= 5.0 then
          return true
        end
      end
    end
  end

  return false
end

RegisterNetEvent('nw_jobscreator:server:updateGradeSalary', function(jobName, grade, salary)
  local src = source
  if not Utils.isValidName(jobName) then return end
  if not canBossEditSalary(src, jobName) then
    TriggerClientEvent('nw_jobscreator:client:notify', src, 'Ingen adgang.', 'error')
    return
  end

  local ok, err = DB.updateGradeSalary(jobName, grade, salary)
  if not ok then
    TriggerClientEvent('nw_jobscreator:client:notify', src, err or 'Fejl.', 'error')
    return
  end
  TriggerClientEvent('nw_jobscreator:client:notify', src, 'Løn opdateret.', 'success')
  TriggerEvent('nw_jobscreator:server:refreshCache')
end)

AddEventHandler('nw_jobscreator:server:refreshCache', function()
  -- Reload boss menus
  DB.loadBossMenus()
  broadcastBossMenus()

  -- Refresh ESX runtime jobs if available
  if Config.Framework == 'esx' and GetResourceState('es_extended') == 'started' then
    local ok, ESX = pcall(function()
      return exports['es_extended']:getSharedObject()
    end)
    if ok and ESX then
      if type(ESX.RefreshJobs) == 'function' then
        pcall(function() ESX.RefreshJobs() end)
      end
    end
  end
end)

exports('GetBossMenus', function()
  return DB.getBossMenus()
end)
