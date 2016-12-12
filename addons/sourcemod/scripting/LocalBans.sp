#pragma semicolon 1
#include <sourcemod>
#include <adminmenu>

#pragma newdecls required

#define PLUGIN_VERSION	"1.0"

public Plugin myinfo =
{
	name        = "Local Bans",
	author      = "R1KO",
	version     = PLUGIN_VERSION,
	url         = "http://hlmod.ru"
};

#define UID(%0) GetClientUserId(%0)
#define CID(%0) GetClientOfUserId(%0)

#define S2I(%0) StringToInt(%0)
#define I2S(%0) IntToString(%0)

#define KICK_DELAY		4.0
 
#define DEBUG_MODE 0

#if DEBUG_MODE 1

static const char g_szDebugLogFile[] = "addons/sourcemod/logs/LocalBans_Debug.log";

stock void DebugMsg(const char[] szMsg, any ...)
{
	char szBuffer[512];
	VFormat(szBuffer, sizeof(szBuffer), szMsg, 2);
	LogToFile(g_szDebugLogFile, szBuffer);
}

#define DebugMessage(%0) DebugMsg(%0);
#else
#define DebugMessage(%0)
#endif

int		g_iShowBansCount;		//	Количество запрашиваемых банов
bool	g_bShowBansMode;		//	Режим отображения банов 1 - Показывать все баны / 0 - Только активные
bool	g_bRemoveBanMode;		//	Кто может удалять баны (0 - Только root, 1 - Root и забанивший админ)
bool	g_bUnBanMode;			//	Кто может разбанивать (0 - Только root, 1 - Root и забанивший админ)
bool	g_bCheckBanMode;		//	Режим проверки бана (0 - Проверять только SteamID, 1 - Проверять SteamID и IP)
char	g_szBanInfo[128];		//	Информация для игроков
char	g_szBanInfoPanel[256];	//	Формат окна информации о бане

char	g_szTimeFormat[64];		//	Формат вывода времени ("%d/%m/%Y-%H:%M:%S")
bool	g_bOffBanMapClear;		//	Очищать ли историю игроков при смене карты
bool	g_bOffBanDelConPlayers;	//	Удалять ли из истории вновь подключившихся игроков

bool	g_bWaitChat[MAXPLAYERS+1];
bool	g_bSearch[MAXPLAYERS+1];
bool	g_bOffBan[MAXPLAYERS+1];
int		g_iBanTarget[MAXPLAYERS+1];
int		g_iBanTime[MAXPLAYERS+1];
int		g_iClientOffset[MAXPLAYERS+1];

Database	g_hDatabase;
KeyValues	g_hKeyValues;
TopMenu		g_hTopMenu;

#include "LocalBans/util.sp"
#include "LocalBans/db.sp"
#include "LocalBans/cmds.sp"
#include "LocalBans/ban.sp"
#include "LocalBans/banlist.sp"
#include "LocalBans/offlineban.sp"

public void OnPluginStart()
{
	char sError[128];
	g_hDatabase = SQLite_UseDatabase("local_bans", sError, sizeof(sError));
	if (g_hDatabase == null)
	{
		SetFailState("Не удалось подключиться к базе данных '%s'", sError);
		return;
	}

	CreateTables();

	LoadTranslations("common.phrases");

	TopMenu hTopMenu;
	if ((hTopMenu = GetAdminTopMenu()) != null)
	{
		OnAdminMenuReady(hTopMenu);
	}

	RegAdminCmd("sm_ban", Command_Ban, ADMFLAG_BAN, "sm_ban <#userid|name> <minutes|0> [reason]");
	RegAdminCmd("sm_unban", Command_Unban, ADMFLAG_UNBAN, "sm_unban <steamid|ip>");
	RegAdminCmd("sm_addban", Command_AddBan, ADMFLAG_RCON, "sm_addban <steamid> <time> [reason] [name]");
	RegAdminCmd("sm_banip", Command_BanIp, ADMFLAG_BAN, "sm_banip <ip|#userid|name> <time> [reason]");
}

