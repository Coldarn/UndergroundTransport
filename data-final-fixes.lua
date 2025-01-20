Util = require("scripts/constants")

local TINT = {0.65, 0.65, 0.65} -- to recolor the items and entities
local SUBGROUP_NAME = 'underground-transport'
local IGNORED_PROTOTYPES = {
  -- Compatibility for Extended Range mod: https://mods.factorio.com/mod/RFM-transport
  ['underground-belt-mr'] = 1,
  ['fast-underground-belt-mr'] = 1,
  ['express-underground-belt-mr'] = 1,
  ['underground-belt-lr'] = 1,
  ['fast-underground-belt-lr'] = 1,
  ['express-underground-belt-lr'] = 1,
  ['turbo-underground-belt-mr'] = 1,
  ['turbo-underground-belt-lr'] = 1,
}

function makePort(undergroundPrototype, direction)
  local entity = table.deepcopy(undergroundPrototype)
  entity.type = TYPE
  entity.name = NAME_PREFIX..direction.."-"..undergroundPrototype.name
  entity.minable.result = entity.name
  entity.fast_replaceable_group = TYPE
  if undergroundPrototype.next_upgrade then
    entity.next_upgrade = NAME_PREFIX..direction.."-"..undergroundPrototype.next_upgrade
  end
  entity.localised_name = {"entity-name."..entity.name}
  for _, sprite_4_way in pairs(entity.structure) do -- should maybe be a bit more general to deal with differently defined sprites
    sprite_4_way.sheet.tint = TINT
  end
  -- need to tint entity icon for upgrade planners:
  if undergroundPrototype.icons then
    for _, icon in pairs(entity.icons) do
      icon.tint = TINT
      if direction == 'output' then
        icon.scale = -1
      end
    end
  else
    entity.icons = {{icon=undergroundPrototype.icon, tint=TINT}}
  end

  local item = {
    type = "item-with-tags",
    name = entity.name,
    icon_size = 64,
    icon_mipmaps = 4,
    linked_belt_type = direction,
    icons = {
      { icon="__UndergroundTransport__/graphics/"..direction.."-"..undergroundPrototype.name..".png", icon_size=64, icon_mipmaps=4 }
    },
    subgroup = SUBGROUP_NAME,
    order = data.raw["item"][undergroundPrototype.name].order,
    place_result = entity.name,
    stack_size = 50,
  }
  if direction == 'output' then
    item.can_be_mod_opened = true
  end

  local recipe = { -- doesn't display properly in-game? also need to add unlock
    type = "recipe",
    name = entity.name,
    enabled = false, -- is_enabled_at_game_start is a more descriptive name
    ingredients = {{type="item", name=undergroundPrototype.name, amount=5}},
    results     = {{type="item", name=entity.name, amount=1}}
  }

  data:extend{entity, item, recipe}

  -- Add recipe unlock to the correct technology:
  for _, technology in pairs(data.raw["technology"]) do
    for _, modifier in pairs(technology.effects or {}) do -- some technologies don't have effects
      if modifier.type == "unlock-recipe" then
        if modifier.recipe == undergroundPrototype.name then -- doesn't work if the original recipe has a different name
          table.insert(technology.effects, {type = "unlock-recipe", recipe = entity.name})
          break
        end
      end
    end
  end
end

local subgroup = {
  type = "item-subgroup",
  name = SUBGROUP_NAME,
  group = "logistics",
  order = 'b[belt]-e',
}
local leftClickEvent = {
  type = "custom-input",
  name = LEFT_CLICK_EVENT,
  key_sequence = "mouse-button-1",
}
data:extend{subgroup, leftClickEvent}

for _, prototype in pairs(data.raw["underground-belt"]) do
  if not IGNORED_PROTOTYPES[prototype.name] then
    -- Make the input and output ports
    makePort(prototype, 'input')
    makePort(prototype, 'output')
  end
end
