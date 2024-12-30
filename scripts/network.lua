local Network = {}

local MIN_BUFFER_LENGTH = 10

function Network.init()
  if not storage.networks then
    storage.networks = {}
  end
end

function Network.tick()
  local recalcBuffers = not storage.nextRecalcTick or game.tick >= storage.nextRecalcTick
  if recalcBuffers then
    storage.nextRecalcTick = game.tick + 600
  end

  for _, surface in pairs(game.surfaces) do
    local network = storage.networks[surface.name]
    local supplies = {
      -- [itemKey] = { {port=port1, lane=1}, {port=port1, lane=2} }
    }

    for _, inPort in ipairs(network.inputs) do
      local entity = inPort.entity
      for idx = 1, 2 do
        -- Check for items ready on each input port lane
        local item = entity.get_transport_line(idx)
        if not item then goto laneLoop end

        -- We have an iteam ready, now check if any outputs want it
        local itemKey = Util.itemFilterToKey(item)
        local demands = network.demands[itemKey]
        if not demands or #demands == 0 then goto laneLoop end

        -- Store this input for later round-robin delivery
        local inputs = supplies[itemKey]
        if not inputs then
          inputs = {}
          supplies[itemKey] = inputs
        end
        table.insert(inputs, { port=inPort, lane=idx})

        ::laneLoop::
      end
    end

    if recalcBuffers then
      for itemKey, outputs in network.demands do
        if #outputs == 0 then
          network.demands[itemKey] = nil
        end
      end
    end

    for itemKey, inputs in pairs(supplies) do
      local demands = network.demands[itemKey]

      local lastDemandIdx = demands.lastIndex
      for i = 0, #demands - 1 do
        demands.lastIndex = (i + lastDemandIdx) % #demands + 1
        local outPort = demands[demands.lastIndex]
        -- TODO: Choose an input and deliver the item to the output
      end
      -- local demandIndex = demands.lastIndex
      -- if demandIndex >= #demands then demandIndex = 0 end
      -- demandIndex = demandIndex + 1
      -- demands.lastIndex = demandIndex

      -- local demand = demands[demandIndex]
      -- local output = demand.entity
      -- local lane = demand.lane
      -- local item = output.get_transport_line(lane)
      -- if item then
      --   local inserted = output.insert_into_transport_line(lane, {name=item.name, count=1})
      --   if inserted > 0 then
      --     local removed = inputs[1].input.remove_item(inputs[1].lane, {name=item.name, count=1})
      --     if removed > 0 then
      --       -- Remove the input from the list if it's now empty
      --       if inputs[1].input.get_item_count(inputs[1].lane) == 0 then
      --         table.remove(inputs, 1)
      --       end
      --     end
      --   end
      -- end
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

function Network.updateDemands(network, port, oldItemFilter, newItemFilter)
  if Util.itemFiltersEqual(oldItemFilter, newItemFilter) then return end
  if oldItemFilter then
    -- Remove the old demand
    local oldDemandKey = Util.itemFilterToKey(oldItemFilter)
    local oldItemDemands = network.demands[oldDemandKey]
    if oldItemDemands then
      Util.tableRemove(oldItemDemands, port)
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
    table.insert(mewItemDemands, port)
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
  local network = Network.get(entity.surface.name)
  local port = Network.getPort(entity)

  Network.updateDemands(network, port, port.leftLane.item, leftLane)
  Network.updateDemands(network, port, port.rightLane.item, rightLane)
  port.leftLane.item = leftLane
  port.rightLane.item = rightLane
end

function Network.removePort(entity)
  local network = Network.get(entity.surface.name)
  local portGroup = Network.getPortGroup(entity)
  local port = portGroup[entity.unit_number]

  Network.updateDemands(network, port, port.leftLane.item, nil)
  Network.updateDemands(network, port, port.rightLane.item, nil)
  portGroup[entity.unit_number] = nil

  log("Removed: "..entity.name..", "..entity.surface.name)
end

return Network