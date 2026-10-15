-- audio_engine: row «Pack de voces» / "Voice pack" of Opciones › «Opciones de mods» (setting_menu). Owned by the audio_engine mod; the tab and the row
-- framework (VRFW_SET / VRFW_OPT) belong to the mod_options mod (VR-Framework), which is the only copy of it.
--
-- * The ROW is declared in mods\audio_engine\options.toml (type lua, SETTING_INFO id crc32("evt_set_voice_lang"),
--   label / help crc32("audio_engine.voice_pack" / "…_help")); mod_options builds it at boot from the player's own
--   files and serves it. Texts (9 languages, English fallback): mods\audio_engine\text.toml, merged by text_engine
--   when it is active, else served by mod_options.
-- * VALUES: Ninguno (0) or one of the installed voice-pack languages (1..): CMND_VRFW_SOUND_VOICE_GET / _NAME / _SET
--   of the framework's sound type (VR-Framework owns the voice packs); with an older ModLoader that keeps them, its CMND_EVT_VOICE_GET / _NAME / _SET (`mods` module) answer
--   instead. The retail «Idioma de voz» row (日本語 / English) is untouched and decides the language of what a pack
--   does not dub. Left / right / A change a draft; the retail «¿Aplicar los
--   cambios?» window stores it on «Sí» and drops it on «No» (mod_options' framework).
-- * This file only gives the row's behaviour: an item of the setting_menu host's list "option_rows" (VRFW_Host.add), which mod_options registers at the menu's first callback, whatever the load order.
--   Without VRFW_Host: VRFW_OPT_Register, or VRFW_OPT_QUEUE before mod_options' Lua. Nothing calls the engine while the
--   chunk loads.

AE_VP_KEY = "audio_engine.voice_pack"  -- row key of options.toml
AE_VP_NONE_ID = 581565135              -- crc32("audio_engine.voice_pack_none"): value 0
AE_VP_OFF_ID = 2052939705              -- crc32("audio_engine.voice_pack_off"): the loader does not answer
AE_VP_COUNT = 1                        -- 1 + installed voice-pack languages (refreshed by get)
-- {framework name, ModLoader name} of each command (crc32 of the names)
AE_VP_GET = {1076213018 --[[CMND_VRFW_SOUND_VOICE_GET]], 2325395018 --[[CMND_EVT_VOICE_GET]]}
AE_VP_NAME = {3365390355 --[[CMND_VRFW_SOUND_VOICE_NAME]], 2738235108 --[[CMND_EVT_VOICE_NAME]]}
AE_VP_SET = {1527430838 --[[CMND_VRFW_SOUND_VOICE_SET]], 2444606950 --[[CMND_EVT_VOICE_SET]]}
AE_VP_SRC = nil                        -- 1 = the framework answers, 2 = the ModLoader (decided by the first get)
function AE_VP_Call(cmd, ...)          -- a command; nil when it is not there
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end
function AE_VP_Cmd(pair, ...)          -- the framework's command, else the ModLoader's
  if AE_VP_SRC ~= nil then
    return AE_VP_Call(pair[AE_VP_SRC], ...)
  end
  return AE_VP_Call(pair[1], ...)
end
function AE_VP_Text(id, fallback)      -- a menu_text row in the game's language, else the English fallback
  local ok, s = pcall(funcLuaCommand, 4074371074 --[[CMND_TEXT_GET]], id)
  if ok and type(s) == "string" and s ~= "" then
    return s
  end
  return fallback
end
AE_VP_ROW = {
  get = function()                     -- stored index, nil = loader / module off
    local i, n = AE_VP_Call(AE_VP_GET[1])
    AE_VP_SRC = 1
    if type(i) ~= "number" or type(n) ~= "number" then
      i, n = AE_VP_Call(AE_VP_GET[2])
      AE_VP_SRC = 2
    end
    if type(i) ~= "number" or type(n) ~= "number" then
      AE_VP_SRC = nil
      return nil
    end
    AE_VP_COUNT = n
    if i < 0 or i >= n then
      return 0
    end
    return i
  end,
  step = function(v, dir)
    local n = AE_VP_COUNT or 1
    if n < 1 then
      n = 1
    end
    return (v + dir + n) % n
  end,
  fmt = function(v)
    if v == 0 then
      return AE_VP_Text(AE_VP_NONE_ID, "None")
    end
    local name, code = AE_VP_Cmd(AE_VP_NAME, v)
    if type(name) == "string" and name ~= "" then
      return name
    end
    if type(code) == "string" and code ~= "" then
      return code
    end
    return "?"
  end,
  set = function(v)
    return AE_VP_Cmd(AE_VP_SET, v) == true
  end,
  off = function()
    return AE_VP_Text(AE_VP_OFF_ID, "Needs the VR ModLoader")
  end
}
if VRFW_Host ~= nil then              -- the setting_menu host's list of rows
  VRFW_Host.add("setting_menu", "option_rows", {id = AE_VP_KEY, value = AE_VP_ROW})
elseif VRFW_OPT_Register ~= nil then
  VRFW_OPT_Register(AE_VP_KEY, AE_VP_ROW)
else
  VRFW_OPT_QUEUE = VRFW_OPT_QUEUE or {}
  VRFW_OPT_QUEUE[#VRFW_OPT_QUEUE + 1] = {key = AE_VP_KEY, row = AE_VP_ROW}
end
