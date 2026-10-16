  -- shared part of the INAROGUE VS preview (docs/game/modes/inarogue.md §28): the retail Chronicle VS screen
  -- (vs_route_town_vs_team_menu + vs_route_town_vs_enemy_formation_menu, the «BATALLA HEROICA · ¡Hacia la cima!»
  -- screen of the Chronicle board) shows a node of the INAROGUE route map. INAROGUE opens both menus as its children
  -- with the parameter evt_ir_vs_node = node + 1; in the INAROGUE save (slot 4) with that parameter set, the menus
  -- read the node's match from the vr-loader (CMND_EVT_RL_RUN_MATCH) instead of a Chronicle town event. Anywhere
  -- else (the Chronicle board, other slots) everything stays retail.
  local EVT_RV = {
    KEY = @crc:evt_ir_vs_node@,               -- parameter: node + 1 (INAROGUE sets it, INAROGUE clears it)
    KEY_RESULT = @crc:evt_ir_vs_result@,      -- parameter: 1 «Empezar partido» (read by INAROGUE)
    SLOT = @crc:CMND_EVT_SLOT_ROGUE@,         -- () -> rogueSlot, active, ...
    RUN_INFO = @crc:CMND_EVT_RL_RUN_INFO@,    -- () -> exists, phase, ...
    MATCH = @crc:CMND_EVT_RL_RUN_MATCH@,      -- (node) -> ok, game, diff, stadium, kind, level, rival, emblem
    P_HAS = 2947612279, P_GET = 3522198769, P_SET = 3860611758, P_CLEAR = 3363400568,
    LOG = 3661580131,                         -- CMND_EVT_LOG
    TEXT_GET = 4074371074,                    -- CMND_TEXT_GET
    on = false, node = 0, game = 0, diff = 1, kind = 0, level = 0, rival = "", emblem = 0, phase = 0, team = 0,
    -- texts: menu_text rows of the 9 languages (research/scripts/rogue_play_text_build.py); the literal is the fallback
    T = {
      TITLE = {@crc:evt_ir_vs_title@, "INAROGUE · Fase {1} · {2}"},
      K5 = {@crc:evt_ird_kind5@, "Pachanga 5 contra 5"},
      K11 = {@crc:evt_ird_kind11@, "Partido 11 contra 11"},
      KBOSS = {@crc:evt_ird_kindboss@, "JEFE de la fase"},
      KELITE = {@crc:evt_ird_kindelite@, "ÉLITE"},
      KEPIC = {@crc:evt_ird_kindepic@, "JEFE ÉPICO"},          -- §33 boss tiers (text/rows/rogue_bosses.toml)
      KGATE = {@crc:evt_ird_kindgate@, "JEFE DE PUERTA"},
    },
    -- the class plate over the VS banner (retail icon_class.g4tx of the game's language): INAZUMA for a pachanga /
    -- match, ZONA LETAL for the phase boss, RANGO DIVINO for an élite (instead of «BATALLA HEROICA»)
    CLASS_TEX = 1103995203,                   -- #/menu/200_icon/06_icon_class/<LG>/icon_class.g4tx
    CLASS_NODE = 4535128,                     -- icon_class_dmy01
    CLASS = {[3] = @crc:gtxt_class02@, [7] = @crc:gtxt_class03@, [8] = @crc:gtxt_class03@, [9] = @crc:gtxt_class02@},
    CLASS_DEFAULT = @crc:gtxt_class01@,
  }

  local function evt_rv_call(cmd, ...)
    local r = table.pack(pcall(funcLuaCommand, cmd, ...))
    if not r[1] then
      return nil
    end
    return table.unpack(r, 2, r.n)
  end

  function EVT_RV.log(...)
    pcall(funcLuaCommand, EVT_RV.LOG, "rogue vs", ...)
  end

  function EVT_RV.tx(t, ...)
    local s = evt_rv_call(EVT_RV.TEXT_GET, t[1])
    if type(s) ~= "string" or s == "" then
      s = t[2]
    end
    local a = table.pack(...)
    return (s:gsub("{(%d)}", function(k)
      local v = a[tonumber(k)]
      return v == nil and "" or tostring(v)
    end))
  end

  -- INAROGUE mode: the INAROGUE save is loaded and INAROGUE asked for this node (read once per menu, in OnInit)
  function EVT_RV.check()
    EVT_RV.on = false
    local rs, act = evt_rv_call(EVT_RV.SLOT)
    if type(rs) ~= "number" or rs ~= act or evt_rv_call(EVT_RV.P_HAS, EVT_RV.KEY) ~= true then
      return false
    end
    local node = (evt_rv_call(EVT_RV.P_GET, EVT_RV.KEY) or 0) - 1
    local ok, game, diff, _, kind, level, rival, emblem = evt_rv_call(EVT_RV.MATCH, node)
    if ok ~= true or type(game) ~= "number" or game == 0 then
      EVT_RV.log("node", node, "has no match: retail screen")
      return false
    end
    -- a random-team rival (InaRogue): built into its slot team now, so this preview shows the team the match plays
    local rule, seed, key, stage, slot = evt_rv_call(@crc:CMND_EVT_RL_RUN_RIVAL@, node)
    if type(rule) == "string" and rule ~= "" then
      local built, team = evt_rv_call(@crc:CMND_VRFW_RANDOM_TEAM_BUILD@, rule, seed, key, stage, slot)
      EVT_RV.log("random rival", rule, "node", node, "->", tostring(built), tostring(team))
    end
    local _, phase = evt_rv_call(EVT_RV.RUN_INFO)
    EVT_RV.on, EVT_RV.node, EVT_RV.game = true, node, game
    EVT_RV.diff = (type(diff) == "number" and diff > 0) and diff or 1
    EVT_RV.kind = type(kind) == "number" and kind or 0
    EVT_RV.level = type(level) == "number" and level or 0
    EVT_RV.rival = type(rival) == "string" and rival or ""
    EVT_RV.emblem = type(emblem) == "number" and emblem or 0
    EVT_RV.phase = type(phase) == "number" and phase or 0
    EVT_RV.team = EVT_RV.kind == 1 and 1 or 0    -- a pachanga shows the 5v5 of the VS dock (team 1)
    return true
  end

  function EVT_RV.kindText()
    local k = EVT_RV.kind
    return EVT_RV.tx(k == 1 and EVT_RV.T.K5 or k == 3 and EVT_RV.T.KBOSS or k == 7 and EVT_RV.T.KELITE or
                     k == 8 and EVT_RV.T.KEPIC or k == 9 and EVT_RV.T.KGATE or EVT_RV.T.K11)
  end
