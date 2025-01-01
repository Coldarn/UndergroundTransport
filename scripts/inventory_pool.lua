local InventoryPool = {
  pool = {}
}

function InventoryPool.checkout()
  local inventory = next(InventoryPool.pool, nil)
  if inventory then
    InventoryPool.pool[inventory] = nil
  else
    inventory = game.create_inventory(1)
  end
  return inventory
end

function InventoryPool.checkin(inventory)
  InventoryPool.pool[inventory] = true
  inventory.clear()
end

return InventoryPool