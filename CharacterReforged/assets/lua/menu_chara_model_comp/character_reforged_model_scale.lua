-- Character Reforged: the menu 3D model component (menu_chara_model_comp) reads a model's base scale once
-- (CMND_GET_SCALE_OBJECT, kept until ResetCharaScale) and writes «scale x that base» on every later model it builds, so a
-- second player built on the same component took the first one's base scale (chara_scale). The cache is dropped before
-- each build of a new scene chara, so every model gets its own base. A rebuild of an existing scene chara (ChangeCharaModel
-- arg 9, its scale already written) keeps the cache. Lets the player page swap players on one layer (plate_model).
-- Wraps the component's globals; nothing runs at load time.
do
  local change = ChangeCharaModel
  local reset = ResetCharaScale
  if type(change) == "function" and type(reset) == "function" then
    function ChangeCharaModel(...)
      local existing = select(9, ...)      -- an existing scene chara handle to rebuild
      if existing == nil or existing == 0 then
        reset()                            -- a new scene chara: its base scale is read again when it completes
      end
      return change(...)
    end
  end
end
