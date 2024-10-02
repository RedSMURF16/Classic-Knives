#include <amxmodx> 
#include <amxmisc>
#include <fakemeta>
#include <fun>
#include <engine>
#include <hamsandwich>
#include <nvault>

new const PLUGIN_VERSION[] = "2.1"
new const ERROR_FILE[] = "knifemenu_errors.log"

#if !defined MAX_PLAYERS   
    const MAX_PLAYERS = 32
#endif 

#if !defined MAX_VALUE_LENGTH   
    const MAX_VALUE_LENGTH = 32
#endif 

#if !defined MAX_PLACEHOLDER_LENGTH
    const MAX_PLACEHOLDER_LENGTH = 64
#endif

#if !defined MAX_RESOURCE_PATH_LENGTH
    const MAX_RESOURCE_PATH_LENGTH = 64
#endif

#if !defined MAX_FILE_CELL_SIZE
    const MAX_FILE_CELL_SIZE = 192
#endif

#if !defined PLATFORM_MAX_PATH_LENGTH
    const MAX_PLATFORM_PATH_LENGTH = 256
#endif

enum
{
    SECTION_NONE,
    SECTION_KNIFE_SETTINGS
}

enum
{
    BHOP_INFO_ALL,
    BHOP_INFO_FLAG_ANY,
    BHOP_INFO_FLAG_ALL,
    BHOP_INFO_DISABLED
}

enum
{
    KNIFE_INFO_ALL,
    KNIFE_INFO_FLAG_ANY,
    KNIFE_INFO_FLAG_ALL,
    KNIFE_INFO_DISABLED
}

enum
{
    KNIFE_DEFAULT,
    KNIFE_MACHETE,
    KNIFE_BAK,
    KNIFE_BUTCHER,
    KNIFE_POCKET
}

enum _:KnifeSettings 
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
    BHOP_INFO,
    BHOP_INFO_FLAG[ MAX_VALUE_LENGTH ],
    BHOP_INFO_FLAG_BIT,
    Float:BHOP_BURST,
    KNIFE_INFO,
    KNIFE_INFO_FLAG[ MAX_VALUE_LENGTH ],
    KNIFE_INFO_FLAG_BIT
}

new g_iKnifeModel[ MAX_PLAYERS + 1 ],
    g_eSettings[ KnifeSettings ],
    Array:g_aFileContents,
    Trie:g_tSettings,
    g_iFileContents,
    g_szFileName[ MAX_RESOURCE_PATH_LENGTH ],
    g_bFileWasRead = false,
    g_iKnifeMenuVault

public plugin_init()
{
    register_plugin( "Classic Knives", PLUGIN_VERSION, "RedSMURF" )
    register_dictionary( "ClassicKnives.txt" )

    RegisterHam( Ham_TakeDamage, "player", "HamTakeDamage", 0 )
    register_event( "CurWeapon", "EventCurWeapon", "be", "1=1" ) // Weapon must be active

    g_iKnifeMenuVault = nvault_open( "Classic Knives" )

    register_clcmd( "say /knife", "MenuDisplay" )
    register_clcmd( "say_team /knife", "MenuDisplay" )
    register_concmd( "ck_reload", "CmdReload", ADMIN_RCON, "-- reload the configuration file" )
}

public CmdReload( id, iLevel, iCmd )
{
   if ( !cmd_access( id, iLevel, iCmd, 1 ) )
   {
        return PLUGIN_HANDLED
   } 

   ReadFile()
   console_print( id, "The configuration file has been reloaded succesfully." )

   return PLUGIN_HANDLED
}

public plugin_end()
{
    ArrayDestroy( g_aFileContents )
    TrieDestroy( g_tSettings )
    nvault_close( g_iKnifeMenuVault )
}

public plugin_precache() 
{ 
    g_aFileContents = ArrayCreate( MAX_FILE_CELL_SIZE )
    g_tSettings = TrieCreate()
    g_iFileContents = -1

    get_configsdir( g_szFileName, charsmax( g_szFileName ) )
    add( g_szFileName, charsmax( g_szFileName ), "/ClassicKnives.ini" )

    ReadFile()
} 

