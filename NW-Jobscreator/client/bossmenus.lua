local UI = lib.require('shared.ui')

local bossMenus = {}
local targetZones = {}
local ESX
local cachedJob, cachedGrade
local setupOxTarget
local textState = {
  showing = false,
  provider = 'ox_lib'
}

local function getPlayerJob()
  -- Best-effort: many frameworks put job in LocalPlayer.state via statebags.
  local st = LocalPlayer and LocalPlayer.state
  if st and st.job and st.job.name then
    return st.job.name, st.job.grade
  end
  if cachedJob then
    return cachedJob, cachedGrade
  end
  if ESX and ESX.GetPlayerData then
    local pd = ESX.GetPlayerData()
    if pd and pd.job then
      return pd.job.name, pd.job.grade
    end
  end
  return nil, nil
end

local function canOpen(menu)
  local jobName, grade = getPlayerJob()
  if not jobName then return false end
  if jobName ~= menu.job then return false end
  grade = tonumber(grade) or 0
  return grade >= (tonumber(menu.min_grade) or 0)
end

local function canMoney(menu)
  local _, grade = getPlayerJob()
  grade = tonumber(grade) or 0
  return grade >= (tonumber(menu.money_min_grade) or 0)
end

local function canEmployees(menu)
  local _, grade = getPlayerJob()
  grade = tonumber(grade) or 0
  return grade >= (tonumber(menu.employees_min_grade) or 0)
end

local function openSalariesMenu(menu)
  CreateThread(function()
    local grades = lib.callback.await('nw_jobscreator:cb:getJobGrades', false, menu.job)
    if not grades then
      UI.notify('Kunne ikke hente rang/løn.', 'error')
      return
    end
    local opts = {}
    for _, g in ipairs(grades) do
      opts[#opts + 1] = {
        title = string.format('[%d] %s', g.grade, g.label),
        description = ('Løn: %s'):format(g.salary),
        icon = 'fa-solid fa-money-bill',
        onSelect = function()
          local inp = UI.input('Sæt løn', {
            { type = 'number', label = 'Ny løn', required = true, default = g.salary }
          }, menu.ui)
          if not inp then return end
          TriggerServerEvent('nw_jobscreator:server:updateGradeSalary', menu.job, g.grade, tonumber(inp[1]))
        end
      }
    end
    UI.showContext(menu.ui, 'nw_jobscreator_salaries_' .. tostring(menu.id), 'Lønninger', opts)
  end)
end

local function openMoneyMenu(menu)
  if not canMoney(menu) then
    UI.notify('Du har ikke adgang til firmapenge.', 'error')
    return
  end

  CreateThread(function()
    local balance = lib.callback.await('nw_jobscreator:cb:getSocietyBalance', false, menu.job)
    if balance == nil then
      UI.notify('Firmakontoen kunne ikke hentes.', 'error')
      return
    end

    local opts = {
      {
        title = 'Saldo',
        description = tostring(balance),
        icon = 'fa-solid fa-coins',
        disabled = true
      },
      {
        title = 'Hæv',
        icon = 'fa-solid fa-arrow-up',
        onSelect = function()
          local inp = UI.input('Hæv', {
            { type = 'number', label = 'Beløb', required = true, min = 1 }
          }, menu.ui)
          if not inp then return end
          TriggerServerEvent('nw_jobscreator:server:societyWithdraw', menu.job, tonumber(inp[1]))
        end
      },
      {
        title = 'Indsæt',
        icon = 'fa-solid fa-arrow-down',
        onSelect = function()
          local inp = UI.input('Indsæt', {
            { type = 'number', label = 'Beløb', required = true, min = 1 }
          }, menu.ui)
          if not inp then return end
          TriggerServerEvent('nw_jobscreator:server:societyDeposit', menu.job, tonumber(inp[1]))
        end
      }
    }

    UI.showContext(menu.ui, 'nw_jobscreator_money_' .. tostring(menu.id), 'Firmapenge', opts)
  end)
