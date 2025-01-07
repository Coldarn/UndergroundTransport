local Network = {
  -- Data model examples:
  -- [surfaceName] = {
  --   inputs = {
  --    [unitNumber] = {
  --      entity=entity,
  --      leftLane={ item=item, buffer={}, bufferLength=10 },
  --      rightLane={ item=item, buffer={}, bufferLength=10 },
  --    },
  --   },
  --   outputs = {
  --    [unitNumber] = {
  --      entity=entity,
  --      leftLane={ item=item, buffer={}, bufferLength=10 },
  --      rightLane={ item=item, buffer={}, bufferLength=10 },
  --    },
  --   },
  --   demands = {
  --    [itemFilterKey] = {
  --      { port=port1, lane=1 },
  --      { port=port1, lane=2 },
  --      lastIndex=#,
  --    },
  --   },
  -- }
}

local MIN_BUFFER_LENGTH = 6 * 4 -- 6 tiles
local BUFFER_LENGTH_RECALC_TICKS = 30 * 60 -- 30 seconds in ticks
local INSERTER_SCAN_RADIUS = 3

function Network.init()
  if not storage.networks then
    storage.networks = {}
  end
end

function trackInput(network, supplies, port, item, laneIndex, inserter)
  -- We have an iteam ready, now check if any outputs want it
  local itemKey = Util.itemFilterToKey(item)
  local demands = network.demands[itemKey]
  if not demands or #demands == 0 then return end

  -- Store this input for delivery down below
  local inputs = supplies[itemKey]
  if not inputs then
    inputs = {}
    supplies[itemKey] = inputs
  end
  table.insert(inputs, { port=port, lane=laneIndex, inserter=inserter })
end

function Network.tick()
  local recalcBufferLenghts = not storage.nextRecalcTick or game.tick >= storage.nextRecalcTick
  if recalcBufferLenghts then
    storage.nextRecalcTick = game.tick + BUFFER_LENGTH_RECALC_TICKS
  end

  for _, surface in pairs(game.surfaces) do
    local network = Network.get(surface.name)
    local supplies = {
      -- [itemFilterKey] = { {port=port1, lane=1}, {port=port1, lane=2} }
    }

    -- Collect all inputs with items ready to deliver
    for _, inPort in pairs(network.inputs) do
      local entity = inPort.entity

      -- Check for items ready on each input port lane
      local canDrop = false
      for idx = 1, 2 do
        local lane = entity.get_transport_line(idx)
        
        -- If there's room to insert an item at the end of the lane, it's not full yet
        if lane.can_insert_at(lane.line_length - 0.25) then
          canDrop = true
          goto laneLoop
        end
        
        -- [1] should be the last item on the lane
        trackInput(network, supplies, inPort, lane[1], idx)
        ::laneLoop::
      end
      if canDrop then
        -- Check if there's an inserter waiting to drop here as well
        local inserters = surface.find_entities_filtered{position=entity.position, radius=INSERTER_SCAN_RADIUS, type="inserter"}
        for _, inserter in pairs(inserters) do
          if inserter.drop_target == entity
            and inserter.held_stack.count > 0
            and Util.positionsEqual(inserter.held_stack_position, inserter.drop_position) then
            trackInput(network, supplies, inPort, inserter.held_stack, nil, inserter)
          end
        end
      end
    end

    if recalcBufferLenghts then
      -- Reset the buffer lengths for each output so they'll update to the farthest recent input
      for _, outPort in pairs(network.outputs) do
        outPort.bufferLength = MIN_BUFFER_LENGTH
      end
    end

    -- Deliver each input item to the next output buffer in the round-robin list
    for itemKey, inputs in pairs(supplies) do
      local demands = network.demands[itemKey]

      Util.tableShuffle(inputs)
      local lastSupplyIdx, inputEntry = next(inputs, nil)
      if not lastSupplyIdx then break end

      for _ = 1, #demands do
        if not demands[demands.lastIndex] then
          demands.lastIndex = 1
        end
        local outputEntry = demands[demands.lastIndex]
        local manhattanDistance = Util.manhattanDistance(inputEntry.port.entity.position, outputEntry.port.entity.position)

        -- Advance to the next output
        demands.lastIndex = demands.lastIndex + 1

        -- Don't proceed unless there's room in this output buffer
        local output = Network.getPortLane(outputEntry.port, outputEntry.lane)
        output.bufferLength = math.max(output.bufferLength, manhattanDistance * 4) -- 4 items/square 

        if #output.buffer < output.bufferLength then
          if inputEntry.lane then
            -- Insert from one of the input's lanes
            local inputLane = inputEntry.port.entity.get_transport_line(inputEntry.lane)
            Network.insertItem(outputEntry.port, output, inputLane[1], manhattanDistance)
          else
            -- Insert from an inserter ready to drop on the input
            local inserter = inputEntry.inserter
            Network.insertItem(outputEntry.port, output, inserter.held_stack, manhattanDistance)
          end

          -- Advance to the next input
          lastSupplyIdx, inputEntry = next(inputs, lastSupplyIdx)
          if not lastSupplyIdx then break end -- No more available
        end
      end
    end

    -- Push items into outputs from their buffers
    for _, output in pairs(network.outputs) do
      for idx = 1, 2 do
        local lane = output.entity.get_transport_line(idx)
        if lane.can_insert_at_back() then
          local portLane = Network.getPortLane(output, idx)
          local buffer = portLane.buffer
          if buffer[1] and buffer[1].arriveTick <= game.tick then
            lane.insert_at_back(buffer[1].inventory[1])
            Network.removeItem(output, portLane, 1)
          end
        end
      end
    end
  end
