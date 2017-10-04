#include <ttt_helpers>
#include <player_methodmap>

#include <general>

Handle timer_end_beacons;

char urls[6][3][512] = {
	{ "sm_rules", "https://clwo.eu/thread-1614-post-15525.html#pid15525", "Opens the rules page" },
	{ "sm_clwo", "https://clwo.eu", "Opens the CLWO page" },
	{ "sm_group", "https://steamcommunity.com/groups/ClassyWolves", "Opens the Steam group page" },
	{ "sm_new", "https://clwo.eu/thread-2123-post-21215.html#pid21215", "Opens the new player page" },
	{ "sm_google", "https://google.com", "Opens the Google search page" },
	{ "sm_gametracker", "https://www.gametracker.com/server_info/ttt.clwo.eu:27015", "Opens the TTT Gametracker page" },
}

public void OnPluginStart() {
	RegAdminCmd("sm_cbeacon", command_toggle_beacon, ADMFLAG_GENERIC);
	//RegAdminCmd("sm_volume", command_volume, ADMFLAG_GENERIC);
	RegAdminCmd("sm_profile", command_profile, ADMFLAG_GENERIC);
	RegAdminCmd("sm_tp", command_toggle_third_person, ADMFLAG_CHEATS);
	RegAdminCmd("sm_reload", command_reload_plugin, ADMFLAG_CHEATS);

	LoadTranslations("common.phrases");

	for (int url = 0; url < sizeof(urls); url++) {
		RegConsoleCmd(urls[url][0], command_open_url, urls[url][2])
	}

	database_ttt = ConnectDatabase("ttt", "ttt");
	database_player_analytics = ConnectDatabase("player_analytics", "P_A");

	cookie_player_experience = RegClientCookie("player_experience", "Current experience player has.", CookieAccess_Private);
	cookie_player_level = RegClientCookie("player_level", "Current player level.", CookieAccess_Private);
	cookie_player_volume = RegClientCookie("player_volume", "Current player volume as percentage", CookieAccess_Private);

	HookEvent("round_start", OnRoundStart);
	HookEvent("round_end", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_death", OnPlayerDeath);

	CreateTimer(1.5, timer_beacon, 0, TIMER_REPEAT);

	LoopClients(client) if (AreClientCookiesCached(client)) OnClientCookiesCached(client);
}

public void OnMapStart() {
    sprite_beam = PrecacheModel("materials/sprites/laserbeam.vmt");
    sprite_halo = PrecacheModel("materials/sprites/glow.vmt");
}

OnClientDisconnect(int client) {
	player_beacon[client] = false;
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	player_beacon[client] = false;
	third_person[client] = false;

	return Plugin_Continue;
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
	//CPrintToChatAll("{purple}[TTT] {yellow}Debug: Round Start Event Fired")
	timer_end_beacons = CreateTimer(210.0, timer_beacon_all);

	LoopAliveClients(client) {
		Player player = Player(client);
		if (player.has_clan_tag && player.armour == 0) {
			player.armour += 10;
		}
	}

	return Plugin_Continue;
}

public Action OnRoundEnd(Event event, const char[] name, bool dontBroadcast) {
	LoopClients(client) {
		player_beacon[client] = false;
		third_person[client] = false;
	}

	//CPrintToChatAll("{purple}[TTT] {yellow}Debug: Round End Event Fired")
	KillTimer(timer_end_beacons);
	return Plugin_Continue;
}

OnClientCookiesCached(int client) {
	Player player = Player(client);
	// player.volume = player.volume;
}

public Action command_toggle_beacon(int client, int args) {
	if (args == 0) {
		Player(client).toggle_beacon();
	} else if (args == 1) {
		char target[128], target_name[128];
		int targets[MAXPLAYERS];

		GetCmdArg(1, target, sizeof(target));
		int response = Player(client).target(target, targets, target_name, true, false);

		for (int i = 0; i < sizeof(targets); i++) {
			if (targets[i]) {
				Player(targets[i]).toggle_beacon();
			} else {
				break;
			}
		}

		if (response > 0) {
			CPrintToChat(client, "{purple}[TTT] {yellow}Toggled beacons on %s.", target_name);
		}
	}
	
	return Plugin_Handled;
}

public Action command_volume(int client, int args) {
	if (args != 2) {
		CPrintToChat(client, "{purple}[TTT] {orchid}Invalid command usage, expects: /volume <target> <percentage>");
		return Plugin_Handled;
	}

	char target[128], volume_string[128];
	GetCmdArg(1, target, sizeof(target));
	GetCmdArg(2, volume_string, sizeof(volume_string));

	int target_player = Player(client).target_one(target)
	if (target_player == -1) return Plugin_Handled;

	float volume = StringToFloat(volume_string);
	if (volume == 0.0) volume = 100.0;

	Player(target_player).volume = volume;

	CPrintToChat(client, "{purple}[TTT] {yellow}Set volume on %N to %.0f%s.", target_player, volume, "%%");

	return Plugin_Handled;
}

public Action command_toggle_third_person(int client, int args) {
	if (args == 0) {
		Player(client).toggle_third_person();
	} else if (args == 1) {
		char target[128], target_name[128];
		int targets[MAXPLAYERS];

		GetCmdArg(1, target, sizeof(target));
		int response = Player(client).target(target, targets, target_name, true, false);

		for (int i = 0; i < sizeof(targets); i++) {
			if (targets[i]) {
				Player(targets[i]).toggle_third_person();
			} else {
				break;
			}
		}

		if (response > 0) {
			CPrintToChat(client, "{purple}[TTT] {yellow}Toggled third person on %s.", target_name);
		}
	}
	
	return Plugin_Handled;
}

public Action command_reload_plugin(int client, int args) {
	if (args == 0) {
		CPrintToChat(client, "{purple}[TTT] {orchid}Invalid usage, /reload <plugin_name>");
		return Plugin_Handled;
	}

	char plugin_name[128]
	GetCmdArg(1, plugin_name, sizeof(plugin_name));

	char load[1024], reload[1024];
	ServerCommandEx(load, sizeof(load), "sm plugins load %s", plugin_name);
	PrintToConsole(client, load);
	ServerCommandEx(reload, sizeof(reload), "sm plugins reload %s", plugin_name);
	PrintToConsole(client, reload);
	CPrintToChat(client, "{purple}[TTT] {yellow}Reloaded %s successfully!", plugin_name);

	return Plugin_Handled;
}

public Action command_profile(int client, int args) {
	if (args == 0) {
		Player(client).profile(client);
	} else if (args == 1) {
		char target[128];

		GetCmdArg(1, target, sizeof(target));
		int target_client = Player(client).target_one(target);

		if (target_client != -1) {
			Player(client).profile(target_client);
		} else {
			CPrintToChat(client, "{purple}[TTT] {orchid}Invalid URL.  This code should be unreachable.")
		}
	}
	
	return Plugin_Handled;
}

public Action command_open_url(int client, int args) {
	char page[128];
	GetCmdArg(0, page, sizeof(page));

	for (int url = 0; url < sizeof(urls); url++) {
		if (strcmp(page, urls[url][0]) == 0) {
			Player(client).display_url(urls[url][1])
			return Plugin_Handled;
		}
	}

	CPrintToChat(client, "{purple}[TTT] {orchid}Invalid URL.  This code should be unreachable.");
	return Plugin_Handled;
}

public Action timer_beacon(Handle Timer) {
	LoopAliveClients(client) {
		Player player = Player(client);
		//CPrintToChatAll("{purple}[TTT] {yellow}Debug: Testing Ping For: %N", client);
		if (player.beacon_enabled) {
			//CPrintToChatAll("{purple}[TTT] {yellow}Debug: Beacon Ping For: %N", client);
			player.beacon_ping(colour_cyan)
		}
	}
}

public Action timer_beacon_all(Handle Timer) {
	CPrintToChatAll("{purple}[TTT] {yellow}There's only one minute thirty left!");
	LoopAliveClients(client) {
		//CPrintToChatAll("{purple}[TTT] {yellow}Debug: Enabled Beacon For: %N", client);
		Player(client).beacon_enabled = true;
	}
}