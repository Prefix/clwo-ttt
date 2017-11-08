#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <multicolors>
#include <ttt>
#include <config_loader>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Round End Sounds"

int g_iSoundEnts[2048];
int g_iNumSounds;

char g_sConfigFile[PLATFORM_MAX_PATH] = "";

char g_sDetPath[PLATFORM_MAX_PATH + 1];
char g_sTraPath[PLATFORM_MAX_PATH + 1];
char g_sInnPath[PLATFORM_MAX_PATH + 1];

bool g_bPlayType = false;
bool g_bStop = true;
bool g_bSettings = true;

Handle g_hCookie;

bool SoundsDetSucess = false;
bool SoundsTraSucess = false;
bool SoundsInnSucess = false;

bool g_bEnable = false;

ArrayList detSound;
ArrayList traSound;
ArrayList innSound;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Bara (& AbNeR_CSS)",
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
}

public void OnPluginStart()
{  
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/res.cfg");
	Config_Setup("TTT-Res", g_sConfigFile);
	
	g_bEnable = Config_LoadBool("res_enable", false, "Enable round end sounds plugin? (Default: false/0)");
	
	if (g_bEnable)
	{
		Config_LoadString("res_traitor_path", "ttt/res/traitor", "Path off traitor sounds in /cstrike/sound", g_sTraPath, sizeof(g_sTraPath));
		Config_LoadString("res_detective_path", "ttt/res/detective", "Path off detective sounds in /cstrike/sound", g_sDetPath, sizeof(g_sDetPath));
		Config_LoadString("res_innocent_path", "ttt/res/innocent", "Path off innocent sounds in /cstrike/sound", g_sInnPath, sizeof(g_sInnPath));
		
		
		g_bPlayType = Config_LoadBool("res_play_type", false, "0 - Random, 1 - Play in queue");
		g_bStop = Config_LoadBool("res_stop_map_music", true, "Stop map musics");	
		g_bSettings = Config_LoadBool("res_client_preferences", true, "Enable/Disable client preferences");
		
		g_hCookie = RegClientCookie("Round End Sounds", "", CookieAccess_Private);
		SetCookieMenuItem(Cookie_RoundEndSound, 0, "Round End Sounds");
		
		LoadTranslations("common.phrases");
	
		RegAdminCmd("sm_resrefresh", Command_ResRefresh, ADMFLAG_CONFIG);
		
		RegConsoleCmd("sm_res", Commamnd_RES);
		
		HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		
		detSound = new ArrayList(512);
		traSound = new ArrayList(512);
		innSound = new ArrayList(512);
	}
	
	Config_Done();
}

public void OnConfigsExecuted()
{
	if (g_bEnable)
	{
		RefreshSounds(0);
	}
}

public void TTT_OnRoundEnd(int winner)
{
	if (!g_bEnable)
	{
		return;
	}
	
	if(g_bStop)
	{
		StopMapMusic();
	}
	
	if(winner == TTT_TEAM_TRAITOR)
	{
		if(SoundsTraSucess)
		{
			PlaySoundTra();
		}
		else
		{
			PrintToServer("[TTT] Can't find sounds for traitors.");
			return;
		}
	}
	else if(winner == TTT_TEAM_DETECTIVE)
	{
		if(SoundsDetSucess)
		{
			PlaySoundDet();
		}
		else
		{
			PrintToServer("[TTT] Can't find sounds for detectives.");
			return;
		}
	}
	else if(winner == TTT_TEAM_INNOCENT)
	{
		if(SoundsInnSucess)
		{
			PlaySoundInn();
		}
		else
		{
			PrintToServer("[TTT] Can't find sounds for innocents.");
			return;
		}
	}
}

public void StopMapMusic()
{
	char sSound[PLATFORM_MAX_PATH];
	int entity = INVALID_ENT_REFERENCE;
	LoopValidClients(i)
	{
		for (int u = 0; u < g_iNumSounds; u++)
		{
			entity = EntRefToEntIndex(g_iSoundEnts[u]);
			if (entity != INVALID_ENT_REFERENCE)
			{
				GetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
				StopClientSound(i, entity, SNDCHAN_STATIC, sSound);
			}
		}
	}
}

