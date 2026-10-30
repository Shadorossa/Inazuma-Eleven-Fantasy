-- Player page in pages (Nacho 2026-10-06; docs/game/ui/ui-redesign.md «Player page: one-row header and 3D model»,
-- round 2): two pages in front of the retail «ATRIBUTOS» page, which keeps only the moves:
--   index 6 = PERFIL (type 8: the description + the 3D model), index 7 = ATRIBUTOS (type 9: the 8 stats as bars),
--   index 0 = SUPERTÉCNICAS (type 1 without the radar), then Hipertécnica (plate_hiper), Equipamiento, Pasivas,
--   Sexto sentido, and the other mods' pages (Utilities' TRAYECTORIA last).
-- The pages are declared to the VR-Framework's player page registry (VRFW_PlayerPages, docs/framework/player-pages.md:
-- CharacterReforged.Profile first, CharacterReforged.Stats after it; Character Reforged's since 2026-10-14, moved from
-- Inazuma Fantasy: docs/refactor/aura-mods-split.md «Player page»); the framework resolves the order at its first
-- use, whatever order the mods' files ran in, and steps Q/E, maps the types and gives the dots' slots (2026-10-09).
-- A wrapper is never wrapped twice (EVT_PPG_WRAPPED). No engine call while the chunk loads.
if EVT_PLATE_PAGES == nil then
  EVT_PLATE_PAGES = true            -- false: no PERFIL / ATRIBUTOS pages (ATRIBUTOS = radar + moves)
end
EVT_PPG_DESC, EVT_PPG_STATS = 6, 7                  -- page indices
EVT_PPG_DESC_TYPE, EVT_PPG_STATS_TYPE = 8, 9        -- personal-plate page types (retail 0-4, Hiper 5, career 6)
if EVT_PLATE_PAGES and VRFW_PlayerPages ~= nil and (EVT_PPG_HOST == nil or EVT_PPG_HOST.pages ~= false) then
  VRFW_PlayerPages.Add({Name = "CharacterReforged.Profile", Index = EVT_PPG_DESC, Type = EVT_PPG_DESC_TYPE, First = true})
  VRFW_PlayerPages.Add({Name = "CharacterReforged.Stats", Index = EVT_PPG_STATS, Type = EVT_PPG_STATS_TYPE,
    After = "CharacterReforged.Profile"})
end
-- round 3: the plate opens on PERFIL. The page index lives in the parents (soccer_formation_menu_inc's local, read and
-- set by GetNowPageIdx / SetNowPageIdx, pure Lua): a fresh menu VM starts it at 0; this moves it to PERFIL once. The
-- chara banks keep their own index (they open on SUPERTÉCNICAS).
-- (a host without pages, research/grafts/plate_pages/host_equip.lua, keeps its own index)
if EVT_PLATE_PAGES and EVT_PPG_START ~= false and not EVT_PPG_STARTED
    and (EVT_PPG_HOST == nil or EVT_PPG_HOST.pages ~= false) and type(GetNowPageIdx) == "function"
    and type(SetNowPageIdx) == "function" then
  local ok, cur = pcall(GetNowPageIdx)
  if ok and cur == 0 then
    pcall(SetNowPageIdx, EVT_PPG_DESC)
  end
  EVT_PPG_STARTED = true
end
if EVT_PPG_WRAPPED == nil then
  EVT_PPG_WRAPPED = {}
end

function EVT_PPG_Wrap(name, make)
  if type(VRFW_Host) == "table" and type(VRFW_Host.wrap) == "function" then
    local ok = VRFW_Host.wrap(name, make, {level = 2})   -- survives a later patch that redefines the function
    return ok
  end
  local cur = _ENV[name]
  if type(cur) ~= "function" or EVT_PPG_WRAPPED[cur] then
    return false
  end
  local w = make(cur)
  EVT_PPG_WRAPPED[w] = true
  _ENV[name] = w
  return true
end

