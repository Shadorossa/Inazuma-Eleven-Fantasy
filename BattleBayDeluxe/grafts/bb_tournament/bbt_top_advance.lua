-- BattleBayDeluxe bb_tournament, top menu part: the tree page (the bracket screen), the results, the champion screen.
-- Appended after bbt_top.lua in graft.toml's order: the parts share one chunk and its locals.
BattleBayDeluxe = type(BattleBayDeluxe) == "table" and BattleBayDeluxe or {}

-- ------------------------------------------------------------------------------------------------ the tree page
-- The knockout tree page is the framework's bracket screen vrfw_bracket_menu (a draw-only child menu of its own, with
-- the bracket's pools and the Victory Road 16-team art), opened over this host by VRFW_Bracket (VRFW
-- assets\lua\menu\_all\90_bracket.lua) with this run's view command. This host keeps the keys, its header and the
-- background; its own pools draw nothing on the tree page. animate = the round just played advances (1.5.35: after
-- the results and after the champion screen); Enter skips the advance (BBT_OnEnter).
function BBT_TreeShow(page, animate)
  VRFW_Bracket.Show(page, { host = BattleBayDeluxe.TournamentHost.menu, view = BattleBayDeluxe.Tournament.VIEW,
    animate = animate == true })
end

function BBT_TreeHide(why)
  VRFW_Bracket.Hide(why)
end

