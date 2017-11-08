#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <config_loader>
#include <ttt_shop>
#include <multicolors>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Dna Scanner"
#define SHORT_NAME "dnascanner"

int g_iPrice = 0;
int g_iPrio = 0;

bool g_bPrintToAll = false;

bool g_bHasScanner[MAXPLAYERS + 1] =  { false, ... };

char g_sConfigFile[PLATFORM_MAX_PATH] = "";
char g_sPluginTag[PLATFORM_MAX_PATH] = "";
char g_sLongName[64];

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	LoadTranslations("ttt.phrases");

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_sConfigFile);

	Config_LoadString("ttt_plugin_tag", "{orchid}[{green}T{darkred}T{blue}T{orchid}]{lightgreen} %T", "The prefix used in all plugin messages (DO NOT DELETE '%T')", g_sPluginTag, sizeof(g_sPluginTag));

	Config_Done();

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/dnascanner.cfg");
	Config_Setup("TTT-Scanner", g_sConfigFile);

	Config_LoadString("dna_name", "Dnascanner", "The name of the Dnascanner in the Shop", g_sLongName, sizeof(g_sLongName));
	g_iPrice = Config_LoadInt("dna_price", 9000, "The amount of credits a dna scanner costs as detective. 0 to disable.");
	g_iPrio = Config_LoadInt("dna_sort_prio", 0, "The sorting priority of the dna scanner in the shop menu.");
	g_bPrintToAll = Config_LoadBool("dna_print_message_to_all", false, "Print scanner to all players? (Default: false)");
	
	Config_Done();

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnClientDisconnect(int client)
{
	ResetScanner(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetScanner(client);
	}
}

public void OnAllPluginsLoaded()
{
	TTT_RegisterCustomItem(SHORT_NAME, g_sLongName, g_iPrice, TTT_TEAM_DETECTIVE, g_iPrio);
}

void ResetScanner(int client)
{
	g_bHasScanner[client] = false;
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);

			if (role != TTT_TEAM_DETECTIVE)
			{
				return Plugin_Stop;
			}

			g_bHasScanner[client] = true;
		}
	}
	return Plugin_Continue;
}

public Action TTT_OnBodyChecked(int client, int[] iRagdollC)
{
	if (iRagdollC[Scanned])
	{
		return Plugin_Continue;
	}

	if (!TTT_IsClientValid(client))
	{
		return Plugin_Continue;
	}

	if (TTT_GetClientRole(client) != TTT_TEAM_DETECTIVE || g_bHasScanner[client] == false)
	{
		return Plugin_Continue;
	}

	if (iRagdollC[Attacker] > 0 && iRagdollC[Attacker] != iRagdollC[Victim])
	{
		if (g_bPrintToAll)
		{
			LoopValidClients(j)
			{
				CPrintToChat(j, g_sPluginTag, "Detective scan found body", j, client, iRagdollC[AttackerName], iRagdollC[Weaponused]);
			}
		}
		else
		{
			CPrintToChat(client, g_sPluginTag, "Detective scan found body", client, client, iRagdollC[AttackerName], iRagdollC[Weaponused]);
		}
	}
	else
	{
		if (g_bPrintToAll)
		{
			LoopValidClients(j)
			{
				CPrintToChat(j, g_sPluginTag, "Detective scan found body suicide", j, client);
			}
		}
		else
		{
			CPrintToChat(client, g_sPluginTag, "Detective scan found body suicide", client, client);
		}
	}

	iRagdollC[Scanned] = true;

	return Plugin_Changed;
}
