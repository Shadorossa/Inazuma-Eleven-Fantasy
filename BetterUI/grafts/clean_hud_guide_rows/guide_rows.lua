-- BetterUI (clean_hud) graft clean_hud_guide_rows: the «Caseta del club» list (play_guide_top_menu) with «Ayuda» (kind 0)
-- always the last row. The row kinds are a chunk local (`t`, one kind per row, read by every list function and by the
-- press); a patch reaches it only as an upvalue of those functions (EVT_UpvalueFind, lua_patch's EVT_DEBUG), so it is edited
-- IN PLACE and no retail local is named in this block. Two wrappers, no engine call at load:
--   * OnInit (before the retail one): Ayuda back to the first place. The retail OnInit marks a locked «Archivo de escenas»
--     in t2 by the ROW index where t[i] == 2, while the lists read t2 by kind + 1; with kind == row index (the retail
--     order) both agree, so the mark is made on the retail order.
--   * OnSetupLayer of the list layer's first row (each open, before the retail code takes the row count): Ayuda to the end,
--     after every kind another mod appended. One log line per VM.
-- A mod that adds a row appends its kind to the list before that call (at load, in OnInit, or in a wrapper of OnSetupLayer
-- defined after this one) and needs nothing else; BetterUI.GuideList.Apply() runs the rule again for a mod that adds its row
-- later than that.
@UPV@
do
  local CHD_GUIDE = {
    OWNERS = {"OnInit", "SetupListItemButton", "GetListButtonLayerIndex", "OnDecideFocus", "OnChangeFocus", "OnEnter"},
    LIST = 530619243,                    -- mainmenu90_12_list_item_small
    LOG = 3661580131,                    -- CMND_EVT_LOG
    HELP = 0,                            -- the kind of «Ayuda»
    kinds = nil, logged = false,
  }

  -- the row-kind list: distinct integers 0..127, 4..16 of them, with the four retail kinds (t2 = {0, 0, 0, 0} is not distinct)
  local function CHD_GuideIsKinds(v)
    if v[0] ~= nil or #v < 4 or #v > 16 then
      return false
    end
    local seen = {}
    for _, k in ipairs(v) do
      if type(k) ~= "number" or k % 1 ~= 0 or k < 0 or k > 127 or seen[k] then
        return false
      end
      seen[k] = true
    end
    return seen[0] == true and seen[1] == true and seen[2] == true and seen[3] == true
  end

  local function CHD_GuideKinds()
    if CHD_GUIDE.kinds == nil then
      CHD_GUIDE.kinds = EVT_UpvalueFind(CHD_GUIDE.OWNERS, CHD_GuideIsKinds)
    end
    return CHD_GUIDE.kinds
  end

  -- Ayuda to the end (last = true) or the front (last = false); the other kinds keep their order. true when it moved.
  local function CHD_GuideMove(last)
    local kinds = CHD_GuideKinds()
    if kinds == nil then
      return false
    end
    local at
    for i = 1, #kinds do
      if kinds[i] == CHD_GUIDE.HELP then
        at = i
        break
      end
    end
    local want = last and #kinds or 1
    if at == nil or at == want then
      return false
    end
    table.remove(kinds, at)
    table.insert(kinds, want, CHD_GUIDE.HELP)
    return true
  end

  BetterUI = type(BetterUI) == "table" and BetterUI or {}
  BetterUI.GuideList = {Apply = function() return CHD_GuideMove(true) end}

  if EVT_CHD_GUIDE_WRAPPED == nil then
    EVT_CHD_GUIDE_WRAPPED = {}
  end

  local init = _ENV.OnInit
  if type(init) == "function" and not EVT_CHD_GUIDE_WRAPPED[init] then
    local w = function(...)
      CHD_GuideMove(false)
      return init(...)
    end
    EVT_CHD_GUIDE_WRAPPED[w] = true
    _ENV.OnInit = w
  end

  local setup = _ENV.OnSetupLayer
  if type(setup) == "function" and not EVT_CHD_GUIDE_WRAPPED[setup] then
    local w = function(a1, a2, ...)
      if a1 == CHD_GUIDE.LIST and a2 == 0 then
        CHD_GuideMove(true)
        if not CHD_GUIDE.logged then
          CHD_GUIDE.logged = true
          local kinds = CHD_GUIDE.kinds
          pcall(funcLuaCommand, CHD_GUIDE.LOG, "EVT guide_rows",
            kinds == nil and "row list not found (no EVT_DEBUG?): «Ayuda» stays first"
              or string.format("«Ayuda» last of %d row(s)", #kinds))
        end
      end
      return setup(a1, a2, ...)
    end
    EVT_CHD_GUIDE_WRAPPED[w] = true
    _ENV.OnSetupLayer = w
  end
end