end

function Network.get(surfaceName)
  local network = storage.networks[surfaceName]
  if not network then
    network = { inputs={}, outputs={}, demands={} }
    storage.networks[surfaceName] = network
  end
  return network
end

function Network.getPortGroup(entity)
  local network = Network.get(entity.surface.name)
  return network[Util.isInput(entity) and 'inputs' or 'outputs']
end

function Network.getPort(entity)
  if not Util.isPort(entity) then return nil end
  if Util.isGhost(entity) then
    return {
      entity=entity,
      itemCounts={},
      leftLane={item=entity.tags[MOD_DATA_LEFT_LANE]},
      rightLane={item=entity.tags[MOD_DATA_RIGHT_LANE]},
    }
  end
  return Network.getPortGroup(entity)[entity.unit_number]
end

function Network.getPortLane(port, lane)
  if lane == 1 then return port.leftLane
  elseif lane == 2 then return port.rightLane end
  return nil
end

-- Inserts an item into the given port and lane's buffer and updates the stack's count
function Network.insertItem(port, lane, itemStack, manhattanDistance)
  local beltStackSize = 1 + port.entity.force.belt_stack_size_bonus
  local insertCount = math.min(itemStack.count, beltStackSize)
  local remainCount = itemStack.count - insertCount

  -- Calculate when the item should arrive based on belt speed and distance
  local outputSpeed = prototypes.entity[port.entity.name].belt_speed

  local entry = {
    inventory=InventoryPool.checkout(),
    arriveTick = game.tick + manhattanDistance / outputSpeed,
  }
  entry.inventory.insert(itemStack)
  entry.inventory[1].count = insertCount
  table.insert(lane.buffer, entry)

  updateItemCount(port, Util.itemFilterToKey(itemStack), insertCount)
  itemStack.count = remainCount
end

-- Removes an item by index from the given port and lane's buffer
function Network.removeItem(port, lane, bufferIndex)
  local entry = lane.buffer[bufferIndex]
  local itemKey = Util.itemFilterToKey(entry.inventory[1])
  local itemCount = entry.inventory[1].count
  InventoryPool.checkin(entry.inventory)
  table.remove(lane.buffer, bufferIndex)

  updateItemCount(port, itemKey, -itemCount)
end

-- Returns a map of itemKey->count for the given port
function Network.getItemCounts(port)
  if not port.itemCounts then
    updateItemCount(port)
  end
  return port.itemCounts
end

-- Updates the static count of items in the given ports buffers
function updateItemCount(port, itemKey, itemCount)
  if not port.itemCounts then
    -- First time accessed we have to count everything in the buffer
    port.itemCounts = {}
    function count(lane)
      for _, entry in ipairs(lane.buffer) do
        local item = entry.inventory[1]
        local key = Util.itemFilterToKey(item)
        if not port.itemCounts[key] then
          port.itemCounts[key] = 0
        end
        port.itemCounts[key] = port.itemCounts[key] + item.count
      end
    end
    count(port.leftLane)
    count(port.rightLane)
  else
    -- After that we can just increment the existing counts
    if not port.itemCounts[itemKey] then
      port.itemCounts[itemKey] = 0
    end
    port.itemCounts[itemKey] = port.itemCounts[itemKey] + itemCount

    if port.itemCounts[itemKey] < 1 then
      port.itemCounts[itemKey] = nil
    end
  end
end

function Network.getDemands(network, itemFilter)
  local demandKey = Util.itemFilterToKey(itemFilter)
  return network.demands[demandKey]
end

