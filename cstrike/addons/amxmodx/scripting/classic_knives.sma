/*
*
*	Classic Knives by RedSMURF
*	
*
*	Description:
*		Classic Knives for general purposes.
*
*	Cvars:
*		None
*	
*	Commands:
*       ck_reload                                           "Reloads the configuration file."
*       say /knife                                          "Opens the classic knives menu."
*       say_team /knife                                     "Opens the classic knives menu."
* 
*
*	Changelog:
*       v1.0: Initial release.
*       v2.1: Added bhop style.
*       v2.2: Optimized code.
*
*/
#include <amxmodx> 
#include <amxmisc>
#include <fakemeta>
#include <fun>
#include <engine>
#include <hamsandwich>
#include <nvault>
#include <smurfchat>

#define isPlayer(%1)                (1 <= %1 <= 32)
#define OFFSET_CAN_LONGJUMP         356
#define PLAYER_JUMP                 6

new const PLUGIN_VERSION[]          = "2.2"
new const Float:DELAY_ON_CONNECT    = 1.0
new const ERROR_FILE[]              = "ClassicKnives_ERRORS.log"

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#if !defined MAX_VALUE_LENGTH
    #define MAX_VALUE_LENGTH 32
#endif

#if !defined MAX_IP_LENGTH
    #define MAX_IP_LENGTH 32
#endif

#if !defined MAX_AUTHID_LENGTH
    #define MAX_AUTHID_LENGTH 64
#endif

#if !defined MAX_RESOURCE_PATH_LENGTH
    #define MAX_RESOURCE_PATH_LENGTH 64
#endif

#if !defined MAX_FILE_CELL_SIZE
    #define MAX_FILE_CELL_SIZE 192
#endif

#if !defined MAX_PLATFORM_PATH_LENGTH
    #define MAX_PLATFORM_PATH_LENGTH 256
#endif

enum
{
    SECTION_NONE,
    SECTION_MAIN_SETTINGS
}

enum
{
    KNIFE_DEFAULT,
    KNIFE_MACHETE,
    KNIFE_BAK,
    KNIFE_BUTCHER,
    KNIFE_POCKET
}

enum
{
    FLAG_ENABLED,
    FLAG_ALL,
    FLAG_ANY,
    FLAG_DISABLED
}

enum
{
    STYLE_NORMAL,
    STYLE_LIMITED_SPEED,
    STYLE_UNLIMITED_SPEED
}

enum _:SETTINGS 
{
    DEFAULT_VIEW_MODEL[ MAX_RESOURCE_PATH_LENGTH ],
    DEFAULT_PLAYER_MODEL[ MAX_RESOURCE_PATH_LENGTH ],
    MACHETE_VIEW_MODEL[ MAX_RESOURCE_PATH_LENGTH ],
    MACHETE_PLAYER_MODEL[ MAX_RESOURCE_PATH_LENGTH ],
    BAK_VIEW_MODEL[ MAX_RESOURCE_PATH_LENGTH ],
    BAK_PLAYER_MODEL[ MAX_RESOURCE_PATH_LENGTH ],
    BUTCHER_VIEW_MODEL[ MAX_RESOURCE_PATH_LENGTH ],
    BUTCHER_PLAYER_MODEL[ MAX_RESOURCE_PATH_LENGTH ],
    POCKET_VIEW_MODEL[ MAX_RESOURCE_PATH_LENGTH ],
    POCKET_PLAYER_MODEL[ MAX_RESOURCE_PATH_LENGTH ],
    Float:DEFAULT_SPEED,
    Float:HIGH_SPEED_LEVEL_A,
    Float:HIGH_SPEED_LEVEL_B,
    Float:HIGH_SPEED_LEVEL_C,
    Float:LOW_SPEED_LEVEL_A,
    Float:LOW_SPEED_LEVEL_B,
    Float:LOW_SPEED_LEVEL_C,
    Float:DEFAULT_GRAVITY,
    Float:HIGH_GRAVITY_LEVEL_A,
    Float:HIGH_GRAVITY_LEVEL_B,
    Float:HIGH_GRAVITY_LEVEL_C,
    Float:LOW_GRAVITY_LEVEL_A,
    Float:LOW_GRAVITY_LEVEL_B,
    Float:LOW_GRAVITY_LEVEL_C,
    Float:HIGH_DAMAGE_LEVEL_A,
    Float:HIGH_DAMAGE_LEVEL_B,
    Float:HIGH_DAMAGE_LEVEL_C,
    Float:LOW_DAMAGE_LEVEL_A,
    Float:LOW_DAMAGE_LEVEL_B,
    Float:LOW_DAMAGE_LEVEL_C,
    KNIFE_INFO,
    KNIFE_INFO_FLAGS,
    bool:KNIFE_AUTO_SWITCH,
    bool:KNIFE_VAULT_SET,
    bool:KNIFE_VAULT_SAVE,
    BHOP_INFO,
    BHOP_INFO_FLAGS,
    bool:BHOP_KNIFE_ONLY,
    BHOP_STYLE,
    Float:BHOP_MAXSPEED_FACTOR,
    Float:BHOP_SLOWDOWN_FACTOR,
}

