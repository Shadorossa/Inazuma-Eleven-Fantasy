-- VRFW free-match classes -----------------
-- The class menu lists the classes the opponent offers (CMND_VRFW_FM_DIFFICULTIES: the mods' [VRFW.FreeMatch]
-- Difficulties that the game has a SOCCER_GAME_DIFFICULTY row for, ascending; LEGENDARY HERO, row 9, last). Row k
-- shows the retail class of its difficulty (ball: the class's declared Ball, else lv_base00..03; title: the class's
-- declared Banner, CMND_VRFW_FM_CLASS, else gtxt_class01..04; "Lv." average of the team of the game's row of that class,
-- VRFW_FMC.Team: the real level, 3 digits with number settings); the clear /
-- advantage-win marks and their box only with ClearTicks (default: retail); locks: the retail rule per class, or none with
-- Unlock = "together" (the list already checked the opponent). Without an answer from the DLL: the 4 retail rows.
-- No engine call at load time; the functions take the game / story bytes from the callbacks (no chunk local here).
VRFW_FMC = VRFW_FMC or {}
VRFW_FMC.RULES = 2045239528   -- CMND_VRFW_FM_RULES
VRFW_FMC.DIFFS = 1129484790   -- CMND_VRFW_FM_DIFFICULTIES
VRFW_FMC.CLASS = 490102859    -- CMND_VRFW_FM_CLASS
VRFW_FMC.ATLAS = 1103995203   -- #/menu/200_icon/06_icon_class/<LG>/icon_class.g4tx (the retail class titles)
VRFW_FMC.BALLS = 3795985350   -- #/menu/30_vsroute/vsroute01/vsroute01_21/vsroute01_21.g4tx (the level balls lv_base00..03)
VRFW_FMC.cache = nil
VRFW_FMC.banners = VRFW_FMC.banners or {}

-- {ticks, together} (retail when the DLL does not answer)
function VRFW_FMC.Rules()
  if VRFW_FMC.rules == nil then
    local r = {pcall(funcLuaCommand, VRFW_FMC.RULES)}
    if r[1] and r[2] == true then
      VRFW_FMC.rules = {ticks = r[3] ~= false, together = r[6] == true}
    else
      VRFW_FMC.rules = {ticks = true, together = false}
    end
  end
  return VRFW_FMC.rules
end
-- the classes `game` offers (read once per open: OnInit clears the cache)
function VRFW_FMC.List(game)
  if VRFW_FMC.cache == nil then
    local t = {}
    local r = {pcall(funcLuaCommand, VRFW_FMC.DIFFS, game)}
    if r[1] and r[2] == true and type(r[3]) == "number" then
      for i = 1, r[3] do
        if type(r[3 + i]) == "number" then
          t[#t + 1] = r[3 + i]
        end
      end
    end
    if #t == 0 then
      t = {6, 7, 8, 9}
    end
    VRFW_FMC.cache = t
  end
  return VRFW_FMC.cache
end
-- class index 0..3 (row 6 + c) shown on menu row a2
function VRFW_FMC.Cls(game, a2)
  local l = VRFW_FMC.List(game)
  local d = l[a2 + 1] or l[#l]
  return d - 6
end
-- menu row a2 beyond the offered list: hidden, not focusable
function VRFW_FMC.Hidden(game, a2)
  return a2 >= #VRFW_FMC.List(game)
end
-- retail lock rule of class c (OnSetupLayer, moved into a function); story = byte 150829411 (1 = not the Story tab)
function VRFW_FMC.RetailLocked(game, story, c)
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
          flag = not funcLuaCommand(4034518619 --[[CMND_GET_CHRONICLE_CLEAR_STATUS]], sfi, c + 1)
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
function VRFW_FMC.Locked(game, story, c)
  if VRFW_FMC.Rules().together then
    return false
  end
  return VRFW_FMC.RetailLocked(game, story, c)
end
-- the art of class index c (0..3), read once: {banner = {atlas, sprite} or false, ball = {atlas, sprite} or false}
function VRFW_FMC.Art(c)
  local b = VRFW_FMC.banners[c]
  if type(b) ~= "table" or b.ball == nil then
    b = {banner = false, ball = false}
    local r = {pcall(funcLuaCommand, VRFW_FMC.CLASS, c + 6)}
    if r[1] and r[2] == true then
      if type(r[4]) == "number" and r[4] ~= 0 and type(r[5]) == "number" and r[5] ~= 0 then
        b.banner = {r[4], r[5]}
      end
      if type(r[6]) == "number" and r[6] ~= 0 and type(r[7]) == "number" and r[7] ~= 0 then
        b.ball = {r[6], r[7]}
      end
    end
    VRFW_FMC.banners[c] = b
  end
  return b
end
-- the title of class index c (0..3): (atlas, sprite) declared for the class, else the retail one (`retail` sprite)
function VRFW_FMC.Banner(c, retail)
  local b = VRFW_FMC.Art(c).banner
  if b then
    return b[1], b[2]
  end
  return VRFW_FMC.ATLAS, retail
end
-- the level ball of class index c: the class's (MatchDifficulty Ball, or the ball of the retail class whose title it
-- shows), else the retail one (`retail` sprite, lv_base00..03)
function VRFW_FMC.Ball(c, retail)
  local b = VRFW_FMC.Art(c).ball
  if b then
    return b[1], b[2]
  end
  return VRFW_FMC.BALLS, retail
end
-- the row's mark box (_list_state_base01) hidden without ClearTicks (the marks are never shown there)
function VRFW_FMC.Box(layer, a2)
  if not VRFW_FMC.Rules().ticks then
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, 1445391659 --[[_list_state_base01]], false, a2)
  end
end
-- the team of `game`'s row of difficulty d (0x836C9C28(game, d)); `fallback` (the first row's, retail) without one
function VRFW_FMC.Team(game, d, fallback)
  local ok, has, team = pcall(funcLuaCommand, 2204933160, game, d)
  if ok and has and type(team) == "number" and team ~= 0 then
    return team
  end
  return fallback
end
-- the clear mark and the advantage-win mark of class c (none without ClearTicks)
function VRFW_FMC.Marks(game, c)
  if not VRFW_FMC.Rules().ticks then
    return false, false
  end
  return funcLuaCommand(989257499 --[[CMND_GET_SOCCER_GAME_CLEAR_FLAG]], game, 6 + c), funcLuaCommand(479325357, game, 6 + c)
end
-- VRFW free-match classes end ------------------------------------------------------------------
