-- menu_engine: the TEAM EMBLEM GRID (VR-Framework UI piece `VRFW_EmblemGrid`; docs/framework/emblem-grid.md). Definitions
-- only (this file runs in every script VM, lua\_all; no engine call at load time). A picker of teams drawn as the Battle
-- Bay grid's emblem tiles, several a row, each with its name and a count under it; the caller owns what a team means.
--
-- Layers: a mod adds two layers to the menu it opens the grid in (its menus TOML), with the framework's objects
-- (research/mods/VRFW/content/menus/emblem_grid.toml):
--   <tile layer>   object vrfw_emblem_tile  (the retail BB emblem tile vs01_43: 136 px plate, 84 px emblem), count >= per
--   <label layer>  object vrfw_tile_label   (the retail character card's name text only), count >= 2 x per
--
--   local g = VRFW_EmblemGrid.New{ tile = crc32(tile layer), label = crc32(label layer) | nil,
--     cols = 8, rows = 3, px = 210, py = 236, cx = 960, cy = 540, scale = 1, prio = nil | draw priority base,
--     log = function(...) end }
--   g:Open(items[, sel])   items[i] = { name = "Raimon", count = "5/16", emblem = <item_emblem id, 0 = neutral plate>,
--                                       full = <the check mark>, dim = <greyed>,
--                                       image = { texture = "#/menu/…/x.g4tx", sprite = "name" } | nil };
--                          sel = 1-based (default 1). `image` (a picture the caller serves, e.g. a Steam avatar) takes
--                          the emblem's place: the texture is loaded and its sprite set on the emblem's texture slot
--   g:Set(i, item)         one item changed (redrawn)
--   g:Step() -> ev | nil   per frame: moves (arrows, L1 / R1 page, wheel, pointer hover) are handled here; returns
--                          { act = "decide" | "all" | "series" | "back", index = i, dir = -1 / 1 } for the caller:
--                          A / click = decide, Y (CMD_FUNC3) = all, L2 / R2 (Q / E) = series, B / right click = back
--   g:Sel() -> i           g:Page() -> page, pages      g:Hide()  (every instance hidden)      g:Close()
--   g:Built(layer, inst)   the menu's OnOpenLayer for those layers (an emblem is asked for once its instance is built,
--                          else 30 frames after it was opened)
-- Keys are polled with CMND_CHECK_INPUT_CMD on the menu controls (the caller turns its menu's own input off while the
-- grid shows). `input = "pad"` (2.0.111): no menu controller is active (a grid over a paused match): the game pad and
-- the keyboard are read directly (CMND_VRFW_INPUT_PAD / _KEY; L2 / R2 = Q / E, L1 / R1 = Page Up / Down). Positions: layer space from the screen's top left, y up (1920 x 1080); the rows a page uses are
-- centred on (cx, cy).
if VRFW_EmblemGrid == nil then
  local EG = {
    C = {
      CHECK_INPUT = 4265778440, LAYER_VISIBLE = 711242136, OPEN_LAYER = 629267548, LOCAL_POS = 1389957207,
      LOCAL_SCALE = 3778714801, MESH_VISIBLE = 3405944500, NODE_VISIBLE = 2158717427, TEXT_VISIBLE = 2735666188,
      SET_TEXT = 1083631230, COLOR = 801406373, EMBLEM = 3190452549, LOADING = 1277042906, SET_PRIO = 1491630496,
      POINTER = 558229292, POINTER_MOVED = 3272825600, SND = 3073642526,
      SPRITE = 558735651,          -- (layer, texture crc, sprite crc, texture slot crc, 0, instance)
      LOAD_TEX = 839427544,        -- CMND_LOAD_MENU_RES_TEXTURE (path)
      TEX_LOADING = 1506186496,    -- (texture crc) -> true while still loading
    },
    CTRLS = {1332654303 --[[MENU_CTRL]], 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]]},
    KEYS = {up = 1197218715, down = 3259546669, left = 2765147006, right = 2075023265, enter = 1981080283,
            back = 3011112225 --[[CMD_BACK]], all = 3421673595 --[[CMD_FUNC3]], l1 = 3966226594, r1 = 942075773,
            l2 = 1970176280 --[[CMD_FUNCL2]], r2 = 2704260807 --[[CMD_FUNCR2]],
            rclick = 3473063670, click = 218912913 --[[CMD_EVT_MOUSE_LEFT]], wup = 1942756954, wdown = 1623431741},
    REPEAT_FIRST = 18, REPEAT_EVERY = 5, BUILD_WAIT = 30, LOAD_WAIT = 120, FOCUS_SCALE = 1.1,
    SY_MOVE = 2500047763,          -- sy0005
    -- the tile (vs01_43): plate quads, the emblem quad / texture slot, the outline (cursor), the check mark (full)
    ICON_MESH = 1926542734,        -- _enjoy_list_icon_dmy01
    ICON_TEX = 618311715,          -- enjoy_list_icon_dmy01
    PLATE = "_enjoy_list_p1_base01",
    OUTLINE = "_enjoy_list_base01_ol",
    CHECK = "_icon_story_check01",
    GRAY = 643056375,              -- gray_out
    TILE_HIDE = {"_enjoy_list_base01_add", "_enjoy_list_p1_base01_ok", "_enjoy_list_p2_base02", "_enjoy_list_base02_add",
                 "_enjoy_list_p2_base01", "_enjoy_list_p2_base01_ok", "_enjoy_list_p1_base02", "_enjoy_list_base_lock01"},
    TILE_HIDE_NODES = {"_pos_1p01", "_pos_1p02", "_pos_enjoy_list01_p2"},
    TILE_HALF = 68,
    -- the label (team00_01 card): only its name text _text_chr01 (190 x 34, centre (0, -39) from the card's origin)
    LABEL_TEXT = 170976702,
    LABEL_DY = 39,
    LABEL_HIDE = {"_icon_chr_base_l01", "_icon_chr_dmy_l01", "_icon_chr_gradation_l01", "_seasonal_frame_l01",
      "_avatar_frame_l01", "_icon_chr_focus_l01", "_icon_chr_position_dmy_l01", "_icon_base_l01", "_icon_chr_type_dmy_l01",
      "_icon_lock01", "_icon_captain01", "_icon_ai_role_dmy01", "_gtxt_lv_l01", "_icon_card01", "_icon_chr_def01_l",
      "_icon_chr_grayout01", "_basara_avatar_l01", "_num_chr_dmy_l01", "_num_chr_dmy_l02", "_gauge_exp_base_l01",
      "_gauge_exp_l01", "_icon_synergy_l01", "_icon_synergy_l02", "_leader_base01", "_gtxt_leader01"},
    LABEL_HIDE_NODES = {"_pos_base02", "_pos_leader01", "_pos_ai_role01", "_num_chr_l01", "_num_chr_l02",
      "_pos_gauge_exp_l01"},
  }
  VRFW_EmblemGrid = EG

  local function M(cmd, ...)
    local ok, a, b = pcall(funcLuaMenuCommand, cmd, ...)
    if ok then
      return a, b
    end
    return nil
  end

  local function crc(s)
    if type(CRC32) == "function" then
      return CRC32(s)
    end
    return 0
  end

  local function In(input)
    for _, c in ipairs(EG.CTRLS) do
      local ok, r = pcall(funcLuaCommand, EG.C.CHECK_INPUT, c, input)
      if ok and r == true then
        return true
      end
    end
    return false
  end

  -- `input = "pad"`: each key name as pad masks (the PS-style layout of vr_sigs::input) and Windows virtual keys
  EG.PAD = {up = {0x10}, down = {0x40}, left = {0x80}, right = {0x20}, enter = {0x4000}, back = {0x2000, 0x1},
            all = {0x1000}, l1 = {0x400}, r1 = {0x800}, l2 = {0x100}, r2 = {0x200}}
  EG.VK = {up = {0x26}, down = {0x28}, left = {0x25}, right = {0x27}, enter = {0x0D}, back = {0x1B, 0x08},
           l1 = {0x21}, r1 = {0x22}, l2 = {0x51}, r2 = {0x45}}
  EG.C.PAD = 2864033604 --[[CMND_VRFW_INPUT_PAD]]
  EG.C.KEY = 3182184968 --[[CMND_VRFW_INPUT_KEY]]

  local G = {}
  G.__index = G

  -- the input `name` is held this frame (the menu controls, or the pad / keyboard with `input = "pad"`)
  function G:Down(name)
    if not self.pad then
      local input = EG.KEYS[name]
      return input ~= nil and In(input)
    end
    if self.pad_frame ~= self.frame then
      self.pad_frame = self.frame
      local ok, held = pcall(funcLuaCommand, EG.C.PAD)
      self.pad_held = (ok and type(held) == "number" and held > 0) and held or 0
    end
    for _, m in ipairs(EG.PAD[name] or {}) do
      if math.floor(self.pad_held / m) % 2 == 1 then
        return true
      end
    end
    for _, vk in ipairs(EG.VK[name] or {}) do
      local ok, v = pcall(funcLuaCommand, EG.C.KEY, vk)
      if ok and v == true then
        return true
      end
    end
    if name == "click" or name == "rclick" or name == "wup" or name == "wdown" then
      return In(EG.KEYS[name])
    end
    return false
  end

  function EG.New(o)
    local g = setmetatable({}, G)
    g.tile, g.label = o.tile, o.label
    g.cols, g.rows = o.cols or 8, o.rows or 3
    g.px, g.py, g.cx, g.cy = o.px or 210, o.py or 236, o.cx or 960, o.cy or 540
    g.scale, g.prio, g.log = o.scale or 1, o.prio, o.log or function() end
    g.pad = o.input == "pad"
    local have = M(1175615627 --[[CMND_GET_CREATE_LAYER_NUM]], g.tile)
    g.per = math.max(1, math.min(g.cols * g.rows, type(have) == "number" and have or 0))
    g.ok = type(have) == "number" and have > 0
    if g.label ~= nil then
      local hl = M(1175615627, g.label)
      g.label_ok = type(hl) == "number" and hl >= 2 * g.per
    end
    g.items, g.sel, g.frame = {}, 0, 0
    g.opened, g.lopened, g.built, g.asked, g.wait, g.drawn, g.held = {}, {}, {}, {}, {}, {}, {}
    g.img, g.loaded = {}, {}
    return g
  end

  function G:Sel()
    return self.sel + 1
  end

  function G:Page()
    return math.floor(self.sel / self.per), math.max(1, math.ceil(#self.items / self.per))
  end

  function G:KeysReset()
    for name in pairs(EG.KEYS) do
      self.held[name] = self:Down(name) and 1000 or 0
    end
    self.ptr_x, self.ptr_y = M(EG.C.POINTER)
  end

  function G:Pressed(name, repeats)
    local now = self:Down(name)
    local h = self.held[name] or 0
    if not now then
      self.held[name] = 0
      return false
    end
    self.held[name] = h + 1
    if not self.keys_seen then
      self.keys_seen = true
      self.log("emblem grid: input seen (" .. name .. ")")
    end
    if h == 0 then
      return true
    end
    return repeats and h >= EG.REPEAT_FIRST and (h - EG.REPEAT_FIRST) % EG.REPEAT_EVERY == 0
  end

  -- centre of cell k of the page (layer space, y up)
  function G:Cell(k)
    local c, r = k % self.cols, math.floor(k / self.cols)
    local page = math.floor(self.sel / self.per)
    local used = math.max(1, math.min(self.rows, math.ceil(math.min(self.per, #self.items - page * self.per) / self.cols)))
    return self.cx + (c - (self.cols - 1) / 2) * self.px, -(self.cy + (r - (used - 1) / 2) * self.py)
  end

  function G:Label(j, x, y, s)
    local L = self.label
    if L == nil or not self.label_ok then
      return
    end
    if s == nil then
      if self.lopened[j] then
        M(EG.C.LAYER_VISIBLE, L, j, false)
      end
      return
    end
    if not self.lopened[j] then
      M(EG.C.OPEN_LAYER, L, j)
      self.lopened[j] = true
    end
    M(EG.C.LOCAL_SCALE, L, 1, 1, 1, j)
    M(EG.C.LOCAL_POS, L, x, y + EG.LABEL_DY, 0, j)
    if self.prio then
      M(EG.C.SET_PRIO, L, j, self.prio + 2)
    end
    M(EG.C.LAYER_VISIBLE, L, j, true)
    for _, m in ipairs(EG.LABEL_HIDE) do
      M(EG.C.MESH_VISIBLE, L, crc(m), false, j)
    end
    for _, m in ipairs(EG.LABEL_HIDE_NODES) do
      M(EG.C.NODE_VISIBLE, L, crc(m), false, j)
    end
    M(EG.C.TEXT_VISIBLE, L, EG.LABEL_TEXT, true, j)
    M(EG.C.SET_TEXT, L, EG.LABEL_TEXT, s, j)
  end

  -- tile k shows item d (1-based; nil = hidden)
  function G:Tile(k, d)
    local L = self.tile
    local it = d and self.items[d] or nil
    if it == nil then
      if self.opened[k] then
        M(EG.C.LAYER_VISIBLE, L, k, false)
      end
      self:Label(2 * k, 0, 0, nil)
      self:Label(2 * k + 1, 0, 0, nil)
      self.drawn[k], self.asked[k], self.wait[k] = nil, nil, nil
      return
    end
    if not self.opened[k] then
      M(EG.C.OPEN_LAYER, L, k)
      self.opened[k] = self.frame
    end
    local focus = (d - 1) == self.sel
    local s = self.scale * (focus and EG.FOCUS_SCALE or 1)
    local x, y = self:Cell(k)
    M(EG.C.LOCAL_SCALE, L, s, s, 1, k)
    M(EG.C.LOCAL_POS, L, x, y, 0, k)
    if self.prio then
      M(EG.C.SET_PRIO, L, k, self.prio + (focus and 1 or 0))
    end
    M(EG.C.LAYER_VISIBLE, L, k, true)
    for _, m in ipairs(EG.TILE_HIDE) do
      M(EG.C.MESH_VISIBLE, L, crc(m), false, k)
    end
    for _, m in ipairs(EG.TILE_HIDE_NODES) do
      M(EG.C.NODE_VISIBLE, L, crc(m), false, k)
    end
    M(EG.C.NODE_VISIBLE, L, crc("_pos_enjoy_list01"), true, k)
    M(EG.C.MESH_VISIBLE, L, crc(EG.PLATE), true, k)
    M(EG.C.MESH_VISIBLE, L, crc(EG.OUTLINE), focus, k)
    M(EG.C.MESH_VISIBLE, L, crc(EG.CHECK), it.full == true, k)
    local v = it.dim and 0.3 or 1
    M(EG.C.COLOR, L, k, EG.GRAY, v, v, v)
    local emblem = type(it.emblem) == "number" and it.emblem or 0
    local img = type(it.image) == "table" and type(it.image.texture) == "string" and type(it.image.sprite) == "string"
      and it.image or nil
    local want = img and ("img:" .. img.texture .. ":" .. img.sprite) or emblem
    if self.drawn[k] ~= want then
      self.drawn[k], self.asked[k], self.wait[k] = want, nil, nil
      self.img[k] = img
      M(EG.C.MESH_VISIBLE, L, EG.ICON_MESH, false, k)
    end
    self:Ask(k)
    local ly = y - EG.TILE_HALF * s
    self:Label(2 * k, x, ly - 22, it.name or "")
    self:Label(2 * k + 1, x, ly - 52, it.count or "")
  end

  -- the emblem of tile k: asked for once its instance is built (or BUILD_WAIT frames after it was opened); no emblem =
  -- the neutral plate
  function G:Ask(k)
    local e = self.drawn[k]
    if e == nil or e == 0 or self.asked[k] then
      return
    end
    if self.built[k] == nil and self.frame - (self.opened[k] or self.frame) < EG.BUILD_WAIT then
      return
    end
    local img = self.img[k]
    if img ~= nil then
      -- a caller's picture: its texture loaded once per path, its sprite on the emblem's texture slot when it is in
      local tc = crc(img.texture)
      if not self.loaded[tc] then
        pcall(funcLuaCommand, EG.C.LOAD_TEX, img.texture)
        self.loaded[tc] = self.frame
      end
      local okl, loading = pcall(funcLuaCommand, EG.C.TEX_LOADING, tc)
      if okl and loading == true and self.frame - self.loaded[tc] < EG.LOAD_WAIT then
        return
      end
      M(EG.C.SPRITE, self.tile, tc, crc(img.sprite), EG.ICON_TEX, 0, k)
      self.asked[k] = self.frame
      M(EG.C.MESH_VISIBLE, self.tile, EG.ICON_MESH, true, k)
      return
    end
    M(EG.C.EMBLEM, self.tile, k, EG.ICON_MESH, EG.ICON_TEX, e, 0)
    self.asked[k], self.wait[k] = self.frame, EG.LOAD_WAIT
  end

  function G:Built(layer, inst)
    if layer == self.tile and type(inst) == "number" then
      self.built[inst] = self.frame
      self.asked[inst] = nil
    end
  end

  function G:Draw()
    local page = math.floor(self.sel / self.per)
    for k = 0, self.per - 1 do
      local d = page * self.per + k + 1
      self:Tile(k, d <= #self.items and d or nil)
    end
  end

  function G:Open(items, sel)
    self.items = items or {}
    self.sel = math.max(0, math.min((sel or 1) - 1, #self.items - 1))
    self:KeysReset()
    self:Draw()
    self.log(string.format("emblem grid opened: %d team(s), %d a page%s", #self.items, self.per,
      self.label_ok == false and " (no label layer)" or ""))
  end

  function G:Set(i, item)
    self.items[i] = item
    self:Draw()
  end

  function G:Hide()
    for k = 0, self.per - 1 do
      self:Tile(k, nil)
    end
  end

  function G:Close()
    self:Hide()
    self.items = {}
  end

  function G:Move(to)
    if to < 0 or to >= #self.items or to == self.sel then
      return false
    end
    self.sel = to
    pcall(funcLuaCommand, EG.C.SND, EG.SY_MOVE)
    self:Draw()
    return true
  end

  function G:Hit(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then
      return nil
    end
    local page = math.floor(self.sel / self.per)
    for k = 0, self.per - 1 do
      local d = page * self.per + k
      if d < #self.items then
        local cx, cy = self:Cell(k)
        if math.abs(x - cx) <= self.px / 2 and math.abs(y + cy) <= self.py / 2 then
          return d
        end
      end
    end
    return nil
  end

  function G:Step()
    self.frame = self.frame + 1
    for k = 0, self.per - 1 do
      if self.drawn[k] ~= nil and not self.asked[k] then
        self:Ask(k)
      end
    end
    for k, left in pairs(self.wait) do
      local loading = M(EG.C.LOADING, self.tile, k) == true
      if not loading or left <= 0 then
        M(EG.C.MESH_VISIBLE, self.tile, EG.ICON_MESH, true, k)
        self.wait[k] = nil
      else
        self.wait[k] = left - 1
      end
    end
    local P = {}
    for _, k in ipairs({"back", "rclick", "click", "enter", "all", "l1", "r1", "l2", "r2", "wup", "wdown"}) do
      P[k] = self:Pressed(k)
    end
    for _, k in ipairs({"left", "right", "up", "down"}) do
      P[k] = self:Pressed(k, true)
    end
    if P.back or P.rclick then
      return {act = "back"}
    end
    if P.l2 or P.r2 then
      return {act = "series", dir = P.l2 and -1 or 1}
    end
    local x, y = M(EG.C.POINTER)
    local moved = M(EG.C.POINTER_MOVED) == true
    if type(x) == "number" and (moved or x ~= self.ptr_x or y ~= self.ptr_y) then
      self.ptr_x, self.ptr_y = x, y
      local d = self:Hit(x, y)
      if d ~= nil then
        self:Move(d)
      end
    end
    if P.click then
      local d = self:Hit(x, y)
      if d ~= nil then
        self.sel = d
        return {act = "decide", index = d + 1}
      end
      return nil
    end
    local n, c = #self.items, self.cols
    local col = self.sel % c
    if n == 0 then
      return nil
    end
    if P.left then
      self:Move(col > 0 and self.sel - 1 or math.min(self.sel + c - 1, n - 1))
    elseif P.right then
      self:Move((col < c - 1 and self.sel + 1 < n) and self.sel + 1 or self.sel - col)
    elseif P.up then
      self:Move(self.sel - c >= 0 and self.sel - c or self.sel)
    elseif P.down then
      self:Move(math.min(self.sel + c, n - 1))
    elseif P.l1 or P.wup then
      self:Move(math.max(self.sel - self.per, 0))
    elseif P.r1 or P.wdown then
      self:Move(math.min(self.sel + self.per, n - 1))
    elseif P.enter then
      return {act = "decide", index = self.sel + 1}
    elseif P.all then
      return {act = "all", index = self.sel + 1}
    end
    return nil
  end
end
