-- menu_engine: top bar shortcuts. Runs in every script VM (lua\_all) but only acts in a
-- menu whose setting has the layer `evt_topbar_icon` (a mod adds it with a [[patch]] add_layer, next to the shared
-- header mainmenu90_01_header), plus the title (title_menu_2: the deferred hand-off below). There, while the header is
-- open (CMND_IS_OPEN_MENU_OBJECT: a funcLuaCommand id), the host's gate (if any) says yes and the entries' atlases are
-- in, the entries of the host `top_bar` ([[entry]] host = "top_bar") are drawn as a row of icons at the RIGHT edge of
-- the header bar; picking one goes back to the title with the retail reset and the title opens that mode (the
-- title hand-off a mod declares, [top_bar_title]).
--
-- Layers (added only, never a retail object swapped): evt_topbar_plate (hover / current plates) and evt_topbar_icon
-- (the glyphs), both cmn01_10_new_icon quads placed by Lua (align left / top, POS (x, -y) in screen px).
-- Draw order: the bar's layers (row, hint, dropdown) are above anything of any hub (TB.PRIO, 1006-1012, applied again
-- each time the row shows); the row hides while a screen fade runs.
-- Input:
--   pointer  mouse or VR's free cursor (the stick-driven virtual mouse: it moves the pointer without the engine's «mouse
--            moved» flag, so a position change counts too): hover = highlight, LEFT CLICK = go (MENU_CTRL command
--            CMD_EVT_MOUSE_LEFT: the mouse button alone; declared by the mod in inputs\), or Accept / the free cursor's A
--            (CMD_ENTER_CLICK) while the pointer leads and rests on an icon. A menu arrow gives the lead back to the keys.
--   D-pad    UP on the menu's top-most element (UP that moves no focus within NAV_WAIT frames, or that wraps the focus to
--            a lower element: the wrap is undone) puts the focus in the bar: the current mode's icon, else the icon
--            nearest in x to the element. The menu is set inactive meanwhile (MENU_ACTIVE false: it sees none of the
--            bar's keys). LEFT / RIGHT = previous / next icon (no wrap, as the retail button rows), A / Enter = go,
--            DOWN or B = back to the element it came from (the menu is reactivated once that key is released).
--   open     the open button (`open` hosts): CMD_VRFW_TOPBAR_OPEN, the rebindable action a mod declares (e.g.
--            «Abrir accesos directos» in the game's «Configuración de controles», default L3 / N; its glyph hint left of
--            the row) = into the bar on the current mode's icon; again, DOWN or B = out. None declared: LS / N read
--            from the devices.
--   pad / kb TAP / HOLD of CMD_EVT_TOPBAR_ON (held state; no mod declares it) = highlight the next
--            icon / go to the highlighted one.
-- Host rules: the mods declare them per menu (`[[top_bar_host]]` in their menus TOML: gate, leave, session, dpad, open,
-- open_yield, rank_centre, standalone, variants, open_hold, active_only; old names r3 / r3_yield / r3_hold), read at OnInit with CMND_VRFW_MENU_TOPBAR_HOST; this file names no menu of any mod. The
-- header's rank plate (its layer, the header node it hangs from, the centred x, the row edge that avoids it) is the
-- `[top_bar_rank]` the framework / a mod declares (same command, after the host rules).
-- The state plates (evt_tb_hover / evt_tb_current / evt_tb_back) come from the atlas the mod that styles the bar
-- declares (`[VRFW.TopBarStyle] PlatesAtlas`, the command's last value); none: the first icon's atlas, with a WARN.
-- Leaving a host (path in the log, «go … path …»):
--   direct   (OFF: TB.DIRECT = false) an entry with `action.direct`: params, auto-save, fade, the next state written as the title would and
--            the retail reset with the title skipped (CMND_VRFW_MENU_TOPBAR_DIRECT): the target opens with nothing in
--            between (ResetDirect); refused = the title round trip below
--   reset    the default: params, auto-save, fade, the Mercado's reset to the title (GoCo)
--   leave    the host's own `leave` function (a global of its VM) instead of the retail reset
--   session  a host over an overlay save session (`session = true`): its `leave` closes the session first; the target
--            waits in param evt_top_bar_defer and the title (this file, title_menu_2 VM) resets into it once no
--            session and no `session` host menu is left
-- The title hand-off (which param the title reads, the focus item / param of `focus` actions, stale params to clear) is
-- the `[top_bar_title]` a mod declares (CMND_VRFW_MENU_TOPBAR_TITLE); without one `title` / `focus` actions are refused.
-- Groups: an entry `action = { group = "<key>" }` is one icon in the bar whose dropdown
-- (under it, while the icon is hovered / has the pad focus) shows the entries that declare `group = "<key>"`, any mod's,
-- by their order, as ONE HORIZONTAL ROW OF ICONS without labels, centred under the group's icon and
-- kept on screen; a group with no entry left (blocked, mode off) is not shown. Pad: DOWN (or A) on the group = into the
-- dropdown on its first icon, LEFT / RIGHT = previous / next icon of the dropdown (no wrap), A = go, UP or B = back to
-- the group's icon (dropdown closed). Mouse: hover opens it; icon + gap + panel are one hover region (the icon under
-- the pointer lit, a click on it goes); off it the dropdown closes after DROP_GRACE frames, at once on a click
-- outside, Esc / B or another icon. Layers evt_topbar_drop_plate (panel, focused-icon highlight) and
-- evt_topbar_drop_icon (the icons); the styling mod's label objects (global VRFW_TopBarDropLabel) are kept hidden
-- (called with on = false). A host without those layers shows no group.
-- Badges: global VRFW_TopBarBadges[<entry key>] = {tex = <menu path>, sprite = <name>} set by a mod in
-- the same VM marks that entry's icon (a dot at its top-right corner, plate instance MAX); nil = no badge.
-- Safety: refused (buzzer) while a message window is open, a fade runs, the game saves, a reserved slot's game (a mod's
-- mode, CMND_VRFW_SLOT_RESERVED) is in memory outside its session host, another shortcut is in flight, or the icon is
-- the current mode (its `menus` exist). Engine calls only from OnInit / Step / layer callbacks (nothing at chunk load).
if VRFW_TopBar == nil then
  local TB = {
    Y = 34, SIZE = 46, CELL_K = 1.55, GAP = 6, RIGHT = 1892, PLATE = 60, -- row geometry (screen px; fits a short header bar of 67 px)
    HOVER_SCALE = 1.06,                                  -- the highlighted icon grows a little (Windows-like: subtle)
    HOLD = 42, SEL_FRAMES = 300, CHECK_EVERY = 6, MAX = 8,   -- MAX: set at Init from the layer count
    NAV_WAIT = 4,                                        -- frames an UP may take to move the menu's focus
    -- diagnostics (loader.log «EVT top_bar <menu> dbg …»): first Step, the raw header-open answer, the texture wait,
    -- once per menu open every entry's quad (pos, size, visible, GPOS read back), the pointer, the D-pad focus moves.
    DEBUG = false,   -- release the «dbg» lines of loader.log only with true
    TEX_MIN = 10, TEX_MAX = 600,                         -- frames: texture wait before the first draw
    DEFER_MAX = 3600,                                    -- title: frames a deferred target may wait, then dropped
    -- the straight reset (`action.direct`): CMND_GAME_RESET wipes the loaded game (the rpg scene's exit) and only
    -- the title scene reads the slot back, so the bar keeps the game in memory first (CMND_VRFW_SLOT_CARRY, save
    -- engine) and the new rpg scene's InitState loads it back before it opens the target (the «alineaciones vacías» bug). false = every `title` entry takes the title round trip.
    DIRECT = true,
    -- a group's dropdown, one row of icons: cell width (at least; a wide icon gets a wider cell), cell height,
    -- icon height, inner margin, gap under the bar, icons at most; the screen width and the margin the panel keeps
    DROP_CELL = 60, DROP_H = 56, DROP_ICON = 38, DROP_PAD = 6, DROP_GAP = 4, DROP_MAX = 6,
    SCREEN_W = 1920, SCREEN_MARGIN = 8,
    DROP_GRACE = 15,                                     -- frames (~250 ms) the pointer may be off icon + dropdown
    dsel = nil, dshut = false, has_drop = false, xs = {}, ws = {}, drop_drawn = false, drop_out = nil,
    on = false, menu = nil, entries = {}, shown = false, sel = nil, sel_t = 0, held = 0, mouse = false,
    px = nil, py = nil, prev = {},  -- last pointer position read; command -> pressed last frame (edges)
    co = nil, frame = 0, wrapped = false, logn = 0, cur = {}, block = false,
    tex_ready = false, tex_t = 0, dbg_open = nil, dbg_steps = 0, dbg_gpos = false, dbg_ptr = false,
    -- D-pad: the menu's focus as last seen (OnChangeFocus / the focus-set command), the bar focus, the pending UP
    has_back = false, back_on = false,
    fev = 0, flayer = nil, fidx = nil, nav = false, nav_from = nil, up = nil, release = nil, self_focus = false,
    defer_t = 0, right = 1892, rank_log = false,
    -- draw priorities (the layers' 2D order across every open menu; not a material priority, so the <= 30 limit of
    -- models / effects does not apply). The bar, its dropdown and its hint are above anything
    -- of any hub (retail tops out at 999 focus arrows / badges and 1000 pointers; only the recommended-training window
    -- 1103 / 1104 and the tutorial fade 9999 are higher). The objects are declared with these numbers by the styling
    -- mod (its PRIO table); they are applied again each time the row shows (Raise), so a layer a
    -- menu's Lua re-prioritised, or a host whose objects another mod declared, still ends on top. Layer name -> prio.
    PRIO = {evt_topbar_back = 1006, evt_topbar_plate = 1007, evt_topbar_icon = 1008, evt_topbar_hint = 1009,
            evt_topbar_drop_plate = 1010, evt_topbar_drop_icon = 1011, evt_topbar_drop_label = 1012},
    raised = false, fading = false,
  }
  VRFW_TopBar = TB
  EvtTopBar = TB   -- 1.x name

  local L_ICON, L_PLATE = 430410954 --[[evt_topbar_icon]], 458408972 --[[evt_topbar_plate]]
  local L_BACK = 301818918 --[[evt_topbar_back: the glass strip of a standalone row]]
  local L_DPLATE = 2234308820 --[[evt_topbar_drop_plate: instance 0 the dropdown's panel, 1 the row highlight]]
  local L_DICON = 53409741 --[[evt_topbar_drop_icon: the dropdown's row icons]]
  local L_DLABEL = 4195704679 --[[evt_topbar_drop_label: the row labels (the styling mod's object; hidden at setup)]]
  local HEADER = 575058101            -- mainmenu90_01_header
  -- the header's rank plate ([top_bar_rank], read at OnInit into TB.rank): its layer (plate), the header node it hangs
  -- from (node). The header skeleton is shared by every menu, so the plate keeps its place and only the hosts with
  -- `rank_centre` move the node at runtime (node translation to the declared header-local `centre_x`). Hosts without it
  -- keep the plate where it is and the row ends at `avoid_right`. Nothing declared: the plate is ignored.
  local NODE_POS = 2575768773         -- (layer, idx, node, axis 0 x / 1 y, value): node local translation
  local NODE_QUAD = 1909474081        -- icon_new01 (the cmn01_10 quad's sprite node)
  local MESH_QUAD = 312193881         -- its mesh (CMND_SET_PRIM_COLOR)
  local Q = 36                        -- cmn01_10 quad size
  local C = {
    LOG = VRFW_Cmd.EVT_LOG, LAYER_NUM = VRFW_Cmd.GET_CREATE_LAYER_NUM, DRAW_PRIO = VRFW_Cmd.SET_DRAW_PRIORITY --[[CMND_SET_DRAW_PRIORITY (layer, idx, prio, children)]], IS_OPEN = VRFW_Cmd.IS_OPEN_MENU_OBJECT, EXISTS = VRFW_Cmd.IS_EXIST_MENU_OBJECT,
    VISIBLE = VRFW_Cmd.SET_LAYER_VISIBLE, SCALE = VRFW_Cmd.SET_LAYER_LOCAL_SCALE, POS = VRFW_Cmd.SET_LAYER_LOCAL_POS, SPRITE = 558735651, PRIM_COLOR = VRFW_Cmd.SET_PRIM_COLOR,
    LOAD_TEX = VRFW_Cmd.LOAD_MENU_RES_TEXTURE, TEX_LOADING = 1506186496,
    CHECK_INPUT = VRFW_Cmd.CHECK_INPUT_CMD, MENU_CTRL = 1332654303, ANALOG_CTRL = 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]],
    KEY = 423089863 --[[CMD_EVT_TOPBAR_ON]],
    OPEN = 4165572102 --[[CMD_VRFW_TOPBAR_OPEN: the bar's open button, a mod's rebindable input action, e.g. L3 / N]],
    INPUT_ACTION = VRFW_Cmd.VRFW_INPUT_ACTION --[[CMND_VRFW_INPUT_ACTION (command or action id) -> the action's declaration]],
    CLICK = 218912913 --[[CMD_EVT_MOUSE_LEFT]], MOVED = 3272825600, POINTER = 558229292, GPOS = 4002164178,
    ENTER_CLICK = 1651523701 --[[CMD_ENTER_CLICK: mouse, Enter, A]], ENTER = 1981080283 --[[CMD_ENTER: Enter, A]],
    CANCEL = 3602695835 --[[CMD_CANCEL: Esc, B]],
    UP = 1197218715, DOWN = 3259546669, LEFT = 2765147006, RIGHT = 2075023265,
    FOCUS_SET = 1778826357 --[[(layer, idx, on): the control focus on / off an element (retail ChangeFocusToNextLayer)]],
    SE = VRFW_Cmd.SND_PLAY_SE, SE_GO = 766561556 --[[sy0080]], SE_NO = 2086672038 --[[sy0003]], SE_MOVE = 3848881948,
    SE_BACK = 202039849 --[[sy0006]],
    MENU_ACTIVE = 1558704558, MSG_BUSY = 898725220, IS_FADE = VRFW_Cmd.BRIGHT_IS_FADE, SAVE_WORKING = 1979970074,
    SESSION = VRFW_Cmd.VRFW_SESSION_STATE, SLOT_ACTIVE = VRFW_Cmd.VRFW_SLOT_ACTIVE,
    SLOT_RESERVED = VRFW_Cmd.VRFW_SLOT_RESERVED,
    TB_HOST = {VRFW_Cmd.VRFW_MENU_TOPBAR_HOST, VRFW_Cmd.VRFW_MENU_TOPBAR_HOST},
    TB_TITLE = {VRFW_Cmd.VRFW_MENU_TOPBAR_TITLE, VRFW_Cmd.VRFW_MENU_TOPBAR_TITLE},
    AUTO_SAVE = VRFW_Cmd.SYSTEM_AUTO_SAVE, FADE = 609722083, FADE_DONE = 2259183189, BUSY = 2736534827,
    GAME_RESET = VRFW_Cmd.GAME_RESET,
    CARRY = VRFW_Cmd.VRFW_SLOT_CARRY,
  }
  C.NAV = {C.UP, C.DOWN, C.LEFT, C.RIGHT}
  -- the focus look of a menu element (input guard): control focus queries, the Focus animation, the cursor locator
  C.CTRL_FOCUS_ACTIVE = VRFW_Cmd.IS_CTRL_FOCUS_ACTIVE --[[CMND_IS_CTRL_FOCUS_ACTIVE (layer)]]
  C.FOCUS_INDEX = 2603265800 --[[(layer) -> the focused instance]]
  C.LAYER_EXISTS = VRFW_Cmd.IS_EXIST_LAYER --[[CMND_IS_EXIST_LAYER (layer)]]
  C.PLAY_ANIME = VRFW_Cmd.PLAY_ANIME_TYPE --[[CMND_PLAY_ANIME_TYPE (layer, idx, type, state, set)]]
  C.ATTACH_TRACE = VRFW_Cmd.SET_LAYER_ATTACH_LOCATOR_TRACE --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE (layer, idx, locator, on)]]
  C.ANIME_FOCUS, C.ANIME_SET_BUTTON = 2734777837 --[[Focus]], 973515837 --[[button]]
  C.LOCATOR_CURSOR = 3313461902 --[[cursor]]
  -- The game pad / keyboard read straight from the devices (CMND_VRFW_INPUT_PAD / _KEY) for the bar's own commands, in `standalone` hosts only (the open button did not enter the
  -- bar in the Chronicle board's pause menu). Those menus open over a screen that is no menu hub (the route board, the
  -- free walk): there CMND_CHECK_INPUT_CMD(MENU_CTRL, …) answers false in the menu's own VM (as in the plate during a
  -- session), so neither the open button nor the bar's arrows / A / B
  -- were seen. The rows: the open action's DEFAULT binding (CMND_VRFW_INPUT_ACTION at OnInit: pad mask 1 << pad index,
  -- the letter key's virtual key; a rebinding made in the game's controls screen is not seen there), else LS 0x2 / N;
  -- the retail MENU_CTRL commands: pad masks of vr_sigs::input (D-pad 0x10 / 0x20 / 0x40 / 0x80, B 0x2000, A 0x4000),
  -- Windows virtual keys (the arrows, Enter, Esc). When no mod declares the open action (CMD_VRFW_TOPBAR_OPEN) the
  -- devices are read for the open button on every host (LS / N): the bar's fallback.
  C.PAD, C.VKEY = VRFW_Cmd.VRFW_INPUT_PAD, VRFW_Cmd.VRFW_INPUT_KEY
  C.DEV = {
    [C.OPEN] = {pad = 0x2, vk = {0x4E}}, [C.UP] = {pad = 0x10, vk = {0x26}}, [C.RIGHT] = {pad = 0x20, vk = {0x27}},
    [C.DOWN] = {pad = 0x40, vk = {0x28}}, [C.LEFT] = {pad = 0x80, vk = {0x25}},
    [C.ENTER] = {pad = 0x4000, vk = {0x0D}}, [C.CANCEL] = {pad = 0x2000, vk = {0x1B}},
  }
  local K = {
    BUSY = 1149663763,      -- evt_top_bar_busy: a shortcut is in flight (any VM)
    TARGET = 837786837,     -- evt_top_bar_target: crc32(entry key) of the shortcut in flight (a mod's screen may go deeper)
    STEP = 3366268333,      -- evt_top_bar_step: how many steps of that entry's `path` were taken (VRFW_TopBarStep)
    DEFER = 3408963264,     -- evt_top_bar_defer: title item for the title once the session is closed (path session)
    DIRECT = 1469556327,    -- evt_top_bar_direct: a straight reset is in flight (the landing menu logs it, then clears it)
    NAV = 3672361613,       -- evt_top_bar_nav: the bar has the focus (heartbeat: a counter the host bumps every frame)
    HIDE = 1455983968,      -- vrfw_top_bar_hidden: a screen plays something full screen over the hub (a mod's scene
                            -- over the menus): the row is not drawn and takes no input while the param is set
  }
  -- the title hand-off a mod declares ([top_bar_title]; read at OnInit): go = param the title reads (the item to press),
  -- box / item = the focus param and the title item of `focus` actions, clear = stale params, session = the session hosts
  local TT = {known = false, go = nil, box = nil, item = nil, clear = {}, session = {}}
  local BLOCK_MENUS = {968210065 --[[sub_window]]}
  local TITLE = "title_menu_2"

  local function Log(...)
    if TB.logn >= (TB.DEBUG and 200 or 60) then return end
    TB.logn = TB.logn + 1
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    pcall(funcLuaCommand, C.LOG, "EVT top_bar " .. tostring(TB.name) .. " " .. table.concat(p, " "))
  end

  local function Crc(s)
    local n = tonumber(s)
    if n ~= nil then return n end
    return CRC32(s)
  end

  local function P(k, v)
    if k == nil then return end                       -- a hand-off param no mod declared
    if VRFW_Param.Has(k) then VRFW_Param.Clear(k) end
    if v ~= nil then VRFW_Param.Set(k, v) end
  end

  -- clear these params (nil = not declared: skipped; a plain loop, ipairs would stop at the first nil)
  local function Clear(...)
    for i = 1, select("#", ...) do P((select(i, ...)), nil) end
  end

  local function Take(k)
    return VRFW_Param.Take(k)
  end

  -- the menu this VM runs, from the script stem the loader gives the patch files ("soccer_top_menu_1.03.98.00")
  local stem = type(EVT_PATCH) == "table" and EVT_PATCH.script or nil
  if type(stem) == "string" then
    TB.name = stem:gsub("_%d+%.%d+%.%d+[%.%d]*$", "")
  end
  TB.host = {}

  -- a top bar rule command: the core's name first, then the engine's (the first that answers)
  local function Rules(ids, ...)
    for _, id in ipairs(ids) do
      local r = table.pack(pcall(funcLuaCommand, id, ...))
      if r[1] and r[2] ~= nil then return table.unpack(r, 2, r.n) end
    end
    return nil
  end

  local function Nums(s)
    local out = {}
    for n in tostring(s or ""):gmatch("[^,%s]+") do out[#out + 1] = tonumber(n) end
    return out
  end

  -- this menu's rules ([[top_bar_host]]) and the title hand-off ([top_bar_title]); OnInit only
  local function LoadRules()
    local known, gate, leave, session, dpad, open, rank_centre, standalone, rplate, rnode, rcx, ravoid, open_yield,
      variants, open_hold, active_only, plates = Rules(C.TB_HOST, TB.name or "")
    TB.host = {}
    -- [VRFW.TopBarStyle] PlatesAtlas: the atlas of the state plates, declared by the mod that styles the bar
    TB.plates_atlas = (type(plates) == "string" and plates ~= "") and plates or nil
    local function nz(v) return (type(v) == "number" and v ~= 0) and v or nil end
    TB.rank = {plate = nz(rplate), node = nz(rnode), centre_x = nz(rcx), avoid = nz(ravoid)}
    if known == true then
      TB.host = {gate = gate ~= "" and gate or nil, leave = leave ~= "" and leave or nil, session = session == true,
                 dpad = dpad ~= false, open = open == true, rank_centre = rank_centre == true,
                 standalone = (standalone ~= nil and standalone ~= "") and CRC32(standalone) or nil,
                 open_yield = Nums(open_yield), variants = Nums(variants),
                 open_hold = (type(open_hold) == "number" and open_hold > 0) and open_hold or 0, active_only = active_only == true}
    end
    -- the open button: the action a mod declares for CMD_VRFW_TOPBAR_OPEN (e.g. a shortcuts action in the
    -- game's controls screen, where the player rebinds it) and its default binding for the device reads; none
    -- declared: the devices' LS / N (TB.open_raw)
    local oka, act = pcall(funcLuaCommand, C.INPUT_ACTION, "CMD_VRFW_TOPBAR_OPEN")
    if oka and type(act) == "table" and act.declared == 1 then
      TB.open_raw = false
      C.DEV[C.OPEN] = {pad = (type(act.pad_mask) == "number" and act.pad_mask > 0) and act.pad_mask or nil,
                       vk = (type(act.vk) == "number" and act.vk > 0) and {act.vk} or {}}
    else
      TB.open_raw = true
      C.DEV[C.OPEN] = {pad = 0x2, vk = {0x4E}}
    end
    if TB.host.open then
      Log("open button", TB.open_raw and "LS / N read from the devices (no action declares CMD_VRFW_TOPBAR_OPEN)"
        or ("action " .. tostring(act.id) .. ", default pad mask " .. tostring(act.pad_mask) .. " vk " .. tostring(act.vk)))
    end
    local tk, go, box, fitem, clear, sess = Rules(C.TB_TITLE)
    TT.known = tk == true
    TT.go = (tk == true and type(go) == "number" and go ~= 0) and go or nil
    TT.box = (type(box) == "number" and box ~= 0) and box or nil
    TT.item = (type(fitem) == "number" and fitem ~= 0) and fitem or nil
    TT.clear, TT.session = Nums(clear), Nums(sess)
  end

  -- the host's own function (a global of this VM) named by a rule: a global name, or a dotted path into a mod's
  -- global table (`<ModPrefix>.TopBarOn`: the mod's own prefix)
  local function HostFn(name)
    if type(name) ~= "string" then return nil end
    local f = _G[name]
    if f == nil and name:find(".", 1, true) then
      f = _G
      for part in name:gmatch("[^%.]+") do
        if type(f) ~= "table" then return nil end
        f = rawget(f, part)
      end
    end
    return type(f) == "function" and f or nil
  end

  -- the VM's menu: the script's menu name, or one of the host's `variants` (settings that share this script, e.g. the
  -- route map's _future / _victory): the one that exists. Until one answers the script's name is used (checked again
  -- on every Refresh); a host without variants is resolved at once.
  local function ResolveMenu()
    if TB.menu_ok then return end
    local vs = TB.host.variants or {}
    if #vs == 0 then TB.menu_ok = true return end
    local cands = {TB.self_crc}
    for _, v in ipairs(vs) do cands[#cands + 1] = v end
    for _, m in ipairs(cands) do
      if funcLuaMenuCommand(C.EXISTS, m) == true then
        TB.menu, TB.menu_ok = m, true
        if VRFW_TopBarGuard ~= nil and VRFW_TopBarGuard.menus ~= nil then VRFW_TopBarGuard.menu = m end
        Log("menu", m, m == TB.self_crc and "(the script's own)" or "(a variant)")
        return
      end
    end
  end

  -- `active_only` hosts: the menu's own Lua wants it active (its last MENU_ACTIVE for itself, kept by the input guard;
  -- none seen = active, the state a menu opens in)
  local function OwnActive()
    if not TB.host.active_only then return true end
    local gd = VRFW_TopBarGuard
    return gd == nil or gd.wish ~= false
  end

  -- the open button stays with a menu of the host's `open_yield` while it exists (a child over the host with its own
  -- action on that button / key, e.g. a squad screen): no entry, no hint there; the icons still work with the mouse
  local function OpenYields()
    for _, m in ipairs(TB.host.open_yield or {}) do
      if funcLuaMenuCommand(C.EXISTS, m) == true then return true end
    end
    return false
  end

  local function SessionOpen()
    local ok, open, _, _, _, _, _, swapped = pcall(funcLuaCommand, C.SESSION)
    return ok and open == true, ok and open == true and swapped == true
  end

  -- one entry of host top_bar (nil = left out: its mode is switched off, or it leads into a blocked mode)
  local function ReadEntry(i)
    local key, text, icon, kind, value, _owner, _vid, menus, steps, group, aspect,
      _ord, _pon, _poff, _fl, _pl, _it, _lk, _lt, _gt, dmenu, dvs, dmode, direct =
      funcLuaCommand(VRFW_Cmd.VRFW_MENU_ENTRY, "top_bar", i)
    if key == nil then return nil end
    -- an entry whose id names a mode switched off ([modes] of a mod's config, CMND_EVT_MODE_ENABLED) is left out
    local id = tostring(key):match("([^%.]+)$")
    local okm, known, mode_on = pcall(funcLuaCommand, VRFW_Cmd.EVT_MODE_ENABLED, id)
    if okm and known == true and mode_on == false then return nil end
    -- a shortcut into a mode the framework blocks (online guard) is left out
    if kind == "title" then
      local okb, blocked = pcall(funcLuaCommand, VRFW_Cmd.VRFW_BLOCKED, value)
      if okb and blocked == true then return nil end
    end
    local e = {key = key, kind = kind, value = value, menus = {}, steps = tostring(steps or ""),
               group = tostring(group or ""), aspect = (type(aspect) == "number" and aspect > 0) and aspect or 1}
    -- `action.direct`: the next state the title would hand the game; the bar resets straight into it
    if direct == true and kind == "title" then
      e.direct = {menu = (type(dmenu) == "number" and dmenu ~= 0) and dmenu or 0, vs = dvs == true,
                  mode = (type(dmode) == "number" and dmode >= 0) and dmode or 0}
    end
    local tex, spr = tostring(icon or ""):match("^(.*):([^:]+)$")
    if tex ~= nil then
      e.tex, e.tex_crc, e.spr = tex, CRC32(tex), CRC32(spr)
    end
    for m in tostring(menus or ""):gmatch("[^,%s]+") do e.menus[#e.menus + 1] = Crc(m) end
    -- the label a dropdown row shows: the entry's text in the game's language (CMND_VRFW_TEXT_GET of its text key)
    if text ~= nil and text ~= "" then
      local okt, t = pcall(funcLuaCommand, VRFW_Cmd.VRFW_TEXT_GET, text)
      e.label = (okt and type(t) == "string" and t ~= "") and t or nil
    end
    return e
  end

  -- the bar's icons in order; a group (kind "group", value = its key) carries its dropdown rows in `items` (the entries
  -- with `group` = that key, in their order). Left out: a second group of the same key (the first declared wins), a
  -- group with no row left or in a host without the dropdown layers, a row whose group no mod declares.
  local function LoadEntries()
    local out = {}
    local ok, n = pcall(funcLuaCommand, VRFW_Cmd.VRFW_MENU_ENTRY_COUNT, "top_bar")
    if not ok or type(n) ~= "number" then return out end
    local bar, rows, groups = {}, {}, {}
    for i = 1, n do
      local e = ReadEntry(i)
      if e ~= nil and e.group ~= "" then
        rows[e.group] = rows[e.group] or {}
        table.insert(rows[e.group], e)
      elseif e ~= nil and e.kind == "group" then
        if groups[e.value] == nil then
          groups[e.value] = e
          bar[#bar + 1] = e
        else
          Log("group", e.value, "declared again by", e.key, ": the first,", groups[e.value].key, ", is kept")
        end
      elseif e ~= nil then
        bar[#bar + 1] = e
      end
    end
    -- an order list a mod declares (global VRFW_TopBarOrder = {"<entry key>", ...}): the listed entries first,
    -- in the list's order (an id no active mod declares is skipped); the rest keep their `order` place after them
    local want = rawget(_G, "VRFW_TopBarOrder")
    if type(want) == "table" then
      local rank = {}
      for i, k in ipairs(want) do if rank[k] == nil then rank[k] = i end end
      local pos = {}
      for i, e in ipairs(bar) do pos[e] = i end
      table.sort(bar, function(a, b)
        local ra, rb = rank[a.key] or (1000 + pos[a]), rank[b.key] or (1000 + pos[b])
        return ra < rb
      end)
    end
    for g, list in pairs(rows) do
      if groups[g] == nil then Log("group", g, "not declared: its", #list, "entries are left out") end
    end
    for _, e in ipairs(bar) do
      if e.kind == "group" then
        local list = rows[e.value] or {}
        e.items = {}
        for k = 1, math.min(#list, TB.DROP_MAX) do e.items[k] = list[k] end
        if #list > TB.DROP_MAX then Log("group", e.value, ":", #list, "entries, the first", TB.DROP_MAX, "are shown") end
        if #e.items == 0 then
          Log("group", e.value, "left out: no entry")
        elseif not TB.has_drop then
          Log("group", e.value, "left out: this menu has no dropdown layers (evt_topbar_drop_icon)")
        else
          out[#out + 1] = e
        end
      else
        out[#out + 1] = e
      end
      if #out >= TB.MAX then break end
    end
    return out
  end

  -- every atlas the row and its dropdowns use (crc32 of the path -> the path)
  local function Atlases()
    local t = {}
    for _, e in ipairs(TB.entries) do
      if e.tex_crc ~= nil then t[e.tex_crc] = e.tex end
      for _, it in ipairs(e.items or {}) do
        if it.tex_crc ~= nil then t[it.tex_crc] = it.tex end
      end
    end
    return t
  end

  -- the row's geometry: every shortcut owns a cell of the same width (CELL = SIZE * CELL_K), right-aligned at the
  -- bar's right edge, GAP between the cells; the icon is centred in its cell (a wide logo is fitted to the cell, aspect
  -- kept: IconSize), the plates and the hit zones are the cell
  local function Layout()
    local n = #TB.entries
    local x = TB.right or TB.RIGHT
    local cell = TB.SIZE * TB.CELL_K
    TB.xs, TB.ws = {}, {}
    for i = n, 1, -1 do
      TB.ws[i], TB.xs[i] = cell, x - cell / 2
      x = x - cell - TB.GAP
    end
  end

  local function X(i)  -- centre x of icon i (1-based)
    if TB.xs[i] == nil then Layout() end
    return TB.xs[i] or (TB.right or TB.RIGHT)
  end

  local function W(i)  -- width of icon i's cell (the same for every shortcut)
    if TB.ws[i] == nil then Layout() end
    return TB.ws[i] or TB.SIZE * TB.CELL_K
  end

  local function IconSize(i)  -- drawn width, height of icon i: SIZE high, a wide logo fitted to the cell (aspect kept)
    local asp = TB.entries[i] and TB.entries[i].aspect or 1
    local w = math.min(TB.SIZE * asp, W(i))
    return w, w / asp
  end

  -- the open dropdown: the group under the selection (nil = none open)
  local function DropGroup()
    local g = TB.sel ~= nil and TB.entries[TB.sel] or nil
    if g == nil or g.kind ~= "group" or TB.dshut then return nil end
    return g
  end

  -- the dropdown's box under group icon gi, one horizontal row of icons: left, top, width, height, cell width. Every
  -- cell is as wide as the widest icon needs (at least DROP_CELL); the panel is centred under the group's icon and
  -- moved back inside the screen (SCREEN_MARGIN) where it would cross an edge.
  local function DropBox(gi)
    local g = TB.entries[gi]
    local count = #g.items
    local cell = TB.DROP_CELL
    for _, it in ipairs(g.items) do cell = math.max(cell, math.ceil(TB.DROP_ICON * (it.aspect or 1)) + 16) end
    local w = count * cell + 2 * TB.DROP_PAD
    local h = TB.DROP_H + 2 * TB.DROP_PAD
    local left = X(gi) - w / 2
    left = math.min(left, TB.SCREEN_W - TB.SCREEN_MARGIN - w)
    left = math.max(TB.SCREEN_MARGIN, left)
    local top = TB.Y + TB.PLATE / 2 + TB.DROP_GAP
    return left, top, w, h, cell
  end

  -- centre x of the dropdown's icon k (1-based) in a box of DropBox
  local function DropCellX(left, cell, k)
    return left + TB.DROP_PAD + (k - 0.5) * cell
  end

  -- the dropdown icon under the pointer (0 = on the open dropdown but on no icon, nil = not on it). The pointer's y is
  -- screen y DOWN (CMND 558229292: «dbg pointer 1869 917»), as TB.Y and the box; GPOS is y up (Pointed negates it).
  -- Pointed negates it too, so moving the mouse down off the group's icon does not close the dropdown before any row.
  local function DropPointed(mx, my)
    local g = DropGroup()
    if g == nil or type(mx) ~= "number" or type(my) ~= "number" then return nil end
    local left, top, w, h, cell = DropBox(TB.sel)
    -- from the bar's bottom edge (the gap under the icon belongs to the dropdown) to the panel's bottom
    if mx < left or mx > left + w or my < TB.Y + TB.PLATE / 2 - 2 or my > top + h then return nil end
    if my < top + TB.DROP_PAD or my > top + h - TB.DROP_PAD then return 0 end
    local k = math.floor((mx - left - TB.DROP_PAD) / cell) + 1
    if k >= 1 and k <= #g.items then return k end
    return 0
  end

  local function Quad(layer, idx, tex, spr, x, y, s, on, h)
    if not on or tex == nil then
      funcLuaMenuCommand(C.VISIBLE, layer, idx, false)
      funcLuaMenuCommand(C.POS, layer, -4000, 4000, 0, idx)
      return
    end
    funcLuaMenuCommand(C.VISIBLE, layer, idx, true)
    funcLuaMenuCommand(C.SCALE, layer, s / Q, (h or s) / Q, 1, idx)
    funcLuaMenuCommand(C.SPRITE, layer, tex, spr, NODE_QUAD, 0, idx)
    funcLuaMenuCommand(C.POS, layer, x, -y, 0, idx)
  end

  -- the open dropdown (or none): panel, focused-icon highlight, the icons side by side. No labels: the styling mod's
  -- label objects stay hidden (VRFW_TopBarDropLabel(menu, i, nil, 0, 0, false, false)).
  local function HideDropLabels()
    local label_fn = _G.VRFW_TopBarDropLabel
    if type(label_fn) ~= "function" then return end
    for k = 1, TB.DROP_MAX do pcall(label_fn, TB.menu, k, nil, 0, 0, false, false) end
  end

  local function DrawDrop(show)
    if not TB.has_drop then return end
    local g = show and DropGroup() or nil
    if g == nil then
      if TB.drop_drawn then
        Quad(L_DPLATE, 0, nil, nil, 0, 0, 0, false)
        Quad(L_DPLATE, 1, nil, nil, 0, 0, 0, false)
        for k = 1, TB.DROP_MAX do Quad(L_DICON, k - 1, nil, nil, 0, 0, 0, false) end
        HideDropLabels()
        TB.drop_drawn = false
      end
      return
    end
    if not TB.drop_drawn then HideDropLabels() end
    TB.drop_drawn = true
    local left, top, w, h, cell = DropBox(TB.sel)
    local middle_y = top + h / 2
    Quad(L_DPLATE, 0, TB.plate_tex, CRC32("evt_tb_back"), left + w / 2, middle_y, w, TB.plate_tex ~= nil, h)
    if TB.dsel ~= nil and TB.plate_tex ~= nil then
      Quad(L_DPLATE, 1, TB.plate_tex, CRC32("evt_tb_hover"), DropCellX(left, cell, TB.dsel), middle_y, cell - 4, true,
        TB.DROP_H - 4)
    else
      Quad(L_DPLATE, 1, nil, nil, 0, 0, 0, false)
    end
    for k = 1, TB.DROP_MAX do
      local it = g.items[k]
      if it ~= nil then
        local icon_h = TB.DROP_ICON * ((TB.dsel == k) and TB.HOVER_SCALE or 1)
        Quad(L_DICON, k - 1, it.tex_crc, it.spr, DropCellX(left, cell, k), middle_y, icon_h * (it.aspect or 1),
          it.tex ~= nil, icon_h)
        local grey = (TB.block or it.cur) and 0.55 or 1
        funcLuaMenuCommand(C.PRIM_COLOR, L_DICON, k - 1, MESH_QUAD, grey, grey, grey)
      else
        Quad(L_DICON, k - 1, nil, nil, 0, 0, 0, false)
      end
    end
  end

  -- what the badges say now (a change redraws the row)
  local function BadgeSig()
    local bs = _G.VRFW_TopBarBadges
    if type(bs) ~= "table" then return "" end
    local t = {}
    for k, b in pairs(bs) do
      if type(b) == "table" then t[#t + 1] = tostring(k) .. "=" .. tostring(b.tex) .. ":" .. tostring(b.sprite) end
    end
    table.sort(t)
    return table.concat(t, ",")
  end

  -- the bar's layers to their TB.PRIO draw priority (every instance, children included), once per showing
  local function Raise()
    TB.raised = true
    local n = 0
    for name, prio in pairs(TB.PRIO) do
      local layer = CRC32(name)
      local ok, cnt = pcall(funcLuaMenuCommand, C.LAYER_NUM, layer)
      if ok and type(cnt) == "number" then
        for idx = 0, cnt - 1 do
          if pcall(funcLuaMenuCommand, C.DRAW_PRIO, layer, idx, prio, true) then n = n + 1 end
        end
      end
    end
    if TB.DEBUG then Log("dbg draw priorities set on", n, "instances") end
  end

  local function Draw()
    TB.badge_sig = BadgeSig()
    -- hidden while a screen fade runs: above everything, the row would otherwise float over the black of a transition
    local show = TB.shown and TB.tex_ready and not TB.fading
    if show and not TB.raised then Raise() end
    local n = #TB.entries
    if TB.has_back then
      -- standalone row: the glass strip behind it (from the left plate edge of icon 1 to the right one of the last)
      local l, r = n > 0 and X(1) - W(1) / 2 or 0, n > 0 and X(n) + W(n) / 2 or 0
      local w = (r - l) + (TB.PLATE - TB.SIZE * TB.CELL_K) + 16
      Quad(L_BACK, 0, TB.plate_tex, CRC32("evt_tb_back"), (l + r) / 2, TB.Y, w, show and TB.back_on and n > 0, TB.PLATE + 12)
    end
    if TB.host.open then
      -- the open button's hint left of the row: drawn by the mod that styles the bar (global VRFW_TopBarHint(menu, x,
      -- y, on): x, y = the hint's centre on screen, on = show it), e.g. the game button glyph of the bound button
      -- that follows the input device; no such function = no hint. Plate instance MAX (the old sprite hint) stays hidden.
      local hint = show and n > 0 and not TB.nav and not TB.open_off
      local hf = _G.VRFW_TopBarHint
      if type(hf) == "function" then
        local okh, err = pcall(hf, TB.menu, (n > 0 and X(1) - W(1) / 2 or TB.RIGHT) - TB.GAP - 17, TB.Y, hint)
        if not okh then Log("hint error", tostring(err)) end
      end
    end
    for i = 1, TB.MAX do
      local e = TB.entries[i]
      local on = show and e ~= nil and e.tex ~= nil
      local idx = i - 1
      if on then
        local sel, cur = TB.sel == i, TB.cur[i] == true
        local sc = sel and TB.HOVER_SCALE or 1
        local iw, ih = IconSize(i)
        Quad(L_ICON, idx, e.tex_crc, e.spr, X(i), TB.Y, iw * sc, true, ih * sc)
        local g = (TB.block and not cur) and 0.55 or 1
        funcLuaMenuCommand(C.PRIM_COLOR, L_ICON, idx, MESH_QUAD, g, g, g)
        local plate = sel and "evt_tb_hover" or (cur and "evt_tb_current" or nil)
        if plate ~= nil and TB.plate_tex ~= nil then
          Quad(L_PLATE, idx, TB.plate_tex, CRC32(plate), X(i), TB.Y, W(i) + TB.PLATE - TB.SIZE * TB.CELL_K, true, TB.PLATE)
        else
          Quad(L_PLATE, idx, nil, nil, 0, 0, 0, false)
        end
      else
        Quad(L_ICON, idx, nil, nil, 0, 0, 0, false)
        Quad(L_PLATE, idx, nil, nil, 0, 0, 0, false)
      end
    end
    -- a badge: a mod of this VM sets VRFW_TopBarBadges[<entry key>] = {tex = <menu path of a loaded
    -- atlas>, sprite = <sprite name>} (nil = none), e.g. a count on an entry.
    -- The first entry of the row with one gets it at its icon's top-right corner, on the spare plate instance MAX.
    local badge = nil
    local bs = _G.VRFW_TopBarBadges
    if show and type(bs) == "table" then
      for i = 1, math.min(n, TB.MAX) do
        local b = bs[TB.entries[i].key]
        if type(b) == "table" and type(b.tex) == "string" and type(b.sprite) == "string" then
          badge = i
          Quad(L_PLATE, TB.MAX, CRC32(b.tex), CRC32(b.sprite), X(i) + W(i) / 2 - 2, TB.Y - TB.SIZE / 2 + 4, 18, true)
          break
        end
      end
    end
    if badge == nil then Quad(L_PLATE, TB.MAX, nil, nil, 0, 0, 0, false) end
    DrawDrop(show)
  end

  -- the game is in a state where leaving for the title is safe
  local function Blocked()
    if funcLuaCommand(C.MSG_BUSY) == true then return "message window" end
    if funcLuaCommand(C.IS_FADE) == true then return "fade" end
    if funcLuaCommand(C.SAVE_WORKING) == true then return "saving" end
    if VRFW_Param.Has(K.BUSY) then return "a shortcut is in flight" end
    -- an overlay session (checked first: its mount answers its storage slot as active too) is left only through a
    -- `session` host's own leave; outside a session, a reserved slot's game (a mod's mode) in memory is refused
    local _, swapped = SessionOpen()
    if swapped then
      if not (TB.host.session and HostFn(TB.host.leave) ~= nil) then
        return "overlay session (leave from its own menu)"
      end
    else
      local ok, act = pcall(funcLuaCommand, C.SLOT_ACTIVE)
      if ok and type(act) == "number" and act > 0 then
        local okr, res = pcall(funcLuaCommand, C.SLOT_RESERVED, act)
        if okr and res == true then return "reserved slot " .. act .. " (no session)" end
      end
    end
    for _, m in ipairs(BLOCK_MENUS) do
      if funcLuaMenuCommand(C.EXISTS, m) == true then return "window menu" end
    end
    return nil
  end

  -- the atlases asked in Init are in (CMND 1506186496 answers true while a texture still loads): no sprite swap before
  local function TexReady()
    if TB.tex_ready then return true end
    TB.tex_t = TB.tex_t + TB.CHECK_EVERY
    local busy = false
    for tc in pairs(Atlases()) do
      local ok, b = pcall(funcLuaCommand, C.TEX_LOADING, tc)
      if ok and b == true then busy = true end
    end
    if TB.plate_tex ~= nil then
      local ok, b = pcall(funcLuaCommand, C.TEX_LOADING, TB.plate_tex)
      if ok and b == true then busy = true end
    end
    if (not busy and TB.tex_t >= TB.TEX_MIN) or TB.tex_t >= TB.TEX_MAX then
      TB.tex_ready = true
      if TB.DEBUG then Log("dbg texture", busy and "still loading after" or "in after", TB.tex_t, "frames") end
    end
    return TB.tex_ready
  end

  -- once per menu open (DEBUG): what every quad got, and where the engine put it (GPOS read back)
  local function DebugDump(tag)
    for i = 1, #TB.entries do
      local e = TB.entries[i]
      local ok, gx, gy = pcall(funcLuaMenuCommand, C.GPOS, L_ICON, i - 1)
      Log("dbg", tag, i, e.key, "idx", i - 1, "pos", X(i), -TB.Y, "visible", TB.shown and TB.tex_ready and e.tex ~= nil,
        "gpos", ok and tostring(gx) or "err", ok and tostring(gy) or "")
    end
  end

  local function Select(i, sound)
    if i == TB.sel then return end
    TB.sel, TB.dsel, TB.dshut = i, nil, false   -- another icon: a dropdown starts closed to its rows, open to view
    TB.sel_t = TB.SEL_FRAMES
    if i ~= nil and sound then funcLuaCommand(C.SE, C.SE_MOVE) end
    Draw()
  end

  -- ---- D-pad focus in the bar ------------------------------------------------------------------------------------
  local function FocusPos(layer, idx)
    if layer == nil then return nil, nil end
    local ok, gx, gy = pcall(funcLuaMenuCommand, C.GPOS, layer, idx or 0)
    if ok and type(gx) == "number" and type(gy) == "number" then return gx, gy end
    return nil, nil
  end

  local function NavEnter(why)
    local pick = nil
    for i = 1, #TB.entries do
      if TB.cur[i] then pick = i end
    end
    local fx = FocusPos(TB.flayer, TB.fidx)
    if pick == nil then
      pick = #TB.entries
      if fx ~= nil then
        local best = nil
        for i = 1, #TB.entries do
          local d = math.abs(X(i) - fx)
          if best == nil or d < best then best, pick = d, i end
        end
      end
    end
    TB.nav, TB.mouse, TB.release, TB.nav_t, TB.open_t = true, false, nil, 0, 0
    TB.nav_from = {layer = TB.flayer, idx = TB.fidx}
    -- no menu sees the bar's keys: the host AND every menu open over it (a child such as Partido libre's list keeps
    -- its own input); each VM's guard (below) suspends its own menu while the heartbeat K.NAV runs
    VRFW_TopBarGuard.Beat(true)
    TB.sel = nil
    Select(pick, true)
    Log("nav enter", why, "icon", pick, "from", tostring(TB.flayer), tostring(TB.fidx), "x", tostring(fx))
  end

  -- back to the menu; its input comes back once `key` is released (the same press never reaches it)
  local function NavLeave(key, why)
    TB.nav, TB.dsel = false, nil
    TB.release = key or 0
    Select(nil, false)
    Log("nav leave", why)
  end

  -- a command of the devices (C.DEV), read only in `standalone` hosts; the pad's held mask once per frame
  local function DevHeld(cmd)
    if TB.host.standalone == nil and not (TB.open_raw and cmd == C.OPEN) then return false end
    local d = C.DEV[cmd]
    if d == nil then return false end
    if TB.pad_frame ~= TB.frame then
      TB.pad_frame = TB.frame
      local ok, held = pcall(funcLuaCommand, C.PAD)
      TB.pad = (ok and type(held) == "number" and held >= 0) and held or 0
    end
    if d.pad ~= nil and math.floor(TB.pad / d.pad) % 2 == 1 then return true end
    for _, vk in ipairs(d.vk or {}) do
      local ok, v = pcall(funcLuaCommand, C.VKEY, vk)
      if ok and v == true then return true end
    end
    return false
  end

  -- `cmd` held: MENU_CTRL (`analog`: also MENU_CTRL_WITH_ANALOG_MOVE_FOCUS), else the devices (standalone hosts)
  local function Held(cmd, analog)
    if funcLuaCommand(C.CHECK_INPUT, C.MENU_CTRL, cmd) == true then return true end
    if analog and funcLuaCommand(C.CHECK_INPUT, C.ANALOG_CTRL, cmd) == true then return true end
    if DevHeld(cmd) then
      if TB.DEBUG and not TB.dbg_dev then
        TB.dbg_dev = true
        Log("dbg device input", cmd, "(MENU_CTRL silent in this menu)")
      end
      return true
    end
    return false
  end

  -- the menu active again (never left inactive): once the leaving key is released, at the latest after 30 frames
  local function NavRelease()
    if TB.release == nil then return end
    TB.release_t = (TB.release_t or 0) + 1
    if TB.release ~= 0 and TB.release_t < 120 and Held(TB.release, true) then
      return
    end
    TB.release, TB.release_t = nil, 0
    if TB.co == nil then
      VRFW_TopBarGuard.Beat(false)   -- every guard gives its menu back the state it wants
      Log("nav menu active again")
    end
  end

  -- an UP that wrapped the menu's focus to a lower element: put it back on the element it left
  local function UndoWrap(old)
    TB.self_focus = true
    pcall(funcLuaMenuCommand, C.FOCUS_SET, TB.flayer, TB.fidx, false)
    pcall(funcLuaMenuCommand, C.FOCUS_SET, old.layer, old.idx, true)
    if type(OnChangeFocus) == "function" then pcall(OnChangeFocus, old.layer, old.idx) end
    TB.self_focus = false
    TB.flayer, TB.fidx = old.layer, old.idx
  end

  local function Refresh()
    -- CMND_IS_OPEN_MENU_OBJECT is a funcLuaCommand id (every retail caller: 332 calls; funcLuaMenuCommand does not
    -- know it and the row never showed: the bug)
    ResolveMenu()
    local raw = nil
    if TB.menu ~= nil then raw = funcLuaCommand(C.IS_OPEN, TB.menu, HEADER) end
    local open = raw ~= nil and raw ~= false and raw ~= 0
    if TB.DEBUG and raw ~= TB.dbg_open then
      TB.dbg_open = raw
      Log("dbg header open (raw)", tostring(raw), "menu", TB.menu, "header", HEADER)
    end
    local back = false
    if not open and TB.host.standalone ~= nil and TB.menu ~= nil then
      local r = funcLuaCommand(C.IS_OPEN, TB.menu, TB.host.standalone)
      open = r ~= nil and r ~= false and r ~= 0
      back = open
    end
    if open and not OwnActive() then open = false end
    -- (a mod's scene played over the menus): the row would stay drawn over the scene
    -- (the hub's header is only hidden there, it stays open). Any VM sets the param (VRFW_TopBarHide below) for as
    -- long as it wants the bar away.
    if open and VRFW_Param.Has(K.HIDE) then open = false end
    if open and TB.host.gate ~= nil then
      local gf = HostFn(TB.host.gate)
      local okg, g = false, nil
      if gf ~= nil then okg, g = pcall(gf) end
      open = okg and g == true
    end
    if back ~= TB.back_on then
      TB.back_on = back
      TB.dbg_gpos = false
    end
    -- the current mode: an icon whose `menus` exist; a group also when one of its rows is (that row is marked too)
    local function IsCur(e)
      for _, m in ipairs(e.menus) do
        if m == TB.menu or m == TB.self_crc or funcLuaMenuCommand(C.EXISTS, m) == true then return true end
      end
      return false
    end
    local cur, rows_changed = {}, false
    for i, e in ipairs(TB.entries) do
      if IsCur(e) then cur[i] = true end
      for _, it in ipairs(e.items or {}) do
        local c = IsCur(it)
        if c ~= (it.cur == true) then rows_changed = true end
        it.cur = c
        if c then cur[i] = true end
      end
    end
    local block = Blocked() ~= nil
    local open_off = TB.host.open == true and OpenYields()
    if open_off ~= (TB.open_off == true) then
      TB.open_off = open_off
      Log("open button", open_off and "left to the menu on top (open_yield)" or "enters the bar again")
    end
    -- the rank plate: centred on the hosts that ask for it (the locator moved again on every check: a header
    -- animation may key it), else the row ends left of it while it is open in this menu
    local right = TB.RIGHT
    local rank = false
    local RK = TB.rank or {}
    if open and RK.plate then
      local r = funcLuaCommand(C.IS_OPEN, TB.menu, RK.plate)
      rank = r ~= nil and r ~= false and r ~= 0
    end
    -- the mod that styles the header may hide the plate while something else takes its place (global
    -- VRFW_TopBarRankHide(menu) -> true, e.g. Clean HUD: the header's team panel is open). Hidden = not drawn (kept
    -- hidden every frame in Poll, an animation may show it again), not centred, the row keeps the bar's right edge.
    local hide = false
    if rank then
      local hf = _G.VRFW_TopBarRankHide
      if type(hf) == "function" then
        local okh, h = pcall(hf, TB.menu)
        hide = okh and h == true
      end
    end
    if hide ~= (TB.rank_hide == true) then
      TB.rank_hide = hide
      if hide then
        -- the plate's own visibility (the menu may hide it itself), given back when the hide ends
        local okv, v = pcall(funcLuaMenuCommand, VRFW_Cmd.IS_LAYER_VISIBLE, RK.plate, 0)
        TB.rank_was = not okv or v ~= false
      elseif RK.plate and TB.rank_was ~= false then
        pcall(funcLuaMenuCommand, C.VISIBLE, RK.plate, 0, true)
      end
      Log("rank plate", hide and "hidden (the header shows something else there)" or "shown again")
    end
    if hide then rank = false end
    if rank and TB.host.rank_centre and RK.node and RK.centre_x then
      pcall(funcLuaMenuCommand, NODE_POS, HEADER, 0, RK.node, 0, RK.centre_x)
      if TB.DEBUG and not TB.rank_log then
        TB.rank_log = true
        local okp, gx, gy = pcall(funcLuaMenuCommand, C.GPOS, RK.plate, 0)
        Log("dbg rank plate centred, gpos", okp and tostring(gx) or "err", okp and tostring(gy) or "")
      end
    elseif rank and RK.avoid then
      right = RK.avoid
    end
    local moved = right ~= TB.right
    if moved then
      TB.right = right
      Layout()
      TB.dbg_gpos = false
      Log("row right edge", right, rank and "(rank plate at its retail place)" or "")
    end
    local was_ready = TB.tex_ready
    local ready = TexReady()
    local fading = open and funcLuaCommand(C.IS_FADE) == true
    local changed = open ~= TB.shown or block ~= TB.block or ready ~= was_ready or moved or open_off ~= (TB.open_drawn == true)
      or rows_changed or BadgeSig() ~= (TB.badge_sig or "") or fading ~= TB.fading
    TB.fading = fading
    TB.open_drawn = open_off
    for i = 1, #TB.entries do
      if (cur[i] == true) ~= (TB.cur[i] == true) then changed = true end
    end
    TB.cur, TB.block = cur, block
    if open ~= TB.shown then
      TB.shown = open
      TB.sel, TB.dsel = nil, nil
      if not open then TB.raised = false end   -- priorities applied again at the next showing
      if not open and TB.nav then NavLeave(0, "header closed") end
      Log(open and "shown" or "hidden", #TB.entries, "texture", TB.tex_ready and "ready" or "loading",
        "standalone", tostring(TB.back_on))
      TB.dbg_gpos = false
    end
    if changed then Draw() end
    if TB.DEBUG and TB.shown and TB.tex_ready and not TB.dbg_gpos then
      TB.dbg_gpos = true
      DebugDump("open")
    end
  end

  -- commands pressed this frame and not the last one (MENU_CTRL, arrows also from the analog table)
  local function Edges()
    local E = {}
    local function one(cmd, analog)
      local now = Held(cmd, analog)
      local was = TB.prev[cmd]
      TB.prev[cmd] = now
      E[cmd] = now and not was
    end
    for _, c in ipairs(C.NAV) do one(c, true) end
    one(C.CLICK) one(C.ENTER_CLICK) one(C.ENTER) one(C.CANCEL) one(C.OPEN)
    return E
  end

  local function Pointed()
    local mx, my = funcLuaMenuCommand(C.POINTER)
    if type(mx) ~= "number" or type(my) ~= "number" then return nil end
    local py = -my
    local half = TB.PLATE / 2
    for i = 1, #TB.entries do
      local gx, gy = funcLuaMenuCommand(C.GPOS, L_ICON, i - 1)
      local hw = (W(i) + TB.PLATE - TB.SIZE * TB.CELL_K) / 2
      if type(gx) == "number" and type(gy) == "number" and math.abs(mx - gx) <= hw and math.abs(py - gy) <= half then
        return i
      end
    end
    return nil
  end

  -- ---- going --------------------------------------------------------------------------------------------------------
  -- the retail reset to the title (the Mercado's own way back); 900 frames later still here = give the screen back
  local function ResetToTitle(save)
    if save then funcLuaCommand(C.AUTO_SAVE) end
    funcLuaCommand(C.FADE, 1, 0.3)
    while not funcLuaCommand(C.FADE_DONE) do coroutine.yield() end
    while funcLuaCommand(C.BUSY) do coroutine.yield() end
    funcLuaMenuCommand(3479138216, 0)
    funcLuaCommand(937976662, true)
    funcLuaCommand(419468738, false)
    funcLuaCommand(1507811093, false)
    Log("reset (the title takes over)")
    funcLuaCommand(C.GAME_RESET)
    for _ = 1, 900 do coroutine.yield() end
    Log("still here 900 frames after the reset: screen and input back")
    Clear(TT.go, TT.box, K.BUSY, K.TARGET, K.DEFER)
    funcLuaCommand(C.FADE, 0, 0.3)
    if TB.menu ~= nil then funcLuaMenuCommand(C.MENU_ACTIVE, TB.menu, true) end
  end

  -- the straight reset (an entry's `action.direct`): the next state written as the
  -- retail title writes it before its Continue (root menu 3479138216 or the VS menu flags, the title's mode value
  -- 3718253404, the title's BGM stop), the game kept in memory (CMND_VRFW_SLOT_CARRY(1): the reset wipes it, the
  -- title would read it back), the retail reset, then CMND_VRFW_MENU_TOPBAR_DIRECT clears the reset's «title next»
  -- byte: the new rpg scene's InitState loads the kept game back and opens the target's state at once (play mode, root
  -- menu), no title scene and no menu in between. Kept game or straight start refused = the title round trip with the
  -- entry's item (`item`); the title reads the slot from its file as on every return.
  local function ResetDirect(e, item)
    local d = e.direct
    funcLuaCommand(C.AUTO_SAVE)
    funcLuaCommand(C.FADE, 1, 0.3)
    while not funcLuaCommand(C.FADE_DONE) do coroutine.yield() end
    while funcLuaCommand(C.BUSY) do coroutine.yield() end
    Log("reset straight into", d.vs and "the VS menu" or tostring(d.menu), "title mode", d.mode)
    -- the auto-save's job done, the game kept in memory, the next state, the reset (VRFW_Reset, 04_reset.lua)
    local straight = VRFW_Reset.straight({ menu = d.menu, vs = d.vs, title_mode = d.mode, bgm_stop = true,
      log = function(text) Log("direct:", text) end }) == "straight"
    if straight then
      P(K.DIRECT, CRC32(e.key))
      Log("direct: no title, the next state opens", tostring(e.key), "(InitState loads the kept slot first)")
    else
      -- the title runs: it reads the slot and presses the entry's item as before (the next state above is rewritten)
      P(TT.go, item)
    end
    for _ = 1, 900 do coroutine.yield() end
    Log("still here 900 frames after the reset: screen and input back")
    Clear(TT.go, TT.box, K.BUSY, K.TARGET, K.DEFER, K.DIRECT)
    funcLuaCommand(C.FADE, 0, 0.3)
    if TB.menu ~= nil then funcLuaMenuCommand(C.MENU_ACTIVE, TB.menu, true) end
  end

  -- leave for the title; the title presses the target (the [top_bar_title] hand-off: param TT.go)
  local function GoCo(e, path)
    P(K.BUSY, 1)
    funcLuaCommand(C.SE, C.SE_GO)
    funcLuaMenuCommand(C.MENU_ACTIVE, TB.menu, false)
    for _, k in ipairs(TT.clear) do P(k, nil) end
    Clear(TT.box, K.DEFER, K.STEP)
    P(K.TARGET, CRC32(e.key))
    local item = Crc(e.value)
    if e.kind == "focus" then
      item = TT.item
      P(TT.box, CRC32(e.value))
    end
    -- a straight reset hands the title nothing (no title runs; a param left for it would be pressed by the next
    -- real title visit)
    if path ~= "direct" then P(path == "session" and K.DEFER or TT.go, item) end
    Log("go", e.key, e.kind, e.value, "path", path, "steps", e.steps ~= "" and e.steps or "-")
    coroutine.yield()
    local leave = HostFn(TB.host.leave)
    if path == "leave" and leave ~= nil then
      -- the host's own exit (it resets to the title its own way)
      leave()
      for _ = 1, 900 do coroutine.yield() end
      Log("leave: still here 900 frames after", TB.host.leave)
      Clear(TT.go, TT.box, K.BUSY, K.TARGET)
      return
    elseif path == "session" and leave ~= nil then
      -- the session host's own leave closes the session; the title runs the deferred target
      P(K.BUSY, nil)
      Log("session: the host leaves the session first; the title opens the target after it is closed")
      leave()
      return
    elseif path == "direct" then
      ResetDirect(e, item)
      return
    end
    ResetToTitle(true)
  end

  -- go to entry e (an icon of the bar or a row of a group's dropdown); cur = it is the current mode
  local function GoEntry(e, cur)
    if e == nil then return end
    local why = Blocked()
    if why == nil and cur then why = "current mode" end
    if why == nil and e.kind ~= "title" and e.kind ~= "focus" and e.kind ~= "lua" then why = "action " .. tostring(e.kind) end
    if why == nil and (e.kind == "title" or e.kind == "focus") and TT.go == nil then why = "no [top_bar_title] hand-off declared" end
    if why == nil and e.kind == "focus" and (TT.item == nil or TT.box == nil) then why = "no focus_item / focus_param in [top_bar_title]" end
    if why ~= nil then
      Log("refused", e.key, why)
      funcLuaCommand(C.SE, C.SE_NO)
      return
    end
    if TB.nav then TB.nav, TB.release = false, nil end
    TB.sel = nil
    -- a mod that can serve the shortcut right here (its screen lives in this menu) registers
    -- VRFW_TopBarHere[<entry key>] = function(entry, menu) -> true; then the title round trip is skipped
    -- («Served in place»). Any other menu (or false / an error) goes the entry's own way.
    local here = rawget(_G, "VRFW_TopBarHere")
    if type(here) == "table" and type(here[e.key]) == "function" then
      local okh, done = pcall(here[e.key], e, TB.name)
      if okh and done == true then
        Log("go", e.key, "served here by", tostring(TB.name))
        return
      end
    end
    if e.kind == "lua" then
      local f = HostFn(e.value)   -- a global, or a dotted name of a mod's table (<ModPrefix>.Panel)
      if type(f) == "function" then pcall(f, e) end
      return
    end
    local path = "reset"
    if HostFn(TB.host.leave) ~= nil then
      if not TB.host.session then
        path = "leave"
      elseif select(2, SessionOpen()) then
        path = "session"
      end
    elseif e.direct ~= nil and e.kind == "title" and TB.DIRECT == true then
      -- an entry that declares its next state (`action.direct`) from a host that leaves the retail way: straight
      -- into it. Hosts with their own `leave` (a free walk's pause, a session) keep their own way out.
      path = "direct"
    end
    VRFW_TopBarGuard.Beat(false)   -- a shortcut ends the bar's focus at once: nothing suspended during the hand-off
    TB.dsel = nil
    TB.co = coroutine.create(GoCo)
    local ok, err = coroutine.resume(TB.co, e, path)
    if not ok then Log("error", err) TB.co = nil end
  end

  local function Go(i)
    local e = TB.entries[i]
    if e == nil or e.kind == "group" then return end   -- a group's icon only opens its dropdown
    GoEntry(e, TB.cur[i])
  end

  -- the dropdown's row k (pad focus / pointer); nil = none
  local function DropSelect(k, sound)
    if k == TB.dsel then return end
    TB.dsel = k
    if k ~= nil and sound then funcLuaCommand(C.SE, C.SE_MOVE) end
    Draw()
  end

  -- ---- per frame ----------------------------------------------------------------------------------------------------
  local function PollNav(E)
    if TB.nav then
      local g = TB.sel ~= nil and TB.entries[TB.sel] or nil
      local grp = g ~= nil and g.kind == "group"
      if TB.dsel ~= nil and grp then
        -- in a group's dropdown (one row of icons): LEFT / RIGHT = previous / next icon (no wrap), UP or B = back to
        -- the group's icon (dropdown closed; DOWN opens it again), DOWN = nothing, A = go, the open button = out
        if E[C.LEFT] then
          if TB.dsel > 1 then DropSelect(TB.dsel - 1, true) end
        elseif E[C.RIGHT] then
          if TB.dsel < #g.items then DropSelect(TB.dsel + 1, true) end
        elseif E[C.UP] then
          TB.dshut = true
          DropSelect(nil)
          Log("nav drop closed (up)")
        elseif TB.host.open and E[C.OPEN] then
          NavLeave(C.OPEN, "open")
        elseif E[C.CANCEL] then
          funcLuaCommand(C.SE, C.SE_BACK)
          TB.dshut = true
          DropSelect(nil)
          Log("nav drop closed (back)")
        elseif E[C.ENTER] then
          local it = g.items[TB.dsel]
          if it ~= nil then GoEntry(it, it.cur) end
        end
        if TB.nav then
          TB.sel_t = TB.SEL_FRAMES
          TB.nav_t = (E[C.UP] or E[C.DOWN] or E[C.LEFT] or E[C.RIGHT]) and 0 or TB.nav_t + 1
          if TB.nav_t > 600 then NavLeave(0, "idle") end
        end
        return true
      end
      if E[C.LEFT] then
        if TB.sel ~= nil and TB.sel > 1 then Select(TB.sel - 1, true) end
      elseif E[C.RIGHT] then
        if TB.sel ~= nil and TB.sel < #TB.entries then Select(TB.sel + 1, true) end
      elseif (E[C.DOWN] or E[C.ENTER]) and grp then
        TB.dshut = false                             -- DOWN (or A) on a group: into its dropdown, first icon
        DropSelect(1, true)
        Log("nav drop", g.value, "icon 1")
      elseif E[C.DOWN] then
        NavLeave(C.DOWN, "down")
      elseif TB.host.open and E[C.OPEN] then
        NavLeave(C.OPEN, "open")
      elseif E[C.CANCEL] then
        funcLuaCommand(C.SE, C.SE_BACK)
        NavLeave(C.CANCEL, "back")
      elseif E[C.ENTER] then
        if TB.sel ~= nil then Go(TB.sel) end
      end
      if TB.nav then
        TB.sel_t = TB.SEL_FRAMES                     -- the bar focus does not fade, but 10 s without a key = back
        TB.nav_t = (E[C.LEFT] or E[C.RIGHT]) and 0 or TB.nav_t + 1
        if TB.nav_t > 600 then NavLeave(0, "idle") end
      end
      return true
    end
    -- `open` hosts: the open button (pad / key) = into the bar (the menu inactive only while there; Esc / B in the bar
    -- never reaches it). `open_hold` hosts: the button held that many frames (a tap stays the menu's own action)
    local hold = TB.host.open_hold or 0
    if TB.host.open and hold > 0 then
      if TB.prev[C.OPEN] and TB.release == nil and TB.co == nil and not OpenYields() then
        TB.open_t = (TB.open_t or 0) + 1
        if TB.open_t == hold then
          TB.up = nil
          NavEnter("open held " .. hold .. " frames")
          return true
        end
      elseif not TB.prev[C.OPEN] then
        TB.open_t = 0
      end
    elseif TB.host.open and E[C.OPEN] and TB.release == nil and TB.co == nil and not OpenYields() then
      TB.up = nil
      NavEnter("open")
      return true
    end
    -- an UP pending: did it move the menu's focus?
    local up = TB.up
    if up ~= nil then
      up.t = up.t + 1
      if TB.fev ~= up.fev then
        TB.up = nil
        local _, ny = FocusPos(TB.flayer, TB.fidx)
        if up.y ~= nil and ny ~= nil and ny < up.y - 8 then
          Log("nav up wrapped the menu's focus", tostring(up.layer), tostring(up.idx), "->", tostring(TB.flayer),
            tostring(TB.fidx), "y", up.y, "->", ny, ": undone")
          UndoWrap(up)
          NavEnter("wrap")
        end
      elseif up.t >= TB.NAV_WAIT then
        TB.up = nil
        NavEnter("top-most (focus did not move)")
      end
    elseif E[C.UP] and TB.host.dpad ~= false and TB.flayer ~= nil and TB.release == nil and not TB.mouse
        and TB.co == nil then
      -- only from a focus this VM knows and that still has the control focus (a child menu on top: not ours)
      local okf, act = pcall(funcLuaMenuCommand, VRFW_Cmd.IS_CTRL_FOCUS_ACTIVE, TB.flayer)
      if okf and act == true then
        local _, y = FocusPos(TB.flayer, TB.fidx)
        TB.up = {t = 0, fev = TB.fev, layer = TB.flayer, idx = TB.fidx, y = y}
      end
    end
    return false
  end

  local function Poll()
    -- the bar's focus (and a shortcut leaving for the title): the heartbeat that keeps every menu's input off
    if TB.nav or TB.release ~= nil then VRFW_TopBarGuard.Beat(true) end
    if TB.co ~= nil then
      local ok, err = coroutine.resume(TB.co)
      if not ok then Log("error", err) end
      if not ok or coroutine.status(TB.co) == "dead" then TB.co = nil end
      return
    end
    TB.frame = TB.frame + 1
    if TB.DEBUG and TB.dbg_steps == 0 then
      TB.dbg_steps = 1
      Log("dbg step alive")
    end
    if TB.frame % TB.CHECK_EVERY == 0 then Refresh() end
    NavRelease()
    if TB.rank_hide and TB.rank and TB.rank.plate then
      pcall(funcLuaMenuCommand, C.VISIBLE, TB.rank.plate, 0, false)
    end
    local E = Edges()
    if not TB.shown or #TB.entries == 0 or not TB.tex_ready then
      TB.up = nil
      if TB.nav then NavLeave(0, "row hidden") end
      return
    end
    -- pointer (mouse / free cursor): hover highlights; the mouse button, or Accept while the pointer leads, decides
    local mx, my = funcLuaMenuCommand(C.POINTER)
    local moved = false
    if type(mx) == "number" and type(my) == "number" then
      moved = funcLuaMenuCommand(C.MOVED) == true
      if not moved and TB.px ~= nil and (math.abs(mx - TB.px) > 1 or math.abs(my - TB.py) > 1) then
        moved = true                         -- the free cursor: no «mouse moved» flag
      end
      TB.px, TB.py = mx, my
    end
    local keys = E[C.UP] or E[C.DOWN] or E[C.LEFT] or E[C.RIGHT]
    if moved then
      if TB.DEBUG and not TB.dbg_ptr then
        TB.dbg_ptr = true
        local gx, gy = funcLuaMenuCommand(C.GPOS, L_ICON, 0)
        Log("dbg pointer", mx, my, "icon1 gpos", tostring(gx), tostring(gy))
      end
      if TB.nav then NavLeave(0, "pointer") end
      TB.up = nil
      TB.mouse = true
      -- over an open dropdown (its icons, or the gap under the group's icon): the group stays selected, the icon under
      -- the pointer is highlighted; else the icon under the pointer (a group's opens its dropdown)
      -- icon + gap + panel are one hover region; off it, an open dropdown waits TB.DROP_GRACE frames (below)
      local d = DropPointed(mx, my)
      if d ~= nil then
        TB.drop_out = nil
        DropSelect(d > 0 and d or nil, d > 0)
      else
        local k = Pointed()
        if k ~= nil then
          TB.drop_out = nil
          Select(k, true)                    -- another icon: its own (or no) dropdown
          if k == TB.sel and TB.dsel ~= nil then DropSelect(nil) end
        elseif TB.sel ~= nil then
          if DropGroup() ~= nil then
            if TB.drop_out == nil then TB.drop_out = TB.DROP_GRACE end
            if TB.dsel ~= nil then DropSelect(nil) end
          else
            Select(nil, false)
          end
        end
      end
    elseif keys and TB.mouse then
      TB.mouse = false                       -- the menu's arrows lead again: the pointer's highlight goes
      TB.drop_out = nil
      Select(nil, false)
    end
    -- the pointer left icon + dropdown: the dropdown closes after the grace (back inside in time: it stays)
    if TB.drop_out ~= nil then
      if not TB.mouse or DropGroup() == nil then
        TB.drop_out = nil
      else
        TB.drop_out = TB.drop_out - 1
        if TB.drop_out <= 0 then
          TB.drop_out = nil
          Select(nil, false)
        end
      end
    end
    if E[C.CLICK] or (TB.mouse and E[C.ENTER_CLICK]) then
      local d = DropPointed(mx, my)
      if d ~= nil and d > 0 then
        local it = TB.entries[TB.sel].items[d]
        return GoEntry(it, it.cur)           -- an icon of the open dropdown
      elseif d == nil then
        local k = Pointed()
        if k ~= nil then return Go(k) end    -- on no icon: nothing (the menu's own click / Enter stays its own)
        if TB.mouse and DropGroup() ~= nil then
          TB.drop_out = nil                  -- a click outside closes an open dropdown (the menu gets its click)
          Select(nil, false)
        end
      end
    end
    -- Esc / B while the pointer has a dropdown open closes it (outside the bar's pad focus; that path is PollNav's)
    if not TB.nav and TB.mouse and E[C.CANCEL] and DropGroup() ~= nil then
      TB.drop_out = nil
      Select(nil, false)
    end
    if PollNav(E) then return end
    -- L3 / T: tap = next icon, hold = go
    if funcLuaCommand(C.CHECK_INPUT, C.MENU_CTRL, C.KEY) == true then
      TB.held = TB.held + 1
      if TB.held == TB.HOLD then
        if TB.sel ~= nil then return Go(TB.sel) end
        Select(1, true)
      end
    elseif TB.held > 0 then
      if TB.held < TB.HOLD then
        TB.mouse = false
        Select(TB.sel == nil and 1 or (TB.sel % #TB.entries) + 1, true)
      end
      TB.held = 0
    end
    if TB.sel ~= nil and not TB.mouse then
      TB.sel_t = TB.sel_t - 1
      if TB.sel_t <= 0 then Select(nil, false) end
    end
  end

  -- ---- title side: a target deferred by a host that had to unwind first (path session) ----------------------------
  local function DeferPoll()
    if TB.co ~= nil then
      local ok, err = coroutine.resume(TB.co)
      if not ok then Log("error", err) end
      if not ok or coroutine.status(TB.co) == "dead" then TB.co = nil end
      return
    end
    TB.frame = TB.frame + 1
    if TB.frame % 10 ~= 0 or not VRFW_Param.Has(K.DEFER) then
      TB.defer_t = 0
      return
    end
    TB.defer_t = TB.defer_t + 10
    local open = SessionOpen()
    local host = false
    for _, m in ipairs(TT.session) do
      if funcLuaMenuCommand(C.EXISTS, m) == true then host = true end
    end
    if open or host or TT.go == nil or funcLuaCommand(C.SAVE_WORKING) == true or funcLuaCommand(C.MSG_BUSY) == true then
      if TB.defer_t >= TB.DEFER_MAX then
        Log("deferred target dropped: still", open and "in the session" or (host and "under the session host" or "busy"),
          "after", TB.defer_t, "frames")
        Clear(K.DEFER, TT.box, K.TARGET)
      end
      return
    end
    local item = Take(K.DEFER)
    Log("deferred target", tostring(item), "after", TB.defer_t, "frames: session closed, reset into it")
    P(TT.go, item)
    TB.co = coroutine.create(function()
      coroutine.yield()
      ResetToTitle(false)                    -- the title saved on arrival; the session's sink is off again
    end)
    local ok, err = coroutine.resume(TB.co)
    if not ok then Log("error", err) TB.co = nil end
  end

  -- the menu's focus as the engine / the menu's Lua move it: OnChangeFocus, OnFocusLayerShift (a1, a2 = the new
  -- element), and the focus-set command a menu's Lua runs itself (e.g. a hub's boxes)
  local function WrapFocus()
    local ocf = OnChangeFocus
    if type(ocf) == "function" then
      OnChangeFocus = function(a1, a2, ...)
        if not TB.self_focus then TB.fev, TB.flayer, TB.fidx = TB.fev + 1, a1, a2 end
        return ocf(a1, a2, ...)
      end
    end
    local ols = OnFocusLayerShift
    if type(ols) == "function" then
      OnFocusLayerShift = function(a1, a2, ...)
        if not TB.self_focus then TB.fev, TB.flayer, TB.fidx = TB.fev + 1, a1, a2 end
        return ols(a1, a2, ...)
      end
    end
    local raw = funcLuaMenuCommand
    -- the argument count is kept as called (explicit nils would change it: commands with optional arguments read
    -- lua_gettop; the 12:15 market_menu hang came with this wrapper passing (id, a1, a2, a3, ...) always)
    funcLuaMenuCommand = function(id, ...)
      if id == C.FOCUS_SET and not TB.self_focus and select("#", ...) >= 3 then
        local a1, a2, a3 = ...
        if a3 == true then TB.fev, TB.flayer, TB.fidx = TB.fev + 1, a1, a2 end
      end
      return raw(id, ...)
    end
  end

  local function WrapStep(poll)
    if TB.wrapped then return end
    -- Step wrapped here (once), after every patch of this script ran: the outermost wrapper
    TB.wrapped = true
    local step = Step
    Step = function(...)
      local r = table.pack(step and step(...))
      if TB.on then
        local ok, err = pcall(poll)
        if not ok then Log("error", err) TB.on = false end
      end
      return table.unpack(r, 1, r.n)
    end
  end

  -- ---- input guard (every VM) --------------------------------------------------------------------------------------
  -- While the bar has the focus, NO menu may take the keys: not the host, not a child opened over it (Partido libre's
  -- list, a shop, the team dock…). The engine dispatches the pad to every ACTIVE menu, and only the menus' own Lua know
  -- (and set) their active state, so each menu VM runs this guard on its own menu:
  --   * the VM's own MENU_ACTIVE(menu, b) calls for its menu are recorded as the menu's wish (in the VM only);
  --     while the bar has the focus a «true» is held back (recorded, the menu stays off)
  --   * every frame (its Step): heartbeat K.NAV alive (changed within GUARD_TTL frames) -> its menu off (once, logged
  --     «input of <menu> suspended»); heartbeat gone -> its menu back to its wish (logged «… restored»; no wish
  --     recorded = active, the state a menu opens in). A host that dies with the focus stops the heartbeat: nothing stays
  --     stuck after GUARD_TTL frames.
  -- The menus a VM suspends (with the bar opened by L3 the left stick still moved the
  -- a mod's grid under it): its script's menu, the menus its own Lua switches with MENU_ACTIVE (learned: a script
  -- whose stem is not its menu's name, e.g. enjoy_team_select_menu_campaign runs the menu enjoy_team_select_menu,
  -- shop_menu_buy runs shop_menu: the old guard switched off a menu that does not exist and the real one
  -- kept the D-pad and the stick) and, until one is learned, the menu of the stem's first shorter name that exists
  -- (enjoy_team_select_menu_campaign -> enjoy_team_select_menu). Each keeps its own wish.
  local GUARD_TTL = 30
  local GD = VRFW_TopBarGuard or {}
  VRFW_TopBarGuard = GD
  GD.raw, GD.menu, GD.off, GD.last, GD.still, GD.beat_n = GD.raw, nil, false, nil, 0, GD.beat_n or 0
  -- the menu's own wish (its Lua's last MENU_ACTIVE for itself in this VM; none = active, the state a menu opens in).
  -- Kept in the VM, never in the param store (one param per menu filled the store: the title hand-off
  -- param could not be written and shortcuts stopped at the title)
  local function Wish(m) return GD.wishes == nil or GD.wishes[m] ~= false end
  -- the menus this VM suspends now (existing menu objects only)
  local function Targets()
    local out, seen = {}, {}
    local function add(m)
      if m ~= nil and not seen[m] then
        seen[m] = true
        if funcLuaMenuCommand(C.EXISTS, m) == true then out[#out + 1] = m end
      end
    end
    add(GD.menu)
    for m in pairs(GD.menus or {}) do add(m) end
    for m in pairs(GD.learned or {}) do add(m) end
    if #out == 0 and type(TB.name) == "string" then
      -- no menu of that name: the stem's shorter names (enjoy_team_select_menu_campaign -> enjoy_team_select_menu)
      local n = TB.name
      for _ = 1, 3 do
        local shorter = n:match("^(.+)_[^_]+$")
        if shorter == nil or not shorter:find("_", 1, true) then break end
        n = shorter
        local m = CRC32(n)
        if funcLuaMenuCommand(C.EXISTS, m) == true then
          out[#out + 1] = m
          GD.learned = GD.learned or {}
          GD.learned[m] = true
          Log("top bar focus: menu of", TB.name, "is", n)
          break
        end
      end
    end
    return out
  end
  function GD.Beat(on)
    if on then
      GD.beat_n = (GD.beat_n % 1000000) + 1
      VRFW_Param.Set(K.NAV, GD.beat_n)
    elseif VRFW_Param.Has(K.NAV) then
      VRFW_Param.Clear(K.NAV)
    end
  end
  local function NavAlive()
    if not VRFW_Param.Has(K.NAV) then GD.last, GD.still = nil, 0 return false end
    local v = VRFW_Param.Get(K.NAV)
    if v ~= GD.last then GD.last, GD.still = v, 0 else GD.still = GD.still + 1 end
    return GD.still < GUARD_TTL
  end
  -- The screen's focus look while the bar has the focus: the focused element whose menu cursor this VM's Lua attached
  -- (CMND_SET_LAYER_ATTACH_LOCATOR_TRACE on the «cursor» locator, recorded by Guard in GD.cursor_on) drops its focus
  -- frame and that cursor, as retail does when a layer gives the focus away (Focus animation set «button» state 2,
  -- trace off). Screens with their own cursor (other locators, layers without control focus) are left alone. The
  -- control focus is not moved and no menu callback runs. On leave the screen's own last wish is put back.
  function GD.FocusHide()
    GD.hidden = {}
    for layer, on in pairs(GD.cursor_on or {}) do
      local okf, act = pcall(GD.raw, C.CTRL_FOCUS_ACTIVE, layer)
      local oki, idx = pcall(GD.raw, C.FOCUS_INDEX, layer)
      if okf and act == true and oki and type(idx) == "number" and on[idx] == true then
        pcall(GD.raw, C.PLAY_ANIME, layer, idx, C.ANIME_FOCUS, 2, C.ANIME_SET_BUTTON)
        pcall(GD.raw, C.ATTACH_TRACE, layer, idx, C.LOCATOR_CURSOR, false)
        GD.hidden[#GD.hidden + 1] = {layer = layer, idx = idx}
        Log("top bar focus: focus look of", TB.name, "hidden", layer, idx)
      end
    end
  end
  function GD.FocusShow()
    local hidden = GD.hidden or {}
    GD.hidden = {}
    for _, h in ipairs(hidden) do
      local oke, exists = pcall(GD.raw, C.LAYER_EXISTS, h.layer)
      local on = GD.cursor_on ~= nil and GD.cursor_on[h.layer] or nil
      -- the screen turned that cursor off itself meanwhile (focus moved, layer closed): its state stays
      if oke and exists == true and on ~= nil and on[h.idx] == true then
        pcall(GD.raw, C.ATTACH_TRACE, h.layer, h.idx, C.LOCATOR_CURSOR, true)
        local okf, act = pcall(GD.raw, C.CTRL_FOCUS_ACTIVE, h.layer)
        local oki, idx = pcall(GD.raw, C.FOCUS_INDEX, h.layer)
        if okf and act == true and oki and idx == h.idx then
          pcall(GD.raw, C.PLAY_ANIME, h.layer, h.idx, C.ANIME_FOCUS, 0, C.ANIME_SET_BUTTON)
        end
        Log("top bar focus: focus look of", TB.name, "restored", h.layer, h.idx)
      end
    end
  end
  local function GuardStep()
    if GD.menu == nil then return end
    local alive = NavAlive()
    if alive and not GD.off then
      GD.FocusHide()
      GD.off = true
      GD.held = {}
      for _, m in ipairs(Targets()) do
        if Wish(m) then
          GD.raw(C.MENU_ACTIVE, m, false)
          GD.held[#GD.held + 1] = m
        end
      end
      if #GD.held > 0 then Log("top bar focus: input of", TB.name, "suspended (" .. #GD.held .. " menu(s))") end
    elseif not alive and GD.off then
      GD.off = false
      local n = 0
      for _, m in ipairs(GD.held or {}) do
        if Wish(m) and funcLuaMenuCommand(C.EXISTS, m) == true then
          GD.raw(C.MENU_ACTIVE, m, true)
          n = n + 1
        end
      end
      if n > 0 then Log("top bar focus: input of", TB.name, "restored (" .. n .. " menu(s))") end
      GD.held = {}
      GD.FocusShow()
    end
  end
  local function Guard()
    -- menus only (never the title screens, whose hand-off presses a mode while a shortcut is in flight, nor a VM the
    -- loader could not name: «?»)
    if GD.installed or type(TB.name) ~= "string" or TB.name == "?" or TB.name:find("^title") then return end
    GD.installed = true
    GD.menu = CRC32(TB.name)
    GD.menus = {[GD.menu] = true}   -- + the host's `variants` (Init, after the rules are read)
    local raw = funcLuaMenuCommand
    GD.raw = raw
    funcLuaMenuCommand = function(id, ...)
      if id == C.ATTACH_TRACE and select("#", ...) >= 4 then
        local layer, idx, locator, on = ...
        if locator == C.LOCATOR_CURSOR and type(layer) == "number" and type(idx) == "number" then
          GD.cursor_on = GD.cursor_on or {}
          local t = GD.cursor_on[layer]
          if on == true then
            if t == nil then t = {} GD.cursor_on[layer] = t end
            t[idx] = true
          elseif t ~= nil then
            t[idx] = nil
            if next(t) == nil then GD.cursor_on[layer] = nil end
          end
        end
      end
      if id == C.MENU_ACTIVE and select("#", ...) >= 2 then
        local m, b = ...
        if type(m) == "number" then
          -- every menu this VM's Lua switches is one of its menus (learned), with its own wish
          local mine = GD.menus ~= nil and GD.menus[m] == true
          if mine then GD.menu, GD.wish = m, b == true end
          GD.learned = GD.learned or {}
          GD.wishes = GD.wishes or {}
          GD.learned[m], GD.wishes[m] = true, b == true
          if b == true and GD.off then
            local held = false
            for _, x in ipairs(GD.held or {}) do if x == m then held = true break end end
            if not held then GD.held = GD.held or {} GD.held[#GD.held + 1] = m end
            return raw(id, m, false)            -- the bar has the focus: the wish is kept for later
          end
        end
      end
      return raw(id, ...)
    end
    local step = Step
    if type(step) == "function" then
      Step = function(...)
        local r = table.pack(step(...))
        local ok, err = pcall(GuardStep)
        if not ok then Log("guard error", err) GD.menu = nil end
        return table.unpack(r, 1, r.n)
      end
    end
  end

  local function Init()
    TB.init_seq = (TB.init_seq or 0) + 1
    pcall(Guard)
    TB.on, TB.shown, TB.sel, TB.held, TB.co, TB.cur, TB.block = false, false, nil, 0, nil, {}, false
    TB.mouse, TB.px, TB.py, TB.prev = false, nil, nil, {}
    TB.tex_ready, TB.tex_t, TB.dbg_open, TB.dbg_steps, TB.dbg_gpos, TB.dbg_ptr = false, 0, nil, 0, false, false
    TB.nav, TB.up, TB.release, TB.defer_t = false, nil, nil, 0
    TB.right, TB.rank_log, TB.rank_hide, TB.open_t, TB.menu_ok = TB.RIGHT, false, false, 0, false
    TB.raised, TB.fading = false, false
    if type(funcLuaMenuCommand) ~= "function" or TB.name == nil or type(CRC32) ~= "function" then return end
    LoadRules()
    -- a straight reset landed: the first menu of the new scene says so with the carry's outcome
    if VRFW_Param.Has(K.DIRECT) then
      VRFW_Param.Clear(K.DIRECT)
      local okc, last = pcall(funcLuaCommand, C.CARRY, 2)
      if tostring(TB.name):find("^title") then
        Log("direct: the title runs after all (carry:", tostring(okc and last or "?"), ")")
      else
        Log("direct: landed on", TB.name, "(carry:", tostring(okc and last or "?"), ")")
      end
    end
    if TB.name == TITLE then
      TB.on = true
      if VRFW_Param.Has(K.HIDE) then VRFW_Param.Clear(K.HIDE) end   -- stale after a reset
      WrapStep(DeferPoll)
      if VRFW_Param.Has(K.DEFER) then Log("title: a deferred target is waiting") end
      return
    end
    local n = funcLuaMenuCommand(C.LAYER_NUM, L_ICON)
    if type(n) ~= "number" or n <= 0 then return end
    -- as many icons as the host has instances of evt_topbar_icon (the count the declaring mod gives the layer):
    -- a ninth / tenth entry is drawn
    -- where the layers allow it; plate instance MAX is the spare one (the old hint)
    TB.MAX = n
    TB.menu, TB.self_crc = CRC32(TB.name), CRC32(TB.name)
    if VRFW_TopBarGuard ~= nil and VRFW_TopBarGuard.menus ~= nil then
      for _, v in ipairs(TB.host.variants or {}) do VRFW_TopBarGuard.menus[v] = true end
    end
    ResolveMenu()
    local nb = funcLuaMenuCommand(C.LAYER_NUM, L_BACK)
    TB.has_back, TB.back_on = type(nb) == "number" and nb > 0, false
    if VRFW_Param.Has(K.BUSY) then VRFW_Param.Clear(K.BUSY) end -- stale after a reset
    if VRFW_Param.Has(K.NAV) then VRFW_Param.Clear(K.NAV) end   -- no focus at a hub's start
    local nd, np = funcLuaMenuCommand(C.LAYER_NUM, L_DICON), funcLuaMenuCommand(C.LAYER_NUM, L_DPLATE)
    TB.has_drop = type(nd) == "number" and nd > 0 and type(np) == "number" and np > 0
    TB.dsel, TB.dshut, TB.drop_drawn = nil, false, TB.has_drop   -- drawn = hide its quads at the first Draw
    TB.drop_out = nil
    TB.entries = LoadEntries()
    TB.xs, TB.ws = {}, {}
    Layout()
    TB.plate_tex = nil
    for _, tex in pairs(Atlases()) do
      funcLuaMenuCommand(C.LOAD_TEX, tex)
    end
    -- the plates evt_tb_hover / evt_tb_current / evt_tb_back: from the declared atlas ([VRFW.TopBarStyle] PlatesAtlas);
    -- none declared: the first icon's atlas (old rule, WARN: a mod's own first icon would show no plate)
    if TB.plates_atlas ~= nil then
      funcLuaMenuCommand(C.LOAD_TEX, TB.plates_atlas)
      TB.plate_tex = CRC32(TB.plates_atlas)
    else
      for _, e in ipairs(TB.entries) do
        if e.tex_crc ~= nil then TB.plate_tex = e.tex_crc break end
      end
      if TB.plate_tex ~= nil then
        Log("WARN no [vrfw.TopBarStyle] PlatesAtlas declared: the plates are read from the first icon's atlas")
      end
    end
    TB.on = #TB.entries > 0
    local ng = 0
    for _, e in ipairs(TB.entries) do if e.kind == "group" then ng = ng + 1 end end
    Log("init", n, "entries", #TB.entries, "groups", ng, "dropdown layers", tostring(TB.has_drop), "gate", tostring(TB.host.gate), "leave", tostring(TB.host.leave),
      "session", tostring(TB.host.session), "title hand-off", tostring(TT.go ~= nil), "variants",
      #(TB.host.variants or {}), "open_hold", tostring(TB.host.open_hold), "active_only", tostring(TB.host.active_only),
      "plates", tostring(TB.plates_atlas or "first icon"))
    if TB.on and not TB.wrapped then
      WrapFocus()
      WrapStep(Poll)
    end
  end

  local init = OnInit
  if type(init) == "function" then
    OnInit = function(...)
      local r = table.pack(init(...))
      local ok, err = pcall(Init)
      if not ok then Log("init error", err) TB.on = false end
      return table.unpack(r, 1, r.n)
    end
  end
  -- our layers: no retail setup / open code ever sees them (hidden until the header is open)
  local setup = OnSetupLayer
  if type(setup) == "function" then
    OnSetupLayer = function(a1, a2, ...)
      if a1 == L_ICON or a1 == L_PLATE or a1 == L_BACK or a1 == L_DPLATE or a1 == L_DICON or a1 == L_DLABEL then
        pcall(funcLuaMenuCommand, C.VISIBLE, a1, a2, false)
        return
      end
      return setup(a1, a2, ...)
    end
  end
  local open = OnOpenLayer
  if type(open) == "function" then
    OnOpenLayer = function(a1, a2, ...)
      if a1 == L_ICON or a1 == L_PLATE or a1 == L_BACK or a1 == L_DPLATE or a1 == L_DICON or a1 == L_DLABEL then
        if TB.on then pcall(Draw) end
        return
      end
      return open(a1, a2, ...)
    end
  end
  -- The same three hooks as VRFW_Host handlers of this script: a stem patch that REDEFINES OnInit /
  -- OnSetupLayer / OnOpenLayer (a source-edit graft, e.g. the framework's route_nodes on the Chronicle board
  -- vs_route_town_menu) runs after lua\_all and drops the wrappers above: Init never ran there (no row) and the
  -- bar's quads stayed at (0, 0) with the cmn01_10 quad's retail sprite (the red «new» badge, top-left corner). A
  -- script that is a host (VRFW_Host.host in its patches) hooks these points over whatever its patches made of them,
  -- so the bar survives them. Where the wrappers above are still under the host's dispatcher, Init runs once (init_seq)
  -- and our layers are answered by whichever comes first. Registering only defines tables (no engine call at load).
  local VH = VRFW_Host
  if type(TB.name) == "string" and type(VH) == "table" and type(VH.on) == "function" then
    local function ours(a1) return a1 == L_ICON or a1 == L_PLATE or a1 == L_BACK or a1 == L_DPLATE or a1 == L_DICON or a1 == L_DLABEL end
    pcall(VH.on, TB.name, "OnInit", {id = "vr_framework.top_bar_init", phase = "around", fn = function(nxt, ...)
      local seq = TB.init_seq
      local r = table.pack(nxt(...))
      if TB.init_seq == seq then
        local ok, err = pcall(Init)
        if not ok then Log("init error", err) TB.on = false end
      end
      return table.unpack(r, 1, r.n)
    end})
    pcall(VH.on, TB.name, "OnSetupLayer", {id = "vr_framework.top_bar_setup", phase = "around", fn = function(nxt, a1, a2, ...)
      if ours(a1) then
        pcall(funcLuaMenuCommand, C.VISIBLE, a1, a2, false)
        return
      end
      return nxt(a1, a2, ...)
    end})
    pcall(VH.on, TB.name, "OnOpenLayer", {id = "vr_framework.top_bar_open", phase = "around", fn = function(nxt, a1, a2, ...)
      if ours(a1) then
        if TB.on then pcall(Draw) end
        return
      end
      return nxt(a1, a2, ...)
    end})
  end
end

-- ---- the steps after the title (an entry's `action.path`) -------------------------------
-- VRFW_TopBarStep("<step>") -> true when the shortcut in flight (param evt_top_bar_target = crc32(entry key)) has
-- `<step>` as its next step; the step is taken (param evt_top_bar_step; after the last one both params are cleared), so
-- a screen asks once, at the moment it can go on (e.g. its OnInit), then decides whether it really can. The path is read
-- from the entry list (CMND_VRFW_MENU_ENTRY, 9th value): the handler knows only its own step name, never an entry key.
-- Engine calls only when called (nothing at chunk load).
if VRFW_TopBarStep == nil then
  local TARGET, STEP = 837786837 --[[evt_top_bar_target]], 3366268333 --[[evt_top_bar_step]]
  local function U32(v) return VRFW_Id.u32_or(v, v) end
  local function Get(k)
    if not VRFW_Param.Has(k) then return nil end
    return U32(VRFW_Param.Get(k))
  end
  local function Clear(k)
    if VRFW_Param.Has(k) then VRFW_Param.Clear(k) end
  end
  local function Log(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    pcall(funcLuaCommand, VRFW_Cmd.EVT_LOG, "EVT top_bar step " .. table.concat(p, " "))
  end
  function VRFW_TopBarStep(step)
    if type(CRC32) ~= "function" then return false end
    local target = Get(TARGET)
    if target == nil then return false end
    local ok, n = pcall(funcLuaCommand, VRFW_Cmd.VRFW_MENU_ENTRY_COUNT, "top_bar")
    if not ok or type(n) ~= "number" then return false end
    for i = 1, n do
      local key, _t, _i, _k, _v, _o, _c, _m, steps = funcLuaCommand(VRFW_Cmd.VRFW_MENU_ENTRY, "top_bar", i)
      if key ~= nil and U32(CRC32(key)) == target then
        local list = {}
        for s in tostring(steps or ""):gmatch("[^,%s]+") do list[#list + 1] = s end
        local done = Get(STEP) or 0
        if list[done + 1] ~= step then return false end
        if done + 1 >= #list then
          Clear(TARGET)
          Clear(STEP)
        else
          Clear(STEP)
          VRFW_Param.Set(STEP, done + 1)
        end
        Log(key, "takes", step, done + 1, "of", #list)
        return true
      end
    end
    return false
  end
end

-- ---- hide the row while something plays full screen over the hub ------------------------------------------
-- VRFW_TopBarHide(true | false): sets / clears the param vrfw_top_bar_hidden every host's row reads (Refresh: not drawn,
-- no input while it is set). For a mod's scene played over the menus: the hub's header
-- stays open under it, so the row would stay drawn. The title clears a stale one after a reset. Engine calls only when
-- called (nothing at chunk load).
if VRFW_TopBarHide == nil then
  function VRFW_TopBarHide(on)
    local HIDE = 1455983968 --[[vrfw_top_bar_hidden]]
    if on then
      VRFW_Param.Set(HIDE, 1)
    elseif VRFW_Param.Has(HIDE) then
      VRFW_Param.Clear(HIDE)
    end
    return true
  end
end
