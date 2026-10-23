-- Utilities: «Cambiar forma» (view forms), the button that cycles the forms of the character a menu shows (Normal,
-- Miximax, Armour...; the list is the VR-Framework's form viewer, CMND_VRFW_FORM_LIST). Moved from Inazuma Fantasy on
-- 2026-10-14 (owner: «coge de IF el botón RS de cuando estás viendo a un personaje y ponlo en utilities»; IF's player
-- page R3 «Formas» and the «Ver apariencia» form viewer, graft form_view). docs/game/mechanics/form-viewer.md §8.
--
-- * The key: Utilities' input action BetterQoL.ViewForms.Cycle (content\inputs\view_forms.toml): command
--   CMD_UTIL_VIEW_FORMS on MENU_CTRL, MENU_CTRL_WITH_ANALOG_MOVE_FOCUS and MENU_CTRL_SEPARATE_CROSS_KEY (the controller
--   of «Ver apariencia»), default RS (R3) / G, rebindable in the game's «Configuración de controles» (tab «Controles
--   básicos»). Its glyph: the markup <CMD_UTIL_VIEW_FORMS> (text row utilities_view_forms), the bound button.
-- * Where it applies: DATA. The menu host «utilities.view_forms» (content\menus\view_forms.toml) lists the menus; a mod
--   adds its own with an [[entry]] of that host: `menus = ["<script stem>"]` and `action = { lua = "<global function>" }`
--   (called on each press in those menus, with the entry; return value ignored). Utilities' own entry: the retail
--   «Ver apariencia» of the team dock (team_dock_formation_menu, graft util_view_forms). Inazuma Fantasy's: its player
--   page (personal_plate_menu, IF menus\102_team\view_forms.toml).
-- * Run time: this file (every menu VM) registers one VRFW_Host «after» handler on the VM's own stem (PostStep, else
--   Step); the menu needs a VRFW_Host host (research/mods/VRFW/assets/lua/menu/<stem>/000_host.lua). Its first call
--   reads the host's entries (VRFW_Menu.entries); a VM no entry names goes idle. Then each frame: the command on the
--   three controllers, one call per press (edge + 8 frames).
-- * For other mods' game Lua (mod.toml [exports] game_lua): BetterQoL.ViewForms.Declared(stem), .Down(stem) (the
--   action fired this frame in a declared menu: for code that polls by itself), .Forms(hdl) (forms, their sources),
--   .GLYPH, .COMMAND.
-- Only one Utilities RS action per menu: the technique preview's (Utilities' «Previsualizar» on the move card) is never
-- declared here, and a menu declared here must not be one of its menus.
-- Defines functions and tables; no engine call at chunk load.
BetterQoL = type(BetterQoL) == "table" and BetterQoL or {}
BetterQoL.ViewForms = type(BetterQoL.ViewForms) == "table" and BetterQoL.ViewForms or {}
do
  local VF = BetterQoL.ViewForms
  VF.HOST = "utilities.view_forms"
  VF.COMMAND = 44460916 --[[CMD_UTIL_VIEW_FORMS]]
  VF.GLYPH = "<CMD_UTIL_VIEW_FORMS>"
  VF.GLYPH_TEXT = 508024922 --[[menu_text utilities_view_forms = <CMD_UTIL_VIEW_FORMS>]]
  VF.CTRLS = {1332654303 --[[MENU_CTRL]], 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]],
    3526778166 --[[MENU_CTRL_SEPARATE_CROSS_KEY]]}
  VF.CHECK = 4265778440 --[[CMND_CHECK_INPUT_CMD (ctrl, command)]]
  VF.FORM_LIST = 2188689660 --[[CMND_VRFW_FORM_LIST (hdl) -> n, form1..formN]]
  VF.LOG = 3661580131 --[[CMND_EVT_LOG]]
  VF.GUARD = 8
  -- per VM state
  VF.vm = VF.vm or {stem = nil, loaded = false, entries = {}, was = false, tick = 0, last = -100}

  local function Log(...)
    pcall(funcLuaCommand, VF.LOG, "Utilities view_forms", ...)
  end

  -- the entries of the host that name `stem` (read once per VM, inside a callback)
  local function Load()
    local S = VF.vm
    if S.loaded then
      return S.entries
    end
    S.loaded = true
    S.entries = {}
    if type(VRFW_Menu) ~= "table" or type(VRFW_Menu.entries) ~= "function" or S.stem == nil then
      return S.entries
    end
    local ok, list = pcall(VRFW_Menu.entries, VF.HOST)
    if not ok or type(list) ~= "table" then
      return S.entries
    end
    for _, e in ipairs(list) do
      local menus = type(e.menus) == "string" and e.menus or ""
      for m in menus:gmatch("[^,]+") do
        if m == S.stem then
          S.entries[#S.entries + 1] = e
          break
        end
      end
    end
    if #S.entries > 0 then
      local keys = {}
      for _, e in ipairs(S.entries) do
        keys[#keys + 1] = tostring(e.key) .. " -> " .. tostring(e.value)
      end
      Log(S.stem, table.concat(keys, "; "))
    end
    return S.entries
  end

  -- a global function by name ("Name" or "A.B")
  local function Resolve(name)
    if type(name) ~= "string" then
      return nil
    end
    local v = _G
    for part in name:gmatch("[^.]+") do
      if type(v) ~= "table" then
        return nil
      end
      v = rawget(v, part)
    end
    return type(v) == "function" and v or nil
  end

  -- is `stem` (this VM's script) one of the declared menus?
  function VF.Declared(stem)
    local S = VF.vm
    if stem ~= nil and stem ~= S.stem then
      return false
    end
    return #Load() > 0
  end

  -- the action's command fired this frame on one of its controllers (raw, no edge)
  function VF.Pressed()
    for _, c in ipairs(VF.CTRLS) do
      local ok, v = pcall(funcLuaCommand, VF.CHECK, c, VF.COMMAND)
      if ok and v == true then
        return true
      end
    end
    return false
  end

  -- for code that polls by itself: the action fired this frame AND `stem` is a declared menu of this VM
  function VF.Down(stem)
    return VF.Declared(stem) and VF.Pressed()
  end

  -- the forms of a character handle, in the cycle order ({0} = only Normal, or no form viewer); 2nd value: each form's
  -- source (the board slot it comes from, «-» for Normal; the framework answers it after the forms, for logs); 3rd:
  -- whether the framework's form viewer answered at all (false = CMND_VRFW_FORM_LIST is not registered)
  function VF.Forms(hdl)
    local r = {pcall(funcLuaCommand, VF.FORM_LIST, hdl)}
    local t, src = {}, {}
    local answered = r[1] == true and type(r[2]) == "number"
    if answered then
      local n = r[2]
      for i = 1, n do
        if type(r[i + 2]) == "number" then
          t[#t + 1] = r[i + 2]
          local s = r[n + i + 2]
          src[#src + 1] = type(s) == "string" and s or "?"
        end
      end
    end
    if #t == 0 then
      t[1], src[1] = 0, "-"
    end
    return t, src, answered
  end

  -- each frame of a VM: one call of the declared actions per press
  function VF.Tick()
    local S = VF.vm
    S.tick = S.tick + 1
    if S.loaded and #S.entries == 0 then
      return
    end
    if #Load() == 0 then
      return
    end
    local p = VF.Pressed()
    local edge = p and not S.was
    S.was = p
    if not edge or S.tick - S.last < VF.GUARD then
      return
    end
    S.last = S.tick
    for _, e in ipairs(S.entries) do
      local f = Resolve(e.value)
      if f ~= nil then
        local ok, err = pcall(f, e)
        if not ok then
          Log("action failed", tostring(e.key), tostring(err))
        end
      end
    end
  end

  -- registration on this VM's stem (the queue when the framework's VRFW_Host is not there yet: Utilities is lua_early)
  local p = type(EVT_PATCH) == "table" and EVT_PATCH.script or nil
  local stem = type(p) == "string" and p:gsub("_%d+%.%d+%.%d+[%.%d]*$", "") or nil
  if type(stem) == "string" and VF.vm.stem == nil then
    VF.vm.stem = stem
    local point = type(rawget(_G, "PostStep")) == "function" and "PostStep" or "Step"
    local spec = {id = "utilities.view_forms_tick", phase = "after", fn = function()
      pcall(VF.Tick)
    end}
    local H = VRFW_Host or EVT_Host
    if type(H) == "table" and type(H.on) == "function" then
      pcall(H.on, stem, point, spec)
    else
      VRFW_HOST_Q = VRFW_HOST_Q or {}
      table.insert(VRFW_HOST_Q, {"on", stem, point, spec})
    end
  end
end
