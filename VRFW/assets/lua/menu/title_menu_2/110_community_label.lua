-- community_label (VRFW mechanism, docs/framework/community-link.md; no content of its own): the title corner label of
-- the community window (layer title00_10_inazuma_post, retail «<Alt> Inazuma Post») reads the `label` text row of the
-- community link a mod declares ([[VRFW.CommunityLink]], CMND_VRFW_COMMUNITY_INFO; {title} / {creator} / {url} filled)
-- when the layer opens; its text plate is refitted. No declaration / no label row: the retail label stays. The icon
-- next to it is the declaring mod's image (its own image declaration of title00_10). Also the game-update notice of an
-- unknown build. No engine call at load time.

local CLB = {
  LAYER = 399128006,        -- title00_10_inazuma_post
  NODE = 2199506815,        -- _text_inazumapost01
  INFO = 3141487640,        -- CMND_VRFW_COMMUNITY_INFO () -> url, creator, title, label crc, body crc
  TEXT_GET = 4074371074,    -- CMND_TEXT_GET (id) -> string
  SET_TEXT = 1083631230,    -- CMND_SET_MENU_TEXT_STRING (layer, node, string, idx)
  TEXT_PLATE = 1172899594,  -- refit the text plate (layer, idx, node)
  UPDATE = 1526988990,      -- CMND_VRFW_GAME_UPDATE () -> unknown build, features + mod declarations off
  TX_UPDATE = 2082649789,   -- crc32("vrfw_game_update_notice") («Unknown game version: {n} functions off - see the report»)
}

local function CLB_Call(f, ...)
  local r = table.pack(pcall(f, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

-- an unknown game build (docs/framework/game-updates.md): the label reads the game-update notice instead
local function CLB_Update()
  local unknown, n = CLB_Call(funcLuaCommand, CLB.UPDATE)
  if unknown ~= true then
    return nil
  end
  local f = CLB_Call(funcLuaCommand, CLB.TEXT_GET, CLB.TX_UPDATE)
  if type(f) ~= "string" or f == "" then
    return nil
  end
  return (string.gsub(f, "{n}", tostring(math.floor(tonumber(n) or 0))))
end

local function CLB_Label()
  local u = CLB_Update()
  if u ~= nil then
    return u
  end
  local url, creator, title, label = CLB_Call(funcLuaCommand, CLB.INFO)
  if type(url) ~= "string" or url == "" or type(label) ~= "number" or label == 0 then
    return nil
  end
  local f = CLB_Call(funcLuaCommand, CLB.TEXT_GET, label)
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
  VRFW_Host.on("title_menu_2", "OnOpenLayer", {
    id = "menu_engine.community_label", phase = "after",
    fn = function(r, a1, a2)
      if a1 == CLB.LAYER then
        local s = CLB_Label()
        if s ~= nil then
          CLB_Call(funcLuaMenuCommand, CLB.SET_TEXT, CLB.LAYER, CLB.NODE, s, a2 or 0)
          CLB_Call(funcLuaMenuCommand, CLB.TEXT_PLATE, CLB.LAYER, a2 or 0, CLB.NODE)
        end
      end
    end,
  })
end