stock void StopClientSound(int client, int entity, int channel, const char[] name)
{
	EmitSoundToClient(client, name, entity, channel, SNDLEVEL_NONE, SND_STOP, 0.0, SNDPITCH_NORMAL, _, _, _, true);
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(g_bEnable && g_bStop)
	{
		g_iNumSounds = 0;
		
		char sSound[PLATFORM_MAX_PATH];
		int entity = INVALID_ENT_REFERENCE;
		
		while ((entity = FindEntityByClassname(entity, "ambient_generic")) != INVALID_ENT_REFERENCE)
		{
			GetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
			
			int len = strlen(sSound);
			if (len > 4 && (StrEqual(sSound[len-3], "mp3") || StrEqual(sSound[len-3], "wav")))
			{
				g_iSoundEnts[g_iNumSounds++] = EntIndexToEntRef(entity);
			}
		}
	}
}

public void Cookie_RoundEndSound(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	Commamnd_RES(client, 0);
} 

public Action Commamnd_RES(int client, int args)
{
	if(g_bSettings)
	{
		return Plugin_Handled;
	}
	
	int cookievalue = GetIntCookie(client, g_hCookie);
	Handle hMenu = CreateMenu(MenuHandle);
	SetMenuTitle(hMenu, "Round End Sounds...");
	char Item[128];
	if(cookievalue == 0)
	{
		Format(Item, sizeof(Item), "Sounds on [X]");
		AddMenuItem(hMenu, "ON", Item);
		Format(Item, sizeof(Item), "Sounds off"); 
		AddMenuItem(hMenu, "OFF", Item);
	}
	else
	{
		Format(Item, sizeof(Item), "Sounds on");
		AddMenuItem(hMenu, "ON", Item);
		Format(Item, sizeof(Item), "Sounds off [X]");
		AddMenuItem(hMenu, "OFF", Item);
	}
	SetMenuExitBackButton(hMenu, true);
	SetMenuExitButton(hMenu, true);
	DisplayMenu(hMenu, client, 30);
	return Plugin_Continue;
}

public Action Command_ResRefresh(int client, int args)
{   
	RefreshSounds(client);
	return Plugin_Handled;
}

public int MenuHandle(Handle menu, MenuAction action, int param1, int param2)
{
	Handle hMenu = CreateMenu(MenuHandle);
	if (action == MenuAction_DrawItem)
	{
		return ITEMDRAW_DEFAULT;
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		ShowCookieMenu(param1);
	}
	else if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0:
			{
				SetClientCookie(param1, g_hCookie, "0");
				Commamnd_RES(param1, 0);
			}
			case 1:
			{
				SetClientCookie(param1, g_hCookie, "1");
				Commamnd_RES(param1, 0);
			}
		}
		CloseHandle(hMenu);
	}
	return 0;
}

void RefreshSounds(int client)
{
	int size = LoadSoundsDet();
	SoundsDetSucess = (size > 0);
	if(SoundsDetSucess)
	{
		if (client == 0)
		{
			LogMessage("[TTT] %d detective sounds loaded.", size);
		}
		else
		{
			ReplyToCommand(client, "[TTT] %d detective sounds loaded.", size);
		}		
	}
	else
	{
		if (client == 0)
		{
			LogMessage("[TTT] Invalid detective sound path.");
		}
		else
		{
			ReplyToCommand(client, "[TTT] Invalid detective sound path.");
		}
	}
	
	size = LoadSoundsTra();
	SoundsTraSucess = (size > 0);
	if(SoundsTraSucess)
	{
		if (client == 0)
		{
			LogMessage("[TTT] %d traitor sounds loaded.", size);
		}
		else
		{
			ReplyToCommand(client, "[TTT] %d traitor sounds loaded.", size);
		}	
	}
	else
	{
		if (client == 0)
		{
			LogMessage("[TTT] Invalid traitor sound path.");
		}
		else
		{
			ReplyToCommand(client, "[TTT] Invalid traitor sound path.");
		}
	}
	
	size = LoadSoundsInn();
	SoundsInnSucess = (size > 0);
	if(SoundsInnSucess)
	{
		if (client == 0)
		{
			LogMessage("[TTT] %d innocent sounds loaded.", size);
		}
		else
		{
			ReplyToCommand(client, "[TTT] %d innocent sounds loaded.", size);
		}	
	}
	else
	{
		if (client == 0)
		{
			LogMessage("[TTT] Invalid innocent sound path.");
		}
		else
		{
			ReplyToCommand(client, "[TTT] Invalid innocent sound path.");
		}
	}
}
 
