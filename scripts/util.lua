local Util = {}

---Returns true if a given string starts with another string.
---@param str string String to evaluate
---@param start string String to look for at the beginning of `str`
---@return boolean
function Util.startsWith(str, start)
  if not str then return false end
  return string.sub(str, 1, string.len(start)) == start
end

-- Removes the given value from the table
function Util.tableRemove(tbl, valueOrFunc)
  local checkFn = valueOrFunc
  if type(valueOrFunc) ~= 'function' then
    checkFn = function(v) return v == valueOrFunc end
  end
  for i, v in ipairs(tbl) do
    if checkFn(v) then
      table.remove(tbl, i)
      return
    end
  end
end

-- Randomizes the order of the elements in the table in-place and returns it
function Util.tableShuffle(tbl)
  local tableSize = #tbl
  if tableSize <= 1 then return tbl end
  for i = tableSize, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end

-- Returns a shallow copy of the given table
function Util.tableShallowCopy(tbl)
  local outTable = {}
  for k, v in pairs(tbl) do
    outTable[k] = v
  end
  return outTable
end

-- Returns the orthogonal distance between the two given points
function Util.manhattanDistance(pos1, pos2)
  return math.abs(pos2.x - pos1.x) + math.abs(pos2.y - pos1.y)
end

-- Returns true if the given entity is an underground transport port
function Util.isPort(entity)
  return Util.startsWith(entity.name, NAME_PREFIX)
    or (Util.isGhost(entity) and Util.startsWith(entity.ghost_name, NAME_PREFIX))
end

function Util.isGhost(entity)
  return entity.type == "entity-ghost"
end

-- Returns true if the given underground transport entity is an input.
function Util.isInput(entity)
  return Util.startsWith(entity.name, "ut-input-")
    or (Util.isGhost(entity) and Util.startsWith(entity.ghost_name, "ut-input-"))
end

function Util.itemFilterToKey(filter)
  return filter.name.."/"..(filter.quality.name and filter.quality.name or filter.quality)
end

function Util.itemFilterFromKey(key)
  local splitIndex = string.find(key, '/', 2)
  return string.sub(key, 1, splitIndex - 1), string.sub(key, splitIndex + 1)
end

function Util.itemFiltersEqual(filter1, filter2)
  return filter1 == filter2 or
    (filter1 and filter2 and filter1.name == filter2.name and filter1.quality == filter2.quality)
end

return Util
