-- vrfw_contact_map_menu, part 7 of 7 (graft contact_map appends it to vrfw_contact_map_menu.lua; one chunk):
-- the engine callbacks (OnInit, OnSetupLayer, Step, ...).
-- ---- callbacks ------------------------------------------------------------------------------------------------------
function OnInit()
  OT.f, OT.lines, OT.setup, OT.ev = 0, 0, {}, {}
  OtNote("init")
  funcLuaCommand(C.P_CLEAR, KEY_RESULT)
  -- the art the mods declare for this screen (VRFW_ScreenArt; the plain atlas vrfw_plain is in the menu's res): its
  -- atlases asked now (Tex: Step redraws when they are in); one line naming the roles drawn plain
  art, plain_tint = VRFW_ScreenArt.Get(ART_SCREEN), {}
  for _, path in ipairs(VRFW_ScreenArt.Atlases(ART_SCREEN)) do
    Tex(path)
  end
  local plain = {}
  for role in pairs(FALLBACK) do
    if art[role] == nil then
      plain[#plain + 1] = role
    end
  end
  if #plain > 0 then
    table.sort(plain)
    Log("art: plain fallback (vrfw_plain) for", #plain, "role(s):", table.concat(plain, " "))
  end
  ready, open_guard, SET, MAP, mode = false, 20, nil, nil, "list"
  for layer in pairs(BUST.key) do
    VRFW_FaceIcon.Forget(layer)   -- the busts are built again from scratch
  end
  HUB.menu, HUB.on, BUST.key, BUST.chara = nil, false, {}, {}
  if funcLuaCommand(C.P_EXISTS, KEY_PARENT) then
    local parent = Int(funcLuaCommand(C.P_GET, KEY_PARENT))
    funcLuaCommand(C.P_CLEAR, KEY_PARENT)
    HUB.menu = parent ~= 0 and parent or nil
  end
  focus = {list = 1, zones = 1, grid = 1, network = 1, shop = 1}
  -- the body types the model's pose has (the framework reads menu_chara_model_pose_config): a player of another body
  -- type gets no model (the pose command would crash the game, see evt_menu_kit.lua#CharaModel)
  local bodies = nil
  local list = Call(@crc:CMND_VRFW_MODEL_POSE_BODIES@, 2328706751 --[[the retail shop pose]])
  if type(list) == "table" and #list > 0 then
    bodies = {}
    for _, b in ipairs(list) do
      bodies[b] = true
    end
  end
  Log("model pose bodies", type(list) == "table" and #list or -1)
  -- each player in his own team's kit (everybody wore the generic Raimon kit): the framework
  -- derives it per card from the data (CMND_VRFW_CONTACT_KIT); 0 = the default
  -- a player of the shown team page (slots 0-15) wears that team's own kit; staff keep theirs
  local function TeamKit(pid)
    local team = CmPages.FORM.filled
    if type(team) ~= "number" or team == 0 then
      return nil
    end
    local okc, cnt = funcLuaCommand(2151743654, team, 8)
    for m = 0, ((okc and type(cnt) == "number") and cnt or 0) - 1 do
      local okp, param = funcLuaCommand(34355761, team, m, 0)
      if okp and Int(param) == Int(pid) then
        local _, slot = funcLuaCommand(34355761, team, m, 7)
        if type(slot) == "number" and slot < 16 then
          local _, uni = funcLuaCommand(2151743654, team, 4)
          if type(uni) == "number" and uni ~= 0 then
            return uni
          end
        end
        return nil
      end
    end
    return nil
  end
  local function Kit(pid)
    local r = Call(@crc:CMND_VRFW_CONTACT_KIT@, pid)
    local u, f = 0, 0
    if type(r) == "table" and type(r.uniform) == "number" then
      u, f = r.uniform, tonumber(r.flags) or 0
    end
    local ok, tu = pcall(TeamKit, pid)
    if ok and tu ~= nil then
      u = tu
    end
    return u, f
  end
  Model = EVT_CharaModelNew(L_MODEL, {kit = Kit, shadow = L_SHADOW, log = Log, pose = 2328706751, bodies = bodies})
  -- (RS turned the 3D player): the shop list base's model control (the right stick turns the model)
  -- stays OFF on this screen, every frame (a build may switch it on); the global menu input controller is never
  -- changed here (the shop's MENU_CTRL_SEPARATE_CROSS_KEY switch froze the Market)
  function Model.NoTurn()
    pcall(funcLuaMenuCommand, 1195674914 --[[chara model control]], L_MODEL, 0, false)
  end
  -- the model PANEL.MODEL_X metres right of where its build put it: once per build, the frame it is shown
  -- (CMND_GET_CHARA_MODEL_POS 3136332215 (layer, inst, slot) -> x, y, z; CMND_SET_CHARA_MODEL_POS 1088067423 (layer,
  -- inst, x, y, z, slot), as the retail SetupCharaModel / CalculateZoomPosition)
  function Model.Place()
    local B = Model.build
    if B == nil or not B.done or Model.pend ~= nil or Model.pid == nil then
      return
    end
    -- the read answers (found, x, y, z) (a log read "model pos unread true true": its first value is a
    -- flag; retail CalculateZoomPosition uses the 2nd-4th); an answer of 3 numbers is taken too
    local function Read(...)
      local r = table.pack(pcall(funcLuaMenuCommand, @crc:CMND_GET_CHARA_MODEL_POS@, L_MODEL, 0, 0, ...))
      if not r[1] then
        return nil
      end
      if type(r[2]) == "boolean" then
        if r[2] and type(r[3]) == "number" and type(r[4]) == "number" and type(r[5]) == "number" then
          return r[3], r[4], r[5]
        end
        return nil
      end
      if type(r[2]) == "number" and type(r[3]) == "number" and type(r[4]) == "number" then
        return r[2], r[3], r[4]
      end
      return nil
    end
    local ok, x, y, z = true, Read()
    if x == nil then
      x, y, z = Read(1001527765)
    end
    if not (type(x) == "number" and type(y) == "number" and type(z) == "number") then
      -- unreadable: the shared menu model camera's offset moves the view instead (camera -MODEL_X = the model
      -- +MODEL_X on screen; CMND 284729675 on 1752770328, as research/grafts/plate_model); given back on the way out
      if Model.placed ~= B then
        Model.placed = B
        Model.cam = true
        local okc = pcall(funcLuaCommand, 284729675, 1752770328, -PANEL.MODEL_X, 0, 0)
        Log("model pos unread: camera offset", -PANEL.MODEL_X, tostring(okc))
      end
      return
    end
    -- already at our place: nothing; else (a new build, or the component put it back) our place again (absolute:
    -- no drift)
    local at = PANEL.MODEL_AT
    if math.abs(x - at[1]) < 0.005 and math.abs(y - at[2]) < 0.005 and math.abs(z - at[3]) < 0.005 then
      return
    end
    local ok2 = pcall(funcLuaMenuCommand, @crc:CMND_SET_CHARA_MODEL_POS@, L_MODEL, 0, at[1], at[2], at[3], 0)
    Model.px = at[1]
    Model.moves = (Model.moves or 0) + 1
    if Model.moves <= 6 then
      Log("model pos", x, y, z, "->", at[1], at[2], at[3], tostring(ok2))
    end
  end
  STATUS.card = nil
  local set = 0
  if funcLuaCommand(C.P_EXISTS, KEY_SET) then
    set = Int(funcLuaCommand(C.P_GET, KEY_SET))
    funcLuaCommand(C.P_CLEAR, KEY_SET)
  end
  if VRFW_Recruit == nil then
    Log("error", "VRFW_Recruit missing (the menu part's lua\\_all\\62_recruit.lua did not run in this VM)")
    return
  end
  VRFW_Recruit.Refresh()                        -- the club counts of the element / position requirements, fresh
  CmPages.direct = nil
  CmPages.trail, CmPages.going, CmPages.all = {}, false, false
  if funcLuaCommand(C.P_EXISTS, 3811836272 --[[vrfw_contact_game]]) then
    CmPages.direct = Int(funcLuaCommand(C.P_GET, 3811836272))
    funcLuaCommand(C.P_CLEAR, 3811836272)
    if CmPages.direct == 0 then
      CmPages.direct = nil
    end
  end
  SET = LoadSet(set)
  if SET == nil then
    Log("open", "set", set, "not declared: closing")
    return
  end
  for _, m in ipairs(SET.maps) do
    m.signed = MapSigned(m)
  end
  Log("open", SET.key, "maps", #SET.maps, VIEW_ALL.on and "VIEW EVERYTHING ON ([debug] reveal_all): nothing is signed by it" or "")
end

-- the tile plates keep no engine mouse zone: the Lua hit test (Ptr) owns hover and click, so the engine never moves
-- its focus (and plays its focus sound) on a hovered plate
local function DropEngineZone(layer, idx)
  pcall(funcLuaMenuCommand, C.HIT_ZONE, layer, idx, false)
  pcall(funcLuaMenuCommand, C.HOVER_FOCUS, layer, idx, false)
end

local function OpenOwnLayers()
  if CmPages.OpenFormLayers ~= nil then
    CmPages.OpenFormLayers()           -- the team dock's lineup layers (a team page)
  end
  for i = 0, N.LINE - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_LINE, i)
  end
  for i = 0, N.TILE - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_TILE, i)
    DropEngineZone(L_TILE, i)
  end
  for i = 0, N.TAG - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_TAG, i)
  end
  for i = 0, N.FACE - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_FACE, i)
  end
  for i = 0, N.UI - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_UI, i)
  end
  for i = 0, N.TITLE - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_TITLE, i)
  end
  for i = 0, N.CARDTXT - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_CARDTXT, i)
  end
  funcLuaMenuCommand(C.OPEN_LAYER, L_BACK, 0)
  funcLuaMenuCommand(C.OPEN_LAYER, L_ZONEART, 0)
  funcLuaMenuCommand(C.OPEN_LAYER, L_CARD, 0)
  funcLuaMenuCommand(C.OPEN_LAYER, L_ICON, 0)
  for i = 0, N.BUST - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_BUST, i)
  end
  funcLuaMenuCommand(C.OPEN_LAYER, L_BUSTICON, 0)
  funcLuaMenuCommand(C.OPEN_LAYER, L_PANEL, 0)
  funcLuaMenuCommand(C.OPEN_LAYER, L_PANEL, 1)
  funcLuaMenuCommand(C.OPEN_LAYER, L_MODEL, 0)
  funcLuaMenuCommand(C.OPEN_LAYER, L_SHADOW, 0)
  funcLuaMenuCommand(C.OPEN_LAYER, L_STATUS, 0)
  funcLuaMenuCommand(C.OPEN_LAYER, L_SLANT, 0)
  funcLuaMenuCommand(C.OPEN_LAYER, L_PPROW, 0)
  for i = 0, N.REQ - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_REQ, i)
    funcLuaMenuCommand(C.OPEN_LAYER, L_REQOK, i)
  end
  funcLuaMenuCommand(C.OPEN_LAYER, L_REQ, REQ.CHECK.BOX_IX)    -- the team page's check box
  funcLuaMenuCommand(C.OPEN_LAYER, L_REQ, REQ.CHECK.MARK_IX)
  local P = INFO.PLATES                                           -- the requirement card's plates, bars, header
  for i = P.FILL_IX, P.FILL_IX + 3 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_REQ, i)
  end
  for i = 0, P.CHIP_IX do
    funcLuaMenuCommand(C.OPEN_LAYER, P.L_PLATE, i)
  end
  for i = 0, 3 do
    funcLuaMenuCommand(C.OPEN_LAYER, P.L_BAR, i)
  end
