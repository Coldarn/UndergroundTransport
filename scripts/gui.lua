local GUI = {}

-- Maps player index to data backing their port configuration window
local PlayerData = {}

local INVENTORY_UPDATE_TICKS = 5
local INVENTORY_PREFIX = 'ut-inventory/'

function GUI.openOutputPortGui(player, entity)
  log("OPENED BY: "..player.index)
  local screen_element = player.gui.screen
  local window = screen_element.add{
    type = "frame",
    direction = "vertical",
  }
  window.style.size = {400, 260}
  window.auto_center = true
  local data = {
    player = player,
    entity = entity,
    port = Network.getPort(entity),
    outputPortWindow = window,
    closeButton = nil,
    chooseLeftButton = nil,
    bothButtonLeft = nil,
    chooseRightButton = nil,
    bothButtonRight = nil,
    inventoryPane = nil,
    inventoryButtons = {},
    dirty = false, -- Set true if a change is made
  }
  PlayerData[player.index] = data

  local titlebar = window.add{ type="flow"}
  titlebar.drag_target = window
  titlebar.add{
    type = "label",
    style = "frame_title",
    caption = {"entity-name."..entity.name},
    ignored_by_interaction = true,
  }
  local filler = titlebar.add{ type="empty-widget", style="draggable_space", ignored_by_interaction=true }
  filler.style.height = 26
  filler.style.horizontally_stretchable = true
  filler.style.margin = {0, 6, 0, 4}
  data.closeButton = titlebar.add{
    type = "sprite-button",
    style = "close_button",
    sprite = "utility/close",
    hovered_sprite = "utility/close_black",
    clicked_sprite = "utility/close_black",
    tooltip = {"gui.close-instruction"},
  }

  local bodyFrame = window.add{ type="frame", direction="vertical", style="entity_frame" }
  local contentFrame = bodyFrame.add{ type="flow", direction="horizontal" }
  local preview = contentFrame.add{ type="entity-preview" }
  preview.style.top_margin = 6
  preview.style.size = {96, 96}
  preview.entity = entity

  local rightColumn = contentFrame.add{ type="flow", direction="vertical" }
  rightColumn.style.vertical_align = "center"
  rightColumn.style.vertical_spacing = 6
  rightColumn.style.left_margin = 10
  rightColumn.add{ type="label", caption={"ui.ut-output-header"} }

  local buttonContainer = rightColumn.add{ type="table", column_count=3 }
  buttonContainer.style.horizontal_spacing = 10
  buttonContainer.style.column_alignments[1] = 'right'

  buttonContainer.add{ type="label", caption={'ui.ut-left-lane'}, style="semibold_label" }
  data.chooseLeftButton = buttonContainer.add{ type="choose-elem-button", elem_type='item-with-quality' }
  data.chooseLeftButton.elem_value = data.port.leftLane.item
  data.bothButtonLeft = buttonContainer.add{ type="button", caption={'ui.ut-both-lanes'} }

  buttonContainer.add{ type="label", caption={'ui.ut-right-lane'}, style="semibold_label" }
  data.chooseRightButton = buttonContainer.add{ type="choose-elem-button", elem_type='item-with-quality' }
  data.chooseRightButton.elem_value = data.port.rightLane.item
  data.bothButtonRight = buttonContainer.add{ type="button", caption={'ui.ut-both-lanes'} }

  bodyFrame.add{ type="label", caption={'ui.ut-inventory-header'} }
  data.inventoryPane = bodyFrame.add{ type="table", column_count=9, column_widths={minimal=40}, wide_as_column_count=true }
  data.inventoryPane.style.height = 40
  data.inventoryPane.style.horizontal_spacing = 0
  data.inventoryPane.style.vertical_spacing = 0

  GUI.updateButtonStates(data)
  GUI.updateInventory()
  data.dirty = false
  player.opened = window
end

function GUI.closeOutputPortGui(event)
  log("Attempted close by: "..event.player_index)
  -- Close the window if the local player is the one who opened it
  local data = PlayerData[event.player_index]
  if data then
    if data.dirty then
      Network.configurePort(data.entity, data.chooseLeftButton.elem_value, data.chooseRightButton.elem_value)
    end
    data.outputPortWindow.destroy()
    PlayerData[event.player_index] = nil
    log("CLOSED BY: "..event.player_index)
  end
end

function GUI.updateButtonStates(data)
  data.bothButtonLeft.enabled = not not data.chooseLeftButton.elem_value
  data.bothButtonRight.enabled = not not data.chooseRightButton.elem_value
  data.dirty = true
end

function GUI.updateInventory()
  if game.tick % INVENTORY_UPDATE_TICKS ~= 0 then return end

  for _, data in pairs(PlayerData) do
    local itemToCount = Network.getItemCounts(data.port)

    -- Add new buttons as needed
    for itemKey, count in pairs(itemToCount) do
      local sprite = "item/"..Util.itemFilterFromKey(itemKey)
      local name = INVENTORY_PREFIX..itemKey
      local button = data.inventoryButtons[itemKey]
      if not button then
        button = data.inventoryPane.add{ type="sprite-button", name=name, sprite=sprite, style="inventory_slot" }
        data.inventoryButtons[itemKey] = button
      end
      button.number = count
    end
    -- Remove buttons matching items no longer in inventory
    for itemKey, button in pairs(data.inventoryButtons) do
      if not itemToCount[itemKey] then
        button.destroy()
        data.inventoryButtons[itemKey] = nil
      end
    end
  end
end

function handleClick(event)
  local data = PlayerData[event.player_index]
  if not data then return end

  if event.element == data.closeButton then
    GUI.closeOutputPortGui(event)
  elseif event.element == data.bothButtonLeft then
    data.chooseRightButton.elem_value = data.chooseLeftButton.elem_value
    GUI.updateButtonStates(data)
  elseif event.element == data.bothButtonRight then
    data.chooseLeftButton.elem_value = data.chooseRightButton.elem_value
    GUI.updateButtonStates(data)
  elseif Util.startsWith(event.element.name, INVENTORY_PREFIX) then
    -- Transfer clicked items into the player's inventory
    local itemKey = string.sub(event.element.name, string.len(INVENTORY_PREFIX) + 1)
    local player = game.get_player(event.player_index)
    local inventory = player.get_main_inventory()
    
    function insertFrom(lane)
      for i = #lane.buffer, 1, -1 do
        local entry = lane.buffer[i]
        local item = entry.inventory[1]
        local key = Util.itemFilterToKey(item)
        if key == itemKey then
          if not inventory.can_insert(item) then break end
          inventory.insert(item)
          Network.removeItem(data.port, lane, i)
        end
      end
    end
    insertFrom(data.port.leftLane)
    insertFrom(data.port.rightLane)
  end
end
script.on_event(defines.events.on_gui_click, handleClick)
script.on_event(defines.events.on_gui_closed, GUI.closeOutputPortGui)

function handleChooseElem(event)
  local data = PlayerData[event.player_index]
  if event.element == data.chooseLeftButton then
    GUI.updateButtonStates(data)
  elseif event.element == data.chooseRightButton then
    GUI.updateButtonStates(data)
  end
end
script.on_event(defines.events.on_gui_elem_changed, handleChooseElem)

return GUI