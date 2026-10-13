-- BetterUI (clean_hud) graft clean_hud_dock_rows: the Team Dock list loses its «Ajustes de equipo» (kind 12) and
-- «Formación» (kind 0) rows. The list kinds (one per row) are a chunk local; a patch reaches it only as an upvalue of
-- the list functions (EVT_UpvalueFind, lua_patch's EVT_DEBUG), so it is edited IN PLACE: no retail local is named in
-- this block, so the build does not promote the chunk's locals (that redefined every retail function after the other
-- dock patches and threw away BetterUI's layout, 1.21.8). Removing by value re-packs the list.
-- 1.21.10: the list is recognised by the kinds that every variant keeps (7, 8, 9; no 3..6), not by «Equipar todo»
-- (10): Inazuma Fantasy's pachanga_dock removes 10 at load, so 1.21.9 never found the list. The list is filtered at
-- load (no engine call) and again by an OnSetupLayer wrapper when the list layer's first row is set up (each open,
-- before the row count is taken), which also writes the one log line. Without EVT_DEBUG the list stays retail.
@UPV@
do
  local CHD_ROWS = {
    HIDDEN = {[12] = true, [0] = true},   -- 12 = Ajustes de equipo (▶), 0 = Formación
    OWNERS = {"SetupTeamDockListItem", "UpdateViewTeamDockListItem", "OnSetupLayer", "OnEnter"},
    HOOK = "OnSetupLayer",
    LIST = 3367997069,                     -- team01_02_list_item
    LOG = 3661580131,                      -- CMND_EVT_LOG
    list = nil, removed = 0, logged = false,
  }

  -- the row-kind list: numbers only, 3..16 rows, with the kinds every variant keeps (7, 8, 9) and none of 3..6
  -- (which rules out the 0..9 / 0,4 tables of the same chunk)
  local function CHD_RowsIsList(v)
    if v[0] ~= nil or #v < 3 or #v > 16 then
      return false
    end
    local seen = {}
    for _, k in ipairs(v) do
      if type(k) ~= "number" or (k >= 3 and k <= 6) then
        return false
      end
      seen[k] = true
    end
    return seen[7] == true and seen[8] == true and seen[9] == true
  end

  local function CHD_RowsFilter()
    if CHD_ROWS.list == nil then
      CHD_ROWS.list = EVT_UpvalueFind(CHD_ROWS.OWNERS, CHD_RowsIsList)
    end
    local kinds = CHD_ROWS.list
    if kinds == nil then
      return
    end
    for row = #kinds, 1, -1 do
      if CHD_ROWS.HIDDEN[kinds[row]] then
        table.remove(kinds, row)
        CHD_ROWS.removed = CHD_ROWS.removed + 1
      end
    end
  end

  CHD_RowsFilter()

  if EVT_CHD_ROWS_WRAPPED == nil then
    EVT_CHD_ROWS_WRAPPED = {}
  end
  local cur = _ENV[CHD_ROWS.HOOK]
  if type(cur) == "function" and not EVT_CHD_ROWS_WRAPPED[cur] then
    local w = function(a1, a2, ...)
      if a1 == CHD_ROWS.LIST and a2 == 0 then
        CHD_RowsFilter()
        if not CHD_ROWS.logged then
          CHD_ROWS.logged = true
          local msg
          if CHD_ROWS.list == nil then
            msg = "row list not found (no EVT_DEBUG?): «Ajustes de equipo» / «Formación» stay"
          else
            msg = string.format("removed %d row(s) («Ajustes de equipo» / «Formación»), %d left",
              CHD_ROWS.removed, #CHD_ROWS.list)
          end
          pcall(funcLuaCommand, CHD_ROWS.LOG, "EVT dock_rows", msg)
        end
      end
      return cur(a1, a2, ...)
    end
    EVT_CHD_ROWS_WRAPPED[w] = true
    _ENV[CHD_ROWS.HOOK] = w
  end
end
