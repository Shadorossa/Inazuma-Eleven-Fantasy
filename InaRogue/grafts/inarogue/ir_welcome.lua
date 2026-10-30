-- ---- the welcome gacha of the first entry (docs/game/modes/inarogue-welcome-gacha.md; owner 2026-10-20) ------------
-- The first-run gift drawn (CMND_INAROGUE_WELCOME_DRAW), a welcome message, InaRogue's gold copy of the retail Players
-- Universe scene (ev74_10091) played over the menus, every player revealed one by one by the retail summon performance
-- (soccer_summon_menu, graft inarogue_welcome), then a summary of the players on this screen (tiles = the retail status
-- plate soccer11_04_formation_chara_status: its backing, the kit-dressed miniface, the name and the stars). Data:
-- content\rogue\welcome_gacha.toml. A global table: no new chunk locals (the 200-local limit).
--@lib evt_menu_kit.lua#Pointer
IRW = {
  DRAW = @crc:CMND_INAROGUE_WELCOME_DRAW@,            -- CMND_INAROGUE_WELCOME_DRAW () -> n
  INFO = @crc:CMND_INAROGUE_WELCOME_INFO@,          -- CMND_INAROGUE_WELCOME_INFO (i) -> ok, param, stars, rarity
  STATE = @crc:CMND_INAROGUE_WELCOME_STATE@,          -- CMND_INAROGUE_WELCOME_STATE (state)
  LAYOUT = @crc:CMND_INAROGUE_WELCOME_LAYOUT@,        -- CMND_INAROGUE_WELCOME_LAYOUT () -> event, n, geometry, meshes, texts, seconds
  RUN = @crc:CMND_INAROGUE_SCENE_RUN@,           -- CMND_INAROGUE_SCENE_RUN (reserved) -> ok, slot / why
  TICK = @crc:CMND_INAROGUE_SCENE_TICK@,          -- CMND_INAROGUE_SCENE_TICK () -> phase, seconds
  RESERVE = @crc:CMND_RESERVE_EVENT@,        -- CMND_RESERVE_EVENT (event) -> id, refused
  HIDE_MENU = 1670867360,     -- (1, menu): a menu not drawn (retail full-screen video over menus)
  SHOW_MENU = 3257327861,     -- (menu): drawn again
  FADE_BUSY = @crc:CMND_BRIGHT_IS_FADE@,     -- CMND_BRIGHT_IS_FADE
  SUMMON_MENU = 369188769,    -- soccer_summon_menu
  CHARA_ID = 347353059,       -- (param) -> chara id
  CHARA_NAME = 523676951,     -- (chara id) -> name
  TEXT_VISIBLE = @crc:CMND_SET_MENU_TEXT_VISIBLE@,  -- CMND_SET_MENU_TEXT_VISIBLE (layer, text, visible, idx)
  TILE = 1844915256,          -- soccer11_04_formation_chara_status (11 instances on this screen)
  TILE_FACE = 2531809341,     -- _icon_chr_status_dmy01
  TILE_FACE_SLOT = 3236322704,   -- icon_chr_status_dmy01
  TILE_NAME = 1704438437,     -- _text_name01
  TILE_STARS = 4238277407,    -- _text_name02
  HEADER_TEXT = 1220590795,   -- _text_sub_title02 of the header
  GUIDE_TEXT = 378156699,     -- _text_guide01 of the guide line
  TXT = {
    MSG = {1478993723 --[[evt_ir_welcome_msg]]},
    TITLE = {2373811702 --[[evt_ir_welcome_title]]},
    SUB = {1756330568 --[[evt_ir_welcome_sub]]},
    STAR_ON = {2007460865 --[[evt_ir_star_on]]},
    STAR_OFF = {3380229650 --[[evt_ir_star_off]]},
  },
  open = false,               -- the summary is on screen (Accept / Back / a click anywhere close it)
  pointer = nil,              -- the summary's pointer (evt_menu_kit.lua#Pointer): a mouse click anywhere closes it
  accepted = false,
  shown = 0,                  -- tiles in use
}

function IRW.WaitFade()
  local k = 0
  while funcLuaCommand(IRW.FADE_BUSY) and k < 120 do
    k = k + 1
    coroutine.yield()
  end
end

