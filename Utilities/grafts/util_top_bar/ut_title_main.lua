-- Utilities top bar, title_main side (graft util_top_bar). The title's press must reach title_main while it
-- reads requests: title_menu_2's mode row is ready well before title_main gets there (Load -> WaitFade -> Start ->
-- InputEnable -> InputWait), and a press in between is dropped (InputEnable makes the title active again and its
-- request is never read; Inazuma Fantasy's 07/10 logs). Param utilities_title_ready = 1 from the moment title_main
-- reads requests; ut_title.lua presses only then (title_menu_2's OnInit clears it). Globals only.
Utilities = type(Utilities) == "table" and Utilities or {}
Utilities.TopBar = type(Utilities.TopBar) == "table" and Utilities.TopBar or {}
Utilities.TopBar.READY_KEY = 3292329527 --[[crc32 utilities_title_ready]]

do
  local wait = SwitchCaseTitleInputWait
  if type(wait) == "function" then
    function SwitchCaseTitleInputWait(...)
      pcall(function()
        if funcLuaCommand(2947612279, Utilities.TopBar.READY_KEY) then
          funcLuaCommand(3363400568, Utilities.TopBar.READY_KEY)
        end
        funcLuaCommand(3860611758, Utilities.TopBar.READY_KEY, 0, 1, 1)
      end)
      return wait(...)
    end
  end
end

-- No white flash (Clean HUD 1.12.1, Nacho 2026-10-08). A shortcut reaches the title in black (the reset's black fade,
-- then ut_title.lua keeps it black) and presses the mode's button there; the title's step to the mode
-- (SwitchCaseTitleFade) then starts the retail WHITE fade 4011714927(1, 0.3). The engine has ONE full-screen fade
-- (colour + alpha, docs/game/ui/modes-hub.md §5): a white fade started on a black screen turns it white at once, the
-- next mode loads under white and fades in from it (the flash). The retail hub buttons go black -> black. So while the
-- screen is already fully black (2259183189 covered, 3249777136(0) black), that one call becomes the black fade
-- 609722083 with the same arguments: nothing changes on screen and the next menu fades in from black (retail top
-- menus fade in with the colour they find). A press on a visible title (retail) keeps the white fade. Inazuma
-- Fantasy's graft modes_hub does the same (EVT_MH_TitleIsBlack, mh_title_main.lua): when it is there, this wrapper
-- leaves the call to it.
function Utilities.TopBar.TitleIsBlack()
  return funcLuaCommand(2259183189) == true and funcLuaCommand(3249777136, 0) == true
end

do
  local fade = SwitchCaseTitleFade
  if type(fade) == "function" then
    function SwitchCaseTitleFade(...)
      if type(EVT_MH_TitleIsBlack) == "function" then
        return fade(...)
      end
      local ok, black = pcall(Utilities.TopBar.TitleIsBlack)
      if not ok or not black then
        return fade(...)
      end
      local cmd = funcLuaCommand
      funcLuaCommand = function(id, ...)
        if id == 4011714927 --[[white fade]] then
          return cmd(609722083 --[[black fade]], ...)
        end
        return cmd(id, ...)
      end
      local r = table.pack(pcall(fade, ...))
      funcLuaCommand = cmd
      if not r[1] then
        error(r[2], 0)
      end
      return table.unpack(r, 2, r.n)
    end
  end
end

-- Fast title for a top bar shortcut (Clean HUD 1.14.3, Nacho 2026-10-08; docs/game/ui/top-bar-direct-jump.md §6). While
-- a shortcut is in flight (the framework's param evt_top_bar_busy, set at the click, cleared by the destination hub's
-- top bar init: Clean HUD's and Inazuma Fantasy's hand-offs alike) the title is black and takes no input, so its timed
-- waits are skipped by moving title_main's state (main-chunk local n16, VRFW_Host.hosts.title_main.L):
--   WaitFade (state 3: the 1 s fade-in of the title + its production wait n21) -> Start (4); Start, InputEnable and
--   InputWait run as retail (the press is read by the retail InputWait, ut_title.lua / mh_title.lua press it there);
--   EndFadeInit (7: the production wait n22 after a press) -> Fade (8), whose white fade is already the black one.
-- Normal title entries (no shortcut) are untouched. If the locals are not reachable (no EVT_DEBUG / map), or n16 is
-- not the state expected, the retail function runs (the old path) and the reason is logged once. Timings: the
-- loader.log lines «go …» (click), «… reset» (10_top_bar.lua), «fast title …» (here), «hand-off» / «press»
-- (ut_title.lua or IF's mh_title.lua) and the destination's «init» line.
Utilities.TopBar.FAST = {BUSY = 1149663763 --[[crc32 evt_top_bar_busy]], noted = false}

function Utilities.TopBar.FastLog(...)
  pcall(funcLuaCommand, 3661580131 --[[CMND_EVT_LOG]], "utilities top_bar fast title", ...)
end

-- the main-chunk locals of title_main, or nil (logged once)
function Utilities.TopBar.FastL()
  local F = Utilities.TopBar.FAST
  if funcLuaCommand(2947612279, F.BUSY) ~= true then
    return nil
  end
  local h = type(VRFW_Host) == "table" and type(VRFW_Host.hosts) == "table" and VRFW_Host.hosts.title_main or nil
  local L = h ~= nil and h.L or nil
  local ok, n = false, nil
  if L ~= nil then
    ok, n = pcall(function() return L.n16 end)
  end
  if not ok or type(n) ~= "number" then
    if not F.noted then
      F.noted = true
      Utilities.TopBar.FastLog("locals not reachable (no VRFW_Host title_main L / EVT_DEBUG): retail waits kept")
    end
    return nil
  end
  return L, n
end

do
  local function skip(name, expect, to)
    local f = _G[name]
    if type(f) ~= "function" then
      return
    end
    _G[name] = function(...)
      local L, n = Utilities.TopBar.FastL()
      if L ~= nil then
        if n == expect then
          local ok = pcall(function() L.n16 = to end)
          if ok then
            Utilities.TopBar.FastLog(name, "skipped", "state", expect, "->", to)
            return false
          end
          Utilities.TopBar.FastLog(name, "could not write the state: retail")
        else
          Utilities.TopBar.FastLog(name, "state", n, "not", expect, ": retail")
        end
      end
      return f(...)
    end
  end
  skip("SwitchCaseTitleWaitFade", 3, 4)
  skip("SwitchCaseTitleEndFadeInit", 7, 8)
end
