-- Plantilla de equipo: «Partido» (11v11) / «Pachanga» (5v5) templates (docs/game/ui/pachanga-templates.md).
-- * «Equipar todo» leaves the list; the first row is the format row «< 11 v 11 >» / «< 5 v 5 >».
-- * The 5v5 templates are the retail teamInfo[1] of the same 11 docks. The retail menu already shows / edits them when
--   it is opened with the team kind param (4081600465) = 1 (the story 5v5 look: mainmenu04_10_formation_base, 5 cards),
--   The selector switches IN PLACE (v3): the pitch layers are closed and built again for the other kind; the dock never
--   closes (a closed standalone dock lets the field under it start). Going back to 11v11 needs the loader
--   (CMND_EVT_PACHANGA_UPVAL: two INCLUDE locals have no setter).
-- * Active teams: «Partido» = the retail VS team (vsUseTeamSet); «Pachanga» = loader team_banks
--   (CMND_EVT_PACHANGA_*, evt_loader\pachanga_slot<N>.json, one per bank). «Establecer como equipo activo» sets the one of
--   the type on screen; the dock number check mark, the header mark and the selector's help line show them.
-- * Only in the standalone dock (opened from the title) outside INAROGUE / story / Crónica; elsewhere the row is grey.
-- * The first rows are the format rows, one per enabled format of EVT_PT_KINDS (the one declaration of the formats):
--   «11v11», «5v5». Up / down move between them as in any list, right leaves the list as the retail list does, Accept
--   on a row switches the dock to that format (since 2026-10-19; before, one row «< 11 v 11 >» cycled with left / right
--   and trapped the focus when it was the list's only row). Every refusal goes through PT.gate (one guard: OnEnter
--   refuses at once, PT.switch checks again).
-- * 2026-09-30 (doc §9): the two templates of a dock share name, emblem, kit, supertácticas, coach and managers
--   (PT.link); leaving the dock puts the Partido team of the visit back in vsUseTeamSet (PT.leave).
-- Uses the file locals t, t2, n, n4, n5, n10, n11, flag3, flag4 (graft.toml expect). Wraps once per definition (EVT_PT_WRAPPED).
-- Nothing calls funcLuaCommand / funcLuaMenuCommand at chunk load.
@BONUS5@
do
  if EVT_PACHANGA == nil then
    EVT_PACHANGA = true              -- false: retail list (with «Equipar todo») and no selector
  end
  if EVT_PT_WRAPPED == nil then
    EVT_PT_WRAPPED = {}
  end
  local PT = {
    INFO = @crc:CMND_EVT_PACHANGA_INFO@,       -- -> ok, active dock (-1), 5v5 members, bank (1-based), slot
    SET = @crc:CMND_EVT_PACHANGA_SET@,         -- (dock | -1) -> ok, code
    VS = @crc:CMND_EVT_PACHANGA_VS@,           -- (op 0 take / 1 remember / 2 peek, vs) -> ok, vs
    FLAGS = @crc:CMND_EVT_PACHANGA_FLAGS@,     -- -> dock bits put back
    VERSION = 2217361807,            -- CMND_EVT_LOADER_VERSION -> api, module mask
    MOD_BIT = 2097152,               -- bit 21 = team bank pages (mod Utilities, which IF requires)
    LOG = 3661580131,                -- CMND_EVT_LOG
    EXISTS = 2947612279, GET = 3522198769, DEL = 3363400568, PUT = 3860611758,   -- menu parameter store
    KEY_KIND = 4081600465,           -- team kind of the dock / its children (0 = 11v11, 1 = 5v5)
    KEY_PLATE_KIND = 2419482555,     -- personal_plate_menu: 1 = 5v5 formation state
    KEY_MODE = @crc:evt_pachanga_mode@,        -- type the next dock opens with (value + 1)
    KEY_DOCK = @crc:evt_pachanga_dock@,        -- dock the next dock opens on
    UPVAL = @crc:CMND_EVT_PACHANGA_UPVAL@,     -- (fn, expect, value, ...) -> upvalues changed (-1 = not available)
    INIT = @crc:CMND_EVT_PACHANGA_INIT@,       -- (dock) -> 5v5 members removed (the template is emptied)
    SPLIT = @crc:CMND_EVT_PACHANGA_SPLIT@,     -- (dock) -> players removed: a 5v5 team that is the 11v11 auto-copy
    FORM_BOX = 3286546665,           -- team00_12_formation_style: the FORMACIÓN box (formation picker)
    KEY_PF = {@crc:evt_pf_menu@, @crc:evt_pf_group@},   -- formation screen VMs: 5v5 mode for dock (pachanga_formation)
    KEY_PF11 = {@crc:evt_pf11_menu@, @crc:evt_pf11_group@},   -- same VMs: 11v11 mode for dock (Partido, 2026-09-30)
    KEY_BANK = @crc:evt_pb_dock@,    -- the bank's 5v5 view (graft pachanga_bank), value = dock
    KEY_ACTIVE_DOCK = 700666421,     -- retail: the active dock (n4) handed to the dock's children (kizuna, habilidades)
    PLATE_MENU = 1427722143,         -- personal_plate_menu (EVT_PT_PlateKind, graft pachanga_plate)
    -- Pachanga has no synergies (Nacho 2026-09-28): these dock layers are hidden and inert. The supertácticas are back
    -- in Pachanga (Nacho 2026-09-30: «recupera la sección de supertácticas»): TACTICS is only shown again after a switch.
    NO5 = {[1179455358] = true,      -- team00_17_synergy_attachment_button_pillar (castle)
           [830633104] = true},      -- team00_17_synergy_attachment_button_flag (flag)
    TACTICS = {2579693296,           -- team00_10_tactics_base (TÁCTICAS header)
               3018698265,           -- soccer08_12_tactics_cmd (x3)
               1559239586},          -- team00_11_p1_tactics_focus (x3, opens the tactics picker)
    GET_INFO = 1033065575, SET_INFO = 1506470613,   -- CMND_GET / SET_TEAM_SET_INFO (set, team, field, ...)
    -- the 5v5 formations (t7 of soccer_formation_menu_inc = the retail 5v5 list); the story's first one is 712431653
    FORM5 = {[1567746227] = true, [712431653] = true, [3011479967] = true, [3296246025] = true, [1422369944] = true},
    FORM5_DEFAULT = 712431653,
    VALID = 1538643580,              -- (set, team, false) -> 0 = the team can play (retail member check)
    GET_VS = 3713813716, SET_VS = 662075964,
    ROW = 13, EQUIP_ALL = 10,        -- list item kinds (t): the first format row (format col c = ROW + c - 1), retail «Equipar todo»
    LIST = 3367997069,               -- team01_02_list_item
    GUIDE_LINE = 3078308064, GUIDE_NODE = 378156699, SET_TEXT = 1083631230,
    MENU_ID = 937147172,             -- soccer_team_dock_menu
    TEXT_GET = 4074371074, SET_HEADER = 2865764598, TEXT_HEADER = 1923260944,
    SOUND = 1917805374, SE_OK = 3848881948, SE_NG = 2086672038,
    ACTIVE_FUNC = 4219711668,        -- OnFunction: «Establecer como equipo activo»
    NAME_FRAME = 1922851874,         -- team01_04_p1_team_name_frame (OnEnter: the retail team name edit)
    PAGE_FUNC = 2294853123,          -- OnFunction: Z / C (L1 / R1) previous / next dock
    T = {
      MATCH = @crc:evt_pt_row_match@, PACHANGA = @crc:evt_pt_row_pachanga@, HELP = @crc:evt_pt_row_help@,
      LINE = @crc:evt_pt_active_line@, NONE = @crc:evt_pt_none@, NOW = @crc:evt_pt_now_active@,
      NEED5 = @crc:evt_pt_need_five@, ONLY_TITLE = @crc:evt_pt_only_title@, NO_LOADER = @crc:evt_pt_no_loader@,
      HEADER = @crc:evt_pt_header@,
      KIND_11 = @crc:evt_pt_kind_11@, KIND_7 = @crc:evt_pt_kind_7@, KIND_5 = @crc:evt_pt_kind_5@,
      KIND_3 = @crc:evt_pt_kind_3@, KIND_LOCKED = @crc:evt_pt_kind_locked@,
      FORMAT = @crc:evt_pt_format_row@,
    },
    FALLBACK = {
      MATCH = "Tipo: Partido",
      PACHANGA = "Tipo: Pachanga",
      LINE = "Equipo activo de partido: {match} · Equipo activo de pachanga: {pachanga}",
      NONE = "ninguno",
      NOW = "La plantilla {n} «{team}» es ahora el equipo activo de pachanga.",
      NEED5 = "Esta plantilla de pachanga no está completa. Coloca a 5 jugadores para poder usarla como equipo activo de pachanga.",
      ONLY_TITLE = "El tipo de plantilla solo se puede cambiar en Plantilla de equipo, entrando desde el menú principal.",
      NO_LOADER = "El equipo activo de pachanga necesita el cargador del mod (módulo team_banks).",
      HEADER = "Pachanga",
      KIND_11 = "11v11", KIND_7 = "7v7", KIND_5 = "5v5", KIND_3 = "3v3",
      KIND_LOCKED = "Este tipo de plantilla todavía no está disponible.",
      FORMAT = "< {a} v {b} >",
    },
    active = -1, loader = false, start = nil, logs = 0,
  }
  EVT_PT = PT

  function PT.pack(...)
    return {n = select("#", ...), ...}
  end

  function PT.log(...)
    if PT.logs < 40 then
      PT.logs = PT.logs + 1
      pcall(funcLuaCommand, PT.LOG, "EVT pachanga", ...)
    end
  end

  function PT.wrap(name, make)
    local cur = _ENV[name]
    if type(cur) ~= "function" or EVT_PT_WRAPPED[cur] then
      return false
    end
    local w = make(cur)
    EVT_PT_WRAPPED[w] = true
    _ENV[name] = w
    return true
  end

  function PT.text(key, subs)
    local s = nil
    local id = PT.T[key]
    if id ~= nil then
      local ok, r = pcall(funcLuaCommand, PT.TEXT_GET, id)
      if ok and type(r) == "string" and r ~= "" then
        s = r
      end
    end
    s = s or PT.FALLBACK[key] or ""
    for k, v in pairs(subs or {}) do
      s = string.gsub(s, "{" .. k .. "}", (string.gsub(tostring(v), "%%", "%%%%")))
    end
    return s
  end

  -- menu parameter store: v = nil deletes the key
  function PT.param(k, v)
    if funcLuaCommand(PT.EXISTS, k) then
      funcLuaCommand(PT.DEL, k)
    end
    if v ~= nil then
      funcLuaCommand(PT.PUT, k, 0, v, 1)
    end
  end

  function PT.take(k)
    if not funcLuaCommand(PT.EXISTS, k) then
      return nil
    end
    local v = funcLuaCommand(PT.GET, k)
    funcLuaCommand(PT.DEL, k)
    return v
  end

  function PT.pachanga()
    return EVT_PACHANGA and n10 == 1
  end

  function PT.isDock(s)
    return type(s) == "number" and s >= 2 and s <= 12
  end

  -- loader module team_banks present -> PT.loader, PT.active (the active pachanga dock of the mounted bank, -1 none)
  function PT.refresh()
    PT.loader, PT.active, PT.bank = false, -1, 1
    local ok, api, mods = pcall(funcLuaCommand, PT.VERSION)
    if not ok or type(mods) ~= "number" or math.floor(mods / PT.MOD_BIT) % 2 ~= 1 then
      return
    end
    local ok2, r, active, _, bank = pcall(funcLuaCommand, PT.INFO)
    if ok2 and r == true and type(active) == "number" then
      PT.loader, PT.active = true, active
      PT.bank = type(bank) == "number" and bank or 1
    end
  end

  -- another mode owns this dock (EVT_DOCK_OWNERS: name -> function, true while that mode's dock is open); the
  -- owners are asked each time, since their graft may wrap OnInit inside this one (mod load order)
  function PT.inRogue()
    if type(EVT_IRD) == "table" and EVT_IRD.on == true then
      return true
    end
    if type(EVT_DOCK_OWNERS) == "table" then
      for _, owns in pairs(EVT_DOCK_OWNERS) do
        if type(owns) == "function" then
          local ok, yes = pcall(owns)
          if ok and yes == true then
            return true
          end
        end
      end
    end
    return false
  end

  -- the type can be switched here? (true | false, reason)
  function PT.canSwitch()
    if not EVT_PACHANGA then
      return false, "off"
    elseif PT.inRogue() then
      return false, "inarogue"
    elseif not flag4 then
      return false, "not standalone"
    elseif funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], 3902542018 --[[chronicle_mode_top_menu]]) == true then
      return false, "chronicle"
    elseif funcLuaCommand(3004482920 --[[CMND_GET_PLAY_GAME_MODE?]]) == 2 then
      return false, "story"
    elseif type(UTIL_TB) == "table" and type(UTIL_TB.online) == "function" and UTIL_TB.online() then
      return false, "online"
    end
    return true
  end

  -- modal message (same calls as the retail OpenChangeTeamDockMessage; runs inside a callback coroutine)
  function PT.message(s)
    funcLuaMenuCommand(1558704558, PT.MENU_ID, false)
    funcLuaCommand(2289627655, s, 0, 0, 0, 0, 0, false)
    local k = -1
    while k < 0 do
      k = funcLuaCommand(1523741473)
      coroutine.yield()
    end
    waitTrue(function()
      return funcLuaCommand(682363669)
    end)
    funcLuaMenuCommand(1558704558, PT.MENU_ID, true)
  end

  -- the same message from a callback that must answer at once (OnEnter: a refusal is `return 1` before any yield; an
  -- OnEnter that yields counts as accepted and the engine goes on to OnDecideFocus, outside a coroutine: log
  -- 2026-10-02 13:17, «switch refused» then «switch 0 -> 1»). The message runs in the dock's own coroutine (Step).
  function PT.say(s)
    if PT.co == nil and PT.msg == nil then
      PT.msg = s
    end
  end

  function PT.stepSay()
    if PT.co == nil and PT.msg ~= nil then
      local s = PT.msg
      PT.co = coroutine.create(function()
        PT.message(s)
      end)
    end
    if PT.co == nil then
      return
    end
    local ok, e = coroutine.resume(PT.co)
    if not ok then
      PT.log("message error", tostring(e))
      pcall(funcLuaMenuCommand, 1558704558, PT.MENU_ID, true)
    end
    if not ok or coroutine.status(PT.co) == "dead" then
      PT.co, PT.msg = nil, nil
    end
  end

  -- ================================================================================================================
  -- The match formats of the first row, in cycle order. The ONE place that declares them; everything below reads this
  -- list. kind = the retail team kind the dock shows for that format (n10: 0 = teamInfo[0], the 11v11 team; 1 =
  -- teamInfo[1], the 5v5 team; retail has no other kind). players / rivals = the numbers of the row text «< 11 v 11 >»
  -- (default: the numbers of id). A format with enabled = false or without a kind is skipped by the row. text = a key of
  -- PT.T (or a menu_text id), used when the format has no numbers. A mode that adds a format sets EVT_PT_KINDS (same
  -- fields) before this block.
  if EVT_PT_KINDS == nil then
    EVT_PT_KINDS = {
      {id = "11v11", text = "KIND_11", players = 11, rivals = 11, kind = 0, enabled = true},
      {id = "7v7", text = "KIND_7", players = 7, rivals = 7, enabled = false},
      {id = "5v5", text = "KIND_5", players = 5, rivals = 5, kind = 1, enabled = true},
      {id = "3v3", text = "KIND_3", players = 3, rivals = 3, enabled = false},
    }
  end

  -- The team name's length is Utilities' (graft util_team_name, docs/game/ui/team-name-length.md): this block only keeps
  -- the other template in step after the retail name edit.

  -- The format rows (docs/game/ui/pachanga-templates.md §11): one normal list row per enabled format, its text the
  -- format's name; Accept on a row switches the dock to that format (PT.switch).
  PT.SE_MOVE = 2500047763            -- sy0005
  PT.pick = nil                      -- the format OnEnter accepted, for the OnDecideFocus of the same press

  function PT.kinds()
    if type(EVT_PT_KINDS) == "table" and #EVT_PT_KINDS > 0 then
      return EVT_PT_KINDS
    end
    return {{id = "11v11", text = "KIND_11", players = 11, rivals = 11, kind = 0, enabled = true},
            {id = "5v5", text = "KIND_5", players = 5, rivals = 5, kind = 1, enabled = true}}
  end

  function PT.kindOn(k)
    return type(k) == "table" and k.enabled ~= false and (k.kind == 0 or k.kind == 1)
  end

  -- the indexes of the enabled formats, in cycle order
  function PT.options()
    local list = {}
    for i, k in ipairs(PT.kinds()) do
      if PT.kindOn(k) then
        list[#list + 1] = i
      end
    end
    return list
  end

  function PT.kindLabel(k)
    if type(k.text) == "number" then
      local ok, s = pcall(funcLuaCommand, PT.TEXT_GET, k.text)
      if ok and type(s) == "string" and s ~= "" then
        return s
      end
    elseif type(k.text) == "string" and PT.T[k.text] ~= nil then
      return PT.text(k.text)
    end
    return tostring(k.label or k.id or "?")
  end

  -- the row text of a format: «< 11 v 11 >» (text key evt_pt_format_row), else «< label >»
  function PT.formatText(k)
    if type(k) ~= "table" then
      return ""
    end
    local id = tostring(k.id or "")
    local a = tonumber(k.players) or tonumber(string.match(id, "^(%d+)"))
    local b = tonumber(k.rivals) or tonumber(string.match(id, "(%d+)$")) or a
    if a ~= nil and b ~= nil then
      return PT.text("FORMAT", {a = math.floor(a), b = math.floor(b)})
    end
    return "< " .. PT.kindLabel(k) .. " >"
  end

  -- the format on screen (n10)
  function PT.activeCol()
    for i, k in ipairs(PT.kinds()) do
      if PT.kindOn(k) and k.kind == (n10 or 0) then
        return i
      end
    end
    return 1
  end

  -- the format col of list kind `kind` (nil = not a format row)
  function PT.colOfKind(kind)
    if type(kind) ~= "number" then
      return nil
    end
    local col = kind - PT.ROW + 1
    if col >= 1 and col <= #PT.kinds() then
      return col
    end
    return nil
  end

  -- the format col of list row i (0-based; nil = not a format row)
  function PT.colAt(i)
    if type(i) ~= "number" or i < 0 or i >= (n or 0) then
      return nil
    end
    return PT.colOfKind(t[i + 1])
  end

  function PT.listIndex()
    local ok, idx = pcall(funcLuaMenuCommand, 2603265800, PT.LIST)
    return ok and idx or nil
  end

  -- the format col of the focused list row (nil = the focus is not on a format row). n6 = the retail «layer with the
  -- focus» (OnChangeFocus / MoveToOtherLayer keep it; 0 before the first focus change, when the list has it). Not
  -- CMND_IS_CTRL_FOCUS_ACTIVE: the retail OnEnter turns the list's control focus off for the decide.
  function PT.focusedCol()
    if n6 ~= nil and n6 ~= 0 and n6 ~= PT.LIST then
      return nil
    end
    return PT.colAt(PT.listIndex())
  end

  function PT.rowFocused()
    return PT.focusedCol() ~= nil
  end

  -- the format the line and the guard talk about: the focused format row's, else the format on screen
  function PT.curCol()
    return PT.focusedCol() or PT.activeCol()
  end

  -- a format row's text: the format's name («11v11», text keys evt_pt_kind_*)
  function PT.rowText(col)
    local k = PT.kinds()[col or PT.activeCol()]
    if type(k) ~= "table" then
      return ""
    end
    return PT.kindLabel(k)
  end

  -- every format row's text (a refresh of the list may have rewritten them)
  function PT.drawRow()
    if not EVT_PACHANGA or type(SetTeamDockListItemText) ~= "function" then
      return
    end
    for i = 0, (n or 0) - 1 do
      local col = PT.colAt(i)
      if col ~= nil then
        pcall(SetTeamDockListItemText, i, PT.rowText(col))
      end
    end
  end

  -- THE guard of the type switch (every path: OnEnter on the row, PT.switch from OnDecideFocus or a wrapper).
  -- col = the column asked for. true = switch to kinds[col].kind; false, why. quiet = no sound / message (PT.switch:
  -- OnEnter already answered this press).
  function PT.gate(col, quiet)
    local ok, why = PT.canSwitch()
    local k = PT.kinds()[col or PT.curCol()]
    local say = nil
    if not ok then
      if why == "not standalone" then
        say = "ONLY_TITLE"
      end
    elseif not PT.kindOn(k) then
      ok, why = false, "locked " .. tostring(k and k.id)
    elseif k.kind == (n10 or 0) then
      ok, why = false, "same"
    elseif k.kind == 0 and not PT.canReset() then
      ok, why, say = false, "no include reset (loader)", "NO_LOADER"
    end
    if ok then
      return true
    end
    PT.log("switch refused", why, quiet and "(decide)" or "")
    if not quiet and why ~= "same" then
      funcLuaCommand(PT.SOUND, PT.SE_NG)
      if say ~= nil then
        PT.say(PT.text(say))
      end
    end
    return false, why
  end

  function PT.greyRow()
    local ok, why = PT.canSwitch()
    if ok then
      return
    end
    for i = 0, (n or 0) - 1 do
      if PT.colAt(i) ~= nil then
        pcall(funcLuaMenuCommand, 4231609516 --[[CMND_SET_LAYER_MODEL_ALPHA?]], PT.LIST, i, 0, 0.5)
        pcall(funcLuaMenuCommand, 1126837159 --[[CMND_SET_MENU_TEXT_ALPHA?]], PT.LIST, i, 931545948 --[[_text_list01_on]], 0.5)
        pcall(funcLuaMenuCommand, 1126837159 --[[CMND_SET_MENU_TEXT_ALPHA?]], PT.LIST, i, 3705682548 --[[_text_list01_off]], 0.5)
      end
    end
  end

  -- "02 Punishment" (dock number as on screen + the name of that team), or «ninguno»
  function PT.describe(set, team)
    if not PT.isDock(set) then
      return PT.text("NONE")
    end
    local name = ""
    if type(GetTeamName) == "function" then
      local ok, r = pcall(GetTeamName, set, team)
      if ok and type(r) == "string" then
        name = r
      end
    end
    return string.format("%02d", set - 1) .. (name ~= "" and (" " .. name) or "")
  end

  function PT.activeLine()
    local vs = funcLuaCommand(PT.GET_VS)
    local line = PT.text("LINE", {match = PT.describe(vs, 0), pachanga = PT.describe(PT.active, 1)})
    local ok, why = PT.canSwitch()
    if not ok and why == "not standalone" then
      line = line .. " " .. PT.text("ONLY_TITLE")
    elseif ok and not PT.kindOn(PT.kinds()[PT.curCol()]) then
      line = PT.text("KIND_LOCKED")  -- the cursor is on a locked type
    end
    pcall(funcLuaMenuCommand, PT.SET_TEXT, PT.GUIDE_LINE, PT.GUIDE_NODE, line, 0)
  end

  function PT.header()
    if not PT.pachanga() then
      return
    end
    local base
    if type(UTIL_TB) == "table" and UTIL_TB.ready and type(UTIL_TB.headerText) == "function" then
      local ok, r = pcall(UTIL_TB.headerText)
      base = ok and r or nil
    end
    if type(base) ~= "string" then
      local ok, r = pcall(funcLuaCommand, PT.TEXT_GET, PT.TEXT_HEADER)
      base = (ok and type(r) == "string") and r or "Plantilla de equipo"
    end
    pcall(funcLuaMenuCommand, PT.SET_HEADER, 5, base .. " · " .. PT.text("HEADER"))
  end

  -- pachanga mode: n4 (the dock compared with n5 by the retail marks) = the active pachanga dock
  function PT.marks()
    if not PT.pachanga() then
      return
    end
    n4 = PT.active
    pcall(UpdateViewTeamDockNo)
    pcall(SetActiveDockBackground, n4 == n5)
    pcall(SetVisibleHeaderTeamDoc, true, n5)
  end

  function PT.flags()
    if PT.loader then
      pcall(funcLuaCommand, PT.FLAGS)
    end
  end

  -- show dock `want` instead of the one the retail OnInit chose (before the layers open)
  function PT.moveTo(want)
    if not PT.isDock(want) or want == n5 then
      return
    end
    n5 = want
    pcall(SetShowTeamDockNo, n5)
    pcall(function()
      SetFormationId(GetTeamDockFormationId())
    end)
  end

  -- the list: «Equipar todo» out, the format rows first (one per enabled format, in EVT_PT_KINDS order)
  if EVT_PACHANGA and type(t) == "table" and type(t2) == "table" then
    for i = #t, 1, -1 do
      if t[i] == PT.EQUIP_ALL or PT.colOfKind(t[i]) ~= nil then
        table.remove(t, i)
      end
    end
    local opts = PT.options()
    for p = #opts, 1, -1 do
      local kind = PT.ROW + opts[p] - 1
      table.insert(t, 1, kind)
      t2[kind + 1] = {itemName = PT.T.MATCH, itemExplation = PT.T.HELP}
    end
  end

  -- starters of the 5v5 team of `set` (the 5 pitch positions; bench and support do not count). Retail mapping of the
  -- formation include: position i -> member index (1721292418), member -> character handle (1720957768 .., 0).
  function PT.starters(set)
    local c = 0
    for i = 0, 4 do
      local ok, idx = funcLuaCommand(1721292418, set, 1, i)
      if not ok or type(idx) ~= "number" then
        idx = i
      end
      local ok2, h = funcLuaCommand(1720957768, set, 1, idx, 0)
      if ok2 and type(h) == "number" and h ~= 0 then
        c = c + 1
      end
    end
    return c
  end

  -- «Establecer como equipo activo» in pachanga mode
  function PT.setActive()
    if n4 == n5 then
      return
    end
    if not PT.loader then
      funcLuaCommand(PT.SOUND, PT.SE_NG)
      PT.message(PT.text("NO_LOADER"))
      return
    end
    if type(CanActiveTeam) == "function" and not CanActiveTeam(n5) then
      funcLuaCommand(PT.SOUND, PT.SE_NG)
      return
    end
    -- complete = the 5 starters (Nacho 2026-09-28: bench / support are optional). The retail «can be the active team»
    -- rule (1104634465) is not used: it answered false for dock 01 with 5 starters + 11 on the bench.
    local starters = PT.starters(n5)
    local code = funcLuaCommand(PT.VALID, n5, 1, false)
    if starters < 5 or (type(code) == "number" and code > 0 and code < 11) then
      PT.log("not complete", n5, "starters", starters, "code", tostring(code))
      funcLuaCommand(PT.SOUND, PT.SE_NG)
      PT.message(PT.text("NEED5"))
      return
    end
    local ok, r, c = pcall(funcLuaCommand, PT.SET, n5)
    if not ok or r ~= true then
      PT.log("set refused", n5, tostring(r), tostring(c))
      funcLuaCommand(PT.SOUND, PT.SE_NG)
      return
    end
    PT.active = n5
    n4 = n5
    funcLuaCommand(PT.SOUND, PT.SE_OK)
    pcall(UpdateViewTeamDockNo)
    local name = ""
    if type(GetTeamName) == "function" then
      local ok2, s = pcall(GetTeamName, n5, 1)
      name = (ok2 and type(s) == "string") and s or ""
    end
    PT.message(PT.text("NOW", {n = string.format("%02d", n5 - 1), team = name}))
    pcall(SetActiveDockBackground, true)
    pcall(SetVisibleHeaderTeamDoc, true, n5)
    PT.log("active pachanga", n5)
  end

  -- the kind keys of the formation screen / plate (both kinds): none may outlive the screen they were left for
  function PT.clearKind()
    PT.param(PT.KEY_KIND, nil)
    PT.param(PT.KEY_PLATE_KIND, nil)
    for _, k in ipairs(PT.KEY_PF) do
      PT.param(k, nil)
    end
    for _, k in ipairs(PT.KEY_PF11) do
      PT.param(k, nil)
    end
  end

  -- the formation INCLUDE keeps the 5v5 values of two locals (n33 starters 5, n37 field height 40) after
  -- OnInitFormationCommon(..., false); the loader puts the 11v11 values back (CMND_EVT_PACHANGA_UPVAL on one of its
  -- functions: upvalues are shared). Probe: 0 = available, -1 = not.
  function PT.canReset()
    if not PT.loader or type(UpdateFormationReducedDrawingIconPos) ~= "function" then
      return false
    end
    local ok, r = pcall(funcLuaCommand, PT.UPVAL, UpdateFormationReducedDrawingIconPos)
    return ok and r == 0
  end

  -- Docks 02+ (sets 3..12): the 5v5 team is independent of the 11v11 team (Nacho 2026-09-28; the loader keeps them
  -- apart in the place / move command). The first time such a dock is shown in Pachanga, a 5v5 team that is only the
  -- retail auto-copy of its 11v11 team is emptied (CMND_EVT_PACHANGA_SPLIT, once per dock and bank). Dock 01 (set 2)
  -- keeps the retail link: same players in both teams.
  -- A dock's 5v5 template that is not a 5v5 team yet (its teamInfo[1] never used: in saves it can hold an old copy of
  -- the 11v11 team with an 11v11 formation, which the 5v5 field draws as 5 starters + a pile of bench cards) becomes an
  -- empty 5v5 template: no members (loader; not dock 01), the story's 5v5 formation, the 11v11 team's name.
  -- true = changed. A template emptied here gets the dock's shared identity back at once (PT.link, §9).
  function PT.ensure5(set)
    local changed = PT.ensure5core(set)
    if changed and type(PT.link) == "function" then
      PT.link(set)
    end
    return changed
  end

  function PT.ensure5core(set)
    if not PT.isDock(set) or not PT.loader then
      return false
    end
    local changed = false
    PT.clearTS(set)
    if set ~= 2 then
      local okS, n = pcall(funcLuaCommand, PT.SPLIT, set)
      if okS and type(n) == "number" and n > 0 then
        changed = true
        PT.log("5v5 team split from the 11v11 team", set, n)
        PT.refresh()
      end
    end
    local ok, f = funcLuaCommand(PT.GET_INFO, set, 1, 4)
    if ok and PT.FORM5[f] then
      return changed
    end
    local r = set ~= 2 and funcLuaCommand(PT.INIT, set) or 0
    funcLuaCommand(PT.SET_INFO, set, 1, 3, PT.FORM5_DEFAULT)
    local ok2, name = funcLuaCommand(PT.GET_INFO, set, 0, 6)
    if ok2 and type(name) == "string" and name ~= "" then
      funcLuaCommand(PT.SET_INFO, set, 1, 0, name)
    end
    PT.log("5v5 template initialised", set, tostring(f), tostring(r))
    return true
  end

  -- the dock's own L1 / R1 refresh (as UTIL_TB.refresh) plus the list labels
  function PT.refreshAll()
    local function try(f, ...)
      if type(f) == "function" then
        local ok, e = pcall(f, ...)
        if not ok then
          PT.log("refresh error", tostring(e))
        end
      end
    end
    try(SetupMemberCharaStHdlList, n5)
    try(SetShowTeamDockNo, n5)
    try(SetupTeamPower, n5)
    try(function()
      SetFormationId(GetTeamDockFormationId())
    end)
    try(SetVisibleHeaderTeamDoc, true, n5)
    for i = 0, (n or 0) - 1 do
      try(SetupTeamDockListItem, i)
      try(UpdateViewTeamDockListItem, i)
    end
    try(UpdateViewMenuByLock)
    try(funcLuaMenuCommand, 1195645349 --[[CMND_UPDATE_SYNERGY_BUTTON?]], 1179455358 --[[team00_17_synergy_attachment_button_pillar]], 0, n5, n10)
    try(funcLuaMenuCommand, 1195645349 --[[CMND_UPDATE_SYNERGY_BUTTON?]], 830633104 --[[team00_17_synergy_attachment_button_flag]], 0, n5, n10)
    try(SetupTeamDockTeamNameBar)
    try(UpdateViewTeamDockNo)
    try(SetActiveDockBackground, n4 == n5)
    try(UpdateTeamBuildTypeInfo, n5, n10)
    flag3 = true                     -- Step -> UpdateFormationInfo (cards on the pitch)
  end

  -- The card positions of the pitch are written once, in OnSetupCharaCardLayer (menu setup): slots < n33 get their
  -- formation offset (SetupFormationIconPosition), the others keep the layout's rest offset and sit on their attach
  -- locator. After 11v11 -> 5v5 in place the 5v5 field re-attaches cards 5..15 to its bench locators
  -- (_pos_sub_atc01..11) and 16..18 to the support ones, but cards 5..10 still carry their 11v11 STARTER offsets (the
  -- refresh only re-places slots < 5): they land off the bench (on the goalkeeper, over EQUIPACIÓN, off the right
  -- edge, stacked on the bench row). Put every non-starter card (and its blank) back to the rest offset, read from
  -- card 18 (a support slot in both kinds, never moved by the INCLUDE). 5v5 -> 11v11 needs nothing: slots < 11 are
  -- re-placed and 11..18 were never moved.
  PT.CARD, PT.BLANK = 1973487846, 3571911991   -- team00_01_chara_card_for_soccer / team00_01_p1_chara_card_blank
  PT.GET_POS, PT.SET_POS, PT.EXISTS_LAYER = 2834507455, 1389957207, 262659071
  function PT.benchRest()
    local moved = 0
    for _, L in ipairs({PT.CARD, PT.BLANK}) do
      local ok, x, y, z = pcall(funcLuaMenuCommand, PT.GET_POS, L, 18)
      if not ok or type(x) ~= "number" then
        x, y, z = 0, 0, 0
      end
      for i = 5, 18 do
        if funcLuaMenuCommand(PT.EXISTS_LAYER, L, i) == true then
          funcLuaMenuCommand(PT.SET_POS, L, x, y or 0, z or 0, i)
          moved = moved + 1
        end
      end
    end
    return moved
  end

  -- 11v11-only layers of the pitch: the dock's OnOpenLayer(field) opens the nickname button and the seasonal cap plate
  -- for either field, but only soccer11_02 attaches them (the story's 5v5 dock opens them for soccer11_02 only,
  -- rpg_team_dock_menu_inc): on the 5v5 field they would stay where the 11v11 field left them.
  PT.ONLY11 = {209828247 --[[team00_16_nickname]], 3266940395 --[[vroad02_03_seasonal_cap_plate_small]]}
  function PT.close11()
    for _, L in ipairs(PT.ONLY11) do
      if funcLuaMenuCommand(2640875187 --[[CMND_IS_OPEN_LAYER]], L) then
        funcLuaMenuCommand(1273612389 --[[CMND_CLOSE_LAYER]], L)
      end
    end
  end

  -- the player plate VM looks cards up in the team of the pitch (graft pachanga_plate)
  function PT.plateKind(kind)
    local ok, r = pcall(funcLuaCommand, 830228314, PT.PLATE_MENU, "EVT_PT_PlateKind", kind, n5)
    PT.log("plate team kind", kind, "dock", n5, tostring(ok), tostring(r))
  end

  -- Pachanga: no synergies. Their dock layers are hidden and cannot take the focus (their decide / enter is refused
  -- below); the 5v5 team's synergy slots are emptied (PT.clearTS), so they do not reach a 5v5 match. Supertácticas are
  -- kept (2026-09-30): retail 5v5 teams carry them (the tactics picker has its own 5v5 rule), so their slots stay.
  function PT.hideTS()
    for L in pairs(PT.NO5) do
      local n = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], L) or 1
      for i = 0, math.max(n, 1) - 1 do
        pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], L, i, false)
      end
      pcall(funcLuaMenuCommand, 3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS?]], L, false)
    end
  end

  -- Partido after Pachanga (in place): the layers hideTS hid (and the tactics, hidden by the builds before 2026-09-30)
  -- are shown and focusable again before the refresh; the retail synergy update then sets their own state
  function PT.showTS()
    local all = {}
    for L in pairs(PT.NO5) do
      all[#all + 1] = L
    end
    for _, L in ipairs(PT.TACTICS) do
      all[#all + 1] = L
    end
    for _, L in ipairs(all) do
      if funcLuaMenuCommand(2640875187 --[[CMND_IS_OPEN_LAYER]], L) then
        local n = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], L) or 1
        for i = 0, math.max(n, 1) - 1 do
          pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], L, i, true)
        end
      end
      pcall(funcLuaMenuCommand, 3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS?]], L, true)
    end
  end

  function PT.clearTS(set)
    if not PT.isDock(set) then
      return
    end
    for kind = 0, 1 do
      pcall(funcLuaCommand, PT.SET_INFO, set, 1, 9, 0, kind)       -- synergy flag / pillar emptied (retail toggle)
    end
  end

  -- IN PLACE: the dock never closes (a closed standalone dock lets the field under it start: 2026-09-28 log, field HUD
  -- over the dock). The retail «team name bar» layer owns the pitch: closing it closes tactics, formation style, kit,
  -- the field base and the 19 cards (OnCloseLayer -> CloseCommonSoccerFormationUI); the team kind is switched
  -- (n10, n11, the INCLUDE state) and opening it again builds them for the other kind (OnOpenLayer ->
  -- OpenCommonSoccerFormationUI). Runs in the OnDecideFocus callback coroutine.
  function PT.rebuild(to)
    local BAR = 1044086265           -- team01_04_team_name_bar
    funcLuaMenuCommand(1273612389 --[[CMND_CLOSE_LAYER]], BAR)
    for _ = 1, 90 do
      if not funcLuaMenuCommand(2640875187 --[[CMND_IS_OPEN_LAYER]], BAR)
          and not funcLuaMenuCommand(2640875187 --[[CMND_IS_OPEN_LAYER]], n11) then
        break
      end
      coroutine.yield()
    end
    if to == 0 then
      PT.clearKind()                 -- a 5v5 kind left by the Pachanga formation screen must not reach Partido
      local r = funcLuaCommand(PT.UPVAL, UpdateFormationReducedDrawingIconPos, 5, 11, 40, 94)
      PT.log("include reset", tostring(r))
      SetFormationLayer(3321884270 --[[soccer11_02_formation_frame]])
      SetupTeamMemberNumMax(19)
    end
    if to == 1 then
      PT.refresh()
      PT.ensure5(n5)
    end
    n10 = to
    n11 = to == 1 and 3518110933 --[[mainmenu04_10_formation_base]] or 3321884270 --[[soccer11_02_formation_frame]]
    OnInitFormationCommon(GetTeamDockFormationId(), nil, n5, nil, nil, nil, to == 1)
    PT.plateKind(to)
    PT.refresh()
    n4 = to == 1 and PT.active or funcLuaCommand(PT.GET_VS)
    funcLuaMenuCommand(629267548 --[[CMND_OPEN_LAYER]], BAR)
    coroutine.yield()
    if to == 0 then
      PT.showTS()
    end
    PT.refreshAll()
    if to == 1 then
      PT.log("bench cards re-placed", PT.benchRest())
      PT.close11()
      PT.hideTS()
      PT.header()
    elseif type(UTIL_TB) == "table" and UTIL_TB.ready and type(UTIL_TB.header) == "function" then
      pcall(UTIL_TB.header)
    else
      local ok, s = pcall(funcLuaCommand, PT.TEXT_GET, PT.TEXT_HEADER)
      pcall(funcLuaMenuCommand, PT.SET_HEADER, 5, (ok and type(s) == "string") and s or "Plantilla de equipo")
    end
    PT.flags()
  end

  -- the selector (callback coroutine of OnDecideFocus; the retail OnEnter disabled the input and the list focus).
  -- col = the column decided (default: the row's cursor). PT.gate refuses here too: a refused press never rebuilds.
  function PT.switch(a1, col)
    col = col or PT.curCol()
    local function back()
      funcLuaMenuCommand(1558704558, PT.MENU_ID, true)
      funcLuaMenuCommand(3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS?]], a1, true)
    end
    if PT.busy then
      return                         -- one press = one switch (a second decide while the pitch is rebuilt)
    end
    if not PT.gate(col, true) then
      back()
      return
    end
    local to = PT.kinds()[col].kind
    if MENU_DEF.IsRequestToDisplayTeamDockMemberErrorMessage(nil, true, n10) then
      back()
      return
    end
    PT.busy = true
    PT.flags()
    -- no sound here: the engine already plays the list's decide sound for the row (it was heard twice)
    PT.log("switch", n10, "->", to, "dock", n5, "in place")
    funcLuaMenuCommand(1558704558, PT.MENU_ID, false)
    local ok, e = pcall(PT.rebuild, to)
    PT.busy = false
    if not ok then
      PT.log("switch error", tostring(e))
    end
    PT.log("switched", PT.pachanga() and "pachanga" or "partido", "dock", n5, "active", n4)
    back()
    PT.drawRow()
  end

  -- ================================================================================================================
  -- Shared identity of a dock's two templates (2026-09-30, Nacho: «vincula los datos compartidos»; doc §9).
  -- Partido k (teamInfo[0]) and Pachanga k (teamInfo[1]) of the same dock share the team name, the emblem, the kit
  -- (uniformId + the owned kit item: field, keeper, coach and manager outfits all come from it), the 4 supertácticas
  -- slots, the coach (position 19 + the team's director id) and the 3 managers (positions 16..18). Lineup (positions
  -- 0..15), formation, captain, team auras and synergies stay per template.
  -- Both copies must exist (the 11v11 match reads teamInfo[0], the 5v5 match teamInfo[1]); this block is the one place
  -- that keeps them equal. Per field, the side that changed since the last sync wins (EVT_PT_LINK_SNAP: the synced
  -- Partido value per bank and dock); a dock not synced yet in this VM, or changed on both sides, takes the Partido
  -- value. Runs at dock open (all 11 docks, before the retail OnInit builds the pitch), after a bank page (all 11),
  -- after every child menu / name edit / bank (the dock on screen) and at exit (all 11). An unmounted bank is synced
  -- when it is mounted (the bank swap moves whole sets: both templates travel together).
  -- Coach and managers are members: they are moved with the retail place command 193693077 (bank set 16 -> template),
  -- which keeps the other template intact only through the loader's split after-hook (team_banks, docks 02..11), so
  -- they are linked for docks 02..11 with the loader. Dock 01 keeps the retail link (same players in both teams).
  -- Off in the INAROGUE save (its dock links 11v11 / 5v5 itself, rogue_dock §26) and in story mode. Kill switch
  -- EVT_PT_LINK = false. Log lines "EVT pachanga link".
  if EVT_PT_LINK == nil then
    EVT_PT_LINK = true
  end
  if EVT_PT_LINK_SNAP == nil then
    EVT_PT_LINK_SNAP = {}
  end
  PT.L = {
    MOVE = 193693077,                -- (toSet, pos, fromSet, hdl, team): retail place / move; set 16 = the bank
    POS_IDX = 1721292418,            -- (set, team, pos) -> ok, member index
    IDX_HDL = 1720957768,            -- (set, team, member, 0 | 1) -> ok, handle | position
    DIRECTOR = 1108596907,           -- (set, team, director id): the coach id of the team (+0x288)
    CHARA = 1131797651,              -- (hdl, 4) -> director id of a character
    TEAM_UNIFORM = 1598711521,       -- away_kit CMND_EVT_TEAM_UNIFORM (set, team [, uniformId]) -> ok, uniformId
    TACTIC_INFO = 2774302575,        -- CMND_GET_SPECIAL_TACTICS_INFO (id, 10) -> ok, refused in a 5v5 team
    PLAY_MODE = 3004482920,
    BANK = 16, COACH = 19, MEMBERS = {16, 17, 18, 19}, SLOTS = 4,
    logs = 0,
  }

  function PT.call(cmd, ...)
    local r = PT.pack(pcall(funcLuaCommand, cmd, ...))
    if not r[1] then
      return nil
    end
    return table.unpack(r, 2, r.n)
  end

  function PT.llog(...)
    if PT.L.logs < 60 then
      PT.L.logs = PT.L.logs + 1
      pcall(funcLuaCommand, PT.LOG, "EVT pachanga link", ...)
    end
  end

  function PT.canLink()
    if not EVT_PACHANGA or not EVT_PT_LINK or PT.inRogue() then
      return false
    end
    return PT.call(PT.L.PLAY_MODE) ~= 2
  end

  function PT.num(ok, v)
    if ok == true and type(v) == "number" then
      return v
    end
    return 0
  end

  -- handle at a position of template t (0 = empty); the position is read back to be sure
  function PT.memberAt(set, t, pos)
    local ok, idx = PT.call(PT.L.POS_IDX, set, t, pos)
    if ok ~= true or type(idx) ~= "number" or idx < 0 then
      return 0
    end
    local okh, h = PT.call(PT.L.IDX_HDL, set, t, idx, 0)
    if okh ~= true or type(h) ~= "number" or h == 0 then
      return 0
    end
    local okp, p = PT.call(PT.L.IDX_HDL, set, t, idx, 1)
    if okp == true and type(p) == "number" and p ~= pos then
      return 0
    end
    return h
  end

  function PT.memberLink(set)
    return PT.loader == true and set >= 3 and set <= 12
  end

  -- the identity of template t: name, emblem, kit {uniformId, item}, tac[1..4], mem[16..19]
  function PT.readId(set, t)
    local id = {tac = {}, mem = {}}
    local ok, s = PT.call(PT.GET_INFO, set, t, 6)
    id.name = (ok == true and type(s) == "string") and s or ""
    id.emblem = PT.num(PT.call(PT.GET_INFO, set, t, 5))
    id.kit = {PT.num(PT.call(PT.GET_INFO, set, t, 7)), PT.num(PT.call(PT.GET_INFO, set, t, 12))}
    for i = 1, PT.L.SLOTS do
      id.tac[i] = PT.num(PT.call(PT.GET_INFO, set, t, 9, i - 1))
    end
    if PT.memberLink(set) then
      for _, p in ipairs(PT.L.MEMBERS) do
        id.mem[p] = PT.memberAt(set, t, p)
      end
    end
    return id
  end

  -- a supertáctica the 5v5 refuses (the retail rule of the tactics picker) stays out of the Pachanga template
  function PT.tac5(v)
    if v == 0 then
      return 0
    end
    local ok, no = PT.call(PT.L.TACTIC_INFO, v, 10)
    if ok and no then
      return 0
    end
    return v
  end

  local function same(a, b)
    if type(a) == "table" and type(b) == "table" then
      return a[1] == b[1] and a[2] == b[2]
    end
    return a == b
  end
  local function plain(v)
    return v
  end
  local function sameArr(x, y)
    for i = 1, PT.L.SLOTS do
      if x[i] ~= y[i] then
        return false
      end
    end
    return true
  end

  -- winner of one field: nil = in sync, 0 = Partido -> Pachanga, 1 = Pachanga -> Partido. a / b = Partido / Pachanga
  -- value, s = the synced Partido value (nil: not synced yet), norm = the Pachanga form of a Partido value
  function PT.side(a, b, s, norm)
    norm = norm or plain
    if same(norm(a), b) then
      return nil
    end
    if s ~= nil and same(a, s) and not same(b, norm(s)) then
      return 1
    end
    return 0
  end

  function PT.putKit(set, t, kit)
    local uid, inv = kit[1], kit[2]
    if inv ~= 0 then
      PT.call(PT.SET_INFO, set, t, 2, inv)             -- the owned kit item (SetTeamUniform: item + home uniform)
    elseif uid == 0 then
      PT.call(PT.SET_INFO, set, t, 7, 0)               -- no kit
    end
    if uid ~= 0 and PT.num(PT.call(PT.GET_INFO, set, t, 7)) ~= uid then
      PT.call(PT.L.TEAM_UNIFORM, set, t, uid)          -- the Visitante twin, or a kit without its item
    end
  end

  function PT.putTac(set, t, vals)
    local cur = {}
    for i = 1, PT.L.SLOTS do
      cur[i] = PT.num(PT.call(PT.GET_INFO, set, t, 9, i - 1))
    end
    for i = 1, PT.L.SLOTS do                           -- empty the changed slots first: a tactic may change slot
      if cur[i] ~= vals[i] and cur[i] ~= 0 then
        PT.call(PT.SET_INFO, set, t, 4, 0, i - 1)
      end
    end
    for i = 1, PT.L.SLOTS do
      if cur[i] ~= vals[i] and vals[i] ~= 0 then
        PT.call(PT.SET_INFO, set, t, 4, vals[i], i - 1)
      end
    end
  end

  function PT.putMember(set, t, pos, h)
    local cur = PT.memberAt(set, t, pos)
    if cur == h then
      return
    end
    if pos == PT.L.COACH and cur ~= 0 then
      PT.call(PT.L.DIRECTOR, set, t, 0)                -- as the retail bank does before the coach leaves
    end
    if h ~= 0 then
      PT.call(PT.L.MOVE, set, pos, PT.L.BANK, h, t)    -- into this template only (loader after-hook keeps the other)
    else
      PT.call(PT.L.MOVE, PT.L.BANK, pos, set, cur, t)  -- the occupant goes back to the bank
    end
    if pos == PT.L.COACH and h ~= 0 then
      local d = PT.call(PT.L.CHARA, h, 4)
      if type(d) == "number" and d ~= 0 then
        PT.call(PT.L.DIRECTOR, set, t, d)
      end
    end
  end

  -- sync one dock; true = something was written
  function PT.link(set)
    if not PT.isDock(set) or not PT.canLink() then
      return false
    end
    local key = (PT.bank or 1) * 100 + set
    local snap = EVT_PT_LINK_SNAP[key] or {tac = {}, mem = {}}
    local a, b = PT.readId(set, 0), PT.readId(set, 1)
    local did = {}
    local function note(what, side)
      did[#did + 1] = what .. (side == 1 and "<5v5" or ">5v5")
    end
    local sd = PT.side(a.name, b.name, snap.name)
    if sd == 0 then
      PT.call(PT.SET_INFO, set, 1, 0, a.name)
    elseif sd == 1 then
      PT.call(PT.SET_INFO, set, 0, 0, b.name)
    end
    if sd then note("name", sd) end
    sd = PT.side(a.emblem, b.emblem, snap.emblem)
    if sd == 0 then
      PT.call(PT.SET_INFO, set, 1, 1, a.emblem)
    elseif sd == 1 then
      PT.call(PT.SET_INFO, set, 0, 1, b.emblem)
    end
    if sd then note("emblem", sd) end
    sd = PT.side(a.kit, b.kit, snap.kit)
    if sd == 0 then
      PT.putKit(set, 1, a.kit)
    elseif sd == 1 then
      PT.putKit(set, 0, b.kit)
    end
    if sd then note("kit", sd) end
    local t0, t1, tw = {}, {}, false
    for i = 1, PT.L.SLOTS do
      t0[i], t1[i] = a.tac[i], b.tac[i]
      local s = PT.side(a.tac[i], b.tac[i], snap.tac[i], PT.tac5)
      if s == 0 then
        t1[i], tw = PT.tac5(a.tac[i]), true
      elseif s == 1 then
        t0[i], tw = b.tac[i], true
      end
    end
    if tw then
      if not sameArr(t0, a.tac) then
        PT.putTac(set, 0, t0)
        note("tactics", 1)
      end
      if not sameArr(t1, b.tac) then
        PT.putTac(set, 1, t1)
        note("tactics", 0)
      end
    end
    if PT.memberLink(set) then
      -- decided on the reads above, then placed (a move empties the member's old position) before emptied
      local plan = {}
      for _, p in ipairs(PT.L.MEMBERS) do
        local s = PT.side(a.mem[p], b.mem[p], snap.mem[p])
        if s == 0 then
          plan[#plan + 1] = {1, p, a.mem[p]}
        elseif s == 1 then
          plan[#plan + 1] = {0, p, b.mem[p]}
        end
      end
      for pass = 1, 2 do
        for _, w in ipairs(plan) do
          if (pass == 1) == (w[3] ~= 0) then
            PT.putMember(set, w[1], w[2], w[3])
            note((w[2] == PT.L.COACH and "coach" or ("manager" .. w[2])), w[1] == 0 and 1 or 0)
          end
        end
      end
    end
    -- the synced state: what both templates hold now; a field still apart (a refused write) is not recorded, so the
    -- next sync takes the Partido value again instead of reading the refusal as a Pachanga edit
    if #did > 0 then
      a, b = PT.readId(set, 0), PT.readId(set, 1)
    end
    local new = {tac = {}, mem = {}}
    if same(a.name, b.name) then new.name = a.name end
    if same(a.emblem, b.emblem) then new.emblem = a.emblem end
    if same(a.kit, b.kit) then new.kit = a.kit end
    for i = 1, PT.L.SLOTS do
      if same(PT.tac5(a.tac[i]), b.tac[i]) then new.tac[i] = a.tac[i] end
    end
    for _, p in ipairs(PT.L.MEMBERS) do
      if a.mem[p] ~= nil and same(a.mem[p], b.mem[p]) then new.mem[p] = a.mem[p] end
    end
    EVT_PT_LINK_SNAP[key] = new
    if #did > 0 then
      PT.llog("dock", string.format("%02d", set - 1), "bank", PT.bank or 1, table.concat(did, " "))
      return true
    end
    return false
  end

  -- every dock of the mounted bank; number of docks changed
  function PT.linkAll(why)
    if not PT.canLink() then
      return 0
    end
    local n = 0
    for set = 2, 12 do
      local ok, r = pcall(PT.link, set)
      if not ok then
        PT.llog("error", set, tostring(r))
      elseif r then
        n = n + 1
      end
    end
    if n > 0 then
      PT.flags()
    end
    PT.llog(why or "all", "bank", PT.bank or 1, "docks changed", n)
    return n
  end

  -- the dock on screen, after something may have edited it (child menu, name, bank): redraw when it changed
  function PT.linkShown()
    local ok, r = pcall(PT.link, n5)
    if not ok then
      PT.llog("error", n5, tostring(r))
      return
    end
    if r then
      PT.flags()
      pcall(PT.refreshAll)
      if PT.pachanga() then
        pcall(PT.hideTS)
        PT.marks()
        PT.header()
      end
    end
  end

  -- ================================================================================================================
  -- Leaving the dock (bug 2026-09-30, Nacho: dock in «Tipo: Pachanga» on dock 01 / 02 = the active pachanga team,
  -- active Partido team 03; after leaving, the main menu «Mi equipo» showed 01 / 02). The «Mi equipo» banner of
  -- title_menu_2 is a group capture of teamInfo[0] of the byte vsUseTeamSet (party+0x9F10; nie.exe 0x1749B00 ->
  -- 0x174A840, re-captured when title_menu_2 opens), so it shows whatever set that byte holds when the title reloads
  -- the save that the standalone dock writes on exit (FuncOnBack: CMND_SAVE_GAME_DATA(0, true), CMND_GAME_RESET). The
  -- dock keeps the Partido team it opened with or the user chose (PT.vs) and, before the retail exit, puts it back in
  -- vsUseTeamSet if anything moved it (a pending pachanga-match restore is taken first), sets the in-place switch
  -- state back to the VS dock (n4) and deletes every key it or its children left in the parameter store.
  function PT.keepVs()
    local v = PT.call(PT.GET_VS)
    if type(v) == "number" then
      PT.vs = v
    end
  end

  function PT.leave()
    if not EVT_PACHANGA or PT.inRogue() then
      return
    end
    PT.linkAll("exit")
    local vs = PT.call(PT.GET_VS)
    local want = PT.vs
    if PT.loader then
      local ok, had, r = pcall(funcLuaCommand, PT.VS, 0)
      if ok and had == true and type(r) == "number" and r >= 0 and r < 16 then
        want = r
      end
    end
    if type(want) == "number" and want >= 0 and want < 16 and type(vs) == "number" and vs ~= want then
      funcLuaCommand(PT.SET_VS, want)
      PT.log("exit: VS team put back", vs, "->", want)
    end
    if PT.pachanga() then
      local v = PT.call(PT.GET_VS)
      if type(v) == "number" then
        n4 = v
      end
    end
    pcall(PT.clearKind)
    pcall(PT.param, PT.KEY_ACTIVE_DOCK, nil)
    pcall(PT.param, PT.KEY_BANK, nil)
    PT.log("exit", PT.pachanga() and "pachanga" or "partido", "dock", n5, "vs", tostring(PT.call(PT.GET_VS)),
      "pachanga", PT.active)
  end

  PT.wrap("OnInit", function(orig)
    return function(...)
      -- the shared identity is synced before the retail OnInit reads the dock (§9)
      PT.refresh()
      pcall(PT.linkAll, "open")
      local mode = PT.take(PT.KEY_MODE)
      local dock = PT.take(PT.KEY_DOCK)
      PT.start = nil
      if EVT_PACHANGA and type(mode) == "number" and not PT.inRogue()
          and funcLuaMenuCommand(2119959601) == true then
        if mode == 2 then
          PT.param(PT.KEY_KIND, 1)   -- the retail OnInit reads it: n10 = 1, 5v5 field
        end
        PT.start = dock
      end
      local r = PT.pack(orig(...))
      PT.refresh()
      if PT.loader then
        -- an interrupted «Desafío de fichaje» may have left the VS team on the pachanga dock
        local ok, had, vs = pcall(funcLuaCommand, PT.VS, 0)
        if ok and had == true and type(vs) == "number" and vs >= 0 and vs < 16 then
          if funcLuaCommand(PT.GET_VS) ~= vs then
            funcLuaCommand(PT.SET_VS, vs)
            PT.log("VS team restored after a trial", vs)
          end
          if not PT.pachanga() then
            n4 = funcLuaCommand(PT.GET_VS)
            pcall(SetActiveDockBackground, n4 == n5)
          end
        end
      end
      PT.keepVs()                    -- the Partido team this visit has to leave behind (PT.leave)
      if PT.pachanga() then
        local want = PT.start
        if not PT.isDock(want) and PT.isDock(PT.active) then
          want = PT.active
        end
        PT.moveTo(want)
        PT.ensure5(n5)
        PT.plateKind(1)
        n4 = PT.active
        pcall(SetVisibleHeaderTeamDoc, true, n5)
        pcall(SetActiveDockBackground, n4 == n5)
        PT.header()
      elseif PT.isDock(PT.start) then
        PT.moveTo(PT.start)
        pcall(SetVisibleHeaderTeamDoc, true, n5)
        pcall(SetActiveDockBackground, n4 == n5)
      end
      PT.flags()
      PT.pick, PT.child = nil, false
      PT.log("open", PT.pachanga() and "pachanga" or "partido", "dock", n5, "active", n4, "pachanga", PT.active,
        "loader", tostring(PT.loader))
      return table.unpack(r, 1, r.n)
    end
  end)

  -- the 5v5 field opening (Pachanga at open or after the switch): no 11v11-only layers on it
  PT.wrap("OnOpenLayer", function(orig)
    return function(a1, a2, ...)
      local r = PT.pack(orig(a1, a2, ...))
      if PT.pachanga() and a1 == n11 then
        pcall(PT.close11)
      end
      if PT.pachanga() and PT.NO5[a1] then
        pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], a1, a2 or 0, false)
        pcall(funcLuaMenuCommand, 3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS?]], a1, false)
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  PT.wrap("SetupTeamDockListItemText", function(orig)
    return function(a1, a2, ...)
      local col = EVT_PACHANGA and PT.colOfKind(a2) or nil
      if col ~= nil then
        SetTeamDockListItemText(a1, PT.rowText(col))
        return
      end
      return orig(a1, a2, ...)
    end
  end)

  PT.wrap("UpdateViewTeamDockListItem", function(orig)
    return function(...)
      local r = PT.pack(orig(...))
      PT.greyRow()
      return table.unpack(r, 1, r.n)
    end
  end)

  PT.wrap("UpdateViewMenuByLock", function(orig)
    return function(...)
      local r = PT.pack(orig(...))
      PT.greyRow()
      return table.unpack(r, 1, r.n)
    end
  end)

  PT.wrap("OnChangeFocus", function(orig)
    return function(a1, a2, ...)
      -- right on a format row is the retail move out of the list (no format cycling since 2026-10-19)
      local r = PT.pack(orig(a1, a2, ...))
      if PT.pachanga() and PT.NO5[a1] and type(OnChangeFocusCommon) == "function" then
        PT.log("focus moved off a hidden tactics / synergy layer", a1)
        pcall(OnChangeFocusCommon, PT.FORM_BOX, 0, true)
      end
      if EVT_PACHANGA and PT.rowFocused() then
        PT.activeLine()              -- on a format row: the active teams line (or why it cannot switch)
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  -- the queued messages of OnEnter (PT.say) run here
  PT.wrap("Step", function(orig)
    return function(...)
      local r = PT.pack(orig(...))
      if EVT_PACHANGA then
        PT.stepSay()
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  PT.wrap("OnEnter", function(orig)
    return function(a1, a2, ...)
      if PT.pachanga() and PT.NO5[a1] then
        funcLuaCommand(PT.SOUND, PT.SE_NG)
        return 1
      end
      -- a format row: refused here, at once (no yield: an OnEnter that yields is taken as accepted), sound and
      -- message by PT.gate; the message opens from Step
      local col = EVT_PACHANGA and a1 == PT.LIST and PT.colAt(a2) or nil
      if col ~= nil then
        if PT.busy or PT.co ~= nil or not PT.gate(col) then
          return 1
        end
        PT.pick = col                -- the format of this press, for its OnDecideFocus
      end
      if a1 == PT.NAME_FRAME then
        -- the retail name edit writes (n5, n10, 0): the other template of the dock takes the new name (§9); the
        -- keyboard's length is Utilities' (graft util_team_name)
        local r = PT.pack(orig(a1, a2, ...))
        PT.linkShown()
        return table.unpack(r, 1, r.n)
      end
      return orig(a1, a2, ...)
    end
  end)

  PT.wrap("OnDecideFocus", function(orig)
    return function(a1, a2, ...)
      local kind = nil
      if EVT_PACHANGA and a1 == PT.LIST and type(a2) == "number" then
        kind = t[a2 + 1]
      end
      local rowCol = PT.colOfKind(kind)
      if rowCol ~= nil then
        local col = PT.pick or rowCol  -- a decide without our OnEnter (a mouse click): the clicked row's format
        PT.pick = nil
        PT.switch(a1, col)           -- PT.gate again inside: a press OnEnter refused never switches
        return
      end
      if PT.pachanga() and PT.NO5[a1] then
        funcLuaCommand(PT.SOUND, PT.SE_NG)
        return
      end
      -- «Conf. de equipo» (build icon): «Bonificaciones de equipo» of the 5v5 team (EVT_Bonus5, §3.7)
      if PT.pachanga() and a1 == 721367678 --[[team00_14_build_type_icon]] and PT.isDock(n5) then
        local r = table.pack(EVT_Bonus5(n5, "dock", orig, a1, a2, ...))
        if not r[1] then
          funcLuaMenuCommand(1558704558, PT.MENU_ID, true)
          funcLuaMenuCommand(3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS?]], a1, true)
          return
        end
        return table.unpack(r, 2, r.n)
      end
      -- «Formación» (list row) and the FORMACIÓN box (formation picker): the retail opens team_dock_formation_menu
      -- without the team kind; in pachanga mode the formation screen and its personal plate edit the 5v5 team (the
      -- story's own keys; the formation menu reads and deletes 4081600465 in its OnInit, the plate 2419482555)
      local form = kind == 0 or a1 == PT.FORM_BOX
      local five = form and PT.pachanga()
      -- Partido (fix 2026-09-30, Nacho: Pachanga formation edited, back, «Tipo: Partido», «Formación» = still the 5v5
      -- editor, «Formación en Y» on 5 positions, the plate naming another player than the focused card): the retail
      -- passes no kind here, so the formation screen kept the 5v5 state of the Pachanga visit (a 4081600465 = 1 left
      -- behind by the 5v5 screen, which soccer_formation_menu puts back in its OnInit, or its VMs' 5v5 locals). The
      -- 11v11 kind is now passed explicitly, with the 11v11 keys of pachanga_formation (the VMs put themselves back in
      -- 11v11 mode). INAROGUE too (2026-10-06, Nacho: 5v5 -> 11v11 showed a 5-card 11v11 pitch with an empty
      -- FORMACIÓN box): its dock switches types, and without the 11v11 keys the formation screen kept the 5v5 list and
      -- committed a 5v5 formation (Formación en Y) to the 11v11 team.
      local eleven = form and EVT_PACHANGA and not five
      if five then
        PT.param(PT.KEY_KIND, 1)
        PT.param(PT.KEY_PLATE_KIND, 1)
        for _, k in ipairs(PT.KEY_PF) do
          PT.param(k, n5)
        end
        for _, k in ipairs(PT.KEY_PF11) do
          PT.param(k, nil)
        end
        PT.plateKind(1)
        PT.log("formation screen in 5v5 mode", kind == 0 and "list" or "box", "dock", n5)
      elseif eleven then
        PT.param(PT.KEY_KIND, 0)
        PT.param(PT.KEY_PLATE_KIND, 0)
        for _, k in ipairs(PT.KEY_PF) do
          PT.param(k, nil)
        end
        for _, k in ipairs(PT.KEY_PF11) do
          PT.param(k, n5)
        end
        PT.log("formation screen in 11v11 mode", kind == 0 and "list" or "box", "dock", n5)
      end
      PT.child = true                -- the dock waits for a child menu: Step reads no pad input meanwhile
      local r = PT.pack(pcall(orig, a1, a2, ...))
      PT.child = false
      if not r[1] then
        error(r[2], 0)
      end
      r = PT.pack(table.unpack(r, 2, r.n))
      if five or eleven then
        PT.clearKind()
        if PT.pachanga() then
          pcall(PT.hideTS)
        end
      end
      -- a child menu (emblem, kit, tactics, formation screen, bank, team name bar...) may have edited one template: the
      -- other one of the dock follows (§9)
      PT.linkShown()
      if kind ~= nil then
        PT.flags()
        PT.marks()
        PT.header()
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  PT.wrap("OnFunction", function(orig)
    return function(a1, a2, ...)
      if PT.pachanga() and a1 == PT.ACTIVE_FUNC and not PT.inRogue() then
        PT.setActive()
        return
      end
      local r = PT.pack(orig(a1, a2, ...))
      if a1 == PT.ACTIVE_FUNC and not PT.pachanga() then
        PT.keepVs()                  -- «Establecer como equipo activo» in Partido: the new VS team is the one to keep
      end
      if PT.pachanga() and a1 == PT.PAGE_FUNC then
        if PT.ensure5(n5) then
          PT.refreshAll()
        end
        PT.marks()
        pcall(PT.hideTS)
        PT.plateKind(1)
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  -- «Banco» in Pachanga: the bank shows and edits the dock's 5v5 team on the dock's own 5v5 pitch (graft pachanga_bank
  -- + pachanga_bank_build.py: layer evt_bank5_field). The dock only tells the bank which dock it opens on; Z / C in
  -- the bank follow on their own. Partido: the retail bank, nothing set.
  PT.wrap("OpenCharaBank", function(orig)
    return function(...)
      if not (PT.pachanga() and PT.isDock(n5)) then
        return orig(...)
      end
      PT.param(PT.KEY_BANK, n5)
      PT.log("bank in 5v5 view", n5)
      local r = PT.pack(pcall(orig, ...))
      PT.param(PT.KEY_BANK, nil)
      pcall(PT.refreshAll)
      pcall(PT.hideTS)
      PT.plateKind(1)
      if not r[1] then
        PT.log("bank error", tostring(r[2]))
        return
      end
      return table.unpack(r, 2, r.n)
    end
  end)

  PT.wrap("FuncOnBack", function(orig)
    return function(...)
      local ok, e = pcall(PT.leave)  -- before the retail exit (the standalone dock saves the game there)
      if not ok then
        PT.log("exit error", tostring(e))
      end
      PT.flags()
      return orig(...)
    end
  end)

  PT.wrap("SwapHeaderTextBack", function(orig)
    return function(...)
      local r = PT.pack(orig(...))
      PT.header()
      return table.unpack(r, 1, r.n)
    end
  end)

  -- AT / DF of the team on screen (retail: always team 0)
  PT.wrap("SetupTeamPower", function(orig)
    return function(a1, ...)
      if not PT.pachanga() then
        return orig(a1, ...)
      end
      local ok, at, df = funcLuaCommand(1033065575 --[[CMND_GET_TEAM_SET_INFO?]], a1, 1, 14)
      local L = 859123864 --[[mainmenu04_06_team_atdf]]
      local p = funcLuaMenuCommand(1927054058 --[[CMND_SEARCH_PRIM_INDEX?]], L, 0, 3699456408)
      funcLuaMenuCommand(3609943765, L, 0, p, at)
      p = funcLuaMenuCommand(1927054058 --[[CMND_SEARCH_PRIM_INDEX?]], L, 0, 4110270132)
      funcLuaMenuCommand(3609943765, L, 0, p, df)
      funcLuaMenuCommand(1233047821, L, 0, 3699456408, true)
      funcLuaMenuCommand(1233047821, L, 0, 4110270132, true)
    end
  end)

  -- header dock plate: its check mark = the active team of the type on screen
  PT.wrap("SetVisibleHeaderTeamDoc", function(orig)
    return function(a1, a2, a3, ...)
      if not PT.pachanga() then
        return orig(a1, a2, a3, ...)
      end
      local m = 811496143 --[[soccer_top_menu]]
      if a3 == nil then
        local p = MENU_DEF.GetParentMenuID(2049316981 --[[soccer_formation_menu]])
        if p ~= 0 then
          m = p
        end
      else
        m = a3
      end
      funcLuaMenuCommand(4108281619, m, a2, a1, a2 == PT.active)
    end
  end)

  -- the retail «team must be valid to leave» check looks at the VS dock; for the 5v5 kind it is the active pachanga
  -- dock (no active pachanga dock = nothing to check)
  if type(MENU_DEF) == "table" and type(MENU_DEF.IsRequestToDisplayTeamDockMemberErrorMessage) == "function"
      and not EVT_PT_WRAPPED[MENU_DEF.IsRequestToDisplayTeamDockMemberErrorMessage] then
    local prev = MENU_DEF.IsRequestToDisplayTeamDockMemberErrorMessage
    local w = function(a1, a2, a3, a4)
      if a1 == nil and a3 == 1 and PT.pachanga() then
        if not PT.isDock(PT.active) then
          return false
        end
        return prev(PT.active, a2, a3, a4)
      end
      return prev(a1, a2, a3, a4)
    end
    EVT_PT_WRAPPED[w] = true
    MENU_DEF.IsRequestToDisplayTeamDockMemberErrorMessage = w
  end

  -- Utilities' team bank pages (UTIL_TB, mod utilities): after a page swap the active pachanga dock is the one of the
  -- new page. Applied now when UTIL_TB exists (Utilities' hook file ran first: it is lua_early and IF requires it),
  -- and queued in UTIL_TB_HOOKS for a VM where it runs later.
  local function EVT_PT_HookBanks(TB)
    for _, k in ipairs({"refresh", "header"}) do
      local f = TB[k]
      if type(f) == "function" and not EVT_PT_WRAPPED[f] then
        local w
        if k == "refresh" then
          w = function(...)
            -- a bank was mounted: its 11 docks get their shared identity synced (§9) before the dock redraws
            PT.refresh()
            pcall(PT.linkAll, "bank")
            if PT.pachanga() then
              PT.ensure5(n5)
            end
            local r = PT.pack(f(...))
            PT.keepVs()              -- the bank swap restores that bank's own VS team
            if PT.pachanga() then
              PT.refresh()
              PT.marks()
              pcall(PT.hideTS)
              PT.plateKind(1)
            end
            return table.unpack(r, 1, r.n)
          end
        else
          w = function(...)
            local r = PT.pack(f(...))
            PT.header()
            return table.unpack(r, 1, r.n)
          end
        end
        EVT_PT_WRAPPED[w] = true
        TB[k] = w
      end
    end
  end
  UTIL_TB_HOOKS = UTIL_TB_HOOKS or {}
  table.insert(UTIL_TB_HOOKS, EVT_PT_HookBanks)
  if type(UTIL_TB) == "table" then
    EVT_PT_HookBanks(UTIL_TB)
  end
end
