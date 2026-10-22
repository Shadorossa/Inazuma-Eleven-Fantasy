-- BetterQoL graft util_album_row: the row «Álbum de jugadores» of «Caseta del club» (play_guide_top_menu).
-- Kind 5 joins the row-kind list `t` when the list's first row is set up; its label, help line and icon go in the
-- lists read by kind (index 6); A on it opens BetterQoL's player album page (BetterQoL.Album.Open). The lists
-- are chunk locals reached as upvalues (EVT_UpvalueFind); without EVT_DEBUG nothing changes. No engine call at load.
@UPV@
do
  local UAL_ROW = {
    OWNERS = {"OnInit", "SetupListItemButton", "SetupListItemText", "SetupTextureListItem", "GetListButtonLayerIndex",
      "OnDecideFocus", "OnChangeFocus", "OnEnter", "OnSetupLayer"},
    LIST = 530619243,                    -- mainmenu90_12_list_item_small
    KIND = 5,                            -- the new row's kind (retail kinds 0..3, «Estadísticas del club» 4)
    HELP = 0,                            -- the kind of «Ayuda»
    LABEL = 4006794419,                  -- BetterQoL.Album.Row
    LINE = 3645827048,                   -- BetterQoL.Album.RowHelp
    ICON = {3154739323 --[[icon_list_s05_on]], 2036400348 --[[icon_list_s05_off]]},
    FIRST_LABEL = 1172051184,            -- t3[1]: the retail label of «Ayuda»
    FIRST_LINE = 1752451890,             -- t4[1]: the retail help line of «Ayuda»
    FIRST_ICON = 2573393831,             -- t5[1][1]: icon_list_s03_on
    LOG = 3661580131,                    -- CMND_EVT_LOG
    SOUND = 1917805374, SY_ERROR = 2086672038,
    found = nil, logged = false,
  }

  local function UalIsKinds(v)
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

  -- the four lists: kinds (t), labels (t3), help lines (t4), icons (t5); nil when one is not reachable
  local function UalLists()
    if UAL_ROW.found == nil then
      local f = {}
      f.kinds = EVT_UpvalueFind(UAL_ROW.OWNERS, UalIsKinds)
      f.labels = EVT_UpvalueFind(UAL_ROW.OWNERS, function(v) return v[1] == UAL_ROW.FIRST_LABEL end)
      f.lines = EVT_UpvalueFind(UAL_ROW.OWNERS, function(v) return v[1] == UAL_ROW.FIRST_LINE end)
      f.icons = EVT_UpvalueFind(UAL_ROW.OWNERS, function(v)
        return type(v[1]) == "table" and v[1][1] == UAL_ROW.FIRST_ICON
      end)
      if f.kinds == nil or f.labels == nil or f.lines == nil or f.icons == nil then
        return nil
      end
      UAL_ROW.found = f
    end
    return UAL_ROW.found
  end

  -- the row in the list (once per VM; again when another script rebuilt the list): last, or in front of «Ayuda» when
  -- «Ayuda» is already the last row. true when the row is in the list.
  local function UalAdd()
    local f = UalLists()
    if f == nil then
      return false
    end
    local k = UAL_ROW.KIND
    f.labels[k + 1] = UAL_ROW.LABEL
    f.lines[k + 1] = UAL_ROW.LINE
    f.icons[k + 1] = UAL_ROW.ICON
    for _, v in ipairs(f.kinds) do
      if v == k then
        return true
      end
    end
    local n = #f.kinds
    if f.kinds[n] == UAL_ROW.HELP then
      table.insert(f.kinds, n, k)
    else
      f.kinds[n + 1] = k
    end
    return true
  end

  Utilities = type(Utilities) == "table" and Utilities or {}
  BetterQoL.AlbumRow = {KIND = UAL_ROW.KIND, Add = UalAdd}

  if EVT_UAL_ROW_WRAPPED == nil then
    EVT_UAL_ROW_WRAPPED = {}
  end

  local setup = _ENV.OnSetupLayer
  if type(setup) == "function" and not EVT_UAL_ROW_WRAPPED[setup] then
    local w = function(a1, a2, ...)
      if a1 == UAL_ROW.LIST and a2 == 0 then
        local ok = UalAdd()
        if not UAL_ROW.logged then
          UAL_ROW.logged = true
          pcall(funcLuaCommand, UAL_ROW.LOG, "betterqol album row",
            ok and string.format("added (%d rows)", #UAL_ROW.found.kinds) or "row lists not found (no EVT_DEBUG?): no row")
        end
      end
      return setup(a1, a2, ...)
    end
    EVT_UAL_ROW_WRAPPED[w] = true
    _ENV.OnSetupLayer = w
  end

  local decide = _ENV.OnDecideFocus
  if type(decide) == "function" and not EVT_UAL_ROW_WRAPPED[decide] then
    local w = function(a1, a2, ...)
      local f = UAL_ROW.found
      if a1 == UAL_ROW.LIST and f ~= nil and type(a2) == "number" and f.kinds[a2 + 1] == UAL_ROW.KIND then
        local P = type(Utilities) == "table" and BetterQoL.Album or nil
        if type(P) == "table" and type(P.Open) == "function" then
          local ok, err = pcall(P.Open)
          if not ok then
            pcall(funcLuaCommand, UAL_ROW.LOG, "betterqol album open failed", tostring(err))
          end
        else
          pcall(funcLuaCommand, UAL_ROW.SOUND, UAL_ROW.SY_ERROR)
        end
        return
      end
      return decide(a1, a2, ...)
    end
    EVT_UAL_ROW_WRAPPED[w] = true
    _ENV.OnDecideFocus = w
  end
end