-- round 9: the Pasivas cursor mode of the plate (R3 on that page): while it runs, this menu's card focus is off and
-- its left / right page steps and its back are swallowed (the plate moves its cursor / leaves the mode instead).
-- Called by the plate through funcLuaCommand(830228314, <this menu>, "EVT_PPG_SetCursor", on).
EVT_PPG_CURSOR = false
function EVT_PPG_SetCursor(on)
  EVT_PPG_CURSOR = on == true
  for _, l in ipairs({1973487846, 1658289671}) do      -- team00_01_chara_card_for_soccer / _for_leader
    pcall(funcLuaMenuCommand, @crc:CMND_SET_ENABLE_CTRL_FOCUS@, l, not EVT_PPG_CURSOR)
  end
  return true
end
EVT_PPG_Wrap("OnFunctionCommonLeftAndRight", function(orig)
  return function(a1, ...)
    if EVT_PPG_CURSOR and (a1 == 2053629800 or a1 == 3033167124) then
      return 1
    end
    return orig(a1, ...)
  end
end)
EVT_PPG_Wrap("FuncOnBack", function(orig)
  return function(...)
    if EVT_PPG_CURSOR then
      pcall(funcLuaCommand, @crc:CMND_EVT_LOG@, "EVT_PPG back swallowed (Pasivas cursor mode)")
      return
    end
    return orig(...)
  end
end)

-- pointer (2026-10-06, docs/game/ui/mouse-support.md §5): a click on a page dot / the Q / E glyph of the plate asks the
-- menu that owns the page index to step through its OWN Q/E path (retail guards, sound, animation, its index): the
-- plate calls funcLuaCommand(830228314, <this menu>, "EVT_PPG_PointerPage", target, dir, bank). `target` = a page
-- index the registry's next step answers once (VRFW_PlayerPages.Goto), nil = a plain Q (dir -1) / E (dir 1) step.
function EVT_PPG_PointerPage(target, dir, bank)
  local P = VRFW_PlayerPages
  if type(target) == "number" and P ~= nil then
    P.Goto(target)
  end
  local right = type(dir) == "number" and dir > 0
  local ok, err = true, nil
  if type(OnFunction) == "function" then
    if bank == true then
      ok, err = pcall(OnFunction, 3959000859, right and 70193212 --[[next]] or 3168962645 --[[prev]])
    else
      ok, err = pcall(OnFunction, right and 3033167124 --[[right]] or 2053629800 --[[left]])
    end
  end
  if P ~= nil then
    P.Goto(nil)
  end
  if not ok then
    pcall(funcLuaCommand, @crc:CMND_EVT_LOG@, "EVT_PPG pointer page error", tostring(err))
  end
  return ok
end

