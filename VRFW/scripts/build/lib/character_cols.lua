-- Column names a character declaration may use (`cells`, `base`, `model_row`, `new_model.cells`): schemas/character/chara_param, chara_base, chara_model names,
-- `col_<n>` for any column index, and the `[[param_column]]` names mods declare (cols 57, 59, 60 of chara_param are free for mods).
-- Lists are 0-based in meaning (entry k + 1 names column k); a mismatch with the schema is a WARN.
local C = {}

C.PARAM = {
  "id", "chara", "element", "main_position", "sub_position", "build_type", "c6", "growth_pattern", "play_style", "rank",
  "ability_board", "skill_1", "skill_1_level", "skill_2", "skill_2_level", "skill_3", "skill_3_level", "skill_4",
  "skill_4_level", "skill_5", "skill_5_level", "skill_6", "skill_6_level", "alt_skill_1", "alt_skill_1_level",
  "alt_skill_2", "alt_skill_2_level", "alt_skill_3", "alt_skill_3_level", "mod_kick", "mod_control", "mod_technique",
  "mod_pressure", "mod_physical", "mod_agility", "mod_intelligence", "flag_36", "flag_37", "flag_38", "flag_39", "title",
  "special_rarity", "performance_genre", "stats_version", "growth_type", "stat_kick", "stat_control", "stat_technique",
  "stat_pressure", "stat_physical", "stat_intelligence", "stat_agility", "stat_speed", "stat_luck", "stat_freedom",
  "recruit_mode", "moment_kit", "col_57", "card_style", "col_59", "col_60", "own_passive_1",
  "own_passive_2", "own_passive_3", "own_passive_4", "own_passive_5", "offpitch_kit", "offpitch_with_kit",
}

C.BASE = {
  "id", "name", "serial_no", "name_text", "short_name_text", "upper_name_text", "model", "motion_override", "reserved_8",
  "voice_bank", "kind", "gender", "chara_class", "academic_year", "c14", "series", "team_1", "team_2", "team_3",
  "description_text", "age_group", "sort_order", "in_ie1", "in_ie2", "in_ie3", "in_go1", "in_go2", "in_go3", "in_ares",
  "in_orion", "in_victory_road", "flag_31", "flag_32", "reserved_33",
}

C.MODEL = {
  "id", "skeleton_path", "body_mesh_path", "motion_override", "body", "clothes", "shoes", "gloves", "parts_color", "c9",
  "head_mesh_path", "head_texture_path", "collar_open", "equipment_flag_2", "reserved_14", "c15", "skin_color", "color_17",
  "exmesh_1", "exmesh_2", "reserved_20", "reserved_21", "color_22", "flag_23", "flag_24", "flag_25", "color_26",
  "exmesh_3", "reserved_28", "flag_29", "flag_30", "chest_size", "c32", "force_kit", "custom_parts_path", "flag_35",
  "facial_motion",
}

-- Column index of `name` in `list` (0-based), or `col_<n>` (any index below 256); nil otherwise.
function C.index(list, name)
  for k, n in ipairs(list) do
    if n == name then return k - 1 end
  end
  local d = name:match("^col_%+?(%d+)$")
  if d then
    local n = tonumber(d)
    if n and n < 256 then return n end
  end
  return nil
end

-- Whether `name` is one of `list`'s names.
function C.has(list, name)
  for _, n in ipairs(list) do
    if n == name then return true end
  end
  return false
end

-- Check `list` against the schema of rows `row` of table `t`: every name that is not `col_<n>` must be that column
-- there. Returns the mismatches as text (nil when none).
function C.check(t, row, list)
  local bad = {}
  for k, n in ipairs(list) do
    if n:sub(1, 4) ~= "col_" then
      local ok, i = pcall(t.col, t, row, n)
      if not ok or i ~= k - 1 then bad[#bad + 1] = n .. " (" .. (k - 1) .. ")" end
    end
  end
  if #bad == 0 then return nil end
  return table.concat(bad, ", ")
end

return C
