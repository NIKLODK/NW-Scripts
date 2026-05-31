local Utils = {}

function Utils.trim(s)
  return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

function Utils.isValidName(s)
  if type(s) ~= 'string' then return false end
  s = Utils.trim(s)
  if #s < 2 or #s > 32 then return false end
  -- ESX job/grade name conventions: lowercase/underscore; allow numbers.
  return s:match('^[a-z0-9_]+$') ~= nil
end

function Utils.isValidLabel(s)
  if type(s) ~= 'string' then return false end
  s = Utils.trim(s)
  local len = #s
  if utf8 and utf8.len then
    local ok, l = pcall(utf8.len, s)
    if ok and l then len = l end
  end
  return len >= 2 and len <= 48
end

function Utils.ensureNumber(n, fallback)
  n = tonumber(n)
  if not n then return fallback end
  return n
end

function Utils.parseCoords(input)
  -- Accept common formats:
  -- "x, y, z"
  -- "vector3(x, y, z)" / "vec3(x, y, z)"
  -- "{x=..., y=..., z=...}" / JSON-ish
  if type(input) ~= 'string' then return nil end
  local s = Utils.trim(input)
  if s == '' then return nil end

  local x, y, z = s:match('vector3%(([-%d%.]+),%s*([-%d%.]+),%s*([-%d%.]+)%)')
  if not x then
    x, y, z = s:match('vec3%(([-%d%.]+),%s*([-%d%.]+),%s*([-%d%.]+)%)')
  end
  if not x then
    x, y, z = s:match('([-%d%.]+)%s*,%s*([-%d%.]+)%s*,%s*([-%d%.]+)')
  end
  if not x then
    x = s:match('[\"%[]?x[\"%]]?%s*[:=]%s*([-%d%.]+)')
    y = s:match('[\"%[]?y[\"%]]?%s*[:=]%s*([-%d%.]+)')
    z = s:match('[\"%[]?z[\"%]]?%s*[:=]%s*([-%d%.]+)')
  end

  x, y, z = tonumber(x), tonumber(y), tonumber(z)
  if not x or not y or not z then return nil end
  return x, y, z
end

return Utils
