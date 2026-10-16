-- Player Training › no bean exchange («Canjear judías», beans_trade_menu). With the classic training the beans give
-- nothing and no bean is ever given (content\items\no_training_beans.toml, VR-Framework [[VRFW.MatchDropRemove]]
-- AllSources), so the exchange would take beans and give none: it is closed and its button guide is not drawn.
-- 1. The opener: MENU_DEF.OpenBeansTradeMenuCore (include menu_def: the item bag, the Mercado, the spirit list and the
--    rarity-up screen) opens nothing; the skill board's OpenBeansTradeMenu / OpenBeansTradeMenu_Coroutine (it opens the
--    menu itself) return at once.
-- 2. The button guide: every screen sets its footer guides with funcLuaMenuCommand(SET_BUTTON_GUIDE, menu, layer,
--    texts, ...) and then their keys with funcLuaMenuCommand(SET_BUTTON_GUIDE_KEYS, menu, layer, keys). The entry whose
--    text is «Canjear judías» is taken out of the first call's lists (every list of the same length) and the same place
--    out of the keys of the next call for that menu and layer, so no screen draws it (the bag, the Mercado, the spirit
--    list, the rarity-up screen, the skill board). funcLuaMenuCommand is registered by the engine after the patches:
--    it is wrapped when it is defined (a __newindex on the globals, chained with any earlier one), or at once if it
--    already is.
-- Every menu VM; no engine call at chunk load; no retail function redefined.
local BEANS_TRADE_TEXT = 193274065           -- menu_text «Canjear judías»
local SET_BUTTON_GUIDE = 2209673388          -- (menu, layer, texts, ...): the footer guides
local SET_BUTTON_GUIDE_KEYS = 452337289      -- (menu, layer, keys): their keys

local function nothing()
  return nil
end

if type(MENU_DEF) == "table" and type(MENU_DEF.OpenBeansTradeMenuCore) == "function" then
  MENU_DEF.OpenBeansTradeMenuCore = nothing
end
if type(OpenBeansTradeMenu) == "function" then
  OpenBeansTradeMenu = nothing
end
if type(OpenBeansTradeMenu_Coroutine) == "function" then
  OpenBeansTradeMenu_Coroutine = nothing
end

-- the guide places taken out, by menu and layer, until their keys are set
local removed_place = {}

local function without_place(list, place)
  local out = {}
  for i = 1, #list do
    if i ~= place then
      out[#out + 1] = list[i]
    end
  end
  return out
end

local function filtered_guide_arguments(args, count)
  local texts = args[4]
  if type(texts) ~= "table" then
    return nil
  end
  local place = nil
  for i = 1, #texts do
    if texts[i] == BEANS_TRADE_TEXT then
      place = i
      break
    end
  end
  if place == nil then
    return nil
  end
  local size = #texts
  for k = 4, count do
    if type(args[k]) == "table" and #args[k] == size then
      args[k] = without_place(args[k], place)
    end
  end
  removed_place[tostring(args[2]) .. ":" .. tostring(args[3])] = place
  return args
end

local function wrap_menu_command(command)
  return function(...)
    local id = ...
    if id == SET_BUTTON_GUIDE then
      local count = select("#", ...)
      local args = {...}
      local ok, filtered = pcall(filtered_guide_arguments, args, count)
      if ok and filtered ~= nil then
        return command(table.unpack(filtered, 1, count))
      end
    elseif id == SET_BUTTON_GUIDE_KEYS then
      local count = select("#", ...)
      local args = {...}
      local key = tostring(args[2]) .. ":" .. tostring(args[3])
      local place = removed_place[key]
      if place ~= nil and type(args[4]) == "table" then
        removed_place[key] = nil
        args[4] = without_place(args[4], place)
        return command(table.unpack(args, 1, count))
      end
    end
    return command(...)
  end
end

if type(funcLuaMenuCommand) == "function" then
  funcLuaMenuCommand = wrap_menu_command(funcLuaMenuCommand)
else
  local ok_meta, meta = pcall(getmetatable, _ENV)
  if ok_meta and (meta == nil or type(meta) == "table") then
    if meta == nil then
      meta = {}
      if not pcall(setmetatable, _ENV, meta) then
        meta = nil
      end
    end
    if meta ~= nil then
      local previous = meta.__newindex
      meta.__newindex = function(globals, key, value)
        if previous == nil then
          rawset(globals, key, value)
        elseif type(previous) == "function" then
          previous(globals, key, value)
        else
          previous[key] = value
        end
        if key == "funcLuaMenuCommand" and type(value) == "function" then
          local stored = rawget(globals, key)
          if type(stored) == "function" then
            rawset(globals, key, wrap_menu_command(stored))
          end
        end
      end
    end
  end
end
