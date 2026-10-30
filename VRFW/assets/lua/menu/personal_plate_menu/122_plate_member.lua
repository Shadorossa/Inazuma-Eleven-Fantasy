-- plate member (VR-Framework base feature, docs/framework/player-pages.md «Plate member»): a screen that shows a team's
-- member on the player plate as a temporary character (players-universe mode, e.g. a line-up viewer) names him with the
-- game parameters VRFW.plate_team (team id) and VRFW.plate_slot (member slot) while its page is up, and clears them
-- after. Then:
-- * the plate's equipment rows show the items of that member's row of the team (CMND_VRFW_TEAM_MEMBER_GEAR: boots,
--   bracelet, pendant, special as the team build wrote them; the match equips the same items itself);
-- * VRFW_PlateMember.Kit() gives his team's kit (the page's 3D model wears it);
-- * a screen that shows a card (no team member) names it with VRFW.plate_card (chara_param id) while its page is up:
--   VRFW_PlateMember.Kit() then gives that card's own team kit, derived from the data by CMND_VRFW_CONTACT_KIT (the
--   contact map's kit: his chara_base's belong team, its kit of his era; else the first team listing him), so the page's
--   3D model wears it (the keeper shirt comes from the plate model's own position check); VRFW.plate_card_team (a
--   team_config id) names the team that dresses that card instead (its uniform first, e.g. a mod card's own team);
-- * the page shows his set as the match plays it (CMND_VRFW_TEAM_MEMBER_MOVES: his loadout's special moves and auras,
--   all available, never padlocked by a learn level): the move, learn table, learn level, board and skill set reads
--   of the plate answer from it; VRFW_PlateMember.SkillSet() gives its aura / mix for the pages that show them.
-- Without the parameters nothing changes. No engine call at load time.
VRFW_PlateMember = type(VRFW_PlateMember) == "table" and VRFW_PlateMember or {}
if VRFW_PlateMember.Gear == nil then
  local M = VRFW_PlateMember
  M.P_TEAM = 1930590710                 -- crc32 of VRFW.plate_team
  M.P_SLOT = 469565326                  -- crc32 of VRFW.plate_slot
  M.P_CARD = 2716223290                 -- crc32 of VRFW.plate_card
  M.P_CARD_TEAM = 1860450077            -- crc32 of VRFW.plate_card_team
  M.C = {
    GEAR = VRFW_Cmd.VRFW_TEAM_MEMBER_GEAR,                  -- CMND_VRFW_TEAM_MEMBER_GEAR(team, slot) -> found, kit, 4 items
    INV_OF_SLOT = 128658370,            -- (charaStHdl, equip slot) -> the inventory handle worn there
    ITEM_OF_INV = 2662166687,           -- (inventory handle, 0) -> its item id
    CARD_KIT = VRFW_Cmd.VRFW_CONTACT_KIT,              -- CMND_VRFW_CONTACT_KIT(card[, team]) -> { uniform, flags, source }
  }
  M.ITEM_SLOTS = 4                      -- equip slots 0-3 (boots, bracelet, pendant, special); 4 (costume) is not in a row

  local function Param(k)
    local v = VRFW_Param.Get(k)
    return type(v) == "number" and v or nil
  end

  -- the named member: team id, slot; nil = none
  function M.Member()
    local team, slot = Param(M.P_TEAM), Param(M.P_SLOT)
    if team == nil or slot == nil or team == 0 then
      return nil
    end
    return team, slot
  end

  -- the named member's team kit and his items (indexed by equip slot 0-3); nil = no member / unknown team
  function M.Gear()
    local team, slot = M.Member()
    if team == nil then
      return nil
    end
    local ok, found, kit, a, b, c, d = pcall(funcLuaCommand, M.C.GEAR, team, slot)
    if not (ok and found == true) then
      return nil
    end
    return kit, {[0] = a or 0, b or 0, c or 0, d or 0}
  end

  -- the kit of the named card's own team; nil = no card named / no kit in the data (the plate model's default)
  function M.CardKit()
    local card = Param(M.P_CARD)
    if card == nil or card == 0 then
      return nil
    end
    local ok, r = pcall(funcLuaCommand, M.C.CARD_KIT, card, Param(M.P_CARD_TEAM) or 0)
    if ok and type(r) == "table" and type(r.uniform) == "number" and r.uniform ~= 0 then
      return r.uniform
    end
    return nil
  end

  function M.Kit()
    local kit = M.Gear()
    if type(kit) == "number" and kit ~= 0 then
      return kit
    end
    return M.CardKit()
  end

  -- the retail row drawer (personal_plate_inc): while a member is named, its two equipment reads answer from his row
  -- (the temporary character wears nothing); every other call is the game's
  local function Wrap(name, make)
    local cur = _ENV[name]
    if type(cur) ~= "function" or M.wrapped == cur then
      return
    end
    M.wrapped = make(cur)
    _ENV[name] = M.wrapped
  end
  Wrap("SetupPersonalPlateEquipItem", function(orig)
    return function(i, hdl, ...)
      local kit, items = M.Gear()
      if items == nil then
        return orig(i, hdl, ...)
      end
      local tokens = {}
      local function slot_item(nxt, cmd, a, b, ...)
        if a == hdl and type(b) == "number" then
          local it = b >= 0 and b < M.ITEM_SLOTS and items[b] or 0
          if it == 0 then
            return 0
          end
          local token = -1000 - b
          tokens[token] = it
          return token
        end
        return nxt(cmd, a, b, ...)
      end
      local function token_item(nxt, cmd, a, b, ...)
        if tokens[a] ~= nil then
          return tokens[a]
        end
        return nxt(cmd, a, b, ...)
      end
      return (VRFW_Host.WithCommands({ [M.C.INV_OF_SLOT] = slot_item, [M.C.ITEM_OF_INV] = token_item }, orig, i, hdl,
        ...))
    end
  end)
