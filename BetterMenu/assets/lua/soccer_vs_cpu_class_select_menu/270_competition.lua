-- This menu's framework difficulty graft is already assembled when this loose
-- patch runs. Keep it intact, capturing only its final reservation.
-- Over the Competition list the class window sits at the bottom of the screen, centred on the three players of the
-- Competition shot (session op «players_x»: the court spots projected with the shot's framing) and kept in the
-- screen's left half, clear of the formation board on the right. Its height comes from its layout (vsroute01_20.g4pkm:
-- _list_base03 from y 36, 404 px for 4 rows every 70 px) and the classes the focused game offers
-- (CMND_VRFW_FM_DIFFICULTIES).
do
  local C, decide, open_layer = BetterMenu.Competition, OnDecideFocus, OnOpenLayer
  if type(decide) == "function" then
    function OnDecideFocus(...) return C.Capture(decide, ...) end
  end
  local WINDOW = 2649426425          -- vsroute01_20_list_locator: the class window and its row locators
  local DIFFS = 1129484790           -- CMND_VRFW_FM_DIFFICULTIES (game) -> true, n, classes
  local LAYOUT = { TOP = 36, HEIGHT = 404, WIDTH = 560, ROWS = 4, ROW_PITCH = 70 }
  local BOTTOM = 948                 -- 12 px above the title menu's lower tile row (y 960, docs/game/mods/better-menu.md §12)
  local HALF = 960                   -- the screen's left half (1920 wide)
  local function place(a2)
    local session = C.State()
    if type(session) ~= "table" or session.open ~= true or not C.Active() then return end
    local rows = LAYOUT.ROWS
    local r = table.pack(pcall(funcLuaCommand, DIFFS, tonumber(session.game) or 0))
    if r[1] and r[2] == true and type(r[3]) == "number" and r[3] >= 1 and r[3] <= LAYOUT.ROWS then rows = r[3] end
    local height = LAYOUT.HEIGHT - LAYOUT.ROW_PITCH * (LAYOUT.ROWS - rows)
    local x = tonumber(C.State("players_x")) or 0
    if x <= 0 then x = HALF / 2 end
    x = math.max(LAYOUT.WIDTH / 2, math.min(HALF - LAYOUT.WIDTH / 2, x))
    local top = BOTTOM - height
    funcLuaMenuCommand(1389957207, WINDOW, x, -(top + LAYOUT.TOP), 0, a2)   -- the layer's origin is 36 px below the window's top
    C.Log("class window", rows, "rows at", x, top)
  end
  if type(open_layer) == "function" then
    function OnOpenLayer(a1, a2, ...)
      local r = table.pack(open_layer(a1, a2, ...))
      if a1 == WINDOW then
        local ok, why = pcall(place, a2)
        if not ok then C.Log("class window error", tostring(why)) end
      end
      return table.unpack(r, 1, r.n)
    end
  end
end
