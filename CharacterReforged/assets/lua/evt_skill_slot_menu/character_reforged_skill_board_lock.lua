-- Character Reforged: the skill table (evt_skill_slot_menu) under the VR-Framework's skill board lock
-- (VRFW_SkillBoardLock: a mode's rule that no player's moves, aura or mix change). While a lock holds, the screen opens
-- in its read-only mode (param evt_ss_readonly, as the scout screen opens it: moves, move panel and plate shown, every
-- change refused with the «cannot» sound and the guide line) and the guide line is the lock's text. Wraps OnInit; no
-- engine call at load time.
CharacterReforged = type(CharacterReforged) == "table" and CharacterReforged or {}
if CharacterReforged.SkillTableLock == nil and type(rawget(_ENV, "OnInit")) == "function" then
  local Lock = {
    KEY_READONLY = 239878988,          -- evt_ss_readonly (the screen reads and clears it at OnInit)
    guide = nil,                       -- the screen's own read-only guide text id
  }
  CharacterReforged.SkillTableLock = Lock

  -- the screen's chunk local PL (CharacterReforged.SkillTable.L, graft skill_table_host), or nil
  local function screen_locals()
    local table_host = CharacterReforged.SkillTable
    local ok, pl = pcall(function() return table_host ~= nil and table_host.L ~= nil and table_host.L.PL or nil end)
    return ok and type(pl) == "table" and pl or nil
  end

  local previous = OnInit
  function OnInit(...)
    local locked, text = false, 0
    if type(VRFW_SkillBoardLock) == "table" then
      locked, text = VRFW_SkillBoardLock.Read()
    end
    local pl = screen_locals()
    if pl ~= nil then
      Lock.guide = Lock.guide or pl.RO_GUIDE
      pl.RO_GUIDE = (locked and text ~= 0) and text or Lock.guide
      if not locked and not VRFW_Param.Has(Lock.KEY_READONLY) then
        pl.readonly = false            -- no opener asked for read-only: not left on from a locked open in this VM
      end
    end
    if locked then
      VRFW_Param.Replace(Lock.KEY_READONLY, true, "plain")
    end
    return previous(...)
  end
end
