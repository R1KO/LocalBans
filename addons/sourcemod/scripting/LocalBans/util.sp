
void UTIL_OfflineBan(int iAdmin, int iID, const char[] szReason)
{
	DebugMessage("%N (%i) UTIL_OfflineBan -> %i (%s)", iAdmin, iAdmin, iID, szReason)
	DataPack hPack = CreateDataPack();
	hPack.WriteCell(UID(iAdmin));
	hPack.WriteCell(iID);
	hPack.WriteString(szReason);

	char szQuery[256];
	FormatEx(szQuery, sizeof(szQuery), "SELECT `name`, `auth`, `ip` FROM `table_offline` WHERE `id` = %i;", iID);
	g_hDatabase.Query(SQL_Callback_OfflineBanSelectInfo, szQuery, hPack);
}

public void SQL_Callback_OfflineBanSelectInfo(Database hDatabase, DBResultSet results, const char[] sError, any hDataPack)
{
	if(sError[0])
	{
		LogError("SQL_Callback_OfflineBanSelectInfo: %s", sError);
		return;
	}
	
	ResetPack(hDataPack);
	int iClient = CID(ReadPackCell(hDataPack));
	if(iClient && results.FetchRow())
	{
		char szQuery[256], szReason[128], szName[MAX_NAME_LENGTH], szAuth[32], szIp[16];
		FormatEx(szQuery, sizeof(szQuery), "DELETE FROM `table_offline` WHERE `id` = '%i';", ReadPackCell(hDataPack));
		g_hDatabase.Query(SQL_Callback_CheckError, szQuery);

		ReadPackString(hDataPack, szReason, sizeof(szReason));

		results.FetchString(0, szName, sizeof(szName));
		results.FetchString(1, szAuth, sizeof(szAuth));
		results.FetchString(2, szIp, sizeof(szIp));
		
		DebugMessage("SQL_Callback_OfflineBanSelectInfo -> '%s', '%s', '%s'", szName, szAuth, szIp)
		UTIL_CreateBan(iClient, _, szAuth, szName, szIp, g_iBanTime[iClient], szReason);
	}

	CloseHandle(hDataPack);
}

void UTIL_CreateBan(int iAdmin = 0, int iTarget = 0, const char[] szSourceAuth = "", const char[] szSourceName = "", const char[] szSourceIp = "", int iLength, const char[] szSourceReason, int iType = 0)
{
	DebugMessage("%N (%i) UTIL_CreateBan -> %i (%s), (%s)", iAdmin, iAdmin, iTarget, szSourceAuth, szSourceName)

	char szName[MAX_NAME_LENGTH*2+1], szIp[16], szQuery[512], szAuth[32], szAdminName[MAX_NAME_LENGTH*2+1], szAdminAuth[32];
	int iAdminUserID = strlen(szSourceReason)*2+1;
	char[] szReason = new char[iAdminUserID];
	g_hDatabase.Escape(szSourceReason, szReason, iAdminUserID);

	int iTargetUserID;
	if(iAdmin)
	{
		iAdminUserID = UID(iAdmin);
		GetClientName(iAdmin, szQuery, MAX_NAME_LENGTH);
		g_hDatabase.Escape(szQuery, szAdminName, sizeof(szAdminName));
		GetClientAuthId(iAdmin, AuthId_Engine, szAdminAuth, sizeof(szAdminAuth));
	}
	else
	{
		iAdminUserID = 0;
		strcopy(szAdminName, sizeof(szAdminName), "CONSOLE");
		strcopy(szAdminAuth, sizeof(szAdminAuth), "STEAM_ID_SERVER");
	}

	if(iTarget)
	{
		iTargetUserID = UID(iTarget);
		GetClientAuthId(iTarget, AuthId_Engine, szAuth, sizeof(szAuth));
		GetClientName(iTarget, szQuery, MAX_NAME_LENGTH);
		g_hDatabase.Escape(szQuery, szName, sizeof(szName));
		GetClientIP(iTarget, szIp, sizeof(szIp));
	}
	else
	{
		iTargetUserID = 0;
		if(szSourceAuth[0])
		{
			strcopy(szAuth, sizeof(szAuth), szSourceAuth);
		}
		else
		{
			strcopy(szAuth, sizeof(szAuth), "unknown");
		}
		g_hDatabase.Escape(szSourceName, szName, sizeof(szName));
		if(szSourceIp[0])
		{
			strcopy(szIp, sizeof(szIp), szSourceIp);
		}
		else
		{
			strcopy(szIp, sizeof(szIp), "unknown");
		}
	}
	
	Handle hDataPack = CreateDataPack();
	WritePackCell(hDataPack, iAdminUserID);
	WritePackCell(hDataPack, iTargetUserID);

	FormatEx(szQuery, sizeof(szQuery), "INSERT INTO `table_bans` (`auth`, `ip`, `name`, `ban_time`, `length`, `reason`, `admin_auth`, `admin_name`, `ban_type`) VALUES ( '%s', '%s', '%s', %i, %i, '%s', '%s', '%s', '%i');", szAuth, szIp, szName, GetTime(), iLength, szReason, szAdminAuth, szAdminName, iType);
	DebugMessage("szQuery: '%s'", szQuery)
	g_hDatabase.Query(SQL_Callback_InsertBan, szQuery, hDataPack);
}

