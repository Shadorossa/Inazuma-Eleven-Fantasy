-- Combo partners of the mod Utilities (feature combo_partners; docs/game/mechanics/combo-partners.md §6.3) on
-- Character Reforged's «Fantasy» skill table (evt_skill_slot_menu; its extension point: docs/framework/
-- skill-table-host.md). SOURCE of the hook file util_cp_skill_table.lua (gen_hooks.py fills the @crc placeholders and
-- the shared picker util_cp_core.src.lua, the same one the retail board's hook file carries; edit the sources, run the
-- script).
-- The screen is Character Reforged's; Utilities declares an X ACTION on it as data (content\menus\102_team\
-- skill_table_partners.toml: [[entry]] host = "character_reforged.skill_table.x_action", id = "partners",
-- action = { lua = "Utilities.SkillTablePartners" }) and the screen's host calls Utilities.SkillTablePartners(phase,
-- ctx) on the focused row:
--   "available" -> the row's move needs partners (CMND_UTIL_COMBO_INFO: 2+ performers, the retail board's test); false
--                  while Inazuma Fantasy's own picker is in this screen (global EVT_CPK: its X stays alone);
--   "guide"     -> the guide entry «X Compañeros» (the entry's text utilities.cp_btn);
--   "press"     -> the picker (the screen's action coroutine): Utilities' list window (layers util_pc_list /
--                  util_pc_row added to this screen by the same menus file; the screen's own list cover hides the
--                  bottom buttons and the card under it), rows «Aleatorio (en el partido)» then the screen's squad
--                  (its team list t4 / formation slots t5 / formation n6) in field order, then the confirm popup and
--                  CMND_UTIL_COMBO_SET.
-- The screen's input is not switched off: while a page is up its focus changes are dropped (OnChangeFocus wrapped)
-- and the focus is put back on the move row, so the rows under the list stay as they were.
-- Without Character Reforged's host nothing calls the function (no X, no guide entry). Definitions only at chunk load.
do
@CORE@

  UTIL_CP.SKILL_TABLE_PRIO = {BG = 449, LIST = 450, ITEM = 451} -- the screen's own list popups (evt_ss_list) use these
  UTIL_CP.FOCUS_INDEX = 2603265800 -- (layer) -> focused instance
  UTIL_CP.FOCUS_SET = 1778826357 -- (layer, instance, true): the focus on that instance

  function UTIL_CP.SkillTableHost()
    local host = type(CharacterReforged) == "table" and CharacterReforged.SkillTable or nil
    if type(host) ~= "table" or type(host.L) ~= "table" then
      return nil
    end
    return host
  end

  -- the screen's squad: its team list t4[1..n15] (the registered squad), formation slots t5[i], formation n6
  function UTIL_CP.SkillTableMembers(locals)
    local team, count = locals.t4, locals.n15
    if type(team) ~= "table" or type(count) ~= "number" then
      return nil
    end
    local slots = locals.t5
    local out = {formation = locals.n6}
    for i = 1, count do
      local h = team[i]
      if type(h) == "number" and h ~= 0 then
        out[#out + 1] = {hdl = h, slot = type(slots) == "table" and slots[i] or nil, index = i}
      end
    end
    return out
  end

  -- the SCREEN table of util_cp_core for this screen (host = CharacterReforged.SkillTable, ctx of the press)
  function UTIL_CP.SkillTable(host, ctx)
    local locals = host.L
    local state = {row = ctx.row}
    local function cover(show)
      local screen_helpers = locals.PL
      if type(screen_helpers) == "table" and type(screen_helpers.ListCover) == "function" then
        pcall(screen_helpers.ListCover, show)
      end
    end
    local function refocus()
      local rows = locals.L_ROW
      if rows == nil or state.row == nil then
        return
      end
      local ok, at = pcall(funcLuaMenuCommand, UTIL_CP.FOCUS_INDEX, rows)
      if not ok or at ~= state.row then
        pcall(funcLuaMenuCommand, UTIL_CP.FOCUS_SET, rows, state.row, true)
      end
    end
    return {
      player = UTIL_CP.U32(ctx.chara),
      backdrop = false, -- the screen's list cover draws the blue backdrop
      Members = function()
        return UTIL_CP.SkillTableMembers(locals)
      end,
      Begin = function()
        cover(true)
      end,
      Frame = refocus,
      Finish = function()
        cover(false)
        refocus()
        if type(UpdateEquipItemInfo) == "function" then
          pcall(UpdateEquipItemInfo) -- the row's own guide and panel back
        end
      end,
      GuideMenu = function()
        return locals.n12
      end,
      Message = host.Message,
    }
  end

  Utilities = type(Utilities) == "table" and Utilities or {}

  -- the x_action entry of Character Reforged's skill table host (see the top of this file)
  function Utilities.SkillTablePartners(phase, ctx)
    local host = UTIL_CP.SkillTableHost()
    if host == nil or type(ctx) ~= "table" then
      return nil
    end
    if phase == "available" then
      if type(EVT_CPK) == "table" then
        return false -- Inazuma Fantasy's picker owns X on this screen
      end
      return type(ctx.row) == "number" and (ctx.move or 0) ~= 0 and UTIL_CP.ComboInfo(ctx.move) ~= nil
    elseif phase == "guide" then
      return true
    elseif phase ~= "press" then
      return nil
    end
    local skill = UTIL_CP.U32(ctx.move)
    local info = UTIL_CP.ComboInfo(skill)
    if info == nil then
      host.Sound("refused")
      return
    end
    UTIL_CP.Open(UTIL_CP.SkillTable(host, ctx), skill, info)
  end

  -- ---- the picker's layers and the focus while it runs (globals wrapped once per VM) -----------------------------
  function UTIL_CP.WrapSkillTableGlobal(name, make)
    UTIL_CP.skill_table_wrapped = UTIL_CP.skill_table_wrapped or {}
    if UTIL_CP.skill_table_wrapped[name] then
      return
    end
    local current = _ENV[name]
    if current == nil then
      return
    end
    _ENV[name] = make(current)
    UTIL_CP.skill_table_wrapped[name] = true
  end

  UTIL_CP.WrapSkillTableGlobal("OnSetupLayer", function(previous)
    return function(a1, a2, ...)
      if UTIL_CP.Ours(a1) then
        UTIL_CP.SetupLayer(a1, a2, UTIL_CP.SKILL_TABLE_PRIO)
        return
      end
      return previous(a1, a2, ...)
    end
  end)

  UTIL_CP.WrapSkillTableGlobal("OnOpenLayer", function(previous)
    return function(a1, a2, ...)
      if UTIL_CP.Ours(a1) then
        if not UTIL_CP.picking then
          pcall(funcLuaMenuCommand, 711242136, a1, a2, false)
        end
        return
      end
      return previous(a1, a2, ...)
    end
  end)

  -- a page is up: the D-pad / stick move the screen's focus too (its input stays on); the move is dropped here and
  -- the page's Frame puts the focus back on the move row
  UTIL_CP.WrapSkillTableGlobal("OnChangeFocus", function(previous)
    return function(a1, a2, ...)
      if UTIL_CP.picking then
        return
      end
      return previous(a1, a2, ...)
    end
  end)
end