end

local function openHireMenu(menu)
  CreateThread(function()
    local players = lib.callback.await('nw_jobscreator:cb:getOnlinePlayers', false, menu.job)
    if not players then
      UI.notify('Kunne ikke hente spillere.', 'error')
      return
    end

    local opts = {}
    for _, p in ipairs(players) do
      local desc = p.job and ('Nuværende job: %s'):format(p.job) or ''
      opts[#opts + 1] = {
        title = ('[%s] %s'):format(p.source, p.name),
        description = desc,
        icon = 'fa-solid fa-user-plus',
        onSelect = function()
          local inp = UI.input('Ansæt spiller', {
            { type = 'number', label = 'Rang', required = true, default = 0, min = 0 }
          }, menu.ui)
          if not inp then return end
          TriggerServerEvent('nw_jobscreator:server:hireEmployee', menu.job, p.source, tonumber(inp[1]))
        end
      }
    end

    if #opts == 0 then
      opts[1] = { title = 'Ingen online spillere', disabled = true }
    end

    UI.showContext(menu.ui, 'nw_jobscreator_hire_' .. tostring(menu.id), 'Ansæt', opts)
  end)
end

local function openEmployeeActions(menu, employee)
  UI.showContext(menu.ui, ('nw_jobscreator_emp_%s_%s'):format(menu.id, employee.identifier), employee.name, {
    {
      title = 'Skift rang',
      icon = 'fa-solid fa-user-pen',
      onSelect = function()
        local inp = UI.input('Skift rang', {
          { type = 'number', label = 'Ny rang', required = true, default = employee.grade, min = 0 }
        }, menu.ui)
        if not inp then return end
        TriggerServerEvent('nw_jobscreator:server:setEmployeeGrade', menu.job, employee.identifier, tonumber(inp[1]))
      end
    },
    {
      title = 'Fyr',
      icon = 'fa-solid fa-user-xmark',
      onSelect = function()
        local alert = lib.alertDialog({
          header = 'Fyr ansat?',
          content = ('Fyr %s?'):format(employee.name),
          centered = true,
          cancel = true
        })
        if alert == 'confirm' then
          TriggerServerEvent('nw_jobscreator:server:fireEmployee', employee.identifier)
        end
      end
    }
  })
end

local function openEmployeesMenu(menu)
  if not canEmployees(menu) then
    UI.notify('Du har ikke adgang til ansatte.', 'error')
    return
  end

  CreateThread(function()
    local employees = lib.callback.await('nw_jobscreator:cb:getEmployees', false, menu.job)
    if not employees then
      UI.notify('Kunne ikke hente ansatte.', 'error')
      return
    end

    local opts = {
      {
        title = 'Ansæt',
        icon = 'fa-solid fa-user-plus',
        onSelect = function()
          openHireMenu(menu)
        end
      }
    }

    for _, e in ipairs(employees) do
      local status = e.online and ('Online (%s)'):format(e.playerName or e.source or '?') or 'Offline'
      opts[#opts + 1] = {
        title = string.format('[%d] %s', e.grade, e.name),
        description = status,
        icon = e.online and 'fa-solid fa-signal' or 'fa-regular fa-circle',
        onSelect = function()
          openEmployeeActions(menu, e)
        end
      }
    end

    UI.showContext(menu.ui, 'nw_jobscreator_employees_' .. tostring(menu.id), 'Ansatte', opts)
  end)
end

