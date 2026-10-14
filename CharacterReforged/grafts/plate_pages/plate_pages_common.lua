-- Player page in pages (Nacho 2026-10-06; docs/game/ui/ui-redesign.md «Player page: one-row header and 3D model»,
-- round 2): two pages in front of the retail «ATRIBUTOS» page, which keeps only the moves:
--   index 6 = PERFIL (type 8: the description + the 3D model), index 7 = ATRIBUTOS (type 9: the 8 stats as bars),
--   index 0 = SUPERTÉCNICAS (type 1 without the radar), then Hipertécnica (plate_hiper), Equipamiento, Pasivas,
--   Sexto sentido, and the other mods' pages (Utilities' TRAYECTORIA last).
-- The pages are declared to the VR-Framework's player page registry (VRFW_PlayerPages, docs/framework/player-pages.md:
-- CharacterReforged.Profile first, CharacterReforged.Stats after it; Character Reforged's since 2026-10-14, moved from
-- Inazuma Fantasy: docs/refactor/aura-mods-split.md «Player page»); the framework resolves the order at its first
-- use, whatever order the mods' files ran in, and steps Q/E, maps the types and gives the dots' slots (2026-10-09).
-- A wrapper is never wrapped twice (EVT_PPG_WRAPPED). No engine call while the chunk loads.
if EVT_PLATE_PAGES == nil then
  EVT_PLATE_PAGES = true            -- false: no PERFIL / ATRIBUTOS pages (ATRIBUTOS = radar + moves)
end
EVT_PPG_DESC, EVT_PPG_STATS = 6, 7                  -- page indices
EVT_PPG_DESC_TYPE, EVT_PPG_STATS_TYPE = 8, 9        -- personal-plate page types (retail 0-4, Hiper 5, career 6)
if EVT_PLATE_PAGES and VRFW_PlayerPages ~= nil and (EVT_PPG_HOST == nil or EVT_PPG_HOST.pages ~= false) then
  VRFW_PlayerPages.Add({Name = "CharacterReforged.Profile", Index = EVT_PPG_DESC, Type = EVT_PPG_DESC_TYPE, First = true})
  VRFW_PlayerPages.Add({Name = "CharacterReforged.Stats", Index = EVT_PPG_STATS, Type = EVT_PPG_STATS_TYPE,
    After = "CharacterReforged.Profile"})
end
-- round 3: the plate opens on PERFIL. The page index lives in the parents (soccer_formation_menu_inc's local, read and
-- set by GetNowPageIdx / SetNowPageIdx, pure Lua): a fresh menu VM starts it at 0; this moves it to PERFIL once. The
-- chara banks keep their own index (they open on SUPERTÉCNICAS).
-- (a host without pages, research/grafts/plate_pages/host_equip.lua, keeps its own index)
if EVT_PLATE_PAGES and EVT_PPG_START ~= false and not EVT_PPG_STARTED
    and (EVT_PPG_HOST == nil or EVT_PPG_HOST.pages ~= false) and type(GetNowPageIdx) == "function"
    and type(SetNowPageIdx) == "function" then
  local ok, cur = pcall(GetNowPageIdx)
  if ok and cur == 0 then
    pcall(SetNowPageIdx, EVT_PPG_DESC)
  end
  EVT_PPG_STARTED = true
end
if EVT_PPG_WRAPPED == nil then
  EVT_PPG_WRAPPED = {}
end

function EVT_PPG_Wrap(name, make)
  local cur = _ENV[name]
  if type(cur) ~= "function" or EVT_PPG_WRAPPED[cur] then
    return false
  end
  local w = make(cur)
  EVT_PPG_WRAPPED[w] = true
  _ENV[name] = w
  return true
end

-- round 9: the Pasivas cursor mode of the plate (R3 on that page): while it runs, this menu's card focus is off and
-- its left / right page steps and its back are swallowed (the plate moves its cursor / leaves the mode instead).
-- Called by the plate through funcLuaCommand(830228314, <this menu>, "EVT_PPG_SetCursor", on).
EVT_PPG_CURSOR = false
function EVT_PPG_SetCursor(on)
  EVT_PPG_CURSOR = on == true
  for _, l in ipairs({1973487846, 1658289671}) do      -- team00_01_chara_card_for_soccer / _for_leader
    pcall(funcLuaMenuCommand, 3518307824, l, not EVT_PPG_CURSOR)
  end
  return true
end
EVT_PPG_Wrap("OnFunctionCommonLeftAndRight", function(orig)
  return function(a1, ...)
    if EVT_PPG_CURSOR and (a1 == 2053629800 or a1 == 3033167124) then
      return 1
    end
    return orig(a1, ...)
  end
end)
EVT_PPG_Wrap("FuncOnBack", function(orig)
  return function(...)
    if EVT_PPG_CURSOR then
      pcall(funcLuaCommand, 3661580131, "EVT_PPG back swallowed (Pasivas cursor mode)")
      return
    end
    return orig(...)
  end
end)

-- pointer (2026-10-06, docs/game/ui/mouse-support.md §5): a click on a page dot / the Q / E glyph of the plate asks the
-- menu that owns the page index to step through its OWN Q/E path (retail guards, sound, animation, its index): the
-- plate calls funcLuaCommand(830228314, <this menu>, "EVT_PPG_PointerPage", target, dir, bank). `target` = a page
-- index the registry's next step answers once (VRFW_PlayerPages.Goto), nil = a plain Q (dir -1) / E (dir 1) step.
function EVT_PPG_PointerPage(target, dir, bank)
  local P = VRFW_PlayerPages
  if type(target) == "number" and P ~= nil then
    P.Goto(target)
  end
  local right = type(dir) == "number" and dir > 0
  local ok, err = true, nil
  if type(OnFunction) == "function" then
    if bank == true then
      ok, err = pcall(OnFunction, 3959000859, right and 70193212 --[[next]] or 3168962645 --[[prev]])
    else
      ok, err = pcall(OnFunction, right and 3033167124 --[[right]] or 2053629800 --[[left]])
    end
  end
  if P ~= nil then
    P.Goto(nil)
  end
  if not ok then
    pcall(funcLuaCommand, 3661580131, "EVT_PPG pointer page error", tostring(err))
  end
  return ok
end
