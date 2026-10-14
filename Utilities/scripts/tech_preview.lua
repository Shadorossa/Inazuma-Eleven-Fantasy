-- Utilities › technique preview (docs/game/ui/technique-preview.md): on the special move card of the «Supertécnicas»
-- list (ability_list_menu, card team02_02_skill_detail_info) the prompt «<RS> Previsualizar» plays the move's cut-in
-- full screen, performed by a player of the ACTIVE squad, and comes back to the list as it was. This script answers
-- WHAT to play (the move's event, its category, the performer, his character name and body rig); the menu side (graft
-- research/grafts/util_tech_preview, assets\lua\_all\utilities_tech_preview.lua) plays it with the VR-Framework's
-- live player (CMND_EVT_ANIM_PREVIEW + CMND_RESERVE_EVENT + CMND_VRFW_ANIM_LIVE_*, the path the Mods screen's
-- technique viewer and Inazuma Fantasy's miximax scene use).
--
-- Nothing is named here: the move's event and category come from the served skill table (skill/skill: event_id_name,
-- category, partner_type), the learn lists from the framework's learn-level service (VRFW.learn), the squad from the game's
-- party (the active vs set, the layout of lib/tb_store), the character name / body from the framework's character
-- index and chara_model / chara_body. Tunables: config.toml [tech_preview].
--
-- Commands (content\game\tech_preview.toml; crc32 of the name):
--   CMND_UTIL_TECH_PREVIEW(skill) -> ok (0 / 1), event, performer handle, chara name, body (1-4), category, why
--   CMND_UTIL_TECH_PREVIEW_CFG()  -> a table of the menu side's tunables (crc32 of the menu / layer names, numbers)

local S = require "lib/tb_store"

Utilities = Utilities or {}
Utilities.TechPreview = Utilities.TechPreview or {}
local TP = Utilities.TechPreview

local function info(...) VRFW.log("tech_preview:", ...) end
local function warn(...) VRFW.warn("tech_preview:", ...) end

local band = bit32.band
local function u32(v) return band(tonumber(v) or 0, 0xFFFFFFFF) end
local function hex(v) v = u32(v); return string.format("0x%04X%04X", math.floor(v / 65536), v % 65536) end

-- ---------------------------------------------------------------------------------------- settings

