-- ===== EVT ui_clean mods_menu layout BEGIN =====
-- clean_hud's adaptation of the VR-Framework «Mods» screen (vrfw_mods_menu, mod mods_menu) to the short menu header
-- (bar 67 px instead of the retail 122 px): the screen's top row (tabs, search, Ver / Orden / Perfil), the restart
-- notice and everything under them move up 55 px. The screen itself is laid out for the retail header and reads this
-- global in its OnInit (CE.ApplyLayout), so the order of the mods' Lua roots does not matter. Without clean_hud the
-- screen keeps the retail layout. No engine call here (chunk load).
VRFW_MM_LAYOUT = VRFW_MM_LAYOUT or {}
VRFW_MM_LAYOUT.top_dy = -55
-- ===== EVT ui_clean mods_menu layout END =====
