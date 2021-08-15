/*
 * sm_throwable9mm.sp: [fjc] apollyon094's throwable pistol thing
 * Copyright (c) 2018-2020 [fjc] apollyon094 <apollyon094@protonmail.com> | http://steamcommunity.com/id/notapollo95/ 
 * Website: apollyon093.blogspot.com
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>


#undef REQUIRE_PLUGIN
/* #include <donator> */

#define VERSION "0.22"

public Plugin:myinfo = {
	name = "[fjc] apollyon094's pistol",
	description = "throwable pistol",
	author = "[fjc] apollyon094",
	version = VERSION,
	url = "apollyon093.blogspot.com"
};

enum EPlayerSetting
{
	Float:e_lastAttackTime,
        Float:e_lastWarnTime,
	e_numThrows,	
	e_allowedThrows,
	keyBuffer,
}

new playerSettings[MAXPLAYERS+1][EPlayerSetting];

new Handle:g_hCvarVersion;

#define PROP_TYPE	"prop_physics_override"

#define MELEE_CROWBAR	1
#define MELEE_STUNSTICK	2


new Handle:g_Crowbars;
new Handle:g_hCrowbarExplodeRadius = INVALID_HANDLE;
new Handle:g_hCrowbarExplodeMagnitude = INVALID_HANDLE;
new Handle:g_hCrowbarThrownDamage = INVALID_HANDLE;
new Handle:g_hCrowbarMaxSpawn	= INVALID_HANDLE;
new Handle:g_hCrowbarMaxLife	= INVALID_HANDLE;
new Handle:g_hCrowbarMinTime = INVALID_HANDLE;
new Handle:g_hCrowbarFlags = INVALID_HANDLE;
new Handle:g_hCrowbarDonatorLevel = INVALID_HANDLE;
new Handle:g_hCrowbarDonatorMaxSpawn = INVALID_HANDLE;
new Handle:g_hDebug = INVALID_HANDLE;
new Handle:g_hNotifyMessage = INVALID_HANDLE;
new Handle:g_hUnavailableSound = INVALID_HANDLE;
new Handle:g_hLastWord = INVALID_HANDLE;

new bool:hasDonator = false;


new Float:iExplodeRadius = 15.0;
new Float:iExplodeMagnitude = 250.0;
new iThrownBarDamage = 80;
new iMaxCrowbarsPerSpawn = 3;
new Float:flMaxLifetime = 30.0;
new Float:flMinThrowTime = 1.0;
new g_iRequiredFlags = 0;
new g_iRequiredDonatorLevel = 0;
new g_iDonatorMaxCrowbarsPerSpawn = 3;
new g_iNotifyMessage = 1;
new g_iLastWord = 0;

new String:szUnavailableSound[1024];

new iDebug = 0;


new Float:now = 0.0;
//new Float:tdiff = 0.0;
//new Float:lastwarn = 0.0;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("IsPlayerDonator");
	MarkNativeAsOptional("GetDonatorLevel");
	return APLRes_Success;
}

