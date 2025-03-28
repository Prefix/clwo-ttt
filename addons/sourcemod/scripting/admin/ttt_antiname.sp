#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#include <colorlib>
#include <generics>
#include <ttt_messages>

int lastChange[MAXPLAYERS + 1];

public OnPluginStart()
{
	RegisterCmds();
	HookEvents();
	InitDBs();
	
	PrintToServer("[ATN] Loaded succcessfully");
}

public void RegisterCmds() {
}

public void HookEvents() {
	HookEvent("player_changename", OnChangeName, EventHookMode_PostNoCopy);
}

public void InitDBs() {
}

public Action OnChangeName(Event event, const char[] name, bool dontBroadcast) {
	char oldName[64], newName[64];

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!client)
    {
		return Plugin_Continue;
	}

	int now = GetTime();
	if (now - lastChange[client] <= 2)
    {
		return Plugin_Continue;
	}

	lastChange[client] = now;

	event.GetString("oldname", oldName, sizeof(oldName));
	event.GetString("newname", newName, sizeof(newName));

	if (!StrEqual(oldName, newName) && IsPlayerAlive(client))
    {
		CPrintToChat(client, TTT_ERROR ... "Sorry, you are not allowed to change your name whilst alive.");
		SetClientName(client, oldName);

		return Plugin_Stop;
	}

	return Plugin_Continue;
}