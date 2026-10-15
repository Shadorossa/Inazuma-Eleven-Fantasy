-- Flow toggles (content/flows/*.toml, schema VRFW.flow/1): a declaration picks the value of one fixed game decision; the later mod wins, "game" keeps retail.
--   * prematch_editor = "skip_offline": skips the pre-match team editor in offline, non-observer matches.
--   * match_exit = "black_to_menu" (+ play_modes): leaving an offline match of those play modes with the game's hold
--     prompts fades to black and stays black until the menu the game returns to has opened (bright-fade layer 1 held
--     by the detour Flow.ExitCover; the menu side is lua/menu/_all/14_match_exit.lua).
--   * CMND_VRFW_FLOW(name) -> value in force, live
--   * CMND_VRFW_MATCH_EXIT_COVER(op, arg): 2 applies?(play mode), 1 hold(play mode), 0 release(menu stem), -1 query(menu stem)

Flow = Flow or {}

local D = require "lib/declarations"

local function info(...) VRFW.log("flow:", ...) end
local function warn(...) VRFW.warn("flow:", ...) end

-- toggles: name -> { values = { value = true }, hook = detour a non-game value needs }
local TOGGLES = {
  prematch_editor = { values = { game = true, skip_offline = true }, hook = "Flow.PrematchEditor" },
  match_exit = { values = { game = true, black_to_menu = true }, hook = "Flow.ExitCover" },
}

local VALUE = {}     -- toggle -> value in force (absent = "game")
local BY = {}        -- toggle -> the declaration that set it
local LIVE = {}      -- toggle -> its detour is installed

local EDITOR_FLAG = 0x2000000
local EXIT_MODES = {}  -- match_exit: play mode -> true (the declaration's play_modes)
local skips, kept = 0, 0

-- ---- declarations

local function start()
  local schema, why = D.schema("flow")
  if not schema then
    warn(why .. ": the flow toggles stay the game's")
    return
  end
  local decls, skipped = D.load(schema, warn)
  for _, d in ipairs(decls) do
    local t = TOGGLES[d.v.name]
    if not t then
      local names = {}
      for k in pairs(TOGGLES) do names[#names + 1] = k end
      table.sort(names)
      warn(string.format("%s: unknown toggle `%s` (%s): left out", d.where, d.v.name, table.concat(names, ", ")))
    elseif d.v.name == "match_exit" and d.v.value ~= "game" and (type(d.v.play_modes) ~= "table" or #d.v.play_modes == 0) then
      warn(string.format("%s: match_exit = %q needs play_modes (the play modes whose matches it covers): left out", d.where, d.v.value))
    elseif not t.values[d.v.value] then
      local vals = {}
      for k in pairs(t.values) do vals[#vals + 1] = k end
      table.sort(vals)
      warn(string.format("%s: %s = %q: one of %s: left out", d.where, d.v.name, d.v.value, table.concat(vals, ", ")))
    else
      if BY[d.v.name] and VALUE[d.v.name] ~= d.v.value then
        info(string.format("%s = %q of %s replaces %q of %s (later mod wins)", d.v.name, d.v.value, d.mod, VALUE[d.v.name], BY[d.v.name].mod))
      end
      VALUE[d.v.name], BY[d.v.name] = d.v.value, d
    end
  end
  if BY.match_exit and type(BY.match_exit.v.play_modes) == "table" then
    for _, m in ipairs(BY.match_exit.v.play_modes) do EXIT_MODES[m] = true end
  end
  local parts, any = {}, false
  local names = {}
  for k in pairs(TOGGLES) do names[#names + 1] = k end
  table.sort(names)
  for _, name in ipairs(names) do
    local v = VALUE[name] or "game"
    if v ~= "game" then
      any = true
      local ok, done, e = pcall(VRFW.hook.apply, TOGGLES[name].hook)
      LIVE[name] = ok and done == true
      if not LIVE[name] then
        warn(string.format("%s = %q (%s): detour %s not installed (%s): the game's rule stays", name, v, BY[name].mod,
          TOGGLES[name].hook, tostring(ok and e or done)))
      end
    end
    parts[#parts + 1] = string.format("%s = %s%s", name, v, BY[name] and (" (" .. BY[name].mod .. ")") or "")
  end
  if any then
    info(string.format("on: %d declaration(s) (%d left out by `when`): %s", #decls, skipped or 0, table.concat(parts, ", ")))
  elseif #decls > 0 or (skipped or 0) > 0 then
    info(string.format("off: %d declaration(s) (%d left out by `when`), every toggle the game's: %s", #decls, skipped or 0, table.concat(parts, ", ")))
  else
    info("off: no mod declares a flow toggle: the game's flow")
  end
end

-- ---- prematch_editor

-- mi = match info; true = skip the editor
local function skip_editor(mi)
  local ok, s = pcall(VRFW.mem.struct, "Flow.MatchInfo", mi)
  if not ok or not s then return false end
  local okf, flags = pcall(function() return s.Flags end)
  if not okf or type(flags) ~= "number" or bit32.band(flags, EDITOR_FLAG) == 0 then return false end
  local oko, observer = pcall(function() return s.Observer end)
  local okt, ty = pcall(function() return s.MatchType end)
  ty = okt and ty or 255
  local okn, net = pcall(VRFW.call, "Flow.IsNetworkSession")
  if oko and observer == 0 and okn and net == false then
    skips = skips + 1
    VRFW.log(string.format("flow: prematch_editor: team editor skipped (offline, match type %d) -> walk-in [%d]", ty, skips))
    return true
  end
  kept = kept + 1
  VRFW.log(string.format("flow: prematch_editor: team editor kept (network %s, observer %s, match type %d) [%d]",
    okn and tostring(net) or "?", oko and tostring(observer) or "?", ty, kept))
  return false
end

-- ---- match_exit

-- While held, the detour Flow.ExitCover keeps layer 1 of the bright-fade object opaque black whatever the game asks
-- (its fade-ins at scene / menu changes included). The hold ends when a menu VM reports its landing, at a title return,
-- or when a query finds it older than COVER_MAX_MS (the asking VM then fades it in).
local COVER_TABLE = "VRFW.Flow.ExitCover"
local COVER_MAX_MS = 8000
local cover = { held = false, since = 0, holds = 0, mode = nil }

local function in_match()
  local ok, v = pcall(function() return VRFW.in_match ~= nil and VRFW.in_match() end)
  return ok and v == true
end

-- true, or false + why
local function exit_applies(mode)
  if VALUE.match_exit ~= "black_to_menu" then return false, "match_exit is the game's" end
  if not LIVE.match_exit then return false, "detour Flow.ExitCover not installed" end
  if type(mode) ~= "number" or not EXIT_MODES[mode] then return false, "play mode " .. tostring(mode) .. " not covered" end
  local ok, net = pcall(VRFW.call, "Flow.IsNetworkSession")
  if not ok or net ~= false then return false, "network session (or unreadable)" end
  return true
end

local function cover_release(why)
  pcall(VRFW.native.table_clear, COVER_TABLE)
  if not cover.held then return false end
  cover.held = false
  info(string.format("match_exit: black cover released (%s) after %d ms [%d]", why, math.floor(VRFW.now() - cover.since), cover.holds))
  return true
end

-- CMND_VRFW_MATCH_EXIT_COVER(op, arg)
--   2, play mode -> 1 | 0, why: the cover applies to leaving this match
--   1, play mode -> 1 | 0, why: hold it (the asking VM faded layer 1 to black first)
--   0, menu stem -> 1 | 0, why: release it (1 = released: the asking VM fades layer 1 in); refused in a match
--  -1, menu stem -> 0 not held | 1 held | 2 held too long, released now (the asking VM fades in); in a match; age ms
function Flow.ExitCover(op, arg)
  op = tonumber(op) or -1
  if op == 2 or op == 1 then
    local ok, why = exit_applies(tonumber(arg))
    if not ok then return 0, why end
    if op == 2 then return 1 end
    local okg, obj = pcall(VRFW.game.flow_bright_fade)
    if not okg or type(obj) ~= "number" or obj == 0 then
      warn("match_exit: no bright-fade object: no cover (" .. tostring(obj) .. ")")
      return 0, "no bright-fade object"
    end
    pcall(VRFW.native.table_clear, COVER_TABLE)
    VRFW.native.table_set(COVER_TABLE, obj, 1)
    cover.held, cover.since, cover.holds, cover.mode = true, VRFW.now(), cover.holds + 1, tonumber(arg)
    info(string.format("match_exit: match left (play mode %s): black cover held [%d]", tostring(arg), cover.holds))
    return 1
  elseif op == 0 then
    if not cover.held then return 0, "not held" end
    if in_match() then return 0, "in a match" end
    cover_release("landed in " .. tostring(arg))
    return 1
  end
  if not cover.held then return 0, in_match(), 0 end
  local age = VRFW.now() - cover.since
  if age > COVER_MAX_MS then
    cover_release(string.format("no landing menu within %d ms, asked by %s", COVER_MAX_MS, tostring(arg)))
    return 2, in_match(), math.floor(age)
  end
  return 1, in_match(), math.floor(age)
end

-- ---- command

-- CMND_VRFW_FLOW(name) -> value, live
function Flow.Cmd(name)
  name = tostring(name or "")
  if not TOGGLES[name] then return nil end
  return VALUE[name] or "game", LIVE[name] == true
end

start()

-- a title return ends any hold (the title's own fade-in then shows it)
VRFW.on("game_reset", function(ev)
  cover_release("game reset")
end)

if LIVE.prematch_editor and VALUE.prematch_editor == "skip_offline" then
  VRFW.on("hook:Flow.PrematchEditor", function(ev)
    if skip_editor(ev.regs.rax) then return { skip = true } end
    return nil
  end)
end