ReadFile()
{
    if ( g_bFileWasRead )
    {
        ArrayClear( g_aFileContents )
        TrieClear( g_tSettings )
        g_iFileContents = -1
    }

    new iFileHandler = fopen( g_szFileName, "rt" )

    if ( !iFileHandler )
    {
        set_fail_state( "An error occured during the opening of the configuration file" )
    }

    if ( iFileHandler )
    {
        new szData[ MAX_FILE_CELL_SIZE ], szKey[ 64 ], szValue[ 64 ], iSection = SECTION_NONE, iLine, iSize

        while( !feof( iFileHandler ) )
        {
            iLine++
            fgets( iFileHandler, szData, charsmax( szData ) ) 
            trim( szData )

            g_iFileContents++
            ArrayPushArray( g_aFileContents, szData )

            switch( szData[ 0 ] )
            {
                case EOS, '#', ';' : 
                {
                    continue 
                }
                case '[' : 
                {
                    iSize = strlen( szData )

                    if ( szData[ iSize - 1 ] == ']' )
                    {
                        switch( szData[ 1 ] )
                        {
                            case 'K', 'k' : 
                            {
                                iSection = SECTION_KNIFE_SETTINGS
                            }
                            default : 
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
                default : 
                {
                    if ( iSection == SECTION_NONE )
                    {
                        LogConfigError( iLine, "Data is not in any defined section: %s ", szData )
                    }
                    else if ( iSection == SECTION_KNIFE_SETTINGS )
                    {
                        strtok( szData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=' )
                        trim( szKey )
                        trim( szValue )

                        TrieSetString( g_tSettings, szKey, szValue )

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
                        else if ( equal( szKey, "BHOP_INFO" ) )
                        {
                            g_eSettings[ BHOP_INFO ] = str_to_num( szValue )
                        }
                        else if ( equal( szKey, "BHOP_INFO_FLAG" ) )
                        {
                            copy( g_eSettings[ BHOP_INFO_FLAG ], charsmax( g_eSettings[ BHOP_INFO_FLAG ] ), szValue )
                            g_eSettings[ BHOP_INFO_FLAG_BIT ] = read_flags( g_eSettings[ BHOP_INFO_FLAG ] )
                        }
                        else if ( equal( szKey, "BHOP_BURST" ) )
                        {
                            g_eSettings[ BHOP_BURST ] = str_to_float( szValue )
                        }
                        else if ( equal( szKey, "KNIFE_INFO" ) )
                        {
                            g_eSettings[ KNIFE_INFO ] = str_to_num( szValue )
                        }
                        else if ( equal( szKey, "KNIFE_INFO_FLAG" ) )
                        {
                            copy( g_eSettings[ KNIFE_INFO_FLAG ], charsmax( g_eSettings[ KNIFE_INFO_FLAG ] ), szValue )
                            g_eSettings[ KNIFE_INFO_FLAG_BIT ] = read_flags( g_eSettings[ KNIFE_INFO_FLAG ] )
                        } 
                    }
                }
            }
        }

        fclose( iFileHandler )
        g_bFileWasRead = true
    }
}

public client_putinserver( id )
{
    new szAuth[ 32 ], szKey[ 32 ], szValue
    get_user_authid( id, szAuth, charsmax( szAuth ) )

    formatex( szKey, charsmax( szKey ), "CK_%s", szAuth )
    szValue = nvault_get( g_iKnifeMenuVault, szKey )

    g_iKnifeModel[ id ] = szValue
}

public saveData( id )
{
    new szAuth[ 32 ], szKey[ 32 ], szValue[ 16 ]
    get_user_authid( id, szAuth, charsmax( szAuth ) )

    formatex( szKey, charsmax( szKey ), "CK_%s", szAuth )
    num_to_str( g_iKnifeModel[ id ], szValue, charsmax( szValue ) )
    nvault_set( g_iKnifeMenuVault, szKey, szValue )
}

public MenuDisplay( id )
{
    new szText[ 64 ], iFlags, bKnifeInfo = false
    formatex( szText, charsmax( szText ), "%L", id, "CK_MENU_TITLE" )
    iFlags = pev( id, pev_flags )

    new iMenu = menu_create( szText, "MenuHandler" )
    new iItem = menu_makecallback( "ItemHandler" )

    switch( g_eSettings[ KNIFE_INFO ] )
    {
        case BHOP_INFO_FLAG_ANY :
        {
            if ( g_eSettings[ KNIFE_INFO_FLAG_BIT ] & iFlags )
            {
                bKnifeInfo = true
            }
        }
        case BHOP_INFO_FLAG_ALL :
        {
            if ( g_eSettings[ KNIFE_INFO_FLAG_BIT ] & iFlags == g_eSettings[ KNIFE_INFO_FLAG_BIT ] )
            {
                bKnifeInfo = true
            }
        }
        case BHOP_INFO_DISABLED : 
        {
            bKnifeInfo = false
        }
        default : 
        {
            bKnifeInfo = true
        }
    }

    if ( bKnifeInfo )
    {
        formatex( szText, charsmax( szText ), "%L \y%L %L", id, "CK_DEFAULT_NAME", id, "CK_DEFAULT_INFO", id, g_iKnifeModel[ id ] == KNIFE_DEFAULT ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, _, _, iItem )

        formatex( szText, charsmax( szText ), "%L \y%L %L", id, "CK_MACHETE_NAME", id, "CK_MACHETE_INFO", id, g_iKnifeModel[ id ] == KNIFE_MACHETE ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, _, _, iItem )

        formatex( szText, charsmax( szText ), "%L \y%L %L", id, "CK_BAK_NAME", id, "CK_BAK_INFO", id, g_iKnifeModel[ id ] == KNIFE_BAK ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, _, _, iItem )

        formatex( szText, charsmax( szText ), "%L \y%L %L", id, "CK_BUTCHER_NAME", id, "CK_BUTCHER_INFO", id, g_iKnifeModel[ id ] == KNIFE_BUTCHER ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, _, _, iItem )

        formatex( szText, charsmax( szText ), "%L \y%L %L", id, "CK_POCKET_NAME", id, "CK_POCKET_INFO", id, g_iKnifeModel[ id ] == KNIFE_POCKET ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, _, _, iItem )
    }
    else 
    {
        formatex( szText, charsmax( szText ), "%L \y%L", id, "CK_DEFAULT_NAME", id, g_iKnifeModel[ id ] == KNIFE_DEFAULT ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, _, _, iItem )

        formatex( szText, charsmax( szText ), "%L \y%L", id, "CK_MACHETE_NAME", id, g_iKnifeModel[ id ] == KNIFE_MACHETE ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, _, _, iItem )

        formatex( szText, charsmax( szText ), "%L \y%L", id, "CK_BAK_NAME", id, g_iKnifeModel[ id ] == KNIFE_BAK ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, _, _, iItem )

        formatex( szText, charsmax( szText ), "%L \y%L", id, "CK_BUTCHER_NAME", id, g_iKnifeModel[ id ] == KNIFE_BUTCHER ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, _, _, iItem )

        formatex( szText, charsmax( szText ), "%L \y%L", id, "CK_POCKET_NAME", id, g_iKnifeModel[ id ] == KNIFE_POCKET ? "CK_SELECTED" : "CK_EMPTY" )
        menu_additem( iMenu, szText, _, _, iItem )
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

    g_iKnifeModel[ id ] = iItem
    switch( g_iKnifeModel[ id ] )
    {
        case KNIFE_DEFAULT  :SetModel( id, KNIFE_DEFAULT )
        case KNIFE_MACHETE  :SetModel( id, KNIFE_MACHETE )
        case KNIFE_BAK      :SetModel( id, KNIFE_BAK )
        case KNIFE_BUTCHER  :SetModel( id, KNIFE_BUTCHER )
        case KNIFE_POCKET   :SetModel( id, KNIFE_POCKET )
    }

    EventCurWeapon( id )
    saveData( id )
    menu_destroy( iMenu )

    return PLUGIN_HANDLED
}

public ItemHandler( id, iMenu, iItem )
{
    return g_iKnifeModel[ id ] == iItem ? ITEM_DISABLED : ITEM_IGNORE
}

public SetModel( id, iItem )
{
    if ( !is_user_connected( id ) || !is_user_alive( id ) )
    {
        return PLUGIN_HANDLED
    }

    new iWeapon = get_user_weapon( id, _, _ )

    if ( iWeapon != CSW_KNIFE )
    { 
        engclient_cmd( id, "weapon_knife" )
    }

    switch( iItem )
    {
        case KNIFE_DEFAULT : 
        {
            entity_set_string( id, EV_SZ_viewmodel, g_eSettings[ DEFAULT_VIEW_MODEL ] )
            entity_set_string( id, EV_SZ_weaponmodel, g_eSettings[ DEFAULT_PLAYER_MODEL ] )
        }
        case KNIFE_MACHETE : 
        {
            entity_set_string( id, EV_SZ_viewmodel, g_eSettings[ MACHETE_VIEW_MODEL ] )
            entity_set_string( id, EV_SZ_weaponmodel, g_eSettings[ MACHETE_PLAYER_MODEL ] )
        }
        case KNIFE_BAK : 
        {
            entity_set_string( id, EV_SZ_viewmodel, g_eSettings[ BAK_VIEW_MODEL ] )
            entity_set_string( id, EV_SZ_weaponmodel, g_eSettings[ BAK_PLAYER_MODEL ] )
        }
        case KNIFE_BUTCHER : 
        {
            entity_set_string( id, EV_SZ_viewmodel, g_eSettings[ BUTCHER_VIEW_MODEL ] )
            entity_set_string( id, EV_SZ_weaponmodel, g_eSettings[ BUTCHER_PLAYER_MODEL ] )
        }
        case KNIFE_POCKET : 
        {
            entity_set_string( id, EV_SZ_viewmodel, g_eSettings[ POCKET_VIEW_MODEL ] )
            entity_set_string( id, EV_SZ_weaponmodel, g_eSettings[ POCKET_PLAYER_MODEL ] )
        }
    }

    return PLUGIN_HANDLED
}

public client_PreThink( id )
{
    if ( !is_user_connected( id ) || !is_user_alive( id ) )
    {
        return PLUGIN_CONTINUE
    }

    new iFlags, bBhop = false
    iFlags = pev( id, pev_flags )

    if ( !( iFlags & FL_ONGROUND ) || !(get_user_button( id ) & IN_JUMP) )
    { 
        return PLUGIN_CONTINUE
    }

    switch( g_eSettings[ BHOP_INFO ] )
    {
        case KNIFE_INFO_FLAG_ANY :
        {
            if ( g_eSettings[ BHOP_INFO_FLAG_BIT ] & iFlags )
            {
                bBhop = true
            }
        }
        case KNIFE_INFO_FLAG_ALL :
        {
            if ( g_eSettings[ BHOP_INFO_FLAG_BIT ] & iFlags == g_eSettings[ BHOP_INFO_FLAG_BIT ] )
            {
                bBhop = true
            }
        }
        case KNIFE_INFO_DISABLED : 
        {
            bBhop = false
        }
        default : 
        {
            bBhop = true
        }
    }

    if ( bBhop )
    {
        new Float:fVelocity[ 3 ]

        pev( id, pev_velocity, fVelocity )
        fVelocity[ 2 ] += g_eSettings[ BHOP_BURST ]
        set_pev( id, pev_velocity, fVelocity )
    }

    return PLUGIN_CONTINUE
}

public EventCurWeapon( id )
{
    new Float:fSpeed = g_eSettings[ DEFAULT_SPEED ]
    new Float:fGravity = g_eSettings[ DEFAULT_GRAVITY ]
    new iWeapon = get_user_weapon( id, _, _ )
    set_user_footsteps( id, 0 )

    // If hes not holding a knife we're setting the default abilities
    if ( iWeapon != CSW_KNIFE )
    {
        set_pev( id, pev_maxspeed, fSpeed )
        set_pev( id, pev_gravity, fGravity )
        return PLUGIN_CONTINUE
    }

    SetModel( id, g_iKnifeModel[ id ] )

    switch( g_iKnifeModel[ id ] )
    {
        case KNIFE_MACHETE : 
        {
            fSpeed = g_eSettings[ LOW_SPEED_LEVEL_C ]
        }
        case KNIFE_BAK : 
        {
            set_user_footsteps( id )
        }
        case KNIFE_BUTCHER : 
        {
            fGravity = g_eSettings[ LOW_GRAVITY_LEVEL_C ]
        }
        case KNIFE_POCKET : 
        {
            fSpeed = g_eSettings[ HIGH_SPEED_LEVEL_C ]
        }
    }

    set_pev( id, pev_maxspeed, fSpeed )
    set_pev( id, pev_gravity, fGravity )

    return PLUGIN_CONTINUE
}

public HamTakeDamage( iVictim, iInflictor, iAttacker, Float:fDamage )
{
    if ( iInflictor != CSW_KNIFE || g_iKnifeModel[ iAttacker ] != KNIFE_MACHETE )
    { 
        return HAM_IGNORED
    }

    new iHealth, iDamage, iWeapon, iBodyHit

    iHealth = pev( iVictim, pev_health )
    iDamage = floatround( fDamage * g_eSettings[ HIGH_DAMAGE_LEVEL_B ] )
    get_user_attacker( iVictim, iWeapon, iBodyHit )

    if ( iHealth > iDamage )
    {
        fakedamage( iVictim, "weapon_knife", float( iDamage ), iBodyHit )
    }
    else 
    {
        user_silentkill( iVictim )
        make_deathmsg( iAttacker, iVictim, 0, "knife" )
    }

    return HAM_IGNORED
}

stock LogConfigError( const iLine, const szText[], any:... )
{
    static szError[ MAX_PLATFORM_PATH_LENGTH ]
    vformat( szError, charsmax( szError ), szText, 3 )
    log_to_file( ERROR_FILE, "Line %d : %s", iLine, szError )
}

                        

