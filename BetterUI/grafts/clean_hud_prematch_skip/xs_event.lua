--@lib clean_hud_xskip.lua#Head
-- Clean HUD pre-match X skip, event side (event_menu: the walk-in / entrance events between the VS screen and the
-- kick-off; docs/game/ui/prematch-skip.md). Left of the retail «(Y) Saltar» guide (layer soccer01_32_replay_button_guide,
-- hold Y = CMND_EVENT_SKIP of this event only) the same guide again (layer clean_hud_xskip_guide, Clean HUD's
-- menus\prematch_skip.toml) reads «(X) <clean_hud.prematch_skip>». Holding X (input CMD_CLEAN_HUD_XSKIP_HOLD of
-- EVENT_CTRL_VISUAL / EVENT_CTRL_TALK, Clean HUD's inputs\prematch_skip.toml) fills its ring like the retail one; when
-- full, the parameter GO is set and the event is skipped the retail way. From then on every pre-match event is skipped
-- as soon as the engine allows it (CMND 0xA50623F3: not in its last 2 s), and the lineup screens close at once
-- (xs_lineup.lua), so the match goes straight to the kick-off. None of that is seen: with the skip's own fade out a
-- black cover goes up on fade layer 1 (the retail skip fades layer 0 out and back in per event; layer 1 is not
-- touched by it), is held every frame while GO, and is lifted only at the kick-off (CHD_XS.Disarm: the lineups hand
-- it to the retail layer 0 fade, the kick-off button fades it in). Once black it is also held natively (CHD_XS.Hold:
-- BetterUI's hook BrightFadeLayer keeps layer 1 black against the game's own fade-ins at each event start / end and in
-- the flow's states 11 / 13, which this Step cannot see between two events). Safety: an event that stays unskippable for
-- CHD_XS_STUCK_S lifts the cover (never a black screen with a scene playing under it). Only while ARMED (set when a
-- VS screen closes offline, cleared by the lineups, the kick-off and half time): story events, replays and every other
-- event keep the retail guide alone. Hold time: CMND_EVT_CHD_XSKIP_HOLD (clean_hud.dll, config.toml prematch_skip_hold; 0 = off), else 1 s.
-- BetterUI 1.21.7: when the ring is full the event is ended in that frame by BetterUI's direct jump
-- (CMND_BETTERUI_XSKIP_JUMP: sounds stopped, timeline run to its end, no fade); the native flow then starts no second
-- entrance event and the lineups close unopened (xs_lineup.lua): no cover, no chained skips. The cover path above is
-- the fallback when the jump is not available (asked CHD_XS_JUMP_TRIES Steps first).
-- Wrappers only (OnSetupLayer, OpenButtonGuideUI, ResetSkippedState, Step); no engine call at chunk load.
local CHD_XS_GUIDE = 3123960154          -- clean_hud_xskip_guide (crc32 of the layer name)
local CHD_XS_BAR = 1996459178            -- bar (MenuRateSetting of the guide: the hold ring)
local CHD_XS_TEXT_GUIDE = 378156699      -- _text_guide01
local CHD_XS_TEXT_BTN = 950238781        -- _text_btn01
local CHD_XS_GLYPH = 1097287577          -- menu_text "<CMD_FUNC4>" (X / its keyboard key, as <CMD_FUNC3> is Y here)
local CHD_XS_LABEL = "clean_hud.prematch_skip"
local CHD_XS_LABEL_CRC = 1249018515      -- crc32("clean_hud.prematch_skip")
local CHD_XS_HOLD_CMD = 4111682363       -- CMND_EVT_CHD_XSKIP_HOLD
local CHD_XS_INPUT = 4265778440          -- CMND_CHECK_INPUT_CMD
local CHD_XS_KEY = 92443601              -- CMD_CLEAN_HUD_XSKIP_HOLD
local CHD_XS_CTRLS = {2917185202 --[[EVENT_CTRL_VISUAL]], 3237690481 --[[EVENT_CTRL_TALK]]}
local CHD_XS_SHOW_S = 3                  -- s the guide stays after the last input (retail n = 3)
local CHD_XS_BUSY_S = 3.0                -- s before the same event may be skipped again (fade out + seek + fade in)
local CHD_XS_DEFAULT_HOLD = 1.0
local CHD_XS_COVER_OUT_S = 0.5           -- the cover's fade out = the retail skip's fade to black (0.5 s)
local CHD_XS_STUCK_S = 6.0               -- s an event may stay unskippable under the cover before it is lifted
local CHD_XS_JUMP_TRIES = 5              -- Steps the direct jump is asked again (BetterUI's script busy) before the cover path
local chd_xs = {hold = 0, holdT = nil, open = false, showT = 0, busy = false, busyT = 0, coverT = nil, stuckT = 0,
                jumpTries = nil}

local function ChdXsHoldTime()
  if chd_xs.holdT == nil then
    local ok, v = pcall(funcLuaCommand, CHD_XS_HOLD_CMD)
    chd_xs.holdT = (ok and type(v) == "number") and v or CHD_XS_DEFAULT_HOLD
  end
  return chd_xs.holdT
end

local function ChdXsCanSkip()
  local ok, v = pcall(funcLuaMenuCommand, 2768643059)
  return ok and v == true
end

local function ChdXsHeld()
  for _, c in ipairs(CHD_XS_CTRLS) do
    local ok, v = pcall(funcLuaCommand, CHD_XS_INPUT, c, CHD_XS_KEY)
    if ok and v == true then
      return true
    end
  end
  return false
end

local function ChdXsOpenAnim()
  return funcLuaMenuCommand(1352645570, CHD_XS_GUIDE, 71445658 --[[Open]])
end

local function ChdXsBar(r)
  pcall(funcLuaMenuCommand, 1595998683, CHD_XS_GUIDE, CHD_XS_BAR, 0, r, 0)
end

local function ChdXsOpen()               -- as the retail OpenButtonGuideUI does it for the Y guide
  if not funcLuaMenuCommand(2640875187 --[[CMND_IS_OPEN_LAYER]], CHD_XS_GUIDE, 0) then
    funcLuaMenuCommand(629267548 --[[CMND_OPEN_LAYER]], CHD_XS_GUIDE, 0)
  elseif funcLuaMenuCommand(1914009721 --[[CMND_IS_END_ANIME?]], CHD_XS_GUIDE, ChdXsOpenAnim(), 753088835 --[[Default]], 1, 0) then
    funcLuaMenuCommand(1748788158 --[[CMND_PLAY_ANIME]], CHD_XS_GUIDE, ChdXsOpenAnim(), 753088835 --[[Default]])
  end
  chd_xs.open = true
  chd_xs.showT = CHD_XS_SHOW_S
end

local function ChdXsClose()
  if chd_xs.open then
    chd_xs.open = false
    pcall(funcLuaMenuCommand, 652384334 --[[CMND_END_ANIME]], CHD_XS_GUIDE, ChdXsOpenAnim(), 753088835 --[[Default]])
  end
end

local function ChdXsReady()              -- the X guide belongs on screen now
  return CHD_XS.Get(CHD_XS.ARMED) == 1 and CHD_XS.Get(CHD_XS.GO) ~= 1 and ChdXsHoldTime() > 0 and ChdXsCanSkip()
end

local function ChdXsSkip(src)            -- the retail skip of RunCoroutineSkipButton
  local ok, r = pcall(funcLuaMenuCommand, 2872569508 --[[CMND_EVENT_SKIP]])
  if ok and r then
    pcall(funcLuaCommand, 155728325)
  end
  chd_xs.busy = true
  chd_xs.busyT = 0
  chd_xs.hold = 0
  ChdXsBar(0)
  ChdXsClose()
  CHD_XS.Log("event skipped", src, tostring(ok), tostring(r))
end

local function ChdXsText()
  local ok, id = pcall(funcLuaCommand, 3096244543 --[[CMND_VRFW_TEXT_ID]], CHD_XS_LABEL)
  if not (ok and type(id) == "number" and id ~= 0) then
    id = CHD_XS_LABEL_CRC
  end
  local s = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], id)
  return type(s) == "string" and s or ""
end

local function ChdXsCoverPath(src)      -- fallback (no direct jump): one fade to black, the events skipped under it
  CHD_XS.Set(CHD_XS.COVER, 1)
  CHD_XS.Cover(CHD_XS_COVER_OUT_S)       -- the one fade out; black from here to the kick-off
  chd_xs.coverT = 0
  chd_xs.stuckT = 0
  CHD_XS.Log(src, ": straight to the kick-off (cover up)")
  ChdXsSkip(src)
end

local function ChdXsJumped(src)          -- the direct jump ended the event: nothing else to do here
  chd_xs.jumpTries = nil
  chd_xs.busy = true
  chd_xs.busyT = 0
  chd_xs.hold = 0
  ChdXsBar(0)
  ChdXsClose()
  CHD_XS.Log(src, ": direct jump to the kick-off (no fade, no cover)")
end

local function ChdXsHoldCover(dt, can)  -- GO: keep the black cover up (layer 1) once its fade out is over
  if CHD_XS.Get(CHD_XS.COVER) ~= 1 then
    return
  end
  if chd_xs.coverT == nil then           -- a later event (new event_menu state): the cover is already up
    chd_xs.coverT = CHD_XS_COVER_OUT_S
  end
  if chd_xs.coverT < CHD_XS_COVER_OUT_S then
    chd_xs.coverT = chd_xs.coverT + dt
  else
    CHD_XS.Cover(0)
    CHD_XS.Hold()                        -- black now: the framework keeps it so (the game's fade-ins between events)
  end
  if can or chd_xs.busy then
    chd_xs.stuckT = 0
  else
    chd_xs.stuckT = chd_xs.stuckT + dt
    if chd_xs.stuckT >= CHD_XS_STUCK_S then
      CHD_XS.Uncover(CHD_XS.COVER_IN_S, "event not skippable")
    end
  end
end

local function ChdXsStep()
  if CHD_XS.Get(CHD_XS.ARMED) ~= 1 then
    ChdXsClose()
    chd_xs.hold = 0
    return
  end
  local dt = funcLuaCommand(2839043456) or 0
  local can = ChdXsCanSkip()
  if CHD_XS.Get(CHD_XS.GO) == 1 then      -- X was held: every pre-match event goes as soon as it can
    ChdXsClose()
    if CHD_XS.Get(CHD_XS.JUMP) == 1 then  -- direct jump: a later pre-match event (if any) is ended the same way
      if chd_xs.busy then
        if not can then
          chd_xs.busy = false
        end
      elseif can then
        if CHD_XS.Jump("next pre-match event") then
          ChdXsJumped("next pre-match event")
        else
          ChdXsSkip("next pre-match event (no jump: retail skip)")
        end
      end
      return
    end
    if chd_xs.jumpTries ~= nil then       -- the jump was not answered yet: asked again, then the cover path
      if CHD_XS.Jump("X held (retry " .. chd_xs.jumpTries .. ")") then
        ChdXsJumped("X held")
      elseif chd_xs.jumpTries >= CHD_XS_JUMP_TRIES then
        chd_xs.jumpTries = nil
        ChdXsCoverPath("X held (no direct jump)")
      else
        chd_xs.jumpTries = chd_xs.jumpTries + 1
      end
      return
    end
    ChdXsHoldCover(dt, can)
    if chd_xs.busy then
      chd_xs.busyT = chd_xs.busyT + dt
      if not can or chd_xs.busyT >= CHD_XS_BUSY_S then
        chd_xs.busy = false
      end
    elseif can then
      ChdXsSkip("next pre-match event")
    end
    return
  end
  local holdT = ChdXsHoldTime()
  if holdT <= 0 or not can then
    if chd_xs.hold > 0 then
      ChdXsBar(0)
    end
    chd_xs.hold = 0
    ChdXsClose()
    return
  end
  if ChdXsHeld() then
    OpenButtonGuideUI()                  -- the retail Y guide too (through the wrapper below, the X guide)
    ChdXsOpen()
    chd_xs.hold = chd_xs.hold + dt
    ChdXsBar(math.min(1, chd_xs.hold / holdT))
    if chd_xs.hold >= holdT then
      CHD_XS.Set(CHD_XS.GO, 1)
      CHD_XS.Log("X held", holdT, "s")
      if CHD_XS.Jump("X held") then      -- BetterUI ended the event in this frame (CMND_BETTERUI_XSKIP_JUMP)
        ChdXsJumped("X held")
      else
        chd_xs.jumpTries = 1             -- asked again next Steps (script busy), then ChdXsCoverPath
        chd_xs.hold = 0
        ChdXsBar(0)
        ChdXsClose()
        CHD_XS.Log("direct jump not answered: asked again")
      end
    end
    return
  end
  if chd_xs.hold > 0 then
    chd_xs.hold = 0
    ChdXsBar(0)
  end
  if chd_xs.open then
    chd_xs.showT = chd_xs.showT - dt
    if chd_xs.showT <= 0 then
      ChdXsClose()
    end
  end
end

local chd_xs_prev_setup = OnSetupLayer
function OnSetupLayer(a1, a2)
  if a1 == CHD_XS_GUIDE then             -- the retail setup of the Y guide, with the X glyph and the Clean HUD label
    local glyph = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], CHD_XS_GLYPH, 0)
    funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], a1, CHD_XS_TEXT_GUIDE, ChdXsText(), a2)
    funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], a1, CHD_XS_TEXT_BTN, type(glyph) == "string" and glyph or "<CMD_FUNC4>", a2)
    funcLuaMenuCommand(541357333, a1, CHD_XS_BAR, 0, a2)
    funcLuaMenuCommand(1595998683, a1, CHD_XS_BAR, 0, 0, a2)
    return
  end
  return chd_xs_prev_setup(a1, a2)
end

local chd_xs_prev_open_guide = OpenButtonGuideUI
function OpenButtonGuideUI(a1)
  local r = chd_xs_prev_open_guide(a1)
  local ok, ready = pcall(ChdXsReady)
  if ok and ready then
    pcall(ChdXsOpen)
  end
  return r
end

local chd_xs_prev_reset = ResetSkippedState
function ResetSkippedState(...)
  chd_xs.busy = false
  chd_xs.hold = 0
  pcall(funcLuaMenuCommand, 3842369982, CHD_XS_GUIDE)
  ChdXsBar(0)
  chd_xs.open = false
  return chd_xs_prev_reset(...)
end

local chd_xs_prev_step = Step
function Step()
  local r = chd_xs_prev_step()
  local ok, err = pcall(ChdXsStep)
  if not ok then
    CHD_XS.Log("step error", tostring(err))
  end
  return r
end
