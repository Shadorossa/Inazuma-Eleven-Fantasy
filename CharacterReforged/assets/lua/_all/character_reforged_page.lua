-- Character Reforged: the player page's SLOTS (docs/refactor/aura-mods-split.md «Player page»). The paged player page
-- (PERFIL, ATRIBUTOS, SUPERTÉCNICAS, the Hiper page, the retail pages, other mods' pages; research/grafts/plate_pages,
-- plate_model, plate_hiper_*: moved from Inazuma Fantasy on 2026-10-14) draws Character Reforged's own values; other
-- mods ADD values to it as data, an [[entry]] of one of the hosts of content\menus\player_page_host.toml whose action is
-- a command of theirs (action = { command = "CMND_..." }):
--
--   character_reforged.page_stat       (charaStHdl, idx 0..8) -> value (< 0 or not a number = no answer), ...
--                                      the stat a row / the radar shows (idx 8 = Suerte); without an answer: Character
--                                      Reforged's CMND_CHARACTERREFORGED_CHARA_STAT (the per-character stats, Suerte
--                                      derived from the curve)
--   character_reforged.page_luck_bonus (charaStHdl) -> a number added to Suerte's DEFAULT value (a training mod's
--                                      committed Suerte; not asked when a page_stat entry answered)
--   character_reforged.page_stat_max   (charaStHdl, idx) -> ok, value, base, bonus, delta, committed, min, max
--                                      the top of a stat's gauge on ATRIBUTOS = base + max (a training mod's limit);
--                                      without an answer: one scale for the 8 rows
--   character_reforged.page_stat_gain  (charaStHdl) -> ok, favouredMask, gain0 .. gain8 (stat idx order)
--                                      the stats a form adds (the ATRIBUTOS Normal / Miximax view, the Hiper page's
--                                      gains text); without an answer: no Miximax view
--   character_reforged.mode_change_partner (card) -> exists, partnerParam, partnerChara, partnerHdl
--                                      the partner of the card's equipped «Modo cambio» (the Hiper cards' and plates'
--                                      partner portrait and title); without an answer: no partner
--
-- The last declared entry is asked first (load order: a mod loaded later overrides), then the earlier ones, then the
-- default. Asked only at run time (never while a chunk loads); every call goes through pcall.
-- Also here: Page.SkillSetOn() (the option «Tabla de habilidades» on the new set: the Hiper page is the page of the new
-- set's aura / mix slots, shown only then), Page.MixOf(card) (the base's mix-slot store, scripts\mix_slots.lua) and
-- Page.Projection(card) (the new set's aura / mix of a card, the skill table's and the match's rule; a match team's
-- player: his member row's set, Page.MatchMemberSet).
-- For other mods' menu Lua: CharacterReforged.Page.Stat / LuckBonus / StatTop / GainsRaw / Providers / SkillSetOn /
-- MixOf / ModeChangePartner.
CharacterReforged = type(CharacterReforged) == "table" and CharacterReforged or {}
if CharacterReforged.Page == nil then
  local Page = {}
  CharacterReforged.Page = Page
  Page.HOST_STAT = "character_reforged.page_stat"
  Page.HOST_LUCK_BONUS = "character_reforged.page_luck_bonus"
  Page.HOST_STAT_MAX = "character_reforged.page_stat_max"
  Page.HOST_STAT_GAIN = "character_reforged.page_stat_gain"
  Page.HOST_MODE_CHANGE_PARTNER = "character_reforged.mode_change_partner"
  Page.CMD_CHARA_STAT = 1938088826         -- crc32("CMND_CHARACTERREFORGED_CHARA_STAT")
  Page.LUCK = 8                            -- stat idx of Suerte
  Page.CMD_MIX_GET = 358194355             -- crc32("CMND_CHARACTERREFORGED_MIX_GET")
  Page.CMD_OPTION_GET = 4082322029         -- crc32("CMND_VRFW_OPTION_GET")
  Page.SKILL_SET_OPTION = "character_reforged.skill_set_view"   -- options.toml row (0 Victory Road, 1 the new set)
  Page.providerCache = {}                  -- host -> the command ids of its entries, last declared first

  local function EngineReady()
    return type(rawget(_ENV, "funcLuaCommand")) == "function"
  end

  -- the command ids declared on a host, last declared first (read once per VM, at the first run-time use)
  function Page.Providers(host)
    local cached = Page.providerCache[host]
    if cached ~= nil then
      return cached
    end
    local list = {}
    if not EngineReady() then
      return list
    end
    local menu = rawget(_ENV, "VRFW_Menu")
    if type(menu) == "table" and type(menu.entries) == "function" then
      local ok, entries = pcall(menu.entries, host)
      if ok and type(entries) == "table" then
        for i = #entries, 1, -1 do
          local entry = entries[i]
          local id = entry.value_id
          if type(id) ~= "number" and type(entry.value) == "string" and type(rawget(_ENV, "CALC_CRC")) == "function" then
            id = CALC_CRC(entry.value)
          end
          if entry.kind == "command" and type(id) == "number" and id ~= 0 then
            list[#list + 1] = id
          end
        end
      end
    end
    Page.providerCache[host] = list
    return list
  end

  -- the value of stat idx (0..8) of a chara status handle: the mods' answer, else Character Reforged's; nil = none
  function Page.Stat(hdl, idx)
    if not EngineReady() then
      return nil
    end
    for _, id in ipairs(Page.Providers(Page.HOST_STAT)) do
      local ok, value = pcall(funcLuaCommand, id, hdl, idx)
      if ok and type(value) == "number" and value >= 0 then
        return value
      end
    end
    local ok, value = pcall(funcLuaCommand, Page.CMD_CHARA_STAT, hdl, idx)
    if ok and type(value) == "number" and value >= 0 then
      if idx == Page.LUCK then
        value = value + Page.LuckBonus(hdl)
      end
      return value
    end
    return nil
  end

  -- the sum of the page_luck_bonus answers for a chara status handle (0 = none)
  function Page.LuckBonus(hdl)
    local sum = 0
    if not EngineReady() then
      return sum
    end
    for _, id in ipairs(Page.Providers(Page.HOST_LUCK_BONUS)) do
      local ok, bonus = pcall(funcLuaCommand, id, hdl)
      if ok and type(bonus) == "number" then
        sum = sum + bonus
      end
    end
    return sum
  end

  -- the top of stat idx's gauge (base + max of a training mod's answer); nil = no mod answers
  function Page.StatTop(hdl, idx)
    if not EngineReady() then
      return nil
    end
    for _, id in ipairs(Page.Providers(Page.HOST_STAT_MAX)) do
      local ok, answered, _, base, _, _, _, _, max = pcall(funcLuaCommand, id, hdl, idx)
      if ok and answered == true and type(base) == "number" and type(max) == "number" and base + max > 0 then
        return base + max
      end
    end
    return nil
  end

  -- the stat gains of a chara status handle's form, as the packed pcall of the answering command:
  -- {true, ok, favouredMask, gain0, ..., gain8}; {false} = no mod answers
  function Page.GainsRaw(hdl)
    if not EngineReady() then
      return {false}
    end
    for _, id in ipairs(Page.Providers(Page.HOST_STAT_GAIN)) do
      local result = {pcall(funcLuaCommand, id, hdl)}
      if result[1] and result[2] and type(result[4]) == "number" then
        return result
      end
    end
    return {false}
  end

  -- true while the option «Tabla de habilidades» shows the new set (6 moves + aura slot + mix slot)
  function Page.SkillSetOn()
    if not EngineReady() then
      return false
    end
    local ok, value = pcall(funcLuaCommand, Page.CMD_OPTION_GET, Page.SKILL_SET_OPTION)
    return ok and (value == 1 or value == true)
  end

  -- THE projection of a saved card while the option shows the new set (scripts\mix_slots.lua
  -- CMND_CHARACTERREFORGED_PROJECT_SKILL_SET, the rule the skill table and the match use): { aura, mix, aura_from,
  -- mix_from }; a team member the player page previews or a team editor's temporary player: the set the match plays
  -- for him (VRFW_PlateMember.SkillSet); nil = the option
  -- on Victory Road, no answer (Character Reforged's scripts off) or no such card. Every
  -- place that shows a player's aura / mix (the Hiper page, the page's form badge, the 3D model's forms) reads this.
  Page.CMD_PROJECT = 2177163225            -- crc32("CMND_CHARACTERREFORGED_PROJECT_SKILL_SET")
  Page.projectionCache = {}                -- card -> {at, value}: one command per card per PROJECTION_CACHE_S
  Page.PROJECTION_CACHE_S = 0.25
  local function Clock()
    if type(os) == "table" and type(os.clock) == "function" then
      local ok, t = pcall(os.clock)
      if ok and type(t) == "number" then
        return t
      end
    end
    return nil
  end
  local function U32(v)
    return VRFW_Id.u32(v)
  end
  -- a player of a match team (the player page in a match, e.g. the pause «Formación»): his team member row's set as
  -- the match plays it (VR-Framework CMND_VRFW_MATCH_MEMBER -> team, slot; CMND_VRFW_TEAM_MEMBER_MOVES -> his loadout):
  -- the first keshin / totem / armour of it in the aura slot, the first Mix-Max / «Modo cambio» in the mix slot;
  -- nil = no match, the user's own player, or a row that plays his card's own learn list
  Page.CMD_MATCH_MEMBER = 992494052        -- crc32("CMND_VRFW_MATCH_MEMBER")
  Page.CMD_MEMBER_MOVES = 319507648        -- crc32("CMND_VRFW_TEAM_MEMBER_MOVES")
  Page.CMD_SKILL_INFO = 2580586398         -- (move, 9) -> ok, category (8 = aura); (move, 13) -> ok, aura type
  Page.MIX_AURA_TYPES = {[2] = true, [6] = true}   -- Mix-Max, «Modo cambio»
  function Page.MatchMemberSet(card)
    local ok, found, team, slot = pcall(funcLuaCommand, Page.CMD_MATCH_MEMBER, card)
    if not (ok and found == true and type(team) == "number" and type(slot) == "number") then
      return nil
    end
    local r = {pcall(funcLuaCommand, Page.CMD_MEMBER_MOVES, team, slot)}
    if not (r[1] == true and r[2] == true) then
      return nil
    end
    -- techniques / rows: the non-aura moves in loadout order and their loadout positions (the move rows' set)
    local value = {aura = 0, mix = 0, aura_from = -1, mix_from = -1, techniques = {}, rows = {}}
    for i = 1, 6 do
      local m = U32(r[2 + i])
      local okc, known, category = pcall(funcLuaCommand, Page.CMD_SKILL_INFO, m, 9)
      if m ~= 0 and okc and known and category == 8 then
        local okt, kt, kind = pcall(funcLuaCommand, Page.CMD_SKILL_INFO, m, 13)
        if okt and kt and Page.MIX_AURA_TYPES[kind] then
          if value.mix == 0 then value.mix, value.mix_from = m, i - 1 end
        elseif value.aura == 0 then
          value.aura, value.aura_from = m, i - 1
        end
      elseif m ~= 0 then
        value.techniques[#value.techniques + 1] = m
        value.rows[#value.rows + 1] = i - 1
      end
    end
    return value
  end

  function Page.Projection(card)
    if not EngineReady() or type(card) ~= "number" or card == 0 or not Page.SkillSetOn() then
      return nil
    end
    -- a team member previewed on the player page, or a team editor's temporary player (a career club's, a league
    -- team's; the VR-Framework's plate member): his set as the match plays it
    if type(VRFW_PlateMember) == "table" and type(VRFW_PlateMember.SkillSet) == "function" then
      local okm, member = pcall(VRFW_PlateMember.SkillSet, card)
      if okm and type(member) == "table" then
        return member
      end
    end
    local now = Clock()
    local hit = Page.projectionCache[card]
    if hit ~= nil and now ~= nil and now - hit.at < Page.PROJECTION_CACHE_S then
      return hit.value
    end
    local value = Page.MatchMemberSet(card)
    local ok, aura, mix, auraFrom, mixFrom = false, nil, nil, nil, nil
    if value == nil then
      ok, aura, mix, auraFrom, mixFrom = pcall(funcLuaCommand, Page.CMD_PROJECT, card)
    end
    if ok and type(aura) == "number" then
      value = {aura = U32(aura), mix = U32(mix), aura_from = tonumber(auraFrom) or -1, mix_from = tonumber(mixFrom) or -1}
    end
    if now ~= nil then
      Page.projectionCache[card] = {at = now, value = value}
    end
    return value
  end

  -- the partner of a card's equipped «Modo cambio»: the first mode_change_partner entry that answers
  -- (exists, partnerParam, partnerChara); nil = none answers
  function Page.ModeChangePartner(card)
    if not EngineReady() or type(card) ~= "number" or card == 0 then
      return nil
    end
    for _, id in ipairs(Page.Providers(Page.HOST_MODE_CHANGE_PARTNER)) do
      local ok, exists, partnerParam, partnerChara = pcall(funcLuaCommand, id, card)
      if ok and exists == true and type(partnerParam) == "number" and partnerParam ~= 0 then
        return partnerParam, partnerChara
      end
    end
    return nil
  end

  -- the mix-slot move of a saved card (Character Reforged's store); 0 = empty / no answer
  function Page.MixOf(card)
    if not EngineReady() or card == nil or card == 0 then
      return 0
    end
    local ok, move = pcall(funcLuaCommand, Page.CMD_MIX_GET, card)
    return (ok and type(move) == "number") and move or 0
  end
end
