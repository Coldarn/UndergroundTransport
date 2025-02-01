Util = require("scripts/util")

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
local EMPTY_SPRITE4WAY = {
  sheet = {
    filename = "__core__/graphics/empty.png",
    size = {1, 1},
  }
}
local FRAME_COUNT = 14
local FRAME_SCALE = 0.5

function makePort(undergroundPrototype, direction)
  local entity = table.deepcopy(undergroundPrototype)
  entity.type = BASE_TYPE
  entity.name = NAME_PREFIX..direction.."-"..undergroundPrototype.name
  entity.minable.result = entity.name
  entity.fast_replaceable_group = BASE_TYPE
  if undergroundPrototype.next_upgrade then
    entity.next_upgrade = NAME_PREFIX..direction.."-"..undergroundPrototype.next_upgrade
  end
  entity.localised_name = {"entity-name."..entity.name}
  for key in pairs(entity.structure) do -- should maybe be a bit more general to deal with differently defined sprites
    entity.structure[key] = EMPTY_SPRITE4WAY
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

  -- Provides the visible animation and power draw as underground belts support neither
  local anim = {
    layers = {
      {
        filename = "__UndergroundTransport__/graphics/normal/"..direction..".png",
        frame_count = FRAME_COUNT,
        size = {70, 84},
        line_length = 7,
        lines_per_file = 2,
        scale = FRAME_SCALE,
        animation_speed = 0.4, -- 24 FPS
        shift = {-0.5, -0.62},
        priority = 'extra-high',
        -- shift = util.mul_shift(util.by_pixel(-50, -64), FRAME_SCALE),
      },
      {
        filename = "__UndergroundTransport__/graphics/normal/"..direction.."-shadow.png",
        frame_count = FRAME_COUNT,
        size = {75, 64},
        line_length = 7,
        lines_per_file = 2,
        scale = 0.75,
        animation_speed = 0.4, -- 24 FPS
        shift = {-0.4, -0.5},
        draw_as_shadow = true,
        priority = 'extra-high',
      },
    }
  }
  local overlayEntity = {
    type = OVERLAY_TYPE,
    name = Util.getAnimEntityName(entity),
    localised_name = {"entity-name."..entity.name},
    hidden = true,
    hidden_in_factoriopedia = true,
    selectable_in_game = false,
    -- TODO: Add icons for the electric network info charts
    -- TODO: Scale energy usage by belt tier
    energy_usage = "50kW",
    energy_source = {
      type = "electric",
      buffer_capacity = "1MJ",
      usage_priority = "secondary-input",
      input_flow_limit = "50kW",
      output_flow_limit = "0W"
    },
    animations = {
      north = anim,
      east = anim,
      south = anim,
      west = anim,
    },
    continuous_animation = true,
  }

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
    ingredients = {{type="item", name=undergroundPrototype.name, amount=4}},
    results     = {{type="item", name=entity.name, amount=1}}
  }

  data:extend{entity, overlayEntity, item, recipe}

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
