#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#include <colorlib>
#include <ttt>
#include <generics>
#include <ttt_messages>
#include <ttt_targeting>

public Plugin myinfo = {
    name = "Random Death Match manager",
    author = "Popey & c0rp3n",
    description = "Random Death Match manager and handler for Trouble in Terrorist Town.",
    version = "1.1.0",
    url = ""
};

Database g_database = null;

int g_currentRound = -1;
int g_lastDeathIndex = -1;

enum CaseVerdict
{
    CaseVerdict_None,
    CaseVerdict_Innocent,
    CaseVerdict_Guilty
};

enum Role
{
    Role_None,
    Role_Innocent,
    Role_Traitor,
    Role_Detective
}

enum struct PlayerData
{
    int currentCase;
    int currentDeath;
    int lastGunFired;
}

PlayerData g_playerData[MAXPLAYERS + 1];

public void OnPluginStart()
{
    RegConsoleCmd("sm_rdm", Command_RDM, "Shows the RDM report window for all recent killers.");
    RegAdminCmd("sm_cases", Command_CaseCount, ADMFLAG_GENERIC, "Shows the current amount of cases to staff.");
    RegAdminCmd("sm_handle", Command_Handle, ADMFLAG_GENERIC, "Handles the next case or a user inputted case.");
    RegAdminCmd("sm_info", Command_Info, ADMFLAG_GENERIC, "Displays all of the information for a given case.");
    RegAdminCmd("sm_verdict", Command_Verdict, ADMFLAG_GENERIC, "Shows a member of staff the availible verdicts for there current case.");
    
    HookEvent("weapon_fire", Event_OnWeaponFire, EventHookMode_Post);

    LoopValidClients(i)
    {
        OnClientPutInServer(i);
    }

    Database.Connect(DbCallback_Connect, "rdm");

    PrintToServer("[RDM] Loaded successfully");
}

public void OnClientPutInServer(int client)
{
    g_playerData[client].currentCase = -1;
    g_playerData[client].currentDeath = -1;
    g_playerData[client].lastGunFired = 0;
}

public void OnClientPostAdminCheck(int client)
{
    Db_SelectLastCase(client);
}

public void TTT_OnRoundStart(int roundid, int innocents, int traitors, int detective)
{
    g_currentRound = roundid;
}

public void TTT_OnClientDeath(int victim, int attacker)
{
    int victimKarma = TTT_GetClientKarma(victim);
    int attackerKarma = TTT_GetClientKarma(attacker);

    if(BadKill(TTT_GetClientRole(attacker), TTT_GetClientRole(victim)))
    {
        CPrintToChatAdmins(ADMFLAG_CHAT, TTT_MESSAGE ... "{default}Bad Action: [{yellow}%N{default}] ({orange}%d{default}) killed [{yellow}%N{default}] ({orange}%d{default})", attacker, attackerKarma, victim, victimKarma);
    }

    Db_InsertDeath(victim, attacker);
}

public Action Command_CaseCount(int client, int args)
{
    Db_SelectCaseCount();

    return Plugin_Handled;
}

public Action Command_Handle(int client, int args)
{
    if (g_playerData[client].currentCase > -1)
    {
        CPrintToChat(client, TTT_ERROR ... "You cannot handle a new case whilst you still have a case awaiting your verdict.");
        return Plugin_Handled;
    }

    Db_SelectNextCase(client);

    return Plugin_Handled;
}

public Action Command_Info(int client, int args)
{
    Db_SelectInfo(client);

    return Plugin_Handled;
}

public Action Command_RDM(int client, int args)
{
    Db_SelectClientDeaths(client);

    return Plugin_Handled;
}

public Action Command_Verdict(int client, int args)
{
    if (g_playerData[client].currentCase < 0)
    {
        CPrintToChat(client, TTT_ERROR ... "You do not currently have a case to cast a verdict upon.");
        return Plugin_Handled;
    }

    if (args < 1)
    {
        Menu verdictMenu = new Menu(MenuHandler_Verdict);
        verdictMenu.AddItem("", "Innocent");
        verdictMenu.AddItem("", "Guilty");
        verdictMenu.Display(client, 240);
    }
    else
    {
        char response[64];
        GetCmdArg(1, response, 64);

        CaseVerdict verdict = CaseVerdict_None;
        if (strcmp(response, "innocent", false) == 0)
        {
            verdict = CaseVerdict_Innocent;
        }
        else if (strcmp(response, "guilty", false) == 0)
        {
            verdict = CaseVerdict_Guilty;
        }

        if (verdict == CaseVerdict_Innocent || verdict == CaseVerdict_Guilty)
        {
            Db_UpdateVerdict(client, g_playerData[client].currentCase, verdict);
        }
        else
        {
            CPrintToChat(client, TTT_ERROR ... "Please pass either Innocent or Guilty.");
        }
    }

    return Plugin_Handled;
}

