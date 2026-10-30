-- menu_engine: the saved filters of the move lists with the framework's tension and family rows
-- (scripts\technique_filter.lua).
-- Runs in every script VM that includes the item filter (LUA_ITEM_FILTER_MENU_INC: SaveFilterData, LoadFilterData,
-- OpenFilter, OnAfterReceiveFilterParamCommon). The game's save holds six tension rows of a filter, so while the
-- framework serves the rows (CMND_VRFW_TECHNIQUE_FILTER_VALUES):
-- * save: the ticked tension and family rows are kept by the framework by value (CMND_VRFW_TECHNIQUE_FILTER_KEEP) and
--   the game saves «all tension rows» in their place;
-- * load: the kept values are ticked again by row (CMND_VRFW_TECHNIQUE_FILTER_KEPT); a saved filter with no kept
--   values gets «all tension rows» (game rows saved before are not the same values).
-- Framework off: the game's functions run unchanged. No engine call at load time.
if VRFW_TechniqueFilterSave == nil and type(SaveFilterData) == "function" and type(LoadFilterData) == "function"
    and type(OpenFilter) == "function" and type(OnAfterReceiveFilterParamCommon) == "function"
    and type(GetFilterParamArray) == "function" and type(CreateSendFilterParamArray) == "function"
    and type(InsertFilterParam) == "function" then
  local TS = {
    CMD_VALUES = VRFW_Cmd.VRFW_TECHNIQUE_FILTER_VALUES,   -- CMND_VRFW_TECHNIQUE_FILTER_VALUES(list item type) -> n, value 1, ... (0 = off)
    CMD_FAMILIES = VRFW_Cmd.VRFW_TECHNIQUE_FILTER_FAMILIES, -- CMND_VRFW_TECHNIQUE_FILTER_FAMILIES() -> first row, n, ... (0 = no family rows)
    FAMILY_CODE = 256,         -- a family row's kept value: FAMILY_CODE + its index (0-based; tension values are bytes)
    CMD_KEEP = VRFW_Cmd.VRFW_TECHNIQUE_FILTER_KEEP,     -- CMND_VRFW_TECHNIQUE_FILTER_KEEP(save id, n, value 1, ...) (n < 0 = forget)
    CMD_KEPT = VRFW_Cmd.VRFW_TECHNIQUE_FILTER_KEPT,     -- CMND_VRFW_TECHNIQUE_FILTER_KEPT(save id) -> n, value 1, ... (-1 = none)
    CMD_SAVE = 3666261249,     -- the game's save of a filter (save id, n, list item type / value / option triples)
    TENSION = 3,               -- list item type of the tension tab
    ALL = 8,                   -- list item type «all rows of a tab» (value = the tab's type)
    loading = nil,             -- save id of the load in flight (its params arrive through OnAfterReceive…)
  }
  VRFW_TechniqueFilterSave = TS

  -- the served row values by row (the tension values, then FAMILY_CODE + index of each family row), or nil while the
  -- framework keeps the game's rows
  local function served()
    local r = table.pack(pcall(funcLuaCommand, TS.CMD_VALUES, TS.TENSION))
    if not r[1] or type(r[2]) ~= "number" or r[2] <= 0 then
      return nil
    end
    local values = {}
    for i = 1, r[2] do
      values[i] = r[2 + i]
    end
    local f = table.pack(pcall(funcLuaCommand, TS.CMD_FAMILIES))
    if f[1] and type(f[2]) == "number" and type(f[3]) == "number" and f[3] > 0 then
      for i = 1, f[3] do
        values[f[2] + i] = TS.FAMILY_CODE + i - 1
      end
    end
    return values
  end

  local function is_all(p)
    return p.listItemType == TS.ALL and p.value == TS.TENSION and p.option == 0
  end

  local game_save = SaveFilterData
  function SaveFilterData(a1)
    local values = served()
    if values == nil then
      return game_save(a1)
    end
    local copy, ticked, all, any = {}, {}, false, false
    for _, p in ipairs(GetFilterParamArray()) do
      if p.listItemType == TS.TENSION and p.option == 0 then
        any = true
        ticked[#ticked + 1] = values[p.value + 1]
      else
        all = all or is_all(p)
        copy[#copy + 1] = p
      end
    end
    if not any and not all then
      return game_save(a1)
    end
    if any then
      pcall(funcLuaCommand, TS.CMD_KEEP, a1, #ticked, table.unpack(ticked))
      if not all then
        InsertFilterParam(copy, TS.ALL, TS.TENSION, 0)
      end
    else
      pcall(funcLuaCommand, TS.CMD_KEEP, a1, -1)
    end
    local send = CreateSendFilterParamArray(copy)
    funcLuaMenuCommand(TS.CMD_SAVE, a1, #send, send)
  end

  local game_load = LoadFilterData
  function LoadFilterData(a1, a2)
    TS.loading = a1
    return game_load(a1, a2)
  end

  local game_open = OpenFilter
  function OpenFilter(...)
    TS.loading = nil
    return game_open(...)
  end

  local game_after = OnAfterReceiveFilterParamCommon
  function OnAfterReceiveFilterParamCommon(...)
    local id = TS.loading
    TS.loading = nil
    local values = id ~= nil and served() or nil
    if values ~= nil then
      local t = GetFilterParamArray()
      local r = table.pack(pcall(funcLuaCommand, TS.CMD_KEPT, id))
      local kept = r[1] and type(r[2]) == "number" and r[2] >= 0
      local had = false
      for i = #t, 1, -1 do
        local p = t[i]
        if p.listItemType == TS.TENSION and p.option == 0 then
          had = true
          table.remove(t, i)
        elseif is_all(p) then
          had = had or kept
          if kept then
            table.remove(t, i)
          end
        end
      end
      if had then
        local row, added = {}, 0
        for i, v in ipairs(values) do
          row[v] = i - 1
        end
        if kept then
          for i = 1, r[2] do
            local at = row[r[2 + i]]
            if at ~= nil then
              InsertFilterParam(t, TS.TENSION, at, 0)
              added = added + 1
            end
          end
        end
        if added == 0 and not (kept and r[2] == 0) then
          InsertFilterParam(t, TS.ALL, TS.TENSION, 0)
        end
      end
    end
    return game_after(...)
  end
end
