NAME_PREFIX = 'ut-'
MOD_DATA_KEY = NAME_PREFIX..'data-'
MOD_DATA_LEFT_LANE = MOD_DATA_KEY..'left'
MOD_DATA_RIGHT_LANE = MOD_DATA_KEY..'right'
BASE_TYPE = "linked-belt"
OVERLAY_TYPE = "electric-energy-interface"
OVERLAY_SUFFIX = "-overlay"
EVENT_TYPE_FILTER = {
  {filter = "type", type = BASE_TYPE},
  {filter = "type", type = "entity-ghost"},
}
LEFT_CLICK_EVENT = 'ut-left-click'