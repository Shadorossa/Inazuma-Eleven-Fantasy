-- Utilities › friends panel («Lista de amigos», docs/game/ui/friends.md): a narrow side panel on the right of the menus
-- with the player's Steam friends in one list, sorted by status (in Inazuma Eleven VR, online, away, offline) then by
-- name. A friend with the mod opens his details next to the list: active team (formation + faces), the career summary,
-- the lines other mods add; actions: invite to my Battle Bay private room, join his, send my team code, the mods we
-- differ in, Steam profile. Mechanism = the VR-Framework's friends API (VRFW.net.*; Steam through the game's own
-- steam_api64.dll and the framework's own transport, never EOS / EAC). The panel itself is
-- assets\lua\_all\utilities_friends.lua (every hub of the top bar; layers of content\menus\friends_panel.toml).
--
-- Commands (crc32 of the name; the panel uses the numbers):
--   CMND_UTIL_FRIENDS_OPEN(refresh, lang code) -> ready, rows, inbox count, error, panel art texture
--   CMND_UTIL_FRIENDS_LAYOUT() -> panel x, width, top, row height, header height, details width, slide frames
--   CMND_UTIL_FRIENDS_ROW(i) -> kind ("friend" / "none"), group, name, status key, dot, badge, room (bool),
--                               avatar texture, avatar sprite, friend id
--   CMND_UTIL_FRIENDS_ACTIONS(i) -> action keys, comma-separated (invite, join, code, mods, profile)
--   CMND_UTIL_FRIENDS_DO(i, action) -> state ("ok" / "wait" / "error"), text
--   CMND_UTIL_FRIENDS_POLL(i, action) -> state ("wait" / "ok" / "error"), text (the mod difference lines)
--   CMND_UTIL_FRIENDS_DETAILS(i) -> asked (bool: the profile is being asked for)
--   CMND_UTIL_FRIENDS_DETAILS_POLL(i) -> state ("wait" / "ok" / "error"), team name, formation name,
--                                       faces ("chara_base:level:name|…"), stats ("key\tname\tvalue" lines)
--   CMND_UTIL_FRIENDS_INBOX() -> the next received item: kind ("code" / "invite" / ""), sender's name, team lines, data
--   CMND_UTIL_FRIENDS_STATUS(menu stem) -> status published ("" = this menu sets none)
-- Export (mod.toml [exports]): Utilities.FriendsProfileLine(label, value) — a line another mod adds to the profile
-- friends see (e.g. Chronicle progress, Battle Bay record), in the sender's language; value "" removes it.

local F = require "lib/fr_core"
local S = require "lib/tb_store"
local T = require "lib/original_names_tables"
local CS = require "lib/career_store"

Utilities = Utilities or {}
Utilities.Friends = Utilities.Friends or {}

-- the panel's atlas (content/images/menu/220_img/util_friends.toml), answered to the panel as before
local PANEL_ART = "#/menu/220_img/util_friends/util_friends.g4tx"
local KIND_PROFILE = "utilities.profile"
local KIND_CODE = "utilities.team_code"
local KIND_MODS = "vrfw.mod_set"
local KIND_INVITE = "vrfw.invite"

local function info(...) VRFW.log("friends:", ...) end
local function warn(...) VRFW.warn("friends:", ...) end

-- ---------------------------------------------------------------------------------------- settings

local cfg = {
  enabled = true,
  profile_refresh_s = 30,
  panel = { x = 1440, width = 480, top = 72, row_h = 64, head_h = 72, details_w = 560, slide_frames = 10 },
  status_menus = {
    bb = { "bb_stadium_top_menu", "enjoy_team_select_menu" },
    menu = { "soccer_top_menu", "market_menu", "item_menu", "play_guide_top_menu", "chronicle_mode_top_menu",
             "victory_road_top_menu", "information_top_menu", "team_dock_common_top_menu", "title_menu_2" },
  },
}

do
  local ok, c = pcall(VRFW.files.config, "friends")
  if ok and type(c) == "table" then
    if type(c.enabled) == "boolean" then cfg.enabled = c.enabled end
    local r = c.profile_refresh_s or c.team_refresh_s
    if type(r) == "number" and r >= 5 then cfg.profile_refresh_s = r end
    if type(c.panel) == "table" then
      for k, v in pairs(c.panel) do
        if cfg.panel[k] ~= nil and type(v) == "number" then cfg.panel[k] = v end
      end
    end
    if type(c.status_menus) == "table" then
      local m = {}
      for status, menus in pairs(c.status_menus) do
        if type(menus) == "table" then m[status] = menus end
      end
      cfg.status_menus = m
    end
  end
