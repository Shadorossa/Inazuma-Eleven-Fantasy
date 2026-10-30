-- free_match_difficulty (VR-Framework base feature):
-- the rules of «Competir contra bots» the mods declare (`[VRFW.FreeMatch]` of the team type), on the list
-- soccer_vs_cpu_list_menu.
-- (handlers of the soccer_vs_cpu_list_menu host). The class menu's part is the graft vrfw_free_match.
--
-- * CMND_VRFW_FM_RULES () -> true, clear ticks, orb «best», direct, unlock «together», preview «top», preview class;
--   CMND_VRFW_FM_DIFFICULTIES (game) -> true, n, the n classes the game offers (declared classes it has a row for).
-- * OnDecideFocus of the opponent list (around): Unlock = "together": a locked opponent (its top class locked and,
--   unless the lowest class would open, the retail rule) says so (text vrfw_fm_rival_locked) instead of opening the
--   class menu; Direct = true and ONE offered class: «Play against X?» (vrfw_fm_ask_team) and the match at that class;
--   else the retail flow (the class menu with the offered classes).
-- * UpdateItem (after): Orb = "best": the row's single orb = the class orb of the highest offered class won (retail
--   clear bits; the team build put the four class orbs on the single-orb slot of vsroute01_06b).
-- * OnChangeFocus of a row (after) and OpenClassSelect (around): the preview (team, levels, class badge) at the
--   lowest offered class (retail: 6) or, Preview = "top", the highest (retail UpdateDifficult). The team is the one
--   of the game's row OF THAT CLASS (0x836C9C28(game, class)): retail asks 0x836C9C28(game) with no class,
--   which falls back to the game's FIRST row (a Chronicle row: difficulty 1), and a Chronicle level map gives that row a
--   copy team the preview cannot draw (empty line-up, no coach, «Nv.0» on the IE3 / CS / Galaxy / Orion tabs). The
--   retail chunk's team local (n2) is set to it, so every later redraw (nickname button) uses it too.
-- * UpdateFormation (after), PreviewClass = false: the preview's «Nv.» level and class badge hidden (the class menu
--   shows them).
-- Rules are read once per VM; with no answer from the DLL every handler leaves the retail code alone.
-- A mod that uses the list for something else (e.g. an office hub) switches these rules off while it does:
-- VRFW_FM.Bypass("<mod>.<name>", true / false), called from its code inside the callbacks (never at load).
-- No engine call at load time.

VRFW_FM = VRFW_FM or {}
local FM = VRFW_FM
FM.bypass = FM.bypass or {}

local K = {
  RULES = VRFW_Cmd.VRFW_FM_RULES,        -- CMND_VRFW_FM_RULES
  DIFFS = VRFW_Cmd.VRFW_FM_DIFFICULTIES,        -- CMND_VRFW_FM_DIFFICULTIES
  TXT_ASK = 4268189860,      -- crc32("vrfw_fm_ask_team"): "Play against %s?"
  TXT_LOCKED = 2350615877,   -- crc32("vrfw_fm_rival_locked")
  TEXT_GET = VRFW_Cmd.TEXT_GET,     -- CMND_TEXT_GET
  LOG = VRFW_Cmd.EVT_LOG,          -- CMND_EVT_LOG
  CLEAR = VRFW_Cmd.GET_SOCCER_GAME_CLEAR_FLAG,         -- CMND_GET_SOCCER_GAME_CLEAR_FLAG
  LIST = 1107559438,         -- team05_03_soccer_cpu_opponent_list
  ITEM = 1074924810,         -- mainmenu90_19_vs_cpu_list_item
  MENU = 1970579282,         -- soccer_vs_cpu_list_menu
  ORB_LAYER = 4088477286,    -- vsroute01_06b_town_map_piece_clear_icon
  POS = {[6] = 1611754387, [7] = 4179114537, [8] = 2384399039, [9] = 276537116},   -- _pos_clear01..04
  POS_BASE01 = 1517329426, POS_BASE02 = 3279539624, CLEAR_BASE01 = 1003654013, POS_CLEAR05 = 1736224650,
  SAVED_TAB = 3683890655,    -- the temp byte the screen keeps its tab in (retail n6)
  logs = 0,
}