public void Event_OnWeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    g_playerData[GetClientOfUserId(event.GetInt("userid"))].lastGunFired = GetTime();
}

public void TTT_OnRoundEnd(int winner, Handle array)
{
    Db_SelectCaseCount();
}

void RoleString(char[] buffer, int maxlength, Role role)
{
    switch (role)
    {
        case Role_Innocent:
        {
            strcopy(buffer, maxlength, "{green}Innocent");
        }
        case Role_Traitor:
        {
            strcopy(buffer, maxlength, "{red}Traitor");
        }
        case Role_Detective:
        {
            strcopy(buffer, maxlength, "{blue}Detective");
        }
    }
}

void RoleEnum(char[] buffer, int maxlength, int role)
{
    if (role == TTT_TEAM_INNOCENT)
    {
        strcopy(buffer, maxlength, "innocent");
    }
    else if (role == TTT_TEAM_TRAITOR)
    {
        strcopy(buffer, maxlength, "traitor");
    }
    else if (role == TTT_TEAM_DETECTIVE)
    {
        strcopy(buffer, maxlength, "detective");
    }
    else
    {
        strcopy(buffer, maxlength, "none");
    }
}

bool BadKill(int attackerRole, int victimRole)
{
    if (attackerRole == victimRole) {
        return true;
    }

    else if (attackerRole == TTT_TEAM_TRAITOR || (attackerRole != TTT_TEAM_TRAITOR && victimRole == TTT_TEAM_TRAITOR)) 
    {
        return false;
    }
    else {
        return true;
    }
}

////////////////////////////////////////////////////////////////////////////////
// Database
////////////////////////////////////////////////////////////////////////////////

public void DbCallback_Connect(Database db, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("DbCallback_Connect: %s", error);
        return;
    }

    g_database = db;
    g_database.SetCharset("utf8");
    Db_SelectLastDeathIndex();
    g_currentRound = TTT_GetRoundID();
}

void Db_InsertDeath(int victim, int attacker)
{
    int victimId = GetSteamAccountID(victim);
    int victimRole = TTT_GetClientRole(victim);
    char sVictimRole[10] = "none";
    RoleEnum(sVictimRole, sizeof(sVictimRole), victimRole);

    int attackerId = GetSteamAccountID(attacker);
    int attackerRole = TTT_GetClientRole(attacker);
    char sAttackerRole[10] = "none";
    RoleEnum(sAttackerRole, sizeof(sAttackerRole), attackerRole);

    char query[768];
    Format(
        query, sizeof(query), "INSERT INTO `deaths` (`death_index`, `death_time`, `victim_id`, `victim_role`, `attacker_id`, `attacker_role`, `last_gun_fire`, `round`) VALUES ('%d', '%d', '%d', '%s', '%d', '%s', '%d', '%d');",
        ++g_lastDeathIndex, GetTime(), victimId, sVictimRole, attackerId, sAttackerRole, g_playerData[victim].lastGunFired, g_currentRound);
    g_database.Query(DbCallback_InsertDeath, query);
}

public void DbCallback_InsertDeath(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null)
    {
        LogError("DbCallback_InsertDeath: %s", error);
        return;
    }
}

void Db_InsertHandle(int client, int death)
{
    CPrintToChatAdmins(ADMFLAG_CHAT, TTT_MESSAGE ... "{yellow}%N {default}has taken an RDM case.", client);

    int accountID = GetSteamAccountID(client);

    char query[768];
    Format(query, sizeof(query), "INSERT INTO `handles` (`death_index`, `admin_id`) VALUES ('%d', '%d');", death, accountID);
    g_database.Query(DbCallback_InsertHandle, query, GetClientUserId(client));
}

public void DbCallback_InsertHandle(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        LogError("DbCallback_InsertHandle: %s", error);
        return;
    }

    int client = GetClientOfUserId(userid);
    Db_SelectCaseBaseInfo(client);
}

