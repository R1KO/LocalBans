
void CreateTables()
{
	SQL_LockDatabase(g_hDatabase);
	g_hDatabase.Query(SQL_Callback_CheckError,	"CREATE TABLE IF NOT EXISTS `table_bans` (\
															`id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,\
															`auth` VARCHAR(32) NOT NULL,\
															`ip` VARCHAR(16) NOT NULL default 'unknown',\
															`name` VARCHAR(32) NOT NULL default 'unknown',\
															`ban_time` INTEGER UNSIGNED NOT NULL,\
															`length` INTEGER UNSIGNED NOT NULL,\
															`reason` VARCHAR(255) NOT NULL,\
															`ban_type` INTEGER UNSIGNED NOT NULL default '0',\
															`admin_auth` VARCHAR(32) NOT NULL,\
															`admin_name` VARCHAR(32) NOT NULL,\
															`remove_type` INTEGER UNSIGNED NOT NULL default '0');");

	g_hDatabase.Query(SQL_Callback_CheckError,	"CREATE TABLE IF NOT EXISTS `table_offline` (\
															`id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,\
															`auth` VARCHAR(32) NOT NULL,\
															`ip` VARCHAR(16) NOT NULL default 'unknown',\
															`name` VARCHAR(32) NOT NULL default 'unknown',\
															`time_disconnect` INTEGER UNSIGNED NOT NULL);");
	SQL_UnlockDatabase(g_hDatabase);
}

public void SQL_Callback_CheckError(Database hDatabase, DBResultSet results, const char[] sError, any data)
{
	if(sError[0])
	{
		LogError("SQL_Callback_CheckError: %s", sError);
	}
}