-- the gold scene over the menus; the screen stays black after it (the reveal opens under black)
function IRW.Scene(event, max_s)
  if type(event) ~= "number" or event == 0 then
    return
  end
  Call(IRW.STATE, 1)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.FADE, 1, 0.3)
  IRW.WaitFade()
  local id, refused = Call(IRW.RESERVE, event)
  Log("welcome gacha: scene reserved", tostring(id), tostring(refused))
  if type(id) == "number" and id ~= 0 then
    ShowOwnLayers(false)
    funcLuaMenuCommand(IRW.HIDE_MENU, 1, MENU)
    local ok, why = Call(IRW.RUN, id)
    Log("welcome gacha: scene run", tostring(ok), tostring(why))
    if ok == true then
      funcLuaCommand(C.FADE, 0, 0.3)
      local frames, limit = 0, Int(max_s) * 60
      local phase = "starting"
      while frames < limit do
        phase = Call(IRW.TICK)
        if phase ~= "starting" and phase ~= "running" then
          break
        end
        frames = frames + 1
        coroutine.yield()
      end
      Log("welcome gacha: scene", tostring(phase), "after", frames, "frame(s)")
      funcLuaCommand(C.FADE, 1, 0)
    end
    funcLuaMenuCommand(IRW.SHOW_MENU, MENU)
  end
  Call(IRW.STATE, 0)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
end

-- the retail summon performance, one player at a time (graft inarogue_welcome runs it in soccer_summon_menu and
-- closes that menu at the end)
function IRW.Reveal(n)
  Call(IRW.STATE, 2)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.OPEN_MENU, IRW.SUMMON_MENU)
  coroutine.yield()
  coroutine.yield()
  local opened = funcLuaMenuCommand(C.EXIST_MENU, IRW.SUMMON_MENU) == true
  Log("welcome gacha: reveal of", n, "player(s), summon menu open", tostring(opened))
  local frames = 0
  while funcLuaMenuCommand(C.EXIST_MENU, IRW.SUMMON_MENU) == true and frames < 36000 do
    frames = frames + 1
    coroutine.yield()
  end
  if frames >= 36000 then
    Log("welcome gacha: the summon screen was still open after 36000 steps: closed")
    funcLuaCommand(C.CLOSE_MENU, IRW.SUMMON_MENU)
  end
  Call(IRW.STATE, 0)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
end

-- n stars as text (the glyphs are menu_text rows)
function IRW.Stars(n)
  local on, off = T(IRW.TXT.STAR_ON), T(IRW.TXT.STAR_OFF)
  return string.rep(on, n) .. string.rep(off, 5 - n)
end

-- tile k (0-based) of the summary: player k at its place of the rows (g = the layout's geometry: tile, gap, scale,
-- offset x, offset y, rows n, count per row..., centre y per row...)
function IRW.Tile(k, g, meshes, texts)
  local ok, param, stars = Call(IRW.INFO, k)
  if ok ~= true then
    return false
  end
  local tile, gap, scale, dx, dy, nrows = g[1], g[2], g[3], g[4], g[5], Int(g[6])
  local row, col = 1, k
  while row <= nrows and col >= Int(g[6 + row]) do
    col = col - Int(g[6 + row])
    row = row + 1
  end
  if row > nrows then
    return false
  end
  local count = Int(g[6 + row])
  local x = 960 + (col - (count - 1) / 2) * (tile + gap) + dx
  local y = -Int(g[6 + nrows + row]) + dy
  funcLuaMenuCommand(C.OPEN_LAYER, IRW.TILE, k)
  funcLuaMenuCommand(C.LAYER_VISIBLE, IRW.TILE, k, true)
  funcLuaMenuCommand(LAYOUT.POS, IRW.TILE, x, y, 0, k)
  funcLuaMenuCommand(ARC.SCALE, IRW.TILE, scale, scale, 1, k)
  for _, m in ipairs(meshes) do
    funcLuaMenuCommand(C.MESH_VISIBLE, IRW.TILE, m, false, k)
  end
  for _, t in ipairs(texts) do
    funcLuaMenuCommand(IRW.TEXT_VISIBLE, IRW.TILE, t, false, k)
  end
  local id = Call(IRW.CHARA_ID, param)
  if type(id) == "number" and id ~= 0 then
    VRFW_FaceIcon.Request(IRW.TILE, k, {chara = id}, IRW.TILE_FACE, IRW.TILE_FACE_SLOT)   -- the tile shows its mesh itself
    local name = Call(IRW.CHARA_NAME, id)
    funcLuaMenuCommand(C.TEXT, IRW.TILE, IRW.TILE_NAME, type(name) == "string" and name or "", k)
  end
  funcLuaMenuCommand(C.TEXT, IRW.TILE, IRW.TILE_STARS, IRW.Stars(Int(stars)), k)
  return true
