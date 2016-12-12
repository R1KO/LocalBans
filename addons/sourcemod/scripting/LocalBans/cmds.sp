
public Action Command_Ban(int iClient, int iArgs)
{
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_ban <#userid|name> <minutes|0> [reason]");
		return Plugin_Handled;
	}

	char szArg[64];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	int iTarget = FindTarget(iClient, szArg, true);
	if (iTarget == -1)
	{
		ReplyToCommand(iClient, "[SM] Игрок не найден!");
		return Plugin_Handled;
	}

	GetCmdArg(2, szArg, sizeof(szArg));

	char szReason[128];
	if (iArgs == 3)
	{
		GetCmdArg(3, szReason, sizeof(szReason));
	}

	UTIL_CreateBan(iClient, iTarget, _, _, _,  S2I(szArg)*60, szReason);

	return Plugin_Handled;
}

public Action Command_AddBan(int iClient, int iArgs)
{
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_addban <steamid> <time> [reason] [name]");
		return Plugin_Handled;
	}
	
	char szAuth[32];
	GetCmdArg(1, szAuth, sizeof(szAuth));

	if (!((strncmp(szAuth, "STEAM_", 6) == 0 && szAuth[7] == ':') || strncmp(szAuth, "[U:", 3) == 0))
	{
		ReplyToCommand(iClient, "[SM] %t", "Invalid SteamID specified");
		return Plugin_Handled;
	}

	char szTime[16];
	GetCmdArg(2, szTime, sizeof(szTime));

	char szReason[128], szName[MAX_NAME_LENGTH];
	if (iArgs == 3)
	{
		GetCmdArg(3, szReason, sizeof(szReason));
	}
	if (iArgs == 4)
	{
		GetCmdArg(4, szName, sizeof(szName));
	}

	UTIL_CreateBan(iClient, _, szAuth, szName, _, S2I(szTime)*60, szReason);

	return Plugin_Handled;
}

public Action Command_BanIp(int iClient, int iArgs)
{
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_banip <ip|#userid|name> <time> [reason]");
		return Plugin_Handled;
	}

	char szArg[64];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	int iTarget = FindTarget(iClient, szArg, true);
	if (iTarget == -1)
	{
		ReplyToCommand(iClient, "[SM] Игрок не найден!");
		return Plugin_Handled;
	}

	GetCmdArg(2, szArg, sizeof(szArg));

	char szReason[128];
	if (iArgs == 3)
	{
		GetCmdArg(3, szReason, sizeof(szReason));
	}

	UTIL_CreateBan(iClient, iTarget, _, _, _,  S2I(szArg)*60, szReason, 1);

	return Plugin_Handled;
}

public Action Command_Unban(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_unban <steamid|ip>");
		return Plugin_Handled;
	}

	char szQuery[256], szAuth[32];
	GetCmdArg(1, szAuth, sizeof(szAuth));

	
	FormatEx(szQuery, sizeof(szQuery), "UPDATE `table_bans` SET `remove_type` = 1 WHERE `remove_type` = '0' AND (`auth` = '%s' OR `ip` = '%s');", szAuth, szAuth);
	g_hDatabase.Query(SQL_Callback_UnBan, szQuery, iClient ? UID(iClient):0);

	return Plugin_Handled;
}

public void SQL_Callback_UnBan(Database hDatabase, DBResultSet results, const char[] sError, any iClient)
{
	if(sError[0])
	{
		LogError("SQL_Callback_UnBan: %s", sError);
		return;
	}
	
	if(iClient)
	{
		iClient = GetClientOfUserId(iClient);
		if(!iClient)
		{
			return;
		}
	}
	
	if(results.AffectedRows)
	{
		ReplyToCommand(iClient, "[SM] Игрок разбанен!");
	}
	else
	{
		ReplyToCommand(iClient, "[SM] Бан не найден!");
	}
}