local function Log(...)
  if K.logs >= 20 then
    return
  end
  K.logs = K.logs + 1
  local parts = {}
  for i = 1, select("#", ...) do
    parts[#parts + 1] = tostring((select(i, ...)))
  end
  pcall(funcLuaCommand, K.LOG, "VRFW fm_difficulty " .. table.concat(parts, " "))
end

-- the rules (nil = the DLL did not answer: retail)
function FM.Rules()
  if FM.rules == nil then
    local r = {pcall(funcLuaCommand, K.RULES)}
    if r[1] and r[2] == true then
      FM.rules = {ticks = r[3] ~= false, best = r[4] == true, direct = r[5] == true, together = r[6] == true, top = r[7] == true,
                  cls = r[8] ~= false}
    else
      FM.rules = false
    end
  end
  return FM.rules or nil
end

-- true while a mod uses the list for something else
function FM.Bypass(id, on)
  FM.bypass[id] = on and true or nil
end
function FM.Off()
  for _, v in pairs(FM.bypass) do
    if v then
      return true
    end
  end
  return false
end

-- the classes `game` offers, ascending (cached per open); nil = the DLL did not answer
function FM.Diffs(game)
  FM.cache = FM.cache or {}
  local t = FM.cache[game]
  if t == nil then
    t = {}
    local r = {pcall(funcLuaCommand, K.DIFFS, game)}
    if r[1] and r[2] == true and type(r[3]) == "number" then
      for i = 1, r[3] do
        if type(r[3 + i]) == "number" then
          t[#t + 1] = r[3 + i]
        end
      end
    end
    FM.cache[game] = t
  end
  if #t == 0 then
    return nil
  end
  return t
end

-- the preview class of `game`: its lowest offered class, or the highest with Preview = "top"
function FM.Preview(game)
  local R, t = FM.Rules(), FM.Diffs(game)
  if R == nil or t == nil then
    return nil
  end
  return R.top and t[#t] or t[1]
end

-- the row orb: the highest offered class won on this save (retail clear bits, set by every won match and never
-- cleared: a lower win never lowers it, old saves show their best at once); 0 = none won
function FM.Best(game)
  local best = 0
  for _, d in ipairs(FM.Diffs(game) or {}) do
    if d > best and funcLuaCommand(K.CLEAR, game, d) == true then
      best = d
    end
  end
  return best
end

function FM.Text(id)
  local ok, s = pcall(funcLuaCommand, K.TEXT_GET, id)
  if ok and type(s) == "string" and s ~= "" then
    return s
  end
  return nil
end

-- retail VS-CPU lock rule of class c (0..3 = row 6 + c) (class menu OnSetupLayer); story = the class menu's byte
-- 150829411 (0 on the Story tab for category-0 entries, else 1). true = locked
function FM.RetailLocked(game, story, c)
  local flag = true
  local ret, ret2 = funcLuaMenuCommand(1984141647, game, c + 6)
  if not ret then
    ret2 = -1
  end
  if ret2 == -1 then
    if story == 1 then
      if game == 281360633 --[[fbtl_free_001]] then
        flag = false
      else
        local ok, sfi = funcLuaCommand(2610596259, game)
        if ok then
          flag = not funcLuaCommand(VRFW_Cmd.GET_CHRONICLE_CLEAR_STATUS, sfi, c + 1)
        end
        local ok2, ev = funcLuaCommand(2610596259, game, 1)
        if ok2 and ev > 0 then
          flag = false
        end
      end
    else
      flag = false
    end
  elseif ret2 == 0 then
    flag = false
  end
  return flag
end

-- Unlock = "together": the opponent is open when its top class or its lowest class would be (every offered class
-- opens with it: no per-class chain)
function FM.Locked(game, story)
  local t = FM.Diffs(game) or {9}
  return FM.RetailLocked(game, story, t[#t] - 6) and FM.RetailLocked(game, story, t[1] - 6)
end

function FM.Ask(text)
  local n7 = 0
  funcLuaCommand(2289627655, text, n7, 0, 0, 0, 0, false)   -- message window (the class menu's call)
  funcLuaCommand(2351835063, 2, 0, n7)                       -- yes / no
  funcLuaCommand(2529383714, 0, 1, n7)
  waitFalse(function()
    return funcLuaCommand(898725220, n7)
  end)
  local r = -1
  while r < 0 do
    r = funcLuaCommand(1523741473, n7)
    coroutine.yield()
  end
  waitTrue(function()
    return funcLuaCommand(682363669, n7)
  end)
  return r == 0
end

-- the opponent `game` decided on the list; true = handled here (locked, or the one-class match)
function FM.Decide(game, story)
  local R = FM.Rules()
  if R.together and FM.Locked(game, story) then
    local locked = FM.Text(K.TXT_LOCKED)
    if locked ~= nil then
      funcLuaMenuCommand(1558704558, K.MENU, false)
      funcLuaCommand(2289627655, locked, 0)
      funcLuaCommand(2599933690, 0, 2086672038 --[[sy0003]])
      waitTrue(function()
        return funcLuaCommand(682363669)
      end)
      funcLuaMenuCommand(1558704558, K.MENU, true)
    else
      funcLuaCommand(VRFW_Cmd.SND_PLAY_SE, 2086672038 --[[sy0003]])
    end
    return true
  end
  local diffs = FM.Diffs(game)
  if not R.direct or diffs == nil or #diffs ~= 1 then
    return false
  end
  local text = 2509321689 --[[¿Empezar partido?]]
  local ok, team = funcLuaCommand(2204933160, game)
  if ok then
    local ok2, name = funcLuaCommand(2151743654, team, 2)
    local ask = FM.Text(K.TXT_ASK)
    if ok2 and name ~= nil and name ~= "" and ask ~= nil and string.find(ask, "%s", 1, true) then
      text = string.gsub(ask, "%%s", function() return name end, 1)
    end
  end
  funcLuaMenuCommand(1558704558, K.MENU, false)
  if not FM.Ask(text) then
    funcLuaMenuCommand(1558704558, K.MENU, true)
    return true
  end
  -- the steps of soccer_vs_cpu_class_select_menu OnDecideFocus, at the opponent's only class
  local diff = diffs[1]
  if funcLuaMenuCommand(VRFW_Cmd.IS_EXIST_MENU_OBJECT, 811496143 --[[soccer_top_menu]]) then
    if VRFW_Param.Has(570346750) then
      VRFW_Param.Clear(570346750)
    end
    VRFW_Param.Set(570346750, 1)          -- tells soccer_top_menu.OpenList a match starts
  end
  BrightFadeAllMenu(2721617045 --[[fade_menu_encount]], true)
  local ret, ret2 = funcLuaCommand(634509816, game, 4)
  if not ret then
    ret2 = 3468355528 --[[s90g001]]
  end
  funcLuaCommand(VRFW_Cmd.SET_PRE_MATCH_SOCCER_GAME_ID, game)
  funcLuaCommand(1104380539, diff)
  local okr = funcLuaCommand(VRFW_Cmd.RESERVE_SOCCER, game, ret2, diff)
  Log("reserve", game, ret2, diff, okr)
  funcLuaCommand(VRFW_Cmd.CLOSE_MENU_OBJECT, K.MENU)
  return true
end

-- the focused opponent's game (0 = none)
local function Focused()
  local ok, g = funcLuaMenuCommand(1666448199, 0)
  if ok and type(g) == "number" then
    return g
  end
  return 0
end

-- the team of `game`'s row of class `d` (nil = no answer)
function FM.Team(game, d)
  local ok, has, team = pcall(funcLuaCommand, 2204933160, game, d)
  if ok and has and type(team) == "number" and team ~= 0 then
    return team
  end
  return nil
end

-- the retail chunk's locals (the host's map; nil without EVT_DEBUG)
local function HostL()
  local h = VRFW_Host ~= nil and VRFW_Host.hosts ~= nil and VRFW_Host.hosts.soccer_vs_cpu_list_menu or nil
  return h ~= nil and h.L or nil
end

-- the preview's team name and emblem for `team` (the retail OnChangeFocus steps)
local function TeamHeader(team)
  local ok, has, name = pcall(funcLuaCommand, 2151743654, team, 2)
  if ok and has then
    funcLuaMenuCommand(VRFW_Cmd.SET_MENU_TEXT_STRING, 1835074715 --[[mainmenu90_34_cpu_team_formation]], 3778687894 --[[_text_team_name01]], name or "", 0)
  end
  local ok2, has2, emblem = pcall(funcLuaCommand, 2151743654, team, 6, 0)
  if ok2 and has2 then
    funcLuaMenuCommand(3190452549, 1835074715 --[[mainmenu90_34_cpu_team_formation]], 0, 574244154 --[[_cpu_icon_emblem_dmy01]], 1949581463 --[[cpu_icon_emblem_dmy01]], emblem)
    local L = HostL()
    if L ~= nil then
      pcall(function() L.n10 = emblem end)
    end
  end
end

local function RePreview()
  local g = Focused()
  local d = g ~= 0 and FM.Preview(g) or nil
  if d == nil or UpdateDifficult == nil then
    return
  end
  local team = FM.Team(g, d)
  local L = HostL()
  local set = false
  if team ~= nil and L ~= nil then
    local ok, cur = pcall(function() return L.n2 end)
    if ok and cur ~= team then
      set = pcall(function() L.n2 = team end)
      if set then
        TeamHeader(team)
      end
    elseif ok then
      set = true
    end
  end
  UpdateDifficult(d)
  if team ~= nil and not set and UpdateFormation ~= nil then
    TeamHeader(team)
    UpdateFormation(team, g)             -- no access to the chunk's locals: draw the class's team once
  end
end

-- «Shown team changed»: the list shows the team of its game's row of the shown class (the focused opponent, then the
-- class the class window focuses: retail UpdateDifficult). A game whose classes have different rivals (a mod's
-- per-class rival) changes team with the class. Listeners: VRFW_FM.shown_team_listeners[id] = function(game, class,
-- team), called once per change of (game, class, team), after the list redrew its formation for it.
FM.shown_team_listeners = FM.shown_team_listeners or {}
FM.shown = nil
function FM.ShownTeamChanged(game, d, team)
  local key = tostring(game) .. ":" .. tostring(d) .. ":" .. tostring(team)
  if FM.shown == key then
    return
  end
  FM.shown = key
  for id, fn in pairs(FM.shown_team_listeners) do
    local ok, why = pcall(fn, game, d, team)
    if not ok then
      Log("shown team listener", id, tostring(why))
    end
  end
end

-- PreviewClass = false: the preview's «Nv.» label, level number and class badge hidden
local function HideClass()
  local R = FM.Rules()
  if R == nil or R.cls or FM.Off() then
    return
  end
  funcLuaMenuCommand(VRFW_Cmd.SET_MESH_VISIBLE, 1835074715 --[[mainmenu90_34_cpu_team_formation]], 2841109264 --[[_chronicle_gtxt_lv01]], false, 0)
  funcLuaMenuCommand(VRFW_Cmd.SET_MESH_VISIBLE, 1835074715 --[[mainmenu90_34_cpu_team_formation]], 2839039721 --[[_chronicle_lv_num_dmy01]], false, 0)
  funcLuaMenuCommand(VRFW_Cmd.SET_MESH_VISIBLE, 1835074715 --[[mainmenu90_34_cpu_team_formation]], 126765991 --[[_cpu_icon_class_dmy01]], false, 0)
  funcLuaMenuCommand(1233047821, 1835074715 --[[mainmenu90_34_cpu_team_formation]], 0, 51927332 --[[the «Nv.» number]], false)
end

if VRFW_Host ~= nil then
  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnInit", {
    id = "menu_engine.free_match_difficulty", phase = "before",
    fn = function()
      FM.cache = nil                 -- the table may change between opens (a reload)
      FM.shown = nil
    end,
  })

  -- the shown class changes (the class window's focus, the preview): the list's team becomes that class's row's
  -- team before the retail redraw (its UpdateFormation draws the local team n2), then the listeners hear it. The game
  -- is the chunk's local n5 (no menu-object command: this may run while the list sets up).
  VRFW_Host.on("soccer_vs_cpu_list_menu", "UpdateDifficult", {
    id = "menu_engine.free_match_difficulty.shown_team", phase = "around",
    fn = function(nxt, d, ...)
      local L = HostL()
      local game, team = nil, nil
      if L ~= nil and type(d) == "number" and not FM.Off() then
        local ok, g = pcall(function() return L.n5 end)
        if ok and type(g) == "number" and g ~= 0 then
          game = g
          team = FM.Team(g, d)
        end
      end
      if team ~= nil then
        local ok, cur = pcall(function() return L.n2 end)
        if ok and cur ~= team and pcall(function() L.n2 = team end) then
          local okn, n = pcall(funcLuaMenuCommand, VRFW_Cmd.GET_CREATE_LAYER_NUM --[[created instances]], 1835074715 --[[mainmenu90_34_cpu_team_formation]])
          if okn and type(n) == "number" and n >= 1 then
            TeamHeader(team)
          end
        end
      end
      local r = table.pack(nxt(d, ...))
      if team ~= nil then
        FM.ShownTeamChanged(game, d, team)
      end
      return table.unpack(r, 1, r.n)
    end,
  })

  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnDecideFocus", {
    id = "menu_engine.free_match_difficulty", phase = "around",
    fn = function(nxt, a1, a2, ...)
      local R = FM.Rules()
      if a1 ~= K.LIST or R == nil or not (R.together or R.direct) or FM.Off() then
        return nxt(a1, a2, ...)
      end
      local game = Focused()
      if game == 0 then
        return nxt(a1, a2, ...)
      end
      local ok, ret5 = funcLuaMenuCommand(1666448199, 3)
      if not ok then
        ret5 = 0
      end
      local tab = funcLuaCommand(VRFW_Cmd.GET_TEMP_BYTE_FLAG, K.SAVED_TAB)
      local story = 1
      if IsStory ~= nil and IsStory(tab) and ret5 == 0 then
        story = 0
      end
      if FM.Decide(game, story) then
        return
      end
      return nxt(a1, a2, ...)
    end,
  })

  VRFW_Host.on("soccer_vs_cpu_list_menu", "UpdateItem", {
    id = "menu_engine.free_match_difficulty", phase = "after",
    fn = function(r, a1, a2, a3)
      local R = FM.Rules()
      if R == nil or not R.best or a3 == nil or a3 == 0 or FM.Off() then
        return
      end
      -- the single-orb pill (_pos_base02, on the capsule's top slot) + the class orb of the highest class won
      -- (_pos_clear01..04 = rows 6..9, all on that slot); the capsule's own pill and the red orb 05 hidden;
      -- nothing won = the empty pill
      funcLuaMenuCommand(VRFW_Cmd.SET_LAYER_VISIBLE, K.ORB_LAYER, a2, true)
      funcLuaMenuCommand(2158717427, K.ORB_LAYER, K.POS_BASE01, true, a2)
      funcLuaMenuCommand(2158717427, K.ORB_LAYER, K.POS_BASE02, true, a2)
      funcLuaMenuCommand(VRFW_Cmd.SET_MESH_VISIBLE, K.ORB_LAYER, K.CLEAR_BASE01, false, a2)
      funcLuaMenuCommand(2158717427, K.ORB_LAYER, K.POS_CLEAR05, false, a2)
      local best = FM.Best(a3)
      for d = 6, 9 do
        funcLuaMenuCommand(2158717427, K.ORB_LAYER, K.POS[d], d == best, a2)
      end
    end,
  })

  -- the retail focus change draws the formation of the game's FIRST row's team (0x836C9C28(game), no class: a
  -- Chronicle row) before the preview class's team is set: two draws per move, and a coach that differs between the
  -- two teams (a mod's staff on the free-match team) blinks while its portrait loads. Around the retail handler, that
  -- one-argument team query answers the previewed class's team and the preview class is the chunk's class (n8), so
  -- the retail draw itself is the final one.
  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnChangeFocus", {
    id = "menu_engine.free_match_difficulty.first_draw", phase = "around",
    fn = function(nxt, a1, ...)
      if a1 ~= K.ITEM or FM.Rules() == nil or FM.Off() then
        return nxt(a1, ...)
      end
      local raw = funcLuaCommand
      funcLuaCommand = function(id, ...)
        if id == 2204933160 and select("#", ...) == 1 then
          local game = ...
          local d = type(game) == "number" and game ~= 0 and FM.Preview(game) or nil
          local team = d ~= nil and FM.Team(game, d) or nil
          if team ~= nil then
            local L = HostL()
            if L ~= nil then
              pcall(function() L.n8 = d end)
            end
            return true, team
          end
        end
        return raw(id, ...)
      end
      local r = table.pack(pcall(nxt, a1, ...))
      funcLuaCommand = raw
      if not r[1] then
        error(r[2], 0)
      end
      return table.unpack(r, 2, r.n)
    end,
  })

  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnChangeFocus", {
    id = "menu_engine.free_match_difficulty", phase = "after",
    fn = function(r, a1)
      if a1 == K.ITEM and FM.Rules() ~= nil and not FM.Off() then
        RePreview()
      end
    end,
  })

  VRFW_Host.on("soccer_vs_cpu_list_menu", "UpdateFormation", {
    id = "menu_engine.free_match_difficulty", phase = "after",
    fn = function(r, a1)
      if a1 ~= nil and a1 ~= 0 then
        HideClass()
      end
    end,
  })

  VRFW_Host.on("soccer_vs_cpu_list_menu", "OpenClassSelect", {
    id = "menu_engine.free_match_difficulty", phase = "around",
    fn = function(nxt, ...)
      local r = table.pack(nxt(...))
      if FM.Rules() ~= nil and not FM.Off() then
        RePreview()                  -- the retail code put the preview back on class 6
      end
      return table.unpack(r, 1, r.n)
    end,
  })
end
