local UndoTracker = {
  recentRemovals = {}, -- array of recently-removed ports
}

local UNDO_RECORD_SEEN_TAG = 'ut-undo-seen'

function UndoTracker.tick()
  -- Detect each time a player's undo stack changes so we can apply undo data
  for _, player in pairs(game.players) do
    local undoStack = player.undo_redo_stack

    -- Add a unique tag to the top undo and redo records to identify when they change
    local hasUndoEntry = undoStack.get_undo_item_count() > 0
    local lastUndoItemTick = hasUndoEntry and undoStack.get_undo_tag(1, 1, UNDO_RECORD_SEEN_TAG)
    local needsUndo = hasUndoEntry and (not lastUndoItemTick or lastUndoItemTick + 1 >= game.tick)
    
    local hasRedoEntry = undoStack.get_redo_item_count() > 0
    local lastRedoItemTick = hasRedoEntry and undoStack.get_redo_tag(1, 1, UNDO_RECORD_SEEN_TAG)
    local needsRedo = hasRedoEntry and (not lastRedoItemTick or lastRedoItemTick + 1 >= game.tick)

    if needsUndo or needsRedo then
      if hasUndoEntry and not lastUndoItemTick then
        -- log('UNDO: '..player.index..', '..serpent.line(undoStack.get_undo_item(1)))
        undoStack.set_undo_tag(1, 1, UNDO_RECORD_SEEN_TAG, game.tick)
      end
      if hasRedoEntry and not lastRedoItemTick then
        -- log('REDO: '..player.index..', '..serpent.line(undoStack.get_redo_item(1)))
        undoStack.set_redo_tag(1, 1, UNDO_RECORD_SEEN_TAG, game.tick)
      end

      -- Update the undo records with settings from recently removed ports
      local actions = undoStack[needsUndo and 'get_undo_item' or 'get_redo_item'](1) -- Latest entries are at the top
      for _, entry in ipairs(UndoTracker.recentRemovals) do
        for actionIdx, action in pairs(actions) do
          if action.type ~= 'removed-entity' then goto nextAction end
          if action.surface_index ~= entry.surface_index then goto nextAction end
          
          if Util.positionsEqual(action.target.position, entry.position) then
            for key, value in pairs(entry.tags) do
              undoStack[needsUndo and 'set_undo_tag' or 'set_redo_tag'](1, actionIdx, key, value)
              -- log('SET TAG')
            end
            break
          end
          ::nextAction::
        end
      end
    end
  end
  
  -- Clear out the recent removals so we don't apply them later by accident
  for idx in pairs(UndoTracker.recentRemovals) do
    UndoTracker.recentRemovals[idx] = nil
    -- log("CLEAR RECENT REMOVAL")
  end
end

-- Records data for the given removed port so we can update the undo record next tick
function UndoTracker.recordPortRemoved(entity, tags)
  table.insert(UndoTracker.recentRemovals, {
    name = entity.name,
    type = entity.type,
    unit_number = entity.unit_number,
    surface_index = entity.surface.index,
    position = entity.position,
    tags = tags,
  })
end

return UndoTracker