public void OnConfigsExecuted()
{
	if(g_hKeyValues != null)
	{
		delete g_hKeyValues;
	}

	g_hKeyValues = new KeyValues("LocalBans");
	
	char szBuffer[256];
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "configs/localbans.ini");
	if(!g_hKeyValues.ImportFromFile(szBuffer))
	{
		SetFailState("Не удалось открыть файл '%s'", szBuffer);
		return;
	}

	g_hKeyValues.Rewind();
	
	g_iShowBansCount	= g_hKeyValues.GetNum("show_bans_count", 20);
	g_bShowBansMode		= view_as<bool>(g_hKeyValues.GetNum("show_bans_mode"));
	g_bRemoveBanMode	= view_as<bool>(g_hKeyValues.GetNum("rmban_mode"));
	g_bUnBanMode		= view_as<bool>(g_hKeyValues.GetNum("unban_mode"));
	g_bCheckBanMode		= view_as<bool>(g_hKeyValues.GetNum("check_ban_mode"));
	g_hKeyValues.GetString("info", g_szBanInfo, sizeof(g_szBanInfo));
	g_hKeyValues.GetString("timeformat", g_szTimeFormat, sizeof(g_szTimeFormat), "%d/%m/%Y-%H:%M:%S");

	g_bOffBanMapClear		= view_as<bool>(g_hKeyValues.GetNum("offban_map_clear"));
	g_bOffBanDelConPlayers	= view_as<bool>(g_hKeyValues.GetNum("offban_del_con_players"));
	g_hKeyValues.GetString("ban_info", g_szBanInfoPanel, sizeof(g_szBanInfoPanel));
	
	if(g_bOffBanMapClear)
	{
		g_hDatabase.Query(SQL_Callback_CheckError,	"DELETE FROM `table_offline`;");
	}
}

public void OnClientPostAdminCheck(int iClient)
{
	if(!IsFakeClient(iClient))
	{
		UTIL_SearchBan(iClient);
	}

	if(g_bOffBanDelConPlayers)
	{
		char szQuery[256], szAuth[32];
		GetClientAuthId(iClient, AuthId_Engine, szAuth, sizeof(szAuth));
		FormatEx(szQuery, sizeof(szQuery), "DELETE FROM `table_offline` WHERE `auth` = '%s';", szAuth);
		g_hDatabase.Query(SQL_Callback_CheckError, szQuery);
	}
}

public void OnClientDisconnect(int iClient) 
{
	if (!IsFakeClient(iClient) && GetUserAdmin(iClient) == INVALID_ADMIN_ID) 
	{
		char szQuery[256], szAuth[32], szName[MAX_NAME_LENGTH*2+1], szIp[16];
		GetClientAuthId(iClient, AuthId_Engine, szAuth, sizeof(szAuth));
		GetClientIP(iClient, szIp, sizeof(szIp));
		GetClientName(iClient, szQuery, MAX_NAME_LENGTH);
		g_hDatabase.Escape(szQuery, szName, sizeof(szName));
		
		FormatEx(szQuery, sizeof(szQuery), "INSERT INTO `table_offline` (`auth`, `ip`, `name`, `time_disconnect`) VALUES ('%s', '%s', '%s', %i)", szAuth, szIp, szName, GetTime());
		g_hDatabase.Query(SQL_Callback_CheckError, szQuery);
	}
}

