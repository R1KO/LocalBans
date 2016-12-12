
public void AdminMenu_Ban(Handle hTopMenu, TopMenuAction action, TopMenuObject topobj_id, int iClient, char[] szBuffer, int iMaxLength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		FormatEx(szBuffer, iMaxLength, "Забанить игрока");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayBanTargetMenu(iClient);
	}
}

void DisplayBanTargetMenu(int iClient)
{
	Menu hMenu = CreateMenu(MenuHandler_BanPlayerList);

	hMenu.SetTitle("Выберите игрока:\n ");
	hMenu.ExitBackButton = true;

	char szName[MAX_NAME_LENGTH], szUserID[16];
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && CanUserTarget(iClient, i))
		{
			I2S(UID(i), szUserID, sizeof(szUserID));
			GetClientName(i, szName, sizeof(szName));
			hMenu.AddItem(szUserID, szName);
		}
	}
	if(!szUserID[0])
	{
		hMenu.AddItem("", "Нет доступных игроков", ITEMDRAW_DISABLED);
	}

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_BanPlayerList(Menu hMenu, MenuAction action, int iClient, int Item)
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
			char szUserID[16];
			hMenu.GetItem(Item, szUserID, sizeof(szUserID));
			
			int iUserID = S2I(szUserID);
			int iTarget = CID(iUserID);

			if (iTarget == 0)
			{
				PrintToChat(iClient, "[SM] %t", "Player no longer available");
			}
			else if (!CanUserTarget(iClient, iTarget))
			{
				PrintToChat(iClient, "[SM] %t", "Unable to target");
			}
			else
			{
				g_iBanTarget[iClient] = iUserID;
				g_bOffBan[iClient] = false;
				DisplayBanTimeMenu(iClient);
			}
		}
	}
	
	return 0;
}

void DisplayBanTimeMenu(int iClient)
{
	Menu hMenu = CreateMenu(MenuHandler_BanTime);

	hMenu.SetTitle("Выберите срок:\n ");
	hMenu.ExitBackButton = true;
	
	g_hKeyValues.Rewind();
	if(g_hKeyValues.JumpToKey("ban_times") && g_hKeyValues.GotoFirstSubKey(false))
	{
		char szTime[16], szTimeDisplay[64];
		do
		{
			g_hKeyValues.GetSectionName(szTime, sizeof(szTime));
			g_hKeyValues.GetString(NULL_STRING, szTimeDisplay, sizeof(szTimeDisplay));
			hMenu.AddItem(szTime, szTimeDisplay);
		} while (g_hKeyValues.GotoNextKey(false));
	}

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_BanTime(Menu hMenu, MenuAction action, int iClient, int Item)
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
				DisplayBanTargetMenu(iClient);
			}
		}
	case MenuAction_Select:
		{
			if (!g_bOffBan[iClient] && CID(g_iBanTarget[iClient]) == 0)
			{
				PrintToChat(iClient, "[SM] %t", "Player no longer available");
			}
			else
			{
				char szTime[16];
				hMenu.GetItem(Item, szTime, sizeof(szTime));
				g_iBanTime[iClient] = S2I(szTime);
				DisplayBanReasonMenu(iClient);
			}
		}
	}
	
	return 0;
}

void DisplayBanReasonMenu(int iClient)
{
	Menu hMenu = CreateMenu(MenuHandler_BanReason);

	hMenu.SetTitle("Выберите причину:\n ");
	hMenu.ExitBackButton = true;
	
	g_hKeyValues.Rewind();
	if(g_hKeyValues.JumpToKey("ban_reasons") && g_hKeyValues.GotoFirstSubKey(false))
	{
		char szReason[128], szReasonDisplay[128];
		do
		{
			g_hKeyValues.GetSectionName(szReason, sizeof(szReason));
			g_hKeyValues.GetString(NULL_STRING, szReasonDisplay, sizeof(szReasonDisplay));
			hMenu.AddItem(szReason, szReasonDisplay);
		} while (g_hKeyValues.GotoNextKey(false));
	}

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_BanReason(Menu hMenu, MenuAction action, int iClient, int Item)
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
				DisplayBanTargetMenu(iClient);
			}
		}
	case MenuAction_Select:
		{
			char szReason[128];
			hMenu.GetItem(Item, szReason, sizeof(szReason));
			if (strcmp(szReason, "own") == 0)
			{
				g_bWaitChat[iClient] = true;
				g_bSearch[iClient] = false;
				DisplayWaitChatMenu(iClient);
				return 0;
			}

			if (g_bOffBan[iClient])
			{
				UTIL_OfflineBan(iClient, g_iBanTarget[iClient], szReason);
			}
			else
			{
				int iTarget = CID(g_iBanTarget[iClient]);
				if (iTarget == 0)
				{
					PrintToChat(iClient, "[SM] %t", "Player no longer available");
				}
				else
				{
					UTIL_CreateBan(iClient, iTarget, _, _, _,  g_iBanTime[iClient]*60, szReason);
				}
			}
		}
	}
	
	return 0;
}