public OnPluginStart()
{

	g_hCvarVersion = CreateConVar("sm_throwable9mm_version", VERSION, "[fjc] apollyon094's pistol version",  FCVAR_NOTIFY|FCVAR_DONTRECORD);
	SetConVarString(g_hCvarVersion, VERSION);
	
	g_hDebug = CreateConVar("sm_throwable9mm_debug", "0", "Enable console debugging");
	HookConVarChange(g_hDebug, OnConVarChanged);

	g_hCrowbarExplodeMagnitude =  CreateConVar("sm_throwable9mm_explodedamage", "80", "Thrown Crowbar Explosion Magnitude.  Set to 0 to disable");
	HookConVarChange(g_hCrowbarExplodeMagnitude, OnConVarChanged);

	g_hCrowbarExplodeRadius = CreateConVar("sm_throwable9mm_exploderadius", "0", "Thrown Crowbar Explosion Radius Override.  Leave as 0 to scale to sm_throwable9mm_explodedamage");
	HookConVarChange(g_hCrowbarExplodeRadius, OnConVarChanged);

	g_hCrowbarThrownDamage = CreateConVar("sm_throwable9mm_throwndamage", "80", "Damage a Thrown Crowbar should inflict");
	HookConVarChange(g_hCrowbarThrownDamage, OnConVarChanged);
	
	g_hCrowbarMaxSpawn = CreateConVar("sm_throwable9mm_maxperspawn", 	"5", "Maximum throwing crowbars per spawn.  0 = unlimited. -1 = none");
	HookConVarChange(g_hCrowbarMaxSpawn, OnConVarChanged);

	g_hCrowbarMaxLife = CreateConVar("sm_throwable9mm_maxlife", "30", "Maximum seconds thrown crowbars (that don't explode) should stick around before dying");
	HookConVarChange(g_hCrowbarMaxLife, OnConVarChanged);

	g_hCrowbarMinTime = CreateConVar("sm_throwable9mm_mintime", "1", "Minimum seconds required between thrown crowbars");
	HookConVarChange(g_hCrowbarMinTime, OnConVarChanged);

	g_hCrowbarDonatorLevel = CreateConVar("sm_throwable9mm_donator_level", "0",  "Minimum donator level required to use throwing crowbars/stunsticks. 0 = don't use donator system");
	HookConVarChange(g_hCrowbarDonatorLevel, OnConVarChanged);
	
	g_hCrowbarDonatorMaxSpawn = CreateConVar("sm_throwable9mm_donator_maxperspawn", "0", "Maximum throwing crowbars per spawn for donators.  0 = unlimited");
	HookConVarChange(g_hCrowbarDonatorMaxSpawn, OnConVarChanged);

	g_hCrowbarFlags = CreateConVar("sm_throwable9mm_requiredflag", "", "Admin Flag a player has to have to use throwing crowbars/stunsticks.  Leave blank for no flag requirement");
	HookConVarChange(g_hCrowbarFlags, OnConVarChanged);

	g_hNotifyMessage = CreateConVar("sm_throwable9mm_notifymsg", "1", "When or if to display crowbar availability.  0 to disable.  1 at spawn.  ");
	HookConVarChange(g_hNotifyMessage, OnConVarChanged);

	g_hUnavailableSound = CreateConVar("sm_throwable9mm_sound", "common/wpn_denyselect.wav", "Sound to play if crowbar isn't available to throw");
	HookConVarChange(g_hUnavailableSound, OnConVarChanged);

	g_hLastWord = CreateConVar("sm_throwable9mm_lastword", "1", "Whether to allow players to throw crowbar(s) after they're dead");
	HookConVarChange(g_hLastWord, OnConVarChanged);

	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i))
		{
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}

	HookEvent("player_spawn", Event_PlayerSpawn);

	g_Crowbars = CreateTrie();
	AutoExecConfig();

	PrintToServer("apolly's crowbar %s loaded", VERSION);
}

public OnAllPluginsLoaded()
{
	hasDonator=false;

	if(LibraryExists("donator.core")) {
		hasDonator=true;
	}
}  

public OnConfigsExecuted()
{

	new String:szRequiredFlags[16];

	iExplodeRadius = GetConVarFloat(g_hCrowbarExplodeRadius);
	iExplodeMagnitude = GetConVarFloat(g_hCrowbarExplodeMagnitude);
	iThrownBarDamage = GetConVarInt(g_hCrowbarThrownDamage);
	iMaxCrowbarsPerSpawn = GetConVarInt(g_hCrowbarMaxSpawn);
	flMaxLifetime = GetConVarFloat(g_hCrowbarMaxLife);
	flMinThrowTime = GetConVarFloat(g_hCrowbarMinTime);
	GetConVarString(g_hCrowbarFlags, szRequiredFlags, sizeof(szRequiredFlags));
	g_iRequiredDonatorLevel = GetConVarInt(g_hCrowbarDonatorLevel);
	g_iDonatorMaxCrowbarsPerSpawn = GetConVarInt(g_hCrowbarDonatorMaxSpawn);
	g_iNotifyMessage = GetConVarInt(g_hNotifyMessage);
	g_iLastWord = GetConVarInt(g_hLastWord);

	GetConVarString(g_hUnavailableSound, szUnavailableSound, sizeof(szUnavailableSound));

	PrecacheSound(szUnavailableSound, true);
//	AddFileToDownloadsTable(szUnavailableSound);

	iDebug = GetConVarInt(g_hDebug);

	TrimString(szRequiredFlags);
	if(szRequiredFlags[0]=='\0'){

	} else { 
		g_iRequiredFlags = ReadFlagString(szRequiredFlags);
	}
}

public OnConVarChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	OnConfigsExecuted();
}

public InitPlayerSettings(client)
{
	playerSettings[client][e_lastAttackTime] = 0.0;
	playerSettings[client][e_numThrows] = 0;
	playerSettings[client][e_allowedThrows] = -1;
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new bool:has_crowbar = false;
	new bool:has_stunstick = false;
	new String:weaponString[50];

	if(!IsAllowed(client)) {
		return Plugin_Continue;
	}
	
	playerSettings[client][e_numThrows] = 0;

	if(hasDonator==true) {
/*		playerSettings[client][e_allowedThrows] = IsPlayerDonator(client) ? g_iDonatorMaxCrowbarsPerSpawn : iMaxCrowbarsPerSpawn; */
		playerSettings[client][e_allowedThrows] = 1                       ? g_iDonatorMaxCrowbarsPerSpawn : iMaxCrowbarsPerSpawn;
	} else {
		playerSettings[client][e_allowedThrows] = iMaxCrowbarsPerSpawn;
	}

	if(Client_HasWeapon(client, "weapon_pistol")){
		client_has = true;
	}
	
	if(has_crowbar==true && has_stunstick==true ) {
		Format(weaponString, sizeof(weaponString), "pistols");	// tell me if this doesn't work or i fucked it up
	}

	if(playerSettings[client][e_allowedThrows] == -1 ) {
		return Plugin_Continue;
	}


	if(g_iNotifyMessage == 1 ){
		if(playerSettings[client][e_allowedThrows] > 0 ) {
			PrintToChat(client, "You have %d throwing %s!", playerSettings[client][e_allowedThrows], weaponString);
		} else {
			PrintToChat(client, "You have a LOT of throwing %s!", weaponString);
		}
	}

	return Plugin_Continue;

}

public OnClientPutInServer(client)
{
        SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	InitPlayerSettings(client);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	decl String:attackerWeapon[30];
	GetEdictClassname(inflictor, attackerWeapon, sizeof(attackerWeapon));


	if(StrEqual(attackerWeapon, "player")){	// What a load of BS
		GetClientWeapon(attacker, attackerWeapon, sizeof(attackerWeapon));
	}

	decl String:buffer[25];
	IntToString(EntIndexToEntRef(inflictor), buffer, sizeof(buffer));
	new tcrowbar[2];
	new bool:gotTrie = GetTrieArray(g_Crowbars, buffer, tcrowbar, sizeof(tcrowbar));
	
	
	if(iDebug){
		PrintToServer("Crowbar: attacker=%d inflictor=%d damage=%f weapon=%d attackerWeapon=%s realattacker=%s", attacker, inflictor, damage, weapon, attackerWeapon, buffer);
	}

	if(StrEqual(attackerWeapon, "prop_physics")){
		if(gotTrie == false){
			PrintToServer("sm_throwable9mm: OnTakeDamage: BAD TRIE!");
			return Plugin_Continue;
		}

		// It's a flying crowbar!
		new Float:originalDamage = damage;

		damage = 0.0;

		if(iDebug){
			PrintToServer("%f %d %d", originalDamage, iThrownBarDamage, iThrownBarDamage);
		}

		new inflictDamage = RoundFloat(originalDamage) > iThrownBarDamage ? RoundFloat(originalDamage) : iThrownBarDamage;
		Entity_Hurt(victim,  inflictDamage, tcrowbar[0], DMG_CLUB, tcrowbar[1] == MELEE_CROWBAR ? "crowbar" : "stunstick");
	//	PrintToServer("Inflict %d damage", inflictDamage);
		return Plugin_Changed;	//Changed;
	}
	return Plugin_Continue;
}