local function openBossMenu(menu)
  if not canOpen(menu) then
    UI.notify('Du har ikke adgang til denne boss-menu.', 'error')
    return
  end

  local opts = {}

  if Config.Society and Config.Society.enabled then
    opts[#opts + 1] = {
      title = 'Firmapenge',
      description = 'Indsæt / hæv',
      icon = 'fa-solid fa-coins',
      disabled = not canMoney(menu),
      onSelect = function()
        openMoneyMenu(menu)
      end
    }
  end

  opts[#opts + 1] = {
    title = 'Ansatte',
    description = 'Ansæt / fyr / skift rang',
    icon = 'fa-solid fa-users',
    disabled = not canEmployees(menu),
    onSelect = function()
      openEmployeesMenu(menu)
    end
  }

  opts[#opts + 1] = {
    title = 'Lønninger',
    description = 'Skift løn pr. rang',
    icon = 'fa-solid fa-money-bill',
    disabled = not canEmployees(menu),
    onSelect = function()
      openSalariesMenu(menu)
    end
  }

  UI.showContext(menu.ui, 'nw_jobscreator_boss_' .. tostring(menu.id), menu.label or 'Boss-menu', opts)
end

setupOxTarget = function(menu)
  if GetResourceState('ox_target') ~= 'started' then return false end
  local coords = vec3(menu.x, menu.y, menu.z)
  local name = ('nw_jobscreator_boss_%s'):format(menu.id)
  targetZones[menu.id] = name
  exports.ox_target:addSphereZone({
    name = name,
    coords = coords,
    radius = menu.radius or 1.5,
    debug = false,
    options = {
      {
        label = menu.label or 'Boss-menu',
        icon = menu.icon or 'fa-solid fa-briefcase',
        onSelect = function()
          openBossMenu(menu)
        end,
        canInteract = function()
          return canOpen(menu)
        end
      }
    }
  })
  return true
end

RegisterNetEvent('nw_jobscreator:client:setBossMenus', function(menus)
  bossMenus = menus or {}

  -- Rebuild target zones on update (best-effort).
  if GetResourceState('ox_target') == 'started' then
    for _, zoneName in pairs(targetZones) do
      pcall(function() exports.ox_target:removeZone(zoneName) end)
      pcall(function() exports.ox_target:removeSphereZone(zoneName) end)
    end
    targetZones = {}
    for _, menu in ipairs(bossMenus) do
      if menu.open_type == 'target' then
        setupOxTarget(menu)
      end
    end
  end
end)

CreateThread(function()
  if GetResourceState('es_extended') == 'started' then
    CreateThread(function()
      while not ESX do
        local ok, obj = pcall(function()
          return exports['es_extended']:getSharedObject()
        end)
        if ok and obj then ESX = obj break end
        Wait(500)
      end

      if ESX and ESX.GetPlayerData then
        local pd = ESX.GetPlayerData()
        if pd and pd.job then
          cachedJob, cachedGrade = pd.job.name, pd.job.grade
        end
      end
    end)

    AddEventHandler('esx:setJob', function(job)
      if job then
        cachedJob, cachedGrade = job.name, job.grade
      end
    end)
  end

  CreateThread(function()
    bossMenus = lib.callback.await('nw_jobscreator:cb:getBossMenus', false) or {}
    for _, menu in ipairs(bossMenus) do
      if menu.open_type == 'target' then
        setupOxTarget(menu)
      end
    end
  end)

  while true do
    Wait(250)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local closest
    local closestDist = 9999.0

    for _, menu in ipairs(bossMenus) do
      if menu.open_type == 'text' then
        local d = #(coords - vec3(menu.x, menu.y, menu.z))
        if d < closestDist then
          closestDist = d
          closest = menu
        end
      end
    end

    if closest and closestDist <= (Config.BossMenus.textInteractDistance or 2.0) and canOpen(closest) then
      if not textState.showing then
        textState.showing = true
        textState.provider = closest.ui or 'ox_lib'
        UI.textShow(textState.provider, {
          description = ('Åbn %s'):format(closest.label or 'Boss-menu'),
          keybind = 'E',
          icon = 'fas fa-briefcase'
        })
      end

      if IsControlJustPressed(0, Config.BossMenus.interactKey or 38) then
        openBossMenu(closest)
      end
    else
      if textState.showing then
        textState.showing = false
        UI.textHide(textState.provider)
      end
    end
  end
end)
