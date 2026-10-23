-- bb_chronicle_teams bb_draft, the 1 vs 1's match settings without the difficulty row while a mod owns the AI
-- difficulty (enjoy_team_select_menu_offline; bbd_difficulty_common.lua). The settings list (its 4 rows: difficulty,
-- stadium, BGM, commentator) opens with the focus on row 0, the difficulty, whose decide opens the difficulty sub
-- window. With an owned difficulty, when the list's last row opened: row 0 is hidden, without its click zone and
-- focus, and the focus starts on row 1; a focus that reaches row 0 (Up, a wrap) goes to row 1; a decide on row 0 does
-- nothing. The match start reads GetSelectDifficultyIdx, which answers the owned index. Globals only; nothing runs at
-- chunk load.
BBD_DIFFICULTY.FIRST_ROW = 1 -- the first row shown: the stadium
BBD_DIFFICULTY.CURSOR = 3313461902 --[[cursor: the attach of the list rows]]

-- the focus (and the cursor) on row `row` of the settings list
function BBD_DifficultyFocusRow(row)
  local L = BBD_DIFFICULTY.OPTIONS
  local n = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM]], L)
  if type(n) ~= "number" or row >= n then
    return
  end
  funcLuaMenuCommand(1778826357 --[[control focus (layer, idx, on)]], L, 0, false)
  funcLuaMenuCommand(3781155141 --[[focus look]], L, 0, 2734777837, 2, 973515837)
  funcLuaMenuCommand(1778826357 --[[control focus (layer, idx, on)]], L, row, true)
  funcLuaMenuCommand(3781155141 --[[focus look]], L, row, 2734777837, 0, 973515837)
  funcLuaMenuCommand(381797568 --[[CMND_SET_CURSOR_LOCATOR]], L, BBD_DIFFICULTY.CURSOR, row, n)
end

-- the difficulty row hidden, the focus on the first row shown
function BBD_DifficultyHideRow()
  local L = BBD_DIFFICULTY.OPTIONS
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], L, 0, false)
  funcLuaMenuCommand(855005857 --[[click zone]], L, 0, false)
  BBD_DifficultyFocusRow(BBD_DIFFICULTY.FIRST_ROW)
  BBD_DifficultyLog("match settings: the difficulty row hidden")
end

do
  local open = OnOpenLayer
  function OnOpenLayer(a1, a2, ...)
    local r = table.pack(open(a1, a2, ...))
    if a1 == BBD_DIFFICULTY.OPTIONS then
      local okn, n = pcall(funcLuaMenuCommand, 1175615627 --[[CMND_GET_CREATE_LAYER_NUM]], a1)
      local ok, owned = pcall(BBD_DifficultyOwned)
      if okn and type(n) == "number" and a2 == n - 1 and ok and owned ~= nil then
        local okh, err = pcall(BBD_DifficultyHideRow)
        if not okh then
          BBD_DifficultyLog("match settings error", tostring(err))
        end
      end
    end
    return table.unpack(r, 1, r.n)
  end

  local change = OnChangeFocus
  function OnChangeFocus(a1, a2, ...)
    if a1 == BBD_DIFFICULTY.OPTIONS then
      local ok, owned = pcall(BBD_DifficultyOwned)
      if ok and owned ~= nil and funcLuaMenuCommand(2603265800 --[[focus index]], a1) == 0 then
        pcall(BBD_DifficultyFocusRow, BBD_DIFFICULTY.FIRST_ROW)
        return
      end
    end
    return change(a1, a2, ...)
  end

  local decide = OnDecideFocus
  function OnDecideFocus(a1, a2, ...)
    if a1 == BBD_DIFFICULTY.OPTIONS and a2 == 0 then
      local ok, owned = pcall(BBD_DifficultyOwned)
      if ok and owned ~= nil then
        return
      end
    end
    return decide(a1, a2, ...)
  end
end