void Db_InsertReport(int client, int death)
{
    char query[768];
    Format(query, sizeof(query), "INSERT INTO `reports` (`death_index`) VALUES ('%d');", death);
    g_database.Query(DbCallback_InsertReport, query, GetClientUserId(client));
}

public void DbCallback_InsertReport(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        LogError("DbCallback_InsertReport: %s", error);
        return;
    }

    int client = GetClientOfUserId(userid);

    CPrintToChat(client, TTT_MESSAGE ... "Thanks for submitting a case, a staff member shall be in contact shortly.");

    CPrintToChatAdmins(ADMFLAG_CHAT, TTT_MESSAGE ... "{yellow}%N {default}opened a new RDM case.", client);

    Db_SelectCaseCount();
}

void Db_SelectLastDeathIndex()
{
    g_database.Query(DbCallback_SelectLastDeathIndex, "SELECT MAX(`death_index`) FROM `deaths`;");
}

public void DbCallback_SelectLastDeathIndex(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null)
    {
        PrintToServer("DbCallback_SelectLastDeathIndex: %s", error);
        return;
    }

    if (results.FetchRow())
    {
        g_lastDeathIndex = results.FetchInt(0);
    }
    else
    {
        g_lastDeathIndex = 0;
    }
}

void Db_SelectCaseCount()
{
    char query[768];
    Format(query, sizeof(query), "SELECT COUNT(*) AS `case_count` FROM `open_cases`;");
    g_database.Query(DbCallback_SelectCaseCount, query);
}

public void DbCallback_SelectCaseCount(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null)
    {
        LogError("DbCallback_SelectCaseCount: %s", error);
        return;
    }

    if (results.FetchRow())
    {
        int caseCount = results.FetchInt(0);
        if (caseCount < 1)
        {
            CPrintToChatAdmins(ADMFLAG_CHAT, TTT_MESSAGE ... "There are currently no unhandled cases.");
        }
        else if (caseCount < 2)
        {
            CPrintToChatAdmins(ADMFLAG_CHAT, TTT_MESSAGE ... "There is now {orange}%d {default}unhandled case.", caseCount);
        }
        else
        {
            CPrintToChatAdmins(ADMFLAG_CHAT, TTT_MESSAGE ... "There are now {orange}%d {default}unhandled cases.", caseCount);
        }
    }
}

void Db_SelectNextCase(int client)
{
    char query[128];
    Format(query, sizeof(query), "SELECT `death_index` FROM `open_cases` ORDER BY `death_index` ASC LIMIT 1;");
    g_database.Query(DbCallback_SelectNextCase, query, GetClientUserId(client));
}

public void DbCallback_SelectNextCase(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        LogError("DbCallback_SelectNextCase: %s", error);
        return;
    }

    int client = GetClientOfUserId(userid);
    if (results.FetchRow())
    {
        int death = results.FetchInt(0);
        Db_InsertHandle(client, death);
        g_playerData[client].currentCase = death;
        Db_SelectInfo(client);
    }
    else
    {
        CPrintToChat(client, TTT_ERROR ... "There are currently no available cases.");
    }
}

void Db_SelectLastCase(int client)
{
    int accountID = GetSteamAccountID(client);

    char query[128];
    Format(query, sizeof(query), "SELECT `death_index` FROM `ongoing_cases` WHERE `admin_id` = '%d' LIMIT 1;", accountID);
    g_database.Query(DbCallback_SelectLastCase, query, GetClientUserId(client));
}

public void DbCallback_SelectLastCase(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        LogError("DbCallback_SelectLastCase: %s", error);
        return;
    }

    int client = GetClientOfUserId(userid);
    if (results.FetchRow())
    {
        int death = results.FetchInt(0);
        g_playerData[client].currentCase = death;
        CPrintToChat(client, "Loaded historic case %d. Use /info to get the case info.");
    }
}

void Db_SelectClientDeaths(int client)
{
    int accountID = GetSteamAccountID(client);

    char query[768];
    Format(query, sizeof(query), "SELECT `death_index`, `attacker_name`, `round` FROM `death_info` WHERE `victim_id` = '%d' ORDER BY `death_time`  DESC LIMIT 10;", accountID);
    g_database.Query(DbCallback_SelectClientDeaths, query, GetClientUserId(client));
}