-- Character Reforged (2026-10-14, owner: «with the Fantasy option every place that shows the player's moves shows the
-- FANTASY set»): while the option «Tabla de habilidades» shows the new set (CharacterReforged.Page.SkillSetOn), every
-- player plate that fills its 6 move rows through the retail SetupPersonalPlateCharaSkillItem (the player page's
-- SUPERTÉCNICAS, the team dock / Plantilla / formation card, the banks, the «Confirmación de supertécnica» window,
-- which reads the rows' moves) shows the skill table's 6 rows instead of the retail list positions (the old «branch»
-- groups): row r = the r-th list position that holds no aura (empty ones included, list order), then the positions
-- holding an aura; a row shows its position's move, nothing when that is an aura (the aura / mix halves own it: the
-- Hiper page), the board slot of the same position when the position is empty (ss2_menus EVT_Skill / PL.ProjPos,
-- the same rule). The retail fill runs with the move lookup answered for this card only (CMND 0x35D3E3B8, the
-- evolution grade read at the move's own list position) and restored right after. A row whose move needs a level above
-- the player's (CMND_VRFW_CHARACTER_LEARN_LEVEL, the framework's learn levels) is drawn as the retail plate draws a move
-- not learned yet: no move at that position and the learn table (0xCF25A8AF) answering that move and its level there,
-- so the retail fill shows its padlock and «Nv. N». In a match (plate type 1, e.g. the pause «Formación») the rows get
-- the player's soccer handle: the rows are those of its card (F.Card), or of the team member row he plays from.
-- Victory Road: the retail rows untouched. No engine call while the chunk loads.
EVT_PPG_FANTASY_MOVES = EVT_PPG_FANTASY_MOVES or {}
do
  local F = EVT_PPG_FANTASY_MOVES
  F.GET_SKILL = 903078840               -- (charaStHdl, list position 0..5) -> move (save skill_list)
  F.LEARNABLE = 3475351727              -- (charaStHdl) -> ok, {move per slot}, {unlock level per slot}
  F.LEARN_LEVEL = @crc:CMND_VRFW_CHARACTER_LEARN_LEVEL@               -- (charaStHdl, move) -> level needed, player's level
  F.SKILL_INFO = @crc:CMND_GET_SOCCER_SKILL_INFO@             -- (move, 9) -> ok, category (8 = an aura)
  F.BOARD_INV = 632801955               -- (charaStHdl, board slot, kind 1 placed / 0 native) -> inventory handle
  F.INV_ITEM = 2662166687               -- (inventory handle, 0) -> move
  F.ROW_COUNT = 6
  F.SKILL_SET = @crc:CMND_VRFW_SKILL_SET@               -- (charaStHdl) -> answered, aura, mix, aura_from, mix_from, row1..6, technique1..6

  local function U32(v)
    v = tonumber(v) or 0
    if v < 0 then
      v = v + 4294967296
    end
    return v
  end

  function F.On()
    local page = type(CharacterReforged) == "table" and CharacterReforged.Page or nil
    if type(page) ~= "table" or type(page.SkillSetOn) ~= "function" then
      return false
    end
    local ok, on = pcall(page.SkillSetOn)
    return ok and on == true
  end

  local function IsAura(call, move)
    if move == 0 then
      return false
    end
    local ok, known, category = pcall(call, F.SKILL_INFO, move, 9)
    return ok and known and category == 8
  end

  local function BoardMove(call, hdl, slot)
    local inv = call(F.BOARD_INV, hdl, slot, 1)
    if inv == nil or inv == 0 then
      inv = call(F.BOARD_INV, hdl, slot, 0)
    end
    if inv == nil or inv == 0 then
      return 0
    end
    return U32(call(F.INV_ITEM, inv, 0))
  end

  -- the 6 rows of the framework's effective skill set (CMND_VRFW_SKILL_SET); nil = no answer (the rule below)
  local function ServiceRows(call, hdl, list)
    local r = {pcall(call, F.SKILL_SET, hdl)}
    if r[1] ~= true or r[2] ~= true then
      return nil
    end
    -- r[1] pcall ok, r[2] answered, r[3..6] aura, mix, aura_from, mix_from, r[7..12] rows, r[13..18] techniques
    local rows = {}
    for i = 1, F.ROW_COUNT do
      local p = tonumber(r[6 + i]) or -1
      local id = U32(r[12 + i])
      local slot = p >= 0 and p or nil
      if id ~= 0 then
        rows[i] = {move = id, position = (slot ~= nil and list[slot] == id) and slot or nil, slot = slot}
      else
        rows[i] = {move = 0, slot = slot}
      end
    end
    return rows
  end

  -- the plate type of this VM's personal plate (personal_plate_inc SetPersonalPlateType: 1 = a match, its move rows
  -- get the match player's soccer handle); nil = not set
  EVT_PPG_Wrap("SetPersonalPlateType", function(orig)
    return function(kind, ...)
      F.plateType = kind
      return orig(kind, ...)
    end
  end)

  F.CARD_OF_SOCCER_CHARA = 24           -- GetSoccerCharaInfo(soccer handle, 24) -> ok, the player's card

  -- the card whose moves a plate row shows: the handle itself, or in a match the card of the soccer handle (the
  -- retail match fill reads the card the same way); nil = no card
  function F.Card(hdl)
    if F.plateType ~= 1 then
      return hdl
    end
    if type(GetSoccerCharaInfo) ~= "function" then
      return nil
    end
    local ok, found, card = pcall(GetSoccerCharaInfo, hdl, F.CARD_OF_SOCCER_CHARA)
    if ok and found ~= false and type(card) == "number" and card ~= 0 then
      return card
    end
    return nil
  end

  -- in a match, a player who plays a team member row (CharacterReforged.Page.MatchMemberSet: the set the hyper page
  -- shows too): his loadout's non-aura moves as the rows; nil = he plays his card's own set
  local function MatchMemberRows(hdl, list)
    local page = type(CharacterReforged) == "table" and CharacterReforged.Page or nil
    if F.plateType ~= 1 or type(page) ~= "table" or type(page.MatchMemberSet) ~= "function" then
      return nil
    end
    local ok, member = pcall(page.MatchMemberSet, hdl)
    if not ok or type(member) ~= "table" or type(member.techniques) ~= "table" then
      return nil
    end
    local rows = {}
    for i = 1, F.ROW_COUNT do
      local id = U32(member.techniques[i])
      local slot = member.rows ~= nil and member.rows[i] or nil
      if id ~= 0 then
        rows[i] = {move = id, position = (slot ~= nil and list[slot] == id) and slot or nil, slot = slot}
      else
        rows[i] = {move = 0}
      end
    end
    return rows
  end

  -- the 6 rows of card `hdl`: { [1..6] = {move = id, position = list position of that move or nil, slot = the row's
  -- list position (an aura position, an empty one or the move's own)} }; in a match a team member row's loadout,
  -- else the framework's effective skill set when it answers, else the same rule read here
  function F.Rows(call, hdl)
    local list, free, auras = {}, {}, {}
    for p = 0, F.ROW_COUNT - 1 do
      local id = U32(call(F.GET_SKILL, hdl, p))
      list[p] = id
      if IsAura(call, id) then
        auras[#auras + 1] = p
      else
        free[#free + 1] = p
      end
    end
    local member = MatchMemberRows(hdl, list)
    if member ~= nil then
      return member
    end
    local served = ServiceRows(call, hdl, list)
    if served ~= nil then
      return served
    end
    for _, p in ipairs(auras) do
      free[#free + 1] = p
    end
    local rows = {}
    for r = 1, F.ROW_COUNT do
      local p = free[r]
      local id = list[p] or 0
      if id ~= 0 then
        rows[r] = IsAura(call, id) and {move = 0, slot = p} or {move = id, position = p, slot = p}
      else
        local b = BoardMove(call, hdl, p)
        rows[r] = {move = (b ~= 0 and not IsAura(call, b)) and b or 0, slot = p}
      end
    end
    return rows
  end

  EVT_PPG_Wrap("SetupPersonalPlateCharaSkillItem", function(orig)
    return function(hdl, slot, ...)
      if type(hdl) ~= "number" or hdl == 0 or type(slot) ~= "number" or slot < 0 or slot >= F.ROW_COUNT
          or type(funcLuaCommand) ~= "function" or not F.On() then
        return orig(hdl, slot, ...)
      end
      local call = funcLuaCommand
      local card = F.Card(hdl)
      if card == nil then
        F.shown[slot] = nil
        return orig(hdl, slot, ...)
      end
      local okRows, rows = pcall(F.Rows, F.raw_call or call, card)
      if not okRows or type(rows) ~= "table" then
        F.shown[slot] = nil
        return orig(hdl, slot, ...)
      end
      local row = rows[slot + 1] or {move = 0}
      F.shown[slot] = {hdl = card, move = row.move, slot = row.slot or slot}
      -- a move above the player's level: the retail «not learned yet» row (padlock + its level); the match fill has
      -- no learn table (the match plays the set as it is)
      local need = 0
      if row.move ~= 0 and F.plateType ~= 1 then
        local okL, n, lv = pcall(call, F.LEARN_LEVEL, hdl, row.move)
        if okL and type(n) == "number" and type(lv) == "number" and n > lv then
          need = n
        end
      end
      local learnable = nil
      if need > 0 then
        local moves, levels = {}, {}
        for i = 1, F.ROW_COUNT do
          moves[i] = 0
          levels[i] = 0
        end
        moves[slot + 1] = row.move
        levels[slot + 1] = need
        learnable = {moves, levels}
      end
      local grade = GetSkillEvoLevelByCharaStHdl
      funcLuaCommand = function(cmd, a, b, ...)
        if a == card then
          if cmd == F.GET_SKILL and b == slot then
            return need > 0 and 0 or row.move
          end
          if cmd == F.LEARNABLE then
            if learnable ~= nil then
              return true, learnable[1], learnable[2]
            end
            return false
          end
        end
        return call(cmd, a, b, ...)
      end
      if type(grade) == "function" then
        GetSkillEvoLevelByCharaStHdl = function(h, p, ...)
          if h == card and p == slot then
            if row.position == nil then
              return 0
            end
            return grade(h, row.position, ...)
          end
          return grade(h, p, ...)
        end
      end
      local ok, r1, r2, r3 = pcall(orig, hdl, slot, ...)
      funcLuaCommand = call
      if type(grade) == "function" then
        GetSkillEvoLevelByCharaStHdl = grade
      end
      if not ok then
        pcall(call, @crc:CMND_EVT_LOG@, "EVT_PPG fantasy moves: retail row fill failed", tostring(r1))
        return orig(hdl, slot, ...)
      end
      return r1, r2, r3
    end
  end)

  -- 2026-10-14 (owner, Jade Beor in the «Confirmación de supertécnica» mode: focusing a row opened «Armadura — Metis»):
  -- the retail focus of a move row (soccer_formation_menu_inc OnChangeFocusCommon, the AI-use toggle) reads the move
  -- of the focused ROW INSTANCE straight from the list, GET_SKILL(card, instance), and opens its detail window
  -- (UpdateSkillDetailInfoWindow(move, instance): an aura there opens the aura card). With Fantasy the instance shows
  -- the skill table's row, not that list position: the window takes the row's own move (nothing for an empty / aura
  -- row) and its list position (the evolution grade). Only when the retail move is the one of the card whose rows
  -- this VM set up last (F.shown); anything else is the retail window.
  F.shown = F.shown or {}
  EVT_PPG_Wrap("UpdateSkillDetailInfoWindow", function(orig)
    return function(skill, slot, ...)
      local shown = type(slot) == "number" and F.shown[slot] or nil
      if shown == nil or type(funcLuaCommand) ~= "function" or not F.On() then
        return orig(skill, slot, ...)
      end
      local ok, listed = pcall(funcLuaCommand, F.GET_SKILL, shown.hdl, slot)
      if not ok or (U32(listed) ~= U32(skill) and U32(shown.move) ~= U32(skill)) then
        return orig(skill, slot, ...)
      end
      return orig(shown.move, shown.slot, ...)
    end
  end)

  -- 2026-10-14 (the «Confirmación de supertécnica» mode, soccer_formation_menu_inc): the AI-use toggle («X Desactivar
  -- IA», OnFunctionCommon 2941571381: AI_USE_GET / AI_USE_SET at the focused INSTANCE) and the move swap (OnEnterCommon
  -- on the skill layer: CMND_SET_SKILL(card, held move, target INSTANCE)) WRITE the save at the list position equal to
  -- the row instance. With Fantasy the instance shows the skill table's row, so both are sent to that row's own source:
  --   * a row showing the move of list position P: the commands act on P;
  --   * a row showing a board slot's move (its list position is empty): the move is not in the list, the game keeps no
  --     AI flag for it -> no AI toggle on that row (the guide hides it, the button does nothing) and no swap (the
  --     retail «cannot» sound);
  --   * an empty or aura row: nothing (the retail code already ignores a row whose shown move is 0).
  -- The focus of a row (OnChangeFocusCommon) reads the row's own move and AI flag the same way (detail window, swap
  -- frame, guide label). Victory Road: untouched.
  F.AI_USE_GET = 232181607              -- (charaStHdl, list position) -> the AI may use the move (nil = no move there)
  F.AI_USE_SET = 139872667              -- (charaStHdl, list position, allowed): writes the save
  F.SET_SKILL = @crc:CMND_SET_SKILL@              -- (charaStHdl, move, list position): swap, writes the save
  F.LIST_POSITION_OF = 26437624         -- (charaStHdl, move) -> its list position (6 or more = not in the list)
  F.FOCUSED_INSTANCE = 2603265800       -- menu command (layer) -> focused instance
  F.AI_TOGGLE_FUNCTION = 2941571381     -- OnFunctionCommon id of the AI-use toggle
  F.PLAY_SOUND = @crc:CMND_SND_PLAY_SE@
  F.CANNOT_SOUND = 3791946501           -- sy0004
  F.BOARD_PLACE = @crc:CMND_CHARACTERREFORGED_BOARD_PLACE@            -- (charaStHdl, inventory handle, board slot)
  F.BOARD_CLEAR = @crc:CMND_CHARACTERREFORGED_BOARD_CLEAR@            -- (charaStHdl, board slot, keepOpen)
  F.LOG = @crc:CMND_EVT_LOG@
  F.BOARD_SLOTS = 9                     -- board slots 0-8 (0-5 = list positions, 8 = the aura slot)

  -- the move on board slot `slot` of card `hdl` and its inventory handle (placed item, else the native one)
  local function BoardAt(call, hdl, slot)
    for _, kind in ipairs({1, 0}) do
      local okh, h = pcall(call, F.BOARD_INV, hdl, slot, kind)
      if okh and type(h) == "number" and h ~= 0 then
        local okm, m = pcall(call, F.INV_ITEM, h, 0)
        return (okm and U32(m or 0)) or 0, h
      end
    end
    return 0, 0
  end

  -- the game rebuilds a player's technique list from his board when a match loads: after a swap of list positions the
  -- board slots of those positions take the list's moves (Character Reforged's board commands), with the handles the
  -- board already holds. One log line per swap.
  function F.MirrorPositions(call, hdl, positions)
    local handle_of = {}
    for slot = 0, F.BOARD_SLOTS - 1 do
      local m, h = BoardAt(call, hdl, slot)
      if m ~= 0 and handle_of[m] == nil then
        handle_of[m] = h
      end
    end
    local todo, done = {}, {}
    for _, p in ipairs(positions) do
      local okw, want = pcall(call, F.GET_SKILL, hdl, p)
      want = okw and U32(want or 0) or 0
      local cur = BoardAt(call, hdl, p)
      if want ~= 0 and want ~= cur and handle_of[want] ~= nil then
        todo[#todo + 1] = {p = p, want = want}
      end
    end
    for _, t in ipairs(todo) do
      pcall(call, F.BOARD_CLEAR, hdl, t.p, 1)
    end
    for _, t in ipairs(todo) do
      local okp, st = pcall(call, F.BOARD_PLACE, hdl, handle_of[t.want], t.p)
      done[#done + 1] = string.format("slot %d %08X %s", t.p, t.want, (okp and st == 1) and "OK" or ("NO " .. tostring(st)))
    end
    if #done > 0 then
      pcall(call, F.LOG, "EVT_PPG fantasy moves: swap mirrored on the board", table.concat(done, ", "))
    end
  end

  local function SkillLayer()
    local layer = g_useFormationCharaSkillLayer
    return type(layer) == "number" and layer or nil
  end

  -- card and projected row ({move, position, slot}) shown by `instance` of this VM's rows, or nil
  local function RowOfInstance(call, instance)
    local shown = type(instance) == "number" and F.shown[instance] or nil
    if shown == nil then
      return nil
    end
    local ok, rows = pcall(F.Rows, call, shown.hdl)
    if not ok or type(rows) ~= "table" or rows[instance + 1] == nil then
      return nil
    end
    return shown.hdl, rows[instance + 1]
  end

  local function FocusedInstance(layer)
    if type(funcLuaMenuCommand) ~= "function" then
      return nil
    end
    local ok, instance = pcall(funcLuaMenuCommand, F.FOCUSED_INSTANCE, layer)
    return (ok and type(instance) == "number") and instance or nil
  end

  -- runs fn(...) with the reads / writes of card `hdl` at `instance` answered for its projected `row`: the AI-use
  -- commands go to the row's list position; no list position -> no AI flag and the AI setting reported off; the move
  -- read answers the row's move
  local function WithRowSource(call, hdl, instance, row, fn, ...)
    local position = row.position
    local enabled = IsAiSkillSettingsEnable
    F.raw_call = call
    funcLuaCommand = function(cmd, a, b, ...)
      if a == hdl and b == instance then
        if cmd == F.AI_USE_GET or cmd == F.AI_USE_SET then
          if position == nil then
            return nil
          end
          return call(cmd, a, position, ...)
        end
        if cmd == F.GET_SKILL then
          return row.move
        end
      end
      return call(cmd, a, b, ...)
    end
    local hideToggle = position == nil and type(enabled) == "function"
    if hideToggle then
      IsAiSkillSettingsEnable = function()
        return false
      end
    end
    local results = table.pack(pcall(fn, ...))
    funcLuaCommand = call
    F.raw_call = nil
    if hideToggle then
      IsAiSkillSettingsEnable = enabled
    end
    if not results[1] then
      error(results[2], 0)
    end
    return table.unpack(results, 2, results.n)
  end

  EVT_PPG_Wrap("OnChangeFocusCommon", function(orig)
    return function(a1, ...)
      local layer = SkillLayer()
      if layer == nil or a1 ~= layer or type(funcLuaCommand) ~= "function" or not F.On() then
        return orig(a1, ...)
      end
      local call = funcLuaCommand
      local instance = FocusedInstance(layer)
      local hdl, row = RowOfInstance(call, instance)
      if row == nil then
        return orig(a1, ...)
      end
      return WithRowSource(call, hdl, instance, row, orig, a1, ...)
    end
  end)

  EVT_PPG_Wrap("OnFunctionCommon", function(orig)
    return function(a1, ...)
      local layer = SkillLayer()
      if a1 ~= F.AI_TOGGLE_FUNCTION or layer == nil or type(funcLuaCommand) ~= "function" or not F.On() then
        return orig(a1, ...)
      end
      local call = funcLuaCommand
      local instance = FocusedInstance(layer)
      local hdl, row = RowOfInstance(call, instance)
      if row == nil then
        return orig(a1, ...)
      end
      return WithRowSource(call, hdl, instance, row, orig, a1, ...)
    end
  end)

  -- the swap: a row showing a board slot's move can be neither held nor a target; CMND_SET_SKILL's target instance
  -- becomes the target row's list position (the held move is found in the list by the engine itself). The override
  -- stays while the retail swap animation waits (only CMND_SET_SKILL with a row index is touched).
  EVT_PPG_Wrap("OnEnterCommon", function(orig)
    return function(a1, a2, ...)
      local layer = SkillLayer()
      if layer == nil or a1 ~= layer or type(a2) ~= "number" or type(funcLuaCommand) ~= "function" or not F.On() then
        return orig(a1, a2, ...)
      end
      local call = funcLuaCommand
      local hdl, row = RowOfInstance(call, a2)
      if row == nil then
        return orig(a1, a2, ...)
      end
      if row.move ~= 0 and row.position == nil then
        pcall(call, F.PLAY_SOUND, F.CANNOT_SOUND)
        return
      end
      local swap = function(cmd, card, move, instance, ...)
        if cmd ~= F.SET_SKILL or type(instance) ~= "number" or instance < 0 or instance >= F.ROW_COUNT then
          return call(cmd, card, move, instance, ...)
        end
        local okRows, rows = pcall(F.Rows, call, card)
        local target = (okRows and type(rows) == "table") and rows[instance + 1] or nil
        local okFrom, from = pcall(call, F.LIST_POSITION_OF, card, move)
        if target == nil or target.position == nil or not okFrom or type(from) ~= "number" or from < 0
            or from >= F.ROW_COUNT then
          pcall(call, @crc:CMND_EVT_LOG@, "EVT_PPG fantasy moves: swap refused", tostring(move), tostring(instance))
          pcall(call, F.PLAY_SOUND, F.CANNOT_SOUND)
          return false
        end
        local results = table.pack(call(cmd, card, move, target.position, ...))
        pcall(F.MirrorPositions, call, card, {from, target.position})
        return table.unpack(results, 1, results.n)
      end
      funcLuaCommand = swap
      local results = table.pack(pcall(orig, a1, a2, ...))
      if funcLuaCommand == swap then
        funcLuaCommand = call
      end
      if not results[1] then
        error(results[2], 0)
      end
      return table.unpack(results, 2, results.n)
    end
  end)
end
