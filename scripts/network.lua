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

function Network.init()
  if not storage.networks then
    storage.networks = {}
  end
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
      for idx = 1, 2 do
        local lane = entity.get_transport_line(idx)
        -- If there's room to insert an item at the end of the lane, it's not full yet
        if lane.can_insert_at(lane.line_length - 0.25) then goto laneLoop end

        -- [1] should be the last item on the lane
        local item = lane[1]
        if not item then goto laneLoop end

        -- We have an iteam ready, now check if any outputs want it
        local itemKey = Util.itemFilterToKey(item)
        local demands = network.demands[itemKey]
        if not demands or #demands == 0 then goto laneLoop end

        -- Store this input for delivery down below
        local inputs = supplies[itemKey]
        if not inputs then
          inputs = {}
          supplies[itemKey] = inputs
        end
        table.insert(inputs, { port=inPort, lane=idx })

        ::laneLoop::
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

        -- Don't proceed unless there's room in this output buffer
        local output = Network.getPortLane(outputEntry.port, outputEntry.lane)
        output.bufferLength = math.max(output.bufferLength, manhattanDistance * 4) -- 4 items/square 

        if #output.buffer < output.bufferLength then
          -- We're committed to delivery now, update the lastIndex for round-robin
          local inputLane = inputEntry.port.entity.get_transport_line(inputEntry.lane)
          
          -- Calculate when the item should arrive based on belt speed and distance
          local outputSpeed = prototypes.entity[outputEntry.port.entity.name].belt_speed

          -- Move the item from the input to the output
          local entry = {
            inventory=InventoryPool.checkout(),
            tick = game.tick + manhattanDistance / outputSpeed,
          }
          entry.inventory.insert(inputLane[1])
          table.insert(output.buffer, entry)
          inputLane.remove_item(inputLane[1])

          -- Advance to the next output
          demands.lastIndex = demands.lastIndex + 1

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
          local buffer = Network.getPortLane(output, idx).buffer
          if buffer[1] and buffer[1].tick <= game.tick then
            local entry = table.remove(buffer, 1)
            lane.insert_at_back(entry.inventory[1])
            InventoryPool.checkin(entry.inventory)
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
  return network[Util.isInput(entity.prototype) and 'inputs' or 'outputs']
end

function Network.getPort(entity)
  return Network.getPortGroup(entity)[entity.unit_number]
end

function Network.getPortLane(port, lane)
  if lane == 1 then return port.leftLane
  elseif lane == 2 then return port.rightLane end
  return nil
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

function Network.addPort(entity)
  entity.linked_belt_type = Util.isInput(entity.prototype) and 'input' or 'output'

  Network.getPortGroup(entity)[entity.unit_number] = {
    entity = entity,
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
  log("Added: "..entity.name..", "..entity.surface.name)
end

function Network.configurePort(entity, leftLane, rightLane)
  if not entity or not entity.valid then return end

  local network = Network.get(entity.surface.name)
  local port = Network.getPort(entity)

  Network.updateDemands(network, port, 1, leftLane)
  Network.updateDemands(network, port, 2, rightLane)
  port.leftLane.item = leftLane
  port.rightLane.item = rightLane
end

function Network.removePort(entity)
  local network = Network.get(entity.surface.name)
  local portGroup = Network.getPortGroup(entity)
  local port = portGroup[entity.unit_number]

  Network.updateDemands(network, port, 1, nil)
  Network.updateDemands(network, port, 2, nil)
  portGroup[entity.unit_number] = nil

  log("Removed: "..entity.name..", "..entity.surface.name)
end

function Network.exportSettings(entity)
  local port = Network.getPort(entity)
  return {
    [MOD_DATA_LEFT_LANE] = port.leftLane.item,
    [MOD_DATA_RIGHT_LANE] = port.rightLane.item,
  }
end

function Network.importSettings(entity, tags)
  Network.configurePort(entity, tags[MOD_DATA_LEFT_LANE], tags[MOD_DATA_RIGHT_LANE])
end

return Network