end

if VRFW_PlateMember.SkillSet == nil then
  local M = VRFW_PlateMember
  M.MC = {
    MOVES = VRFW_Cmd.VRFW_TEAM_MEMBER_MOVES,                  -- CMND_VRFW_TEAM_MEMBER_MOVES(team, slot) -> found, 6 moves, 6 levels
    GET_SKILL = 903078840,              -- (charaStHdl, list position 0-5) -> move
    LEARNABLE = 3475351727,             -- (charaStHdl) -> ok, {move per slot}, {learn level per slot}
    LEARN_LEVEL = VRFW_Cmd.VRFW_CHARACTER_LEARN_LEVEL,              -- CMND_VRFW_CHARACTER_LEARN_LEVEL(charaStHdl, move) -> level needed, player's level
    BOARD_INV = 632801955,              -- (charaStHdl, board slot, kind) -> inventory handle
    SKILL_SET = VRFW_Cmd.VRFW_SKILL_SET,              -- CMND_VRFW_SKILL_SET(charaStHdl) -> answered, aura, mix, aura_from, mix_from, rows, techniques
    SKILL_INFO = VRFW_Cmd.GET_SOCCER_SKILL_INFO,            -- (move, 9) -> ok, category (8 = aura); (move, 13) -> ok, aura type
    LOG = VRFW_Cmd.EVT_LOG,                   -- CMND_EVT_LOG
  }
  M.MIX_TYPES = {[2] = true, [6] = true} -- aura types of the mix slot: Mix-Max, mode change
  M.set = nil                           -- {key, moves, aura, mix, aura_from, mix_from, rows, techniques}

  local function U32(v) return VRFW_Id.u32(v) end

  -- the named member's set ({moves[1..6], aura, mix, ...}); nil = no member, or he plays his card's own list
  function M.Set(call)
    local team, slot = M.Member()
    if team == nil then
      M.set = nil
      return nil
    end
    local key = tostring(team) .. ":" .. tostring(slot)
    if M.set ~= nil and M.set.key == key then
      return M.set.found and M.set or nil
    end
    local r = {pcall(call, M.MC.MOVES, team, slot)}
    local set = {key = key, found = r[1] == true and r[2] == true, moves = {}, rows = {}, techniques = {},
                 aura = 0, mix = 0, aura_from = -1, mix_from = -1}
    if set.found then
      for i = 1, 6 do
        local m = U32(r[2 + i])
        set.moves[i] = m
        local okc, known, category = pcall(call, M.MC.SKILL_INFO, m, 9)
        if m ~= 0 and okc and known and category == 8 then
          local okt, kt, kind = pcall(call, M.MC.SKILL_INFO, m, 13)
          if okt and kt and M.MIX_TYPES[kind] then
            if set.mix == 0 then set.mix, set.mix_from = m, i - 1 end
          elseif set.aura == 0 then
            set.aura, set.aura_from = m, i - 1
          end
        elseif m ~= 0 then
          set.rows[#set.rows + 1] = i - 1
          set.techniques[#set.techniques + 1] = m
        end
      end
    end
    M.set = set
    -- one line per member shown: what the page answers from
    pcall(call, M.MC.LOG, "VRFW plate member", string.format("team 0x%08X slot %s: %s", team % 4294967296, tostring(slot),
      set.found and string.format("team set applied: %d technique(s), aura 0x%08X, mix 0x%08X", #set.techniques, set.aura,
        set.mix) or ("card's own set kept (" .. tostring(r[3]) .. ")")))
    return set.found and set or nil
  end

  -- {aura, mix, aura_from, mix_from} of the named member's set; nil = none named
  function M.SkillSet()
    if type(funcLuaCommand) ~= "function" then
      return nil
    end
    local set = M.Set(funcLuaCommand)
    if set == nil then
      return nil
    end
    return {aura = set.aura, mix = set.mix, aura_from = set.aura_from, mix_from = set.mix_from}
  end

  -- while a member is named, the plate's set reads answer from his loadout (every other command is the game's)
  local answer = {
    [M.MC.GET_SKILL] = function(set, a, b)
      return set.moves[(tonumber(b) or -1) + 1] or 0
    end,
    [M.MC.LEARNABLE] = function()
      return false
    end,
    [M.MC.LEARN_LEVEL] = function(set, a, b, nxt)
      local ok, need, level = pcall(nxt, M.MC.LEARN_LEVEL, a, b)
      return 0, (ok and level) or 1
    end,
    [M.MC.BOARD_INV] = function()
      return 0
    end,
    [M.MC.SKILL_SET] = function(set)
      local rows, techniques = {}, {}
      for i = 1, 6 do
        rows[i] = set.rows[i] or -1
        techniques[i] = set.techniques[i] or 0
      end
      return true, set.aura, set.mix, set.aura_from, set.mix_from, rows[1], rows[2], rows[3], rows[4], rows[5], rows[6],
        techniques[1], techniques[2], techniques[3], techniques[4], techniques[5], techniques[6]
    end,
  }
  -- installed when the menu starts (OnInit: the engine's funcLuaCommand exists then), once per VM. M.Set's own
  -- reads (moves, move info, log) are not hooked here, so they go through the global.
  local function answer_member(nxt, cmd, a, b, ...)
    local ok, set = pcall(M.Set, funcLuaCommand)
    if ok and set ~= nil then
      return answer[cmd](set, a, b, nxt)
    end
    return nxt(cmd, a, b, ...)
  end
  function M.Install()
    if M.installed or type(funcLuaCommand) ~= "function" then
      return
    end
    local ids = {}
    for cmd in pairs(answer) do
      ids[#ids + 1] = cmd
    end
    M.installed = VRFW_Host.HookCommand(ids, answer_member, "VRFW.plate_member")
  end
  if VRFW_Host ~= nil then
    VRFW_Host.on("personal_plate_menu", "OnInit", {id = "vrfw.plate_member.install", phase = "before", create = true,
      fn = function()
        M.set = nil
        M.Install()
      end})
  end
end
