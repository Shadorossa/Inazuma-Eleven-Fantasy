-- Utilities technique preview, the «Supertécnicas» list side (docs/game/ui/technique-preview.md). The special move card
-- of the list (team02_02_skill_detail_info) gets the prompt «<RS> Previsualizar» at its bottom right (layer
-- util_tp_hint, content\menus\tech_preview.toml: a copy of the card's own retail page guide). The button (the action
-- BetterQoL.TechPreview.Play, command CMD_UTIL_TECH_PREVIEW, default RS / P, rebindable in «Configuración de
-- controles») plays the move's cut-in FULL SCREEN with a player of the active squad at the move's position, through the
-- VR-Framework's live player (the one the Mods screen's technique viewer and Inazuma Fantasy's miximax scene use):
--   fade out, BGM away -> the performer's model held by the one-model menu chara_model_only_view_menu (an event over
--   the menus only binds actors to models a menu holds) -> CMND_EVT_ANIM_PREVIEW writes the move's event with that
--   performer over a preview slot -> every open menu of the dock hidden + suspended, the header bars hidden in their
--   own menus -> CMND_RESERVE_EVENT + CMND_VRFW_ANIM_LIVE_RUN (SceneEvent pushed over the menu scene) -> fade in ->
--   played to its end (B or the game's own hold-to-skip end it) -> black -> everything given back in reverse ->
--   BGM, fade in. Nothing is closed or reopened: the list keeps its tab, page, focus and card.
-- What to play (event, performer, body) is scripts\tech_preview.lua (CMND_BETTERQOL_TECH_PREVIEW); the tunables come from
-- config.toml [tech_preview] (CMND_BETTERQOL_TECH_PREVIEW_CFG). The menus' own input state is never touched (no
-- MENU_ACTIVE / CHANGE_MENU_INPUT_CTRL): while the cut-in plays this screen's callbacks do nothing (BetterQoL.TechPreview.busy).
-- One log line per state change (CMND_EVT_LOG «util_tech_preview …»). Globals only; no engine call at chunk load.
BetterQoL = BetterQoL or {}
BetterQoL.TechPreview = {
  CMD = @crc:CMND_BETTERQOL_TECH_PREVIEW@, CFG_CMD = @crc:CMND_BETTERQOL_TECH_PREVIEW_CFG@,
  PREVIEW = @crc:CMND_EVT_ANIM_PREVIEW@, RESERVE = @crc:CMND_RESERVE_EVENT@,
  LIVE_RUN = @crc:CMND_VRFW_ANIM_LIVE_RUN@, LIVE_TICK = @crc:CMND_VRFW_ANIM_LIVE_TICK@,
  LIVE_CTL = @crc:CMND_VRFW_ANIM_LIVE_CTL@, LIVE_WINDOW = @crc:CMND_VRFW_ANIM_LIVE_WINDOW@,
  LIVE_VIEW = @crc:CMND_VRFW_ANIM_LIVE_VIEW@,
  INPUT = @crc:CMND_CHECK_INPUT_CMD@, MENU_CTRL = @crc:MENU_CTRL@, KEY = @crc:CMD_UTIL_TECH_PREVIEW@,
  CANCEL = @crc:CMD_CANCEL@, FOCUS_ACTIVE = @crc:CMND_IS_CTRL_FOCUS_ACTIVE@,
  EXIST_MENU = @crc:CMND_IS_EXIST_MENU_OBJECT@, LAYER_NUM = @crc:CMND_GET_CREATE_LAYER_NUM@, IS_OPEN = @crc:CMND_IS_OPEN_LAYER@, OPEN = @crc:CMND_OPEN_LAYER@,
  LVIS = @crc:CMND_SET_LAYER_VISIBLE@, IS_LVIS = @crc:CMND_IS_LAYER_VISIBLE@, POS = @crc:CMND_SET_LAYER_LOCAL_POS@, SET_STR = @crc:CMND_SET_MENU_TEXT_STRING@, PLATE = @crc:CMND_UPDATE_TEXT_PLATE@,
  TEXT_GET = @crc:CMND_TEXT_GET@, LOG = @crc:CMND_EVT_LOG@, LIST_COUNT = 2389020234, ITEM_TO_SKILL = 901208644,
  SUSPEND = 369172623, RESUME = 66378409, HIDE = 1670867360, SHOW = 3257327861, CROSS = 830228314,
  OPEN_MENU = @crc:CMND_OPEN_MENU_OBJECT@, CLOSE_MENU = @crc:CMND_CLOSE_MENU_OBJECT@, MENU_LOADING = 667479479,
  BGM_STOP = @crc:CMND_BGM_STOP@, BGM_RESUME = @crc:CMND_BGM_RESUME@, FADE = 609722083, IS_FADE = @crc:CMND_BRIGHT_IS_FADE@, CRAFT = @crc:CMND_EXEC_CRAFT_OBJ_ID@,
  CHARA_INFO = 1131797651, CHARA_MODEL_ID = 347353059,
  HINT = @crc:util_tp_hint@, N_BTN = @crc:_text_btn01@, N_GUIDE = 378156699 --[[_text_guide01]],
  TXT_KEY = @crc:utilities_tech_preview_key@, TXT_WORD = @crc:utilities_tech_preview@,
  CARD = 2628045944 --[[team02_02_skill_detail_info]], ITEM = 1205526439 --[[team08_02_ability_list_item]],
  LIST = 571205469 --[[team05_03_ability_list]], TAB = 4044286600 --[[cmn06_20_list_tab_item]],
  READY_KEY = @crc:utilities_tp_model_ready@,
  skill = 0, plans = {}, shown = nil, opened = false, texts = false, busy = false, co = nil, cfg = nil,
}

