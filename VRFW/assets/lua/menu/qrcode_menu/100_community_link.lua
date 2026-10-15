-- community_link (VRFW mechanism; no content of its own): the retail «Inazuma Post»
-- window (qrcode_menu, opened from the title with Alt) shows the community invite a mod DECLARES
-- ([[VRFW.CommunityLink]] in its content\community_links\), and Accept / a left click opens it.
--
-- * Body: the declaration's `body` text row (menu_text of the declaring mod; CMND_TEXT_GET in the game's language)
--   with {url} / {creator} / {title} filled from CMND_VRFW_COMMUNITY_INFO, written into the window's text node
--   _text_win04 when the window opens. No declaration / no row: the retail text stays.
-- * Open: the declaring mod's menu patch turns the window's CMD_ENTER_CLICK row (left click / Enter / A; retail: close)
--   into CMD_FUNCTION vrfw_community_open; OnFunction (the script has none: create) asks the plugin to open the
--   declared invite (CMND_VRFW_COMMUNITY_OPEN takes no argument: the Lua never hands a URL to the shell). Without that
--   patch the function never comes and the window behaves as retail.
-- No engine call at load time.

local CL = {
  INFO = 3141487640,        -- CMND_VRFW_COMMUNITY_INFO () -> url, creator, title, label crc, body crc
  OPEN = 3569811179,        -- CMND_VRFW_COMMUNITY_OPEN () -> started
  TEXT_GET = 4074371074,    -- CMND_TEXT_GET (id) -> string
  SET_TEXT = 1083631230,    -- CMND_SET_MENU_TEXT_STRING (layer, node, string, idx)
  SE = 1917805374,          -- play a system sound
  SE_OK = 3848881948,       -- sy0000
  SE_NG = 2086672038,       -- sy0003
  FN_OPEN = 1801650413,     -- crc32("vrfw_community_open"): the CMD_FUNCTION of the declaring mod's menu patch
  LAYER = 292844459,        -- general_win
  NODE = 1119493378,        -- _text_win04
}

local function CL_Call(f, ...)
  local r = table.pack(pcall(f, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

-- the body in the game's language, or nil (no declaration, no body row)
local function CL_Body()
  local url, creator, title, _, body = CL_Call(funcLuaCommand, CL.INFO)
  if type(url) ~= "string" or url == "" or type(body) ~= "number" or body == 0 then
    return nil
  end
  local f = CL_Call(funcLuaCommand, CL.TEXT_GET, body)
  if type(f) ~= "string" or f == "" then
    return nil
  end
  local function lit(s)
    return (string.gsub(tostring(s or ""), "%%", "%%%%"))
  end
  f = string.gsub(f, "{url}", lit(url))
  f = string.gsub(f, "{creator}", lit(creator))
  f = string.gsub(f, "{title}", lit(title))
  return f
end

if VRFW_Host ~= nil and type(OnOpenLayer) == "function" then
  VRFW_Host.on("qrcode_menu", "OnOpenLayer", {
    id = "menu_engine.community_link", phase = "after",
    fn = function(r, a1, a2)
      if a1 == CL.LAYER then
        local s = CL_Body()
        if s ~= nil then
          funcLuaMenuCommand(CL.SET_TEXT, CL.LAYER, CL.NODE, s, a2 or 0)
        end
      end
    end,
  })
  VRFW_Host.on("qrcode_menu", "OnFunction", {
    id = "menu_engine.community_link", phase = "around", create = true,
    fn = function(nxt, a1, ...)
      if a1 == CL.FN_OPEN then
        local ok = CL_Call(funcLuaCommand, CL.OPEN)
        CL_Call(funcLuaCommand, CL.SE, ok and CL.SE_OK or CL.SE_NG)
        return
      end
      return nxt(a1, ...)
    end,
  })
end
