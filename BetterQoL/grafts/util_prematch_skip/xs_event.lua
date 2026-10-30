--@lib util_xskip.lua#Head
-- Utilities pre-match X skip, event side (event_menu: the walk-in / entrance events between the VS screen and the
-- kick-off; docs/game/ui/prematch-skip.md). Left of the retail «(Y) Saltar» guide (layer soccer01_32_replay_button_guide,
-- hold Y = CMND_EVENT_SKIP of this event only) the same guide again (layer util_xskip_guide, Utilities'
-- menus\prematch_skip.toml) reads «(X) <utilities.prematch_skip>». Holding X (input CMD_UTIL_XSKIP_HOLD of
-- EVENT_CTRL_VISUAL / EVENT_CTRL_TALK, Utilities' inputs\prematch_skip.toml) fills its ring like the retail one; when
-- full, the parameter GO is set and the event is skipped the retail way. From then on every pre-match event is skipped
-- as soon as the engine allows it (CMND 0xA50623F3: not in its last 2 s), and the lineup screens close at once
-- (xs_lineup.lua), so the match goes straight to the kick-off. None of that is seen: with the skip's own fade out a
-- black cover goes up on fade layer 1 (the retail skip fades layer 0 out and back in per event; layer 1 is not
-- touched by it), is held every frame while GO, and is lifted only at the kick-off (UTIL_XS.Disarm: the lineups hand
-- it to the retail layer 0 fade, the kick-off button fades it in). Once black it is also held natively (UTIL_XS.Hold:
-- Utilities' hook BrightFadeLayer keeps layer 1 black against the game's own fade-ins at each event start / end and in
-- the flow's states 11 / 13, which this Step cannot see between two events). Safety: an event that stays unskippable for
-- UTIL_XS_STUCK_S lifts the cover (never a black screen with a scene playing under it). Only while ARMED (set when a
-- VS screen closes offline, cleared by the lineups, the kick-off and half time): story events, replays and every other
-- event keep the retail guide alone. Hold time: CMND_BETTERQOL_XSKIP_HOLD (Utilities' scripts\prematch_skip.lua, config.toml prematch_skip_hold; 0 = off), else 1 s.
-- BetterUI 1.21.7: when the ring is full the event is ended in that frame by Utilities' direct jump
-- (CMND_BETTERQOL_XSKIP_JUMP: sounds stopped, timeline run to its end, no fade); the native flow then starts no second
-- entrance event and the lineups close unopened (xs_lineup.lua): no cover, no chained skips. The cover path above is
-- the fallback when the jump is not available (asked UTIL_XS_JUMP_TRIES Steps first).
-- BetterUI 1.22.3: the jump runs under one fade to black. X full -> the cover fades layer 1 to black
-- (UTIL_XS_COVER_OUT_S), is held natively, then the event is ended; the flow's states 12 -> 13 -> 14 (lineup cameras,
-- formations, BGM) run under it and the lineups hand it to the retail kick-off fade in (xs_lineup.lua): no camera cuts.
-- Wrappers only (OnSetupLayer, OpenButtonGuideUI, ResetSkippedState, Step); no engine call at chunk load.
local UTIL_XS_GUIDE = 1753759681          -- util_xskip_guide (crc32 of the layer name)
local UTIL_XS_BAR = 1996459178            -- bar (MenuRateSetting of the guide: the hold ring)
local UTIL_XS_TEXT_GUIDE = 378156699      -- _text_guide01
local UTIL_XS_TEXT_BTN = 950238781        -- _text_btn01
local UTIL_XS_GLYPH = 1097287577          -- menu_text "<CMD_FUNC4>" (X / its keyboard key, as <CMD_FUNC3> is Y here)
local UTIL_XS_LABEL = "utilities.prematch_skip"
local UTIL_XS_LABEL_CRC = 1667839001      -- crc32("utilities.prematch_skip")
local UTIL_XS_HOLD_CMD = @crc:CMND_BETTERQOL_XSKIP_HOLD@
local UTIL_XS_INPUT = @crc:CMND_CHECK_INPUT_CMD@
local UTIL_XS_KEY = 2293079475              -- CMD_UTIL_XSKIP_HOLD
local UTIL_XS_CTRLS = {2917185202 --[[EVENT_CTRL_VISUAL]], 3237690481 --[[EVENT_CTRL_TALK]]}
local UTIL_XS_SHOW_S = 3                  -- s the guide stays after the last input (retail n = 3)
local UTIL_XS_BUSY_S = 3.0                -- s before the same event may be skipped again (fade out + seek + fade in)
local UTIL_XS_DEFAULT_HOLD = 1.0
local UTIL_XS_COVER_OUT_S = 0.4           -- the cover's fade out before the jump / the cover path's skips
local UTIL_XS_STUCK_S = 6.0               -- s an event may stay unskippable under the cover before it is lifted
local UTIL_XS_JUMP_TRIES = 5              -- Steps the direct jump is asked again (Utilities' script busy) before the cover path
local util_xs = {hold = 0, holdT = nil, open = false, showT = 0, busy = false, busyT = 0, coverT = nil, stuckT = 0,
                jumpTries = nil, coverPath = false}

local function UtilXsHoldTime()
  if util_xs.holdT == nil then
    local ok, v = pcall(funcLuaCommand, UTIL_XS_HOLD_CMD)
    util_xs.holdT = (ok and type(v) == "number") and v or UTIL_XS_DEFAULT_HOLD
  end
  return util_xs.holdT
end

local function UtilXsCanSkip()
  local ok, v = pcall(funcLuaMenuCommand, 2768643059)
  return ok and v == true
end

local function UtilXsHeld()
  for _, c in ipairs(UTIL_XS_CTRLS) do
    local ok, v = pcall(funcLuaCommand, UTIL_XS_INPUT, c, UTIL_XS_KEY)
    if ok and v == true then
      return true
    end
  end
  return false
end

local function UtilXsOpenAnim()
  return funcLuaMenuCommand(1352645570, UTIL_XS_GUIDE, 71445658 --[[Open]])
end

local function UtilXsBar(r)
  pcall(funcLuaMenuCommand, 1595998683, UTIL_XS_GUIDE, UTIL_XS_BAR, 0, r, 0)
end

local function UtilXsOpen()               -- as the retail OpenButtonGuideUI does it for the Y guide
  if not funcLuaMenuCommand(@crc:CMND_IS_OPEN_LAYER@, UTIL_XS_GUIDE, 0) then
    funcLuaMenuCommand(@crc:CMND_OPEN_LAYER@, UTIL_XS_GUIDE, 0)
  elseif funcLuaMenuCommand(@crc:CMND_IS_END_ANIME@, UTIL_XS_GUIDE, UtilXsOpenAnim(), 753088835 --[[Default]], 1, 0) then
    funcLuaMenuCommand(@crc:CMND_PLAY_ANIME@, UTIL_XS_GUIDE, UtilXsOpenAnim(), 753088835 --[[Default]])
  end
  util_xs.open = true
  util_xs.showT = UTIL_XS_SHOW_S
end

local function UtilXsClose()
  if util_xs.open then
    util_xs.open = false
    pcall(funcLuaMenuCommand, @crc:CMND_END_ANIME@, UTIL_XS_GUIDE, UtilXsOpenAnim(), 753088835 --[[Default]])
  end
end

local function UtilXsReady()              -- the X guide belongs on screen now
  return UTIL_XS.Get(UTIL_XS.ARMED) == 1 and UTIL_XS.Get(UTIL_XS.GO) ~= 1 and UtilXsHoldTime() > 0 and UtilXsCanSkip()
end

local function UtilXsSkip(src)            -- the retail skip of RunCoroutineSkipButton
  local ok, r = pcall(funcLuaMenuCommand, @crc:CMND_EVENT_SKIP@)
  if ok and r then
    pcall(funcLuaCommand, 155728325)
  end
  util_xs.busy = true
  util_xs.busyT = 0
  util_xs.hold = 0
  UtilXsBar(0)
  UtilXsClose()
  UTIL_XS.Log("event skipped", src, tostring(ok), tostring(r))
end

local function UtilXsText()
  local ok, id = pcall(funcLuaCommand, @crc:CMND_VRFW_TEXT_ID@, UTIL_XS_LABEL)
  if not (ok and type(id) == "number" and id ~= 0) then
    id = UTIL_XS_LABEL_CRC
  end
  local s = funcLuaCommand(@crc:CMND_TEXT_GET@, id)
  return type(s) == "string" and s or ""
end

local function UtilXsJumped(src)          -- the direct jump ended the event: nothing else to do here
  util_xs.jumpTries = nil
  util_xs.busy = true
  util_xs.busyT = 0
  util_xs.hold = 0
  UtilXsBar(0)
  UtilXsClose()
  UTIL_XS.Log(src, ": direct jump to the kick-off (event ended under the black cover)")
end

local function UtilXsHoldCover(dt, can)  -- GO: keep the black cover up (layer 1) once its fade out is over
  if UTIL_XS.Get(UTIL_XS.COVER) ~= 1 then
    return
  end
  if util_xs.coverT == nil then           -- a later event (new event_menu state): the cover is already up
    util_xs.coverT = UTIL_XS_COVER_OUT_S
  end
  if util_xs.coverT < UTIL_XS_COVER_OUT_S then
    util_xs.coverT = util_xs.coverT + dt
  else
    UTIL_XS.Cover(0)
    UTIL_XS.Hold()                        -- black now: the framework keeps it so (the game's fade-ins between events)
  end
  if can or util_xs.busy then
    util_xs.stuckT = 0
  else
    util_xs.stuckT = util_xs.stuckT + dt
    if util_xs.stuckT >= UTIL_XS_STUCK_S then
      UTIL_XS.Uncover(UTIL_XS.COVER_IN_S, "event not skippable")
    end
  end
end

local function UtilXsKeepBlack()         -- the cover stays black while the flow runs on to the lineups
  if UTIL_XS.Get(UTIL_XS.COVER) == 1 then
    UTIL_XS.Cover(0)
    UTIL_XS.Hold()
  end
end

local function UtilXsJumpUnderCover(dt, can)  -- the fade to black first, then the direct jump (else the cover path)
  UtilXsHoldCover(dt, can)
  if UTIL_XS.Get(UTIL_XS.COVER) == 1 and util_xs.coverT < UTIL_XS_COVER_OUT_S then
    return                               -- still fading to black
  end
  if not can then                        -- no event to end yet (a later event loading): kept black, asked next Step
    return
  end
  local src = "X held (" .. (util_xs.jumpTries or 0) .. ")"
  if UTIL_XS.Jump(src) then
    UtilXsJumped(src)
    return
  end
  util_xs.jumpTries = (util_xs.jumpTries or 0) + 1
  if util_xs.jumpTries >= UTIL_XS_JUMP_TRIES then
    util_xs.coverPath = true
    UTIL_XS.Log("direct jump not answered: cover path")
    UtilXsSkip("X held (no direct jump)")
  end
end

local function UtilXsStep()
  if UTIL_XS.Get(UTIL_XS.ARMED) ~= 1 then
    UtilXsClose()
    util_xs.hold = 0
    return
  end
  local dt = funcLuaCommand(2839043456) or 0
  local can = UtilXsCanSkip()
  if UTIL_XS.Get(UTIL_XS.GO) == 1 then      -- X was held: every pre-match event goes as soon as it can
    UtilXsClose()
    if UTIL_XS.Get(UTIL_XS.JUMP) == 1 then  -- direct jump: a later pre-match event (if any) is ended the same way
      UtilXsKeepBlack()
      if util_xs.busy then
        if not can then
          util_xs.busy = false
        end
      elseif can then
        if UTIL_XS.Jump("next pre-match event") then
          UtilXsJumped("next pre-match event")
        else
          UtilXsSkip("next pre-match event (no jump: retail skip)")
        end
      end
      return
    end
    if not util_xs.coverPath then         -- the jump waits for the fade to black (also in a later event's menu)
      UtilXsJumpUnderCover(dt, can)
      return
    end
    UtilXsHoldCover(dt, can)
    if util_xs.busy then
      util_xs.busyT = util_xs.busyT + dt
      if not can or util_xs.busyT >= UTIL_XS_BUSY_S then
        util_xs.busy = false
      end
    elseif can then
      UtilXsSkip("next pre-match event")
    end
    return
  end
  local holdT = UtilXsHoldTime()
  if holdT <= 0 or not can then
    if util_xs.hold > 0 then
      UtilXsBar(0)
    end
    util_xs.hold = 0
    UtilXsClose()
    return
  end
  if UtilXsHeld() then
    OpenButtonGuideUI()                  -- the retail Y guide too (through the wrapper below, the X guide)
    UtilXsOpen()
    util_xs.hold = util_xs.hold + dt
    UtilXsBar(math.min(1, util_xs.hold / holdT))
    if util_xs.hold >= holdT then
      UTIL_XS.Set(UTIL_XS.GO, 1)
      UTIL_XS.Set(UTIL_XS.COVER, 1)
      UTIL_XS.Cover(UTIL_XS_COVER_OUT_S)   -- the one fade to black; the event is ended once it is black
      util_xs.coverT = 0
      util_xs.stuckT = 0
      util_xs.jumpTries = nil
      util_xs.hold = 0
      UtilXsBar(0)
      UtilXsClose()
      UTIL_XS.Log("X held", holdT, "s: fade to black, then the direct jump")
    end
    return
  end
  if util_xs.hold > 0 then
    util_xs.hold = 0
    UtilXsBar(0)
  end
  if util_xs.open then
    util_xs.showT = util_xs.showT - dt
    if util_xs.showT <= 0 then
      UtilXsClose()
    end
  end
end

local util_xs_prev_setup = OnSetupLayer
function OnSetupLayer(a1, a2)
  if a1 == UTIL_XS_GUIDE then             -- the retail setup of the Y guide, with the X glyph and the Utilities label
    local glyph = funcLuaCommand(@crc:CMND_TEXT_GET@, UTIL_XS_GLYPH, 0)
    funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, a1, UTIL_XS_TEXT_GUIDE, UtilXsText(), a2)
    funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, a1, UTIL_XS_TEXT_BTN, type(glyph) == "string" and glyph or "<CMD_FUNC4>", a2)
    funcLuaMenuCommand(541357333, a1, UTIL_XS_BAR, 0, a2)
    funcLuaMenuCommand(1595998683, a1, UTIL_XS_BAR, 0, 0, a2)
    return
  end
  return util_xs_prev_setup(a1, a2)
end

local util_xs_prev_open_guide = OpenButtonGuideUI
function OpenButtonGuideUI(a1)
  local r = util_xs_prev_open_guide(a1)
  local ok, ready = pcall(UtilXsReady)
  if ok and ready then
    pcall(UtilXsOpen)
  end
  return r
end

local util_xs_prev_reset = ResetSkippedState
function ResetSkippedState(...)
  util_xs.busy = false
  util_xs.hold = 0
  pcall(funcLuaMenuCommand, 3842369982, UTIL_XS_GUIDE)
  UtilXsBar(0)
  util_xs.open = false
  return util_xs_prev_reset(...)
end

local util_xs_prev_step = Step
function Step()
  local r = util_xs_prev_step()
  local ok, err = pcall(UtilXsStep)
  if not ok then
    UTIL_XS.Log("step error", tostring(err))
  end
  return r
end