end

function OnSetupLayer(a1, a2)
  if OT.f <= OT.FRAMES then
    OT.setup[a1] = (OT.setup[a1] or 0) + 1
  end
  if CmPages.FORM_LAYER[a1] then
    CmPages.SetupFormLayer(a1, a2)
    return
  end
  if a1 == L_HEADER then
    SetupSoccerTopCommonHeaderLayerInfo(a1, 4153539961, 253801632, 3969848060, 1144161661, 3293713115, 253801632, 1152304044, 305955024, 3007971317)
    UpdateHeader(3586861540)
    UpdateTitle()
    OpenOwnLayers()
  elseif a1 == L_ROW or a1 == L_TITLE or a1 == L_CARDTXT then
    funcLuaMenuCommand(C.TEXT, a1, TEXT_ON, "", a2)
    funcLuaMenuCommand(C.TEXT, a1, TEXT_OFF, "", a2)
    funcLuaMenuCommand(C.TEXT_VISIBLE, a1, TEXT_ON, a1 ~= L_ROW, a2)
    funcLuaMenuCommand(C.TEXT_VISIBLE, a1, TEXT_OFF, false, a2)
    for _, m in ipairs(ROW_MESHES) do
      funcLuaMenuCommand(C.MESH_VISIBLE, a1, m, false, a2)
    end
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, a2, CUR, false)
    if a1 ~= L_ROW then
      Hide(a1, a2)
    end
  elseif a1 == L_RETAIL_BG then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
  elseif a1 == L_BACK or a1 == L_ZONEART or a1 == L_LINE or a1 == L_TILE or a1 == L_FACE or a1 == L_TAG or a1 == L_UI or a1 == L_CARD
      or a1 == L_ICON or a1 == L_REQ or a1 == L_REQOK or a1 == L_BUST or a1 == L_BUSTICON
      or a1 == INFO.PLATES.L_PLATE or a1 == INFO.PLATES.L_BAR then
    Hide(a1, a2)                -- DrawAll draws what is used when the anchor opens
    if a1 == L_TILE then
      DropEngineZone(a1, a2)
    end
  elseif a1 == L_PANEL then
    Hide(a1, a2)
  elseif a1 == L_MODEL then
    for _, m in ipairs({"_scr_line01", "_scr_obj01", "_dmy01"}) do   -- shop01_01's scroll bar / dummy: not used here
      funcLuaMenuCommand(C.MESH_VISIBLE, a1, CRC32(m), false, a2)
    end
  elseif a1 == L_STATUS or a1 == L_PPROW or a1 == L_SLANT then
    if type(VRFW_UI) == "table" then
      VRFW_UI.HeaderRow.Bare(a1, a2)  -- no rarity banner, no level from the first draw
    end
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
  elseif a1 == L_GUIDE_LINE then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, 0, false)
  elseif a1 == L_BTN_GUIDE then
    UpdateButtonGuide()
  end
