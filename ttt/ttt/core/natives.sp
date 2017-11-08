public int Native_IsRoundActive(Handle plugin, int numParams)
{
	return g_bRoundStarted;
}

public int Native_GetClientRole(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (TTT_IsClientValid(client))
	{
		return g_iRole[client];
	}

	return 0;
}

public int Native_GetClientKarma(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	bool publicKarma = view_as<bool>(GetNativeCell(2));

	if (TTT_IsClientValid(client) && g_bKarma[client])
	{
		if (g_iConfig[bpublicKarma] || publicKarma)
		{
			return g_iKarma[client];
		}
		else
		{
			return g_iKarmaStart[client];
		}
	}

	return 0;
}

public int Native_GetClientRagdoll(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	int iBody[Ragdolls];

	if (TTT_IsClientValid(client))
	{
		for (int i = 0; i < g_aRagdoll.Length; i++)
		{
			g_aRagdoll.GetArray(i, iBody[0], sizeof(iBody));
			if (iBody[Victim] == client)
			{
				SetNativeArray(2, iBody[0], sizeof(iBody));
			}
			return 1;
		}
	}

	return 0;
}

public int Native_SetRagdoll(Handle plugin, int numParams)
{
	int iBody[Ragdolls];

	GetNativeArray(1, iBody[0], sizeof(iBody));

	g_aRagdoll.PushArray(iBody[0]);

	return 0;
}

public int Native_SetClientRole(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int role = GetNativeCell(2);

	if (TTT_IsClientValid(client))
	{
		g_iRole[client] = role;
		TeamInitialize(client);
		return g_iRole[client];
	}
	else if (role < TTT_TEAM_UNASSIGNED || role > TTT_TEAM_DETECTIVE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid role %d", role);
	}

	return 0;
}

public int Native_SetClientKarma(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int karma = GetNativeCell(2);
	bool force = view_as<bool>(GetNativeCell(3));

	if (TTT_IsClientValid(client) && g_bKarma[client])
	{
		return setKarma(client, karma, force);
	}

	return 0;
}

public int Native_AddClientKarma(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int karma = GetNativeCell(2);
	bool force = view_as<bool>(GetNativeCell(3));

	if (TTT_IsClientValid(client) && g_bKarma[client])
	{
		return setKarma(client, g_iKarma[client] + karma, force);
	}

	return 0;
}

public int Native_RemoveClientKarma(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int karma = GetNativeCell(2);
	bool force = view_as<bool>(GetNativeCell(3));

	if (TTT_IsClientValid(client) && g_bKarma[client])
	{
		return setKarma(client, g_iKarma[client] - karma, force);
	}

	return 0;
}

public int Native_WasBodyFound(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (TTT_IsClientValid(client))
	{
		int iSize = g_aRagdoll.Length;

		if (iSize == 0)
		{
			return false;
		}

		int iRagdoll[Ragdolls];

		for (int i = 0; i < iSize; i++)
		{
			g_aRagdoll.GetArray(i, iRagdoll[0]);

			if (iRagdoll[Victim] == client)
			{
				return iRagdoll[Found];
			}
		}
	}

	return 0;
}

public int Native_WasBodyScanned(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (TTT_IsClientValid(client))
	{
		int iSize = g_aRagdoll.Length;

		if (iSize == 0)
		{
			return false;
		}

		int iRagdoll[Ragdolls];

		for (int i = 0; i < iSize; i++)
		{
			g_aRagdoll.GetArray(i, iRagdoll[0]);

			if (iRagdoll[Victim] == client)
			{
				return iRagdoll[Scanned];
			}
		}
	}

	return 0;
}

public int Native_LogString(Handle plugin, int numParams)
{
	char message[512];
	int bytes;

	FormatNativeString(0, 1, 2, sizeof(message), bytes, message);
	addArrayTime(message);

	return 0;
}

public int Native_GetFoundStatus(Handle plugin, int numParams)
{
	return g_bFound[GetNativeCell(1)];
}

public int Native_SetFoundStatus(Handle plugin, int numParams)
{
	g_bFound[GetNativeCell(1)] = view_as<bool>(GetNativeCell(2));

	return;
}

public int Native_OverrideConfigInt(Handle plugin, int numParams)
{
	g_iConfig[GetNativeCell(1)] = GetNativeCell(2);

	return;
}

public int Native_OverrideConfigBool(Handle plugin, int numParams)
{
	g_iConfig[GetNativeCell(1)] = GetNativeCell(2);

	return;
}

public int Native_OverrideConfigFloat(Handle plugin, int numParams)
{
	g_iConfig[GetNativeCell(1)] = GetNativeCell(2);

	return;
}

public int Native_OverrideConfigString(Handle plugin, int numParams)
{
	int size = GetNativeCell(3);
	char[] buffer = new char[size];

	GetNativeString(2, buffer, size);
	strcopy(view_as<char>(g_iConfig[GetNativeCell(1)]), size, buffer);

	return;
}

public int Native_ReloadConfig(Handle plugin, int numParams)
{
	SetupConfig();

	return;
}

public int Native_ForceTraitor(Handle plugin, int numParams)
{
	int userid = GetClientUserId(GetNativeCell(1));
	
	if(g_aForceTraitor.FindValue(userid) == -1 && g_aForceDetective.FindValue(userid) == -1)
	{
		g_aForceTraitor.Push(userid);
	}
	else
	{
		return false;
	}

	return true;
}

public int Native_ForceDetective(Handle plugin, int numParams)
{
	int userid = GetClientUserId(GetNativeCell(1));
	
	if(g_aForceTraitor.FindValue(userid) == -1 && g_aForceDetective.FindValue(userid) == -1)
	{
		g_aForceDetective.Push(userid);
	}
	else
	{
		return false;
	}

	return true;
}
