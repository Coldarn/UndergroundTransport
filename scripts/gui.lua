local GUI = {
  player = nil,
  entity = nil,
  port = nil,
  outputPortWindow = nil,
  closeButton = nil,
  chooseLeftButton = nil,
  bothButtonLeft = nil,
  chooseRightButton = nil,
  bothButtonRight = nil,
  inventoryPane = nil,
  inventoryButtons = {},
}

local INVENTORY_UPDATE_TICKS = 5
local INVENTORY_PREFIX = 'ut-inventory/'

function GUI.openOutputPortGui(player, entity)
  local screen_element = player.gui.screen
  local window = screen_element.add{
    type = "frame",
    direction = "vertical",
  }
  window.style.size = {400, 260}
  window.auto_center = true
  GUI.player = player
  GUI.entity = entity
  GUI.outputPortWindow = window

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
  GUI.closeButton = titlebar.add{
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

  GUI.port = Network.getPort(entity)
  buttonContainer.add{ type="label", caption={'ui.ut-left-lane'}, style="semibold_label" }
  GUI.chooseLeftButton = buttonContainer.add{ type="choose-elem-button", elem_type='item-with-quality' }
  GUI.chooseLeftButton.elem_value = GUI.port.leftLane.item
  GUI.bothButtonLeft = buttonContainer.add{ type="button", caption={'ui.ut-both-lanes'} }

  buttonContainer.add{ type="label", caption={'ui.ut-right-lane'}, style="semibold_label" }
  GUI.chooseRightButton = buttonContainer.add{ type="choose-elem-button", elem_type='item-with-quality' }
  GUI.chooseRightButton.elem_value = GUI.port.rightLane.item
  GUI.bothButtonRight = buttonContainer.add{ type="button", caption={'ui.ut-both-lanes'} }

  bodyFrame.add{ type="label", caption={'ui.ut-inventory-header'} }
  GUI.inventoryPane = bodyFrame.add{ type="table", column_count=9, column_widths={minimal=40}, wide_as_column_count=true }
  GUI.inventoryPane.style.height = 40
  GUI.inventoryPane.style.horizontal_spacing = 0
  GUI.inventoryPane.style.vertical_spacing = 0

  GUI.updateButtonStates()
  GUI.updateInventory()
  player.opened = window
  script.on_nth_tick(INVENTORY_UPDATE_TICKS, GUI.updateInventory)
end

function GUI.closeOutputPortGui(event)
  if GUI.outputPortWindow then
    Network.configurePort(GUI.entity, GUI.chooseLeftButton.elem_value, GUI.chooseRightButton.elem_value)
    GUI.outputPortWindow.destroy()
    GUI.outputPortWindow = nil
    GUI.inventoryButtons = {}
    script.on_nth_tick(INVENTORY_UPDATE_TICKS, nil)
  end
end

function GUI.updateButtonStates()
  GUI.bothButtonLeft.enabled = not not GUI.chooseLeftButton.elem_value
  GUI.bothButtonRight.enabled = not not GUI.chooseRightButton.elem_value
end

function GUI.updateInventory()
  local itemToCount = Network.getItemCounts(GUI.port)

  -- Add new buttons as needed
  for itemKey, count in pairs(itemToCount) do
    local sprite = "item/"..Util.itemFilterFromKey(itemKey)
    local name = INVENTORY_PREFIX..itemKey
    local button = GUI.inventoryButtons[itemKey]
    if not button then
      button = GUI.inventoryPane.add{ type="sprite-button", name=name, sprite=sprite, style="inventory_slot" }
      GUI.inventoryButtons[itemKey] = button
    end
    button.number = count
  end
  -- Remove buttons matching items no longer in inventory
  for itemKey, button in pairs(GUI.inventoryButtons) do
    if not itemToCount[itemKey] then
      button.destroy()
      GUI.inventoryButtons[itemKey] = nil
    end
  end
end

function handleClick(event)
  if event.element == GUI.closeButton then
    GUI.closeOutputPortGui(event)
  elseif event.element == GUI.bothButtonLeft then
    GUI.chooseRightButton.elem_value = GUI.chooseLeftButton.elem_value
    GUI.updateButtonStates()
  elseif event.element == GUI.bothButtonRight then
    GUI.chooseLeftButton.elem_value = GUI.chooseRightButton.elem_value
    GUI.updateButtonStates()
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
          Network.removeItem(GUI.port, lane, i)
        end
      end
    end
    insertFrom(GUI.port.leftLane)
    insertFrom(GUI.port.rightLane)
  end
end
script.on_event(defines.events.on_gui_click, handleClick)
script.on_event(defines.events.on_gui_closed, GUI.closeOutputPortGui)

function handleChooseElem(event)
  if event.element == GUI.chooseLeftButton then
    GUI.updateButtonStates()
  elseif event.element == GUI.chooseRightButton then
    GUI.updateButtonStates()
  end
end
script.on_event(defines.events.on_gui_elem_changed, handleChooseElem)

return GUI