enum _:PLAYER_DATA
{
    PDATA_NAME[ MAX_VALUE_LENGTH ],
    PDATA_AUTHID[ MAX_AUTHID_LENGTH ],
    PDATA_ADMIN_FLAGS,
    PDATA_KNIFE,
    PDATA_WEAPON,
    bool:PDATA_BHOP,
    bool:PDATA_KNIFE_INFO
}

new g_eSettings[ SETTINGS ],
    g_ePlayerData[ MAX_PLAYERS + 1 ][ PLAYER_DATA ],
    g_szFileName[ MAX_RESOURCE_PATH_LENGTH ],
    g_bFileWasRead = false,
    g_iVault,
    g_iItemHandler,
    g_pGravity

public plugin_init()
{
    register_plugin( "Classic Knives", PLUGIN_VERSION, "RedSMURF" )
    register_dictionary( "ClassicKnives.txt" )

    register_cvar( "classic_knives", PLUGIN_VERSION, FCVAR_SERVER | FCVAR_SPONLY )

    RegisterHam( Ham_TakeDamage, "player", "fwdTakeDamage" )
    RegisterHam( Ham_Player_Jump, "player", "fwdPlayerJump" )
    register_event( "CurWeapon", "Event_CurWeapon", "be", "1=1" )

    register_clcmd( "say /knife", "showMenu" )
    register_clcmd( "say_team /knife", "showMenu" )
    register_concmd( "ck_reload", "cmdReload", ADMIN_RCON, "-- Reloads the configuration file" )

    g_iVault = nvault_open( "ClassicKnives" )
    g_iItemHandler = menu_makecallback( "ItemHandler" )
    g_pGravity = get_cvar_pointer( "sv_gravity" )
}

public plugin_end()
{
    nvault_close( g_iVault )
}

public plugin_precache() 
{
    get_configsdir( g_szFileName, charsmax( g_szFileName ) )
    add( g_szFileName, charsmax( g_szFileName ), "/ClassicKnives.ini" )

    ReadFile()
} 

public cmdReload( id, iLevel, iCmd )
{
   if ( !cmd_access( id, iLevel, iCmd, 1 ) )
        return PLUGIN_HANDLED

   ReadFile()
   console_print( id, "The configuration file has been reloaded successfully." )

   return PLUGIN_HANDLED
}