public Action:OnPlayerRunCmd(client, &iButtons, &Impulse, Float:fVelocity[3], Float:fAngles[3], &iWeapon)
{

	new iTimeLeft;

	if(playerSettings[client][e_allowedThrows]==-1 ) {
		return Plugin_Continue;
	}

	GetMapTimeLeft(iTimeLeft);

	if((!IsPlayerAlive(client) || iTimeLeft<=0) && !g_iLastWord){ 	// Note: timeleft may be negative on servers with infinite time, in which case we should check GetMapTimeLimit too
		return Plugin_Continue;
	}

	now = GetGameTime();

	if( playerSettings[client][e_lastAttackTime] != 0.0 && (now - playerSettings[client][e_lastAttackTime]) < flMinThrowTime ){
		return Plugin_Continue;
	}

	decl iActiveWeapon;
	iActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");

	if(iActiveWeapon != -1 && IsValidEntity(iActiveWeapon) && IsValidEdict(iActiveWeapon) ) {
		decl String:weapon[64];	

		GetEdictClassname(iActiveWeapon, weapon, sizeof(weapon));	

		if((StrEqual(weapon, "weapon_crowbar") || StrEqual(weapon, "weapon_stunstick")) && (iButtons & IN_ATTACK2 )) {

			playerSettings[client][e_lastAttackTime] = now;

			if(playerSettings[client][e_allowedThrows] > 0  && playerSettings[client][e_numThrows] >= playerSettings[client][e_allowedThrows] ) {
				PrintToChat(client, "You don't have any throwing crowbars left!");
				playerSettings[client][e_lastWarnTime] = GetGameTime();
				EmitSoundToAll(szUnavailableSound, client);
				return Plugin_Continue;
			}

			if(StrEqual(weapon, "weapon_pistol")) {
				ThrowPistol(client);
			}

			iButtons |= IN_ATTACK;
//			RemovePlayerItem(client, iActiveWeapon);
		}
	}
	return Plugin_Continue;	
}

public explode(entity)
{

	decl Float:position[3];

	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	if(iDebug){
		PrintToServer("Creating explosion at %f/%f/%f", position[0], position[1], position[2]);
	}

	new owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if(iDebug){
		PrintToServer("Owner entity of the crowbar was %d", owner);
	}

	new ent = CreateEntityByName("env_explosion");
	if(ent<0){
		PrintToServer("Failed to create env_physexplosion!");
		return false;
	}

	if(owner>=0){	
		SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", owner);
	}

	TeleportEntity(ent, position, NULL_VECTOR, NULL_VECTOR);

	DispatchKeyValue(ent, "spawnflags", "4");

	if(iExplodeRadius>0){
		DispatchKeyValueFloat(ent, "iRadiusOverride", iExplodeRadius);
	}

	DispatchKeyValueFloat(ent, "iMagnitude", iExplodeMagnitude);
	DispatchSpawn(ent);
	ActivateEntity(ent);
	AcceptEntityInput(ent, "Explode");
	AcceptEntityInput(ent, "Kill");
	return true;

}

public OnTouch(entity, other)
{
	if(iDebug){
		PrintToServer("Collide? entity=%d other=%d", entity, other);
	}

	if(explode(entity)<0){
		return false;
	}

	AcceptEntityInput(entity, "Kill");
	return false;//true;
}

ThrowPistol(client)
{
	new Float:angles[3];
	new Float:fwd[3];
	new Float:cvelocity[3];
	new Float:origin[3];
	new Float:velocity[3];

	GetClientEyeAngles(client, angles);
	GetClientEyePosition(client, origin);

	GetAngleVectors(angles, fwd, NULL_VECTOR, NULL_VECTOR);

	ScaleVector(fwd, (1000.0 + (250.0 *5 ) ) );

 	GetEntPropVector(client, Prop_Data, "m_vecVelocity", cvelocity);
	AddVectors(fwd, cvelocity, velocity);


	new ent = CreateEntityByName(PROP_TYPE);
	if(ent<=0){
		return;
	}
	SetEntityModel(ent, "models/weapons/w_pistol.mdl");
	}

	DispatchKeyValue(ent, "damagetype", "1");
	DispatchKeyValue(ent, "spawnflags", "32");
	DispatchKeyValue(ent, "inertiaScale", "10.0");


//	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 11);	

	DispatchSpawn(ent);