local cfg = {
  -- the squad's first `lineup` members are the starting eleven (the rest: the bench)
  lineup = 11,
  -- skill category (skill_config `category`: 1 shoot, 2 offense, 3 defense, 4 keeper) -> card main position
  -- (chara_param `main_position`: 1 GK, 2 FW, 3 MF, 4 DF)
  positions = { ["1"] = 2, ["2"] = 3, ["3"] = 4, ["4"] = 1 },
  -- prefer a player whose card learns the move (chara_param learn list) over the first one at the position
  prefer_learners = true,
  -- the menus that must exist for the preview (the menu-scene team dock: from the title or the main hub) and the ones
  -- that turn it off (Chronicle / story field menus: their scene runs the game's own event dispatcher)
  need_any_menu = { "team_dock_common_top_menu", "soccer_top_menu" },
  off_with_menus = { "chronicle_mode_top_menu", "team_dock_menu_rpg_battle" },
  -- the menus hidden (and suspended) while the cut-in plays, if open, in this order; shown again in reverse
  hide_menus = { "ability_list_menu", "sub_window", "item_filter_menu", "ability_learning_board_menu",
    "personal_plate_menu", "team_dock_formation_menu", "soccer_formation_menu", "soccer_team_dock_menu",
    "team_dock_common_top_menu", "soccer_top_menu" },
  -- the header / guide layers hidden in those menus' own context (assets\lua\_all\utilities_tech_preview.lua)
  bar_menus = { "team_dock_common_top_menu", "soccer_top_menu", "soccer_team_dock_menu" },
  bar_layers = { "mainmenu90_01_header", "mainmenu90_03_header_rank", "mainmenu90_31_doc_item",
    "mainmenu90_05_content_guide_line01", "mainmenu90_06_content_guide_line03", "mainmenu01_06_base_button_guide" },
  -- the one-model menu that holds the performer's model while the cut-in plays (an event over the menus only binds
  -- actors to models a menu holds: docs/game/media/miximax-cutscene-cs.md §9.9-9.12) and its model layer
  carrier_menu = "chara_model_only_view_menu",
  carrier_layer = "rpg99_99_chara_model_only_view",
  -- the menu scene's blue backdrop (craft object) put behind the cut-in, as the miximax scene does; "" = none
  backdrop = "bg10000",
  -- prompt offset from the place of the card's retail page guide (menu px, x right / y up)
  hint_x = 0,
  hint_y = 0,
  -- seconds: fade out / in around the cut-in, BGM fade, the longest wait for the model and for the scene
  fade_s = 0.3,
  bgm_fade_s = 0.5,
  model_wait_frames = 300,
  max_seconds = 120,
  -- B (CMD_CANCEL) during the cut-in ends it (the game's own hold-to-skip of the event works too)
  back_skips = true,
  -- log every answer of CMND_UTIL_TECH_PREVIEW (one line per move asked; the play itself always logs)
  log_queries = false,
}

do
  local ok, c = pcall(VRFW.files.config, "tech_preview")
  if ok and type(c) == "table" then
    for k, v in pairs(c) do
      if cfg[k] ~= nil and type(v) == type(cfg[k]) then cfg[k] = v end
    end
  end
end

-- ---------------------------------------------------------------------------------------- the moves

local MOVES = nil     -- skill id -> { event, category, players }
local function moves()
  if MOVES then return MOVES end
  MOVES = {}
  local ok, rows = pcall(VRFW.table.rows, "skill/skill")
  if not ok or type(rows) ~= "table" then
    warn("skill/skill not readable: " .. tostring(rows) .. " (no preview)")
    return MOVES
  end
  local n = 0
  for _, r in ipairs(rows) do
    local ev = r.event_id_name
    if type(ev) == "string" and ev ~= "" then
      MOVES[u32(r.skill_id)] = { event = ev, category = tonumber(r.category) or 0, players = tonumber(r.partner_type) or 0 }
      n = n + 1
    end
  end
  info(n .. " moves with a cut-in (skill/skill event_id_name)")
  return MOVES
end

-- does card `param` learn move `skill`? (the framework's learn-level service: the card's effective learn list, mods'
-- learn lists included); nil when the service has no answer
local function learns(param, skill)
  if not (VRFW.learn and VRFW.learn.learnset) then return nil end
  local ok, set = pcall(VRFW.learn.learnset, param)
  if not ok or type(set) ~= "table" then return nil end
  for _, e in ipairs(set) do
    if type(e) == "table" and u32(e[1] or e.move) == skill then return true end
  end
  return false
end

-- ---------------------------------------------------------------------------------------- body rigs

local MODEL_BODY = nil   -- chara_model id -> rig 1-4
local function rig_of_path(p)
  local d = tostring(p or ""):match("c000(%d)01")
  local n = tonumber(d)
  if n and n >= 1 and n <= 4 then return n end
  return nil
end
local function model_bodies()
  if MODEL_BODY then return MODEL_BODY end
  MODEL_BODY = {}
  local okb, bodies = pcall(VRFW.table.rows, "character/chara_body")
  local by_body = {}
  if okb and type(bodies) == "table" then
    for _, b in ipairs(bodies) do by_body[u32(b.id)] = rig_of_path(b.skeleton_path) end
  end
  local okm, models = pcall(VRFW.table.rows, "character/chara_model")
  if okm and type(models) == "table" then
    for _, m in ipairs(models) do
      MODEL_BODY[u32(m.id)] = by_body[u32(m.body)] or rig_of_path(m.skeleton_path)
    end
  else
    warn("character/chara_model not readable: " .. tostring(models) .. " (body rig 1 for everyone)")
  end
  return MODEL_BODY
end

local BASE_MODEL = nil   -- chara_base id -> chara_model id
local function base_model(base)
  if not BASE_MODEL then
    BASE_MODEL = {}
    local ok, rows = pcall(VRFW.table.rows, "character/chara_base")
    if ok and type(rows) == "table" then
      for _, r in ipairs(rows) do
        local id = u32(r.id)
        if id ~= 0 and BASE_MODEL[id] == nil then BASE_MODEL[id] = u32(r.model) end
      end
    end
  end
  return BASE_MODEL[u32(base)]
end

-- ---------------------------------------------------------------------------------------- the active squad

local function rd(ty, at)
  if type(at) ~= "number" or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

-- the active squad's members in slot order: { { hdl, param, base, position } } (nil, why when unreadable)
local function squad()
  local okp, party = pcall(VRFW.game.tb_party)
  if not okp or type(party) ~= "number" or party < 0x10000 then return nil, "no party" end
  local logical = rd("u8", party + S.ACTIVE_OFF)
  if logical == nil or logical > 15 then return nil, "no active squad" end
  local okm, phys = pcall(VRFW.call, "TB_LogicalToPhysical", 0, logical)
  if not okm or type(phys) ~= "number" or phys < 0 or phys > 15 then return nil, "no physical squad" end
  local data = rd("ptr", party + S.PARTY_SET_DATA)
  if data == nil then return nil, "no squad data" end
  local team = data + phys * S.SET_SIZE
  local out = {}
  for k = 0, S.MEMBERS - 1 do
    local h = rd("u32", team + S.MEMBER_LIST + k * S.MEMBER_STRIDE)
    if h ~= nil and h ~= 0 then
      local okr, r = pcall(VRFW.chara.record, h)
      if okr and type(r) == "table" and type(r.param) == "number" then
        local okc, card = pcall(VRFW.chara.card, r.param)
        card = okc and card or nil
        out[#out + 1] = { hdl = h, param = u32(r.param), base = card and card.base or nil,
          position = card and tonumber(card.position) or 0, slot = k }
      end
    end
  end
  if #out == 0 then return nil, "the active squad is empty" end
  return out
end

-- the performer: a starter at the position who learns the move, a starter who learns it, a starter at the position,
-- the same on the bench, else the first starter
local function pick(members, skill, want)
  local lineup = math.max(1, tonumber(cfg.lineup) or 11)
  local known = {}
  local function knows(m)
    if not cfg.prefer_learners then return false end
    if known[m.param] == nil then known[m.param] = learns(m.param, skill) == true end
    return known[m.param]
  end
  local passes = {
    { "starter, position + learns it", function(m, i) return i <= lineup and m.position == want and knows(m) end },
    { "starter, learns it", function(m, i) return i <= lineup and knows(m) end },
    { "starter at the position", function(m, i) return i <= lineup and m.position == want end },
    { "bench, position + learns it", function(m, i) return i > lineup and m.position == want and knows(m) end },
    { "bench at the position", function(m, i) return i > lineup and m.position == want end },
    { "first starter", function(_, i) return i == 1 end },
  }
  for _, p in ipairs(passes) do
    for i, m in ipairs(members) do
      if m.base and p[2](m, i) then return m, p[1] end
    end
  end
  return nil, "no member with a character"
end

-- ---------------------------------------------------------------------------------------- commands

local last_logged = nil

-- CMND_UTIL_TECH_PREVIEW(skill) -> ok (0 / 1), event, performer handle, chara name, body (1-4), category, why
function TP.Plan(skill)
  skill = u32(skill)
  local function no(why)
    if cfg.log_queries and last_logged ~= skill then
      last_logged = skill
      info("move " .. hex(skill) .. ": no preview (" .. why .. ")")
    end
    return 0, "", 0, "", 0, 0, why
  end
  if skill == 0 then return no("no move") end
  local mv = moves()[skill]
  if not mv then return no("not a special move with a cut-in") end
  local want = tonumber(cfg.positions[tostring(mv.category)]) or 0
  local members, why = squad()
  if not members then return no(why) end
  local m, how = pick(members, skill, want)
  if not m then return no(how) end
  local okc, ch = pcall(VRFW.chara.character, m.base)
  local name = okc and type(ch) == "table" and ch.name or nil
  if type(name) ~= "string" or name == "" then return no("the performer's character has no name") end
  local body = model_bodies()[base_model(m.base) or 0] or 1
  if cfg.log_queries and last_logged ~= skill then
    last_logged = skill
    info(string.format("move %s: %s (category %d, %d player(s)) by %s (card %s, slot %d, position %d: %s), body %d",
      hex(skill), mv.event, mv.category, math.max(1, mv.players), name, hex(m.param), m.slot, m.position, how, body))
  end
  return 1, mv.event, m.hdl, name, body, mv.category, how
end

local function crcs(list)
  local out = {}
  for i, s in ipairs(list or {}) do out[i] = VRFW.crc32(s) end
  return out
end

-- CMND_UTIL_TECH_PREVIEW_CFG() -> the menu side's tunables
function TP.Config()
  return {
    need_any = crcs(cfg.need_any_menu), off_with = crcs(cfg.off_with_menus), hide = crcs(cfg.hide_menus),
    bar_menus = crcs(cfg.bar_menus), bar_layers = crcs(cfg.bar_layers),
    carrier = VRFW.crc32(cfg.carrier_menu), carrier_layer = VRFW.crc32(cfg.carrier_layer),
    backdrop = cfg.backdrop ~= "" and VRFW.crc32(cfg.backdrop) or 0,
    hint_x = tonumber(cfg.hint_x) or 0, hint_y = tonumber(cfg.hint_y) or 0,
    fade_s = tonumber(cfg.fade_s) or 0.3, bgm_fade_s = tonumber(cfg.bgm_fade_s) or 0.5,
    model_wait = tonumber(cfg.model_wait_frames) or 300, max_frames = math.floor((tonumber(cfg.max_seconds) or 120) * 60),
    back_skips = cfg.back_skips and 1 or 0,
  }
end

-- the tables are read at load (the load gets 10 budgets); a table that was not readable then is read again when a card
-- asks
do
  local ok, e = pcall(function() moves(); model_bodies(); base_model(0) end)
  if not ok then
    warn("tables not read at load (" .. tostring(e) .. "): read when a card asks")
    MOVES, MODEL_BODY, BASE_MODEL = nil, nil, nil
  end
end
info("ready")