-- the results of a round: matches 1-4 on the left (plates as the left side), 5-8 on the right (mirrored), the two
-- plates of a match one above the other, each team's goals beside its plate
-- 1.5.24 (owner): the round's results as scoreboard rows, EVERY match of the round on one page (16 rows for a
-- 32-team first round): team A's plate (crest left) ending at the centre, team B's mirrored plate starting there,
-- each team's goals in a box at its plate's inner end (the winner's box lit, the loser's dark); a shoot-out adds the
-- kicks in brackets, extra time «(pr.)». v.rows[t] = { a, b, ga, gb, pa, pb, et, done, w }
-- 1.36.0 (owner 2026-10-23: the winners' goals missing, the losers' faded): the digits sit on the plates' inner
-- end, so they draw in front of the plates (DIGIT_PRIO above their 551; the connectors' digits stay at 548): an
-- opaque winner's plate no longer covers them and a faded loser's plate no longer shows them through its alpha
BattleBayDeluxe.Tournament.RES = { GAP = 20, BOX_W = 64, BOX_W_PEN = 128, BOX_H = 0.74, PITCH_MAX = 84, FILL = 0.84, DIGIT_PRIO = 553,
  -- the boxes' colours: BattleBayDeluxe.Tournament.SPR_STATE win / lose / even (1.5.37: coloured quads)
}
function BBT_DrawResults(v)
  local G, Rr = BattleBayDeluxe.Tournament.G, BattleBayDeluxe.Tournament.RES
  local rows = v.rows or {}
  local n = #rows
  if n == 0 then
    return
  end
  local pitch = math.min(Rr.PITCH_MAX, (G.BOTTOM - G.TOP) / n)
  local s = math.min(G.SCALE_MAX, pitch * Rr.FILL / G.PLATE_H)
  local top = (G.TOP + G.BOTTOM) / 2 - pitch * n / 2
  local pw = G.PLATE_W * s
  local bh = G.PLATE_H * s * Rr.BOX_H
  local scores = {}
  for t, r in ipairs(rows) do
    local y = top + pitch * (t - 0.5)
    local xa = G.CX - Rr.GAP / 2 - pw
    local xb = G.CX + Rr.GAP / 2
    if r.a and (r.a.team or 0) ~= 0 then
      BBT_Plate(r.a, xa, y, s, false, false)
    end
    if r.b and (r.b.team or 0) ~= 0 then
      BBT_Plate(r.b, xb, y, s, true, false)
    end
    -- 1.48.0: the league's calendar / results: the player's plate in the bracket's gold frame
    if v.fmt == "league" then
      if r.a and r.a.me then
        BBT_Focus(xa, y, s, false)
      elseif r.b and r.b.me then
        BBT_Focus(xb, y, s, true)
      end
    end
    scores[#scores + 1] = r.done and (BBT_Score({ ga = r.ga, gb = r.gb, pa = r.pa, pb = r.pb }) .. (r.et and "*" or ""))
      or "-"
    if r.done then
      for side = 1, 2 do
        local g = side == 1 and r.ga or r.gb
        local pk = side == 1 and r.pa or r.pb
        local txt = tostring(g or 0)
        local bw = Rr.BOX_W * s
        if (r.pa or 0) + (r.pb or 0) > 0 then
          txt = string.format("%d (%d)", g or 0, pk or 0)
          bw = Rr.BOX_W_PEN * s
        elseif r.et then
          txt = txt .. "*"
        end
        local look = "even"
        if r.w ~= 0 then
          look = r.w == side and "win" or "lose"
        end
        local bx = side == 1 and (G.CX - Rr.GAP / 2 - bw / 2 - 4) or (G.CX + Rr.GAP / 2 + bw / 2 + 4)
        -- 1.9.0: the Victory Road digits (a draw white), the shoot-out's kicks smaller in brackets, extra time
        -- marked; 1.33.0 (owner 2026-10-23): no box behind them, the winner's yellow-orange, the loser's light blue
        local N = BattleBayDeluxe.Tournament.NUM
        local style = look == "win" and "gold" or (look == "lose" and "blue" or "white")
        local h = bh * N.BOX_FILL
        local parts = BBT_NumParts({}, g or 0, style, h)
        if (r.pa or 0) + (r.pb or 0) > 0 then
          BBT_NumParts(parts, pk or 0, style, h * N.PEN_S, true)
        elseif r.et then
          parts[#parts + 1] = { "bbd_tn_d_et", h * N.PEN_S }
        end
        BBT_Glyphs(parts, bx, y, Rr.DIGIT_PRIO)
      end
    end
  end
  -- 1.33.0: the scores this page shows, once per draw (the owner saw every result «0»)
  BBT_Log("results page: " .. #rows .. " match(es): " .. table.concat(scores, "  "))
end

-- 1.5.60 (owner 2026-10-14: «que la fase de grupos no se divida nunca en páginas, siempre 1 sola página»): the group
-- stage's standings tables (1.5.54's approved sketch: a card per group, position, crest + name, the numbers, the
-- points cell, the qualification zone, the player's row, the form dots, the legend) are drawn with EVERY group on one
-- page (1 / 2 / 4 groups «wide», 8 «compact» 4 x 2, 16 «tiny» 4 x 4) in a menu of their own, evt_bbd_tn_groups_menu
-- (content\menus\bb_tournament.toml [[screen]], its script assets\lua\screens\evt_bbd_tn_groups_menu.lua): 642 layer
-- instances that this menu (bb_stadium_top_menu at 779 of the engine's ~844 per open menu, docs/game/ui/
-- menu-layer-limits.md §2.1-2.3) cannot hold. 1.5.57-1.5.58 paged them on the bracket's pools (BBT_GrpPaging, L1 / R1,
-- «(k/n)» in the title): gone. That menu is display-only (registry priority 0, no input layer): this host keeps the
-- keys (L1 / R1 to the other pages, Enter, Back), its header title and the background; the group page draws nothing on
-- this menu's pools (all hidden) and opens the child; any other page, or the overlay's close, closes it.
-- The handshake with the child is VRFW_ChildMenu (VRFW menu\_all\89_child_menu.lua): parameters
-- evt_bbd_tn_groups_page / evt_bbd_tn_groups_host_hi / _lo, the redraw and close cross-menu calls, the child closing
-- with this host menu.
BattleBayDeluxe.Tournament.GM = {
  MENU = @crc:evt_bbd_tn_groups_menu@,
  child = nil,   -- the host side of the handshake (VRFW_ChildMenu.Host), made at the first call
}

function BBT_GroupsChild()
  local GM = BattleBayDeluxe.Tournament.GM
  GM.child = GM.child or VRFW_ChildMenu.Host(GM.MENU, { prefix = "evt_bbd_tn_groups_", label = "groups menu",
    log = function(...) BBT_Log("groups menu:", ...) end })
  return GM.child
end

-- the group page shown: the child menu opened, or asked to draw again when it is already up
function BBT_GroupsShow(page)
  BBT_GroupsChild().Show(page, BattleBayDeluxe.TournamentHost.menu)
end

-- the child closed (another page shown, the overlay closed)
function BBT_GroupsHide()
  BBT_GroupsChild().Hide("the overlay left the group page")
end

-- every Step of this host: the child opened after an earlier one closed
function BBT_GroupsStep()
  BBT_GroupsChild().Step()
end

function BBT_Title(v)
  local t = v.title or {}
  local key = t.key or ""
  if key == "md" or key == "groups" or key == "groups_md" then
    return BBT_TextValue(key, t.n or 0)
  end
  if v.kind == "league" or v.kind == "hub" or v.kind == "scorers" or v.kind == "squad" or v.kind == "fixtures"
    or v.calendar then
    -- the league's pages: «Liga · Jornada N de M», «Calendario · Jornada N de M» …; the standings page among the
    -- standings pages when there are more
    local s = t.m and BBT_TextValue2(key, t.n or 0, t.m) or ((t.n or 0) > 0 and BBT_TextValue(key, t.n) or BBT_Text(key))
    if (v.page_count or 1) > 1 then
      s = string.format("%s  (%d/%d)", s, v.page_n or 1, v.page_count)
    end
    return s
  end
  if key == "" then
    return BBT_Text("mode_tournament")
  end
  return BBT_Text(key)
end

-- a text key of the run's format: the league's own variant (<key>_league) for a league
function BBT_RunKey(key, league)
  return league and (key .. "_league") or key
end

function BBT_Outcome(v)
  if v.outcome == "champion" then
    return BBT_Text(BBT_RunKey("champion", v.fmt == "league"))
  end
  if v.outcome == "out" and v.place and v.place.stage == "league" then
    return BBT_TextValue("out_league", v.place.pos or 0)
  end
  if v.outcome == "out" and v.place then
    if v.place.stage == "groups" then
      return BBT_Text("out_groups")
    end
    return BBT_Text("out_ko_" .. tostring(v.place.from_end or 1))
  end
  return ""
end

-- 1.5.28 (owner): the champion screen. When a tournament is over (a champion and an outcome), its first opening
-- shows the WINNER (the player or a CPU team): the crest big in the centre, its name below, «¡CAMPEÓN!» above with
-- the crown; the crest scales in and the banner slides in (BBT_ChampStep, frame time); Enter = the final bracket
-- (then Enter closes the ended run as before). Drawn with the overlay's own layers: the champion's plate instance
-- (row_l BattleBayDeluxe.Tournament.ROW_CHAMP) with its plate hidden (only its crest, scaled), two texts, the crown quad.
BattleBayDeluxe.Tournament.CH = { EMB_S = 3.4, EMB_Y = 520, NAME_Y = 760, NAME_S = 1.3, BANNER_Y = 230, BANNER_S = 2.2, CROWN_Y = 330,
  CROWN_S = 2.2, DUR = 0.6, SLIDE = 700, TXT_BANNER = 0, TXT_NAME = 1 }
function BBT_ChampLayout(p)
  local G, C, L, H = BattleBayDeluxe.Tournament.G, BattleBayDeluxe.Tournament.C, BattleBayDeluxe.Tournament.L, BattleBayDeluxe.Tournament.CH
  local e = 1 - (1 - math.min(1, p)) ^ 3
  -- the crest: the plate's crest slot sits 22 .. 90 px from its left edge, 34 px under its top
  local s = math.max(0.05, H.EMB_S * e)
  local i = BattleBayDeluxe.Tournament.ROW_CHAMP
  funcLuaMenuCommand(C.SCALE, L.row_l, s, s, 1, i)
  funcLuaMenuCommand(C.POS, L.row_l, G.CX - 56 * s, -H.EMB_Y, 0, i)
  -- the banner slides in from the left, the name fades up with the crest
  local bx = G.CX - H.SLIDE * (1 - e)
  funcLuaMenuCommand(C.POS, L.txt, bx, -H.BANNER_Y, 0, H.TXT_BANNER)
  funcLuaMenuCommand(C.SCALE, L.txt, H.NAME_S * e, H.NAME_S * e, 1, H.TXT_NAME)
  local cs = H.CROWN_S * e
  funcLuaMenuCommand(C.SCALE, L.icon, G.CROWN_W * cs / G.Q, G.CROWN_H * cs / G.Q, 1, 0)
end

function BBT_ChampText(i, str, x, y, scale)
  local C, L = BattleBayDeluxe.Tournament.C, BattleBayDeluxe.Tournament.L
  BBT_Take(L.txt, i)
  funcLuaMenuCommand(C.VISIBLE, L.txt, i, true)
  funcLuaMenuCommand(C.POS, L.txt, x, -y, 0, i)
  funcLuaMenuCommand(C.SCALE, L.txt, scale, scale, 1, i)
  funcLuaMenuCommand(C.TEXT_STYLE, L.txt, i, BattleBayDeluxe.Tournament.TXT_ON, BattleBayDeluxe.Tournament.STYLE_TXT)
  funcLuaMenuCommand(C.TEXT, L.txt, BattleBayDeluxe.Tournament.TXT_ON, str, i)
  funcLuaMenuCommand(C.TEXT, L.txt, BattleBayDeluxe.Tournament.TXT_OFF, "", i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L.txt, BattleBayDeluxe.Tournament.TXT_ON, true, i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L.txt, BattleBayDeluxe.Tournament.TXT_OFF, false, i)
end

function BBT_ChampOpen(v)
  local C, L, H, G = BattleBayDeluxe.Tournament.C, BattleBayDeluxe.Tournament.L, BattleBayDeluxe.Tournament.CH, BattleBayDeluxe.Tournament.G
  BattleBayDeluxe.TournamentState.view, BattleBayDeluxe.TournamentState.page = v, v.page
  BattleBayDeluxe.TournamentState.champ = { t = 0, team = v.champion }
  BattleBayDeluxe.TournamentState.champ_done = true
  pcall(BBT_TreeHide, "the champion screen")
  BBT_Begin()
  -- the crest: the champion's plate instance, plate and name hidden
  local i = BBT_Take(L.row_l, BattleBayDeluxe.Tournament.ROW_CHAMP)
  funcLuaMenuCommand(C.VISIBLE, L.row_l, i, true)
  for _, m in pairs(BattleBayDeluxe.Tournament.PLATE) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L.row_l, m, false, i)
  end
  funcLuaMenuCommand(C.TEXT_VISIBLE, L.row_l, BattleBayDeluxe.Tournament.TXT_ON, false, i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L.row_l, BattleBayDeluxe.Tournament.TXT_OFF, false, i)
  funcLuaMenuCommand(C.PRIM_COLOR, L.row_l, i, BattleBayDeluxe.Tournament.MESH_EMBLEM, 1, 1, 1)
  BBT_Alpha(L.row_l, i, 1)
  VRFW_Team.Emblem(L.row_l, i, v.champion, BattleBayDeluxe.TournamentState.emb)
  BBT_ChampText(H.TXT_BANNER, BBT_Text("champion_banner"), G.CX, H.BANNER_Y, H.BANNER_S)
  BBT_ChampText(H.TXT_NAME, VRFW_Team.Name(v.champion), G.CX, H.NAME_Y, H.NAME_S)
  BBT_Quad(L.icon, BattleBayDeluxe.Tournament.SPR_CROWN, G.CX, H.CROWN_Y, G.CROWN_W * H.CROWN_S, G.CROWN_H * H.CROWN_S, { 1, 1, 1 })
  BBT_End()
  BBT_ChampLayout(0)
  pcall(BattleBayDeluxe.TournamentHost.title, BBT_Text(BBT_RunKey("champion", v.fmt == "league")))
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
  BBT_Log(string.format("champion screen: team %s (%s)", VRFW_Id.hex(v.champion),
    v.outcome == "champion" and "the player" or "a CPU team"))
  return true
end

-- the entrance animation, from Step (the frame time: Step runs faster than 60 / s in menus)
function BBT_ChampStep()
  local ch = BattleBayDeluxe.TournamentState.champ
  if not ch or ch.t >= BattleBayDeluxe.Tournament.CH.DUR then
    return
  end
  local ok, dt = pcall(funcLuaCommand, 1549797111)
  if not ok or type(dt) ~= "number" or dt <= 0 or dt > 0.5 then
    dt = 1 / 60
  end
  ch.t = ch.t + dt
  BBT_ChampLayout(ch.t / BattleBayDeluxe.Tournament.CH.DUR)
end

-- the view kinds drawn by the group stage's own menu (evt_bbd_tn_groups_menu.lua)
BBT_GM_KINDS = { groups = true, league = true, hub = true, scorers = true, squad = true, fixtures = true }
function BBT_GmKind(kind)
  return BBT_GM_KINDS[kind] == true
end

function BBT_Draw(page, animate)
  local v = BBT_Call(BattleBayDeluxe.Tournament.VIEW, page or -1)
  if type(v) ~= "table" or v.kind == "none" then
    BBT_Log("view unavailable", tostring(v))
    return false
  end
  -- 1.5.28: a finished tournament opens on its champion first (once per opening of the overlay)
  BattleBayDeluxe.TournamentState.champ = nil
  if (v.champion or 0) ~= 0 and (v.outcome or "") ~= "" and not BattleBayDeluxe.TournamentState.champ_done and (page == nil or page < 0) then
    return BBT_ChampOpen(v)
  end
  BattleBayDeluxe.TournamentState.view, BattleBayDeluxe.TournamentState.page = v, v.page
  BattleBayDeluxe.TournamentState.hub_zones = nil   -- the pointer zones of the page drawn before (the hub / grid send theirs once drawn)
  BBT_Begin()
  -- 1.8.0: the Victory Road stadium dimmed under the page (the box pool's first quad, behind everything it draws; the
  -- league's standings too)
  if BattleBayDeluxe.TournamentState.stadium_bg and v.kind ~= "groups" then
    BBT_Quad(BattleBayDeluxe.Tournament.L.box, BattleBayDeluxe.Tournament.SPR_DIM, BattleBayDeluxe.Tournament.G.CX, 540, BattleBayDeluxe.Tournament.G.W, 1080, BattleBayDeluxe.Tournament.WHITE, BattleBayDeluxe.Tournament.G.PRIO_DIM)
  end
  local ok, err = pcall(function()
    if v.kind == "results" then
      BBT_DrawResults(v)
    end
  end)
  if not ok then
    BBT_Log("draw error", tostring(err))
  end
  BBT_End()
  -- 1.5.60: the group page = every group on one page in the group stage's own menu (this menu's pools all hidden);
  -- 1.45.0: the league's standings pages too; the tree page in the bracket screen
  if BBT_GmKind(v.kind) then
    BBT_GroupsShow(v.page)
  else
    BBT_GroupsHide()
  end
  if v.kind == "tree" then
    BBT_TreeShow(v.page, animate)
  else
    BBT_TreeHide("the overlay left the tree page")
  end
  -- 1.5.22: what this draw placed (once per draw), and the view's fields when it placed nothing
  local u = BattleBayDeluxe.TournamentState.used or {}
  local L = BattleBayDeluxe.Tournament.L
  local placed = (u[L.row_l] or 0) + (u[L.row_r] or 0) + (u[L.line] or 0) + (u[L.txt] or 0)
  local keys = {}
  if placed == 0 then
    for k, x in pairs(v) do
      keys[#keys + 1] = tostring(k) .. ":" .. type(x) .. (type(x) == "table" and ("#" .. #x) or "")
    end
  end
  if BBT_GmKind(v.kind) or v.kind == "tree" then
    keys = {}   -- the group / tree pages draw in their own menus (their own log lines)
  end
  BBT_Log(string.format("bracket drawn n=%d on %s (kind %s, rounds %s; plates %d+%d, lines %d, texts %d)%s%s",
    placed, BattleBayDeluxe.TournamentHost.name, tostring(v.kind), tostring(v.rounds), u[L.row_l] or 0, u[L.row_r] or 0, u[L.line] or 0,
    u[L.txt] or 0, v.kind == "groups" and (" groups " .. #(v.groups or {}) .. " in evt_bbd_tn_groups_menu")
      or (v.kind == "league" and (" standings " .. #(v.standings or {}) .. " rows in evt_bbd_tn_groups_menu")
      or (v.kind == "tree" and " in vrfw_bracket_menu" or "")),
    #keys > 0 and (" view: " .. table.concat(keys, " ")) or ""))
  -- the title in the menu's own header: the page; after the run, its end
  local title = BBT_Title(v)
  local tail = BBT_Outcome(v)
  if tail ~= "" then
    title = title .. "  ·  " .. tail
  end
  pcall(BattleBayDeluxe.TournamentHost.title, title)
  return true
end

-- 1.42.0 (owner): the bracket keeps the Battle Bay menu background but not its logo with the character art (mesh
-- _bg_logo_bb01 of vs01_00_p2_background_bb_stadium; the stadium picture _bg_stadium01 stays); shown again on close
BattleBayDeluxe.Tournament.BG_BB = 314687935 --[[vs01_00_p2_background_bb_stadium]]
BattleBayDeluxe.Tournament.BG_BB_LOGO = @crc:_bg_logo_bb01@
function BBT_BgLogo(show)
  if BattleBayDeluxe.TournamentHost.menu == BattleBayDeluxe.Tournament.TOP then
    pcall(funcLuaMenuCommand, BattleBayDeluxe.Tournament.C.MESH_VISIBLE, BattleBayDeluxe.Tournament.BG_BB, BattleBayDeluxe.Tournament.BG_BB_LOGO, show, 0)
  end
end

function BBT_Open(page)
  if BattleBayDeluxe.TournamentState.open then
    return BBT_Draw(page)
  end
  BattleBayDeluxe.TournamentState.open = true
  BattleBayDeluxe.TournamentState.emb = {}
  BattleBayDeluxe.TournamentState.prio = {}
  local H = BattleBayDeluxe.TournamentHost
  BBT_SwitchLayers(H.close, false)
  BBT_ShowLayers(H.hide, false)
  BBT_BgLogo(false)
  for _, l in ipairs(H.lists or {}) do
    funcLuaMenuCommand(@crc:CMND_SET_ENABLE_CTRL_FOCUS@, l, false)
  end
  -- 1.39.0 (owner): the bracket keeps the Battle Bay's own menu background (not closed, no band, no stadium)
  local G = BattleBayDeluxe.Tournament.G
  local sy = (G.BG_BOTTOM - G.BG_TOP) / G.BG_H
  funcLuaMenuCommand(BattleBayDeluxe.Tournament.C.SCALE, BattleBayDeluxe.Tournament.L.bg, 1, sy, 1, 0)
  funcLuaMenuCommand(BattleBayDeluxe.Tournament.C.POS, BattleBayDeluxe.Tournament.L.bg, 0, -(G.BG_TOP - G.BG_Y * sy), 0, 0)
  -- the Victory Road stadium (its layout in screen px: at the origin) at the back (G.PRIO_STADIUM: a higher draw
  -- priority draws in front); the band (195), the retail art and the bracket's pools (546-554) in front of it
  BattleBayDeluxe.TournamentState.strip = {}
  BattleBayDeluxe.TournamentState.stadium_bg = false
  local nst = 0
  if type(nst) == "number" and nst >= 1 then
    bbt_open_layer(BattleBayDeluxe.Tournament.L.stadium, 0)
    funcLuaMenuCommand(BattleBayDeluxe.Tournament.C.SCALE, BattleBayDeluxe.Tournament.L.stadium, 1, 1, 1, 0)
    funcLuaMenuCommand(BattleBayDeluxe.Tournament.C.POS, BattleBayDeluxe.Tournament.L.stadium, 0, 0, 0, 0)
    pcall(funcLuaMenuCommand, @crc:CMND_SET_DRAW_PRIORITY@, BattleBayDeluxe.Tournament.L.stadium, 0, G.PRIO_STADIUM, true)
    BattleBayDeluxe.TournamentState.stadium_bg = true
  end
  -- every instance opened once, hidden until a page draws it (each draw shows what it uses, hides the rest)
  BBT_EachInstance(function(l, i)
    bbt_open_layer(l, i)
    BBT_Hide(l, i)
  end)
  bbt_open_layer(BattleBayDeluxe.Tournament.ANCHOR, 0)
  -- 1.5.20: the anchor is a button object; on «Modos de juego» it showed at the top left (a teal box over the
  -- header): placed off screen and invisible, it keeps the keys
  funcLuaMenuCommand(BattleBayDeluxe.Tournament.C.POS, BattleBayDeluxe.Tournament.ANCHOR, -4000, 4000, 0, 0)
  funcLuaMenuCommand(BattleBayDeluxe.Tournament.C.VISIBLE, BattleBayDeluxe.Tournament.ANCHOR, 0, false)
  BBT_FocusAnchor()
  BattleBayDeluxe.TournamentState.focus_watch = 0
  pcall(BattleBayDeluxe.TournamentHost.guide, true)
  if not BBT_Draw(page) then
    BBT_Close()
    return false
  end
  pcall(BBT_Diag, "open")
  return true
end

-- 1.5.20 diagnostics (owner: the bracket not seen on «Modos de juego»): per layer, the instances the menu created,
-- whether instance 0 is open and how many this draw used; the background's state
-- 1.5.21: one string (the log command keeps only its first 8 arguments), + the visibility / global position the
-- engine reports for instance 0 (the VRFW input trace's own commands)
function BBT_Diag(when)
  local parts = {}
  for k, l in pairs(BattleBayDeluxe.Tournament.L) do
    local n = funcLuaMenuCommand(@crc:CMND_GET_CREATE_LAYER_NUM@, l)
    local open = funcLuaMenuCommand(@crc:CMND_IS_OPEN_LAYER@, l, 0, BattleBayDeluxe.TournamentHost.menu)
    local okv, vis = pcall(funcLuaMenuCommand, @crc:CMND_IS_LAYER_VISIBLE@ --[[is visible]], l, 0)
    local okp, gx, gy = pcall(funcLuaMenuCommand, 4002164178 --[[global pos]], l, 0)
    parts[#parts + 1] = string.format("%s n=%s open0=%s vis0=%s pos0=%s,%s used=%s", k, tostring(n), tostring(open),
      tostring(okv and vis), tostring(okp and gx), tostring(okp and gy), tostring(BattleBayDeluxe.TournamentState.used and BattleBayDeluxe.TournamentState.used[l]))
  end
  local v = BattleBayDeluxe.TournamentState.view or {}
  BBT_Log(string.format("bracket %s on %s: kind %s page %s | %s", when, BattleBayDeluxe.TournamentHost.name, tostring(v.kind),
    tostring(v.page), table.concat(parts, "; ")))
end

function BBT_Close()
  -- 1.5.64: the view's open / close state in the log (owner 2026-10-14: the group tables left over the team grid)
  BBT_Log("overlay closing on " .. tostring(BattleBayDeluxe.TournamentHost.name) .. ": page " .. tostring(BattleBayDeluxe.TournamentState.page) .. ", group page menu " ..
    (BBT_GroupsChild().Open() and "open" or "not open"))
  BattleBayDeluxe.TournamentState.champ, BattleBayDeluxe.TournamentState.champ_done = nil, false
  BBT_GroupsHide()   -- 1.5.60: the group stage's own menu
  BBT_TreeHide("the overlay closed")
  BBT_EachInstance(function(l, i)
    bbt_close_layer(l, i)
  end)
  bbt_close_layer(BattleBayDeluxe.Tournament.L.bg, 0)
  if BattleBayDeluxe.TournamentState.stadium_bg then
    bbt_close_layer(BattleBayDeluxe.Tournament.L.stadium, 0)
    BattleBayDeluxe.TournamentState.stadium_bg = false
  end
  bbt_close_layer(BattleBayDeluxe.Tournament.ANCHOR, 0)
  BattleBayDeluxe.TournamentState.emb = {}
  funcLuaMenuCommand(@crc:CMND_SET_ENABLE_CTRL_FOCUS@, BattleBayDeluxe.Tournament.ANCHOR, false)
  BattleBayDeluxe.TournamentState.open = false
  local H = BattleBayDeluxe.TournamentHost
  BBT_SwitchLayers(H.close, true)
  BBT_ShowLayers(H.hide, true)
  BBT_BgLogo(true)
  H.header()
  -- the badge again: the run may have moved on (a match played) or ended (the retail Campaña record then)
  if H.name == "bb_stadium_top_menu" then
    pcall(OnSetupLayer, BattleBayDeluxe.Tournament.BADGE, 0)
  end
  H.refocus()
  BattleBayDeluxe.TournamentState.focus_watch = nil
  pcall(H.guide, false)
end

-- 1.37.0 (owner 2026-10-23: «al darle a aceptar no pasa nada» on the results shown after a match): the input anchor
-- takes the keys (its focus enabled and set). The overlay opens on the results while the top menu is still coming back
-- from the match: until the anchor reports its focus (at most FOCUS_SETTLE Steps after the opening) it is set again,
-- and a decide on any other layer while the overlay is up is the overlay's Enter
BattleBayDeluxe.Tournament.FOCUS_SETTLE = 120
function BBT_FocusAnchor()
  funcLuaMenuCommand(@crc:CMND_SET_ENABLE_CTRL_FOCUS@, BattleBayDeluxe.Tournament.ANCHOR, true)
  funcLuaMenuCommand(1778826357, BattleBayDeluxe.Tournament.ANCHOR, 0, true)
end

-- from Step after an opening: the anchor's focus until it holds
function BBT_FocusWatch()
  local S = BattleBayDeluxe.TournamentState
  S.focus_watch = S.focus_watch + 1
  local has = funcLuaMenuCommand(@crc:CMND_IS_CTRL_FOCUS_ACTIVE@, BattleBayDeluxe.Tournament.ANCHOR) == true
  if has then
    if S.focus_watch > 1 then
      BBT_Log("overlay keys: the anchor holds the focus after " .. S.focus_watch .. " Step(s)")
    end
    S.focus_watch = nil
    return
  end
  if S.focus_watch >= BattleBayDeluxe.Tournament.FOCUS_SETTLE then
    BBT_Log("overlay keys: the anchor never reported its focus in " .. BattleBayDeluxe.Tournament.FOCUS_SETTLE ..
      " Steps (a decide on any layer is still the overlay's Enter)")
    S.focus_watch = nil
    return
  end
  BBT_FocusAnchor()
end

-- 1.5.33 (owner 2026-10-13): the round's results show ONCE, right after the match (Enter = the bracket); everywhere
-- else (the Torneo panel, «Continuar», «Ver el cuadro», L1 / R1 from a bracket page) the bracket. Page ids
-- (scripts/lib/tourney_view.lua): results >= BBT_RESULTS_PAGE, then the group pages, the tree.
BBT_RESULTS_PAGE = 20

-- the bracket page of a view: the tree when the knockout is drawn, else the first group page (a league: its standings
-- page with the player's team); nil when none
function BBT_BracketPageOf(v)
  if v.home_page ~= nil then
    return v.home_page
  end
  local first
  for _, p in ipairs(v.pages or {}) do
    if p < BBT_RESULTS_PAGE then
      if p == 0 then
        return 0
      end
      first = first or p
    end
  end
  return first
end

-- the page an entry opens on: -1 (the view's own first page) unless that is the results page; the champion
-- screen of an ended run still comes first (its Enter goes to the tree)
function BBT_EntryPage()
  local v = BBT_Call(BattleBayDeluxe.Tournament.VIEW, -1)
  if type(v) ~= "table" or v.kind ~= "results" then
    return -1
  end
  if (v.champion or 0) ~= 0 and (v.outcome or "") ~= "" then
    return -1
  end
  return BBT_BracketPageOf(v) or -1
end

function BBT_Turn(d)
  local v = BattleBayDeluxe.TournamentState.view
  if not v or not v.pages then
    return
  end
  -- from a bracket page the results page is not among the pages turned to
  local pages = {}
  for _, p in ipairs(v.pages) do
    if p < BBT_RESULTS_PAGE or (BattleBayDeluxe.TournamentState.page or 0) >= BBT_RESULTS_PAGE then
      pages[#pages + 1] = p
    end
  end
  if #pages < 2 then
    return
  end
  local k = 1
  for i, p in ipairs(pages) do
    if p == BattleBayDeluxe.TournamentState.page then
      k = i
    end
  end
  k = (k - 1 + d) % #pages + 1
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
  BBT_Draw(pages[k])
end

-- the next match: the round's rulebook selected, then the retail campaign «continue» (the Campaña row's branch 0)
function BBT_PlayNext()
  -- 1.5.5: the Campaña's block kept, the tournament's match written into it (CMND_BBD_TOURN_PREPARE)
  local prep = BBT_Call(BattleBayDeluxe.Tournament.PREPARE)
  if type(prep) ~= "table" or not prep.ok then
    BBT_Log("next match: not prepared", type(prep) == "table" and "refused" or "busy")
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2086672038 --[[sy0003]])
    return
  end
  pcall(funcLuaCommand, BattleBayDeluxe.Tournament.RULE_SELECT, prep.rules or "")
  BBT_Close()
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
  local ret = funcLuaMenuCommand(2227512519)
  BBT_Log("next match requested", tostring(ret), prep.rules or "")
  if not ret then
    BBT_Call(BattleBayDeluxe.Tournament.UNLOAD)
  end
  if ret then
    -- the host's mark for the way back (Modos de juego: the engine reopens it on the Torneo tile)
    pcall(BattleBayDeluxe.TournamentHost.before_match)
    funcLuaMenuCommand(1558704558, BattleBayDeluxe.TournamentHost.menu, false)
    if type(BrightFadeAllMenu) == "function" then
      BrightFadeAllMenu(3578114327 --[[fade_menu_encount_campaign]], true)
    end
    funcLuaCommand(769636339, 0.5)
    if BattleBayDeluxe.TournamentHost.menu ~= 811496143 then
      funcLuaCommand(@crc:CMND_CLOSE_MENU_OBJECT@, BattleBayDeluxe.TournamentHost.menu, true)
    end
    funcLuaCommand(@crc:CMND_CLOSE_MENU_OBJECT@, 811496143 --[[soccer_top_menu]])
  end
end

function BBT_OnEnter()
  -- 1.5.35: Enter during the bracket's advance = its end at once (the next Enter goes on)
  if VRFW_Bracket.Busy() then
    VRFW_Bracket.Skip()
    BBT_Log("bracket advance: skipped")
    return
  end
  -- 1.52.0: the league hub's dashboard waits for its action (its side menu's row)
  if BBT_HubKey("enter") or BBT_HubCalKey("enter") then
    return
  end
  -- 1.48.0: a page of the league hub's sections (Calendario, Competición): Enter / Back = the hub again
  if BattleBayDeluxe.TournamentState.section then
    BattleBayDeluxe.TournamentState.section = false
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 202039849 --[[sy0006]])
    return
  end
  if BattleBayDeluxe.TournamentState.champ then
    -- the champion screen: Enter = the final bracket (the tree page; a league: its standings)
    BattleBayDeluxe.TournamentState.champ = nil
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
    local v = BattleBayDeluxe.TournamentState.view or {}
    BBT_Draw(v.home_page or (v.pages and v.pages[#v.pages]) or 0, true)
    return
  end
  local v = BattleBayDeluxe.TournamentState.view or {}
  -- 1.48.0: a running league's results (after a match): Enter = the career hub
  if v.fmt == "league" and (v.outcome or "") == "" and not BattleBayDeluxe.TournamentState.hub and BattleBayDeluxe.TournamentState.co == nil then
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
    BattleBayDeluxe.TournamentState.co = coroutine.create(BBT_LeagueHub)
    return
  end
  -- 1.5.33: on the results page (after a match) Enter = the bracket, updated with the round's winners
  if v.kind == "results" then
    local p = BBT_BracketPageOf(v)
    if p ~= nil then
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
      BBT_Draw(p, true)
      BBT_Log("results -> bracket page", p)
      return
    end
  end
  if v.watching then
    -- eliminated: the next remaining round, simulated now, its results first
    local r = BBT_Call(BattleBayDeluxe.Tournament.STEP)
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
    if type(r) == "table" and r.event == "step" then
      BBT_Draw(-1)
      return
    end
  end
  if v.outcome ~= nil and v.outcome ~= "" then
    BBT_Call(BattleBayDeluxe.Tournament.CLOSE)
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
    BBT_Close()
    return
  end
  if (v.next or 0) ~= 0 then
    BattleBayDeluxe.TournamentState.co = coroutine.create(BBT_PlayNext)
    return
  end
  BBT_Close()
end