public void OnAdminMenuReady(Handle hSourceTopMenu)
{
	TopMenu hTopMenu = TopMenu.FromHandle(hSourceTopMenu);

	if (g_hTopMenu == hTopMenu)
	{
		return;
	}

	g_hTopMenu = hTopMenu;

	TopMenuObject TopMenuCategory = g_hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

	if (TopMenuCategory != INVALID_TOPMENUOBJECT)
	{
		g_hTopMenu.AddItem("sm_ban", AdminMenu_Ban, TopMenuCategory, "sm_ban", ADMFLAG_BAN);
		g_hTopMenu.AddItem("sm_offlineban", AdminMenu_OfflineBan, TopMenuCategory, "sm_offlineban", ADMFLAG_BAN);
		g_hTopMenu.AddItem("sm_banlist", AdminMenu_BanList, TopMenuCategory, "sm_banlist", ADMFLAG_BAN);
	}
}

public Action OnClientSayCommand(int iClient, const char[] szCommand, const char[] szArgs)
{
	if(iClient && g_bWaitChat[iClient])
	{
		DisplayWaitChatMenu(iClient, szArgs);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}


void DisplayWaitChatMenu(int iClient, const char[] szValue = "")
{
	Menu hMenu = CreateMenu(MenuHandler_WaitChat);
	hMenu.ExitBackButton = true;

	if(g_bSearch[iClient])
	{
		hMenu.SetTitle("Введите в чат ник/стим\n ");
	}
	else
	{
		hMenu.SetTitle("Введите в чат свою причину\n ");
	}
	
	if(szValue[0])
	{
		char szBuffer[128];

		if(g_bSearch[iClient])
		{
			FormatEx(szBuffer, sizeof(szBuffer), "Найти \"%s\"", szValue);
		}
		else
		{
			FormatEx(szBuffer, sizeof(szBuffer), "Принять \"%s\"", szValue);
		}
	
		hMenu.AddItem(szValue, szBuffer);
	}
	else
	{
		char szBuffer[128];

		if(g_bSearch[iClient])
		{
			strcopy(szBuffer, sizeof(szBuffer), "Найти");
		}
		else
		{
			strcopy(szBuffer, sizeof(szBuffer), "Принять");
		}
		
		hMenu.AddItem("", szBuffer, ITEMDRAW_DISABLED);
	}

	hMenu.AddItem("", "", ITEMDRAW_NOTEXT);
	hMenu.AddItem("", "", ITEMDRAW_NOTEXT);
	hMenu.AddItem("", "", ITEMDRAW_NOTEXT);
	hMenu.AddItem("", "", ITEMDRAW_NOTEXT);
	hMenu.AddItem("", "", ITEMDRAW_NOTEXT);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_WaitChat(Menu hMenu, MenuAction action, int iClient, int Item)
{
	switch(action)
	{
	case MenuAction_End:
		{
			delete hMenu;
		}
	case MenuAction_Cancel:
		{
			g_bWaitChat[iClient] = false;
			if (Item == MenuCancel_ExitBack)
			{
				if(g_bOffBan[iClient])
				{
					DisplayOfflineListMenu(iClient);
				}
				else
				{
					DisplayBanListMenu(iClient);
				}
			}
		}
	case MenuAction_Select:
		{
			g_bWaitChat[iClient] = false;
			char szBuffer[128];
			hMenu.GetItem(Item, szBuffer, sizeof(szBuffer));
			if(g_bSearch[iClient])
			{
				char szQuery[256];
				if(g_bOffBan[iClient])
				{
					FormatEx(szQuery, sizeof(szQuery), "SELECT `id`, `name`, `time_disconnect` FROM `table_offline` WHERE `auth` LIKE '%%%s%%' OR `name` LIKE '%%%s%%' ORDER BY `time_disconnect` DESC;", szBuffer, szBuffer);
					g_hDatabase.Query(SQL_Callback_SelectOfflineList, szQuery, UID(iClient));
				}
				else
				{
					FormatEx(szQuery, sizeof(szQuery), "SELECT `id`, `name` FROM `table_bans` WHERE `auth` LIKE '%%%s%%' OR `name` LIKE '%%%s%%';", szBuffer, szBuffer);
					g_hDatabase.Query(SQL_Callback_SelectBanList, szQuery, UID(iClient));
				}
			}
			else
			{
				if (g_bOffBan[iClient])
				{
					UTIL_OfflineBan(iClient, g_iBanTarget[iClient], szBuffer);
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
						UTIL_CreateBan(iClient, iTarget, _, _, _,  g_iBanTime[iClient]*60, szBuffer);
					}
				}
			}
		}
	}

	return 0;
}


//	#define BANFLAG_AUTO		(1<<0)	/**< Auto-detects whether to ban by steamid or IP */
//	#define BANFLAG_IP			(1<<1)	/**< Always ban by IP address */
//	#define BANFLAG_AUTHID		(1<<2)	/**< Always ban by authstring (for BanIdentity) if possible */
//	#define BANFLAG_NOKICK		(1<<3)	/**< Does not kick the client */

/**
 * Called for calls to BanClient() with a non-empty command.
 *
 * @param client		Client being banned.
 * @param time			Time the client is being banned for (0 = permanent).
 * @param flags			One if AUTHID or IP will be enabled.  If AUTO is also 
 *						enabled, it means Core autodetected which to use.
 * @param reason		Reason passed via BanClient().
 * @param kick_message	Kick message passed via BanClient().
 * @param command		Command string to identify the ban source.
 * @param source		Source value passed via BanClient().
 * @return				Plugin_Handled to block the actual server banning.
 *						Kicking will still occur.
 */
public Action OnBanClient(int iClient, int iTime, int iFlags, const char[] szReason, const char[] szKickMsg, const char[] szCmd, any iAdmin)
{
	DebugMessage("OnBanClient: %i, %i, %i, %s, %s, %s, %i", iClient, iTime, iFlags, szReason, szKickMsg, szCmd, iAdmin)
	
	UTIL_CreateBan(iAdmin, iClient, _, _, _, iTime*60, szReason, (iFlags & BANFLAG_IP) ? 1:0);
}

/**
 * Called for calls to BanIdentity() with a non-empty command.
 *
 * @param identity		Identity string being banned (authstring or ip).
 * @param time			Time the client is being banned for (0 = permanent).
 * @param flags			Ban flags (only IP or AUTHID are valid here).
 * @param reason		Reason passed via BanIdentity().
 * @param command		Command string to identify the ban source.
 * @param source		Source value passed via BanIdentity().
 * @return				Plugin_Handled to block the actual server banning.
 */
public Action OnBanIdentity(const char[] szAuth, int iTime, int iFlags, const char[] szReason, const char[] szCmd, any iAdmin)
{
	DebugMessage("OnBanIdentity: %s, %i, %i, %s, %s, %i", szAuth, iTime, iFlags, szReason, szCmd, iAdmin)
	
	if(iFlags & BANFLAG_IP)
	{
		UTIL_CreateBan(iAdmin, 0, _, _, szAuth, iTime*60, szReason, 1);
	}
	else
	{
		UTIL_CreateBan(iAdmin, 0, szAuth, _, _, iTime*60, szReason);
	}
}

/**
 * Called for calls to RemoveBan() with a non-empty command.
 *
 * @param identity		Identity string being banned (authstring or ip).
 * @param flags			Ban flags (only IP or AUTHID are valid here).
 * @param command		Command string to identify the ban source.
 * @param source		Source value passed via BanIdentity().
 * @return				Plugin_Handled to block the actual server banning.
 */
public Action OnRemoveBan(const char[] szAuth, int iFlags, const char[] szCmd, any iAdmin)
{
	DebugMessage("OnRemoveBan: %s, %i, %s, %i", szAuth, iFlags, szCmd, iAdmin)
	
	char szQuery[256];
	FormatEx(szQuery, sizeof(szQuery), "UPDATE `table_bans` SET `remove_type` = 1 WHERE `remove_type` = '0' AND (`auth` = '%s' OR `ip` = '%s');", szAuth, szAuth);
	g_hDatabase.Query(SQL_Callback_CheckError, szQuery);
}
