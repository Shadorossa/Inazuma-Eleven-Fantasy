-- InaRogue welcome gacha, the scene overlay (graft inarogue_welcome, docs/game/modes/inarogue-welcome-gacha.md): the
-- orbs of InaRogue's scene ev74_10091 are the pooled effects inarogue.welcome_ball<RARITY>; the engine asks this menu's
-- GetBustupIconRarityType(i) for <RARITY>. While InaRogue's scene plays (CMND_INAROGUE_WELCOME_STATE = the NUMBER 1)
-- orb i is drawn player i's (the digit of his stars, 0 = no player) and the bust-ups are the best players of the draw.
-- Otherwise (the retail Players Universe scene) the retail answers. Read once at OnInit, never at chunk load.
EVT_IRW_SCENE = EVT_IRW_SCENE or {}
do
  local S = EVT_IRW_SCENE
  S.STATE = @crc:CMND_INAROGUE_WELCOME_STATE@
  S.BALLS = @crc:CMND_INAROGUE_WELCOME_BALLS@
  S.balls = nil                           -- nil = not read yet, false = not InaRogue's scene, else { orbs, digits…, bust-ups… }

  -- a command whose script is off answers a plain `true`: only the NUMBER 1 means «InaRogue's scene»
  function S.Load()
    if S.balls ~= nil then
      return S.balls
    end
    S.balls = false
    local ok, st = pcall(funcLuaCommand, S.STATE)
    if not (ok and type(st) == "number" and st == 1) then
      return S.balls
    end
    local okb, t = pcall(funcLuaCommand, S.BALLS)
    if okb and type(t) == "table" and type(t[1]) == "number" then
      S.balls = t
    end
    return S.balls
  end

  local prevInit = OnInit
  if type(prevInit) == "function" then
    function OnInit(...)
      prevInit(...)
      S.balls = nil
      S.Load()
    end
  end

  local prevBust = SetBustupIconCharaId
  if type(prevBust) == "function" then
    function SetBustupIconCharaId(a1, a2, ...)
      local b = type(funcLuaCommand) == "function" and S.Load() or false
      if b then
        local i = math.floor(tonumber(a1) or 0)
        return prevBust(a1, b[2 + b[1] + i] or 0, ...)
      end
      return prevBust(a1, a2, ...)
    end
  end

  local prev = GetBustupIconRarityType
  if type(prev) == "function" then
    function GetBustupIconRarityType(a1, ...)
      local b = type(funcLuaCommand) == "function" and S.Load() or false
      if b then
        local i = math.floor(tonumber(a1) or 0)
        if i < 0 or i >= b[1] then
          return 0
        end
        return b[2 + i] or 0
      end
      return prev(a1, ...)
    end
  end
end
