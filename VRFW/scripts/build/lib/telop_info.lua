-- Builds skill_telop_info_config edits from the telop TOMLs: `margins` (per-language left/right of blank_size_info), `eldorado` (eldorado_id), `info` (target row).
-- The row is `info`, else the telopInfoId of move `technique` (default: the move keyed by the telop id); a row shared by several moves changes for all (WARN).
-- A missing row is added as a clone of the move's current row (else zeros). One row delta per mod in load order, applied by VRFW.telop.apply_rows.
-- input = { picks = { { lang, id, mod, origin, technique, margins = { left, right }, eldorado, info } } (key order),
--           order = { mod ids in load order }, framework, consts = { table, prefix, skill_prefix, ext } }

local M = {}

local function has_info(p)
  return p.margins ~= nil or p.eldorado ~= nil
end

-- row edits per mod in load order: { { mod, rows = { [row] = { margins = { [lang] = { l, r } }, eldorado, from } } } }
local function edits(picks, moves, order)
  local pos = {}
  for i, m in ipairs(order) do
    if pos[m] == nil then pos[m] = i end
  end
  local list, by_mod, warned = {}, {}, {}
  for _, p in ipairs(picks) do
    if has_info(p) then
      local id = p.id
      local tech = p.technique or id
      local current = nil
      if moves then current = moves.row_of[tech] end
      if current == 0 then current = nil end
      local row = nil
      if p.info ~= nil then
        row = p.info
      elseif current ~= nil then
        row = current
        local n = moves.users[current] or 1
        local wk = tech .. "\0" .. tostring(current)
        if n > 1 and not warned[wk] then
          warned[wk] = true
          VRFW.log.warn(string.format(
            "telop %s (%s): the telop row %s of move %s is shared by %d moves: its margins change for all of them (give `info` a new name and point the move at it: technique engine `cells = { telopInfoId = … }`)",
            id, p.origin, VRFW.hex(row), tech, n))
        end
      else
        local wk = tech .. "\0" .. "0"
        if not warned[wk] then
          warned[wk] = true
          VRFW.log.warn(string.format("telop %s (%s): `margins` / `eldorado` need a row: no move `%s` with a telop row (write `technique` or `info`): not applied", id, p.origin, tech))
        end
      end
      if row ~= nil then
        local m = by_mod[p.mod]
        if m == nil then
          m = { mod = p.mod, rows = {}, first = #list + 1 }
          by_mod[p.mod] = m
          list[#list + 1] = m
        end
        local e = m.rows[row]
        if e == nil then
          e = { margins = {} }
          m.rows[row] = e
        end
        if p.margins ~= nil then e.margins[p.lang] = p.margins end
        if p.eldorado ~= nil then e.eldorado = p.eldorado end
        if e.from == nil and current ~= nil and current ~= row then e.from = current end
      end
    end
  end
  local huge = math.huge
  table.sort(list, function(a, b)
    local pa, pb = pos[a.mod] or huge, pos[b.mod] or huge
    if pa ~= pb then return pa < pb end
    return a.first < b.first
  end)
  return list
end

-- The row delta of one mod (`exists` = the rows the table has).
local function rows_file(m, exists, table_id)
  local rows = {}
  for r in pairs(m.rows) do rows[#rows + 1] = r end
  table.sort(rows)
  local set, add = {}, {}
  for _, r in ipairs(rows) do
    local e = m.rows[r]
    local cells = {}
    if next(e.margins) ~= nil then
      local child = {}
      for l, v in pairs(e.margins) do
        child[l .. "_left"] = v[1]
        child[l .. "_right"] = v[2]
      end
      cells.blank_size_info = { set = { child } }
    end
    if e.eldorado ~= nil then cells.eldorado_id = e.eldorado end
    if exists[r] then
      set[#set + 1] = { key = r, cells = cells }
    else
      add[#add + 1] = { key = r, from = e.from, cells = cells }
    end
  end
  return { owner = m.mod, label = "mods/" .. m.mod .. "/telop (margins)", table = table_id, set = set, add = add }
end

function M.build(input)
  local C = input.consts
  local any = false
  for _, p in ipairs(input.picks) do
    if has_info(p) then any = true break end
  end
  if not any then return { serve = {} } end
  local skill_key, skill_err = VRFW.rows.key(C.skill_prefix, C.ext)
  local info_key, info_err = VRFW.rows.key(C.prefix, C.ext)
  local moves = nil
  if skill_key then
    local m, err = VRFW.telop.skill_rows(skill_key)
    if m then
      moves = m
    elseif err then
      VRFW.log.warn("skill_config: " .. err .. ": `technique` rows unknown")
    end
  else
    VRFW.log.warn(skill_err .. ": `technique` rows unknown")
  end
  local list = edits(input.picks, moves, input.order)
  if #list == 0 then return { serve = {} } end
  if info_key == nil then
    VRFW.log.error(info_err .. ": margins not applied")
    return { serve = {} }
  end
  local exists, err = VRFW.telop.row_ids(info_key)
  if exists == nil then
    if err then
      VRFW.log.error("skill_telop_info_config: " .. err .. ": margins not applied")
    else
      VRFW.log.error(info_key .. " not found: margins not applied")
    end
    return { serve = {} }
  end
  local files = {}
  local n = 0
  for _, m in ipairs(list) do
    files[#files + 1] = rows_file(m, exists, C.table)
    for _ in pairs(m.rows) do n = n + 1 end
  end
  local made = VRFW.telop.apply_rows(input.framework, files)
  for _, k in ipairs(made) do
    if k == info_key then
      VRFW.log.info(string.format("skill_telop_info_config: %d row(s) from the telop TOMLs", n))
      return { serve = { info_key } }
    end
  end
  return { serve = {} }
end

return M
