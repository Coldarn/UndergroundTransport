local GUI = {
  player = nil,
  entity = nil,
  outputPortWindow = nil,
  closeButton = nil,
  chooseLeftButton = nil,
  bothButtonLeft = nil,
  chooseRightButton = nil,
  bothButtonRight = nil,
}

function GUI.openOutputPortGui(player, entity)
  local screen_element = player.gui.screen
  local window = screen_element.add{
    type = "frame",
    direction = "vertical",
  }
  window.style.size = {400, 200}
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

  local contentFrame = window.add{ type="frame", name="content_frame", direction="horizontal", style="entity_frame" }
  local preview = contentFrame.add{ type="entity-preview" }
  preview.style.top_margin = 6
  preview.style.size = {96, 96}
  preview.entity = entity

  local rightColumn = contentFrame.add{ type="flow", direction="vertical" }
  rightColumn.style.vertical_align = "center"
  rightColumn.style.vertical_spacing = 6
  rightColumn.style.left_margin = 10
  rightColumn.add{ type="label", caption="Select items to output from the network" }

  local buttonContainer = rightColumn.add{ type="table", column_count=3 }
  buttonContainer.style.horizontal_spacing = 10
  buttonContainer.style.column_alignments[1] = 'right'

  local port = Network.getPort(entity)
  buttonContainer.add{ type="label",  caption='Left lane:', style="semibold_label" }
  GUI.chooseLeftButton = buttonContainer.add{ type="choose-elem-button", elem_type='item-with-quality' }
  GUI.chooseLeftButton.elem_value = port.leftLane
  GUI.bothButtonLeft = buttonContainer.add{ type="button", caption="Set both lanes" }

  buttonContainer.add{ type="label", caption='Right lane:', style="semibold_label" }
  GUI.chooseRightButton = buttonContainer.add{ type="choose-elem-button", elem_type='item-with-quality', elem_value=port.rightLane }
  GUI.chooseRightButton.elem_value = port.rightLane
  GUI.bothButtonRight = buttonContainer.add{ type="button", caption="Set both lanes" }

  GUI.updateButtonStates()
  player.opened = window
end

function GUI.closeOutputPortGui(event)
  if GUI.outputPortWindow then
    Network.configurePort(GUI.entity, GUI.chooseLeftButton.elem_value, GUI.chooseRightButton.elem_value)
    GUI.outputPortWindow.destroy()
    GUI.outputPortWindow = nil
  end
end

function GUI.updateButtonStates()
  GUI.bothButtonLeft.enabled = not not GUI.chooseLeftButton.elem_value
  GUI.bothButtonRight.enabled = not not GUI.chooseRightButton.elem_value
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