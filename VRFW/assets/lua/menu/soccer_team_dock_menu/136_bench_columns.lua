-- menu_engine: the second bench column (lua\_all\81_team_editor_bench_columns.lua, VRFW_BenchColumns) in the dock (soccer_team_dock_menu): the column drawn after the retail draw of the formation (UpdateFormationInfo).
-- Definitions only; no engine call at load.
if VRFW_Host ~= nil then
  local STEM = "soccer_team_dock_menu"
  local ID = "menu_engine.bench_columns"
  local function columns()
    return type(VRFW_BenchColumns) == "table" and VRFW_BenchColumns or nil
  end

  VRFW_Host.on(STEM, "OnInit", {
    id = ID, phase = "before", priority = -900,
    fn = function()
      local c = columns()
      -- the dock's layout (field_dx / bench_dx)
      if c then c.Begin({ layout = true }) end
    end,
  })

  -- an instance 19-24 set up / opened: drawn (or hidden); the frame and the focus range once they open
  VRFW_Host.on(STEM, "OnSetupLayer", {
    id = ID, phase = "after",
    fn = function(_, layer, index)
      local c = columns()
      if c and type(index) == "number" and index >= 19 then c.DrawAt(index) end
    end,
  })
  VRFW_Host.on(STEM, "OnOpenLayer", {
    id = ID, phase = "after",
    fn = function(_, layer, index)
      local c = columns()
      if c and type(layer) == "number" and type(index) == "number" then c.Opened(layer, index) end
    end,
  })

  -- the column's moves (right from the bench, inside the column, left back to the bench)
  VRFW_Host.on(STEM, "OnChangeFocus", {
    id = ID, phase = "around", priority = -900,
    fn = function(nxt, layer, input, ...)
      local c = columns()
      if c and c.Active() and c.Nav(layer, input) then
        return 1
      end
      return nxt(layer, input, ...)
    end,
  })

  -- the retail focus change and card draws redraw the instances they touch with the retail rule (none past 18)
  VRFW_Host.on(STEM, "UpdateChangeFocusLayer", {
    id = ID, phase = "after",
    fn = function(_, layer, from, to)
      local c = columns()
      if c and c.Active() then c.Focused(layer, to) end
    end,
  })
  for _, point in ipairs({ "UpdateFormationInfo" }) do
    VRFW_Host.on(STEM, point, {
      id = ID, phase = "after",
      fn = function()
        local c = columns()
        if c and c.Active() then c.Draw() end
      end,
    })
  end
end
