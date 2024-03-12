------------------------------------------
--  This file holds menu related items  --
------------------------------------------

function ulx.donate(calling_ply)
	calling_ply:SendLua([[gui.OpenURL( "]] .. GetConVar("donate_url"):GetString() .. [[" )]]);
end
local donate = ulx.command("Menus", "ulx donate", ulx.donate, "!donate");
donate:defaultAccess(ULib.ACCESS_ALL);
donate:help("View donation information.");

function ulx.discord(calling_ply)
	calling_ply:SendLua([[gui.OpenURL( "]] .. GetConVar("discord_url"):GetString() .. [[" )]]);
end
local discord = ulx.command("Menus", "ulx discord", ulx.discord, "!disc");
discord:defaultAccess(ULib.ACCESS_ALL);
discord:help("View Discord invite.");
local discord2 = ulx.command("Menus", "ulx discord", ulx.discord, "!discord");
discord2:defaultAccess(ULib.ACCESS_ALL);
discord2:help("View Discord invite.");

function ulx.collection(calling_ply)
	calling_ply:SendLua([[gui.OpenURL( "]] .. GetConVar("collection_url"):GetString() .. [[" )]]);
end
local collection = ulx.command("Menus", "ulx collection", ulx.collection, "!collection");
collection:defaultAccess(ULib.ACCESS_ALL);
collection:help("View server addons collection.");

function ulx.soundlist(calling_ply)
	calling_ply:ConCommand("menu_sounds");
end
local soundlist = ulx.command("Menus", "ulx soundlist", ulx.soundlist, {"!sounds", "!soundlist", "!listsounds"});
soundlist:defaultAccess(ULib.ACCESS_ALL);
soundlist:help("Open the sound list.");
