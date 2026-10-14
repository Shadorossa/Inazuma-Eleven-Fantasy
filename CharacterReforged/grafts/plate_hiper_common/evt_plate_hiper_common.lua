-- ===== EVT plate_hiper common BEGIN =====
-- Personal plate (team dock / formation / bank player panel): the page "Hipertécnica" after the moves page. Built by
-- research/scripts/plate_hiper_build.py, docs/game/skill-slots.md ("Hiper page on the personal plate"). Plain Lua 5.2.
-- The page is index 4 (page type 5), declared to the VR-Framework's player page registry (VRFW_PlayerPages,
-- docs/framework/player-pages.md: CharacterReforged.Hiper after vrfw.Moves). Character Reforged's since 2026-10-14
-- (moved from Inazuma Fantasy; docs/refactor/aura-mods-split.md «Player page»): the framework owns the order, the
-- index -> type map and the Q/E steps of the parents and the plate (2026-10-09; this block's own step wrappers are
-- gone).
-- This block is appended to the parent menus and the banks (plain Lua) and grafted into personal_plate_menu. A wrapper
-- is never wrapped twice (EVT_PH_WRAPPED), and a fresh retail definition (chunk run again) is wrapped again.
if EVT_PLATE_HIPER == nil then
  EVT_PLATE_HIPER = true            -- false: no Hiper page
end
EVT_PH_PAGE = 4                     -- page index of the Hiper page
EVT_PH_TYPE = 5                     -- its personal-plate page type (retail types 0-4)
if EVT_PH_WRAPPED == nil then
  EVT_PH_WRAPPED = {}
end

-- The Hiper page is the page of the new skill set's aura / mix slots: shown only while Character Reforged's option
-- «Tabla de habilidades» is on the new set (row character_reforged.skill_set_view; CharacterReforged.Page.SkillSetOn,
-- assets\lua\_all\character_reforged_page.lua). Asked by the registry's steps / dots (its Enabled), never while the
-- chunk loads; read each time, so switching the option needs no restart.
function EVT_PH_HiperOn()
  local page = type(CharacterReforged) == "table" and CharacterReforged.Page or nil
  return type(page) == "table" and type(page.SkillSetOn) == "function" and page.SkillSetOn() == true
end

if VRFW_PlayerPages ~= nil then
  VRFW_PlayerPages.Add({Name = "CharacterReforged.Hiper", Index = EVT_PH_PAGE, Type = EVT_PH_TYPE, After = "vrfw.Moves",
    Enabled = function()
      return EVT_PLATE_HIPER and EVT_PH_HiperOn()
    end})
end

-- next page index from `cur` in direction dir (+1 E / -1 Q); `count` = the rows of the caller's page table (chara
-- bank: #t2). The registry's step (the banks' page code, graft plate_hiper_bank, calls this name).
function EVT_PlateHiperStep(cur, dir, count)
  if VRFW_PlayerPages ~= nil then
    return VRFW_PlayerPages.Step(cur, dir, count)
  end
  return cur
end

function EVT_PH_Wrap(name, make)
  local cur = _ENV[name]
  if type(cur) ~= "function" or EVT_PH_WRAPPED[cur] then
    return false
  end
  local w = make(cur)
  EVT_PH_WRAPPED[w] = true
  _ENV[name] = w
  return true
end
-- ---- bottom button guide (2026-09-24): no "Aceptar", one "<Q><E> Desplazarte" entry for the plate pages ---------
-- The formation / team dock default guide (SetupDefaultFormationButtonGuide) adds "Aceptar" (menu_text 1847312674,
-- CMD_ENTER); it is dropped (Enter / mouse / A still work). Our entry: label menu_text crc32("evt_ph_guide_scroll")
-- = "Desplazarte", keys crc32("evt_ph_guide_keys") = "<CMD_FUNCL2><CMD_FUNCR2>" (Q E on keyboard, LT RT on a pad),
-- both added to common/text/es/menu_text by the builder. The Q/E glyphs next to the plate arrows are hidden in the
-- plate script. The chara bank calls EVT_PH_GuideEdit on its own guide arrays (patched in by the builder).
if EVT_PH_GUIDE == nil then
  EVT_PH_GUIDE = true
