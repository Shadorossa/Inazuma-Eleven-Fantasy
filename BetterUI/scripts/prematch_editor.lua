-- BetterUI's pre-kick-off editor decision: the handler of the mid hook PrematchEditor
-- (content\game\prematch_editor.toml). Until 1.16.3 clean_hud.dll decided the same, with the same log lines.
-- At load: the handler registration and the config read below.

local EDITOR_FLAG = 0x2000000      -- match info flags: the retail pre-kick-off editor opens
local skips = 0

-- config.toml skip_prematch_editor (developer kill switch; default true), read once at script load: the mod's config
-- is loaded from disk by its first read, which made the first kick-off's hook take 43.7 ms on the game thread
-- (2026-10-13 loader.log); the config does not change while the game runs.
local ENABLED = true
do
  local ok, v = pcall(VRFW.files.config, "skip_prematch_editor")
  ENABLED = not (ok and v == false)
end
local function enabled()
  return ENABLED
end

-- mi = the match info (rax at the site). true = skip the editor (the retail bit-off path), false = the retail editor.
-- Skipped only in a readable, offline, non-observer match with the editor flag set; anything unreadable keeps it.
function BetterUI.SkipEditor(mi)
  local ok, info = pcall(VRFW.mem.struct, "MatchInfo", mi)
  if not ok then
    return false
  end
  local okf, flags = pcall(function() return info.flags end)
  if not okf or bit32.band(flags, EDITOR_FLAG) == 0 then
    return false
  end
  local oko, observer = pcall(function() return info.observer end)
  local okn, net = pcall(VRFW.call, "IsNetworkSession")
  local okt, ty = pcall(function() return info.match_type end)
  ty = okt and ty or 255
  if oko and observer == 0 and okn and net == false then
    skips = skips + 1
    VRFW.log(string.format("prematch: pre-kick-off team editor skipped (offline, match type %d) -> walk-in [%d]", ty, skips))
    return true
  end
  VRFW.log(string.format("prematch: pre-kick-off team editor kept (network %s, observer %s, match type %d)",
    okn and tostring(net) or "?", oko and tostring(observer) or "?", ty))
  return false
end

-- BattleSettingFlow state 6, before its `test dword [rax], 2000000h`: skip = resume at the je target (continue_at).
VRFW.on("hook:PrematchEditor", function(ev)
  if not enabled() then
    return nil
  end
  if BetterUI.SkipEditor(ev.regs.rax) then
    return { skip = true }
  end
  return nil
end)