end

function OnOpenLayer(a1, a2)
  if a1 == L_ROW and a2 == 0 then
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, false)
    funcLuaMenuCommand(C.FOCUS_ENABLE, a1, true)
    funcLuaMenuCommand(C.LIST_NUM, a1, 1)
    funcLuaMenuCommand(C.FOCUS_SET, a1, 0)
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, 0, CUR, false)
    funcLuaMenuCommand(C.POS, a1, -4000, 4000, 0, 0)
    if SET == nil then
      Close(0)
      return
    end
    OtNote("anchor open")
    if CmPages.direct ~= nil and not CmPages.OpenDirect() then
      Close(0)
      return
    end
    UpdateTitle()
    DrawAll()
    UpdateButtonGuide()
    Ptr.Reset()
    HubYield(true)
    KEYS.free_off = true
    KEYS.Free(true)
    funcLuaMenuCommand(C.POS, L_MODEL, PANEL.MODEL_DX, 0, 0, 0)   -- the model over the plate's centre
    ready = true
    if funcLuaCommand(C.FADE_DONE) then
      funcLuaCommand(C.FADE, 0, 0.3)
    end
  elseif a1 == L_GUIDE_LINE then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, 0, false)
  end
end

function OnDecideFocus(a1, a2)
  KEYS.cb.ENTER = KEYS.frame
  KEYS.Seen("ENTER")
  if evt_co ~= nil or not ready or open_guard > 0 or Ptr.Owns() then
    return
  end
  StartCo(Decide)