public void DbCallback_SelectClientDeaths(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        LogError("DbCallback_SelectClientDeaths: %s", error);
        return;
    }

    int client = GetClientOfUserId(userid);

    Menu rdmMenu = new Menu(MenuHandler_RDM);
    rdmMenu.SetTitle("Please select the death you would like to report.");
    while(results.FetchRow())
    {
        int death;
        int roundNumber;
        char name[64];
        char info[8];
        char message[192];

        death = results.FetchInt(0);
        results.FetchString(1, name, sizeof(name));
        roundNumber = results.FetchInt(2);

        IntToString(death, info , 8);
        Format(message, sizeof(message), "%s (%i rounds ago)", name, g_currentRound - roundNumber);
        rdmMenu.AddItem(info, message);
    }

    rdmMenu.Display(client, 240);
}

void Db_SelectCaseBaseInfo(int client)
{
    char query[768];
    Format(query, sizeof(query), "SELECT `death_index`, `victim_name`, `attacker_name` FROM `case_info` WHERE `death_index` = '%d';", g_playerData[client].currentCase);
    g_database.Query(DbCallback_SelectCaseBaseInfo, query, GetClientUserId(client));
}

public void DbCallback_SelectCaseBaseInfo(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        LogError("DbCallback_SelectCaseBaseInfo: %s", error);
        return;
    }

    if (results.FetchRow())
    {
        int client = GetClientOfUserId(userid);
        int death = results.FetchInt(0);
        char victimName[64]; results.FetchString(1, victimName, sizeof(victimName));
        char attackerName[64]; results.FetchString(2, attackerName, sizeof(attackerName));

        CPrintToChat(client, TTT_MESSAGE ... "You have taken case {orange}#%d: {yellow}%s's {default}accusing {yellow}%s of RDM.", death, victimName, attackerName);
    }
}


void Db_SelectInfo(int client)
{
    char query[768];
    Format(query, sizeof(query), "SELECT `death_index`, `death_time`, `victim_name`, `victim_role`+0, `victim_karma`, `attacker_name`, `attacker_role`+0, `attacker_karma`, `last_gun_fire`, `round` FROM `case_info` WHERE `death_index` = '%d';", g_playerData[client].currentCase);
    g_database.Query(DbCallback_SelectInfo, query, GetClientUserId(client));
}

public void DbCallback_SelectInfo(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        LogError("DbCallback_SelectInfo: %s", error);
        return;
    }

    if (results.FetchRow())
    {
        int client = GetClientOfUserId(userid);

        int death = results.FetchInt(0);
        int time = results.FetchInt(1);
        char victimName[64]; results.FetchString(2, victimName, sizeof(victimName));
        Role victimRole = view_as<Role>(results.FetchInt(3));
        int victimKarma = results.FetchInt(4);
        char attackerName[64]; results.FetchString(5, attackerName, sizeof(attackerName));
        Role attackerRole = view_as<Role>(results.FetchInt(6));
        int attackerKarma = results.FetchInt(7);
        int lastshot = results.FetchInt(8);
        int round = results.FetchInt(9);

        char sVictimRole[16];
        RoleString(sVictimRole, sizeof(sVictimRole), victimRole);

        char sAttackerRole[16];
        RoleString(sAttackerRole, sizeof(sAttackerRole), attackerRole);

        CPrintToChat(client, TTT_MESSAGE ... "Case information for Death: {orange}%d{default}({orange}%d {default}rounds ago)", death, g_currentRound - round);
        CPrintToChat(client, TTT_MESSAGE ... "The victim had shot last {orange}%d {default}seconds before there death.", time - lastshot);
        CPrintToChat(client, TTT_MESSAGE ... "Accuser: {yellow}%s{default}({orange}%d{default}) - %s", victimName, victimKarma, sVictimRole);
        CPrintToChat(client, TTT_MESSAGE ... "Accused: {yellow}%s{default}({orange}%d{default}) - %s", attackerName, attackerKarma, sAttackerRole);
    }
}

void Db_SelectVerdictInfo(int client, int death)
{
    char query[256];
    Format(query, sizeof(query), "SELECT `death_index`, `victim_id`, `victim_name`, `attacker_id`, `attacker_name`, `verdict`+0 FROM `case_info` WHERE `death_index` = '%d';", death);
    g_database.Query(DbCallback_SelectVerdictInfo, query, GetClientUserId(client));
}