end

-- ---------------------------------------------------------------------------------------- the net service

local function net(op, ...)
  if type(VRFW.net) ~= "table" or type(VRFW.net[op]) ~= "function" then
    return nil, "the VR-Framework has no VRFW.net." .. op .. " (update it)"
  end
  local ok, r = pcall(VRFW.net[op], ...)
  if not ok then return nil, tostring(r) end
  return r
end

local function result(r, err)
  if type(r) ~= "table" then return false, err or "no answer" end
  if r.ok == false then return false, tostring(r.error) end
  return true, r.value
end

-- ---------------------------------------------------------------------------------------- the active team

local function rd(ty, at)
  if type(at) ~= "number" or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

-- [inferred] the team's formation id: the first field after the 29 member slots (TeamInfo +0x250, docs/game/mechanics/
-- team-squads-extended.md §1.3); the receiver shows it only when it is a formation_config form_id
local FORMATION_OFF = 0x250

-- the active squad (the vs active set's team 0): name, formation id, { { param, level, rarity } } or nil
local function active_team()
  local okp, party = pcall(VRFW.game.tb_party)
  if not okp or type(party) ~= "number" or party < 0x10000 then return nil end
  local logical = rd("u8", party + S.ACTIVE_OFF)
  if logical == nil or logical > 15 then return nil end
  local okm, phys = pcall(VRFW.call, "TB_LogicalToPhysical", 0, logical)
  if not okm or type(phys) ~= "number" or phys < 0 or phys > 15 then return nil end
  local data = rd("ptr", party + S.PARTY_SET_DATA)
  if data == nil then return nil end
  local team = data + phys * S.SET_SIZE
  local bytes = {}
  for i = 0, 63 do
    local b = rd("u8", team + i)
    if b == nil or b == 0 then break end
    bytes[#bytes + 1] = string.char(b)
  end
  local members = {}
  for k = 0, S.MEMBERS - 1 do
    local h = rd("u32", team + S.MEMBER_LIST + k * S.MEMBER_STRIDE)
    if h ~= nil and h ~= 0 then
      local okr, r = pcall(VRFW.chara.record, h)
      if okr and type(r) == "table" and type(r.param) == "number" then
        members[#members + 1] = { r.param, r.level or 0, r.rarity or 0 }
      end
    end
  end
  return table.concat(bytes), rd("u32", team + FORMATION_OFF) or 0, members
end

-- the career summary of the active slot (career.json of scripts\career.lua): { key, param, value } of the most
-- matches, the top scorer, the most MVP awards
-- (decoded again only when the slot or its career.json changed: the decode was most of the panel's Open time)
local career_cache = { slot = nil, text = nil, out = {} }

local function career_summary()
  local okS, slot = pcall(VRFW.slots.active)
  if not okS or type(slot) ~= "number" then return {} end
  local okB, text = pcall(VRFW.save.blob, CS.BLOB, slot)
  if not okB or type(text) ~= "string" then return {} end
  if career_cache.slot == slot and career_cache.text == text then return career_cache.out end
  local okD, f = pcall(CS.decode, text, slot)
  if not okD or type(f) ~= "table" or type(f.players) ~= "table" then return {} end
  local best = {}
  for _, p in pairs(f.players) do
    if type(p) == "table" and tonumber(p.param) then
      for _, k in ipairs({ "matches", "goals", "mvp" }) do
        local v = tonumber(p[k]) or 0
        if v > 0 and (best[k] == nil or v > best[k][2]) then best[k] = { tonumber(p.param), v } end
      end
    end
  end
  local out = {}
  for _, k in ipairs({ "matches", "goals", "mvp" }) do
    if best[k] then out[#out + 1] = { k, best[k][1], best[k][2] } end
  end
  career_cache.slot, career_cache.text, career_cache.out = slot, text, out
  return out
end

-- lines other mods add (Utilities.FriendsProfileLine)
local extra = {}
local extra_order = {}

local function clean(s)
  return (tostring(s or ""):gsub("[|\n\r\t]", " "))
end

local profile_at, profile_desc, team_desc = nil, nil, nil
-- the panel's Open forces a fresh profile, but not again within this many ms (the panel reloads its list every ~5 s
-- while open; nothing of the profile can change meanwhile, the panel holds the menu's input)
local OPEN_FORCE_MS = 15000

-- the profile friends get when they ask (VRFW.net.share_set), at most every profile_refresh_s
local function share_profile(force)
  local now = VRFW.now()
  if not force and profile_at ~= nil and now - profile_at < cfg.profile_refresh_s * 1000 then return profile_desc end
  profile_at = now
  local name, form, members = active_team()
  local lines = { "p1" }
  if name ~= nil then
    team_desc = F.encode_team(name, members)
    lines[#lines + 1] = "team|" .. clean(name) .. "|" .. tostring(form or 0)
    local m = {}
    for i, x in ipairs(members) do
      if i > F.MAX_MEMBERS then break end
      m[#m + 1] = F.int(x[1]) .. ":" .. F.int(x[2]) .. ":" .. F.int(x[3])
    end
    lines[#lines + 1] = "m|" .. table.concat(m, ",")
  end
  for _, c in ipairs(career_summary()) do
    lines[#lines + 1] = tostring(c[1]) .. "|" .. F.int(c[2]) .. "|" .. F.int(c[3])
  end
  for _, label in ipairs(extra_order) do
    if extra[label] ~= nil then lines[#lines + 1] = "x|" .. clean(label) .. "|" .. clean(extra[label]) end
  end
  local d = table.concat(lines, "\n")
  if d ~= profile_desc then
    local ok, err = result(net("share_set", KIND_PROFILE, d))
    if not ok then warn("share_set: " .. tostring(err)) end
    profile_desc = d
  end
  return profile_desc
end

function Utilities.FriendsProfileLine(label, value)
  label = clean(label):sub(1, 48)
  if label == "" then return false end
  if value == nil or value == "" then
    extra[label] = nil
  else
    if extra[label] == nil then extra_order[#extra_order + 1] = label end
    extra[label] = clean(value):sub(1, 64)
  end
  profile_at = nil
  return true
end

-- ---------------------------------------------------------------------------------------- names

local names = nil   -- { lang, base = { [param] = chara_base | false }, text = { [chara_base] = name text id | false }, rows, forms, nouns }

local function lang_of(code)
  local c = type(code) == "number" and math.floor(code) or nil
  if c and c >= 0 and type(VRFW.files.game_languages) == "function" then
    local ok, t = pcall(VRFW.files.game_languages)
    local l = ok and type(t) == "table" and t[c + 1] or nil
    if type(l) == "string" then return l end
  end
  return "en"
end

local function load_names(lang)
  if names and names.lang == lang then return names end
  -- card -> character -> name text come from the framework's shared character index (VRFW.chara.*,
  -- docs/framework/chara-index.md), asked per shown player (name_of / base_of): no chara_param / chara_base read in this
  -- VM (each was a full-table scan, ~100+ ms on the game thread, and a large heap kept for the session)
  local n = { lang = lang, base = {}, text = {}, forms = {}, nouns = {} }
  pcall(function()
    for _, r in ipairs(VRFW.table.rows("formation/formation")) do
      if type(r.form_id) == "number" then
        n.forms[bit32.band(r.form_id, 0xFFFFFFFF)] = bit32.band(r.noun_id or 0, 0xFFFFFFFF)
      end
    end
    for _, r in ipairs(VRFW.table.raw("data/common/text/" .. lang .. "/item_text.cfg.bin", "NOUN_INFO")) do
      if type(r[1]) == "number" and type(r[6]) == "string" then n.nouns[bit32.band(r[1], 0xFFFFFFFF)] = r[6] end
    end
  end)
  local okt, rows = pcall(VRFW.files.text_rows, T.text_key(lang, T.CHARA))
  if (not okt or type(rows) ~= "table") and lang ~= "en" then
    okt, rows = pcall(VRFW.files.text_rows, T.text_key("en", T.CHARA))
  end
  n.rows = (okt and type(rows) == "table") and rows or {}
  names = n
  return n
end

-- the character of a card (cached per card; false = unknown)
local function base_of(param)
  local n = names
  if not n or type(param) ~= "number" then return nil end
  local b = n.base[param]
  if b == nil then
    local ok, c = pcall(VRFW.chara.base_of, param)
    b = (ok and type(c) == "number") and c or false
    n.base[param] = b
  end
  return b or nil
end

-- the name text id of a character (cached; false = unknown)
local function name_text_of(b)
  local n = names
  if not n or not b then return nil end
  local id = n.text[b]
  if id == nil then
    local ok, c = pcall(VRFW.chara.character, b)
    id = (ok and type(c) == "table" and type(c.name_text) == "number") and c.name_text or false
    n.text[b] = id
  end
  return id or nil
end

local function name_of(param)
  local n = names
  local id = name_text_of(base_of(param))
  local r = id and n.rows[id]
  local s = r and r[0]
  if type(s) == "string" and s ~= "" then return T.strip_furigana(s) end
  return "#" .. F.int(param)
end

local function formation_of(form)
  local n = names
  local noun = n and n.forms[form]
  local s = noun and n.nouns[noun]
  if type(s) == "string" and s ~= "" then return T.strip_furigana(s) end
  return ""
end

-- a team description as lines: the team's name, then «Lv 45  Name» per member
local function team_lines(desc)
  local tname, members = F.decode_team(desc)
  if tname == nil then return "" end
  local out = { tname ~= "" and tname or "—" }
  for _, m in ipairs(members) do
    out[#out + 1] = "Lv " .. F.int(m[2]) .. "  " .. name_of(m[1])
  end
  return table.concat(out, "\n")
end

-- ---------------------------------------------------------------------------------------- the panel's rows

local view = { rows = {}, lang = "en" }

-- the avatars the framework served, per friend id: { texture, sprite, asked at (ms) }. Each VRFW.net.friend_avatar
-- copies and hashes the friend's whole RGBA avatar, and the panel asks every row on each list reload (~5 s), so an
-- answer is reused for AVATAR_TTL_MS (a changed avatar shows at most that late)
local avatars = {}
local AVATAR_TTL_MS = 60000

-- the list the panel scrolls: the Steam friends only, by status (in the game, online, away, offline) then by name; an
-- empty list is one «nadie» row
local DOT_ORDER = { game = 1, on = 2, away = 3, off = 4 }

local function dot_of(f)
  if f.in_game then return "game" end
  if f.online ~= true then return "off" end
  if f.persona == "away" or f.persona == "snooze" or f.persona == "busy" then return "away" end
  return "on"
end

local function badge_of(f)
  if f.group == "same" then return "ok" end
  if f.group == "different" then return "warn" end
  return ""
end

local function build_rows(list)
  local friends = {}
  for _, f in ipairs(list) do
    if f.steam_friend == true then friends[#friends + 1] = f end
  end
  table.sort(friends, function(a, b)
    local da, db = DOT_ORDER[dot_of(a)] or 4, DOT_ORDER[dot_of(b)] or 4
    if da ~= db then return da < db end
    return tostring(a.name):lower() < tostring(b.name):lower()
  end)
  local rows = {}
  for _, f in ipairs(friends) do
    rows[#rows + 1] = { kind = "friend", group = f.group, f = f }
  end
  if #rows == 0 then rows[1] = { kind = "none", group = "" } end
  return rows
end

function Utilities.Friends.Open(refresh, code)
  if not cfg.enabled then return false, 0, 0, "disabled", "" end
  view.lang = lang_of(code)
  -- the profile is not the panel: a failure there never costs the list
  local recent = profile_at ~= nil and VRFW.now() - profile_at < OPEN_FORCE_MS
  local okS, errS = pcall(share_profile, not recent)
  if not okS then warn("profile: " .. tostring(errS)) end
  local okA, art = true, PANEL_ART
  local r, err = net("friends", refresh == true)
  if type(r) ~= "table" or r.ready ~= true then
    local e = type(r) == "table" and tostring(r.error) or tostring(err)
    warn("no friend list: " .. e)
    view.rows = build_rows({})
    return false, #view.rows, 0, e, okA and tostring(art) or ""
  end
  view.rows = build_rows(type(r.list) == "table" and r.list or {})
  info(string.format("panel: %d Steam friend row(s), inbox %s", #view.rows, tostring(r.inbox)))
  return true, #view.rows, tonumber(r.inbox) or 0, "", okA and tostring(art) or ""
end

-- the panel's layout (config.toml [friends.panel])
function Utilities.Friends.Layout()
  local p = cfg.panel
  return p.x, p.width, p.top, p.row_h, p.head_h, p.details_w, p.slide_frames
end

function Utilities.Friends.Row(i)
  local row = view.rows[math.floor(tonumber(i) or 0)]
  if row == nil then return "" end
  if row.kind ~= "friend" then
    return row.kind, row.group, "", "", "", "", false, "", "", ""
  end
  local f = row.f
  local tex, sprite = "", ""
  local now = VRFW.now()
  local c = avatars[f.id]
  if c ~= nil and now - c[3] < AVATAR_TTL_MS then
    tex, sprite = c[1], c[2]
  else
    local a = net("friend_avatar", f.id)
    if type(a) == "table" and a.ready == true then
      tex, sprite = tostring(a.texture), tostring(a.sprite)
      avatars[f.id] = { tex, sprite, now }
    end
  end
  return "friend", tostring(f.group), tostring(f.name), tostring(f.status_key), dot_of(f), badge_of(f), f.room == true,
    tex, sprite, tostring(f.id)
end

local function friend(i)
  local row = view.rows[math.floor(tonumber(i) or 0)]
  return row and row.kind == "friend" and row.f or nil
end

function Utilities.Friends.Actions(i)
  local f = friend(i)
  if f == nil then return "" end
  return table.concat(F.actions(f, net("status")), ",")
end

-- ---------------------------------------------------------------------------------------- actions

function Utilities.Friends.Do(i, action)
  local f = friend(i)
  if f == nil then return "error", "no such row" end
  if action == "invite" then
    local ok, err = result(net("friend_invite", f.id))
    return ok and "ok" or "error", ok and "" or tostring(err)
  elseif action == "join" then
    local ok, v = result(net("friend_join", f.id))
    return ok and "ok" or "error", tostring(v or "")
  elseif action == "mods" then
    local ok, err = result(net("friend_ask", f.id, KIND_MODS))
    return ok and "wait" or "error", ok and "" or tostring(err)
  elseif action == "code" then
    share_profile(true)
    if team_desc == nil then return "error", "no active team" end
    local code = F.code_of(team_desc)
    local ok, err = result(net("friend_push", f.id, KIND_CODE, code))
    pcall(VRFW.net.clipboard, code)
    return ok and "ok" or "error", ok and code or tostring(err)
  elseif action == "profile" then
    local ok, err = result(net("friend_profile", f.id))
    return ok and "ok" or "error", ok and "" or tostring(err)
  end
  return "error", "unknown action " .. tostring(action)
end

function Utilities.Friends.Poll(i, _action)
  local f = friend(i)
  if f == nil then return "error", "no such row" end
  local a = net("friend_answer", f.id, KIND_MODS)
  if type(a) ~= "table" then return "error", "no answer" end
  if a.state == "waiting" then return "wait", "" end
  if a.state ~= "ok" then return "error", tostring(a.state) end
  return "ok", tostring(a.data)
end

-- ---------------------------------------------------------------------------------------- details

function Utilities.Friends.Details(i)
  local f = friend(i)
  if f == nil or (f.vrfw or "") == "" then return false end
  load_names(view.lang)
  return (result(net("friend_ask", f.id, KIND_PROFILE)))
end

-- a profile (share_profile's text) -> team name, formation name, faces, stats lines
local function parse_profile(d)
  local tname, form, faces, stats = "", "", {}, {}
  for line in tostring(d):gmatch("[^\n]+") do
    local p = {}
    for x in (line .. "|"):gmatch("([^|]*)|") do p[#p + 1] = x end
    if p[1] == "team" then
      tname, form = p[2] or "", formation_of(tonumber(p[3]) or 0)
    elseif p[1] == "m" then
      for prm, lv in tostring(p[2] or ""):gmatch("(%d+):(%d+):%d+") do
        local param = tonumber(prm)
        local base = base_of(param) or 0
        faces[#faces + 1] = F.int(base) .. ":" .. lv .. ":" .. (name_of(param):gsub("[|:]", " "))
      end
    elseif p[1] == "matches" or p[1] == "goals" or p[1] == "mvp" then
      stats[#stats + 1] = p[1] .. "\t" .. name_of(tonumber(p[2]) or 0) .. "\t" .. tostring(p[3] or "")
    elseif p[1] == "x" then
      stats[#stats + 1] = "x\t" .. tostring(p[2] or "") .. "\t" .. tostring(p[3] or "")
    end
  end
  return tname, form, table.concat(faces, "|"), table.concat(stats, "\n")
end

function Utilities.Friends.DetailsPoll(i)
  local f = friend(i)
  if f == nil then return "error", "", "", "", "" end
  local a = net("friend_answer", f.id, KIND_PROFILE)
  if type(a) ~= "table" then return "error", "", "", "", "" end
  if a.state == "waiting" then return "wait", "", "", "", "" end
  if a.state ~= "ok" then return "error", "", "", "", "" end
  load_names(view.lang)
  return "ok", parse_profile(a.data)
end

-- ---------------------------------------------------------------------------------------- received items

local inbox = {}

function Utilities.Friends.Inbox()
  if #inbox == 0 then
    local r = net("friend_inbox")
    if type(r) == "table" then
      for _, it in ipairs(r) do inbox[#inbox + 1] = it end
    end
  end
  while #inbox > 0 do
    local it = table.remove(inbox, 1)
    if it.kind == KIND_INVITE then
      return "invite", tostring(it.name), "", tostring(it.data)
    end
    local d = it.kind == KIND_CODE and F.desc_of_code(it.data) or nil
    if d ~= nil then
      load_names(view.lang)
      pcall(VRFW.net.clipboard, it.data)
      return "code", tostring(it.name), team_lines(d), tostring(it.data)
    end
    warn("received " .. tostring(it.kind) .. " from " .. tostring(it.from) .. " ignored")
  end
  return ""
end

-- ---------------------------------------------------------------------------------------- status

local last_status = nil
-- menu stem -> its group (false = none): config.toml [friends.status_menus] does not change while the game runs
local status_of = {}

-- Called by every menu VM when it opens (utilities_friends.lua Init), so it stays O(1): a cached group lookup and the
-- presence only when the group changed. The profile is no longer refreshed here (its active team / career.json read
-- and JSON decode cost up to ~95 ms on the game thread): it is shared again when the panel opens (Open) and when a
-- save is loaded (below, off the menu-open path).
function Utilities.Friends.Status(stem)
  local st = status_of[stem]
  if st == nil then
    st = (type(stem) == "string" and F.status_of_menu(cfg.status_menus, stem)) or false
    if type(stem) == "string" then status_of[stem] = st end
  end
  st = st or nil
  if not cfg.enabled then return "" end
  if st ~= nil and st ~= last_status then
    local ok, err = result(net("presence_set", "vrfw_status", st))
    if ok then
      last_status = st
    else
      warn("presence: " .. tostring(err))
    end
  end
  return st or ""
end

-- the profile friends get, refreshed where nobody waits on a menu: a save loaded (the slot service's thread; at the
-- boot too). Not at match_end: the career decode would be a hitch on the game thread there; the panel's Open shares
-- the new numbers.
local function refresh_profile(why)
  if not cfg.enabled then return nil end
  local ok, err = pcall(share_profile, true)
  if not ok then warn("profile (" .. why .. "): " .. tostring(err)) end
  return nil
end
VRFW.on("slot_load", function() return refresh_profile("slot_load") end)

-- ---------------------------------------------------------------------------------------- guard

-- every command answers, whatever happens: an error inside one is logged and answered with its «failed» values instead of
-- reaching the framework (an uncaught error switches the whole script off until a restart, and the panel then gets no
-- answer at all: no art, no list; Utilities 1.14.4)
do
  local failed = {
    Open = function(e)
      local okA, art = true, PANEL_ART
      return false, 0, 0, "script: " .. e, okA and tostring(art) or ""
    end,
    Layout = function()
      local p = cfg.panel
      return p.x, p.width, p.top, p.row_h, p.head_h, p.details_w, p.slide_frames
    end,
    Row = function() return "" end,
    Actions = function() return "" end,
    Details = function() return false end,
    Inbox = function() return "" end,
    Status = function() return "" end,
  }
  for name, fn in pairs(Utilities.Friends) do
    if type(fn) == "function" then
      Utilities.Friends[name] = function(...)
        local r = table.pack(pcall(fn, ...))
        if r[1] then return table.unpack(r, 2, r.n) end
        local e = tostring(r[2])
        warn(name .. ": " .. e)
        local f = failed[name]
        if f ~= nil then return f(e) end
        return "error", e
      end
    end
  end
end
