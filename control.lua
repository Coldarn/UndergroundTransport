require("scripts/constants")
Util = require("scripts/util")
InventoryPool = require("scripts/inventory_pool")
Network = require("scripts/network")
GUI = require("scripts/gui")


script.on_init(Network.init)
script.on_event(defines.events.on_tick, Network.tick)



---Handles cration of a port
---@param event EventData.on_built_entity|EventData.on_robot_built_entity|EventData.on_entity_cloned|EventData.script_raised_built|EventData.script_raised_revive
function handleEntityCreated(event)
  local entity = event.entity or event.destination
  if not Util.isPort(entity) then return end
  Network.addPort(entity)
end
script.on_event(defines.events.on_entity_cloned, handleEntityCreated, EVENT_TYPE_FILTER)
script.on_event(defines.events.on_built_entity, handleEntityCreated, EVENT_TYPE_FILTER)
script.on_event(defines.events.on_robot_built_entity, handleEntityCreated, EVENT_TYPE_FILTER)
script.on_event(defines.events.script_raised_built, handleEntityCreated, EVENT_TYPE_FILTER)
script.on_event(defines.events.script_raised_revive, handleEntityCreated, EVENT_TYPE_FILTER)
script.on_event(defines.events.on_space_platform_built_entity, handleEntityCreated, EVENT_TYPE_FILTER)



---Handle the removal of a port
---@param event EventData.on_entity_died|EventData.on_robot_mined_entity|EventData.on_player_mined_entity|EventData.script_raised_destroy
function handleEntityRemoved(event)
  local entity = event.entity
  local proto = entity.prototype
  if not Util.isPort(entity) then return end
  Network.removePort(entity)
end
script.on_event(defines.events.on_entity_died, handleEntityRemoved, EVENT_TYPE_FILTER)
script.on_event(defines.events.on_robot_mined_entity, handleEntityRemoved, EVENT_TYPE_FILTER)
script.on_event(defines.events.on_player_mined_entity, handleEntityRemoved, EVENT_TYPE_FILTER)
script.on_event(defines.events.script_raised_destroy, handleEntityRemoved, EVENT_TYPE_FILTER)
script.on_event(defines.events.on_space_platform_mined_entity, handleEntityRemoved, EVENT_TYPE_FILTER)



-- Open output port GUI
function handleLeftClick(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  GUI.closeOutputPortGui(player)

  local entity = player.selected
  if not entity or not Util.isPort(entity) or Util.isInput(entity) then return end

  GUI.openOutputPortGui(player, entity)
end
script.on_event(LEFT_CLICK_EVENT, handleLeftClick)



-- function handleGuiOpened(event)
--   if event.gui_type ~= defines.gui_type.entity then return end
  
--   local entity = event.entity
--   if not Util.isPort(entity) then return end

--   log("Opened: "..entity.name)
-- end
-- script.on_event(defines.events.on_gui_opened, handleGuiOpened)


-- function handleEntitySelected(event)
--   local player = game.get_player(event.player_index)
--   local entity = player.selected
--   if not entity or not Util.isPort(entity) then return end

--   log("Opened: "..entity.name)
-- end
-- script.on_event(defines.events.on_selected_entity_changed , handleEntitySelected)


-- function handleCursorChanged(event)
--   local player = game.get_player(event.player_index)
--   local item = player.cursor_stack
--   if not item or not item.valid_for_read then return end
--   if not Util.isPort(item) then return end
  
--   -- TODO: Show correct entity ghost for output ports
--   -- if Util.isInput(item) then
--   --   player.cursor_ghost = 
--   -- end
--   -- log(serpent.line(item))
--   -- item.linked_belt_type = Util.isInput(item) and 'input' or 'output'
-- end
-- script.on_event(defines.events.on_player_cursor_stack_changed, handleCursorChanged)