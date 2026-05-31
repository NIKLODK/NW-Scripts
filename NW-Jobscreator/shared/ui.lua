-- UI wrapper for:
-- - context menus (boss menus / admin menus)
-- - text UI prompts for "press E"
--
-- ox_lib is always supported.
-- lation_ui is optional; since lation_ui export APIs differ between versions,
-- this wrapper tries a few common patterns and falls back to ox_lib.

local UI = {}

local function hasLation()
  return GetResourceState('lation_ui') == 'started' and exports.lation_ui ~= nil
end

local function tryLation(methods, ...)
  if not hasLation() then return false end
  for i = 1, #methods do
    local fn = exports.lation_ui[methods[i]]
    if fn then
      local ok = pcall(fn, exports.lation_ui, ...)
      if ok then return true end
    end
  end
  return false
end

function UI.notify(msg, nType, provider)
  provider = provider or 'ox_lib'
  nType = nType or 'info'

  if provider == 'lation_ui' and hasLation() then
    local ok = tryLation({ 'notify', 'Notify' }, {
      title = 'Jobskaber',
      message = msg,
      type = nType
    })
    if ok then return end
  end

  lib.notify({
    title = 'Jobskaber',
    description = msg,
    type = nType
  })
end

-- msg can be string (ox_lib) or a lation_ui config table (lation_ui)
function UI.textShow(provider, msg)
  provider = provider or 'ox_lib'

  if provider == 'lation_ui' and hasLation() then
    if type(msg) == 'string' then
      msg = { description = msg }
    end
    local ok = tryLation({ 'showText', 'ShowText', 'showTextUI', 'ShowTextUI', 'textUI', 'TextUI' }, msg)
    if ok then return end
  end

  if type(msg) == 'table' then
    msg = msg.description or msg.title or 'Press [E]'
  end
  lib.showTextUI(msg)
end

function UI.textHide(provider)
  provider = provider or 'ox_lib'

  if provider == 'lation_ui' and hasLation() then
    local ok = tryLation({ 'hideText', 'HideText', 'hideTextUI', 'HideTextUI' })
    if ok then return end
  end

  lib.hideTextUI()
end

-- provider: 'ox_lib' | 'lation_ui'
-- id: stable menu id string
-- title: string
-- options: array of { title, description?, icon?, onSelect=function() end, disabled? }
function UI.showContext(provider, id, title, options)
  provider = provider or 'ox_lib'

  if provider == 'lation_ui' and hasLation() then
    local registered = tryLation({ 'registerMenu', 'RegisterMenu' }, {
      id = id,
      title = title,
      options = options
    })
    local shown = tryLation({ 'showMenu', 'ShowMenu', 'openMenu', 'OpenMenu' }, id)
    if registered and shown then return end
  end

  lib.registerContext({
    id = id,
    title = title,
    options = options
  })
  lib.showContext(id)
end

function UI.input(title, rows, provider)
  provider = provider or 'ox_lib'
  if provider == 'lation_ui' and hasLation() then
    for _, method in ipairs({ 'input', 'Input', 'inputDialog', 'InputDialog' }) do
      local fn = exports.lation_ui[method]
      if fn then
        local ok, result = pcall(fn, exports.lation_ui, {
          title = title,
          options = rows
        })
        if ok then return result end
      end
    end
  end
  return lib.inputDialog(title, rows)
end

return UI