end
EVT_PH_GUIDE_ACCEPT = 1847312674        -- "Aceptar"
EVT_PH_GUIDE_TEXT = 1622554036          -- "Desplazarte"
EVT_PH_GUIDE_KEYS = 249694208           -- "<CMD_FUNCL2><CMD_FUNCR2>"
EVT_PH_CMD_ENTER = 1981080283

-- chara bank: guide arrays (texts, keys, offsets, t18, greyout, commands); `plate` = the personal plate is open
function EVT_PH_GuideEdit(plate, texts, keys, offs, t18, grey, cmds)
  if not EVT_PH_GUIDE or not plate then
    return texts, keys, offs, t18, grey, cmds
  end
  local n = #texts
  for k = n, 1, -1 do
    if texts[k] == EVT_PH_GUIDE_ACCEPT and (cmds == nil or cmds[k] == nil or cmds[k] == EVT_PH_CMD_ENTER) then
      local all = {texts, keys, offs, t18, grey, cmds}
      for i = 1, 6 do
        local arr = all[i]
        if arr ~= nil and #arr >= k then
          table.remove(arr, k)
        end
      end
    end
  end
  -- 2026-09-25 (user): no "Desplazarte" entry any more; the plate shows the Q / E glyphs by its page dots
  return texts, keys, offs, t18, grey, cmds
end

EVT_PH_Wrap("AddButtonGuideInfo", function(orig)
  return function(a1, a2, a3, a4, a5, a6, ...)
    if EVT_PH_IN_GUIDE and EVT_PH_GUIDE and a1 == EVT_PH_GUIDE_ACCEPT and a6 == EVT_PH_CMD_ENTER then
      return
    end
    return orig(a1, a2, a3, a4, a5, a6, ...)
  end
end)

-- "<L3> Miximax" (2026-09-25): while the personal plate shows the Atributos page of a player with a fusion, the plate
-- sets the loader UI flag evt_r9_mx_hint; the parent menu (team dock / formation) adds the entry to its guide and
-- rebuilds the guide when the flag changes. Not in the plate menu itself (it has no SetupDefault... guide of its own).
EVT_PH_MX_HINT_KEY = 1361529897         -- crc32("evt_r9_mx_hint")
EVT_PH_MX_TEXT = 3716432925             -- menu_text "Miximax"
EVT_PH_MX_KEYS = 3378555688             -- menu_text "<CMD_FUNC5>"
EVT_PH_UI_FLAG_GET = 100903117          -- CMND_EVT_UI_FLAG_GET

function EVT_PH_MxHint()
  local ok, v = pcall(funcLuaCommand, EVT_PH_UI_FLAG_GET, EVT_PH_MX_HINT_KEY)
  return ok and type(v) == "number" and v ~= 0
end

EVT_PH_Wrap("UpdateButtonGuideParam", function(orig)
  return function(...)
    if EVT_PH_IN_GUIDE and EVT_PH_GUIDE and not EVT_PH_GUIDE_ADDED then
      EVT_PH_GUIDE_ADDED = true
      -- 2026-09-25 (user): no "Desplazarte" entry (the plate shows Q / E by its page dots); only the L3 hint
      if SetPersonalPlateType == nil and EVT_PH_MxHint() then
        pcall(AddButtonGuideInfo, EVT_PH_MX_TEXT, EVT_PH_MX_KEYS, 18, 0, 0, 0)
      end
    end
    return orig(...)
  end
end)

-- parent menus only: rebuild the guide when the plate's flag changes (polled once per frame)
if SetPersonalPlateType == nil and SetupDefaultFormationButtonGuide ~= nil then
  for _, fname in ipairs({"PostStep", "Step"}) do
    EVT_PH_Wrap(fname, function(orig)
      return function(...)
        local r = orig(...)
        local on = EVT_PH_MxHint()
        if on ~= (EVT_PH_MX_HINT_LAST == true) then
          EVT_PH_MX_HINT_LAST = on
          pcall(SetupDefaultFormationButtonGuide, EVT_PH_GUIDE_ARG)
        end
        return r
      end
    end)
  end
end

EVT_PH_Wrap("SetupDefaultFormationButtonGuide", function(orig)
  return function(...)
    EVT_PH_GUIDE_ARG = ...
    EVT_PH_IN_GUIDE = true
    EVT_PH_GUIDE_ADDED = false
    local ok, r = pcall(orig, ...)
    EVT_PH_IN_GUIDE = false
    if not ok then
      error(r, 0)
    end
    return r
  end
end)
-- ===== EVT plate_hiper common END =====
