-- ===== EVT ui_clean bank_sort_guide BEGIN =====
-- research/scripts/ui_clean_build.py, docs/game/ui-redesign.md section 11
do
local EVT_UI_Block = function()
-- EVT ui_clean graft: common part (research/scripts/ui_clean_build.py, docs/game/ui-redesign.md section 11).
-- Appended as one child function to the retail bytecode of a menu and run at the end of its main chunk.
-- Build-time placeholders: limpio (string), the owning mod's ui_flags.toml flags, merged (Lua table body), bank (menu tag for the log).
local EVT_UI_MARK = "EVT_UI_CLEAN_GRAFT"

-- Kill switch. EVT_UI_PRESET = "off" makes every ui_clean wrapper pass everything through unchanged.
-- Each feature can also be switched off on its own in EVT_UI_FLAGS (set by the build, see --preset / --no-*).
if EVT_UI_PRESET == nil then
  EVT_UI_PRESET = "limpio"
end
EVT_UI_FLAGS = EVT_UI_FLAGS or {}
for k, v in pairs({ bank_sort_guide = true, buff_icons = true, buff_panel = false, corner_buttons = true, duel_telop = true, enemy_meters = true, esc_guide = true, exec_offset = true, header_short = true, nickname_pill = true, team_param_guide = true, zone_exec = false, zone_hud = true }) do
  if EVT_UI_FLAGS[k] == nil then
    EVT_UI_FLAGS[k] = v
  end
end

@UI_WRAP@

-- EVT ui_clean, menu chara_bank_menu (Banco): the bottom guide entry of the sort mode ("Por adquisición",
-- "Por rareza", ... with the swap / CMD_FUNC2 glyph 2387151820) is dropped from the guide tables, so the other entries
-- close up (the guide row is laid out by the engine from the tables). The sort itself (CMD_FUNC2 key binding of the
-- menu setting) and the sort label at the top right of the list are not touched. Flag: bank_sort_guide.
-- Guide calls (UpdateButtonGuide): funcLuaMenuCommand(2209673388, menu, mainmenu01_06_base_button_guide,
-- texts, icons, offsets, t18, t19) then funcLuaMenuCommand(452337289, menu, same layer, keys).
local CMND_GUIDE_SET = 2209673388
local CMND_GUIDE_KEYS = 452337289
local GUIDE_LAYER = 1138543975
local ICON_SORT = 2387151820
local KEY_SORT = 3170216173           -- CMD_FUNC2
local ui_bank_dropped = false

local function Without(t, i)
  if type(t) ~= "table" or #t < i then
    return t
  end
  local o = {}
  for k = 1, #t do
    if k ~= i then
      o[#o + 1] = t[k]
    end
  end
  return o
end

local function UiMenuFilter(orig, id, ...)
  if not UiOn("bank_sort_guide") then
    return nil
  end
  if id == CMND_GUIDE_SET then
    local a = Pack(...)
    if a[2] ~= GUIDE_LAYER or type(a[4]) ~= "table" then
      return nil
    end
    local idx = nil
    for k = 1, #a[4] do
      if a[4][k] == ICON_SORT then
        idx = k
        break
      end
    end
    ui_bank_dropped = idx ~= nil
    if idx == nil then
      return nil
    end
    for k = 3, 7 do
      a[k] = Without(a[k], idx)
    end
    UiLog("bank_sort_guide", idx)
    return Pack(orig(id, table.unpack(a, 1, a.n)))
  elseif id == CMND_GUIDE_KEYS and ui_bank_dropped then
    local a = Pack(...)
    if a[2] ~= GUIDE_LAYER or type(a[3]) ~= "table" then
      return nil
    end
    ui_bank_dropped = false
    local keys = {}
    for k = 1, #a[3] do
      if a[3][k] ~= KEY_SORT then
        keys[#keys + 1] = a[3][k]
      end
    end
    a[3] = keys
    return Pack(orig(id, table.unpack(a, 1, a.n)))
  end
  return nil
end

UiHookMenuCommand(UiMenuFilter)

end
EVT_UI_Block()
end
-- ===== EVT ui_clean bank_sort_guide END =====
