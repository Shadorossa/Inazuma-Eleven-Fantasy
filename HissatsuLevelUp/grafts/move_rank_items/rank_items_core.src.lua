  -- ---- the rules' side (shared by both views; the rules themselves are Hissatsu Level Up's script) ---------------------
  -- Item ids, caps and grades come from scripts\hissatsu_level_up.lua (CMND_HISSATSULEVELUP_RANK_ITEMS / _RANK_ITEM): the
  -- raise item (Libro de mejora de supertécnica: +1 level, up to the second-to-last) and the last-grade item (Cuaderno
  -- de evolución definitiva: second-to-last -> last, [ranks] last_grade_item_only). Without Hissatsu Level Up's script the
  -- commands do not answer: nothing is offered.
  HissatsuLevelUp = type(HissatsuLevelUp) == "table" and HissatsuLevelUp or {}
  HissatsuLevelUp.RankItems = type(HissatsuLevelUp.RankItems) == "table" and HissatsuLevelUp.RankItems or {}
  local RankItems = HissatsuLevelUp.RankItems
  RankItems.ITEMS = @crc:CMND_HISSATSULEVELUP_RANK_ITEMS@  -- () -> raise id, last id, use cap, last grade
  RankItems.ITEM = @crc:CMND_HISSATSULEVELUP_RANK_ITEM@    -- (hdl, move, item, apply) -> code, old, new
  RankItems.ITEM_NUM = 2011560392                        -- CMND_GET_ITEM_NUM (item, false) -> stock
  RankItems.DEL_ITEM = 425598937                         -- CMND_DELETE_ITEM (item, count)
  RankItems.ITEM_NAME = 1883585771                       -- (item, 0) -> the item's name (retail UpdateItemEquipLine)
  RankItems.SKILL_INFO = 2580586398                      -- CMND_GET_SOCCER_SKILL_INFO (skill, 16 = growth type)
  RankItems.TEXT_GET = 4074371074                        -- CMND_TEXT_GET (text id) -> string
  RankItems.LOG = 3661580131                             -- CMND_EVT_LOG -> loader.log
  RankItems.TX = {
    GUIDE = @crc:HissatsuLevelUp.RankItemGuide@, LEVEL = @crc:HissatsuLevelUp.RankItemLevel@,
    CONFIRM = @crc:HissatsuLevelUp.RankItemConfirm@, DONE = @crc:HissatsuLevelUp.RankItemDone@,
    NONE = @crc:HissatsuLevelUp.RankItemNone@, NEEDS_LAST = @crc:HissatsuLevelUp.RankItemNeedsLast@,
    MAX = @crc:HissatsuLevelUp.RankItemMax@, NO_GRADE = @crc:HissatsuLevelUp.RankItemNoGrade@,
    FAILED = @crc:HissatsuLevelUp.RankItemFailed@, PRESS_AGAIN = @crc:HissatsuLevelUp.RankItemPressAgain@,
    KEY = @crc:HissatsuLevelUp.RankItemUseKey@,
  }
  -- the refusal of each code of CMND_HISSATSULEVELUP_RANK_ITEM: its reason (log) and its text
  RankItems.REFUSALS = {
    [1] = {reason = "not_a_rank_item", text = "FAILED"},
    [2] = {reason = "no_grade", text = "NO_GRADE"},
    [3] = {reason = "already_max", text = "MAX"},
    [4] = {reason = "needs_second_to_last", text = "FAILED"},
    [5] = {reason = "not_in_set", text = "NO_GRADE"},
    [-1] = {reason = "bad_args", text = "FAILED"},
    [-2] = {reason = "hissatsu_level_up_off", text = "FAILED"},
  }

  function RankItems.Log(view, ...)
    local parts = {view}
    for k = 1, select("#", ...) do
      parts[#parts + 1] = tostring((select(k, ...)))
    end
    pcall(funcLuaCommand, RankItems.LOG, "HissatsuLevelUp rank_items", table.concat(parts, " "))
  end

  function RankItems.U32(v)
    if type(v) ~= "number" then
      return 0
    end
    if v < 0 then
      v = v + 4294967296
    end
    return v
  end

  function RankItems.Hex(v)
    v = RankItems.U32(v)
    return string.format("%04X%04X", math.floor(v / 65536) % 65536, math.floor(v % 65536))
  end

  function RankItems.Text(id)
    local ok, s = pcall(funcLuaCommand, RankItems.TEXT_GET, id)
    return (ok and type(s) == "string") and s or ""
  end

  -- {key} placeholders (plain replacement: names may hold % characters)
  function RankItems.Fill(s, values)
    return (string.gsub(s, "{(%w+)}", function(k)
      local v = values[k]
      if v == nil then
        return nil
      end
      return tostring(v)
    end))
  end

  -- raise item id, last-grade item id (0, 0 = Hissatsu Level Up's script does not answer)
  function RankItems.Ids()
    local ok, raise, last = pcall(funcLuaCommand, RankItems.ITEMS)
    if not ok or type(raise) ~= "number" or type(last) ~= "number" then
      return 0, 0
    end
    return RankItems.U32(raise), RankItems.U32(last)
  end

  function RankItems.Active()
    local raise, last = RankItems.Ids()
    return raise ~= 0 or last ~= 0
  end

  function RankItems.Num(id)
    if id == 0 then
      return 0
    end
    local ok, v = pcall(funcLuaCommand, RankItems.ITEM_NUM, id, false)
    return ok and (tonumber(v) or 0) or 0
  end

  -- how many rank items the player holds (both kinds)
  function RankItems.Owned()
    local raise, last = RankItems.Ids()
    return RankItems.Num(raise) + RankItems.Num(last)
  end

  function RankItems.ItemName(id)
    local ok, s = pcall(funcLuaCommand, RankItems.ITEM_NAME, id, 0)
    if ok and type(s) == "string" and s ~= "" then
      return s
    end
    return RankItems.Hex(id)
  end

  -- the grade as the game draws it: the move's evolution glyph (growth type = SKILL_INFO 16), else «Nv. grade + 1»
  function RankItems.Label(skill, grade)
    if grade > 0 and type(AppendEvoCodeToSkillName) == "function" then
      local okq, okv, growth = pcall(funcLuaCommand, RankItems.SKILL_INFO, skill, 16)
      if okq and okv and type(growth) == "number" then
        local ok, s = pcall(AppendEvoCodeToSkillName, "", grade, growth)
        if ok and type(s) == "string" and s ~= "" then
          return s
        end
      end
    end
    return RankItems.Fill(RankItems.Text(RankItems.TX.LEVEL), {n = grade + 1})
  end

  function RankItems.Check(chara, skill, item, apply)
    if item == 0 then
      return nil
    end
    local ok, code, old, new = pcall(funcLuaCommand, RankItems.ITEM, chara, skill, item, apply == true)
    if not ok or type(code) ~= "number" then
      return nil
    end
    return code, tonumber(old) or 0, tonumber(new) or 0
  end

  -- what using a rank item on (chara, skill) would do: plan = {chara, skill, item, code, old, new, values, refusal}
  -- (refusal = nil when it can be used: the item applies and the player holds one). values fill the texts: move, item,
  -- old, new, count; `move_name` = the move's name as the screen writes it.
  function RankItems.Plan(chara, skill, move_name)
    local raise, last = RankItems.Ids()
    local code, old, new = RankItems.Check(chara, skill, raise, false)
    local item = raise
    if code == 3 then                                    -- raise item capped: second-to-last or last grade
      local code2, old2, new2 = RankItems.Check(chara, skill, last, false)
      if code2 ~= nil then
        code, old, new, item = code2, old2, new2, last
      end
    end
    local plan = {chara = chara, skill = skill, item = item, code = code, old = old or 0, new = new or 0, last = last}
    plan.values = {move = move_name or "", old = RankItems.Label(skill, plan.old), new = RankItems.Label(skill, plan.new)}
    if code == nil then
      plan.refusal = {reason = "no_answer", text = "FAILED"}
    elseif code ~= 0 then
      plan.refusal = RankItems.REFUSALS[code] or {reason = "code_" .. tostring(code), text = "FAILED"}
    else
      plan.values.item = RankItems.ItemName(item)
      plan.values.count = RankItems.Num(item)
      if plan.values.count < 1 then
        plan.refusal = item == last and {reason = "no_manual", text = "NEEDS_LAST"} or {reason = "no_book", text = "NONE"}
      end
    end
    return plan
  end

  function RankItems.RefusalText(plan)
    return RankItems.Fill(RankItems.Text(RankItems.TX[plan.refusal.text] or RankItems.TX.FAILED), plan.values)
  end

  function RankItems.ConfirmText(plan)
    return RankItems.Fill(RankItems.Text(RankItems.TX.CONFIRM), plan.values)
  end

  -- one log line per refusal: view, reason, chara, move, item, code, grade
  function RankItems.LogRefused(view, plan)
    RankItems.Log(view, "refused", plan.refusal.reason, "chara", tostring(plan.chara), "move", RankItems.Hex(plan.skill),
      "item", RankItems.Hex(plan.item), "code", tostring(plan.code), "grade", tostring(plan.old), "->", tostring(plan.new))
  end

  -- use the planned item: the rules apply it (store + saved skill_list + live units), then one copy leaves the bag.
  -- true + the done text, or false (logged as refused)
  function RankItems.Use(view, plan)
    local code, old, new = RankItems.Check(plan.chara, plan.skill, plan.item, true)
    if code ~= 0 then
      plan.code = code
      plan.refusal = RankItems.REFUSALS[code or 0] or {reason = "apply_failed", text = "FAILED"}
      RankItems.LogRefused(view, plan)
      return false, RankItems.Text(RankItems.TX.FAILED)
    end
    local before = RankItems.Num(plan.item)
    funcLuaCommand(RankItems.DEL_ITEM, plan.item, 1)
    RankItems.Log(view, "used", RankItems.Hex(plan.item), "on", RankItems.Hex(plan.skill), "chara", tostring(plan.chara),
      "grade", tostring(old), "->", tostring(new), "stock", tostring(before), "->", tostring(RankItems.Num(plan.item)))
    plan.values.old, plan.values.new = RankItems.Label(plan.skill, old or 0), RankItems.Label(plan.skill, new or 0)
    return true, RankItems.Fill(RankItems.Text(RankItems.TX.DONE), plan.values)
  end
