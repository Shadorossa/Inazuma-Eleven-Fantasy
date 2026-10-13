-- menu_engine: INPUT TRACE (VR-Framework 2.2, 2026-10-12, diagnostics; docs/app/contact-map-fichajes-2026-10-12.md §6-7).
-- Definitions + wrappers only (this file runs in every menu VM, lua\_all); the trace is installed from the VM's first
-- OnInit / Step (the engine registers funcLuaCommand / funcLuaMenuCommand after the chunk), never at load.
--
-- Owner, 2026-10-12: after leaving any shop page the hub under it takes no input (no key reaches its Lua). Every Lua
-- call that switches a menu's input is logged with the VM that sent it, so the unbalanced one shows in loader.log:
--   «VRFW input <vm> f<frame> <what> <args>»
-- MENU_ACTIVE (menu, on), the layer input switch 2171393651 (layer, on), the ctrl focus 3518307824 (layer, on), the
-- free cursor 1951894516 (on), the cursor control 1813741958 (on), the virtual-mouse cursor 879521569, menu hide /
-- show (369172623 / 66378409), open / close of a menu, and the shop's temp flag 939384271. A call repeating the last
-- one of the same kind in the VM is not logged again; at most VRFW_INPUT_TRACE.MAX lines per VM.
--
-- 2.2.25 (round 6: every Lua switch was balanced, the hub still got no key): the engine's own input owners. Each frame
-- CMenuController (vtable slot 3, 0x54D8F0 -> 0x5510A0) gives the pad only to the entries of its input list with the
-- highest priority; an entry whose menu is gone is dropped there. For 60 s after a VM starts and after it makes its
-- menu active again (the return from a child screen), every 60 frames the VM asks the framework's script for that list
-- (CMND_VRFW_MENU_INPUT_DUMP, scripts\menu_input.lua: menu crc, priority, order, alive, the menu's active byte) and
-- logs it when it changed: «VRFW input owners <vm> f<frame> <list>». A menu still listed above the hub is the owner of
-- the dead input. The same window also logs our layers drawn in the screen's top-left corner (the dark box over the
-- header): «VRFW input topleft <vm> f<frame> <layer> <idx> <gx> <gy>; ...».
-- VRFW_INPUT_TRACE.on = false switches it off.
if VRFW_INPUT_TRACE == nil then
  local T = {on = true, MAX = 400, n = 0, frame = 0, last = {}, installed = false, vm = "?",
    watch = 0, WATCH = 3600, EVERY = 60, owners = nil, corner = nil,
    DUMP = 3276827605 --[[CMND_VRFW_MENU_INPUT_DUMP]], GPOS = 4002164178, IS_VISIBLE = 1262717583, LAYER_NUM = 1175615627,
    CORNER = {"evt_topbar_back", "evt_topbar_plate", "evt_topbar_icon", "evt_topbar_hint", "evt_topbar_drop_plate",
      "evt_topbar_drop_icon", "evt_topbar_drop_label", "util_fr_back", "util_fr_plate", "util_fr_icon", "util_fr_face",
      "util_fr_text", "vrfw_cm_bust", "vrfw_cm_busticon", "mainmenu01_10_return_arrow_button_guide"},
    MENU = {[1558704558] = "menu_active", [2171393651] = "layer_input", [3518307824] = "ctrl_focus",
      [1951894516] = "free_cursor", [879521569] = "virtual_mouse", [369172623] = "menu_hide", [66378409] = "menu_show",
      [438207617] = "input_ctrl", [2515285936] = "input_switch", [3694710990] = "finalize_menu"},
    CMD = {[1813741958] = "cursor_control", [320421347] = "close_menu", [433545986] = "open_menu",
      [3964465990] = "temp_flag", [2515285936] = "input_switch", [2770980979] = "pause_input"},
    ring = {}, RING = 50}
  VRFW_INPUT_TRACE = T

  function T.Log(what, ...)
    local args = {}
    for i = 1, select("#", ...) do
      args[#args + 1] = tostring((select(i, ...)))
    end
    local sig = table.concat(args, ",")
    -- 2.2.74: the last RING calls of this VM, every one (the freeze watchdog dumps them)
    T.ring[#T.ring + 1] = "f" .. T.frame .. " " .. what .. "(" .. sig .. ")"
    if #T.ring > T.RING then
      table.remove(T.ring, 1)
    end
    local key = T.frame .. "|" .. sig
    if T.last[what] == key then
      return
    end
    T.last[what] = key
    if T.n >= T.MAX then
      return
    end
    T.n = T.n + 1
    pcall(T.raw_cmd, 3661580131, "VRFW input", T.vm, "f" .. T.frame, what, sig)
  end

  -- the engine's input owners (logged when they changed) and our layers in the top-left corner
  function T.Watch(owners_only)
    local ok, list = pcall(T.raw_cmd, T.DUMP)
    if ok and type(list) == "string" and list ~= T.owners then
      T.owners = list
      local G = VRFW_TopBarGuard
      local okh, has = pcall(T.raw_cmd, 2947612279, 3672361613 --[[evt_top_bar_nav]])
      pcall(T.raw_cmd, 3661580131, "VRFW input owners", T.vm, "f" .. T.frame, list, "guard off",
        tostring(type(G) == "table" and G.off), "nav param", tostring(okh and has))
    end
    if owners_only or type(CRC32) ~= "function" then
      return
    end
    local hits = {}
    for _, name in ipairs(T.CORNER) do
      local layer = CRC32(name)
      local okn, n = pcall(T.raw_menu, T.LAYER_NUM, layer)
      if okn and type(n) == "number" then
        for idx = 0, math.min(n, 128) - 1 do
          local okv, v = pcall(T.raw_menu, T.IS_VISIBLE, layer, idx)
          if okv and v == true then
            local okp, gx, gy = pcall(T.raw_menu, T.GPOS, layer, idx)
            if okp and type(gx) == "number" and type(gy) == "number" and gx < 400 and gy > -250 then
              hits[#hits + 1] = name .. " " .. idx .. " " .. math.floor(gx) .. " " .. math.floor(gy)
            end
          end
        end
      end
    end
    local s = table.concat(hits, "; ")
    if s ~= (T.corner or "") then
      T.corner = s
      pcall(T.raw_cmd, 3661580131, "VRFW input topleft", T.vm, "f" .. T.frame, s ~= "" and s or "none")
    end
  end

  function T.Install()
    if T.installed or type(funcLuaCommand) ~= "function" or type(funcLuaMenuCommand) ~= "function" then
      return
    end
    T.installed = true
    local p = type(EVT_PATCH) == "table" and EVT_PATCH.script or nil
    T.vm = type(p) == "string" and p or "?"
    T.stem = (T.vm:gsub("_%d+%.%d+%.%d+[%.%d]*$", ""))
    local raw_menu, raw_cmd = funcLuaMenuCommand, funcLuaCommand
    T.raw_cmd = raw_cmd
    T.raw_menu = raw_menu
    funcLuaMenuCommand = function(c, ...)
      local what = T.on and T.MENU[c] or nil
      if what ~= nil then
        pcall(T.Log, what, ...)
        if c == 1558704558 and select(2, ...) == true then
          T.watch = T.WATCH                      -- a menu made active again: watch its input for 60 s
          if T.inactive and T.CURSOR_RESET[T.stem or ""] then
            T.cr = 0                             -- 2.2.59: the device-mode reset below
          end
          T.inactive = false
        elseif c == 1558704558 and select(2, ...) == false then
          T.inactive = true
        end
      end
      return raw_menu(c, ...)
    end
    funcLuaCommand = function(c, a, ...)
      local what = T.on and T.CMD[c] or nil
      if what ~= nil and (c ~= 3964465990 or a == 939384271) then
        pcall(T.Log, what, a, ...)
      end
      return raw_cmd(c, a, ...)
    end
    T.watch = T.WATCH
    if T.WD.STEMS[T.stem or ""] ~= nil then
      pcall(T.WdCallbacks)                     -- 2.2.74: the freeze watchdog counts this VM's input callbacks
    end
    -- 2.2.29: Step wrapped again here (OnInit runs after every patch of the script: a stem patch that redefined Step
    -- after lua\_all dropped the first wrapper, so the market's trace stayed at frame 0 and never watched)
    if not T.ticking and type(Step) == "function" then
      local step = Step
      Step = function(...)
        return T.Wrapped(step, ...)
      end
    end
    pcall(T.Log, "trace on")
  end

  -- one tick per engine Step call, however many of our wrappers are in its chain
  function T.Wrapped(step, ...)
    T.ticking = true
    if T.in_step then
      return step(...)
    end
    T.in_step = true
    pcall(T.Tick)
    local r = table.pack(pcall(step, ...))
    T.in_step = false
    if not r[1] then
      error(r[2], 0)
    end
    return table.unpack(r, 2, r.n)
  end

  -- 2.2.59 (owner: after a shop the Mercado / the office list stays dead until the stick and another device are
  -- switched quickly, then works): the engine's device mode (the stick's virtual mouse, CMND_SET_ENABLE_FREE_CURSOR_FOR
  -- _VIRTUAL_MOUSE 879521569, which retail market_menu turns on when it opens: (true, false, true)) is reset once when
  -- the hub makes itself active again after a child: off two frames later, on (retail arguments) two frames after
  -- that, what a device switch does by hand. Hubs where retail uses it: CURSOR_RESET (crc-free stems). Logged once per
  -- return: «VRFW input <vm> cursor reset».
  T.CURSOR_RESET = {market_menu = true, soccer_vs_cpu_list_menu = true}
  function T.CursorReset()
    if T.cr == nil then return end
    T.cr = T.cr + 1
    if T.cr == 2 then
      pcall(T.raw_menu, 879521569, false, false, true)
    elseif T.cr == 4 then
      -- 2.2.74: the normal menu controller first (a shop's 3D model view leaves MENU_CTRL_SEPARATE_CROSS_KEY selected;
      -- docs/app/contact-map-fichajes-2026-10-12.md section 23), then the retail virtual mouse, which may select
      -- MENU_CTRL itself
      pcall(T.raw_menu, 438207617 --[[CMND_CHANGE_MENU_INPUT_CTRL]], 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]])
      pcall(T.raw_menu, 879521569, true, false, true)
      pcall(T.raw_cmd, 3661580131, "VRFW input", T.vm, "f" .. T.frame, "cursor reset")
      T.cr = nil
    end
  end

  -- 2.2.74 FREEZE WATCHDOG (shop freeze, intermittent). In the Mercado, the office hub and the shop page: a VM whose
  -- menu should have the input (open, not closing, no child window / shop / hub / plate over it, no fade) that sees
  -- Accept / Back pressed on the device (CMND_VRFW_INPUT_PAD / _KEY) WD.PRESSES times over at least WD.SPAN frames with
  -- none of its input callbacks (OnFunction, OnDecideFocus, OnEnter, OnBack, OnChangeFocus) is frozen. Then, at most
  -- once every WD.GAP frames and WD.MAX times per VM: a state dump (lines «VRFW freeze watchdog ...»: the reason, the
  -- engine's input owners + the selected menu controller and its input switch, the menus open / closing, the fade,
  -- the last 50 input calls of this VM), and a recovery: the normal controller (MENU_CTRL_WITH_ANALOG_MOVE_FOCUS) with
  -- its input switch on, MENU_ACTIVE(menu, true), the list's ctrl focus, the virtual-mouse reset. Log «freeze
  -- watchdog: recovered». T.WD.on = false switches it off.
  T.WD = {on = true, PRESSES = 3, SPAN = 120, GAP = 600, MAX = 5, n = 0, last = -100000, cb = 0, cb_name = "none",
    presses = 0, first = nil, held = {},
    STEMS = {market_menu = {menu = 839500579, list = 536841765},
      soccer_vs_cpu_list_menu = {menu = 1970579282}, shop_menu_buy = {menu = 3170360552, list = 2569990914}},
    -- menus that legitimately take the input from the watched one
    OVER = {[839500579] = {3170360552, 713974531, 1970579282, 449578137, 968210065, 1427722143, 1355292071},
      [1970579282] = {3170360552, 449578137, 968210065, 1427722143},
      [3170360552] = {449578137, 968210065, 1427722143}},
    NAMES = {[839500579] = "market_menu", [1970579282] = "soccer_vs_cpu_list_menu", [3170360552] = "shop_menu",
      [713974531] = "shop_menu_basara_top", [449578137] = "general_window", [968210065] = "sub_window",
      [1427722143] = "personal_plate_menu", [1355292071] = "vrfw_contact_map_menu"},
    -- {name, pad bit, Windows key}: Accept and Back
    KEYS = {{"enter", 0x4000, 0x0D}, {"back", 0x2000, 0x1B}}}

  function T.WdCallbacks()
    local W = T.WD
    for _, name in ipairs({"OnFunction", "OnDecideFocus", "OnEnter", "OnBack", "OnChangeFocus"}) do
      local f = _G[name]
      if type(f) == "function" then
        _G[name] = function(...)
          W.cb = T.frame
          W.cb_name = name
          W.presses, W.first = 0, nil
          return f(...)
        end
      end
    end
  end

  function T.WdDevice(k)
    local okp, held = pcall(T.raw_cmd, 2864033604 --[[CMND_VRFW_INPUT_PAD]])
    if okp and type(held) == "number" and held >= 0 and math.floor(held / k[2]) % 2 == 1 then
      return true
    end
    local okk, v = pcall(T.raw_cmd, 3182184968 --[[CMND_VRFW_INPUT_KEY]], k[3])
    return okk and v == true
  end

  function T.WdOpen(m)
    local ok, e = pcall(T.raw_menu, 2231168902 --[[CMND_IS_EXIST_MENU_OBJECT]], m)
    return ok and e == true
  end

  -- the watched menu should have the input now
  function T.WdEligible(S)
    if not T.WdOpen(S.menu) then
      return false
    end
    local okc, closing = pcall(T.raw_cmd, 1193349555 --[[CMND_IS_CLOSING_MENU_OBJECT]], S.menu)
    if okc and closing == true then
      return false
    end
    for _, m in ipairs(T.WD.OVER[S.menu] or {}) do
      if T.WdOpen(m) then
        return false
      end
    end
    local okf, fade = pcall(T.raw_cmd, 1215256347 --[[CMND_BRIGHT_IS_FADE]])
    return not (okf and fade == true)
  end

  function T.WdLog(...)
    pcall(T.raw_cmd, 3661580131, "VRFW freeze watchdog", T.vm, "f" .. T.frame, ...)
  end

  function T.WdDump(S, why)
    local W = T.WD
    T.WdLog("FROZEN", why)
    local ok, list = pcall(T.raw_cmd, T.DUMP)
    T.WdLog("owners / controller", ok and tostring(list) or "n/a")
    local menus = {}
    for m, name in pairs(W.NAMES) do
      if T.WdOpen(m) then
        local okc, closing = pcall(T.raw_cmd, 1193349555, m)
        menus[#menus + 1] = name .. ((okc and closing == true) and " closing" or " open")
      end
    end
    local okf, fade = pcall(T.raw_cmd, 1215256347)
    local okl, lf = pcall(T.raw_menu, 102308320 --[[CMND_IS_CTRL_FOCUS_ACTIVE]], S.list or 0)
    T.WdLog("menus: " .. (#menus > 0 and table.concat(menus, ", ") or "none") .. " | fade " .. tostring(okf and fade)
      .. " | list focus " .. tostring(okl and lf) .. " | last callback " .. W.cb_name .. " at f" .. W.cb
      .. " | MENU_ACTIVE(false) last " .. tostring(T.inactive))
    for i = 1, #T.ring, 10 do
      T.WdLog("last calls " .. i .. "-" .. math.min(i + 9, #T.ring) .. ": "
        .. table.concat(T.ring, "; ", i, math.min(i + 9, #T.ring)))
    end
  end

  function T.WdRecover(S)
    pcall(T.raw_menu, 438207617 --[[CMND_CHANGE_MENU_INPUT_CTRL]], 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]])
    local okw, was = pcall(T.raw_cmd, 4001406493 --[[CMND_VRFW_MENU_INPUT_CTRL_ON]])
    pcall(T.raw_menu, 1558704558 --[[MENU_ACTIVE]], S.menu, true)
    if S.list ~= nil then
      pcall(T.raw_menu, 3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS]], S.list, true)
    end
    T.cr = 0                                   -- the virtual-mouse reset (CursorReset: off, then on)
    local okc, ctrl = pcall(T.raw_cmd, 2250140554 --[[CMND_VRFW_MENU_INPUT_CTRL]])
    T.WdLog("freeze watchdog: recovered", "input switch was " .. tostring(okw and was), "now " .. tostring(okc and ctrl))
  end

  function T.WdTick()
    local W = T.WD
    local S = W.STEMS[T.stem or ""]
    if S == nil or not W.on or not T.installed or W.n >= W.MAX then
      return
    end
    local press = false
    for _, k in ipairs(W.KEYS) do
      local on = T.WdDevice(k)
      if on and not W.held[k[1]] then
        press = true
      end
      W.held[k[1]] = on
    end
    if not press then
      return
    end
    if not T.WdEligible(S) then
      W.presses, W.first = 0, nil
      return
    end
    -- a callback in the 3 frames after the press resets the count (W.cb is set by the callback wrappers)
    W.presses = W.presses + 1
    W.first = W.first or T.frame
    if W.presses >= W.PRESSES and T.frame - W.first >= W.SPAN and T.frame - W.last >= W.GAP
        and T.frame - W.cb > T.frame - W.first then
      W.n, W.last = W.n + 1, T.frame
      local why = W.presses .. " Accept / Back presses in " .. (T.frame - W.first) .. " frames, no input callback"
      W.presses, W.first = 0, nil
      pcall(T.WdDump, S, why)
      pcall(T.WdRecover, S)
    end
  end

  function T.Tick()
    T.frame = T.frame + 1
    if T.cr ~= nil then
      pcall(T.CursorReset)
    end
    if T.WD.on then
      pcall(T.WdTick)
    end
    if not T.installed then
      pcall(T.Install)
    end
    if T.on and T.watch > 0 then
      T.watch = T.watch - 1
      if T.watch % T.EVERY == 0 then
        pcall(T.Watch)
      end
    end
  end

  local init = OnInit
  if type(init) == "function" then
    OnInit = function(...)
      pcall(T.Install)
      return init(...)
    end
  end
  local step = Step
  if type(step) == "function" then
    Step = function(...)
      return T.Wrapped(step, ...)
    end
  end
  -- the same entry points as VRFW_Host handlers (2.2.29): in a host script (shop_menu_buy, soccer_vs_cpu_list_menu...)
  -- a lua_early merged file redefines OnInit / Step after lua\_all and the wrappers above never run; the host's
  -- dispatchers call these. The handler ticks only where no Step wrapper of ours ever ran.
  local VH = VRFW_Host
  local p = type(EVT_PATCH) == "table" and EVT_PATCH.script or nil
  local stem = type(p) == "string" and p:gsub("_%d+%.%d+%.%d+[%.%d]*$", "") or nil
  if type(stem) == "string" and type(VH) == "table" and type(VH.on) == "function" then
    pcall(VH.on, stem, "OnInit", {id = "vr_framework.input_trace_init", phase = "before", fn = function(...)
      pcall(T.Install)
    end})
    pcall(VH.on, stem, "Step", {id = "vr_framework.input_trace_step", phase = "after", fn = function(r, ...)
      if not T.ticking then
        pcall(T.Tick)
      end
    end})
  end
end