public void SQL_Callback_InsertBan(Database hDatabase, DBResultSet results, const char[] sError, any hDataPack)
{
	if(sError[0])
	{
		LogError("SQL_Callback_InsertBan: %s", sError);
		CloseHandle(hDataPack);
		return;
	}
	
	ResetPack(hDataPack);
	
	int iClient = CID(ReadPackCell(hDataPack));
	if(iClient)
	{
		PrintToChat(iClient, "Бан успешно добавлен!");
	}
	iClient = CID(ReadPackCell(hDataPack));
	if(iClient)
	{
		UTIL_SearchBan(iClient);
	}
	CloseHandle(hDataPack);
}

void UTIL_SearchBan(int iClient)
{
	char szQuery[256], szAuth[32], szIp[16];
	GetClientAuthId(iClient, AuthId_Engine, szAuth, sizeof(szAuth));
	GetClientIP(iClient, szIp, sizeof(szIp));
	if(g_bCheckBanMode)
	{
		FormatEx(szQuery, sizeof(szQuery), "SELECT `id`, `ban_time`, `length`, `reason`, `admin_name`, `admin_auth` FROM `table_bans` WHERE `remove_type` = '0' AND (`auth` = '%s' OR `ip` = '%s');", szAuth, szIp);
	}
	else
	{
		FormatEx(szQuery, sizeof(szQuery), "SELECT `id`, `ban_time`, `length`, `reason`, `admin_name`, `admin_auth` FROM `table_bans` WHERE `remove_type` = '0' AND ((`auth` = '%s' AND `ban_type` = 0) OR (`ip` = '%s' AND `ban_type` = 1));", szAuth, szIp);
	}
	DebugMessage("szQuery: '%s'", szQuery)
	g_hDatabase.Query(SQL_Callback_SearchClientBan, szQuery, UID(iClient));
}

public void SQL_Callback_SearchClientBan(Database hDatabase, DBResultSet results, const char[] sError, any iUserID)
{
	if(sError[0])
	{
		LogError("SQL_Callback_SearchClientBan: %s", sError);
		return;
	}
	
	int iClient = GetClientOfUserId(iUserID);
	if(iClient)
	{
		if(results.FetchRow())
		{
			DebugMessage("FetchRow")
	
			int iBanTime = results.FetchInt(1);
			int iLength = results.FetchInt(2);
			int iTime = GetTime();
			if(iLength && iTime > iBanTime+iLength)
			{
				DebugMessage("UTIL_UnBan")
				UTIL_UnBan(results.FetchInt(0));
				return;
			}
			
			char szAuth[32], szBanReason[256], szAdminName[MAX_NAME_LENGTH], szAdminAuth[32], szBanTime[64], szDuration[64], szExp[64];
			GetClientAuthId(iClient, AuthId_Engine, szAuth, sizeof(szAuth));
			FormatTime(szBanTime, sizeof(szBanTime), g_szTimeFormat, iBanTime);	
			if(!GetDuration(iLength, szDuration, sizeof(szDuration)))
			{
				FormatEx(szDuration, sizeof(szDuration), "%i мин.", iLength/60);
			}
			
			if(iLength)
			{
				UTIL_GetTimeFromStamp(szExp, sizeof(szExp), ((iBanTime+iLength)-iTime), iClient);
				Format(szExp, sizeof(szExp), "через %s", szExp);
			}
			else
			{
				strcopy(szExp, sizeof(szExp), "Никогда");
			}

			results.FetchString(3, szBanReason, sizeof(szBanReason));
			results.FetchString(4, szAdminName, sizeof(szAdminName));
			results.FetchString(5, szAdminAuth, sizeof(szAdminAuth));
		
			PrintToConsole(iClient, "####################################################################");
			PrintToConsole(iClient, "####################################################################");
			PrintToConsole(iClient, "####################################################################");
			
			PrintToConsole(iClient, "###\t \t Вы забанены на этом сервере");
			PrintToConsole(iClient, "###\t \t Ваш SteamID: %s", szAuth);
			PrintToConsole(iClient, "###\t \t Забанен админом: %s (%s)", szAdminName, szAdminAuth);
			PrintToConsole(iClient, "###\t \t Причина: %s", szBanReason);
			PrintToConsole(iClient, "###\t \t Бан выдан: %s", szBanTime);
			PrintToConsole(iClient, "###\t \t Длительность: %s", szDuration);
			PrintToConsole(iClient, "###\t \t Истекает: %s", szExp);
			PrintToConsole(iClient, "###\t \t %s", g_szBanInfo);

			PrintToConsole(iClient, "####################################################################");
			PrintToConsole(iClient, "####################################################################");
			PrintToConsole(iClient, "####################################################################");
			
			char szBuffer[256];
			strcopy(szBuffer, sizeof(szBuffer), g_szBanInfoPanel);
			ReplaceString(szBuffer, sizeof(szBuffer), "\\n", "\n");
			ReplaceString(szBuffer, sizeof(szBuffer), "{AUTH}", szAuth);
			ReplaceString(szBuffer, sizeof(szBuffer), "{ADMIN_NAME}", szAdminName);
			ReplaceString(szBuffer, sizeof(szBuffer), "{ADMIN_AUTH}", szAdminAuth);
			ReplaceString(szBuffer, sizeof(szBuffer), "{REASON}", szBanReason);
			ReplaceString(szBuffer, sizeof(szBuffer), "{BAN_TIME}", szBanTime);
			ReplaceString(szBuffer, sizeof(szBuffer), "{DURATION}", szDuration);
			ReplaceString(szBuffer, sizeof(szBuffer), "{EXPIRES}", szExp);
			ReplaceString(szBuffer, sizeof(szBuffer), "{BAN_INFO}", g_szBanInfo);
			
			DebugMessage("Banned")
			DataPack hPack;
			CreateDataTimer(KICK_DELAY, Timer_KickDelay, hPack);
			hPack.WriteCell(UID(iClient));
			hPack.WriteString(szBuffer);
		}
	}
}

