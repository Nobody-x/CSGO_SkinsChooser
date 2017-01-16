/**
* CS:GO Skins Chooser by Root
*
* Description:
*   Changes player skin and appropriate arms on the fly without editing any configuration files.
*
* Version 1.2.4
* Changelog & more info at http://goo.gl/4nKhJ
*
* RIP Root
*/
#pragma semicolon 1

// ====[ INCLUDES ]==========================================================================
#include <sdktools>
#include <cstrike>
#include <autoexecconfig>
#undef REQUIRE_PLUGIN
#tryinclude <updater>


#pragma newdecls required

// ====[ CONSTANTS ]=========================================================================
#define PLUGIN_NAME     "CS:GO Skins Chooser"
#define PLUGIN_VERSION  "1.2.4"
// #define UPDATE_URL      "https://raw.github.com/zadroot/CSGO_SkinsChooser/master/updater.txt"
#define UPDATE_URL      "https://raw.githubusercontent.com/Nobody-x/CSGO_SkinsChooser/master/updater.txt"
#define MAX_SKINS_COUNT 72
#define RANDOM_SKIN     -1

// ====[ VARIABLES ]=========================================================================
ConVar sc_enable     = null;
ConVar sc_random     = null;
ConVar sc_changetype = null;
ConVar sc_admflag    = null;
Menu t_skins_menu  = null;
Menu ct_skins_menu = null;
char TerrorSkin[MAX_SKINS_COUNT][PLATFORM_MAX_PATH];
char TerrorArms[MAX_SKINS_COUNT][PLATFORM_MAX_PATH];
char CTerrorSkin[MAX_SKINS_COUNT][PLATFORM_MAX_PATH];
char CTerrorArms[MAX_SKINS_COUNT][PLATFORM_MAX_PATH];
int TSkins_Count, CTSkins_Count, Selected[MAXPLAYERS + 1] = {RANDOM_SKIN, ...};

// ====[ PLUGIN ]============================================================================
public Plugin myinfo =
{
	name        = PLUGIN_NAME,
	author      = "Root",
	description = "Simply stock skin chooser for CS:GO",
	version     = PLUGIN_VERSION,
	url         = "forums.alliedmods.net/showthread.php?p=1889086"
}


/* OnPluginStart()
 *
 * When the plugin starts up.
 * ------------------------------------------------------------------------------------------ */