function Network.updateDemands(network, port, laneIndex, newItemFilter)
  local oldItemFilter = Network.getPortLane(port, laneIndex).item
  if Util.itemFiltersEqual(oldItemFilter, newItemFilter) then return end
  if oldItemFilter then
    -- Remove the old demand
    local oldDemandKey = Util.itemFilterToKey(oldItemFilter)
    local oldItemDemands = network.demands[oldDemandKey]
    if oldItemDemands then
      Util.tableRemove(oldItemDemands, function (entry)
        return entry.port == port and entry.lane == laneIndex
      end)
      if #oldItemDemands == 0 then
        -- Clean up the demand array if now empty
        network.demands[oldDemandKey] = nil
      end
    end
  end
  if newItemFilter then
    -- Add the new demand
    local newDemandKey = Util.itemFilterToKey(newItemFilter)
    local mewItemDemands = network.demands[newDemandKey]
    if not mewItemDemands then
      mewItemDemands = { lastIndex=0 } -- Track the last output index for round-robin delivery
      network.demands[newDemandKey] = mewItemDemands
    end
    table.insert(mewItemDemands, { port=port, lane=laneIndex })
  end
end

function Network.addPort(entity, priorEntity)
  entity.disconnect_linked_belts()
  entity.linked_belt_type = Util.isInput(entity) and 'input' or 'output'

  if Util.isGhost(entity) then return end
  local newPort = nil

  local upgradeInPlace = not not priorEntity
  local isSameDirection = upgradeInPlace and Util.isInput(entity) == Util.isInput(priorEntity)
  if upgradeInPlace and isSameDirection then
    -- For in-place upgrade, preserve the prior port's settings and buffers but replace the port entity
    local group = Network.getPortGroup(priorEntity)
    local upgradePort = group[priorEntity.unit_number]
    newPort = upgradePort
    newPort.entity = entity
    group[priorEntity.unit_number] = nil
  else
    -- For new ports, create an empty model
    newPort = {
      entity = entity,
      itemCounts = {},
      leftLane = {
        item = nil,
        buffer = {},
        bufferLength = MIN_BUFFER_LENGTH,
      },
      rightLane = {
        item = nil,
        buffer = {},
        bufferLength = MIN_BUFFER_LENGTH,
      },
    }
    if upgradeInPlace then
      -- If the new port direction doesn't match the prior one, remove the old port
      Network.removePort(priorEntity)
    end
  end
  Network.getPortGroup(entity)[entity.unit_number] = newPort

  log("Added: "..entity.name..", "..entity.surface.name)
end

function Network.configurePort(entity, leftLane, rightLane)
  if not entity or not entity.valid then return end

  if Util.isGhost(entity) then
    entity.tags = createSettings(leftLane, rightLane)
  else
  local network = Network.get(entity.surface.name)
  local port = Network.getPort(entity)

  Network.updateDemands(network, port, 1, leftLane)
  Network.updateDemands(network, port, 2, rightLane)
  port.leftLane.item = leftLane
  port.rightLane.item = rightLane
  end
end

function Network.removePort(entity, spillInventory)
  GUI.checkClose(entity)
  if Util.isGhost(entity) then return end

  local network = Network.get(entity.surface.name)
  local portGroup = Network.getPortGroup(entity)
  local port = portGroup[entity.unit_number]

  Network.updateDemands(network, port, 1, nil)
  Network.updateDemands(network, port, 2, nil)
  portGroup[entity.unit_number] = nil

  function spill(lane)
    for _, slot in pairs(lane.buffer) do
      if spillInventory then
        -- Insert into the given inventory
        spillInventory.insert(slot.inventory[1])
      else
        -- Otherwise, spill onto the ground around the port
        entity.surface.spill_item_stack{
          position=entity.position,
          stack=slot.inventory[1],
          allow_belts=false,
        }
      end
      InventoryPool.checkin(slot.inventory)
    end
  end
  spill(port.leftLane)
  spill(port.rightLane)
  log("Removed: "..entity.name..", "..entity.surface.name)

-- Returns configuration settings for the given entity in a tags-compatible table
function Network.exportSettings(entity)
  if Util.isGhost(entity) then
    return entity.tags or {}
  else
    local port = Network.getPort(entity)
    return createSettings(port.leftLane.item, port.rightLane.item)
  end
end

function createSettings(leftItem, rightItem)
  return {
    [MOD_DATA_LEFT_LANE] = leftItem,
    [MOD_DATA_RIGHT_LANE] = rightItem,
  }
end

-- Updates configuration settings for the given entity from the given tags-compatible table
function Network.importSettings(entity, tags)
  if Util.isGhost(entity) then
    entity.tags = tags
  else
  Network.configurePort(entity, tags[MOD_DATA_LEFT_LANE], tags[MOD_DATA_RIGHT_LANE])
  end
end

return Network