-- VR-Framework > save adjust (docs/framework/save-adjust.md). Opciones (setting_top_menu) gets a small row «Ajustar save»
-- below «Licencias» while some enabled mod declares a save adjust action (content\save_adjust\*.toml, [[VRFW.SaveAdjust]];
-- CMND_VRFW_SAVE_TOOLS_*). Aceptar on it:
--
--   1. one confirmation (the game's yes / no window): the label of every available action, then «this changes your
--      current save: saved and backed up first, then the title loads it»;
--   2. Sí: CMND_VRFW_SAVE_TOOLS_REQUEST("") = every available action (refused on the locked retail save, a reserved slot,
--      an empty slot, an overlay session: a message, nothing changed), the game's auto-save (wait for its job), then
--      CMND_VRFW_SLOT_RELOAD(the active slot): the save engine's load hooks run the actions in order on the slot's FILE
--      before the game reads it; the framework writes the tree back once (the slot service's backup first);
--   3. the summary: changed = one result line per action that changed something + «the game goes back to the title»
--      and the retail BackToTitle (the title loads the fixed save); nothing changed / failed = CMND_VRFW_SLOT_ABORT (the
--      reload undone: the game in memory stays as it was) and a message.
--
-- Hooks on the framework's host of this script (000_host.lua; the locals t / t2 / flag4 through VRFW_Host, EVT_DEBUG):
-- `@edit` = the entry t2[40]; after OnInit = 40 placed after «Licencias» (t2[3]) on the PC list (flag4) when there is
-- an action; around OnDecideFocus = the session (OnDecideFocus is the retail coroutine of the list's Aceptar). The row's
-- slot is data (content\menus\save_tools_row.toml: the small list's third item). Only the game's general window is
-- opened: it is modal and centred, and the list keeps its focus when it closes. Never touches the menu's input (no
-- CMND_CHANGE_MENU_INPUT_CTRL / MENU_ACTIVE). No engine call at load time. Log: «VRFW save_adjust …» lines (CMND_EVT_LOG).

VRFW_SaveTools = VRFW_SaveTools or {}
local S = VRFW_SaveTools

S.ROW_TYPE = 40                       -- t2[40]: an index no other entry uses (retail 0-4, mods 5-8)
S.LICENSES_TYPE = 3                   -- t2[3] «Licencias»
S.SMALL_LIST = 530619243              -- mainmenu90_12_list_item_small
S.LINE_PREFIX = "· "                  -- before each action label in the confirmation
S.SAVE_WAIT_FRAMES = 600              -- the auto-save's job: 10 s at most
S.C = {
  COUNT = 4046583974,                 -- CMND_VRFW_SAVE_TOOLS_COUNT () -> n
  GET = 542677548,                    -- CMND_VRFW_SAVE_TOOLS_GET (i) -> key, labelId, descriptionId, available, mod, resultId
  REQUEST = 4164686576,               -- CMND_VRFW_SAVE_TOOLS_REQUEST (key, "" = every available action) -> ok, why
  RESULT = 3027832782,                -- CMND_VRFW_SAVE_TOOLS_RESULT () -> state, count, written, resultId, text, loadRulesWrote, items
  RESULT_ITEM = 2707736126,           -- CMND_VRFW_SAVE_TOOLS_RESULT_ITEM (i) -> key, labelId, count, resultId
  CANCEL = 4043639727,                -- CMND_VRFW_SAVE_TOOLS_CANCEL ()
  SLOT_ACTIVE = 4245285902,           -- CMND_VRFW_SLOT_ACTIVE () -> slot
  SLOT_RELOAD = 347070041,            -- CMND_VRFW_SLOT_RELOAD (slot) -> ok
  SLOT_ABORT = 2340980027,            -- CMND_VRFW_SLOT_ABORT ()
  LOG = 3661580131,                   -- CMND_EVT_LOG
  TEXT_GET = 4074371074,              -- CMND_TEXT_GET (menu_text id) -> string
  AUTO_SAVE = 3673719958,             -- CMND_SYSTEM_AUTO_SAVE
  SAVE_WORKING = 1979970074,          -- a save / load job is running
  MSG_OPEN = 2289627655,              -- general window (text, kind, 0, 0, 0, 0, false)
  MSG_BUTTONS = 2351835063,           -- (2, 0) = yes / no
  MSG_ANSWER = 1523741473,            -- -1 while open, then the button (0 = Sí)
  MSG_DONE = 682363669,               -- true = no general window up
  MSG_BUSY = 898725220,               -- a general window is busy
  SE = 1917805374,
}
S.SE_DECIDE = 3848881948              -- sy0000
S.SE_ERROR = 2086672038               -- sy0003
-- menu_text rows of the framework (text\rows\save_tools.toml): id = crc32(row id); English fallback below
S.T = {
  ROW = 3361226603,                   -- vrfw_save_tools_row «Ajustar save»
  ROW_HELP = 1921294418,              -- vrfw_save_tools_row_help
  CONFIRM_ALL = 2566813849,           -- vrfw_save_tools_confirm_all (the line above the action labels)
  CONFIRM = 3734088709,               -- vrfw_save_tools_confirm (%s = the action labels)
  DONE = 3674225646,                  -- vrfw_save_tools_done (%d)
  TO_TITLE = 562068050,               -- vrfw_save_tools_to_title
  NOTHING = 1936425366,               -- vrfw_save_tools_nothing
  BY_LOAD_RULES = 2962265954,         -- vrfw_save_tools_by_load_rules
  FAILED = 42260550,                  -- vrfw_save_tools_failed (%s)
  NONE = 3032341386,                  -- vrfw_save_tools_none
  UNAVAILABLE = 2660106037,           -- vrfw_save_tools_unavailable
  LOCKED = 1994240928,                -- vrfw_save_tools_locked
  RESERVED = 1277745355,              -- vrfw_save_tools_reserved
  BUSY = 79131335,                    -- vrfw_save_tools_busy
}
S.FALLBACK = {
  [S.T.CONFIRM_ALL] = "This will be applied to your current save:",
  [S.T.CONFIRM] = "%s\n\nA backup is made first, then you return to the title screen.\nApply?",
  [S.T.DONE] = "Done: %d change(s).",
  [S.T.TO_TITLE] = "The game goes back to the title screen to load the adjusted save.",
  [S.T.NOTHING] = "There was nothing to change: the save stays as it was.",
  [S.T.BY_LOAD_RULES] = "Your mods' load rules had already adjusted this save when it was loaded again.",
  [S.T.FAILED] = "The save could not be adjusted (%s). The save stays as it was.",
  [S.T.NONE] = "None of your mods has adjustments for this save.",
  [S.T.UNAVAILABLE] = "This adjustment has nothing to do with your current mods.",
  [S.T.LOCKED] = "The original save is protected: duplicate it into another slot and adjust the copy.",
  [S.T.RESERVED] = "This save belongs to a mod's mode and cannot be adjusted here.",
  [S.T.BUSY] = "The save cannot be adjusted right now. Try again in a few seconds.",
}
-- CMND_VRFW_SAVE_TOOLS_REQUEST's refusals -> the message
S.REFUSAL_TEXT = {locked = S.T.LOCKED, reserved = S.T.RESERVED, unavailable = S.T.UNAVAILABLE}

function S.Log(...)
  pcall(funcLuaCommand, S.C.LOG, "VRFW save_adjust", ...)
end

function S.Call(cmd, ...)
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

function S.Text(id)
  local ok, s = pcall(funcLuaCommand, S.C.TEXT_GET, id)
  if ok and type(s) == "string" and s ~= "" then
    return s
  end
  return S.FALLBACK[id] or ""
end

-- the actions of the enabled mods: { {key, label, description, available, mod, result} }
function S.Actions()
  local n = S.Call(S.C.COUNT)
  local out = {}
  for i = 1, (type(n) == "number" and n or 0) do
    local key, label, description, available, mod, result = S.Call(S.C.GET, i)
    if type(key) == "string" and key ~= "" then
      out[#out + 1] = {key = key, label = label, description = description, available = available == true, mod = mod, result = result}
    end
  end
  return out
end

-- ---- windows (inside OnDecideFocus' coroutine) -----------------------------------------------------------------------

-- wait until the general window that was just asked for is gone (seen first; never forever)
function S.WaitWindowGone()
  local k, seen, gone = 0, false, 0
  while k < 36000 do
    k = k + 1
    coroutine.yield()
    local done = S.Call(S.C.MSG_DONE)
    if done == false then
      seen, gone = true, 0
    else
      gone = gone + 1
      if (seen and gone > 2) or (not seen and gone > 120) then
        return seen
      end
    end
  end
  return seen
end

-- a message with the game's plain window (one button)
function S.Message(text)
  S.Log("message", text)
  funcLuaCommand(S.C.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
  S.WaitWindowGone()
end

-- the game's yes / no window: true = Sí
function S.Ask(text)
  funcLuaCommand(S.C.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
  funcLuaCommand(S.C.MSG_BUTTONS, 2, 0)
  local answer, k = -1, 0
  while answer < 0 and k < 36000 do
    k = k + 1
    coroutine.yield()
    local a = S.Call(S.C.MSG_ANSWER)
    answer = type(a) == "number" and a or -1
    if answer < 0 and k > 120 and S.Call(S.C.MSG_DONE) == true then
      break                           -- the window went away without an answer
    end
  end
  S.WaitWindowGone()
  S.Log("question answered", tostring(answer))
  return answer == 0
end

-- ---- the session --------------------------------------------------------------------------------------------------

-- one result line per action that changed something (its own result text, %d = its count)
function S.SummaryLines(items)
  local lines = {}
  for i = 1, (type(items) == "number" and items or 0) do
    local key, _, count, result = S.Call(S.C.RESULT_ITEM, i)
    if type(key) == "string" and type(count) == "number" and count > 0 then
      local line = S.Text(type(result) == "number" and result ~= 0 and result or S.T.DONE)
      if line == "" then line = S.Text(S.T.DONE) end
      local ok, text = pcall(string.format, line, count)
      lines[#lines + 1] = ok and text or line
    end
  end
  return lines
end

-- every available action, after one confirmation
function S.Run(actions)
  local labels = {}
  for _, a in ipairs(actions) do
    labels[#labels + 1] = S.LINE_PREFIX .. S.Text(a.label)
  end
  local question = S.Text(S.T.CONFIRM_ALL) .. "\n" .. table.concat(labels, "\n")
  if not S.Ask(string.format(S.Text(S.T.CONFIRM), question)) then
    return
  end
  local ok, why = S.Call(S.C.REQUEST, "")
  if ok ~= true then
    S.Log("request refused", tostring(why))
    funcLuaCommand(S.C.SE, S.SE_ERROR)
    S.Message(S.Text(S.REFUSAL_TEXT[why] or S.T.BUSY))
    return
  end
  local slot = S.Call(S.C.SLOT_ACTIVE)
  -- the game in memory to the file first: the actions work on the file, and the title loads the file
  S.Call(S.C.AUTO_SAVE)
  local k = 0
  repeat
    k = k + 1
    coroutine.yield()
  until S.Call(S.C.SAVE_WORKING) ~= true or k >= S.SAVE_WAIT_FRAMES
  if S.Call(S.C.SAVE_WORKING) == true then
    S.Log("the auto-save is still running after", k, "frames: not adjusted")
    S.Call(S.C.CANCEL)
    S.Message(S.Text(S.T.BUSY))
    return
  end
  S.Log("saved in", k, "frames; reloading slot", tostring(slot))
  -- the save engine's switch to the same slot: its load hooks run the actions on the file (the safe point)
  if type(slot) ~= "number" or S.Call(S.C.SLOT_RELOAD, slot) ~= true then
    S.Log("reload of slot", tostring(slot), "refused: not adjusted")
    S.Call(S.C.CANCEL)
    S.Message(S.Text(S.T.BUSY))
    return
  end
  local state, count, written, _, text, by_load_rules, items = S.Call(S.C.RESULT)
  S.Log("result", tostring(state), "count", tostring(count), "written", tostring(written), "load rules wrote",
    tostring(by_load_rules), "actions", tostring(items), tostring(text))
  -- the slot's file changed (by the actions, or first by a mod's own on-load pass of the same reload): the title must
  -- load it; the game in memory is the old save
  if state == "done" and (written == true or by_load_rules == true) then
    funcLuaCommand(S.C.SE, S.SE_DECIDE)
    local lines = S.SummaryLines(items)
    if by_load_rules == true then
      lines[#lines + 1] = S.Text(S.T.BY_LOAD_RULES)
    end
    if #lines == 0 then
      local okf, done = pcall(string.format, S.Text(S.T.DONE), type(count) == "number" and count or 0)
      lines[1] = okf and done or S.Text(S.T.DONE)
    end
    lines[#lines + 1] = S.Text(S.T.TO_TITLE)
    S.Message(table.concat(lines, "\n"))
    S.Log("back to the title: the title loads the adjusted slot", tostring(slot))
    BackToTitle()
    return
  end
  -- nothing written: the reload is undone, the game in memory is the save as it was
  S.Call(S.C.SLOT_ABORT)
  S.Call(S.C.CANCEL)
  if state == "done" then
    S.Message(S.Text(S.T.NOTHING))
  else
    funcLuaCommand(S.C.SE, S.SE_ERROR)
    S.Message(string.format(S.Text(S.T.FAILED), tostring(text ~= nil and text ~= "" and text or state)))
  end
end

function S.Session()
  local available = {}
  for _, a in ipairs(S.Actions()) do
    if a.available then
      available[#available + 1] = a
    end
  end
  if #available == 0 then
    S.Message(S.Text(S.T.NONE))
    return
  end
  S.Run(available)
end

-- ---- hooks on the host of this script -------------------------------------------------------------------------------

if VRFW_Host ~= nil then
  VRFW_Host.on("setting_top_menu", "@edit", {
    id = "vr_framework.save_adjust.row",
    fn = function(L)
      local t2 = L.t2
      if type(t2) ~= "table" then
        S.Log("no locals of setting_top_menu (EVT_DEBUG off?): no «Ajustar save» row")
        return
      end
      t2[S.ROW_TYPE] = {
        buttonType = 1,
        buttonLayerName = S.SMALL_LIST,
        buttonTextName = S.T.ROW,
        explanationTextName = S.T.ROW_HELP,
        listItemOnTextureName = 0,
        listItemOffTextureName = 0,
        menuObjectName = 0,
      }
    end,
  })
  VRFW_Host.on("setting_top_menu", "OnInit", {
    id = "vr_framework.save_adjust.order",
    phase = "after",
    fn = function()
      local L = VRFW_Host.hosts.setting_top_menu and VRFW_Host.hosts.setting_top_menu.L
      local t, t2 = L and L.t, L and L.t2
      if type(t) ~= "table" or type(t2) ~= "table" or t2[S.ROW_TYPE] == nil or L.flag4 ~= true then
        return                         -- no locals, or the console list (no slot for a third small row)
      end
      local at = nil
      for i, v in ipairs(t) do
        if v == S.ROW_TYPE then return end
        if v == S.LICENSES_TYPE then at = i end
      end
      if at == nil then
        return                         -- a list without «Licencias» (a mod's own Options rows, e.g. a field pause menu)
      end
      local n = S.Call(S.C.COUNT)
      if type(n) ~= "number" or n < 1 then
        return
      end
      table.insert(t, at + 1, S.ROW_TYPE)
      S.Log("«Ajustar save» row added", n, "action(s)")
    end,
  })
  VRFW_Host.on("setting_top_menu", "OnDecideFocus", {
    id = "vr_framework.save_adjust.decide",
    fn = function(nxt, a1, a2, ...)
      if a1 == S.SMALL_LIST and type(GetLitItemType) == "function" and GetLitItemType(a1, a2) == S.ROW_TYPE then
        return S.Session()
      end
      return nxt(a1, a2, ...)
    end,
  })
end
