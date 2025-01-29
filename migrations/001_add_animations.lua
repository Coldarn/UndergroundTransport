
-- Adds in animation entities for previously-existing ports
if not storage.networks then return end

for _, surface in pairs(game.surfaces) do
  local network = Network.get(surface.name)
  if not network or network.animationEntities then goto nextSurface end

  network.animationEntities = {}
  for _, input in pairs(network.inputs) do
    AnimationTracker.setup(input.entity)
  end
  for _, output in pairs(network.outputs) do
    AnimationTracker.setup(output.entity)
  end
  ::nextSurface::
end
