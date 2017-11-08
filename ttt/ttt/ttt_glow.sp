#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <ttt>
#include <CustomPlayerSkins>
#include <config_loader>

#undef REQUIRE_PLUGIN
#include <ttt_wallhack>
#include <ttt_tagrenade>
#define REQUIRE_PLUGIN

int g_iColorInnocent[3] =  {0, 255, 0};
int g_iColorTraitor[3] =  {255, 0, 0};
int g_iColorDetective[3] =  {0, 0, 255};

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Glow"

bool g_bDGlow = false;
bool g_bTGlow = false;

char g_sConfigFile[PLATFORM_MAX_PATH] = "";

bool g_bCPS = false;
bool g_bWallhack = false;
bool g_bTAGrenade = false;

bool g_bDebug = false;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Bara & zipcore",
	description = TTT_PLUGIN_DESCRIPTION,
	version = "My_Version.1",
	url = TTT_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ttt_glow");

	return APLRes_Success;
}

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/glow.cfg");

	Config_Setup("TTT-Glow", g_sConfigFile);

	g_bDGlow = Config_LoadBool("glow_detective_enable", true, "Detectives see the glows of other detectives. 0 to disable.");
	g_bTGlow = Config_LoadBool("glow_traitor_enable", true, "Traitors see the glows of other traitors. 0 to disable.");

	Config_Done();

	g_bCPS = LibraryExists("CustomPlayerSkins");
	g_bWallhack = LibraryExists("ttt_wallhack");
	g_bTAGrenade = LibraryExists("ttt_tagrenade");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "CustomPlayerSkins"))
	{
		g_bCPS = true;
	}
	
	if (StrEqual(name, "ttt_wallhack"))
	{
		g_bWallhack = true;
	}
	
	if (StrEqual(name, "ttt_tagrenade"))
	{
		g_bTAGrenade = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "CustomPlayerSkins"))
	{
		g_bCPS = false;
	}
	
	if (StrEqual(name, "ttt_wallhack"))
	{
		g_bWallhack = false;
	}
	
	if (StrEqual(name, "ttt_tagrenade"))
	{
		g_bTAGrenade = false;
	}
}

public void OnAllPluginsLoaded()
{
	if (!g_bCPS)
	{
		SetFailState("CustomPlayerSkins not loaded!");
	}
	else
	{
		CreateTimer(0.3, Timer_SetupGlow, _, TIMER_REPEAT);
	}
}

public Action Timer_SetupGlow(Handle timer, any data)
{
	if(!TTT_IsRoundActive())
	{
		return Plugin_Continue;
	}

	LoopValidClients(i)
	{
		if (TTT_GetClientRole(i) != TTT_TEAM_INNOCENT) {
			SetupGlowSkin(i);
		}
	}

	return Plugin_Continue;
}

void SetupGlowSkin(int client)
{
	UnHookSkin(client);
	CPS_RemoveSkin(client);

	if (!TTT_IsRoundActive())
	{
		return;
	}

	if (!g_bDebug && (IsFakeClient(client) || IsClientSourceTV(client)))
	{
		return;
	}

	if (!IsPlayerAlive(client))
	{
		return;
	}

	if (!g_bDGlow && TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
	{
		return;
	}

	if (!g_bTGlow && TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
	{
		return;
	}

	char model[PLATFORM_MAX_PATH];
	GetClientModel(client, model, sizeof(model));
	int skin = CPS_SetSkin(client, model, CPS_RENDER);

	if(skin == -1)
	{
		return;
	}
	if (SDKHookEx(skin, SDKHook_SetTransmit, OnSetTransmit_GlowSkin))
	{
		SetupGlow(client, skin);
	}
}

void UnHookSkin(int client)
{
	if(CPS_HasSkin(client))
	{
		int skin = EntRefToEntIndex(CPS_GetSkin(client));

		if(IsValidEntity(skin))
		{
			SDKUnhook(skin, SDKHook_SetTransmit, OnSetTransmit_GlowSkin);
		}
	}
}

void SetupGlow(int client, int skin)
{
	int iOffset;

	if ((iOffset = GetEntSendPropOffs(skin, "m_clrGlow")) == -1)
	{
		return;
	}

	SetEntProp(skin, Prop_Send, "m_bShouldGlow", true, true);
	SetEntProp(skin, Prop_Send, "m_nGlowStyle", 0);
	SetEntPropFloat(skin, Prop_Send, "m_flGlowMaxDist", 10000000.0);

	int iRed = 255;
	int iGreen = 255;
	int iBlue = 255;

	if (TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
	{
		iRed = g_iColorDetective[0];
		iGreen = g_iColorDetective[1];
		iBlue = g_iColorDetective[2];
	}
	else if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
	{
		iRed = g_iColorTraitor[0];
		iGreen = g_iColorTraitor[1];
		iBlue = g_iColorTraitor[2];
	}
	else if (TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
	{
		iRed = g_iColorInnocent[0];
		iGreen = g_iColorInnocent[1];
		iBlue = g_iColorInnocent[2];
	}

	SetEntData(skin, iOffset, iRed, _, true);
	SetEntData(skin, iOffset + 1, iGreen, _, true);
	SetEntData(skin, iOffset + 2, iBlue, _, true);
	SetEntData(skin, iOffset + 3, 255, _, true);
}

public Action OnSetTransmit_GlowSkin(int skin, int client)
{
	int target = -1;
	LoopValidClients(i)
	{
		if (i < 1)
		{
			continue;
		}

		if (client == i)
		{
			continue;
		}

		if (!g_bDebug && IsFakeClient(i))
		{
			continue;
		}

		if (!IsPlayerAlive(i))
		{
			continue;
		}

		if (!CPS_HasSkin(i))
		{
			continue;
		}

		if (EntRefToEntIndex(CPS_GetSkin(i)) != skin)
		{
			continue;
		}

		target = i;
	}
	
	int iRole = TTT_GetClientRole(client);
	int iTRole = TTT_GetClientRole(target);
	
	if ((iRole == TTT_TEAM_DETECTIVE || iRole == TTT_TEAM_TRAITOR) && g_bWallhack && TTT_HasActiveWallhack(client))
	{
		return Plugin_Continue;
	}
	
	if (iRole == TTT_TEAM_TRAITOR && g_bTAGrenade && TTT_CheckTAGrenade(client, target))
	{
		return Plugin_Continue;
	}
	
	if (iRole == TTT_TEAM_DETECTIVE && iRole == iTRole)
	{
		return Plugin_Continue;
	}

	if (iRole == TTT_TEAM_TRAITOR && iRole == iTRole)
	{
		return Plugin_Continue;
	}

	return Plugin_Handled;
}