//	SetEntProp(ent, Prop_Send, "m_nSolidType", 12);
//	SetEntProp(ent, Prop_Send, "m_usSolidFlags", 0x0004);	// 136 = FSOLID_TRIGGER | FSOLID_USE_TRIGGER_BOUNDS

	if(iExplodeMagnitude>0){
		SDKHook(ent,  SDKHook_Touch, OnTouch);
	}

	SetVariantString("OnUser1 !self:Kill::1.5:1");
        AcceptEntityInput(ent, "AddOutput");

	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);	// needed to prevent self-collisions

//	SetEntPropVector(ent, Prop_Data, "m_vecAngVelocity", g_fSpin);
	SetEntPropFloat(ent, Prop_Send, "m_flElasticity", 0.2);


	SetVariantString("!activator");
	HookSingleEntityOutput(ent, "OnPhysGunOnlyPickup", OnGravgunPickup);

	angles[1] += Float:GetRandomFloat(0.1, 5.0);

//	TeleportEntity(ent, origin, angles, velocity);

	TeleportEntity(ent, origin, fwd, velocity);

	playerSettings[client][e_numThrows]++;
	playerSettings[client][e_lastWarnTime] = GetGameTime();

	decl String:buffer[25];
	new ref = EntIndexToEntRef(ent);

	Format(buffer, sizeof(buffer), "%d", ref);
	new trieArray[2];
	trieArray[0] = client;
	trieArray[1] = meleeType;

	SetTrieArray(g_Crowbars, buffer, trieArray, sizeof(trieArray));
	CreateTimer(flMaxLifetime, KillCrowbar, ref);
}

public OnGravgunPickup(const String:output[], caller, activator, Float:delay)
{
	if(IsValidEntity(caller)){
		decl String:buffer[25];
		new trieArray[2];
		
		Format(buffer, sizeof(buffer), "%d", EntIndexToEntRef(caller));
		GetTrieArray(g_Crowbars, buffer, trieArray, sizeof(trieArray));
		trieArray[0] = activator;
		
		SetTrieArray(g_Crowbars, buffer, trieArray, sizeof(trieArray));
		SetEntPropEnt(caller, Prop_Send, "m_hOwnerEntity", activator);
	}
}

public Action:KillCrowbar(Handle:timer, any:ref)
{
	new entity = EntRefToEntIndex(ref);
	if(entity < 0 )
		return;

	if(IsValidEdict(entity)){
		AcceptEntityInput(entity, "kill");
	}
	decl String:buffer[25];
	IntToString(ref, buffer, sizeof(buffer));
	RemoveFromTrie(g_Crowbars, buffer); 
//PrintToServer("TCROWBAR KILLING index=%d ref=%d", entity, ref)
}

public DispatchKeyValueInt(ent, const String:vari[], val)
{
	decl String:buffer[50];
	//IntToString(_:val, buffer, sizeof(buffer));
	Format(buffer, sizeof(buffer), "%d", val);
//	decho("DispatchKeyValue(%d,%s,%s) (was %d)", ent, vari, buffer,val);
	return(DispatchKeyValue(ent, vari, buffer));
}

public bool:IsAllowed(client)
{
	if(hasDonator==true ) {
/*		if(g_iRequiredDonatorLevel && GetDonatorLevel(client) < g_iRequiredDonatorLevel ) { */
		if(g_iRequiredDonatorLevel && 0                       < g_iRequiredDonatorLevel ) {
			return false;
		}
	}

	if(g_iRequiredFlags == 0 ) {
		return true;
	}

	new AdminId:adminId = GetUserAdmin(client);
	if(adminId == INVALID_ADMIN_ID ) {
		return false;
	}
	new flags = GetAdminFlags(adminId, Access_Effective);
	if(flags & g_iRequiredFlags ) {	
		return true;
	}

	return false;

}

