-- VRFW board node menus, game Lua side (every menu VM; script side scripts\node_menu.lua; docs/framework/node-menu.md).
-- A mod's [[VRFW.NodeMenu]] names Chronicle board nodes and a handler (a function of the board's VM, `Name` or `Table.Name`): picking one
-- of those pieces calls handler(piece index, node name, menu key) instead of opening its command menu. Mechanism only:
-- what the menu shows is the declaring mod's.
--   VRFW_NodeMenu.Of(idx)        -> handler name, node name, key of board piece index `idx` (nil = none)
--   VRFW_NodeMenu.IsPiece(idx)   -> true when the piece opens a mod menu (the board's balloon hides its face)
--   VRFW_NodeMenu.OpenPiece(idx) -> true when the piece's handler ran its flow (route_board's VRFW_RB_PieceOpen default;
--                                   the board then goes back as after «back» from its command menu)
-- Log: "LUAPRINT … VRFW_NODE_MENU …".
if VRFW_NodeMenu == nil then
  local N = {
    OF_PIECE = 1787427826,           -- CMND_VRFW_NODE_MENU_OF_PIECE (pieceId) -> handler, node, key
    by_idx = {},                     -- board piece index -> {handler, node, key} or false (cached)
  }
  VRFW_NodeMenu = N

  function N.Log(...)
    if PRINT ~= nil then
      pcall(PRINT, "VRFW_NODE_MENU", ...)
    end
  end

  function N.Of(idx)
    if idx == nil or idx < 0 or VRFW_RN_Load == nil then
      return nil
    end
    local m = N.by_idx[idx]
    if m == nil then
      m = false
      local node = (VRFW_RN_Load().byIdx or {})[idx]
      if node ~= nil and node.piece ~= nil then
        local ok, handler, name, key = pcall(funcLuaCommand, N.OF_PIECE, node.piece)
        if ok and type(handler) == "string" and handler ~= "" then
          m = {handler = handler, node = name, key = key}
        end
      end
      N.by_idx[idx] = m
    end
    if m == false then
      return nil
    end
    return m.handler, m.node, m.key
  end

  function N.IsPiece(idx)
    return N.Of(idx) ~= nil
  end

  function N.OpenPiece(idx)
    local handler, node, key = N.Of(idx)
    if handler == nil then
      return false
    end
    local fn = _G
    for part in string.gmatch(handler, "[^%.]+") do
      fn = type(fn) == "table" and fn[part] or nil
    end
    if type(fn) ~= "function" then
      N.Log("piece", idx, "node", node, "handler", handler, "is not defined in this VM")
      return false
    end
    local ok, ran = pcall(fn, idx, node, key)
    if not ok then
      N.Log("piece", idx, "node", node, "handler", handler, "error", tostring(ran))
      return false
    end
    N.Log("piece", idx, "node", node, "handler", handler, ran == true and "ran" or "passed")
    return ran == true
  end
end
