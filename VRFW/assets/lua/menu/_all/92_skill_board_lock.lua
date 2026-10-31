-- menu_engine: the skill board lock, VRFW_SkillBoardLock. While a mod's [[VRFW.SkillBoardLock]] holds
-- (content\skill_board_lock\*.toml, answered by scripts\skill_board_lock.lua through CMND_VRFW_SKILL_BOARD_LOCK) no
-- player's moves, auras or mix can be changed; the screens that change them stay view only. Definitions only (this file
-- runs in every script VM, lua\_all): no engine call at load time.
--   VRFW_SkillBoardLock.Read()    -> locked, text id: asks the lock once (a screen calls it at its OnInit) and keeps the
--                                    answer in this VM (a dock-only lock counts only while a team editor dock is open)
--   VRFW_SkillBoardLock.Locked()  -> locked, text id of the last Read in this VM (no engine call)
--   VRFW_SkillBoardLock.Refuse()  plays the «cannot» sound
--   VRFW_SkillBoardLock.GuardList(spec) -> a list screen (called from its patch file at load) whose Accept equips the
--     focused row: while locked Accept / a row click on spec.list_layer is refused, every row of spec.item_layer is
--     greyed (the screen's own SetupGrayout) and the Accept guide entry (text spec.enter_text) shows the lock's text.
--     The wrappers go on at the screen's first OnInit, over every other patch of the screen.
if VRFW_SkillBoardLock == nil then
  local K = {
    LOCK = VRFW_Cmd.VRFW_SKILL_BOARD_LOCK,   -- CMND_VRFW_SKILL_BOARD_LOCK () -> locked, text id, dock only
    LOG = VRFW_Cmd.EVT_LOG,                   -- CMND_EVT_LOG
    SOUND = 1917805374,                       -- play a system sound effect
    SE_NO = 2086672038,                       -- sy0003 (the retail «cannot» sound)
    GUIDE_COLUMNS = 2209673388,               -- (menu, guide, texts, glyphs, offsets, ...) of the bottom button guide
    GREY = 0.5,                               -- the retail «not available» row factor
  }
  local Lock = { locked = false, text = 0 }
  VRFW_SkillBoardLock = Lock

  function Lock.Read()
    local ok, locked, text, dock_only = pcall(funcLuaCommand, K.LOCK)
    locked = ok and locked == true
    if locked and dock_only == true then
      local okf, foreign = pcall(function() return VRFW_TeamEditor ~= nil and VRFW_TeamEditor.Foreign() end)
      locked = okf and foreign ~= nil and foreign ~= false
    end
    local was = Lock.locked
    Lock.locked, Lock.text = locked, locked and (tonumber(text) or 0) or 0
    if locked ~= was then
      pcall(funcLuaCommand, K.LOG, "VRFW skill board lock", locked and "on" or "off")
    end
    return Lock.locked, Lock.text
  end

  function Lock.Locked()
    return Lock.locked, Lock.text
  end

  function Lock.Refuse()
    pcall(funcLuaCommand, K.SOUND, K.SE_NO)
  end

  -- the guide call with the Accept entry's text replaced by the lock's text
  local function lock_guide_text(enter_text)
    return function(nxt, cmd, menu, guide, texts, ...)
      if Lock.locked and Lock.text ~= 0 and type(texts) == "table" then
        local copy = {}
        for i, t in ipairs(texts) do
          copy[i] = t == enter_text and Lock.text or t
        end
        texts = copy
      end
      return nxt(cmd, menu, guide, texts, ...)
    end
  end

  function Lock.GuardList(spec)
    spec = type(spec) == "table" and spec or {}
    local mine = {}
    local function wrap(name, make)
      local cur = _ENV[name]
      if type(cur) ~= "function" or cur == mine[name] then
        return
      end
      mine[name] = make(cur)
      _ENV[name] = mine[name]
    end
    local function on_list(a1)
      return Lock.locked and (a1 == spec.list_layer or a1 == spec.item_layer)
    end
    local function wrap_all()
      wrap("OnEnter", function(previous)
        return function(a1, ...)
          if on_list(a1) then
            Lock.Refuse()
            return
          end
          return previous(a1, ...)
        end
      end)
      wrap("OnDecideFocus", function(previous)
        return function(a1, ...)
          if on_list(a1) then
            Lock.Refuse()
            return
          end
          return previous(a1, ...)
        end
      end)
      wrap("UpdateListItem", function(previous)
        return function(a1, a2, ...)
          local r = table.pack(previous(a1, a2, ...))
          if Lock.locked and a1 == spec.item_layer and type(SetupGrayout) == "function" then
            pcall(SetupGrayout, a1, a2, K.GREY)
          end
          return table.unpack(r, 1, r.n)
        end
      end)
      if spec.enter_text ~= nil and type(VRFW_Host) == "table" and type(VRFW_Host.WithCommands) == "function" then
        local guide_text = lock_guide_text(spec.enter_text)
        wrap("UpdateButtonGuide", function(previous)
          return function(...)
            if not Lock.locked then
              return previous(...)
            end
            return VRFW_Host.WithCommands({ menu = { [K.GUIDE_COLUMNS] = guide_text } }, previous, ...)
          end
        end)
      end
    end
    local previous_init = _ENV.OnInit
    if type(previous_init) ~= "function" then
      return false
    end
    _ENV.OnInit = function(...)
      Lock.Read()
      wrap_all()
      return previous_init(...)
    end
    return true
  end
end
