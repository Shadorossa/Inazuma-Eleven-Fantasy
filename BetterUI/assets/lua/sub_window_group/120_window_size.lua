-- BetterUI (prefix BetterUI), the game's one-column sub windows (sub_window_group type 0, layer
-- win05_13_sub_list_locator: PERSONAJE, COMANDOS and every one-column list popup): the blue panel follows the row count.
-- The panel is two quads, _list_sub_base01 (blue gradient) and _list_sub_ring01 (light ring), each 488 x 804 px with its
-- top edge at the window top. Their mask textures (list_sub_msk00 / list_sub_msk01, 488 x 268) are mapped at their own
-- pixel size (UV scale 804 / 268 = 3 along the height), so the visible panel ends 268 px under the top: the 2-row size.
-- The retail size animation (win_size line03_01 .. line09_01) moves that mask 70 px per extra row through a texture UV
-- track; in game that track has no effect, while the outer frame (_list_sub_base02, a node scale track) does grow.
-- The quads' height is set instead, every time the window layer opens: height = 804 x visible / 268, visible =
-- 268 + 70 x (rows - 2), so the mask (stretched with its quad) ends at the visible height. Checked against the layout:
-- row N sits at y -128 - 70 x (N - 1) with a 72 px plate, so the last plate ends 34 px over the panel bottom for any row
-- count (the retail 2-row margin), and the outer frame (304 + 70 x (rows - 2) px from y +18) keeps its 18 px border.
-- 1- and 2-row windows get the layout height back (the layer is reused between windows). Wrappers by assignment (the
-- script has no VRFW_Host host); no engine call at load time.
if BetterUI_WindowSize == nil and type(SetupWindowParams) == "function" and type(OnOpenLayer) == "function" then
  local W = {
    NODE_SIZE = 2885415772,          -- (layer, instance, node, width, height): a quad's size in px
    LAYER_NAME = "win05_13_sub_list_locator",   -- the window layer of sub window type 0
    PANEL_NODES = {"_list_sub_base01", "_list_sub_ring01"},
    PANEL_WIDTH = 488,               -- the quads' layout size
    PANEL_HEIGHT = 804,
    MASK_HEIGHT = 268,               -- the mask textures' height: the visible panel at the layout size (2 rows)
    LAYOUT_ROWS = 2,
    ROW_STEP = 70,                   -- px per row (the _listNN anchors)
    MAX_ROWS = 9,
    rows = nil,                      -- the row count of the window being opened (retail getMaxParamNum)
  }
  BetterUI_WindowSize = W

  local function log(...)
    if PRINT ~= nil then
      pcall(PRINT, "EVT_UI window_size", ...)
    end
  end

  -- the quads' height that shows a panel of this many rows
  function W.PanelHeight(rows)
    local shown = math.max(W.LAYOUT_ROWS, math.min(W.MAX_ROWS, rows))
    local visible = W.MASK_HEIGHT + W.ROW_STEP * (shown - W.LAYOUT_ROWS)
    return W.PANEL_HEIGHT * visible / W.MASK_HEIGHT, visible
  end

  local setup = SetupWindowParams
  SetupWindowParams = function(count, texts, size, ...)
    local r = table.pack(setup(count, texts, size, ...))
    local ok, rows = pcall(getMaxParamNum, count, size)
    W.rows = (ok and type(rows) == "number") and rows or nil
    return table.unpack(r, 1, r.n)
  end

  local open_layer = OnOpenLayer
  OnOpenLayer = function(layer, idx, ...)
    local r = table.pack(open_layer(layer, idx, ...))
    if W.rows ~= nil and (idx or 0) == 0 and type(VRFW_Crc32) == "function" and type(GetWindowLayerName) == "function" then
      local ok, window = pcall(GetWindowLayerName)
      if ok and layer == window and layer == VRFW_Crc32(W.LAYER_NAME) then
        local height, visible = W.PanelHeight(W.rows)
        for _, node in ipairs(W.PANEL_NODES) do
          pcall(funcLuaMenuCommand, W.NODE_SIZE, layer, 0, VRFW_Crc32(node), W.PANEL_WIDTH, height)
        end
        log("rows " .. W.rows .. ", panel " .. visible .. " px (quads " .. height .. ")")
        W.rows = nil
      end
    end
    return table.unpack(r, 1, r.n)
  end
end
