-- VR-Framework › flow toggles (service S8 of VRFW 2.3, docs/framework/flow.md). Declarations: every active mod's
-- content\flows\*.toml (`VRFW.flow/1`, keys: content\types\flow.toml); native side: content\game\flow.toml.
--
--   * A toggle is one of the game's fixed screen / flow decisions; a declaration chooses its value. Several mods
--     declaring the same toggle: the later mod (load order) wins. No declaration, or only the value "game": nothing
--     is installed and the game decides as it always does.
--   * prematch_editor = "skip_offline": the team editor between the VS screen and the walk-in (soccer_formation_menu,
--     opened when the match info flag 0x2000000 is set) is not opened in an offline, non-observer match: the game's
--     own «no editor» path runs (state 7 goes on to the walk-in). Anything unreadable keeps the editor.
--   * CMND_VRFW_FLOW(name) -> value in force, live.

Flow = Flow or {}

local D = require "lib/declarations"

local function info(...) VRFW.log("flow:", ...) end
local function warn(...) VRFW.warn("flow:", ...) end

-- the toggles of the mechanism: name -> { values = { value = true }, hook = the detour a non-game value needs }
local TOGGLES = {
  prematch_editor = { values = { game = true, skip_offline = true }, hook = "Flow.PrematchEditor" },
}

local VALUE = {}     -- toggle -> value in force (absent = "game")
local BY = {}        -- toggle -> the declaration that set it
local LIVE = {}      -- toggle -> its detour is installed

local EDITOR_FLAG = 0x2000000
local skips, kept = 0, 0

-- ---------------------------------------------------------------------------------------------- declarations

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

-- ---------------------------------------------------------------------------------------------- prematch_editor

-- mi = the match info (rax at the site). true = skip the editor (the game's «no editor» path)
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

-- ---------------------------------------------------------------------------------------------- command

-- CMND_VRFW_FLOW(name) -> value, live
function Flow.Cmd(name)
  name = tostring(name or "")
  if not TOGGLES[name] then return nil end
  return VALUE[name] or "game", LIVE[name] == true
end

start()

if LIVE.prematch_editor and VALUE.prematch_editor == "skip_offline" then
  VRFW.on("hook:Flow.PrematchEditor", function(ev)
    if skip_editor(ev.regs.rax) then return { skip = true } end
    return nil
  end)
end
