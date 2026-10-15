-- VRFW_MATCH_EXIT: the menu side of the flow toggle match_exit = "black_to_menu" (scripts\flow.lua, docs/framework/flow.md §1.1).
-- Leaving an offline match with the game's hold prompts («Finalizar partido» in the pause or at the end of the match)
-- fades the screen to black (bright-fade layer 1) and asks the framework to HOLD it there (CMND_VRFW_MATCH_EXIT_COVER:
-- the detour Flow.ExitCover keeps the layer black through the game's own fade-ins). The match-end transition, the
-- loading and the menus the game passes through are not seen; the menu the game lands on fades in once.
--   * match VMs (they define UpdateGameEndProgress / UpdateGameRetireProgress): the hold gauge reaching full asks for
--     the cover (only if a mod declared the toggle for this play mode, offline);
--   * every menu VM whose OnInit runs under the cover, outside a match, is a landing candidate: once its layers stopped
--     opening for LAND_QUIET Steps it releases the cover and fades layer 1 in. A menu that routes on to another one by
--     itself sets VRFW_MATCH_EXIT.route (its stem patch); VRFW_MATCH_EXIT.manual = true leaves the landing to its stem
--     patch (VRFW_MATCH_EXIT.land(why));
--   * every such VM asks the framework every POLL Steps: a cover held too long is released there and faded in.
-- Wraps global functions (and OnInit through VRFW_Host too); no engine call at load time.
VRFW_MATCH_EXIT = VRFW_MATCH_EXIT or {}
do
  local X = VRFW_MATCH_EXIT
  if not X.wrapped then
    X.wrapped = true
    local C = {
      COVER = 2007754216,      -- CMND_VRFW_MATCH_EXIT_COVER(op, arg)
      MODE = 3507337950,       -- CMND_VRFW_MODE_CURRENT -> key, id, play mode, in match, …
      FADE = 609722083,        -- (alpha, seconds, layer): the bright fade
      LOG = 3661580131,        -- CMND_EVT_LOG
    }
    local LAYER = 1            -- the bright-fade layer of the cover (layer 0 stays the game's)
    local FADE_OUT_S = 0.3     -- the fade to black when the hold gauge is full
    local FADE_IN_S = 0.3      -- the fade in on the landing menu
    local LAND_QUIET = 6       -- Steps with no layer opening: the landing menu is open
    local LAND_MAX = 240       -- Steps a landing candidate waits for its first layer before it lands anyway
    local POLL = 30            -- Steps between two expiry checks

    local script = type(EVT_PATCH) == "table" and EVT_PATCH.script or nil
    X.stem = type(script) == "string" and (script:gsub("_%d+%.%d+%.%d+[%.%d]*$", "")) or "?"
    X.armed, X.born, X.done = false, false, false
    X.route = X.route or false
    X.manual = X.manual or false
    local steps, last_open, inited = 0, nil, false

    local function log(...)
      pcall(funcLuaCommand, C.LOG, "VRFW match_exit", tostring(X.stem), ...)
    end
    X.log = log

    local function fade_in()
      pcall(funcLuaCommand, C.FADE, 0, FADE_IN_S, LAYER)
    end

    -- match VM: the hold gauge of a «Finalizar partido» prompt is full
    function X.arm(why)
      if X.armed then return end
      X.armed = true
      local okm, _, _, mode = pcall(funcLuaCommand, C.MODE)
      if not okm then mode = nil end
      local ok, yes, why_not = pcall(funcLuaCommand, C.COVER, 2, mode)
      if not ok or yes ~= 1 then
        log("match left (" .. why .. "): no cover", tostring(ok and why_not or yes))
        return
      end
      pcall(funcLuaCommand, C.FADE, 1, FADE_OUT_S, LAYER)
      local okh, held, why_held = pcall(funcLuaCommand, C.COVER, 1, mode)
      if okh and held == 1 then
        log("match left (" .. why .. "): fade to black, cover held", "play mode " .. tostring(mode))
      else
        fade_in()
        log("match left (" .. why .. "): cover not held, faded back", tostring(okh and why_held or held))
      end
    end

    -- landing menu: the cover off and one fade in (true when this VM released it)
    function X.land(why)
      if X.done or not X.born then return false end
      local ok, r, why_not = pcall(funcLuaCommand, C.COVER, 0, X.stem)
      if not ok then
        X.done = true
        return false
      end
      if r == 1 then
        X.done = true
        fade_in()
        log("landed (" .. tostring(why) .. "): cover released, fade in")
        return true
      end
      if why_not == "not held" then X.done = true end
      return false
    end

    local function init_check()
      if inited then return end
      inited = true
      local ok, st, in_match = pcall(funcLuaCommand, C.COVER, -1, X.stem)
      if not ok then return end
      if st == 2 then
        X.done = true
        fade_in()
        log("cover held too long: released, fade in")
      elseif st == 1 and in_match ~= true then
        X.born = true
      end
    end

    local function opened()
      if X.born and not X.done then last_open = steps end
    end

    local function step()
      if not X.born or X.done then return end
      steps = steps + 1
      if steps % POLL == 0 then
        local ok, st = pcall(funcLuaCommand, C.COVER, -1, X.stem)
        if ok and st == 2 then
          X.done = true
          fade_in()
          log("cover held too long: released, fade in")
          return
        elseif ok and st == 0 then
          X.done = true          -- released elsewhere
          return
        end
      end
      if X.manual or X.route then return end
      if last_open ~= nil then
        if steps - last_open >= LAND_QUIET then X.land("layers open") end
      elseif steps >= LAND_MAX then
        X.land("no layer opened")
      end
    end

    -- after the global `name` (when the script defines it), `after(...)` runs in pcall with its arguments
    local function wrap(name, after)
      local f = rawget(_ENV, name)
      if type(f) ~= "function" then return false end
      rawset(_ENV, name, function(...)
        local r = table.pack(f(...))
        pcall(after, ...)
        return table.unpack(r, 1, r.n)
      end)
      return true
    end

    local function gauge(why)
      return function(now, need)
        if type(now) == "number" and type(need) == "number" and need > 0 and now >= need then X.arm(why) end
      end
    end
    wrap("UpdateGameEndProgress", gauge("end of match prompt"))
    wrap("UpdateGameRetireProgress", gauge("pause prompt"))
    wrap("OnInit", init_check)
    wrap("OnOpenLayer", opened)
    wrap("Step", step)
    local VH = VRFW_Host
    if X.stem ~= "?" and type(VH) == "table" and type(VH.on) == "function" then
      pcall(VH.on, X.stem, "OnInit", { id = "vr_framework.match_exit", phase = "after", fn = function(r, ...)
        init_check()
      end })
    end
  end
end