ReadFile()
{
    if ( g_bFileWasRead )
    {
        new iPlayers[ 32 ], iNum, i
        get_players( iPlayers, iNum, SC_FILTERING_FLAGS )

        for ( i = 0; i < iNum; i ++ )
            UpdateData( iPlayers[ i ] )
    }

    new iFileHandler = fopen( g_szFileName, "rt" )

    if ( !iFileHandler )
    {
        set_fail_state( "An error occured during the opening of the configuration file" )
    }

    new szData[ MAX_FILE_CELL_SIZE ], szKey[ 64 ], szValue[ 64 ], iSection = SECTION_NONE, iLine

    while( !feof( iFileHandler ) )
    {
        iLine++
        fgets( iFileHandler, szData, charsmax( szData ) ) 
        trim( szData )
        
        switch( szData[ 0 ] )
        {
            case EOS, '#', ';':
            {
                continue 
            }
            case '[': 
            {
                if ( szData[ strlen( szData ) - 1 ] == ']' )
                {
                    switch( szData[ 1 ] )
                    {
                        case 'M', 'm': iSection = SECTION_MAIN_SETTINGS
                        default: 
                        {
                            LogConfigError( iLine, "Unknown section name: %s", szData )
                            iSection = SECTION_NONE
                        }
                    }
                }
                else 
                {
                    LogConfigError( iLine, "Unclosed section name: %s", szData )
                    iSection = SECTION_NONE
                }
            }
            default: 
            {
                if ( iSection == SECTION_NONE )
                {
                    LogConfigError( iLine, "Data is not in any defined section: %s ", szData )
                }
                else if ( iSection == SECTION_MAIN_SETTINGS )
                {
                    strtok( szData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=' )
                    trim( szKey )
                    trim( szValue )

                    if ( equal( szKey, "DEFAULT_VIEW_MODEL" ) && !g_bFileWasRead )
                    {
                        precache_model( szValue )
                        copy( g_eSettings[ DEFAULT_VIEW_MODEL ], charsmax( g_eSettings[ DEFAULT_VIEW_MODEL ] ), szValue ) 
                    }
                    else if ( equal( szKey, "DEFAULT_PLAYER_MODEL" ) && !g_bFileWasRead )
                    {
                        precache_model( szValue )
                        copy( g_eSettings[ DEFAULT_PLAYER_MODEL ], charsmax( g_eSettings[ DEFAULT_PLAYER_MODEL ] ), szValue ) 
                    }
                    else if ( equal( szKey, "MACHETE_VIEW_MODEL" ) && !g_bFileWasRead )
                    {
                        precache_model( szValue )
                        copy( g_eSettings[ MACHETE_VIEW_MODEL ], charsmax( g_eSettings[ MACHETE_VIEW_MODEL ] ), szValue ) 
                    }
                    else if ( equal( szKey, "MACHETE_PLAYER_MODEL" ) && !g_bFileWasRead )
                    {
                        precache_model( szValue )
                        copy( g_eSettings[ MACHETE_PLAYER_MODEL ], charsmax( g_eSettings[ MACHETE_PLAYER_MODEL ] ), szValue ) 
                    }
                    else if ( equal( szKey, "BAK_VIEW_MODEL" ) && !g_bFileWasRead )
                    {
                        precache_model( szValue )
                        copy( g_eSettings[ BAK_VIEW_MODEL ], charsmax( g_eSettings[ BAK_VIEW_MODEL ] ), szValue ) 
                    }
                    else if ( equal( szKey, "BAK_PLAYER_MODEL" ) && !g_bFileWasRead )
                    {
                        precache_model( szValue )
                        copy( g_eSettings[ BAK_PLAYER_MODEL ], charsmax( g_eSettings[ BAK_PLAYER_MODEL ] ), szValue ) 
                    }
                    else if ( equal( szKey, "BUTCHER_VIEW_MODEL" ) && !g_bFileWasRead )
                    {
                        precache_model( szValue )
                        copy( g_eSettings[ BUTCHER_VIEW_MODEL ], charsmax( g_eSettings[ BUTCHER_VIEW_MODEL ] ), szValue ) 
                    }
                    else if ( equal( szKey, "BUTCHER_PLAYER_MODEL" ) && !g_bFileWasRead )
                    {
                        precache_model( szValue )
                        copy( g_eSettings[ BUTCHER_PLAYER_MODEL ], charsmax( g_eSettings[ BUTCHER_PLAYER_MODEL ] ), szValue ) 
                    }
                    else if ( equal( szKey, "POCKET_VIEW_MODEL" ) && !g_bFileWasRead )
                    {
                        precache_model( szValue )
                        copy( g_eSettings[ POCKET_VIEW_MODEL ], charsmax( g_eSettings[ POCKET_VIEW_MODEL ] ), szValue ) 
                    }
                    else if ( equal( szKey, "POCKET_PLAYER_MODEL" ) && !g_bFileWasRead )
                    {
                        precache_model( szValue )
                        copy( g_eSettings[ POCKET_PLAYER_MODEL ], charsmax( g_eSettings[ POCKET_PLAYER_MODEL ] ), szValue ) 
                    }
                    else if ( equal( szKey, "DEFAULT_SPEED" ) )
                    {
                        g_eSettings[ DEFAULT_SPEED ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "HIGH_SPEED_LEVEL_A" ) )
                    {
                        g_eSettings[ HIGH_SPEED_LEVEL_A ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "HIGH_SPEED_LEVEL_B" ) )
                    {
                        g_eSettings[ HIGH_SPEED_LEVEL_B ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "HIGH_SPEED_LEVEL_C" ) )
                    {
                        g_eSettings[ HIGH_SPEED_LEVEL_C ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "LOW_SPEED_LEVEL_A" ) )
                    {
                        g_eSettings[ LOW_SPEED_LEVEL_A ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "LOW_SPEED_LEVEL_B" ) )
                    {
                        g_eSettings[ LOW_SPEED_LEVEL_B ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "LOW_SPEED_LEVEL_C" ) )
                    {
                        g_eSettings[ LOW_SPEED_LEVEL_C ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "DEFAULT_GRAVITY" ) )
                    {
                        g_eSettings[ DEFAULT_GRAVITY ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "HIGH_GRAVITY_LEVEL_A" ) )
                    {
                        g_eSettings[ HIGH_GRAVITY_LEVEL_A ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "HIGH_GRAVITY_LEVEL_B" ) )
                    {
                        g_eSettings[ HIGH_GRAVITY_LEVEL_B ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "HIGH_GRAVITY_LEVEL_C" ) )
                    {
                        g_eSettings[ HIGH_GRAVITY_LEVEL_C ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "LOW_GRAVITY_LEVEL_A" ) )
                    {
                        g_eSettings[ LOW_GRAVITY_LEVEL_A ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "LOW_GRAVITY_LEVEL_B" ) )
                    {
                        g_eSettings[ LOW_GRAVITY_LEVEL_B ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "LOW_GRAVITY_LEVEL_C" ) )
                    {
                        g_eSettings[ LOW_GRAVITY_LEVEL_C ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "HIGH_DAMAGE_LEVEL_A" ) )
                    {
                        g_eSettings[ HIGH_DAMAGE_LEVEL_A ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "HIGH_DAMAGE_LEVEL_B" ) )
                    {
                        g_eSettings[ HIGH_DAMAGE_LEVEL_B ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "HIGH_DAMAGE_LEVEL_C" ) )
                    {
                        g_eSettings[ HIGH_DAMAGE_LEVEL_C ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "LOW_DAMAGE_LEVEL_A" ) )
                    {
                        g_eSettings[ LOW_DAMAGE_LEVEL_A ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "LOW_DAMAGE_LEVEL_B" ) )
                    {
                        g_eSettings[ LOW_DAMAGE_LEVEL_B ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "LOW_DAMAGE_LEVEL_C" ) )
                    {
                        g_eSettings[ LOW_DAMAGE_LEVEL_C ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "KNIFE_INFO_FLAGS" ) )
                    {
                        g_eSettings[ KNIFE_INFO_FLAGS ] = read_flags( szValue )
                    } 
                    else if ( equal( szKey, "KNIFE_AUTO_SWITCH" ) )
                    {
                        g_eSettings[ KNIFE_AUTO_SWITCH ] = bool:str_to_num( szValue )
                    } 
                    else if ( equal( szKey, "KNIFE_VAULT_SET" ) )
                    {
                        g_eSettings[ KNIFE_VAULT_SET ] = bool:str_to_num( szValue )
                    } 
                    else if ( equal( szKey, "KNIFE_VAULT_SAVE" ) )
                    {
                        g_eSettings[ KNIFE_VAULT_SAVE ] = bool:str_to_num( szValue )
                    } 
                    else if ( equal( szKey, "BHOP_INFO" ) )
                    {
                        g_eSettings[ BHOP_INFO ] = str_to_num( szValue )
                    }
                    else if ( equal( szKey, "BHOP_INFO_FLAGS" ) )
                    {
                        g_eSettings[ BHOP_INFO_FLAGS ] = read_flags( szValue )
                    }
                    else if ( equal( szKey, "BHOP_KNIFE_ONLY" ) )
                    {
                        g_eSettings[ BHOP_KNIFE_ONLY ] = bool:str_to_num( szValue )
                    }
                    else if ( equal( szKey, "BHOP_STYLE" ) )
                    {
                        g_eSettings[ BHOP_STYLE ] = str_to_num( szValue )
                    }
                    else if ( equal( szKey, "BHOP_MAXSPEED_FACTOR" ) )
                    {
                        g_eSettings[ BHOP_MAXSPEED_FACTOR ] = str_to_float( szValue )
                    }
                    else if ( equal( szKey, "BHOP_SLOWDOWN_FACTOR" ) )
                    {
                        g_eSettings[ BHOP_SLOWDOWN_FACTOR ] = str_to_float( szValue )
                    }
                }
            }
        }
    }

    g_bFileWasRead = true
    fclose( iFileHandler )
}

public client_authorized( id )
{
    get_user_name( id, g_ePlayerData[ id ][ PDATA_NAME ], charsmax( g_ePlayerData[][ PDATA_NAME ] ) )
    get_user_authid( id, g_ePlayerData[ id ][ PDATA_AUTHID ], charsmax( g_ePlayerData[][ PDATA_AUTHID ] ) )
    
    if ( g_eSettings[ KNIFE_VAULT_SET ] )
        setData( id )

    set_task( DELAY_ON_CONNECT, "UpdateData", id )
}

public setData( id )
{
    g_ePlayerData[ id ][ PDATA_KNIFE ] = nvault_get( g_iVault, g_ePlayerData[ id ][ PDATA_AUTHID ] )
}

public client_disconnected( id )
{
    if ( g_eSettings[ KNIFE_VAULT_SAVE ] )
        saveData( id )
}

public saveData( id )
{
    new szData[ 4 ]

    formatex( szData, charsmax( szData ), "%d", g_ePlayerData[ id ][ PDATA_KNIFE ] )
    nvault_set( g_iVault, g_ePlayerData[ id ][ PDATA_AUTHID ], szData )
}

public UpdateData( id )
{
    get_user_name( id, g_ePlayerData[ id ][ PDATA_NAME ], charsmax( g_ePlayerData[][ PDATA_NAME ] ) )
    g_ePlayerData[ id ][ PDATA_ADMIN_FLAGS ] = get_user_flags( id )

    switch( g_eSettings[ KNIFE_INFO ] )
    {
        case FLAG_ANY:
        {
            if ( g_eSettings[ KNIFE_INFO_FLAGS ] & g_ePlayerData[ id ][ PDATA_ADMIN_FLAGS ] )
                g_ePlayerData[ id ][ PDATA_KNIFE_INFO ] = true
        }
        case FLAG_ALL:
        {
            if ( g_eSettings[ KNIFE_INFO_FLAGS ] & g_ePlayerData[ id ][ PDATA_ADMIN_FLAGS ] == g_eSettings[ KNIFE_INFO_FLAGS ] )
                g_ePlayerData[ id ][ PDATA_KNIFE_INFO ] = true
        }
        case FLAG_DISABLED: 
        {
            g_ePlayerData[ id ][ PDATA_KNIFE_INFO ] = false
        }
        default: 
        {
            g_ePlayerData[ id ][ PDATA_KNIFE_INFO ] = true
        }
    }

    switch( g_eSettings[ BHOP_INFO ] )
    {
        case FLAG_ANY:
        {
            if ( g_eSettings[ BHOP_INFO_FLAGS ] & g_ePlayerData[ id ][ PDATA_ADMIN_FLAGS ] )
                g_ePlayerData[ id ][ PDATA_BHOP ] = true
        }
        case FLAG_ALL:
        {
            if ( g_eSettings[ BHOP_INFO_FLAGS ] & g_ePlayerData[ id ][ PDATA_ADMIN_FLAGS ] == g_eSettings[ BHOP_INFO_FLAGS ] )
                g_ePlayerData[ id ][ PDATA_BHOP ] = true
        }
        case FLAG_DISABLED: 
        {
            g_ePlayerData[ id ][ PDATA_BHOP ] = false
        }
        default: 
        {
            g_ePlayerData[ id ][ PDATA_BHOP ] = true
        }
    }
}

public showMenu( id )
{
    new szText[ 64 ], iMenu
    formatex( szText, charsmax( szText ), "%L", id, "CK_MENU_TITLE" )

    iMenu = menu_create( szText, "MenuHandler" )

    if ( g_ePlayerData[ id ][ PDATA_KNIFE_INFO ] )
    {
        formatex( szText, charsmax( szText ), "%L \y%L %L", id, "CK_DEFAULT_NAME", id, "CK_DEFAULT_INFO", id, g_ePlayerData[ id ][ PDATA_KNIFE ] == KNIFE_DEFAULT ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, .callback = g_iItemHandler )

        formatex( szText, charsmax( szText ), "%L \y%L %L", id, "CK_MACHETE_NAME", id, "CK_MACHETE_INFO", id, g_ePlayerData[ id ][ PDATA_KNIFE ] == KNIFE_MACHETE ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, .callback = g_iItemHandler )

        formatex( szText, charsmax( szText ), "%L \y%L %L", id, "CK_BAK_NAME", id, "CK_BAK_INFO", id, g_ePlayerData[ id ][ PDATA_KNIFE ] == KNIFE_BAK ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, .callback = g_iItemHandler )

        formatex( szText, charsmax( szText ), "%L \y%L %L", id, "CK_BUTCHER_NAME", id, "CK_BUTCHER_INFO", id, g_ePlayerData[ id ][ PDATA_KNIFE ] == KNIFE_BUTCHER ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, .callback = g_iItemHandler )

        formatex( szText, charsmax( szText ), "%L \y%L %L", id, "CK_POCKET_NAME", id, "CK_POCKET_INFO", id, g_ePlayerData[ id ][ PDATA_KNIFE ] == KNIFE_POCKET ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, .callback = g_iItemHandler )
    }
    else 
    {
        formatex( szText, charsmax( szText ), "%L \y%L", id, "CK_DEFAULT_NAME", id, g_ePlayerData[ id ][ PDATA_KNIFE ] == KNIFE_DEFAULT ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, .callback = g_iItemHandler )

        formatex( szText, charsmax( szText ), "%L \y%L", id, "CK_MACHETE_NAME", id, g_ePlayerData[ id ][ PDATA_KNIFE ] == KNIFE_MACHETE ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, .callback = g_iItemHandler )

        formatex( szText, charsmax( szText ), "%L \y%L", id, "CK_BAK_NAME", id, g_ePlayerData[ id ][ PDATA_KNIFE ] == KNIFE_BAK ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, .callback = g_iItemHandler )

        formatex( szText, charsmax( szText ), "%L \y%L", id, "CK_BUTCHER_NAME", id, g_ePlayerData[ id ][ PDATA_KNIFE ] == KNIFE_BUTCHER ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, .callback = g_iItemHandler )

        formatex( szText, charsmax( szText ), "%L \y%L", id, "CK_POCKET_NAME", id, g_ePlayerData[ id ][ PDATA_KNIFE ] == KNIFE_POCKET ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, .callback = g_iItemHandler )
    }

    menu_setprop( iMenu, MPROP_EXIT, MEXIT_ALL )
    menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" )

    menu_display( id, iMenu )
}

public MenuHandler( id, iMenu, iItem )
{
    if ( iItem == MENU_EXIT ) 
    {
        menu_destroy( iMenu )
        return PLUGIN_HANDLED
    }

    g_ePlayerData[ id ][ PDATA_KNIFE ] = iItem

    if ( g_eSettings[ KNIFE_AUTO_SWITCH ] && g_ePlayerData[ id ][ PDATA_WEAPON ] != CSW_KNIFE )
    {
        engclient_cmd( id, "weapon_knife" )
    }

    Event_CurWeapon( id )
    menu_destroy( iMenu )

    return PLUGIN_HANDLED
}

public ItemHandler( id, iMenu, iItem )
{
    return g_ePlayerData[ id ][ PDATA_KNIFE ] == iItem ? ITEM_DISABLED : ITEM_IGNORE
}

public Event_CurWeapon( id )
{
    if ( !is_user_alive( id ) )
        return PLUGIN_CONTINUE

    g_ePlayerData[ id ][ PDATA_WEAPON ] = get_user_weapon( id )

    static Float:fSpeed, Float:fGravity, iFootSteps
    fSpeed = g_eSettings[ DEFAULT_SPEED ]
    fGravity = g_eSettings[ DEFAULT_GRAVITY ]
    iFootSteps = 0
    
    if ( g_ePlayerData[ id ][ PDATA_WEAPON ] == CSW_KNIFE )
    {
        setModel( id, g_ePlayerData[ id ][ PDATA_KNIFE ]  )

        switch( g_ePlayerData[ id ][ PDATA_KNIFE ]  )
        {
            case KNIFE_MACHETE: 
            {
                fSpeed = g_eSettings[ LOW_SPEED_LEVEL_C ]
            }
            case KNIFE_BAK: 
            {
                iFootSteps = 1
            }
            case KNIFE_BUTCHER: 
            {
                fGravity = g_eSettings[ LOW_GRAVITY_LEVEL_C ]
            }
            case KNIFE_POCKET: 
            {
                fSpeed = g_eSettings[ HIGH_SPEED_LEVEL_C ]
            }
        }
    }

    set_pev( id, pev_maxspeed, fSpeed )
    set_pev( id, pev_gravity, fGravity )
    set_user_footsteps( id, iFootSteps )

    return PLUGIN_CONTINUE
}

public setModel( id, iKnife )
{
    if ( !is_user_alive( id ) )
        return PLUGIN_HANDLED

    switch( iKnife )
    {
        case KNIFE_DEFAULT: 
        {
            set_pev( id, pev_viewmodel2, g_eSettings[ DEFAULT_VIEW_MODEL ] )
            set_pev( id, pev_weaponmodel2, g_eSettings[ DEFAULT_PLAYER_MODEL ] )
        }
        case KNIFE_MACHETE: 
        {
            set_pev( id, pev_viewmodel2, g_eSettings[ MACHETE_VIEW_MODEL ] )
            set_pev( id, pev_weaponmodel2, g_eSettings[ MACHETE_PLAYER_MODEL ] )
        }
        case KNIFE_BAK: 
        {
            set_pev( id, pev_viewmodel2, g_eSettings[ BAK_VIEW_MODEL ] )
            set_pev( id, pev_weaponmodel2, g_eSettings[ BAK_PLAYER_MODEL ] )
        }
        case KNIFE_BUTCHER: 
        {
            set_pev( id, pev_viewmodel2, g_eSettings[ BUTCHER_VIEW_MODEL ] )
            set_pev( id, pev_weaponmodel2, g_eSettings[ BUTCHER_PLAYER_MODEL ] )
        }
        case KNIFE_POCKET: 
        {
            set_pev( id, pev_viewmodel2, g_eSettings[ POCKET_VIEW_MODEL ] )
            set_pev( id, pev_weaponmodel2, g_eSettings[ POCKET_PLAYER_MODEL ] )
        }
    }

    return PLUGIN_HANDLED
}

public fwdPlayerJump( id )
{
    if ( !is_user_alive( id )
    || !g_ePlayerData[ id ][ PDATA_BHOP ]
    || !( pev( id, pev_flags ) & FL_ONGROUND )
    || pev( id, pev_waterlevel ) >= 2 )
        return HAM_IGNORED

    if ( g_eSettings[ BHOP_STYLE ] == STYLE_NORMAL )
    {
        set_pev( id, pev_oldbuttons, pev( id, pev_oldbuttons ) & ~IN_JUMP )
        set_pev( id, pev_gaitsequence, PLAYER_JUMP )
        set_pev( id, pev_frame, 0.0 )

        return HAM_IGNORED
    }

    set_pev( id, pev_oldbuttons, pev( id, pev_oldbuttons ) | IN_JUMP )

    static Float:fVelocity[ 3 ], Float:fGravity,
    Float:fFrameTime, Float:fForward[ 3 ], iLongJump = 0 
    pev( id, pev_velocity, fVelocity )
    pev( id, pev_gravity, fGravity )
    global_get( glb_v_forward, fForward )
    global_get( glb_frametime, fFrameTime )
    
    if ( g_eSettings[ BHOP_STYLE ] == STYLE_LIMITED_SPEED )
    {
        static Float:fMaxSpeed, Float:fSpeed, Float:fFraction

        pev( id, pev_maxspeed, fMaxSpeed )
        fMaxSpeed *= g_eSettings[ BHOP_MAXSPEED_FACTOR ]
        fSpeed = floatsqroot( fVelocity[ 0 ] * fVelocity[ 0 ] + fVelocity[ 1 ] * fVelocity[ 1 ] + fVelocity[ 2 ] * fVelocity[ 2 ] )

        if ( fSpeed > fMaxSpeed )
        {
            fFraction = fMaxSpeed / fSpeed * g_eSettings[ BHOP_SLOWDOWN_FACTOR ]

            fVelocity[ 0 ] *= fFraction
            fVelocity[ 1 ] *= fFraction
            fVelocity[ 2 ] *= fFraction
        }
    }

    if ( pev( id, pev_button ) & IN_DUCK
    &&  get_pdata_int( id, OFFSET_CAN_LONGJUMP ) )
    {
        new Float:fPunchAngle[ 3 ]
        pev( id, pev_punchangle, fPunchAngle )

        fPunchAngle[ 0 ] = -5.0 

        fVelocity[ 0 ] = fForward[ 0 ] * 560.0
        fVelocity[ 1 ] = fForward[ 1 ] * 560.0
        fVelocity[ 2 ] = 299.33259094191531084669989858532
        iLongJump = 1
    }
    else
    {
        fVelocity[ 2 ] = 268.32815729997476356910084024775
    }

    fVelocity[ 2 ] -= fGravity * 0.5 * fFrameTime * get_pcvar_num( g_pGravity )

    set_pev( id, pev_velocity, fVelocity )
    set_pev( id, pev_gaitsequence, PLAYER_JUMP + iLongJump )
    set_pev( id, pev_frame, 0.0 )

    return HAM_IGNORED
}

public fwdTakeDamage( iVictim, iInflictor, iAttacker, Float:fDamage, iDamageBits )
{
    if ( !isPlayer( iAttacker ) || g_ePlayerData[ iAttacker ][ PDATA_WEAPON ] != CSW_KNIFE || g_ePlayerData[ iAttacker ][ PDATA_KNIFE ] != KNIFE_MACHETE )
        return HAM_IGNORED

    fDamage *= g_eSettings[ HIGH_DAMAGE_LEVEL_B ]
    SetHamParamFloat( 4, fDamage )

    return HAM_HANDLED
}

stock LogConfigError( const iLine, const szText[], any:... )
{
    static szError[ MAX_PLATFORM_PATH_LENGTH ]
    vformat( szError, charsmax( szError ), szText, 3 )

    log_to_file( ERROR_FILE, "^nLine %d: %s^n", iLine, szError )
} 
