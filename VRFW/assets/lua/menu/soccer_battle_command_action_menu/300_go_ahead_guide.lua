-- VRFW go-ahead guide (docs/framework/ai-move.md §6): a mod's script may show its own word on the «¡Subid!» button guide
-- (layer soccer08_17_go_ahead_guide, the L2 plate) while the game hides it (the team without the ball):
-- VRFW.hud.go_ahead_guide("<sprite>") sets the rule flag VRFW.hud.go_ahead_guide = crc32 of a sprite of the guide's
-- atlas (soccer08_17, added by the mod's image declaration) and VRFW.hud.go_ahead_guide.gray. The engine calls
-- SetGoAheadButtonGuideStatus(visible, gray, area) every frame for the controlled player (gray = true while the order
-- is not available) and (false, false) to hide every guide; only the per-frame call is turned into «shown with the
-- mod's sprite». Flag 0 or the game showing its own guide: the retail sprite and the retail call. The recast gauge
-- stays hidden under the mod's word. Wraps the include's globals; no engine call at load time.
do
  local C = {
    FLAG_GET = VRFW_Cmd.VRFW_RULE_FLAG_GET,    -- CMND_VRFW_RULE_FLAG_GET(key) -> value (0 = not set)
    LOG = VRFW_Cmd.EVT_LOG,         -- CMND_EVT_LOG
  }
  local FLAG = "VRFW.hud.go_ahead_guide"
  local FLAG_GRAY = "VRFW.hud.go_ahead_guide.gray"
  local GUIDE = 4104611069          -- soccer08_17_go_ahead_guide
  local RETAIL_SPRITE = 3337459067  -- gtxt_action_lineup01 («¡Subid!»)
  local state = { shown = 0, active = false, logged = {} }

  local function flag(key)
    local ok, v = pcall(funcLuaCommand, C.FLAG_GET, key)
    if ok and type(v) == "number" then
      return v
    end
    return 0
  end

  -- put `sprite` (0 = the retail one) on the guide's word mesh, once per change
  local function show(sprite)
    if sprite == state.shown or type(SwapTextureAttachButtonGuide) ~= "function" then
      return
    end
    state.shown = sprite
    pcall(SwapTextureAttachButtonGuide, GUIDE, 0, sprite ~= 0 and sprite or RETAIL_SPRITE)
    if not state.logged[sprite] then
      state.logged[sprite] = true
      pcall(funcLuaCommand, C.LOG, "VRFW go_ahead_guide sprite", string.format("%.0f", sprite))
    end
  end

  local set = SetGoAheadButtonGuideStatus
  if type(set) == "function" and VRFW_GoAheadGuideStatus ~= set then
    VRFW_GoAheadGuideStatus = function(visible, gray, area)
      local sprite = flag(FLAG)
      state.active = sprite ~= 0 and not visible and gray == true
      if state.active then
        show(sprite)
        return set(true, flag(FLAG_GRAY) ~= 0, area)
      end
      if visible then
        show(0)
      end
      return set(visible, gray, area)
    end
    SetGoAheadButtonGuideStatus = VRFW_GoAheadGuideStatus
  end

  local gauge = UpdateGoAheadRecastGauge
  if type(gauge) == "function" and VRFW_GoAheadGuideGauge ~= gauge then
    VRFW_GoAheadGuideGauge = function(visible, rate)
      if state.active then
        return gauge(false, 0)
      end
      return gauge(visible, rate)
    end
    UpdateGoAheadRecastGauge = VRFW_GoAheadGuideGauge
  end

  -- a retail (re)setup of the guide puts the retail sprite back: apply the mod's one again on the next frame
  local texture = UpdateTextureAttachButtonGuide
  if type(texture) == "function" and VRFW_GoAheadGuideTexture ~= texture then
    VRFW_GoAheadGuideTexture = function(layer, ...)
      local r = table.pack(texture(layer, ...))
      if layer == GUIDE then
        state.shown = 0
      end
      return table.unpack(r, 1, r.n)
    end
    UpdateTextureAttachButtonGuide = VRFW_GoAheadGuideTexture
  end
end