public void OnPluginStart()
{
	AutoExecConfig_SetFile("plugin.csgo_skins");
	// Create console variables
	CreateConVar("sm_csgo_skins_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);
	sc_enable     = AutoExecConfig_CreateConVar("sm_csgo_skins_enable",  "1", "Whether or not enable CS:GO Skins Chooser plugin",                                   0, true, 0.0, true, 1.0);
	sc_random     = AutoExecConfig_CreateConVar("sm_csgo_skins_random",  "1", "Whether or not randomly change models for all players on every respawn\n2 = Once",   0, true, 0.0, true, 2.0);
	sc_changetype = AutoExecConfig_CreateConVar("sm_csgo_skins_change",  "0", "Determines when change selected player skin:\n0 = On next respawn\n1 = Immediately", 0, true, 0.0, true, 1.0);
	sc_admflag    = AutoExecConfig_CreateConVar("sm_csgo_skins_admflag", "",  "If flag is specified (a-z), only admins with that flag will able to use skins menu", 0);

	// Create/register client commands to setup player skins
	RegConsoleCmd("sm_skin",  Command_SkinsMenu);
	RegConsoleCmd("sm_skins", Command_SkinsMenu);
	RegConsoleCmd("sm_model", Command_SkinsMenu);

	// Hook skins-related player events
	HookEvent("player_spawn",      OnPlayerEvents, EventHookMode_Post);
	HookEvent("player_disconnect", OnPlayerEvents, EventHookMode_Post);

	// Create and exec plugin's configuration file
	AutoExecConfig_ExecuteFile();

#if defined _updater_included
	if (LibraryExists("updater"))
	{
		// Adds plugin to the updater
		Updater_AddPlugin(UPDATE_URL);
	}
#endif
}

/* OnMapStart()
 *
 * When the map starts.
 * ------------------------------------------------------------------------------------------ */
public void OnMapStart()
{
	// Declare string to load skin's config from sourcemod/configs folder
	char file[PLATFORM_MAX_PATH], curmap[PLATFORM_MAX_PATH];
	GetCurrentMap(curmap, sizeof(curmap));

	// Does current map string contains a "workshop" prefix at a start?
	if (strncmp(curmap, "workshop", 8) == 0)
	{
		// If yes - skip the first 19 characters to avoid comparing the "workshop/12345678" prefix
		BuildPath(Path_SM, file, sizeof(file), "configs/skins/%s.cfg", curmap[19]);
	}
	else /* That's not a workshop map */
	{
		// Let's check that custom skin configuration file is exists for current map
		BuildPath(Path_SM, file, sizeof(file), "configs/skins/%s.cfg", curmap);
	}

	// Unfortunately config for current map is not exists
	if (!FileExists(file))
	{
		// Then use default one
		BuildPath(Path_SM, file, sizeof(file), "configs/skins/any.cfg");

		// Disable plugin if no generic config is avaliable
		if (!FileExists(file))
		{
			SetFailState("Fatal error: Unable to open generic configuration file \"%s\"!", file);
		}
	}

	// Refresh menus and config
	PrepareMenus();
	PrepareConfig(file);
}

#if defined _updater_included
/* OnLibraryAdded()
 *
 * Called after a library is added that the current plugin references.
 * ------------------------------------------------------------------------------------------ */
public void OnLibraryAdded(const char[] name)
{
	// Updater
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}
#endif

/* OnPlayerEvents()
 *
 * Called when player spawns or disconnects from a server.
 * ------------------------------------------------------------------------------------------ */
public void OnPlayerEvents(Event event, const char[] name, bool dontBroadcast)
{
	// Does plugin is enabled?
	if (!sc_enable.BoolValue)
		return;

	// Get real player index from event key
	int client = GetClientOfUserId(event.GetInt("userid"));
	int random = sc_random.IntValue;

	// player_spawn event was fired
	if (name[7] == 's')
	{
		// Make sure player is valid and not controlling a bot
		if (IsValidClient(client) && (random || !GetEntProp(client, Prop_Send, "m_bIsControllingBot")))
		{
			int team  = GetClientTeam(client);
			int model = Selected[client];

			// Get same random number for using same arms and skin
			int trandom  = GetRandomInt(0, TSkins_Count  - 1);
			int ctrandom = GetRandomInt(0, CTSkins_Count - 1);

			// Change player skin to random only once
			if (random == 2 && model == RANDOM_SKIN)
			{
				// And assign random model
				Selected[client] = (team == CS_TEAM_T ? trandom : ctrandom);
			}

			// Set skin depends on client's team
			switch (team)
			{
				case CS_TEAM_T: // Terrorists
				{
					// If random model should be accepted, get random skin of all avalible skins
					if (random == 1 && model == RANDOM_SKIN)
					{
						SetEntityModel(client, TerrorSkin[trandom]);

						// Same random int
						SetEntPropString(client, Prop_Send, "m_szArmsModel", TerrorArms[trandom]);
					}
					else if (RANDOM_SKIN < model < TSkins_Count)
					{
						SetEntityModel(client, TerrorSkin[model]);
						SetEntPropString(client, Prop_Send, "m_szArmsModel", TerrorArms[model]);
					}
				}
				case CS_TEAM_CT: // Counter-Terrorists
				{
					// Also make sure that player havent chosen any skin yet
					if (random == 1 && model == RANDOM_SKIN)
					{
						SetEntityModel(client, CTerrorSkin[ctrandom]);
						SetEntPropString(client, Prop_Send, "m_szArmsModel", CTerrorArms[ctrandom]);
					}

					// Model index must be valid (more than map default and less than max)
					else if (RANDOM_SKIN < model < CTSkins_Count)
					{
						// And set the model
						SetEntityModel(client, CTerrorSkin[model]);
						SetEntPropString(client, Prop_Send, "m_szArmsModel", CTerrorArms[model]);
					}
				}
			}
		}
	}
	else Selected[client] = RANDOM_SKIN; // Reset skin on player_disconnect

}

/* Command_SkinsMenu()
 *
 * Shows skin's menu to a player.
 * ------------------------------------------------------------------------------------------ */
public Action Command_SkinsMenu(int client, int args)
{
	if (sc_enable.BoolValue)
	{
		// Once again make sure that client is valid
		if (IsValidClient(client) && (IsPlayerAlive(client) || !sc_changetype.BoolValue))
		{
			// Get flag name from convar string and get client's access
			char sAdmflag[AdminFlags_TOTAL];
			sc_admflag.GetString(sAdmflag, sizeof(sAdmflag));

			// Converts a string of flag characters to a bit string
			int iAdmFlag = ReadFlagString(sAdmflag);

			// Check if player is having any access (including skins overrides)
			if (iAdmFlag == 0
			||  iAdmFlag != 0 && CheckCommandAccess(client, "csgo_skins_override", iAdmFlag, true))
			{
				// Show individual skin menu depends on client's team
				switch (GetClientTeam(client))
				{
					case CS_TEAM_T:  if (t_skins_menu  != null) t_skins_menu.Display(client, MENU_TIME_FOREVER);
					case CS_TEAM_CT: if (ct_skins_menu != null) ct_skins_menu.Display(client, MENU_TIME_FOREVER);
				}
			}
		}
	}

	// That thing fixing 'unknown command' in client console on command call
	return Plugin_Handled;
}

/* MenuHandler_ChooseSkin()
 *
 * Menu to set player's skin.
 * ------------------------------------------------------------------------------------------ */
public int MenuHandler_ChooseSkin(Menu menu, MenuAction action, int client, int param)
{
	// Called when player pressed something in a menu
	if (action == MenuAction_Select)
	{
		// Don't use any other value than 10, otherwise you may crash clients and a server
		char skin_id[10];
		GetMenuItem(menu, param, skin_id, sizeof(skin_id));

		// Make sure we havent selected random skin
		if (!StrEqual(skin_id, "Random"))
		{
			// Get skin number
			int skin = StringToInt(skin_id, sizeof(skin_id));

			// Correct. So lets save the selected skin
			Selected[client] = skin;

			// Set player model and arms immediately
			if (sc_changetype.BoolValue)
			{
				// Depends on client team obviously
				switch (GetClientTeam(client))
				{
					case CS_TEAM_T:
					{
						SetEntityModel(client, TerrorSkin[skin]);
						SetEntPropString(client, Prop_Send, "m_szArmsModel", TerrorArms[skin]);
					}
					case CS_TEAM_CT:
					{
						SetEntityModel(client, CTerrorSkin[skin]);
						SetEntPropString(client, Prop_Send, "m_szArmsModel", CTerrorArms[skin]);
					}
				}
			}
		}
		else Selected[client] = RANDOM_SKIN;
	}
}

/* PrepareConfig()
 *
 * Adds skins to a menu, makes limits for allowed skins
 * ------------------------------------------------------------------------------------------ */
void PrepareConfig(const char[] file)
{
	// Creates a new KeyValues structure to setup player skins
	KeyValues kv = new KeyValues("Skins");

	// Convert given file to a KeyValues tree
	kv.ImportFromFile(file);

	// Get 'Terrorists' section
	if (kv.JumpToKey("Terrorists"))
	{
		char section[MAX_SKINS_COUNT], skin[MAX_SKINS_COUNT], arms[MAX_SKINS_COUNT], skin_id[3];

		// Sets the current position in the KeyValues tree to the first sub key
		if (!kv.GotoFirstSubKey())
			SetFailState("Fatal error: Can't go to the first sub-key");

		do
		{
			// Get current section name
			kv.GetSectionName(section, sizeof(section));

			// Also make sure we've got 'skin' and 'arms' sections
			if (kv.GetString("skin", skin, sizeof(skin))
			&&  kv.GetString("arms", arms, sizeof(arms)))
			{
				// Copy the full path of skin from config and save it
				strcopy(TerrorSkin[TSkins_Count], sizeof(TerrorSkin[]), skin);
				strcopy(TerrorArms[TSkins_Count], sizeof(TerrorArms[]), arms);

				Format(skin_id, sizeof(skin_id), "%d", TSkins_Count++);

				t_skins_menu.AddItem(skin_id, section);

				// Precache every model (before mapchange) to prevent client crashes
				PrecacheModel(skin, true);
				PrecacheModel(arms, true);
			}
			else LogError("Player model or arms for \"%s\" is incorrect!", section);
		}

		// Because we need to process all keys
		while (kv.GotoNextKey());
	}
	else SetFailState("Fatal error: Missing \"Terrorists\" section!");

	// Get back to the top
	kv.Rewind();

	// Check CT config right now
	if (kv.JumpToKey("Counter-Terrorists"))
	{
		char section[MAX_SKINS_COUNT], skin[MAX_SKINS_COUNT], arms[MAX_SKINS_COUNT], skin_id[3];

		if (!kv.GotoFirstSubKey())
			SetFailState("Fatal error: Can't go to the first sub-key");

		// Lets begin
		do
		{
			kv.GetSectionName(section, sizeof(section));

			if (kv.GetString("skin", skin, sizeof(skin))
			&&  kv.GetString("arms", arms, sizeof(arms)))
			{
				strcopy(CTerrorSkin[CTSkins_Count], sizeof(CTerrorSkin[]), skin);
				strcopy(CTerrorArms[CTSkins_Count], sizeof(CTerrorArms[]), arms);

				// Calculate number of avalible CT skins
				Format(skin_id, sizeof(skin_id), "%d", CTSkins_Count++);

				// Add every section as a menu item
				ct_skins_menu.AddItem(skin_id, section);

				PrecacheModel(skin, true);

				// Precache arms too. Those will not crash client, but arms will not be shown at all
				PrecacheModel(arms, true);
			}

			// Something is wrong
			else LogError("Player model or arms for \"%s\" is incorrect!", section);
		}
		while (kv.GotoNextKey());
	}
	else SetFailState("Fatal error: Missing \"Counter-Terrorists\" section!");

	kv.Rewind();

	// Local handles must be freed
	delete kv;
}

/* PrepareMenus()
 *
 * Create menus if config is valid.
 * ------------------------------------------------------------------------------------------ */
void PrepareMenus()
{
	// Firstly zero out amount of avalible skins
	TSkins_Count = CTSkins_Count = 0;

	// Then safely close menu handles
	if (t_skins_menu != null)
	{
		delete t_skins_menu;
		t_skins_menu = null;
	}
	if (ct_skins_menu != null)
	{
		delete ct_skins_menu;
		ct_skins_menu = null;
	}

	// Create specified menus depends on client teams
	t_skins_menu  = new Menu(MenuHandler_ChooseSkin, MenuAction_Select);
	ct_skins_menu = new Menu(MenuHandler_ChooseSkin, MenuAction_Select);

	// And dont forget to set the menu's titles
	t_skins_menu.SetTitle( "Choose your Terrorist skin:");
	ct_skins_menu.SetTitle("Choose your Counter-Terrorist skin:");

	if (sc_random.BoolValue)
	{
		t_skins_menu.AddItem( "Random", "Random");
		ct_skins_menu.AddItem("Random", "Random");
	}
}

/* IsValidClient()
 *
 * Checks if a client is valid.
 * ------------------------------------------------------------------------------------------ */
bool IsValidClient(int client)
{
	return (1 <= client <= MaxClients && IsClientInGame(client));
}