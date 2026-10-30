-- VRFW_Cmd: the engine command ids by name. VRFW_Cmd.SET_LAYER_VISIBLE is the id of CMND_SET_LAYER_VISIBLE: the
-- CRC-32 of the full command name, computed at its first use in this VM and kept. Any command name works (the game's,
-- the framework's CMND_VRFW_* / CMND_EVT_*, a mod's own). Definitions only: no engine call at load.
--   funcLuaMenuCommand(VRFW_Cmd.SET_LAYER_VISIBLE, layer, index, true)
-- The parameter store's four commands have no known name: VRFW_Cmd.PARAM_HAS / PARAM_GET / PARAM_SET / PARAM_DELETE
-- hold their ids (callers use VRFW_Param, 03_param.lua).
-- VRFW_Crc32(text) -> the CRC-32 of a text (0..4294967295), the hash of the game's names and keys.
-- Files that run before this one in a VM (the _all files of lua_early mods, the framework roots before menu, include
-- patches, whole screen scripts) use it inside functions only.
if VRFW_Crc32 == nil then
  local band, bxor, rshift = bit32.band, bit32.bxor, bit32.rshift
  local byte = string.byte

  function VRFW_Crc32(text)
    local crc = 0xFFFFFFFF
    for i = 1, #text do
      crc = bxor(crc, byte(text, i))
      for _ = 1, 8 do
        if band(crc, 1) ~= 0 then
          crc = bxor(rshift(crc, 1), 0xEDB88320)
        else
          crc = rshift(crc, 1)
        end
      end
    end
    return bxor(crc, 0xFFFFFFFF)
  end
end

if VRFW_Cmd == nil then
  local Crc32 = VRFW_Crc32

  VRFW_Cmd = setmetatable({}, {
    __index = function(ids, name)
      if type(name) ~= "string" then
        return nil
      end
      local id = Crc32("CMND_" .. name)
      rawset(ids, name, id)
      return id
    end,
  })
end

-- the parameter store: has (key), get (key), set (key, 0, value[, kind]), delete (key)
if rawget(VRFW_Cmd, "PARAM_HAS") == nil then
  rawset(VRFW_Cmd, "PARAM_HAS", 2947612279)
  rawset(VRFW_Cmd, "PARAM_GET", 3522198769)
  rawset(VRFW_Cmd, "PARAM_SET", 3860611758)
  rawset(VRFW_Cmd, "PARAM_DELETE", 3363400568)
end