end

-- X / FUNC2 "Items": the shelf of the open map / zone
function KEYS.Shop()
  if true then                      -- the shelf is not offered from the contact map
    return
  end
  if open_guard <= 0 and MAP ~= nil and (mode == "grid" or mode == "network" or mode == "zones") then
    funcLuaCommand(C.SE, SE_DECIDE)
    OpenShop()
  end
end

-- the polled pad (Step): a press acts 2 frames later unless its callback came; held = repeat (only for a press the
-- poll owns: a held arrow the engine serves repeats through OnFunction)
function KEYS.Poll(free)
  local stick = KEYS.free_off and KEYS.StickDir() or nil    -- free cursor on: the stick drives the game's pointer
  for name, cmd in pairs(KEYS.NAV) do
    local on = KeyOn(cmd) or stick == name
    if on and not KEYS.held[name] then
      KEYS.press[name] = free and KEYS.frame or nil
      KEYS.owned[name] = false
    elseif not on then
      KEYS.press[name], KEYS.owned[name] = nil, false
    end
    KEYS.held[name] = on
    local p = KEYS.press[name]
    local act = false
    if p ~= nil and not KEYS.owned[name] and KEYS.frame - p >= 2 then
      if (KEYS.cb[name] or -100) < p - 2 and free then   -- a callback just before the poll saw the press counts too
        KEYS.owned[name] = true
        KEYS.next_rep[name] = KEYS.frame + KEYS.REPEAT_FIRST
        act = true
        if KEYS.logs < 5 then
          KEYS.logs = KEYS.logs + 1
          Log("pad by poll (no callback)", name, mode)
        end
      else
        KEYS.press[name] = nil
      end
    elseif p ~= nil and KEYS.owned[name] and free and KEYS.DIR[name] ~= nil and KEYS.frame >= KEYS.next_rep[name] then
      KEYS.next_rep[name] = KEYS.frame + KEYS.REPEAT
      act = true
    end
    if act then
      local d = KEYS.DIR[name]
      if d ~= nil then
        KEYS.Move(d[1], d[2])
      elseif name == "ENTER" then
        KEYS.press[name] = nil
        StartCo(Decide)
      elseif name == "FUNC2" then
        KEYS.press[name] = nil
        KEYS.Shop()
      elseif name == "FUNC3" or name == "FUNC4" then
        KEYS.press[name] = nil
        if evt_co == nil and ready then
          StartCo(name == "FUNC3" and CmPages.Trial or CmPages.Release)
        end
      end
    end
  end
