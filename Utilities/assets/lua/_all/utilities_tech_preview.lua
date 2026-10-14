-- Utilities: the technique preview's helpers in other menus (docs/game/ui/technique-preview.md). The «Supertécnicas»
-- list (graft research/grafts/util_tech_preview) calls them with the retail cross-menu call
-- funcLuaCommand(830228314, menu, name, ...) (it runs the function in that menu's Lua and answers only true):
--   Utilities_TpCarrier("set", layer, model)   in chara_model_only_view_menu: its model layer (hidden) loads the
--                                              performer's model, so the move's event can bind its actor to it (an
--                                              event over the menus only shows models a menu holds)
--   Utilities_TpCarrier("poll", layer, key)    puts 1 (ready) / 2 (gave up) in the parameter store under `key`
--   Utilities_TpCarrier("end", layer)          the layer hidden again (the list closes the menu when it opened it)
--   Utilities_TpBars(1, "crc,crc,…") / (0)     in a header menu: those of its layers that are visible are hidden /
--                                              given back (the header, rank, guide lines: menu-wide hides miss them)
-- Defines functions only; engine calls only when called.
Utilities_TP = type(Utilities_TP) == "table" and Utilities_TP or {}

function Utilities_TpCarrier(op, layer, x)
  local T = Utilities_TP
  if type(layer) ~= "number" then return false end
  if op == "set" then
    pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], layer, 0, false)
    pcall(funcLuaMenuCommand, 59611540 --[[the layer's chara model]], layer, 0, x)
    pcall(funcLuaMenuCommand, 180466856 --[[motion]], layer, 0, 2263925137 --[[立ち1L]], 0, 0)
    pcall(funcLuaMenuCommand, 2232914067 --[[CMND_CHARA_MODEL_CHANGE]], layer, 0, 0, 9)
    pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], layer, 0, false)
    T.polls = 0
    return true
  elseif op == "poll" then
    T.polls = (T.polls or 0) + 1
    local ok, ready = pcall(funcLuaMenuCommand, 1583438030 --[[the layer's model is built]], layer, 0, 0)
    local v = (ok and ready == true and T.polls > 3) and 1 or (T.polls > 600 and 2 or 0)
    if v ~= 0 and type(x) == "number" then
      pcall(funcLuaCommand, 3860611758 --[[param set]], x, 0, v, 1)
    end
    return true
  elseif op == "end" then
    pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], layer, 0, false)
    T.polls = 0
    return true
  end
  return false
end

function Utilities_TpBars(hide, list)
  local T = Utilities_TP
  if hide == 1 or hide == true then
    T.bars = T.bars or {}
    for s in tostring(list or ""):gmatch("[^,]+") do
      local l = tonumber(s)
      if l ~= nil then
        local okn, n = pcall(funcLuaMenuCommand, 1175615627 --[[CMND_GET_CREATE_LAYER_NUM]], l)
        if okn and type(n) == "number" and n > 0 then
          local okv, vis = pcall(funcLuaMenuCommand, 1262717583 --[[CMND_IS_LAYER_VISIBLE]], l, 0)
          if okv and vis == true then
            pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], l, 0, false)
            T.bars[#T.bars + 1] = l
          end
        end
      end
    end
  else
    local b = T.bars or {}
    T.bars = nil
    for i = #b, 1, -1 do
      pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], b[i], 0, true)
    end
  end
  return true
end
