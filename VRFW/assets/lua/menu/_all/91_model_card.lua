-- VRFW model cards, game Lua side (every menu VM; script side scripts\model_card.lua; docs/framework/model-card.md).
-- One player's 3D model posed inside a box of the screen: in a team's kit, playing the first clip of a list his motion
-- set holds (the list always ends with the stand), placed and sized so his feet and height fit the box.
-- The model is drawn in the 3D pass: over the background pass, under every normal 2D layer. While a card is up the
-- screen's normal-pass background layers (spec.hide) are hidden and the background-pass copy (spec.backdrop, object
-- vrfw_model_card_backdrop) is shown in their place; the screen's own 2D layers then cover the model where they overlap.
--   local K = VRFW_ModelCard.New(spec)
--     spec.layer     crc of the screen's layer of object vrfw_model_card (instance 0, model slot 0)
--     spec.backdrop  crc of its layer of object vrfw_model_card_backdrop (optional)
--     spec.hide      { layer crc, … } normal-pass layers hidden while the card is up (instance 0; e.g. the retail
--                    mainmenu90_00_background)
--     spec.log       function(...) for the log lines (optional)
--   K.Want(w)       the card the screen wants now (nil = none). w = { card = chara_param, team = team id whose kit
--                   he wears (nil = his own), clips = "pack:clip|…", box = { x, y, w, h } screen px (1920 x 1080, y
--                   down), feet = 0.9 (feet line, part of the box height), centre = 0.5 (part of the box width),
--                   height = 0.8 (the player's height, part of the box height), fit = true (the box is the whole
--                   model's rectangle: sized and placed by content\defaults\model_card.toml [fit], feet / height
--                   unused), static = true (the stand only, clips unused) }. The same card again changes nothing;
--                   another player / kit / clip list / static flag releases the model and builds the new one.
--   K.Step()        every frame (also while the screen closes)
--   K.Hide()        = K.Want(nil)
--   K.Released()    true once no model is held and the frames after its free went by: close the menu object only then
-- One build at a time, the model hidden until the component reports it complete; a release during a load waits for
-- the load (never mid-load). No engine call at load time.
if VRFW_ModelCard == nil then
  local MC = {}
  VRFW_ModelCard = MC

  local CMD = {
    SET_CHARA = 59611540,          -- (layer, idx, chara, slot)
    KIT = 3290636356,              -- (layer, idx, uniform, motion set number, flags, slot)
    BELONG_KIT = 1701330357,       -- (layer, idx, true): a team's kit, as the team dock's view
    MOTION = 180466856,            -- (layer, idx, clip, 0, 0, 0, 0, slot)
    GET_MODEL = 3895705890,        -- (layer, idx, slot) -> model handle (0 = none)
    COMPLETE = 1583438030,         -- (layer, idx, slot) -> the build is complete
    MODEL_VIS = 1890282463,        -- funcLuaCommand (model handle, on)
    LOADING = 2475005551,          -- funcLuaCommand (chara) -> true while that chara's model loads
    TO_MODEL = 347353059,          -- funcLuaCommand (chara_param) -> chara
    TURN_CONTROL = 1195674914,     -- (layer, idx, on): the right stick turns the model
    ROT = 2463117189,              -- (layer, idx, rx, ry, rz)
  }
  local SETTLE, MAX_FRAMES, FREE_FRAMES = 2, 180, 2
  -- the shop01_01_list_base meshes a card hides, at its open and on every setup of its layer: the scroll bar only (the
  -- dummy _dmy01 is where the model stands: hidden, the model is never made and the card has no model handle)
  local SCROLL_MESHES = { "_scr_line01", "_scr_obj01" }
  local KEY = nil                  -- the model key of every card: crc32("vrfw_model_card") (computed at first use)

  local function M(...)
    local r = table.pack(pcall(funcLuaMenuCommand, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end
  local function F(...)
    local r = table.pack(pcall(funcLuaCommand, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end

  -- the layers of the cards made in this VM (layer crc -> true): each setup of one hides the shop list base's scroll
  -- line and scroll knob (left shown they draw a thin white line down the screen)
  MC.layers = {}
  local function HideShopParts(layer, idx)
    for _, mesh in ipairs(SCROLL_MESHES) do M(VRFW_Cmd.SET_MESH_VISIBLE, layer, VRFW_Crc32(mesh), false, idx or 0) end
  end
  -- the screen's OnSetupLayer wrapped once (again only when the screen defined a new one); called from MC.New (OnInit)
  local function WatchSetup()
    if OnSetupLayer == MC.setup or type(OnSetupLayer) ~= "function" then return end
    local inner = OnSetupLayer
    MC.setup = function(a1, a2, ...)
      local r = table.pack(inner(a1, a2, ...))
      if MC.layers[a1] then HideShopParts(a1, a2) end
      return table.unpack(r, 1, r.n)
    end
    OnSetupLayer = MC.setup
  end

  local function same(a, b)
    if a == nil or b == nil then return a == b end
    return a.card == b.card and a.team == b.team and a.clips == b.clips and a.static == b.static
  end

  -- two boxes of the same place and size (a screen may pass a new box table every frame)
  local function same_box(a, b)
    if a == nil or b == nil then return a == b end
    return a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h
  end

  -- fit = true: the camera distance at which the [fit] envelope (top_m above the feet, below_m under them, width_m
  -- wide) fills the box minus margin_px on every side, and the feet line it gives (screen px)
  local function FitBox(b, fit, ppm1, centre)
    local m = fit.margin_px or 6
    local top, below, wide = fit.top_m or 2.1, fit.below_m or 0.03, fit.width_m or 1.1
    local bw, bh = math.max(20, (b.w or 450) - 2 * m), math.max(40, (b.h or 742) - 2 * m)
    local d = ppm1 * math.max((top + below) / bh, wide / bw)
    local ppm = ppm1 / d
    local feet = (b.y or 0) + (b.h or 742) - m - below * ppm
    local sx = (b.x or 0) + (b.w or 450) * (centre or 0.5)
    return d, sx, feet
  end

  function MC.New(spec)
    local K = { spec = spec, want = nil, held = nil, free_frames = 0, covered = false, logs = 0, opened = false }
    local layer = spec.layer
    MC.layers[layer] = true
    WatchSetup()

    local function Log(...)
      if spec.log ~= nil and K.logs < 40 then
        K.logs = K.logs + 1
        pcall(spec.log, "model card", ...)
      end
    end

    local function Handle()
      local h = M(CMD.GET_MODEL, layer, 0, 0)
      return type(h) == "number" and h ~= 0 and h or nil
    end

    local function Visible(on)
      local h = Handle()
      if h then F(CMD.MODEL_VIS, h, on) end
    end

    -- the screen's background swapped for the background-pass copy while a model is shown
    local function Cover(on)
      if K.covered == on then return end
      K.covered = on
      for _, l in ipairs(spec.hide or {}) do M(VRFW_Cmd.SET_LAYER_VISIBLE, l, 0, not on) end
      if spec.backdrop then M(VRFW_Cmd.SET_LAYER_VISIBLE, spec.backdrop, 0, on) end
      Log("backdrop", tostring(on))
    end

    -- the place of the model for its box (the camera of content\defaults\model_card.toml)
    local function Place(H)
      local w, cam = H.want, H.camera or {}
      local b = w.box or {}
      H.placed_box = w.box
      local eye_y, eye_z, look_y = cam.eye_y or 2.25, cam.eye_z or 12.5, cam.look_y or 1.6
      local ppm1, tall = cam.px_per_m_at_1m or 3060, cam.player_height or 1.7
      local d, sx, feet
      if w.fit then
        d, sx, feet = FitBox(b, H.fit or {}, ppm1, w.centre)
      else
        local h_px = math.max(40, (b.h or 742) * (w.height or 0.8))
        d = ppm1 * tall / h_px
        sx = (b.x or 0) + (b.w or 450) * (w.centre or 0.5)
        feet = (b.y or 0) + (b.h or 742) * (w.feet or 0.9)
      end
      local z = eye_z - d
      local ppm = ppm1 / d
      local look = look_y + (eye_y - look_y) * z / eye_z
      local x, y = (sx - 960) / ppm, look - (feet - 540) / ppm
      M(VRFW_Cmd.SET_CHARA_MODEL_POS, layer, 0, x, y, z, 0)
      M(CMD.TURN_CONTROL, layer, 0, false)
      M(CMD.ROT, layer, 0, 0, cam.turn or -15, 0)
      Log("placed", w.card, string.format("%.2f %.2f %.2f", x, y, z), w.fit and string.format("fit box %.0f %.0f %.0f %.0f", b.x or 0, b.y or 0, b.w or 0, b.h or 0) or "")
    end

    local function Build(H)
      local w = H.want
      local kit = F(VRFW_Cmd.VRFW_CONTACT_KIT, w.card, w.team or 0)
      local uniform = type(kit) == "table" and tonumber(kit.uniform) or 0
      local flags = type(kit) == "table" and tonumber(kit.flags) or 0
      local motion = 1
      local has, v = F(VRFW_Cmd.GET_CHARA_INFO, w.card, 21)
      if has == true and type(v) == "number" and v ~= 0 then motion = v end
      M(CMD.SET_CHARA, layer, 0, H.chara, 0)
      M(VRFW_Cmd.SET_SCN_CHARA_REGIST_TYPE, layer, 0, 4, 0)
      M(CMD.KIT, layer, 0, uniform, motion, flags, 0)
      if (w.team or 0) ~= 0 and uniform ~= 0 then M(CMD.BELONG_KIT, layer, 0, true) end
      M(CMD.MOTION, layer, 0, H.stand, 0, 0, 0, 0, 0)
      M(VRFW_Cmd.CHARA_MODEL_CHANGE, layer, 0, 0, 9, 0, KEY)
      Visible(false)
      Log("build", w.card, H.chara, string.format("uniform 0x%08X flags %d team %s clip %s", uniform % 4294967296,
        flags, tostring(w.team), tostring(H.clip and H.clip.name)))
    end

    -- a new card: the chara, the clip its motion set holds; built once nothing else loads
    local function Start(w)
      local chara = F(CMD.TO_MODEL, w.card)
      if type(chara) ~= "number" or chara == 0 then
        Log("no chara", w.card)
        return nil
      end
      local base = F(VRFW_Cmd.VRFW_CHARA_BASE, w.card)
      local set = type(base) == "number" and F(VRFW_Cmd.VRFW_CHARA_MOTION_SET, base) or nil
      -- static: no clip list, the stand only (the clip answer still brings the camera and the fit envelope)
      local clips = w.static and "" or (w.clips or "")
      local clip = F(VRFW_Cmd.VRFW_MODEL_CARD_CLIP, type(set) == "string" and set or "", clips)
      if type(clip) ~= "table" then clip = nil end
      return { want = w, chara = chara, set = set, clip = clip, camera = clip and clip.camera or nil,
        fit = clip and clip.fit or nil,
        stand = 2263925137 --[[立ち1L]], phase = "wait", n = 0, ok = 0 }
    end

    local function Free()
      Visible(false)
      M(CMD.SET_CHARA, layer, 0, 0, 0)
      M(VRFW_Cmd.CHARA_MODEL_CHANGE, layer, 0, 0, 9, 0, KEY)
      Log("released", K.held and K.held.want.card)
      K.held = nil
      K.free_frames = FREE_FRAMES
    end

    local function Busy(H)
      return H.phase == "load" or F(CMD.LOADING, H.chara) == true
    end

    function K.Want(w)
      if w ~= nil and (w.card or 0) == 0 then w = nil end
      if same(w, K.want) then
        if w ~= nil and K.held ~= nil then K.held.want.box = w.box end
        return
      end
      K.want = w
      if K.held ~= nil then K.held.leaving = true end
      if w == nil then Visible(false) Cover(false) end
    end

    function K.Hide() K.Want(nil) end

    function K.Released()
      return K.held == nil and K.want == nil and K.free_frames <= 0
    end

    function K.Step()
      if KEY == nil then KEY = VRFW_Crc32("vrfw_model_card") end
      if not K.opened then
        K.opened = true
        if spec.backdrop then M(VRFW_Cmd.SET_LAYER_VISIBLE, spec.backdrop, 0, false) end
        M(VRFW_Cmd.OPEN_LAYER, layer, 0)
        -- the shop list base's scroll bar is not part of a card
        HideShopParts(layer, 0)
      end
      if K.free_frames > 0 then
        K.free_frames = K.free_frames - 1
        return
      end
      local H = K.held
      -- the held model is no longer wanted: freed once its load is done
      if H ~= nil and H.leaving then
        Visible(false)
        if H.phase == "load" and H.n < MAX_FRAMES then
          H.n = H.n + 1
          if M(CMD.COMPLETE, layer, 0, 0) ~= true then return end
        end
        Free()
        return
      end
      if H == nil then
        if K.want == nil then return end
        H = Start(K.want)
        if H == nil then
          K.want = nil
          Cover(false)
          return
        end
        K.held = H
      end
      H.n = H.n + 1
      if H.phase == "wait" then
        if F(CMD.LOADING, H.chara) == true and H.n < MAX_FRAMES then return end
        Build(H)
        H.phase, H.n, H.ok = "load", 0, 0
      elseif H.phase == "load" then
        if M(CMD.COMPLETE, layer, 0, 0) == true then H.ok = H.ok + 1 else H.ok = 0 end
        if H.ok < SETTLE and H.n < MAX_FRAMES then return end
        Place(H)
        local c = H.clip
        if c ~= nil and c.attach then
          local h = Handle()
          local done, why = false, "no model handle"
          if h then done, why = F(VRFW_Cmd.VRFW_MODEL_CARD_PACK, h, c.pack) end
          Log("pack", c.pack, tostring(done), tostring(why))
          if done ~= true then
            -- the pack did not load: the stand stays (never a clip the model cannot play)
            H.clip = nil
          end
          H.phase, H.n = "pack", 0
        else
          H.phase, H.n = "play", 0
        end
      elseif H.phase == "pack" then
        local frames = H.camera and H.camera.pack_frames or 6
        if H.n < frames then return end
        H.phase, H.n = "play", 0
      elseif H.phase == "play" then
        if H.clip ~= nil and H.clip.clip ~= H.stand then M(CMD.MOTION, layer, 0, H.clip.clip, 0, 0, 0, 0, 0) end
        Log("shown", H.want.card, H.clip and H.clip.name or "stand")
        Cover(true)
        Visible(true)
        H.phase = "up"
      elseif H.phase == "up" then
        if not same_box(H.placed_box, H.want.box) then Place(H) end
      end
    end

    return K
  end
end
