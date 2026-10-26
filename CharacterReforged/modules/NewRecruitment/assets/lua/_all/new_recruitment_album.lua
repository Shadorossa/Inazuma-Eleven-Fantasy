-- New Recruitment › where players are recruited (option «Fichajes», options.toml row new_recruitment.recruit_source):
-- 0 «Pachangas» (the default: the pachanga zones of the Chronicle board, assets\lua\vs_route_town_menu\
-- new_recruitment_pachangas.lua), 1 «Álbum» (BetterQoL's «Álbum de jugadores»: A on a player the club does not have
-- asks «¿Quieres fichar a X?» and he joins on «Sí»), 2 «Ambos». Read live (no restart).
-- * NewRecruitment.RecruitSource() -> 0 / 1 / 2;  NewRecruitment.RecruitFrom(where) -> "pachangas" / "album" allowed.
-- * NewRecruitment.Ask(s) / Notice(s) / Say(id, name): the game's question / notice window (Sí / No, «%s» = the name),
--   used inside a coroutine (they yield until the window is answered and closed); the pachangas' join scene uses them.
-- * The album action: one entry of BetterQoL.AlbumActions (BetterQoL's export, docs/game/ui/album.md §5): offered while
--   the option allows the album and NewRecruitment.Applies() (not a reserved slot); the signing is the VR-Framework's
--   recruit service (VRFW_Recruit.Recruit: one card per character, a free bank slot, the game's add path, autosave) at
--   the level of the team in use. Every album row has a normal card (BetterQoL's roster keeps only those), so every
--   player the club does not have can be signed.
-- Definitions only; no engine call at load time.
NewRecruitment = NewRecruitment or {}

if NewRecruitment.RecruitSource == nil then
  local A = {
    OPTION_GET = 4082322029,                 -- CMND_VRFW_OPTION_GET (row key) -> value
    OPTION_KEY = "new_recruitment.recruit_source",
    DEFAULT = 0,                             -- options.toml default: pachangas
    FROM = {pachangas = {[0] = true, [2] = true}, album = {[1] = true, [2] = true}},
    TEXT = 4074371074,                       -- CMND_TEXT_GET
    LOG = 3661580131,
    MSG_OPEN = 2289627655, MSG_KIND = 2351835063, MSG_RESULT = 1523741473, MSG_DONE = 682363669, MSG_BUSY = 898725220,
    -- text\rows\album_text.toml (menu_text rows) and the pachangas' «%s joined» line
    GUIDE = 2414122637 --[[new_recruitment_album_guide]], ASK = 1868475591 --[[new_recruitment_album_ask]],
    OWNED = 2127430293 --[[new_recruitment_album_owned]], FULL = 1165105549 --[[new_recruitment_album_full]],
    FAILED = 1534386840 --[[new_recruitment_album_failed]], DONE = 290976732 --[[new_recruitment_pachangas_join_done]],
  }
  NewRecruitment.Album = A

  local function call(cmd, ...)
    local r = table.pack(pcall(funcLuaCommand, cmd, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end

  function NewRecruitment.RecruitSource()
    if type(funcLuaCommand) ~= "function" then return A.DEFAULT end
    local value, held = call(A.OPTION_GET, A.OPTION_KEY)
    if value == false then value = held end
    return (type(value) == "number" and (value == 0 or value == 1 or value == 2)) and value or A.DEFAULT
  end

  function NewRecruitment.RecruitFrom(where)
    local set = A.FROM[where]
    return set ~= nil and set[NewRecruitment.RecruitSource()] == true
  end

  -- a Sí / No question (the game's question window); true = «Sí»
  function NewRecruitment.Ask(s)
    call(A.MSG_OPEN, s, 0, 0, 0, 0, 0, false)
    call(A.MSG_KIND, 2, 0)
    coroutine.yield()
    local r = -1
    while r == nil or r < 0 do
      r = call(A.MSG_RESULT)
      coroutine.yield()
    end
    while call(A.MSG_DONE) ~= true do
      coroutine.yield()
    end
    return r == 0
  end

  function NewRecruitment.Notice(s)
    call(A.MSG_OPEN, s, 0, 0, 0, 0, 0, false)
    call(A.MSG_KIND, 1, 0)
    coroutine.yield()
    while call(A.MSG_BUSY) == true do
      coroutine.yield()
    end
    while call(A.MSG_DONE) ~= true do
      coroutine.yield()
    end
  end

  -- text `id` of the game's language with «%s» = name
  function NewRecruitment.Say(id, name)
    local t = call(A.TEXT, id)
    t = type(t) == "string" and t or ""
    local ok, s = pcall(string.format, t, name or "")
    return ok and s or t
  end

  -- the album action (BetterQoL.AlbumActions): row = {base, param, name, owned}
  A.action = {
    id = "NewRecruitment.Recruit",
    guide = A.GUIDE,
    On = function()
      return NewRecruitment.RecruitFrom("album") and VRFW_Recruit ~= nil and
        (NewRecruitment.Applies == nil or NewRecruitment.Applies())
    end,
    Run = function(row)
      local R = VRFW_Recruit
      local name = tostring(row.name or "")
      if R == nil or type(row.param) ~= "number" or row.param == 0 then return false end
      local can, why = R.CanSign(row.param)
      if row.owned == true or why == "owned" then
        NewRecruitment.Notice(NewRecruitment.Say(A.OWNED, name))
        return false
      end
      if not can then
        NewRecruitment.Notice(NewRecruitment.Say(A.FULL, name))
        return false
      end
      if not NewRecruitment.Ask(NewRecruitment.Say(A.ASK, name)) then
        return false
      end
      local level = type(R.TeamLevel) == "function" and R.TeamLevel() or 1
      local ok, err = R.Recruit{param = row.param, level = level}
      pcall(funcLuaCommand, A.LOG, "NewRecruitment album recruit", row.param, level, ok == true and "joined" or tostring(err))
      if ok == true then
        NewRecruitment.Notice(NewRecruitment.Say(A.DONE, name))
        return true
      end
      NewRecruitment.Notice(NewRecruitment.Say(err == "bank_full" and A.FULL or A.FAILED, name))
      return false
    end,
  }

  if type(BetterQoL) == "table" then
    BetterQoL.AlbumActions = type(BetterQoL.AlbumActions) == "table" and BetterQoL.AlbumActions or {}
    local listed = false
    for _, a in ipairs(BetterQoL.AlbumActions) do
      if type(a) == "table" and a.id == A.action.id then listed = true end
    end
    if not listed then
      BetterQoL.AlbumActions[#BetterQoL.AlbumActions + 1] = A.action
    end
  end
end