int LoadSoundsDet()
{
	detSound.Clear();
	char name[128];
	char soundname[512];
	char soundpath[PLATFORM_MAX_PATH];
	char soundpath2[PLATFORM_MAX_PATH];
	strcopy(soundpath, sizeof(soundpath), g_sDetPath);
	
	Format(soundpath2, sizeof(soundpath2), "sound/%s/", soundpath);
	Handle hDir = OpenDirectory(soundpath2);
	if(hDir != null)
	{
		while (ReadDirEntry(hDir, name, sizeof(name)))
		{
			int namelen = strlen(name) - 4;
			if (StrContains(name, ".mp3", false) == namelen)
			{
				Format(soundname, sizeof(soundname), "sound/%s/%s", soundpath, name);
				AddFileToDownloadsTable(soundname);
				Format(soundname, sizeof(soundname), "%s/%s", soundpath, name);
				PrecacheSound(soundname);
				detSound.PushString(soundname);
			}
		}
		
		delete hDir;
	}
	
	return detSound.Length;
}

int LoadSoundsTra()
{
	traSound.Clear();
	char name[128];
	char soundname[512];
	char soundpath[PLATFORM_MAX_PATH];
	char soundpath2[PLATFORM_MAX_PATH];
	strcopy(soundpath, sizeof(soundpath), g_sTraPath);
	
	Format(soundpath2, sizeof(soundpath2), "sound/%s/", soundpath);
	Handle hDir = OpenDirectory(soundpath2);
	if(hDir != null)
	{
		while (ReadDirEntry(hDir, name, sizeof(name)))
		{
			int namelen = strlen(name) - 4;
			if (StrContains(name, ".mp3", false) == namelen)
			{
				Format(soundname, sizeof(soundname), "sound/%s/%s", soundpath, name);
				AddFileToDownloadsTable(soundname);
				Format(soundname, sizeof(soundname), "%s/%s", soundpath, name);
				PrecacheSound(soundname);
				traSound.PushString(soundname);
			}
		}
		
		delete hDir;
	}
	return traSound.Length;
}

int LoadSoundsInn()
{
	innSound.Clear();
	char name[128];
	char soundname[512];
	char soundpath[PLATFORM_MAX_PATH];
	char soundpath2[PLATFORM_MAX_PATH];
	strcopy(soundpath, sizeof(soundpath), g_sInnPath);
	Format(soundpath2, sizeof(soundpath2), "sound/%s/", soundpath);
	Handle hDir = OpenDirectory(soundpath2);
	if(hDir != null)
	{
		while (ReadDirEntry(hDir, name, sizeof(name)))
		{
			int namelen = strlen(name) - 4;
			if(StrContains(name,".mp3",false) == namelen)
			{
				Format(soundname, sizeof(soundname), "sound/%s/%s", soundpath, name);
				AddFileToDownloadsTable(soundname);
				Format(soundname, sizeof(soundname), "%s/%s", soundpath, name);
				PrecacheSound(soundname);
				innSound.PushString(soundname);
			}
		}
		
		delete hDir;
	}
	
	return innSound.Length;
}

void PlaySoundDet()
{
	int soundToPlay = 0;
	if(g_bPlayType)
	{
		soundToPlay = GetRandomInt(0, detSound.Length-1);
	}
	
	char sSound[128];
	detSound.GetString(soundToPlay, sSound, sizeof(sSound));
	detSound.Erase(soundToPlay);
	PlayMusicAll(sSound);
	if(detSound.Length == 0)
		LoadSoundsDet();
}

void PlaySoundTra()
{
	int soundToPlay = 0;
	if(g_bPlayType)
	{
		soundToPlay = GetRandomInt(0, traSound.Length-1);
	}
	
	char sSound[128];
	traSound.GetString(soundToPlay, sSound, sizeof(sSound));
	traSound.Erase(soundToPlay);
	PlayMusicAll(sSound);
	if(traSound.Length == 0)
		LoadSoundsTra();
}

void PlaySoundInn()
{
	int soundToPlay = 0;
	if(g_bPlayType)
	{
		soundToPlay = GetRandomInt(0, innSound.Length-1);
	}
	
	char sSound[128];
	innSound.GetString(soundToPlay, sSound, sizeof(sSound));
	innSound.Erase(soundToPlay);
	PlayMusicAll(sSound);
	if(innSound.Length == 0)
		LoadSoundsInn();
}

void PlayMusicAll(char[] sSound)
{
	LoopValidClients(i)
	{
		if((!g_bSettings || GetIntCookie(i, g_hCookie) == 0))
		{
			ClientCommand(i, "playgamesound Music.StopAllMusic");
			ClientCommand(i, "play \"*%s\"", sSound);
		}
	}
}

int GetIntCookie(int client, Handle handle)
{
	char sCookieValue[11];
	GetClientCookie(client, handle, sCookieValue, sizeof(sCookieValue));
	return StringToInt(sCookieValue);
}
