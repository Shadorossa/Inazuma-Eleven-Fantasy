-- menu_engine: VRFW_ScreenArt, the art of the framework's own screens (VRFW 2.4.51, docs/framework/screen-art.md).
-- The chain board and the contact map draw their plates, icons and backgrounds by ROLE ("tile_open", "icon_lock",
-- "background", ...): a role is a sprite some mod declares (content\screen_art\*.toml, `VRFW.screen_art/1`, served by
-- the framework's script screen_art.lua through CMND_VRFW_SCREEN_ART), else the screen's plain fallback: a shape of the
-- framework's neutral atlas vrfw_plain (square, circle, ring, arrows, a face mask, a blank), tinted. The framework ships
-- no other picture for these screens. Definitions only (this file runs in every script VM, lua\_all;
-- no engine call at load: a screen's art is read at its first use, once per VM).
if VRFW_ScreenArt == nil then
  local A = {
    CMD = 4208389390,            -- CMND_VRFW_SCREEN_ART (screen) -> { [role] = { atlas, sprite, mod } }
    LOG = 3661580131,            -- CMND_EVT_LOG
    PLAIN = "#/menu/220_img/vrfw_plain/vrfw_plain.g4tx",
    art = {},                    -- screen -> role -> { atlas, sprite, tex, crc }
  }
  VRFW_ScreenArt = A

  local function log(...)
    pcall(funcLuaCommand, A.LOG, "vrfw.ScreenArt", ...)
  end

  -- the declared roles of a screen (read once per VM): role -> { atlas, sprite, tex = crc32(atlas), crc = crc32(sprite) }
  function A.Get(screen)
    local t = A.art[screen]
    if t ~= nil then
      return t
    end
    t = {}
    A.art[screen] = t
    local ok, got = pcall(funcLuaCommand, A.CMD, screen)
    local n = 0
    if ok and type(got) == "table" then
      for role, a in pairs(got) do
        if type(a) == "table" and type(a.atlas) == "string" and type(a.sprite) == "string" then
          t[role] = { atlas = a.atlas, sprite = a.sprite, tex = CRC32(a.atlas), crc = CRC32(a.sprite) }
          n = n + 1
        end
      end
    end
    if n == 0 then
      log(screen, "no mod declares its art: plain fallback (vrfw_plain)")
    else
      log(screen, n, "declared role(s)")
    end
    return t
  end

  -- one declared role of a screen (nil = none: draw the fallback)
  function A.Role(screen, role)
    return A.Get(screen)[role]
  end

  -- the atlases a screen's declared art uses (each once): the screen asks them with CMND_LOAD_TEX
  function A.Atlases(screen)
    local seen, out = {}, {}
    for _, a in pairs(A.Get(screen)) do
      if not seen[a.atlas] then
        seen[a.atlas] = true
        out[#out + 1] = a.atlas
      end
    end
    return out
  end

  -- a shape of the plain atlas: its texture crc, sprite crc ("square", "circle", "ring", "arrow_l", "arrow_r", "mask",
  -- "blank")
  function A.Plain(shape)
    return CRC32(A.PLAIN), CRC32("vrfw_plain_" .. shape)
  end
end
