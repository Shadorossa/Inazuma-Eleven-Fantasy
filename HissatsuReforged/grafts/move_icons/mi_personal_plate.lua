-- EVT move icons: child of the retail personal_plate_inc bytecode (player page / bank / formation skill rows). Its row
-- builders SetupPersonalPlateCharaSkillItem and SetupCharaSkillItem run the badge pass
-- (SetupCommandActionSkillInfoCategoryIcon, wrapped in soccer_common by this graft) and only THEN set the armed mesh's
-- visibility for their move: the 2nd badge (EVT_MI.Second, on that mesh) is shown again after them. Retail runs first
-- and its results are returned; only Lua globals are wrapped at load.
EVT_MI_PP = EVT_MI_PP or {}
for _, name in ipairs({"SetupPersonalPlateCharaSkillItem", "SetupCharaSkillItem"}) do
  if EVT_MI_PP[name] == nil then
    EVT_MI_PP[name] = _ENV[name]
  end
  if EVT_MI_PP[name] ~= nil then
    _ENV[name] = function(...)
      if EVT_MI ~= nil then
        EVT_MI.lastCall = nil
      end
      local r = table.pack(EVT_MI_PP[name](...))
      if EVT_MI ~= nil and EVT_MI.lastCall ~= nil then
        pcall(EVT_MI.Again, EVT_MI.lastCall[1], EVT_MI.lastCall[2])
      end
      return table.unpack(r, 1, r.n)
    end
  end
end

-- The single-move detail card (SetupPersonalPlateSkillDetailInfo: Habilidades / ability lists, player page, shop,
-- formation, ability board...; SetupPersonalPlateSkillEnptyDetailInfo: the same card for an empty slot). Its layer and
-- instance are main-chunk locals of personal_plate_inc; the card always sets the tag mesh _gtxt_longshoot01's
-- visibility on them, so they are read from that call while retail runs (the global funcLuaMenuCommand is forwarded
-- unchanged and put back right after). Then, on that card:
--   * EVT_MoveIconsDetail adds the tag retail has no case for (a long + counter shot: both words; a registered badge
--     such as Inazuma Fantasy's keeper clear «P» + «Despeje»);
--   * then every function of EVT_MI_PP.CardHooks runs (hook(L, inst, skill); skill nil on the empty-slot card): other
--     mods' grafts add their own card changes there (Inazuma Fantasy's move_icons_clear removes the category section).
EVT_MI_PP.CardHooks = EVT_MI_PP.CardHooks or {}

function EVT_MI_PP.RunHooks(L, inst, skill)
  for _, hook in ipairs(EVT_MI_PP.CardHooks) do
    pcall(hook, L, inst, skill)
  end
end

-- run retail card setup `name`, catching the card's layer / instance; then `after(L, inst, ...)`
function EVT_MI_PP.Card(name, after, ...)
  local real, seen = funcLuaMenuCommand, nil
  if real ~= nil then
    funcLuaMenuCommand = function(c, L, m, v, inst, ...)
      if c == 3405944500 and m == 1220252763 --[[_gtxt_longshoot01]] then
        seen = {L, inst}
      end
      return real(c, L, m, v, inst, ...)
    end
  end
  local r = table.pack(pcall(EVT_MI_PP[name], ...))
  funcLuaMenuCommand = real
  if not r[1] then
    error(r[2], 0)
  end
  if seen ~= nil then
    pcall(after, seen[1], seen[2], ...)
  end
  return table.unpack(r, 2, r.n)
end

if EVT_MI_PP.SetupPersonalPlateSkillDetailInfo == nil then
  EVT_MI_PP.SetupPersonalPlateSkillDetailInfo = SetupPersonalPlateSkillDetailInfo
end
if EVT_MI_PP.SetupPersonalPlateSkillDetailInfo ~= nil then
  function SetupPersonalPlateSkillDetailInfo(...)
    return EVT_MI_PP.Card("SetupPersonalPlateSkillDetailInfo", function(L, inst, skill)
      if EVT_MoveIconsDetail ~= nil then
        pcall(EVT_MoveIconsDetail, L, inst, skill)
      end
      EVT_MI_PP.RunHooks(L, inst, skill)
    end, ...)
  end
end

if EVT_MI_PP.SetupPersonalPlateSkillEnptyDetailInfo == nil then
  EVT_MI_PP.SetupPersonalPlateSkillEnptyDetailInfo = SetupPersonalPlateSkillEnptyDetailInfo
end
if EVT_MI_PP.SetupPersonalPlateSkillEnptyDetailInfo ~= nil then
  function SetupPersonalPlateSkillEnptyDetailInfo(...)
    return EVT_MI_PP.Card("SetupPersonalPlateSkillEnptyDetailInfo", function(L, inst)
      EVT_MI_PP.RunHooks(L, inst, nil)
    end, ...)
  end
end