-- an unsigned 32-bit id as 8 hex digits (string.format of a number above 2^31 is not safe in the game's Lua)
function BetterQoL.TechPreview.Hex(v)
  return VRFW_Id.hex(v):sub(3)
end

function BetterQoL.TechPreview.Log(...)
  local t = {}
  for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
  pcall(funcLuaCommand, BetterQoL.TechPreview.LOG, "util_tech_preview", table.concat(t, " "))
end

-- config.toml [tech_preview] through the script (nil until it answers)
function BetterQoL.TechPreview.Cfg()
  if BetterQoL.TechPreview.cfg == nil then
    local ok, c = pcall(funcLuaCommand, BetterQoL.TechPreview.CFG_CMD)
    if ok and type(c) == "table" then BetterQoL.TechPreview.cfg = c end
  end
  return BetterQoL.TechPreview.cfg
end

local function Has(m)
  local ok, r = pcall(funcLuaMenuCommand, BetterQoL.TechPreview.EXIST_MENU, m)
  return ok and r == true
end

-- the preview plays only over the menu-scene team dock (title route or main hub), never over the Chronicle / story
-- field menus: "" = here, else why not
function BetterQoL.TechPreview.Context()
  local c = BetterQoL.TechPreview.Cfg()
  if c == nil then return "no config answer (scripts busy or off)" end
  for _, m in ipairs(c.off_with or {}) do
    if Has(m) then return "off with menu " .. BetterQoL.TechPreview.Hex(m) .. " open" end
  end
  for _, m in ipairs(c.need_any or {}) do
    if Has(m) then return "" end
  end
  return "not over the menu-scene team dock"
end

-- the plan of move `skill` (cached per move; nil = the script did not answer this frame)
function BetterQoL.TechPreview.Plan(skill)
  local p = BetterQoL.TechPreview.plans[skill]
  if p ~= nil then return p end
  local ok, go, ev, hdl, name, body, cat, how = pcall(funcLuaCommand, BetterQoL.TechPreview.CMD, skill)
  if not ok or go == nil then return nil end
  if go ~= 1 then
    -- a list row may give the item id of the move: its skill id once more
    local okc, s2 = pcall(funcLuaCommand, BetterQoL.TechPreview.ITEM_TO_SKILL, skill)
    if okc and type(s2) == "number" and s2 ~= 0 and s2 ~= skill then
      local ok2, go2, ev2, hdl2, name2, body2, cat2, how2 = pcall(funcLuaCommand, BetterQoL.TechPreview.CMD, s2)
      if ok2 and go2 == 1 then
        ok, go, ev, hdl, name, body, cat, how = ok2, go2, ev2, hdl2, name2, body2, cat2, how2
      end
    end
  end
  p = {ok = go == 1, event = ev, hdl = hdl, name = name, body = body, category = cat, how = how}
  BetterQoL.TechPreview.plans[skill] = p
  return p
end

-- the prompt layer opened once, its texts set once (the glyph follows the binding: markup <CMD_UTIL_TECH_PREVIEW>)
function BetterQoL.TechPreview.HintReady()
  local T = BetterQoL.TechPreview
  local okn, n = pcall(funcLuaMenuCommand, T.LAYER_NUM, T.HINT)
  if not okn or type(n) ~= "number" or n <= 0 then return false end
  local oko, open = pcall(funcLuaMenuCommand, T.IS_OPEN, T.HINT, 0)
  if not (oko and open == true) then
    if not T.opened then
      T.opened = true
      T.open_wait = 0
      pcall(funcLuaMenuCommand, T.OPEN, T.HINT, 0)
      T.Log("prompt layer opened")
    end
    -- an engine that never answers «open» for it: on after 30 frames all the same
    T.open_wait = (T.open_wait or 0) + 1
    if T.open_wait < 30 then return false end
  end
  if not T.texts then
    T.texts = true
    local key = funcLuaCommand(T.TEXT_GET, T.TXT_KEY)
    local word = funcLuaCommand(T.TEXT_GET, T.TXT_WORD)
    if type(key) ~= "string" or key == "" then key = "<CMD_UTIL_TECH_PREVIEW>" end
    if type(word) ~= "string" then word = "" end
    pcall(funcLuaMenuCommand, T.SET_STR, T.HINT, T.N_BTN, key, 0)
    pcall(funcLuaMenuCommand, T.SET_STR, T.HINT, T.N_GUIDE, word, 0)
    pcall(funcLuaMenuCommand, T.PLATE, T.HINT, 0, T.N_GUIDE)
    -- the prompt's place: the config offset plus the stack of the card's guide pills (VRFW_Pager: above the «Y <next
    -- page>» pill while that one shows)
    local pager = (type(VRFW_Pager) == "table" and type(VRFW_Pager.PillRegister) == "function") and VRFW_Pager or nil
    function T.PlacePill(dx, dy)
      local c = T.Cfg()
      local x, y = (c and c.hint_x or 0) + (dx or 0), (c and c.hint_y or 0) + (dy or 0)
      pcall(funcLuaMenuCommand, T.POS, T.HINT, x, y, 0, 0)
    end
    if pager ~= nil then
      pager.PillRegister("tech_preview", 2, T.PlacePill)
      T.PlacePill(pager.PillOffset("tech_preview"))
    else
      T.PlacePill(0, 0)
    end
    T.Log("prompt ready", "offset", c and c.hint_x or 0, c and c.hint_y or 0)
  end
  return true
end

function BetterQoL.TechPreview.Show(on)
  if BetterQoL.TechPreview.shown == on then return end
  BetterQoL.TechPreview.shown = on
  pcall(funcLuaMenuCommand, BetterQoL.TechPreview.LVIS, BetterQoL.TechPreview.HINT, 0, on)
  if type(VRFW_Pager) == "table" and type(VRFW_Pager.PillShow) == "function" then
    pcall(VRFW_Pager.PillShow, "tech_preview", on)
  end
end

-- the prompt shows for a special move with a cut-in while the card is up, over the menu-scene dock
function BetterQoL.TechPreview.Want()
  local T = BetterQoL.TechPreview
  if T.busy or T.skill == 0 then return false end
  local okv, vis = pcall(funcLuaMenuCommand, T.IS_LVIS, T.CARD, 0)
  if okv and vis == false then return false end
  if T.ctx_skill ~= T.skill then
    T.ctx_skill, T.ctx = T.skill, T.Context()
  end
  if T.ctx ~= "" then return false end
  local p = T.Plan(T.skill)
  return p ~= nil and p.ok
end

function BetterQoL.TechPreview.Step()
  local T = BetterQoL.TechPreview
  if T.co ~= nil then
    local ok, e = coroutine.resume(T.co)
    if not ok then
      T.Log("play failed:", e)
      T.co = nil
      T.Restore("error")
    elseif coroutine.status(T.co) == "dead" then
      T.co = nil
    end
    return
  end
  if not T.HintReady() then return end
  local want = T.Want()
  T.Show(want)
  if not want then return end
  local okf, act = pcall(funcLuaMenuCommand, T.FOCUS_ACTIVE, T.ITEM)
  if not (okf and act == true) then return end
  local okk, pressed = pcall(funcLuaCommand, T.INPUT, T.MENU_CTRL, T.KEY)
  if okk and pressed == true then
    T.co = coroutine.create(T.Play)
    local ok, e = coroutine.resume(T.co, T.skill)
    if not ok then
      T.Log("play failed:", e)
      T.co = nil
      T.Restore("error")
    end
  end
end

local function Wait(frames, cond)
  for _ = 1, frames do
    if cond() then return true end
    coroutine.yield()
  end
  return cond()
end

local function FadeWait()
  Wait(120, function() return funcLuaCommand(BetterQoL.TechPreview.IS_FADE) ~= true end)
end

-- the performer's model held by the one-model menu (hidden): true when it reports ready
function BetterQoL.TechPreview.Carrier(hdl)
  local T, c = BetterQoL.TechPreview, BetterQoL.TechPreview.Cfg()
  local okm, base = pcall(funcLuaCommand, T.CHARA_INFO, hdl, 4)
  local okd, model = pcall(funcLuaCommand, T.CHARA_MODEL_ID, okm and base or 0)
  if not okd or type(model) ~= "number" or model == 0 then
    T.Log("carrier: no model id for", T.Hex(hdl), tostring(base), tostring(model))
    return false
  end
  T.st.carrier_opened = false
  if not Has(c.carrier) then
    funcLuaCommand(T.OPEN_MENU, c.carrier)
    T.st.carrier_opened = true
  end
  Wait(240, function()
    local okl, loading = pcall(funcLuaCommand, T.MENU_LOADING, c.carrier)
    return Has(c.carrier) and not (okl and loading == true)
  end)
  coroutine.yield()
  VRFW_Param.Clear(T.READY_KEY)
  pcall(funcLuaCommand, T.CROSS, c.carrier, "Utilities_TpCarrier", "set", c.carrier_layer, model)
  local ready, frames = nil, 0
  Wait(c.model_wait or 300, function()
    frames = frames + 1
    pcall(funcLuaCommand, T.CROSS, c.carrier, "Utilities_TpCarrier", "poll", c.carrier_layer, T.READY_KEY)
    if VRFW_Param.Has(T.READY_KEY) then
      ready = VRFW_Param.Get(T.READY_KEY)
      return true
    end
    return false
  end)
  VRFW_Param.Clear(T.READY_KEY)
  T.Log("carrier", "menu opened", tostring(T.st.carrier_opened), "model", T.Hex(model), "base", T.Hex(base), "ready",
    tostring(ready), "frames", frames)
  return ready == 1
end

local function BarList()
  local c, t = BetterQoL.TechPreview.Cfg(), {}
  for _, l in ipairs(c.bar_layers or {}) do t[#t + 1] = tostring(math.floor(l)) end
  return table.concat(t, ",")
end

-- everything the play changed, given back in reverse (also after an error)
function BetterQoL.TechPreview.Restore(why)
  local T, st, c = BetterQoL.TechPreview, BetterQoL.TechPreview.st, BetterQoL.TechPreview.Cfg()
  if st == nil then
    T.busy = false
    return
  end
  T.st = nil
  if st.running then pcall(funcLuaCommand, T.LIVE_CTL, "release", 0) end
  pcall(funcLuaCommand, T.FADE, 1, 0)
  for i = #(st.bars or {}), 1, -1 do
    pcall(funcLuaCommand, T.CROSS, st.bars[i], "Utilities_TpBars", 0, "")
  end
  for i = #(st.hidden or {}), 1, -1 do
    pcall(funcLuaMenuCommand, T.SHOW, st.hidden[i])
    pcall(funcLuaMenuCommand, T.RESUME, st.hidden[i])
  end
  if st.carrier_set and c ~= nil then
    pcall(funcLuaCommand, T.CROSS, c.carrier, "Utilities_TpCarrier", "end", c.carrier_layer)
    if st.carrier_opened then pcall(funcLuaCommand, T.CLOSE_MENU, c.carrier) end
  end
  if type(VRFW_TopBarHide) == "function" then pcall(VRFW_TopBarHide, false) end
  if st.bgm then pcall(funcLuaCommand, T.BGM_RESUME) end
  pcall(funcLuaCommand, T.FADE, 0, c and c.fade_s or 0.3)
  T.busy = false
  T.Show(false)
  T.Log("back to the list:", why, "menus", #(st.hidden or {}), "bars", #(st.bars or {}))
end

-- the coroutine of one preview (resumed by Step)
function BetterQoL.TechPreview.Play(skill)
  local T, c = BetterQoL.TechPreview, BetterQoL.TechPreview.Cfg()
  local p = T.Plan(skill)
  if c == nil or p == nil or not p.ok then return end
  local ctx = T.Context()
  if ctx ~= "" then
    T.Log("not played:", ctx)
    return
  end
  T.busy = true
  T.st = {hidden = {}, bars = {}}
  T.Show(false)
  T.Log("play", T.Hex(skill), p.event, "by", p.name, T.Hex(p.hdl), "body", p.body,
    "category", p.category, "(" .. tostring(p.how) .. ")")
  if type(VRFW_TopBarHide) == "function" then pcall(VRFW_TopBarHide, true) end
  funcLuaCommand(T.BGM_STOP, c.bgm_fade_s or 0.5)
  T.st.bgm = true
  funcLuaCommand(T.FADE, 1, c.fade_s or 0.3)
  FadeWait()
  -- under the black: the performer's model, then the move's event with him over a preview slot
  T.st.carrier_set = true
  local held = T.Carrier(p.hdl)
  local okv, slot, notes = pcall(funcLuaCommand, T.PREVIEW, p.event, p.name, p.body)
  T.Log("preview slot", tostring(okv), tostring(slot), tostring(notes))
  if not okv or type(slot) ~= "string" or slot == "" then
    T.Restore("no preview slot")
    return
  end
  for _, m in ipairs(c.hide or {}) do
    if Has(m) then
      pcall(funcLuaMenuCommand, T.SUSPEND, m)
      pcall(funcLuaMenuCommand, T.HIDE, 1, m)
      T.st.hidden[#T.st.hidden + 1] = m
    end
  end
  local bars = BarList()
  for _, m in ipairs(c.bar_menus or {}) do
    if Has(m) then
      pcall(funcLuaCommand, T.CROSS, m, "Utilities_TpBars", 1, bars)
      T.st.bars[#T.st.bars + 1] = m
    end
  end
  if (c.backdrop or 0) ~= 0 then pcall(funcLuaCommand, T.CRAFT, c.backdrop) end
  local okr, res, nowait = pcall(funcLuaCommand, T.RESERVE, CALC_CRC(slot))
  local note = ""
  if not okr then
    note = "CMND_RESERVE_EVENT raised: " .. tostring(res)
  elseif type(res) ~= "number" then
    note = "CMND_RESERVE_EVENT answered " .. tostring(res)
  end
  pcall(funcLuaCommand, T.LIVE_WINDOW, 0, 0, 0, 0, 0)
  pcall(funcLuaCommand, T.LIVE_VIEW, 1, 0, 0)
  local okl, run, why = pcall(funcLuaCommand, T.LIVE_RUN, type(res) == "number" and res or 0, slot, note)
  T.Log("run", slot, "reserved", tostring(res), tostring(nowait), "->", tostring(okl), tostring(run), tostring(why),
    "model held", tostring(held), "menus hidden", #T.st.hidden)
  if not (okl and run == true) then
    T.Restore("not played: " .. tostring(why))
    return
  end
  T.st.running = true
  pcall(funcLuaCommand, T.LIVE_CTL, "hold", 0)      -- played into its end, then the scene closes
  local frames, phase, faded, ended, seen = 0, "starting", false, false, {}
  while frames < (c.max_frames or 7200) do
    coroutine.yield()
    frames = frames + 1
    local okt, ph = pcall(funcLuaCommand, T.LIVE_TICK)
    phase = okt and type(ph) == "string" and ph or "error"
    if not seen[phase] then
      seen[phase] = true
      T.Log("phase", phase, "frame", frames)
    end
    if phase == "running" and not faded then
      faded = true
      funcLuaCommand(T.FADE, 0, c.fade_s or 0.3)
    end
    if phase ~= "starting" and phase ~= "running" then break end
    if not ended and c.back_skips == 1 and phase == "running" then
      local okb, back = pcall(funcLuaCommand, T.INPUT, T.MENU_CTRL, T.CANCEL)
      if okb and back == true then
        ended = true
        pcall(funcLuaCommand, T.LIVE_CTL, "end", 0)
        T.Log("ended with B at frame", frames)
      end
    end
  end
  if phase == "starting" or phase == "running" then
    T.Log("timeout after", frames, "frames: ended")
    pcall(funcLuaCommand, T.LIVE_CTL, "end", 0)
    Wait(600, function()
      local okt, ph = pcall(funcLuaCommand, T.LIVE_TICK)
      return not (okt and (ph == "starting" or ph == "running"))
    end)
  end
  T.Restore("played (" .. phase .. ", " .. frames .. " frames)")
  FadeWait()
end

do
  local prev = UpdateSkillDetailWindow
  function UpdateSkillDetailWindow(a1, ...)
    local r = table.pack(prev(a1, ...))
    local s = type(a1) == "number" and a1 or 0
    if s ~= BetterQoL.TechPreview.skill then BetterQoL.TechPreview.skill = s end
    return table.unpack(r, 1, r.n)
  end
end

do
  -- a tab whose list is empty leaves no move on the card
  local prev = OnChangeFocus
  function OnChangeFocus(a1, a2)
    local r = table.pack(prev(a1, a2))
    if a1 == BetterQoL.TechPreview.TAB then
      local ok, n = pcall(funcLuaMenuCommand, BetterQoL.TechPreview.LIST_COUNT, BetterQoL.TechPreview.LIST)
      if ok and type(n) == "number" and n <= 0 then BetterQoL.TechPreview.skill = 0 end
    end
    return table.unpack(r, 1, r.n)
  end
end

do
  local prev = OnSetupLayer
  function OnSetupLayer(a1, a2)
    if a1 == BetterQoL.TechPreview.HINT then
      pcall(funcLuaMenuCommand, BetterQoL.TechPreview.LVIS, a1, a2, false)
      BetterQoL.TechPreview.shown = false
    end
    if prev ~= nil then return prev(a1, a2) end
  end
end

do
  -- while the cut-in plays the screen's own functions (filter, sort, detail page) do nothing
  local prev = OnFunction
  function OnFunction(...)
    if BetterQoL.TechPreview.busy then return end
    if prev ~= nil then return prev(...) end
  end
end

do
  local prev = Step
  function Step(...)
    local r
    if BetterQoL.TechPreview.busy and BetterQoL.TechPreview.co == nil then
      BetterQoL.TechPreview.Restore("left busy")
    end
    if prev ~= nil and not BetterQoL.TechPreview.busy then r = table.pack(prev(...)) end
    local ok, e = pcall(BetterQoL.TechPreview.Step)
    if not ok then BetterQoL.TechPreview.Log("step error:", e) end
    if r ~= nil then return table.unpack(r, 1, r.n) end
  end
end