public void DbCallback_SelectVerdictInfo(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        LogError("DbCallback_SelectVerdictInfo: %s", error);
        return;
    }

    if (results.FetchRow())
    {
        int client = GetClientOfUserId(userid);

        int death = results.FetchInt(0);
        int victimID = results.FetchInt(1);
        char victimName[64]; results.FetchString(2, victimName, sizeof(victimName));
        int attackerID = results.FetchInt(3);
        char attackerName[64]; results.FetchString(4, attackerName, sizeof(attackerName));
        CaseVerdict verdict = view_as<CaseVerdict>(results.FetchInt(5));
        char cVerdict[24];

        if(verdict == CaseVerdict_Guilty)
        {
            cVerdict = "Guilty";
        }
        if(verdict == CaseVerdict_Innocent)
        {
            cVerdict = "Innocent";
        }


        int victim = AccountIDToClient(victimID);
        int attacker = AccountIDToClient(attackerID);

        if (verdict == CaseVerdict_Innocent)
        {
            if (IsValidClient(victim))
            {
                CPrintToChat(victim, TTT_MESSAGE ... "{yellow}%N {default}has handled your case against {yellow}%s {default}and has concluded them to be {green}innocent{default}, if you have any questions please message staff using an @ before your message or /chat.", client, attackerName);
            }
            if (IsValidClient(attacker))
            {
                CPrintToChat(attacker, TTT_MESSAGE ... "{yellow}%N {default}has found you {green}innocent {default}in your defense against {yellow}%s{default}, have a nice day.", client, victimName);
            }
            CPrintToChat(client, TTT_MESSAGE ... "You have concluded the defendant {green}innocent {default}for case {orange}%d", death);
        }
        else if (verdict == CaseVerdict_Guilty)
        {
            if (IsValidClient(victim))
            {
                CPrintToChat(victim, TTT_MESSAGE ... "{yellow}%N {default}has handled your case against {yellow}%s {default}and has concluded them to be {red}guilty{default}. Thanks for your report.", client, attackerName);
            }
            if (IsValidClient(attacker))
            {
                CPrintToChat(attacker, TTT_MESSAGE ... "You are being slayed next round by {yellow}%N {default}for killing {yellow}%s{default}. If you have any questions about this please message staff by using an @ before your message.", client, victimName);
                TTT_AddRoundSlays(attacker, 1, false);
            }
            CPrintToChat(client, TTT_MESSAGE ... "You have concluded the defendant {red}guilty {default}for case {orange}%d.", death);
        }

        LogAction(client, attackerID, "\"%L\" concluded \"%L\"'s case against \"%L\" (Verdict: %s)", client, victimID, attackerID, cVerdict);
    }
}

void Db_UpdateVerdict(int client, int death, CaseVerdict verdict)
{
    char sVerdict[9] = "none";
    if (verdict == CaseVerdict_Innocent)
    {
        sVerdict = "innocent";
    }
    else if (verdict == CaseVerdict_Guilty)
    {
        sVerdict = "guilty";
    }

    char query[768];
    Format(query, sizeof(query), "UPDATE `handles` SET `handles`.`verdict` = '%s' WHERE `death_index` = '%d';", sVerdict, death);
    g_database.Query(DbCallback_UpdateVerdict, query, GetClientUserId(client));
}

public void DbCallback_UpdateVerdict(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        LogError("DbCallback_UpdateVerdict: %s", error);
        return;
    }

    int client = GetClientOfUserId(userid);

    Db_SelectVerdictInfo(client, g_playerData[client].currentCase);

    g_playerData[client].currentCase = -1;
}

////////////////////////////////////////////////////////////////////////////////
// Menus
////////////////////////////////////////////////////////////////////////////////

int MenuHandler_RDM(Menu menu, MenuAction action, int client, int data)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[8];
            menu.GetItem(data, info, 8);
            int death = StringToInt(info);

            Db_InsertReport(client, death);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
}

int MenuHandler_Verdict(Menu menu, MenuAction action, int client, int choice)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            CaseVerdict verdict = CaseVerdict_None;
            if (choice == 0)
            {
                verdict = CaseVerdict_Innocent;
            }
            else if (choice == 1)
            {
                verdict = CaseVerdict_Guilty;
            }

            Db_UpdateVerdict(client, g_playerData[client].currentCase, verdict);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
}
