-- Character Reforged › a character's engine objects for the per-character stats (scripts\stats.lua): the status object
-- FindCharaRecord 0xD7F3E0 gives (container [[g_gameRoot]+0x69D8] + 8 + kind * 8), its save record (+0x08: param id +4,
-- prm_growth[0..7] +0x24), its param block (+0x10: 5 stat arrays at +0x10 / +0x30 / +0x50 / +0x70 / +0x90, i32 per
-- stat) and the effective level (HumanChara_GetLevel 0xD85710, as HumanChara_RefreshStatus passes it). The same reads as
-- Inazuma Fantasy's lib\chara_view.lua (the stats moved here on 2026-10-14). Error codes: -1 bad args, -2 not ready,
-- -4 exception, -5 no record. Needs content\game\chara_records.toml (CharacterReforged.FindCharaRecord,
-- CharacterReforged.HumanGetLevel, character_reforged_chara_containers).

local M = {}

M.ERR_BAD_ARGS, M.ERR_NOT_READY, M.ERR_EXCEPTION, M.ERR_NO_RECORD = -1, -2, -4, -5

local OBJ_RECORD, OBJ_PARAMS, REC_PARAM_ID, REC_PRM_GROWTH = 0x08, 0x10, 0x04, 0x24
local PARAM_ARRAYS = { 0x10, 0x30, 0x50, 0x70, 0x90 }

local HBUF, FBUF

local function rd(ty, addr)
  local ok, v = pcall(VRFW.mem.read, ty, addr)
  if ok then return v end
  return nil
end

local function bufs()
  if not HBUF then
    HBUF = VRFW.mem.buffer("character_reforged_stats_hdl", 8)
    FBUF = VRFW.mem.buffer("character_reforged_stats_flag", 8)
  end
end

function M.ready()
  return VRFW.is_on("CharacterReforged.FindCharaRecord") and VRFW.is_on("CharacterReforged.HumanGetLevel")
    and VRFW.is_on("character_reforged_chara_containers")
end

-- the status object of a character handle checked against its record, or nil + error code
function M.object(hdl)
  local kind = math.floor(hdl / 4096) % 16
  if hdl == 0 or kind >= 0xD then return nil, M.ERR_BAD_ARGS end
  local conts = VRFW.game.character_reforged_chara_containers()
  if not conts then return nil, M.ERR_NOT_READY end
  local cont = rd("ptr", conts + 8 + kind * 8)
  if not cont or cont == 0 then return nil, M.ERR_NOT_READY end
  bufs()
  VRFW.mem.write("u32", HBUF, hdl)
  local ok, obj = pcall(VRFW.call, "CharacterReforged.FindCharaRecord", cont, HBUF)
  if not ok then
    VRFW.error(string.format("stats: FindCharaRecord(0x%08X) raised: %s", hdl, tostring(obj)))
    return nil, M.ERR_EXCEPTION
  end
  if not obj or obj < 0x10000 then return nil, M.ERR_NO_RECORD end
  local rec = rd("ptr", obj + OBJ_RECORD)
  if not rec or rd("u32", rec) ~= hdl then return nil, M.ERR_NO_RECORD end
  return obj
end

-- the card (chara_param id) of a status object's record, or nil
function M.param_id(obj)
  local rec = rd("ptr", obj + OBJ_RECORD)
  return rec and rd("i32", rec + REC_PARAM_ID)
end

-- the record of a status object, or nil
function M.record(obj)
  return rd("ptr", obj + OBJ_RECORD)
end

-- the param block of a status object, or nil
function M.params(obj)
  return rd("ptr", obj + OBJ_PARAMS)
end

-- prm_growth[idx] of a save record (the trained points the menus add), or nil
function M.growth_of(rec, idx)
  return rd("i32", rec + REC_PRM_GROWTH + idx * 4)
end

-- the effective level of a status object, or nil + error code
function M.level(obj)
  bufs()
  local ok, v = pcall(VRFW.call, "CharacterReforged.HumanGetLevel", obj, FBUF)
  if not ok then
    VRFW.error(string.format("stats: GetLevel(0x%X) raised: %s", obj, tostring(v)))
    return nil, M.ERR_EXCEPTION
  end
  return v % 65536
end

-- engine stat idx (0..7) of a param block: the base array (+0x10) and the sum of the 5 arrays (i32 wrapping)
function M.param_stat(params, idx)
  local b = rd("i32", params + PARAM_ARRAYS[1] + idx * 4)
  if b == nil then return nil end
  local sum = 0
  for _, a in ipairs(PARAM_ARRAYS) do
    local v = rd("i32", params + a + idx * 4)
    if v == nil then return nil end
    sum = sum + v
  end
  sum = sum % 4294967296
  if sum >= 2147483648 then sum = sum - 4294967296 end
  return b, sum
end

return M
