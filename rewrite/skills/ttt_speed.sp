#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#include <ttt>
#include <colorvariables>
#include <generics>
#include <ttt_skills>

#define SPEED_MAX_LEVEL 4

public Plugin myinfo =
{
    name = "TTT Speed",
    author = "Popey & c0rp3n",
    description = "TTT Speed Skill",
    version = "0.0.1",
    url = ""
};

int errorTimeout[MAXPLAYERS + 1];

float lastTime[MAXPLAYERS+1] = { 0.0, ... };
int cooldownEndTime[MAXPLAYERS+1] = { 0, ... };

bool isInCooldown[MAXPLAYERS+1] = { false, ... };
bool isUsingSpeed[MAXPLAYERS+1] = { false, ... };
bool keyPressed[MAXPLAYERS+1] = { false, ... };

Handle speedCooldownTimers[MAXPLAYERS+1] = { INVALID_HANDLE, ... };

public OnPluginStart()
{
    LoadTranslations("common.phrases");

    PrintToServer("[SPD] Loaded successfully");
}

public OnAllPluginsLoaded()
{
    Skills_RegisterSkill(Skill_Speed, "Speed", "Grants the player double movement speed for a short period of time.", SPEED_MAX_LEVEL);
}

public OnClientDisconnect(int client)
{
    ClearTimer(speedCooldownTimers[client]);
}

public void TTT_OnRoundStart(int innocents, int traitors, int detective)
{
    LoopClients(i)
    {
        CallTimer(speedCooldownTimers[i]);
    }
}

public void TTT_OnRoundEnd(int winner)
{
    LoopClients(i)
    {
        CallTimer(speedCooldownTimers[i]);
    }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float velocity[3], float angles[3], int &weapon)
{
    if (!IsAliveClient(client) || !TTT_IsRoundActive()) { return Plugin_Continue; }

    if (isUsingSpeed[client]) { return Plugin_Continue; }

    if (!(buttons & IN_USE))
    {
        if (keyPressed[client]) { keyPressed[client] = false; }

        return Plugin_Continue;
    }

    if (keyPressed[client]) { return Plugin_Continue; }

    if (!keyPressed[client])
    {
        keyPressed[client] = true;

        float currentTime = GetGameTime();
        if (currentTime > lastTime[client] + 0.5)
        {
            lastTime[client] = currentTime;
            return Plugin_Continue;
        }

        lastTime[client] = currentTime;

        int upgradeLevel = Skills_GetSkill(client, Skill_Speed, 0, SPEED_MAX_LEVEL);
        if (upgradeLevel == 0)
        {
            return Plugin_Continue;
        }

        if (isInCooldown[client]) {
            if (!ErrorTimeout(client, 2))
            CPrintToChat(client, "{purple}[TTT] {red}Sprint is on cooldown for another {blue}%d {red}seconds.", cooldownEndTime[client] - GetTime());

            return Plugin_Continue;
        }

        int cooldownTime = 120 / upgradeLevel;
        cooldownEndTime[client] = GetTime() + cooldownTime;

        CPrintToChat(client, "{purple}[TTT] {yellow}Sprint has been {green}activated{yellow}.");

        // Speed gradual build up.
        for (float i = 0.0; i < 0.5; i += 0.01) {
            DataPack pack;
            CreateDataTimer(i, SpeedIncrease, pack);
            pack.WriteCell(GetClientSerial(client));
            pack.WriteFloat(i);
        }

        // Speed end.
        isUsingSpeed[client] = true;
        CreateTimer(3.0, RevokeSpeed, GetClientUserId(client));

        // Speed cooldown.
        isInCooldown[client] = true;
        speedCooldownTimers[client] = CreateTimer(float(cooldownTime), CooldownEnd, GetClientUserId(client));
    }

    return Plugin_Continue;
}

public Action SpeedIncrease(Handle timer, Handle pack)
{
    ResetPack(pack);
    int client = GetClientFromSerial(ReadPackCell(pack));
    if (!IsValidClient(client)) return Plugin_Stop;

    float speed = 1.0 + ReadPackFloat(pack);

    SetClientSpeed(client, speed);
    SetEntityGravity(client, 1.0 / speed);

    return Plugin_Stop;
}

public Action RevokeSpeed(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client)) return Plugin_Stop;

    isUsingSpeed[client] = false;
    SetClientSpeed(client, 1.0);
    SetEntityGravity(client, 1.0);

    CPrintToChat(client, "{purple}[TTT] {yellow}Sprint has been {red}deactivated{yellow}.");

    return Plugin_Stop;
}

public Action CooldownEnd(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    isInCooldown[client] = false;
    ClearTimer(speedCooldownTimers[client]);

    return Plugin_Stop;
}

public SetClientSpeed(int client, float speed)
{
    SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", speed);
}

public bool ErrorTimeout(int client, int timeout)
{
    int currentTime = GetTime();
    if (currentTime - errorTimeout[client] < timeout)
    {
        return true;
    }

    errorTimeout[client] = currentTime;
    return false;
}