end

function OnFunction(a1, a2)
  local id = a1
  if a1 ~= FN.UP and a1 ~= FN.DOWN and a1 ~= FN.LEFT and a1 ~= FN.RIGHT and a1 ~= FN.SHOP and a1 ~= FN.TRIAL
    and a1 ~= FN.RELEASE then
    id = a2
  end
  if id == FN.TRIAL or id == FN.RELEASE then
    KEYS.cb[id == FN.TRIAL and "FUNC3" or "FUNC4"] = KEYS.frame
    if evt_co == nil and ready then
      StartCo(id == FN.TRIAL and CmPages.Trial or CmPages.Release)
    end
    return 1
  end
  local name = (id == FN.UP and "UP") or (id == FN.DOWN and "DOWN") or (id == FN.LEFT and "LEFT")
    or (id == FN.RIGHT and "RIGHT") or (id == FN.SHOP and "FUNC2") or nil
  if name ~= nil then
    KEYS.cb[name] = KEYS.frame
    KEYS.Seen(name)
  end
  if evt_co ~= nil or not ready then
    return 1
  end
  if id == FN.SHOP then
    KEYS.Shop()
    return 1
  end
  local dx = id == FN.LEFT and -1 or (id == FN.RIGHT and 1 or 0)
  local dy = id == FN.UP and -1 or (id == FN.DOWN and 1 or 0)
  if dx == 0 and dy == 0 then
    return
  end
  KEYS.Move(dx, dy)
  return 1
end

function OnEnter(a1, a2)
  KEYS.cb.ENTER = KEYS.frame
  if a1 == L_BTN or a1 == L_RET then
    return 1
  end
  OnDecideFocus(a1, a2)
end

function OnBack(a1)
  KEYS.back_cb = KEYS.frame
  if evt_co ~= nil or not ready or open_guard > 0 then
    return 1
  end
  funcLuaCommand(C.SE, SE_BACK)
  Back()
  return 1
end