/*
Debug_PrintButtons(client, buttons)
{
	if(buttons &  IN_ATTACK		) { PrintToServer("%d is IN_ATTACK", client); }
	if(buttons &  IN_JUMP			) { PrintToServer("%d is IN_JUMP ", client); }
	if(buttons &  IN_DUCK			) { PrintToServer("%d is IN_DUCK", client); }
	if(buttons &  IN_FORWARD		) { PrintToServer("%d is IN_FORWARD", client); }
	if(buttons &  IN_BACK			) { PrintToServer("%d is IN_BACK", client); }
	if(buttons &  IN_USE			) { PrintToServer("%d is IN_USE", client); }
	if(buttons &  IN_CANCEL		) { PrintToServer("%d is IN_CANCEL", client); }
	if(buttons &  IN_LEFT			) { PrintToServer("%d is IN_LEFT", client); }
	if(buttons &  IN_RIGHT		) { PrintToServer("%d is IN_RIGHT", client); }
	if(buttons &  IN_MOVELEFT		) { PrintToServer("%d is IN_MOVELEFT", client); }
	if(buttons &  IN_MOVERIGHT		) { PrintToServer("%d is IN_MOVERIGHT", client); } 
	if(buttons &  IN_ATTACK2		) { PrintToServer("%d is IN_ATTACK2", client); } 
	if(buttons &  IN_RUN			) { PrintToServer("%d is IN_RUN", client); } 
	if(buttons &  IN_RELOAD		) { PrintToServer("%d is IN_RELOAD", client); } 
	if(buttons &  IN_ALT1			) { PrintToServer("%d is IN_ALT1", client); } 
	if(buttons &  IN_ALT2			) { PrintToServer("%d is IN_ALT2", client); } 
	if(buttons &  IN_SCORE		) { PrintToServer("%d is IN_SCORE", client); }
	if(buttons &  IN_SPEED		) { PrintToServer("%d is IN_SPEED", client); }
	if(buttons &  IN_WALK			) { PrintToServer("%d is IN_WALK", client); }
	if(buttons &  IN_ZOOM			) { PrintToServer("%d is IN_ZOOM", client); }
	if(buttons &  IN_WEAPON1		) { PrintToServer("%d is IN_WEAPON1", client); }
	if(buttons &  IN_WEAPON2		) { PrintToServer("%d is IN_WEAPON2", client); } 
	if(buttons &  IN_BULLRUSH		) { PrintToServer("%d is IN_BULLRUSH", client); } 
	if(buttons &  IN_GRENADE1		) { PrintToServer("%d is IN_GRENADE1", client); } 
	if(buttons &  IN_GRENADE2		) { PrintToServer("%d is IN_GRENADE2", client); } 
	if(buttons &  IN_ATTACK3		) { PrintToServer("%d is IN_ATTACK3", client); }

}

Debug_PrintSolidFlags(ent)
{
	new  solf = GetEntProp(ent, Prop_Send, "m_usSolidFlags");
	if(solf & FSOLID_CUSTOMRAYTEST ) { PrintToServer("%d is FSOLID_CUSTOMRAYTEST", ent); }
	if(solf & FSOLID_CUSTOMBOXTEST) { PrintToServer("%d is FSOLID_CUSTOMBOXTEST", ent); }
	if(solf & FSOLID_NOT_SOLID) { PrintToServer("%d is FSOLID_NOT_SOLID", ent); }
	if(solf & FSOLID_TRIGGER) { PrintToServer("%d is FSOLID_TRIGGER", ent); }
	if(solf & FSOLID_NOT_STANDABLE) { PrintToServer("%d is FSOLID_NOT_STANDABLE", ent); }
	if(solf & FSOLID_VOLUME_CONTENTS) { PrintToServer("%d is FSOLID_VOLUME_CONTENTS", ent); }	
	if(solf & FSOLID_FORCE_WORLD_ALIGNED) { PrintToServer("%d is FSOLID_FORCE_WORLD_ALIGNED", ent); }
	if(solf & FSOLID_USE_TRIGGER_BOUNDS) { PrintToServer("%d is FSOLID_USE_TRIGGER_BOUNDS", ent); }
	if(solf & FSOLID_ROOT_PARENT_ALIGNED) { PrintToServer("%d is FSOLID_ROOT_PARENT_ALIGNED", ent); }
	if(solf & FSOLID_TRIGGER_TOUCH_DEBRIS) { PrintToServer("%d is FSOLID_TRIGGER_TOUCH_DEBRIS", ent); }
}

*/