end

-- the summary: the players on this screen until Accept / Back
function IRW.Summary(n, g, meshes, texts)
  if type(g) ~= "table" then
    return
  end
  ShowOwnLayers(false)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_BG, 0, true)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_HEADER, 0, true)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_GUIDE_LINE, 0, true)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_BTN_GUIDE, 0, true)
  funcLuaMenuCommand(C.TEXT, L_HEADER, IRW.HEADER_TEXT, T(IRW.TXT.TITLE))
  funcLuaMenuCommand(C.TEXT, L_GUIDE_LINE, IRW.GUIDE_TEXT, T(IRW.TXT.SUB, n), 0)
  IRW.shown = 0
  IRW.accepted = false
  IRW.open = true                 -- before the tiles open: their OnOpenLayer shows them
  for k = 0, n - 1 do
    if IRW.Tile(k, g, type(meshes) == "table" and meshes or {}, type(texts) == "table" and texts or {}) then
      IRW.shown = k + 1
    end
  end
  Log("welcome gacha: summary of", IRW.shown, "player(s)")
  funcLuaCommand(C.FADE, 0, 0.3)
  IRW.pointer = IRW.pointer or EVT_PointerNew()
  IRW.pointer.Reset()             -- the press that ended the reveal is no click here
  while not IRW.accepted do
    local ev = IRW.pointer.Poll()
    if ev.click ~= nil or ev.miss then
      IRW.accepted = true
    end
    coroutine.yield()
  end
  IRW.open = false
  funcLuaCommand(C.SE, SE_DECIDE)
  for k = 0, IRW.shown - 1 do
    funcLuaMenuCommand(C.LAYER_VISIBLE, IRW.TILE, k, false)
  end
  funcLuaMenuCommand(C.TEXT, L_HEADER, IRW.HEADER_TEXT, TXT.HEADER)
  RestoreOwnLayers()
  UpdateGuideLine()
  SyncNativeFocus()               -- the pointer may have moved the engine focus over the hidden rows meanwhile
end

-- Accept / Back while the summary is open: it closes (true = the input is taken)
function IRW.Input()
  if IRW.open then
    IRW.accepted = true
    return true
  end
  return false
end

-- the whole welcome: draw, message, scene, reveal, summary
-- one log line per step of the welcome (on change only)
function IRW.Step(name)
  if IRW.step ~= name then
    IRW.step = name
    Log("welcome gacha step:", name)
  end
end

function IRW.Steps()
  IRW.Step("draw")
  local n = Int(Call(IRW.DRAW))
  Log("welcome gacha: players drawn", n)
  if n <= 0 then
    return
  end
  IRW.Step("message")
  Message(T(IRW.TXT.MSG, n))
  local event, _, g, meshes, texts, max_s = Call(IRW.LAYOUT)
  IRW.Step("scene")
  IRW.Scene(event, max_s)
  IRW.Step("reveal")
  IRW.Reveal(n)
  IRW.Step("summary")
  IRW.Summary(n, g, meshes, texts)
end

-- the whole welcome: draw, message, scene, reveal, summary. Any error gives the plain menu back (the players are in the
-- bank already: the welcome only shows them).
function IRW.Run()
  local ok, err = pcall(IRW.Steps)
  if not ok then
    Log("welcome gacha: error at step", tostring(IRW.step), "- the plain menu comes back:", tostring(err))
    IRW.open = false
    for k = 0, 10 do
      funcLuaMenuCommand(C.LAYER_VISIBLE, IRW.TILE, k, false)
    end
    Call(IRW.STATE, 0)
    funcLuaMenuCommand(IRW.SHOW_MENU, MENU)
    funcLuaMenuCommand(C.TEXT, L_HEADER, IRW.HEADER_TEXT, TXT.HEADER)
    RestoreOwnLayers()
    UpdateGuideLine()
    funcLuaCommand(C.FADE, 0, 0.3)
    funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
  end
  IRW.Step("done")
  IRW.step = nil
end
