

public void AdminMenu_OfflineBan(Handle hTopMenu, TopMenuAction action, TopMenuObject topobj_id, int iClient, char[] szBuffer, int iMaxLength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		FormatEx(szBuffer, iMaxLength, "Забанить игрока (Оффлайн)");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayOfflineListMenu(iClient);
	}
}

void DisplayOfflineListMenu(int iClient)
{
	char szQuery[256];
	FormatEx(szQuery, sizeof(szQuery), "SELECT `id`, `name`, `time_disconnect` FROM `table_offline` ORDER BY `time_disconnect` DESC LIMIT %i, %i;", g_iClientOffset[iClient], g_iClientOffset[iClient]+g_iShowBansCount);
	
	g_hDatabase.Query(SQL_Callback_SelectOfflineList, szQuery, UID(iClient));
}

public void SQL_Callback_SelectOfflineList(Database hDatabase, DBResultSet results, const char[] sError, any iUserID)
{
	if(sError[0])
	{
		LogError("SQL_Callback_SelectOfflineList: %s", sError);
		return;
	}
	
	int iClient = CID(iUserID);
	if(iClient)
	{
		Menu hMenu = CreateMenu(MenuHandler_OfflineList);

		hMenu.SetTitle("Оффлайн бан:\n ");
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

public int MenuHandler_OfflineList(Menu hMenu, MenuAction action, int iClient, int Item)
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
				g_bOffBan[iClient] = true;
				DisplayWaitChatMenu(iClient);
				return 0;
			}

			DisplayOfflineBanInfoMenu(iClient, S2I(szID));
		}
	}
	
	return 0;
}

void DisplayOfflineBanInfoMenu(int iClient, int iID)
{
	char szQuery[256];
	FormatEx(szQuery, sizeof(szQuery), "SELECT `id`, `name`, `auth`, `ip`, `time_disconnect` FROM `table_offline` WHERE `id` = '%i';", iID);

	g_hDatabase.Query(SQL_Callback_SelectOfflineBanInfo, szQuery, UID(iClient));
}

public void SQL_Callback_SelectOfflineBanInfo(Database hDatabase, DBResultSet results, const char[] sError, any iUserID)
{
	if(sError[0])
	{
		LogError("SQL_Callback_SelectOfflineBanInfo: %s", sError);
		return;
	}
	
	int iClient = GetClientOfUserId(iUserID);
	if(iClient && results.FetchRow())
	{
		Menu hMenu = CreateMenu(MenuHandler_OfflineBanInfo);
		hMenu.ExitBackButton = true;

		char szID[16], szName[MAX_NAME_LENGTH], szAuth[32], szIp[16], szDiscTime[64];
		results.FetchString(0, szID, sizeof(szID));
		results.FetchString(1, szName, sizeof(szName));
		results.FetchString(2, szAuth, sizeof(szAuth));
		results.FetchString(3, szIp, sizeof(szIp));

		FormatTime(szDiscTime, sizeof(szDiscTime), g_szTimeFormat, results.FetchInt(4));	

		hMenu.SetTitle("Ник: %s\n\
						SteamID: %s\n\
						Отключился: %s",
						szName,
						szAuth,
						szDiscTime);

		hMenu.AddItem(szID, "Забанить");

		hMenu.AddItem("", "", ITEMDRAW_NOTEXT);
		hMenu.AddItem("", "", ITEMDRAW_NOTEXT);
		hMenu.AddItem("", "", ITEMDRAW_NOTEXT);
		hMenu.AddItem("", "", ITEMDRAW_NOTEXT);
		hMenu.AddItem("", "", ITEMDRAW_NOTEXT);

		hMenu.Display(iClient, MENU_TIME_FOREVER);
	}
}

public int MenuHandler_OfflineBanInfo(Menu hMenu, MenuAction action, int iClient, int Item)
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

			g_iBanTarget[iClient] = S2I(szID);
			g_bOffBan[iClient] = true;
			DebugMessage("%N (%i) MenuHandler_OfflineBanInfo -> %i", iClient, iClient, g_iBanTarget[iClient])
			DisplayBanTimeMenu(iClient);
		}
	}
	
	return 0;
}