-- one line per frame with an event (and every OT.EVERY frames) during the first OT.FRAMES frames (OPEN TRACE above)
local function OtStep()
  if OT.f > OT.FRAMES then
    return
  end
  if OT.names == nil then
    OT.names = {[L_LINE] = "line", [L_TILE] = "tile", [L_FACE] = "face", [L_TAG] = "tag", [L_UI] = "ui",
      [L_TITLE] = "title", [L_CARDTXT] = "cardtxt", [L_BUST] = "bust", [L_BUSTICON] = "busticon", [L_REQ] = "req",
      [L_REQOK] = "reqok", [L_BACK] = "back", [L_ZONEART] = "zoneart", [L_CARD] = "card", [L_ICON] = "icon",
      [L_PANEL] = "panel", [L_MODEL] = "model", [L_SHADOW] = "shadow", [L_STATUS] = "status", [L_SLANT] = "slant",
      [L_PPROW] = "pprow", [L_ROW] = "row", [L_HEADER] = "header", [INFO.PLATES.L_PLATE] = "reqplate",
      [INFO.PLATES.L_BAR] = "reqbar"}
  end
  local parts = {}
  for layer, n in pairs(OT.setup) do
    parts[#parts + 1] = "setup " .. (OT.names[layer] or tostring(layer)) .. " x" .. n
  end
  local counted = {}
  for _, e in ipairs(OT.ev) do
    counted[e] = (counted[e] or 0) + 1
  end
  for e, n in pairs(counted) do
    parts[#parts + 1] = n > 1 and (e .. " x" .. n) or e
  end
  if (#parts > 0 or OT.f % OT.EVERY == 0) and OT.lines < OT.MAX then
    OT.lines = OT.lines + 1
    Log("open trace f" .. OT.f, mode, table.concat(parts, ", "))
  end
  OT.setup, OT.ev = {}, {}
  OT.f = OT.f + 1
end

function Step()
  pcall(OtStep)
  if evt_co ~= nil then
    if coroutine.status(evt_co) == "dead" then
      evt_co = nil
    else
      local ok, err = coroutine.resume(evt_co)
      if not ok then
        PRINT("vrfw_contact_map_menu: " .. tostring(err))
        Log("error", tostring(err))
        evt_co = nil
        funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
      elseif coroutine.status(evt_co) == "dead" then
        evt_co = nil
      end
    end
  end
  if ready and open_guard > 0 then
    open_guard = open_guard - 1
  end
  if not ready and SET ~= nil then   -- the input anchor never opened: the layer pools are past the engine's limit
    KEYS.wait = (KEYS.wait or 0) + 1
    if KEYS.wait == 300 then
      Log("STUCK: the input anchor never opened (layer instances past the menu's limit?)")
    end
  end
  -- faces / the background still loading: redraw when they arrive (600 frames at most, then the "?" icon)
  if ready and tex_wait then
    local changed, still = false, false
    for path, f in pairs(tex_frames) do
      if f >= 0 then
        if funcLuaCommand(C.TEX_LOADING, CRC32(path)) == true then
          if f + 1 > 600 then
            tex_frames[path] = -1
            changed = true
          else
            tex_frames[path] = f + 1
            still = true
          end
        else
          tex_frames[path] = -2
          changed = true
          OtNote("tex in")
        end
      end
    end
    if changed or not still then
      DrawAll()
    end
  end
  if ready then
    PollPointer()
    BustStep()
    if Model ~= nil then
      Model.Step()
      Model.NoTurn()
      Model.Place()
    end
    KEYS.frame = KEYS.frame + 1
    local free = evt_co == nil and open_guard <= 0 and funcLuaCommand(C.MSG_BUSY) ~= true
    if KEYS.co_was and evt_co == nil and not KEYS.free_off then
      KEYS.Free(true, true)     -- a question / message window may have switched the free cursor off
    end
    KEYS.co_was = evt_co ~= nil
    KEYS.Poll(free)
    CmNetViewStep(free)
    local l1, r1, back = KeyEdge("L1"), KeyEdge("R1"), KeyEdge("BACK")
    if free and (l1 or r1) then
      if not PageTurn(r1 and 1 or -1) then
        funcLuaCommand(C.SE, SE_NG)
      end
    end
    if back then
      KEYS.back_poll = KEYS.frame
    end
    if KEYS.back_poll ~= nil and KEYS.frame - KEYS.back_poll >= 2 then
      if KEYS.back_cb < KEYS.back_poll and free then
        if KEYS.logs < 5 then
          KEYS.logs = KEYS.logs + 1
          Log("back by poll (no OnBack)", mode)
        end
        funcLuaCommand(C.SE, SE_BACK)
        Back()
      end
      KEYS.back_poll = nil
    end
  end
end
