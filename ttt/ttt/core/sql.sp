public void Callback_Karma(Handle owner, Handle hndl, const char[] error, any userid)
{
	if (hndl == null || strlen(error) > 0)
	{
		LogToFileEx(g_iConfig[serrFile], "(Callback_Karma) Query failed: %s", error);
		return;
	}
}

public void Callback_UpdatePlayer(Handle owner, Handle hndl, const char[] error, any userid)
{
	if (hndl == null || strlen(error) > 0)
	{
		LogToFileEx(g_iConfig[serrFile], "(Callback_UpdatePlayer) Query failed: %s", error);
		return;
	}
	else
	{
		int client = GetClientOfUserId(userid);

		if (TTT_IsClientValid(client))
		{
			g_bKarma[client] = true;
		}
	}
}

public void SQL_OnClientPostAdminCheck(Handle owner, Handle hndl, const char[] error, any userid)
{
	int client = GetClientOfUserId(userid);

	if (!client || !TTT_IsClientValid(client) || IsFakeClient(client))
	{
		return;
	}

	if (hndl == null || strlen(error) > 0)
	{
		LogToFileEx(g_iConfig[serrFile], "(SQL_OnClientPostAdminCheck) Query failed: %s", error);
		return;
	}
	else
	{
		if (!SQL_FetchRow(hndl))
		{
			g_iKarma[client] = g_iConfig[istartKarma];
			UpdatePlayer(client);
		}
		else
		{
			char sCommunityID[64];

			if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
			{
				LogToFileEx(g_iConfig[serrFile], "(SQL_OnClientPostAdminCheck) Auth failed: #%d", client);
				return;
			}

			int karma = SQL_FetchInt(hndl, 0);

			if (g_bDebug)
			{
				LogToFileEx(g_iConfig[slogFile], "Name: %L has %d karma", client, karma);
			}

			if (karma == 0)
			{
				g_iKarma[client] = g_iConfig[istartKarma];
			}
			else
			{
				g_iKarma[client] = karma;
			}

			CS_SetClientContributionScore(client, karma);

			g_bKarma[client] = true;
		}
	}
}
