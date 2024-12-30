local Util = {}

---Returns true if a given string starts with another string.
---@param str string String to evaluate
---@param start string String to look for at the beginning of `str`
---@return boolean
function Util.startsWith(str, start)
  return string.sub(str, 1, string.len(start)) == start
end

-- Removes the given value from the table
function Util.tableRemove(tbl, value)
  for i, v in ipairs(tbl) do
    if v == value then
      table.remove(tbl, i)
      return
    end
  end
end

-- Returns true if the given entity is an underground transport port
function Util.isPort(entity)
  return Util.startsWith(entity.name, NAME_PREFIX)
end

-- Returns true if the given underground transport entity is an input.
function Util.isInput(entity)
  return Util.startsWith(entity.name, "ut-input-")
end

function Util.itemFilterToKey(filter)
  return filter.name.."/"..filter.quality
end

function Util.itemFiltersEqual(filter1, filter2)
  return filter1 == filter2 or
    (filter1 and filter2 and filter1.name == filter2.name and filter1.quality == filter2.quality)
end

return Util
