local Auth = {}

local function listContains(list, value)
  if type(list) ~= 'table' or value == nil then return false end
  for _, v in ipairs(list) do
    if v == value then return true end
  end
  return false
end

local function getDiscordId(src)
  local count = GetNumPlayerIdentifiers(src)
  for i = 0, count - 1 do
    local identifier = GetPlayerIdentifier(src, i)
    if identifier and identifier:sub(1, 8) == 'discord:' then
      return identifier:sub(9)
    end
  end
  return nil
end

local function getESX()
  if GetResourceState('es_extended') ~= 'started' then return nil end
  local ok, obj = pcall(function()
    return exports['es_extended']:getSharedObject()
  end)
  if ok then return obj end
  return nil
end

local function getESXGroup(src)
  local ESX = getESX()
  if not ESX or type(ESX.GetPlayerFromId) ~= 'function' then return nil end
  local xPlayer = ESX.GetPlayerFromId(src)
  if not xPlayer then return nil end

  -- ESX variants expose group in different ways.
  if type(xPlayer.getGroup) == 'function' then
    local ok, group = pcall(function() return xPlayer.getGroup() end)
    if ok then return group end
  end
  if type(xPlayer.getGroup) == 'string' then
    return xPlayer.getGroup
  end
  if type(xPlayer.group) == 'string' then
    return xPlayer.group
  end

  return nil
end

function Auth.isAdmin(src)
  if src == 0 then return true end

  local cfg = Config.Admin or {}

  local ace = cfg.ace or Config.AdminAce
  if ace and IsPlayerAceAllowed(src, ace) then
    return true
  end

  local discordId = getDiscordId(src)
  if discordId and listContains(cfg.discordIds, discordId) then
    return true
  end

  local group = getESXGroup(src)
  if group and listContains(cfg.esxGroups, group) then
    return true
  end

  return false
end

return Auth

