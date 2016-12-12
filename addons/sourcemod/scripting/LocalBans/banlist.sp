
public void AdminMenu_BanList(Handle hTopMenu, TopMenuAction action, TopMenuObject topobj_id, int iClient, char[] szBuffer, int iMaxLength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		FormatEx(szBuffer, iMaxLength, "Банлист");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iClientOffset[iClient] = 0;
		DisplayBanListMenu(iClient);
	}
}

void DisplayBanListMenu(int iClient)
{
	char szQuery[256];
	if(g_bShowBansMode)
	{
		FormatEx(szQuery, sizeof(szQuery), "SELECT `id`, `name`, `remove_type` FROM `table_bans` LIMIT %i, %i;", g_iClientOffset[iClient], g_iClientOffset[iClient]+g_iShowBansCount);
	}
	else
	{
		FormatEx(szQuery, sizeof(szQuery), "SELECT `id`, `name` FROM `table_bans` WHERE `remove_type` = '0' LIMIT %i, %i;", g_iClientOffset[iClient], g_iClientOffset[iClient]+g_iShowBansCount);
	}
	
	g_hDatabase.Query(SQL_Callback_SelectBanList, szQuery, UID(iClient));
}

public void SQL_Callback_SelectBanList(Database hDatabase, DBResultSet results, const char[] sError, any iUserID)
{
	if(sError[0])
	{
		LogError("SQL_Callback_SelectBanList: %s", sError);
		return;
	}
	
	int iClient = GetClientOfUserId(iUserID);
	if(iClient)
	{
		Menu hMenu = CreateMenu(MenuHandler_BanList);

		hMenu.SetTitle("Список банов:\n ");
		hMenu.ExitBackButton = true;

		if(results.RowCount)
		{
			hMenu.AddItem("search", "Поиск\n ");

			char szName[MAX_NAME_LENGTH*2], szID[16];
			int i = 0;
			while(results.FetchRow())
			{
				results.FetchString(0, szID, sizeof(szID));
				results.FetchString(1, szName, sizeof(szName));
				hMenu.AddItem(szID, szName);
				if(g_bShowBansMode)
				{
					switch(results.FetchInt(2))
					{
						case 1:	StrCat(szName, sizeof(szName), " (Истек)");
						case 2:	StrCat(szName, sizeof(szName), " (Разбанен)");
					}
				}
				++i;
			}
			
			if(i == g_iShowBansCount)
			{
				hMenu.AddItem("more", "Показать больше банов");
			}
		}
		else
		{
			hMenu.AddItem("", "Нет доступных банов", ITEMDRAW_DISABLED);
		}

		hMenu.Display(iClient, MENU_TIME_FOREVER);
	}
}

public int MenuHandler_BanList(Menu hMenu, MenuAction action, int iClient, int Item)
{
	switch(action)
	{
	case MenuAction_End:
		{
			delete hMenu;
		}
	case MenuAction_Cancel:
		{
			if (Item == MenuCancel_ExitBack && g_hTopMenu)
			{
				g_hTopMenu.Display(iClient, TopMenuPosition_LastCategory);
			}
		}
	case MenuAction_Select:
		{
			char szID[16];
			hMenu.GetItem(Item, szID, sizeof(szID));
			if(strcmp(szID, "more") == 0)
			{
				g_iClientOffset[iClient] += g_iShowBansCount;
				DisplayBanListMenu(iClient);
				return 0;
			}
			if(strcmp(szID, "search") == 0)
			{
				g_bWaitChat[iClient] = true;
				g_bSearch[iClient] = true;
				g_bOffBan[iClient] = false;
				DisplayWaitChatMenu(iClient);
				return 0;
			}

			DisplayBanInfoMenu(iClient, S2I(szID));
		}
	}
	
	return 0;
}

void DisplayBanInfoMenu(int iClient, int iID)
{
	char szQuery[256];
	FormatEx(szQuery, sizeof(szQuery), "SELECT `id`, `name`, `admin_name`, `admin_auth`, `ban_time`, `length`, `reason`, `remove_type` FROM `table_bans` WHERE `id` = '%i';", iID);

	g_hDatabase.Query(SQL_Callback_SelectBanInfo, szQuery, UID(iClient));
}