bool GetDuration(int iDuration, char[] szBuffer, int iMaxLen)
{
	g_hKeyValues.Rewind();
	char szKey[64];
	FormatEx(szKey, sizeof(szKey), "ban_times/%i", iDuration/60);
	g_hKeyValues.GetString(szKey, szBuffer, iMaxLen);
	return (szBuffer[0]);
}

public Action Timer_KickDelay(Handle hTimer, Handle hDataPack)
{
	ResetPack(hDataPack);
	int iClient = CID(ReadPackCell(hDataPack));
	DebugMessage("Timer_KickDelay: %i", iClient)
	if(iClient)
	{
		char szMessage[512];
		ReadPackString(hDataPack, szMessage, sizeof(szMessage));
		KickClient(iClient, szMessage);
	}

	return Plugin_Stop;
}

void UTIL_UnBan(int iBanID, int iType = 1)
{
	char szQuery[256];
	FormatEx(szQuery, sizeof(szQuery), "UPDATE `table_bans` SET `remove_type` = %i WHERE `id` = '%i';", iType, iBanID);
	g_hDatabase.Query(SQL_Callback_CheckError, szQuery);
}

void UTIL_RemoveBan(int iBanID)
{
	char szQuery[256];
	FormatEx(szQuery, sizeof(szQuery), "DELETE FROM `table_bans` WHERE `id` = '%i';", iBanID);
	g_hDatabase.Query(SQL_Callback_CheckError, szQuery);
}

void UTIL_GetTimeFromStamp(char[] szBuffer, int iMaxLen, int iTimeStamp, int iClient = LANG_SERVER)
{
	if (iTimeStamp > 31536000)
	{
		int years = iTimeStamp / 31536000;
		int days = iTimeStamp / 86400 % 365;
		if (days > 0)
		{
			FormatEx(szBuffer, iMaxLen, "%d г. %d д.", years, days);
		}
		else
		{
			FormatEx(szBuffer, iMaxLen, "%d г.", years);
		}
		return;
	}
	if (iTimeStamp > 86400)
	{
		int days = iTimeStamp / 86400 % 365;
		int hours = (iTimeStamp / 3600) % 24;
		if (hours > 0)
		{
			FormatEx(szBuffer, iMaxLen, "%d д. %d ч.", days, hours);
		}
		else
		{
			FormatEx(szBuffer, iMaxLen, "%d д.", days);
		}
		return;
	}
	else
	{
		int Hours = (iTimeStamp / 3600);
		int Mins = (iTimeStamp / 60) % 60;
		int Secs = iTimeStamp % 60;
		
		if (Hours > 0)
		{
			FormatEx(szBuffer, iMaxLen, "%02d:%02d:%02d", Hours, Mins, Secs);
		}
		else
		{
			FormatEx(szBuffer, iMaxLen, "%02d:%02d", Mins, Secs);
		}
	}
}
