local AnimationTracker = {
  -- Data model examples:
  -- [surfaceName] = {
  --   ...
  --   animationEntities = {
  --     [portEntityUnitNumber] = [animationEntity],
  --   },
  -- }
}

function AnimationTracker.setup(portEntity)
  local network = Network.get(portEntity.surface.name)
  local animEntity = network.animationEntities[portEntity.unit_number]
  if animEntity then
    -- TODO: Verify its still the right animation for this port
    return
  end

  animEntity = portEntity.surface.create_entity{
    name = Util.getAnimEntityName(portEntity),
    position = portEntity.position,
    direction = portEntity.direction,
    force = portEntity.force,
  }
  network.animationEntities[portEntity.unit_number] = animEntity
end

function AnimationTracker.teardown(portEntity)
  local network = Network.get(portEntity.surface.name)
  local animEntity = network.animationEntities[portEntity.unit_number]
  if animEntity then
    animEntity.destroy()
    network.animationEntities[portEntity.unit_number] = nil
  end
end

return AnimationTracker