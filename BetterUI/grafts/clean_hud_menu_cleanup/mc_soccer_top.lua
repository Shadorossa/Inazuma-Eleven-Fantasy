-- ===== EVT ui_clean menu_cleanup BEGIN =====
-- research/scripts/ui_clean_build.py, docs/game/ui-redesign.md section 11
do
local EVT_UI_Block = function()
-- EVT ui_clean graft: common part (research/scripts/ui_clean_build.py, docs/game/ui-redesign.md section 11).
-- Appended as one child function to the retail bytecode of a menu and run at the end of its main chunk.
-- Build-time placeholders: limpio (string), the owning mod's ui_flags.toml flags, merged (Lua table body), menu_cleanup_soccer_top (menu tag for the log).
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

-- EVT ui_clean, Clean HUD «menu cleanup» (graft clean_hud_menu_cleanup; docs/game/ui/ui-redesign.md «Mode top menus cleanup»). Appended to
-- the mode top menus that carry the retail corner buttons (soccer_top_menu = Modo Competición / «Modos de juego»,
-- chronicle_mode_top_menu = Modo Crónica, bb_stadium_top_menu = Estadio BB); everything below works from the declared
-- tables, so the same block serves every menu.
--   * corner buttons «V Guía de controles» (mainmenu90_24_02_play_guide_button) and «Alt Tutorial»
--     (mainmenu90_24_tutorial_button), flag corner_buttons: still created (the retail code addresses them) but
--     invisible, without control focus, mouse zone or cursor; their retail functions (list -> corner, corner -> list,
--     corner up / down, V, Alt) and Accept on them do nothing. The tutorial's «come back on the tutorial button» temp
--     value is cleared before the retail OnInit reads it, so the menu always opens on its lists. A retail helper that
--     shows a list of layers again (SwitchLayerVisible, bb_stadium_top_menu after its stadium window) leaves them
--     hidden. The tutorial still runs from the retail first-play notice. Where graft clean_hud_controls_guide declares
--     the footer «Guía de controles», that graft (outside this block) takes the V key before it gets here.
-- The icon boxes of Modo Crónica are graft clean_hud_chr_boxes; Inazuma Fantasy's comp_menu boxes («Modos de juego»)
-- run before this block and are not touched.

-- declared data ----------------------------------------------------------------------------------------------------
local UI_MC_CORNERS = {
  [4096284290] = "controls guide",
  [3687874606] = "tutorial",
}
-- retail OnFunction ids of the corner buttons (soccer_top_menu / chronicle_mode_top_menu / bb_stadium_top_menu)
local UI_MC_CORNER_FN = {
  [1055436260] = true, -- list -> corner buttons
  [3860297742] = true, -- corner buttons -> list
  [1169567619] = true, -- corner buttons -> list (bb_stadium_top_menu)
  [3517640427] = true, -- corner up / down
  [1643904886] = true, -- V: the controls guide window
  [2666587639] = true, -- Alt: the tutorial
}
local UI_MC_TUTORIAL_RETURN = 207055258   -- temp value: the tutorial asks to come back on the tutorial button
local UI_MC_CURSOR = 3313461902

-- engine commands ----------------------------------------------------------------------------------------------------
local CMND_SET_LAYER_VISIBLE = 711242136
local CMND_SET_ENABLE_CTRL_FOCUS = 3518307824
local CMND_SET_HIT_ZONE = 855005857          -- (layer, idx, bool): the instance's mouse zone
local CMND_ATTACH_TRACE = 1774843228         -- (layer, idx, locator, bool): the cursor follows the instance
local CMND_SET_TEMP_VALUE = 2565779025

local function UiMcCmd(...)
  if type(funcLuaMenuCommand) ~= "function" then
    return nil
  end
  local ok, r = pcall(funcLuaMenuCommand, ...)
  if ok then
    return r
  end
  return nil
end

-- corner buttons ------------------------------------------------------------------------------------------------------
local function UiMcIsCorner(a1)
  return UI_MC_CORNERS[a1] ~= nil and UiOn("corner_buttons")
end

local ui_mc_corner_logged = {}
local function UiMcHideCorner(a1, a2)
  local i = a2 or 0
  UiMcCmd(CMND_SET_LAYER_VISIBLE, a1, i, false)
  UiMcCmd(CMND_SET_ENABLE_CTRL_FOCUS, a1, false)
  UiMcCmd(CMND_SET_HIT_ZONE, a1, i, false)
  UiMcCmd(CMND_ATTACH_TRACE, a1, i, UI_MC_CURSOR, false)
  if not ui_mc_corner_logged[a1] then
    ui_mc_corner_logged[a1] = true
    UiLog("menu_cleanup corner hidden", UI_MC_CORNERS[a1])
  end
end

-- callbacks -----------------------------------------------------------------------------------------------------------
do
  local init = rawget(_ENV, "OnInit")
  if type(init) == "function" then
    rawset(_ENV, "OnInit", function(...)
      if UiOn("corner_buttons") and type(funcLuaCommand) == "function" then
        pcall(funcLuaCommand, CMND_SET_TEMP_VALUE, UI_MC_TUTORIAL_RETURN, 0)
      end
      return init(...)
    end)
  end
  local setup = rawget(_ENV, "OnSetupLayer")
  if type(setup) == "function" then
    rawset(_ENV, "OnSetupLayer", function(a1, a2, ...)
      local r = Pack(setup(a1, a2, ...))
      if UiMcIsCorner(a1) then
        UiMcHideCorner(a1, a2)
      end
      return table.unpack(r, 1, r.n)
    end)
  end
  local open = rawget(_ENV, "OnOpenLayer")
  if type(open) == "function" then
    rawset(_ENV, "OnOpenLayer", function(a1, a2, ...)
      local r = Pack(open(a1, a2, ...))
      if UiMcIsCorner(a1) then
        UiMcHideCorner(a1, a2)
      end
      return table.unpack(r, 1, r.n)
    end)
  end
  local decide = rawget(_ENV, "OnDecideFocus")
  if type(decide) == "function" then
    rawset(_ENV, "OnDecideFocus", function(a1, ...)
      if UiMcIsCorner(a1) then
        return
      end
      return decide(a1, ...)
    end)
  end
  local enter = rawget(_ENV, "OnEnter")
  if type(enter) == "function" then
    rawset(_ENV, "OnEnter", function(a1, ...)
      if UiMcIsCorner(a1) then
        return
      end
      return enter(a1, ...)
    end)
  end
  local switch = rawget(_ENV, "SwitchLayerVisible")
  if type(switch) == "function" then
    rawset(_ENV, "SwitchLayerVisible", function(a1, a2, ...)
      local r = Pack(switch(a1, a2, ...))
      if a2 == true and type(a1) == "table" and UiOn("corner_buttons") then
        for _, layer in ipairs(a1) do
          if UI_MC_CORNERS[layer] ~= nil then
            UiMcCmd(CMND_SET_LAYER_VISIBLE, layer, 0, false)
          end
        end
      end
      return table.unpack(r, 1, r.n)
    end)
  end
  local fn = rawget(_ENV, "OnFunction")
  if type(fn) == "function" then
    rawset(_ENV, "OnFunction", function(a1, ...)
      if UI_MC_CORNER_FN[a1] and UiOn("corner_buttons") then
        UiLog("menu_cleanup corner function ignored", a1)
        return
      end
      return fn(a1, ...)
    end)
  end
end

end
EVT_UI_Block()
end
-- ===== EVT ui_clean menu_cleanup END =====
