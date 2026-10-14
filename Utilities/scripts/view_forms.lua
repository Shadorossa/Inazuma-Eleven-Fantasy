-- Utilities › «Cambiar forma» (docs/game/mechanics/form-viewer.md §8.3): the tunables of the form indicator the graft
-- util_view_forms draws in the retail «Ver apariencia» (a dark tile with the form's glyph + a light tile under the
-- bound key's glyph, at the top right of the shown character; layers util_vf_tile / util_vf_badge of
-- content\menus\view_forms.toml). Nothing else: the forms are the VR-Framework's form viewer, the key is
-- assets\lua\_all\utilities_view_forms.lua.
--
-- Command (content\game\view_forms.toml):
--   CMND_UTIL_VIEW_FORMS_CFG() -> {badge_x, badge_y, badge_scale, badge_priority, tile_size, tile_gap, key_scale,
--   key_dx, key_dy} (config.toml [view_forms])

Utilities = Utilities or {}
Utilities.ViewForms = Utilities.ViewForms or {}
local ViewForms = Utilities.ViewForms

-- defaults = config.toml [view_forms] as shipped (the graft has the same values when this script does not answer)
local settings = {
  badge_x = 1720,        -- the row's right edge (screen px of a 1920 x 1080 menu, x right)
  badge_y = 230,         -- the row's vertical centre (screen px, y down)
  badge_scale = 1,       -- the whole row's scale
  badge_priority = 690,  -- the tiles' draw priority (over the 3D model and the formation board); the glyph one above
  tile_size = 52,        -- a tile's side (screen px at scale 1)
  tile_gap = 6,          -- the gap between the two tiles
  key_scale = 0.9,       -- the key glyph's text scale
  key_dx = 0,            -- the key glyph's nudge inside the light tile (screen px)
  key_dy = 0,            -- (y down: < 0 = up)
}

do
  local ok, c = pcall(VRFW.files.config, "view_forms")
  if ok and type(c) == "table" then
    for k, v in pairs(c) do
      if settings[k] ~= nil and type(v) == "number" then settings[k] = v end
    end
  end
end

-- CMND_UTIL_VIEW_FORMS_CFG() -> the indicator's place and size
function ViewForms.Config()
  local answer = {}
  for k, v in pairs(settings) do
    answer[k] = v
  end
  return answer
end

VRFW.log("view_forms: indicator at " .. tostring(settings.badge_x) .. "," .. tostring(settings.badge_y)
  .. " scale " .. tostring(settings.badge_scale) .. " priority " .. tostring(settings.badge_priority)
  .. " tiles " .. tostring(settings.tile_size) .. "+" .. tostring(settings.tile_gap))