public void SQL_Callback_SelectBanInfo(Database hDatabase, DBResultSet results, const char[] sError, any iUserID)
{
	if(sError[0])
	{
		LogError("SQL_Callback_SelectBanInfo: %s", sError);
		return;
	}
	
	int iClient = GetClientOfUserId(iUserID);
	if(iClient && results.FetchRow())
	{
		Menu hMenu = CreateMenu(MenuHandler_BanInfo);
		hMenu.ExitBackButton = true;
		
		int iID = results.FetchInt(0);
		int iBanTime = results.FetchInt(4);
		int iLength = results.FetchInt(5);
		int iTime = GetTime();
		
		char szID[16], szAuth[32], szName[MAX_NAME_LENGTH], szBanReason[256], szAdminName[MAX_NAME_LENGTH], szAdminAuth[32], szAdminAuth2[32], szBanTime[64], szDuration[64], szExp[64];
		results.FetchString(1, szName, sizeof(szName));
		results.FetchString(2, szAdminName, sizeof(szAdminName));
		results.FetchString(3, szAdminAuth, sizeof(szAdminAuth));
		results.FetchString(6, szBanReason, sizeof(szBanReason));
		GetClientAuthId(iClient, AuthId_Engine, szAdminAuth2, sizeof(szAdminAuth2));
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

		if(g_bShowBansMode)
		{
			char szBuffer[64];
			
			switch(results.FetchInt(7))
			{
				case 0:	FormatEx(szBuffer, sizeof(szBuffer), "Активный\nИстекает: %s", szExp);
				case 1:	strcopy(szBuffer, sizeof(szBuffer), "Истек");
				case 2:	strcopy(szBuffer, sizeof(szBuffer), "Разбанен");
			}

			hMenu.SetTitle("SteamID: %s\n\
						Ник: %s\n\
						Забанен админом: %s\n\
						Причина: %s\n\
						Бан выдан: %s\n\
						Длительность: %s\n\
						Статус: %s",
						szAuth,
						szName,
						szAdminName,
						szBanReason,
						szBanTime,
						szDuration,
						szBuffer);
		}
		else
		{
			hMenu.SetTitle("SteamID: %s\n\
						Ник: %s\n\
						Забанен админом: %s\n\
						Причина: %s\n\
						Бан выдан: %s\n\
						Длительность: %s\n\
						Истекает: %s",
						szAuth,
						szName,
						szAdminName,
						szBanReason,
						szBanTime,
						szDuration,
						szExp);
		}

		bool bRemoveBanAccess = CheckCommandAccess(iClient, "sm_remove_ban", ADMFLAG_UNBAN);
		bool bUnBanAccess = CheckCommandAccess(iClient, "sm_unban", ADMFLAG_UNBAN);
		bool bItsHimBan = (strcmp(szAdminAuth2, szAdminAuth) == 0);
		
		if((g_bUnBanMode && (bItsHimBan || bUnBanAccess)) || (!g_bUnBanMode && bUnBanAccess))
		{
			FormatEx(szID, sizeof(szID), "u%i", iID);
			hMenu.AddItem(szID, "Разбанить");
		}
		
		if((g_bRemoveBanMode && (bItsHimBan || bRemoveBanAccess)) || (!g_bRemoveBanMode && bRemoveBanAccess))
		{
			FormatEx(szID, sizeof(szID), "r%i", iID);
			hMenu.AddItem(szID, "Удалить");
		}
		
		hMenu.AddItem("", "", ITEMDRAW_NOTEXT);
		hMenu.AddItem("", "", ITEMDRAW_NOTEXT);
		hMenu.AddItem("", "", ITEMDRAW_NOTEXT);
		hMenu.AddItem("", "", ITEMDRAW_NOTEXT);

		hMenu.Display(iClient, MENU_TIME_FOREVER);
	}
}

public int MenuHandler_BanInfo(Menu hMenu, MenuAction action, int iClient, int Item)
{
	switch(action)
	{
	case MenuAction_End:
		{
			delete hMenu;
		}
	case MenuAction_Cancel:
		{
			if (Item == MenuCancel_ExitBack)
			{
				DisplayBanListMenu(iClient);
			}
		}
	case MenuAction_Select:
		{
			char szID[16];
			hMenu.GetItem(Item, szID, sizeof(szID));

			int iID = S2I(szID[1]);
			if(szID[0] == 'u')
			{
				UTIL_UnBan(iID, 2);
				DisplayBanInfoMenu(iClient, iID);
				PrintToChat(iClient, "Игрок разбанен!");
				return 0;
			}

			if(szID[0] == 'r')
			{
				UTIL_RemoveBan(iID);
				DisplayBanListMenu(iClient);
				PrintToChat(iClient, "Бан удален!");
				return 0;
			}
		}
	}
	
	return 0;
}