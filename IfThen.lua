--####################################################################################
--####################################################################################
--Main class
--####################################################################################
--####################################################################################
--Dependencies: Lib\*.lua, StringParsing.lua, SyntaxColor.lua, Macro.lua, Methods.lua, Documentation.lua, Parsing.lua

--Bindings.xml						(http://www.wowwiki.com/Using_bindings.xml_to_create_key_bindings_for_your_addon)
BINDING_HEADER_IFTHEN				= "IfThen";
_G["BINDING_NAME_MACRO IfThen_Btn"]	= "Trigger IfThen macro";
BINDING_NAME_IFTHEN_EDIT			= "Show edit window";
BINDING_NAME_IFTHEN_MOREHELP		= "Show 'more help' window";

local IFTHEN_frame						= nil; --Self reference(s) used for RegisterEvent/UnregisterEvent
local IFTHEN_frame_onevent				= nil;
local IFTHEN_frame_onevent_background	= nil;
local IFTHEN_frame_Edit_FilterBox		= nil;

--IFTHEN_GameVersion					= nil; --UIversion number of the game for quick lookup for other parts of the code for compatibility
	--if (IFTHEN_GameVersion < 50400) then
		--Before patch 5.4.0

local IFTHEN_addon_type		= GetAddOnMetadata("IfThen", "X-AddonType");	--BETA or FULL
local IFTHEN_addon_version	= GetAddOnMetadata("IfThen", "Version");		--Version number for the addon from the .TOC file
--local IFTHEN_addon_type		= "FULL";	--Either "FULL" or "BETA"
--local IFTHEN_addon_version	= "2.0.0"	--Version number for the addon

IFTHEN_text_version			= "0.0.0"	--Version number for the raw text, for future compat issues (SAVED TO DISK)
IFTHEN_text					= {};		--Array of Raw text							(SAVED TO DISK)
IFTHEN_cache				= {};		--List of things that we persistently cache (SAVED TO DISK)
IFTHEN_settings				= {};		--Array of Settings							(SAVED TO DISK)

	--Constant definitions for all the key's in IFTHEN_settings
local SETTING_OnEvent		= "OnEvent";		--OnEvent() feature enabled/disabled
local SETTING_ExtraSlash	= "ExtraSlash";		--ExtraSlash feature enabled/disabled
local SETTING_GetQuest		= "GetQuest";		--GetQuest feature enabled/disabled
local SETTING_MacroRefresh	= "MacroRefresh";	--Says whether the Macro should automatically update the icon to that of the item/spell being used
local SETTING_Shift			= "Shift";			--Shift/Alt clicking the macro will open window / reload UI
local SETTING_Spellcheck	= "Spellcheck";		--Use the spellcheck feature
local SETTING_Minimal		= "Minimal";		--Use the minimal feature
local SETTING_Color			= "Color";			--Use the syntax coloring feature
local SETTING_EasyCast		= "EasyCast";		--EasyCast feature
local SETTING_LineNumber	= "LineNumber";		--LineNumber feature
local SETTING_Debug			= "Debug";			--Debugging enabled/disabled

--Constants
local CONST_AddonFull				= "FULL";	--Always has the value "FULL";
local CONST_AddonPrefix				= "IFTHEN";	--Prefix for addon messages
local CONST_VersionAnnounceMax		= 60;		--Number of seconds in between global auto-announcements
local CONST_SearchResultLines		= 4;		--If the screen width is below 1280 we change this to 2. Number of lines shown in search in Edit frame.
local CONST_HelpNavigateNum			= 40;		--If the screen height is below 900 we change this to 10. Number of entries to show in the hyperlink list for the help page.
local CONST_MaxDoubleClickInterval	= 0.40;		--Max time in seconds between 2 mouseclicks. Higher than this and we dont call it a 'double' click


--Local pointers to global functions
local tonumber	= tonumber;
local tostring	= tostring;
local pairs		= pairs;
local math_floor= floor;	--math.floor
local strlen	= strlen;
local strsub	= strsub;
local strlower	= strlower;
local strupper	= strupper;
local strtrim	= strtrim;	--string.trim
local tinsert	= tinsert;	--table.insert
local sort		= sort;		--table.sort
local select 	= select;

local print				= print;
local InCombatLockdown	= InCombatLockdown;
local IsAltKeyDown		= IsAltKeyDown;
local IsShiftKeyDown	= IsShiftKeyDown;
local UnitChannelInfo	= UnitChannelInfo;
local UnitCastingInfo	= UnitCastingInfo;
local GetNumGossipAvailableQuests = GetNumGossipAvailableQuests;
local SelectGossipAvailableQuest= SelectGossipAvailableQuest;
local GetNumGossipActiveQuests	= GetNumGossipActiveQuests;
local SelectGossipActiveQuest	= SelectGossipActiveQuest;
local CompleteQuest		= CompleteQuest;
local GetNumQuestChoices= GetNumQuestChoices;
local GetQuestReward	= GetQuestReward;
local IsMouseButtonDown	= IsMouseButtonDown;
local GetMouseFocus		= GetMouseFocus;
local IsMouselooking	= IsMouselooking;
local GetTime			= GetTime;
local GetScreenWidth	= GetScreenWidth;
local MouselookStop		= MouselookStop;
local SetOverrideBindingMacro	= SetOverrideBindingMacro;
local ClearOverrideBindings		= ClearOverrideBindings;


--####################################################################################
--####################################################################################
--Event Handling and Macro Scriptmethod
--####################################################################################

IfThen			= {};	--Global declaration
IfThen.__index	= IfThen;

local StringParsing	= IfThen_StringParsing;		--Local pointer
local SyntaxColor	= IfThen_SyntaxColor;		--Local pointer
local Macro			= IfThen_Macro;				--Local pointer
local Methods		= IfThen_Methods;			--Local pointer
local Documentation	= IfThen_Documentation;		--Local pointer
local Parsing		= IfThen_Parsing;			--Local pointer

--Local variables that cache stuff so we dont have to recreate large objects
local cache_getMoreHelpText		= nil;
local cache_getScrollText		= nil;
local cache_addonLoaded			= false;	--flag to tell us wehter the addon is loaded (so we dont reinit when instancing etc)
local cache_versionAnnounced	= false;	--flag used to make sure we only announce new version updates to the player only once per play session.
local cache_versionTable		= nil;		--temp table used to store list of names and version-numbers (nil == no logging)
local cache_versionAnnounceLast = nil;		--timestamp when we last did an global announcement, used to prevent spamming chat channels to often (does not consider whispers)
local cache_changePage			= false;	--flag to prevent verbose comments when changing page in the edit window
local cache_helpPageType		= "";		--the type of help page currently shown (all, syntax, argument, actions, event, variable, setting), the value is used when looking up documentation for a specific function
local cache_helpPageOffset		= 1;		--Number. Offset for what hyperlinks to show on the help page.
local cache_playerName			= strlower(GetUnitName("player",false));	--string with the players name (to reduce the number of lookups)
local cache_EditRecolorFlag		= false;	--Flag to prevent multiple calls to Edit_ReColor()
local cache_EditTextChangedFlag	= false;	--Flag used to determine if there is a need to Recolor the text when Syntax coloring is enabled
local cache_Color_Function		= "";
local cache_Color_Variable		= "";
local cache_Color_HyperLinks	= "FF0000"; --Red hyperlink color
local cache_EasyCastHook		= false;	--Flag to determine if we already have made a hook for EasyCast. This is to prevent creating multiple hooks that can occur if the user toggles the feature on/off several times
local cache_ACHIEVEMENT_TRACKER_MODULE = nil; --nil or pointer to an original function.

--Removes functions that are not needed after initial startup.
function IfThen:CleanUp()
	--if true then return nil end
	if (self:isDebug()) then print("Skipping cleanup since Debug mode is enabled"); return nil; end

	--if (cache_addonLoaded == false) then return nil end
	IfThen_Methods:CleanUp();
	IfThen_Parsing:CleanUp();
	IfThen_Documentation:CleanUp();

	IfThen_Methods["CleanUp"] = nil;
	IfThen_Parsing["CleanUp"] = nil;
	IfThen_Documentation["CleanUp"] = nil;

	self:getMoreHelpText_Declare("syntax"); --Make sure this has been called before we remove anything
	local d = {"OnLoad", "getMoreHelpText_Declare", "getExampleText", "versionCheck" , "ToggleHooks"};
	for i=1, #d do self[d[i]] = nil; end --for

	return nil;
end


--Retreive a dataitem from persistent cache
function IfThen:GetCache(name, isGlobal)
	if (name == nil or name == "") then return nil end
	if (isGlobal == nil) then name = name.."_"..GetRealmName().."_"..GetUnitName("player",false) end --default optional argument to set cache item as global instead of per character
	name = strupper(name);
	return IFTHEN_cache[name];
end--GetCache


--Store a dataitem in persistent cache
function IfThen:SetCache(name, value, isGlobal)
	if (name == nil or name == "") then return nil end
	if (isGlobal == nil) then name = name.."_"..GetRealmName().."_"..GetUnitName("player",false) end --default optional argument to set cache item as global instead of per character
	name = strupper(name);
	IFTHEN_cache[name] = value;
	return IFTHEN_cache[name];
end--SetCache


--Returns the current value for a setting. (Note: Case-Sensitive)
function IfThen:GetCurrentSetting(strSetting)
	if (strSetting == nil) then return nil end
	return IFTHEN_settings[strSetting];
end


--OnLoad Event
function IfThen:OnLoad(s)
	--We here only register for the events that we want to listen to, IfThen:OnEvent() handles the various events
	IFTHEN_frame = s; --save it for later reference
	s:RegisterEvent("PLAYER_ENTERING_WORLD");
	s:RegisterEvent("ADDON_LOADED");
	return nil;
end


--Handles the events for the addon
function IfThen:OnEvent(s, event, ...)
	--print("IfThen:OnEvent triggered: '"..event.."'   '"..tostring({...}) .."'");

	if (event == "PLAYER_ENTERING_WORLD") then
		--Startup
		--local ___version, ___internalVersion, ___thedate, ___uiVersion = GetBuildInfo();
		--IFTHEN_GameVersion = ___uiVersion; --UI version number used for compatibility checks between game versions.

		if (GetScreenWidth() < 1280) then CONST_SearchResultLines = 2	else CONST_SearchResultLines = 4 end --Number of lines to show in search result (restrict to only 2 on very low resolutions)
		if (GetScreenHeight() < 960) then CONST_HelpNavigateNum = 10	else CONST_HelpNavigateNum = 40 end	 --Number of hyperlinks to show in help page result (restrict to only 10 on very low resolutions)


		if (cache_addonLoaded) then
			--Stop loading if this has already been done
			self:VersionAnnounce(nil); --Announce our own version number to the world
			return nil;
		end--cache_addonLoaded

		--Set all the settings to default values if they don't exist
		if (IFTHEN_settings[SETTING_OnEvent] == nil)		then IFTHEN_settings[SETTING_OnEvent]		= true;	end	--OnEvent() feature enabled/disabled
		if (IFTHEN_settings[SETTING_ExtraSlash] == nil)		then IFTHEN_settings[SETTING_ExtraSlash]	= false;end	--ExtraSlash feature enabled/disabled
		if (IFTHEN_settings[SETTING_GetQuest] == nil)		then IFTHEN_settings[SETTING_GetQuest]		= true;	end	--GetQuest feature enabled/disabled
		if (IFTHEN_settings[SETTING_MacroRefresh] == nil)	then IFTHEN_settings[SETTING_MacroRefresh]	= false;end	--Says whether the Macro should automatically update the icon to that of the item/spell being used
		if (IFTHEN_settings[SETTING_Shift] == nil)			then IFTHEN_settings[SETTING_Shift]			= true;	end	--Shift/Alt clicking the macro will open window / reload UI
		if (IFTHEN_settings[SETTING_Spellcheck] == nil)		then IFTHEN_settings[SETTING_Spellcheck]	= false;end	--Use the spellcheck feature
		if (IFTHEN_settings[SETTING_Minimal] == nil)		then IFTHEN_settings[SETTING_Minimal]		= false;end	--Use the minimal feature
		if (IFTHEN_settings[SETTING_Color] == nil)			then IFTHEN_settings[SETTING_Color]			= true;end	--Use the syntax coloring feature
		if (IFTHEN_settings[SETTING_EasyCast] == nil)		then IFTHEN_settings[SETTING_EasyCast]		= false;end	--Use the easycast feature
		if (IFTHEN_settings[SETTING_LineNumber] == nil)		then IFTHEN_settings[SETTING_LineNumber]	= false;end	--Use the linenumber feature
		if (IFTHEN_settings[SETTING_Debug] == nil)			then IFTHEN_settings[SETTING_Debug]			= 0;	end	--Debugging enabled/disabled

		--Display upgrade message
		local updated = self:versionCheck(IFTHEN_text_version, IFTHEN_addon_version);
		if (updated) then IFTHEN_text_version = IFTHEN_addon_version; end

		--Check if the macro exists and if it dosent, then we create a new default one.
		if (Macro:exists() == false) then
			Macro:create();
			self:msg("Created a new IfThen macro. Use /macro to find it and place it on your toolbar");
		end

		--Register to receive addon messages from other clients
		local booRegister =  C_ChatInfo.RegisterAddonMessagePrefix(CONST_AddonPrefix);
		IFTHEN_frame:RegisterEvent("CHAT_MSG_ADDON");
		--Announce our own version number to the world
		self:VersionAnnounce(nil);

		--Save the reference to the frame we use with OnEvent (must do it here since the xml isn't loaded until after IfThen.lua)
		IFTHEN_frame_onevent = IfThenFrame_OnEvent;
		IFTHEN_frame_onevent_background = IfThenFrame_OnEvent_Background;

		--Often referenced frames/editboxes etc
		IFTHEN_frame_Edit_FilterBox	= IfThenXML_Edit_FilterBox;

		--Register for all the events that we can later use with OnEvent()
		--self:Toggle_OnEvent(true); --this is now handeled by self:ParseText()

		--Register for all the events that makes it possible to use MacroRefresh
		self:Toggle_MacroRefresh(true);

		--Enable Syntax coloring if thats enabled
		self:Toggle_Color(true);

		--Enable EasyCast if thats enabled
		self:Toggle_EasyCast(true);

		--Enable LineNumbers if thats enabled
		self:Toggle_LineNumber(true);

		--Add the slash command
		SLASH_IFTHEN1 = "/ifthen";
		SLASH_IFTHEN2 = "/ift";
		SlashCmdList["IFTHEN"] = function(cmd) return self:Slash(cmd) end;

		--Add the ifthen 'slash' event
		SLASH_IFTHENSLASH1 = "/ifthenslash";
		SLASH_IFTHENSLASH2 = "/ifs";
		SlashCmdList["IFTHENSLASH"] = function(cmd) return self:IFT_Slash(cmd) end;

		--Registers some extra but useful slash commands
		self:Toggle_ExtraSlash(true);

		--Show welcome message
		local strVersion = IFTHEN_addon_version;
		if (IFTHEN_addon_type ~= CONST_AddonFull) then strVersion = strVersion.." "..IFTHEN_addon_type end --append any BETA type it its there
		self:msg("IfThen loaded ("..strVersion.."). Use "..SLASH_IFTHEN1.. " or "..SLASH_IFTHEN2.." for more info.");
		if (IFTHEN_settings[SETTING_Debug]==1) then self:msg("    Debug is Enabled") end

		--Show extra debug info if its enabled
		--if (self:isDebug()) then self:debugInfo(); self:printBuildInfo(); end

		--Get colors to use in scrolllist
		local tmp = SyntaxColor:GetColors();
		cache_Color_Function = tmp["FUNC"];
		cache_Color_Variable = tmp["VAR"];

		--Force a reparse of the raw text
		self:ParseText(false);

		--Enable/Disable any hooks that we might use...
		self:ToggleHooks();

		--Post-hook into default chatframes
		hooksecurefunc("ChatFrame_OnHyperlinkShow", IfThen_ChatFrame_OnHyperlinkShow);

		--Hook into objective tracker (so user can click a quest/achievement title in the tracker and it gets inserted into the edit window.
		cache_ACHIEVEMENT_TRACKER_MODULE = ACHIEVEMENT_TRACKER_MODULE["OnBlockHeaderClick"];
		ACHIEVEMENT_TRACKER_MODULE["OnBlockHeaderClick"] = IfThen_ACHIEVEMENT_TRACKER_MODULE;
		--Using a post-hook on the quest details frame
		hooksecurefunc("QuestLogPopupDetailFrame_Show", IfThen_QuestLogPopupDetailFrame_Show);

		--We hook into the 'Deadly Boss Mods' addon if its available to improve the %BossName% variable.
		if (Methods["hook_DBM"] ~= nil) then
			Methods:hook_DBM();
			Methods["hook_DBM"] = nil; --Cleanup this function after it's been called.
		end

		--Trigger Proces_If so that any lines that might Refresh the macro icon will do so, so we don't display the placholder [?] icon
		--Parsing:Process_If();

		--Register with LibDataBroker
		if (LibStub ~= nil) then
			local lib = LibStub:GetLibrary("LibDataBroker-1.1"); --https://github.com/tekkub/libdatabroker-1-1/
			lib:NewDataObject("IfThen Edit", {type="launcher", icon="252184", tooltiptext="IfThen Edit", text="Edit", OnClick=function(clickedframe, button) IfThen:Edit_Open(); end} );
			lib:NewDataObject("IfThen Help", {type="launcher", icon="252184", tooltiptext="Ifthen Help", text="Help", OnClick=function(clickedframe, button) IfThen:Help_Open("argument"); end} );
		end --if LibStub

		--If Minimal feature is enabled then we strip away almost all the documentation
		if (IFTHEN_settings[SETTING_Minimal] == true) then
			Documentation:MinimizeDocStruct(true); --This method is removed by CleanUp()
		end

		cache_addonLoaded = true; --set flag so that this stuff is only done once
		if self["CleanUp"] ~= nil then
			self:CleanUp(); --remove all unused functions
			self["CleanUp"] = nil;
			self:collectGarbage(true);
		end--if CleanUp
		return nil;

	elseif (event=="CHAT_MSG_ADDON") then
		--Receive commands/requests from other clients with IfThen installed.
		--CHAT_MSG_ADDON("prefix", "message", "channel", "sender")
		local arrArgs	 = {...};
		local strPrefix  = strupper(arrArgs[1]);	--IFTHEN
		local strMessage = arrArgs[2];				--Format: "command:data1:data2..."
		local strChannel = strupper(arrArgs[3]);	--INSTANCE, GUILD, OFFICER, PARTY, RAID, WHISPER
		local strSender  = arrArgs[4];				--name of player that is sending the message

		local tonumber = tonumber;
		local tostring = tostring;
		local strlower = strlower;
		local strupper = strupper;

		--Supported Commands:
		--	announce-version:1:0:0:FULL/BETA		--announce the version you are running to everyone else (MAJOR:MINOR:REVISION:FULL/BETA)
		--	request-version:1:0:0:FULL/BETA			--request version number from anyone listening (they will reply with a whisper)

		if (strPrefix ~= CONST_AddonPrefix)			then return nil end --Only react to our own addon commands
		if (strSender == nil or strSender == "")	then return nil end --Verify that we got a player to send any reply to.
		if (Methods:playernameCompare(strSender, cache_playerName) == true) then return nil; end --Do not do anything if this is one of our own commands

		local strParts = StringParsing:split(strMessage, ":"); --Split into its command and dataparts
		if (strParts == nil or #strParts == 0) then return nil end

		local strCommand = strParts[1];
		if (strCommand == nil or strCommand == "") then return nil end
		strCommand = strtrim(strlower(strCommand));
		if (strCommand == "announce-version") then
			--Someone is announcing their version number. We can check it against our own number and also log if we are to do that.

			--Parse and vaildate incoming data...
			if (#strParts ~= 5) then return nil end --must be 5 arguments
			local strMaj, strMin, strRev, strTyp = strParts[2], strParts[3], strParts[4], strParts[5];
			if (strMaj==nil or strMaj=="" or strMin==nil or strMin=="" or strRev==nil or strRev=="" or strTyp==nil or strTyp=="") then return nil end
			local intMaj, intMin, intRev = tonumber(strMaj), tonumber(strMin), tonumber(strRev);
			if (intMaj==nil or intMaj < 0 or intMin==nil or intMin < 0 or intRev==nil or intRev < 0) then return nil end --We don't accept negative numbers

			local intTyp, intMyTyp = 0, 0; --We convert FULL/BETA into a number where FULL has the largest value
			if ( strtrim(strupper(tostring(strTyp)))== CONST_AddonFull) then intTyp   = 9 end --FULL is the largest (9), anything else remains a 0
			if ( strupper(IFTHEN_addon_type)		== CONST_AddonFull) then intMyTyp = 9 end

			--Construct a proper version number string
			local strNewVersion 	 = tostring(intMaj).."."..tostring(intMin).."."..tostring(intRev).." "..strTyp; --These are for display
			local strMyVersion       = IFTHEN_addon_version.." "..IFTHEN_addon_type;
			local strNewVersionShort = tostring(intTyp).."."..tostring(intMaj).."."..tostring(intMin).."."..tostring(intRev); --These two are for comparison (we prepend the FULL/BETA status as a number)
			local strMyVersionShort  = tostring(intMyTyp).."."..IFTHEN_addon_version;

			--Log in temp table if the table is not nil (if the table is nil then that means we are not to log)
			if (cache_versionTable ~= nil) then
				cache_versionTable[#cache_versionTable+1] = {strChannel, strSender, strNewVersion}; --channel, name and version number in an output friendly format
			end--if cache_versionTable

			--Check against our own version number
			if (cache_versionAnnounced == false) then
				local intIsOld = self:compareVersionNumber(strNewVersionShort, strMyVersionShort); -- 1==we are outdated, 0==equal, -1==we have newer

				if (intIsOld == 1 and intTyp == 9 and intTyp ~= intMyTyp) then
					--I have BETA, and you have FULL. Make sure that your version number isnt older than mine before we announce
					strNewVersionShort = tostring(intMaj).."."..tostring(intMin).."."..tostring(intRev); --Compare version numbers without BETA/FULL (intTyp) first
					strMyVersionShort  = IFTHEN_addon_version;
					intIsOld = self:compareVersionNumber(strNewVersionShort, strMyVersionShort); -- 1==we are outdated, 0==equal, -1==we have newer
					if (intIsOld == 0) then intIsOld = 1 end --I have BETA and you have FULL, but the version number is identical. We will announce it.
				end--

				--[[
					Truth table: A == announce, - == nothing
					you/ME			FULL	BETA
					newer full		A		A
					newer beta		-		A
					same full		-		A
					same beta		-		-
					older full		-		-
					older beta		-		-
				]]--

				if (intIsOld == 1) then
					--Set flag and show message in chat about us being outdated
					cache_versionAnnounced = true; --set flag to prevent flooding the user
					self:msg("A newer version of IfThen is available. You have version '"..strMyVersion.."' but now version '"..strNewVersion.."' is available. Get the new version online!");
				end--if intIsOld
			end--if cache_versionAnnounced

			return nil; --done

		elseif (strCommand == "request-version") then
			--Someone is requesting that everyone is announcing their version number to them
			if (strlower(strSender) == cache_playerName) then return nil end --Do not do anything if this is one of our own commands
			self:VersionAnnounce(strSender); --Send the reply directly to the requesting client and then we are done

			return nil; --done
		end--if strCommand

		return nil;

	elseif (event=="UNIT_SPELLCAST_SUCCEEDED" or event=="UNIT_SPELLCAST_STOP" or event=="UNIT_SPELLCAST_INTERRUPTED" or event=="UNIT_SPELLCAST_CHANNEL_STOP" or event=="PLAYER_EQUIPMENT_CHANGED") then
		--Calling Macro:refresh() in combat works, but its not needed so we use InCombatLockdown() as a filter to reduce the number of calls
		if (IFTHEN_settings[SETTING_MacroRefresh]==true and InCombatLockdown()==false) then Macro:refresh(Parsing:getCurrentMacroBlocks()); end
		return nil;

	elseif (event=="PLAYER_REGEN_ENABLED") then
		--Player edited and saved the raw text while in combat. Force a reparse of the raw text now that combat has ended
		s:UnregisterEvent("PLAYER_REGEN_ENABLED");
		self:ParseText(true);

	elseif(event=="ADDON_LOADED" and tostring(select(1,...)) == "Blizzard_AchievementUI") then
		--The 'Blizzard_AchievementUI' addon is not loaded until the user presses the 'Y' button to show it so we can't hook into until its loaded
		--s:UnregisterEvent("ADDON_LOADED");
		hooksecurefunc("AchievementButton_ToggleTracking", IFTHEN_AchievementButton_ToggleTracking);

	elseif(event=="ADDON_LOADED" and tostring(select(1,...)) == "DBM-Core" ) then
		--We hook into the 'Deadly Boss Mods' addon if its available to improve the %BossName% variable.
		--s:UnregisterEvent("ADDON_LOADED");
		if (Methods["hook_DBM"] ~= nil) then --Dont know if this has been loaded already or not.
			Methods:hook_DBM();
			Methods["hook_DBM"] = nil; --Cleanup this function after it's been called.
		end
	end

	--print("IfThen:OnEvent finished");
	return nil;
end


--Handles the events for the OnEvent feature
function IfThen:OnEvent_OnEvent(s, event, ...)
	--[[if (self:isDebug()) then
		print("IfThen==>Event '"..tostring(event).."'");
		local a = {...};
		local nA = #a;
		print("IfThen==>Arguments '"..tostring(nA).."'");
		print( self:array_to_string(a) );
		print("---------------------------------------");
	end]]--

	--Exit if OnEvent is disabled (redundant since we unregister the events if the feature is disabled)
	--if (IFTHEN_settings[SETTING_OnEvent] == false) then return nil end

	--Forward the event to Process: that will do its thing
	Parsing:Process_Event(event, ...);

	return nil;
end


--Handles any background events for the OnEvent feature
function IfThen:OnEvent_Background(s, event, ...)
	--Exit if OnEvent is disabled (redundant since we unregister the events if the feature is disabled)
	--if (IFTHEN_settings[SETTING_OnEvent] == false) then return nil end

	--Forward the event to Methods: that will do its thing
	Methods:BackgroundEvent(event, ...);
	return nil;
end


--OnEvent('Spellcheck'): Replaces any escaped strings in the list with our own replacements
function IfThen:ReplaceInChat(orgText)
	--Run the OnEvent(Spellcheck, Old, New) events to replace any string
	local newText = Methods:SpellCheck( tostring(orgText) );

	--We replace '%i' with the players, own, equipped itemlevel
	--local iLevel = Methods:getEquipmentItemLevel("",false);
	--if (iLevel ~= nil) then newText = StringParsing:replace(newText, "%i", tostring(iLevel["EquippedRounded"])); end
	--We replace '%g' with the players guildname
	--local guildName, guildRankName, guildRankIndex, realm = GetGuildInfo("player");
	--if (guildName ~= nil) then newText = StringParsing:replace(newText, "%g", tostring(guildName)); end

	return newText;
end


local TimeSinceLastVerReq		= 0;
local TimeSinceLastUpdate		= 0;
local TimeSinceLastClock		= 0;
local TimeSinceLastColor		= 0;
local TimeColorInterval			= 0.5; --Dynamically adjusted based on the time it takes to run SyntaxColor:ColorText()
local booTimeSinceLastUpdate	= false;
local booVersionRequest			= false; --Set/unset when requesting version number from other clients
local IFTHEN_CLOCK_Trigger		= false; --These are used to prevent further propagation of the code when these events are not in use (doing nothing is -really- efficient)
local IFTHEN_COLOR_Trigger		= false;
local IFTHEN_TICK_Trigger		= false;
local IFTHEN_TICK_Trigger_Bg	= false;
local IFTHEN_TIMER_Trigger_Bg	= false;
--Handles OnUpdate for the OnEvent feature
function IfThen:OnEvent_OnUpdate(s, elapsed)
	TimeSinceLastVerReq	= TimeSinceLastVerReq + elapsed;
	TimeSinceLastUpdate	= TimeSinceLastUpdate + elapsed;
	TimeSinceLastClock	= TimeSinceLastClock  + elapsed;
	TimeSinceLastColor	= TimeSinceLastColor  + elapsed; --increment update counters

	if (booTimeSinceLastUpdate) then return nil end --flag to prevent multiple runs of the same code while another is already running
	booTimeSinceLastUpdate = true;

	--We execute this on every game re-draw provided its needed
	if (IFTHEN_TIMER_Trigger_Bg) then Methods:BackgroundEvent("IFTHEN_TIMER") end   --Forward the event to Methods background event: that will do its thing

	if (TimeSinceLastUpdate >= 1) then --We only execute this code every 1 seconds
		--print("TimeSinceLastUpdate "..tostring(TimeSinceLastUpdate).." Elapsed "..tostring(elapsed));
		TimeSinceLastUpdate = 0; --Reset the counter
		if (IFTHEN_TICK_Trigger) then 		Parsing:Process_Event("IFTHEN_TICK") end	--Forward the event to Process: that will do its thing
		if (IFTHEN_TICK_Trigger_Bg) then	Methods:BackgroundEvent("IFTHEN_TICK") end	--Forward the event to Methods background event: that will do its thing
	end	--if

	if (TimeSinceLastClock > 30) then --We only execute this code every 30 seconds
		--print("TimeSinceLastClock "..tostring(TimeSinceLastClock).." Elapsed "..tostring(elapsed));
		TimeSinceLastClock = 0; --Reset the counter
		if (IFTHEN_CLOCK_Trigger) then 		Parsing:Process_Event("IFTHEN_CLOCK") end	--Forward the event to Process: that will do its thing
	end	--if

	if (TimeSinceLastColor >= TimeColorInterval) then --TimeColorInterval is dynamically adjusted by :Edit_ReColor() depending on how long SyntaxColor took to run.
		TimeSinceLastColor = 0;
		if (IFTHEN_COLOR_Trigger and cache_EditTextChangedFlag) then self:Edit_ReColor(); end --Blocking call...
	end --if

	if (TimeSinceLastVerReq > 3) then --We do the callback for VersionCheck after 3 seconds
		TimeSinceLastVerReq = 0;
		if (booVersionRequest) then self:VersionRequest_CallBack() end
	end	--if

	booTimeSinceLastUpdate = false; --Reset flag and free the method up for the next execution
	return nil;
end


local TimeSinceLastGC			= 0;
local booTimeSinceLastGCUpdate	= false;
--Handles OnUpdate for the OnGCEvent feature
function IfThen:OnEvent_OnGCUpdate(s, elapsed)
	TimeSinceLastGC		= TimeSinceLastGC + elapsed; --increment update counters

	if (booTimeSinceLastGCUpdate) then return nil end --flag to prevent multiple runs of the same code while another is already running
	booTimeSinceLastGCUpdate = true;

	if (TimeSinceLastGC > 30) then --We do a GC every 30 seconds
			TimeSinceLastGC = 0;
			self:collectGarbage(true);
	end	--if

	booTimeSinceLastGCUpdate = false; --Reset flag and free the method up for the next execution
	return nil;
end



--####################################################################################
--####################################################################################
--Version checking
--####################################################################################

--Announces the version number of the addon to everyone or a specific player
function IfThen:VersionAnnounce(strSender)
	--Announce our own version number to the world
	local booI, booP, booR, booG = Methods:InInstanceGroup(nil), Methods:InParty(nil), Methods:InRaid(nil), IsInGuild();

	local tonumber = tonumber; --local fpointer
	local tostring = tostring;

	local myVersion = StringParsing:split(IFTHEN_addon_version, ".");
	local myMaj, myMin, myRev, myTyp = tonumber(myVersion[1]), tonumber(myVersion[2]), tonumber(myVersion[3]), IFTHEN_addon_type;
	local strMessage = "announce-version:"..tostring(myMaj)..":"..tostring(myMin)..":"..tostring(myRev)..":"..myTyp;

	--We announce our version number in all the chat channels that we can
	if (strSender ~= nil and strSender ~= "") then
		SendAddonMessage(CONST_AddonPrefix, strMessage, "WHISPER", strSender);
	else
		--Make sure we don't announce versions to global channels too often, so we compare the timestamp when we last did an announce with the time now.
		if (cache_versionAnnounceLast ~= nil) then
			local d = difftime(time(), cache_versionAnnounceLast);
			if (d < CONST_VersionAnnounceMax) then return nil end --We dont announce if its less than max seconds since last time we did an announce
		end--if cache_versionAnnounceLast

		if (booG) then C_ChatInfo.SendAddonMessage(CONST_AddonPrefix, strMessage, "GUILD", nil); end
		if (booI) then C_ChatInfo.SendAddonMessage(CONST_AddonPrefix, strMessage, "INSTANCE_CHAT", nil); end
		if (booP) then C_ChatInfo.SendAddonMessage(CONST_AddonPrefix, strMessage, "PARTY", nil); end
		if (booR) then C_ChatInfo.SendAddonMessage(CONST_AddonPrefix, strMessage, "RAID", nil); end

		cache_versionAnnounceLast = time(); --log the time when we did the announcements
	end--if strSender
	return nil;
end


--Requests the version number from the party/raid/guild that we are in
function IfThen:VersionRequest()
	if (booVersionRequest) then
		self:msg("Still requesting data from other clients...");
		return nil;
	end --if we get a new request before the last one is done then skip this

	local tonumber = tonumber; --local fpointer
	local tostring = tostring;

	local myVersion = StringParsing:split(IFTHEN_addon_version, ".");
	local myMaj, myMin, myRev, myTyp = tonumber(myVersion[1]), tonumber(myVersion[2]), tonumber(myVersion[3]), IFTHEN_addon_type; --We do not support announcing beta's yet so we always return FULL
	local strMessage	= "request-version:"..tostring(myMaj)..":"..tostring(myMin)..":"..tostring(myRev)..":"..myTyp; --format: "command:data1:data2..."
	local strType		= ""; --INSTANCE, GUILD, OFFICER, PARTY, RAID

	local booI, booP, booR, booG = Methods:InInstanceGroup(nil), Methods:InParty(nil), Methods:InRaid(nil), IsInGuild();

	--We will request in one of these where guild is the lowest priority
	if (booG) then strType = "GUILD"; end
	if (booP) then strType = "PARTY"; end
	if (booR) then strType = "RAID"; end
	if (booI) then strType = "INSTANCE_CHAT"; end

	if (strType == "") then
		self:msg("Can not request version number from other clients when not grouped.");
		return nil;
	end--if strType

	self:msg("Requesting version number from other clients...");
	cache_versionTable = {}; --set table to an empty table so that it will start logging data
	SendAddonMessage(CONST_AddonPrefix, strMessage, strType, nil); --send the request...

	--Wait for N seconds...
	TimeSinceLastVerReq	= 0; 	--Reset the timer so that it starts counting from now
	booVersionRequest	= true;	--After N seconds IfThen:VersionRequest_CallBack() is called

	return nil;
end


--Handles the callback for the Version check feature
function IfThen:VersionRequest_CallBack()
	booVersionRequest = false; --Reset flag so that we are not called anymore
	local print = print; --local fpointer

	self:msg("You have version: "..IFTHEN_addon_version.." "..IFTHEN_addon_type..".");
	self:msg("Version numbers of other clients...");
	if (cache_versionTable == nil or #cache_versionTable == 0) then
		print("      No clients returned data.");
		print(" ");
		cache_versionTable = nil; --set to nil to stop logging data
		return nil;
	end

	print("  Found "..tostring(#cache_versionTable).." client(s)");
	for i=1, #cache_versionTable do
		--local strChannel, strSender, strVersion = cache_versionTable[i][1], cache_versionTable[i][2], cache_versionTable[i][3];
		local strSender, strVersion = cache_versionTable[i][2], cache_versionTable[i][3];
		print("      "..strSender.." - "..strVersion);
	end--for i
	print(" ");

	cache_versionTable = nil; --set to nil to stop logging data
	return nil;
end


--####################################################################################
--####################################################################################
--Raw text parsing and display
--####################################################################################

--Sends the raw text to be parsed
function IfThen:ParseText(display)
	if (display == true and not cache_changePage) then self:msg("Parsing raw text into a more efficient internal object structure"); end

	local b = false;
	if (InCombatLockdown()==false) then
		--Not in combat
		local defMacroName, defMacroPrefix, maxLen = Macro:getDefaultMacroValues();
		b = Parsing:ParseText(IFTHEN_text, IFTHEN_settings[SETTING_OnEvent], defMacroName, defMacroPrefix, maxLen);
		if (b == true) then
			local tbl = Parsing:getCurrentMacroBlocks();--Get list of MacroBlock names
			local boo = Macro:manageMacros(tbl);		--Pass list along to Macro that will create/delete any missing macros
		end
		--Output any errors that occurred during the parsing
		local strError = Parsing:ParseErrorPrint();
		if (strError ~= nil and not cache_changePage) then self:msg_error(strError); end

		self:Toggle_OnEvent(true); --Refresh the events that we listen for after we have reparsed the raw text
	else
		--If in combat then subscribe to event for end of combat and then reparse the text
		IFTHEN_frame:RegisterEvent("PLAYER_REGEN_ENABLED");
		if (display == true and not cache_changePage) then self:msg("You are currently in combat. Will parse text when combat ends"); end
	end--if

	return b;
end


--Returns the raw text from an array element
function IfThen:GetRawtextPage(intPage)
	local arr = IFTHEN_text;

	if (intPage >= 1 and intPage <= #arr) then
		return arr[intPage];
	elseif (intPage >= 1 and intPage <= #arr +1) then
		return ""; --index is +1 out of bounds, we allow that so that we can create new elements in the array
	else
		--intPage is outofbounds and we just print an error and return nil
		self:msg_error("Function tried to access raw text page that does not exits '"..tostring(intPage).."'");
		return nil;
	end
end


--Sets the raw text page to a new value
function IfThen:SetRawtextPage(RawText, intPage)
	local arr = IFTHEN_text;
	RawText = strtrim(RawText);

	local strlen  = strlen; --local fpointer
	local tinsert = tinsert;

	intPage = tonumber(intPage); --cast from string to int before we do comparisons
	if (intPage >= 1 and intPage <= #arr) then
		arr[intPage] = RawText; --overwrite
	else
		--the intPage is out of bounds for the existing array, and we append the raw text in a new page
		if (strlen(RawText) ~= 0) then tinsert(arr,RawText); end --ignore empty string pages at the end
	end

	--Remove any elements that are simply empty strings
	local arr2 = {};
	for i=1, #arr do
		if (strlen(arr[i]) >0) then tinsert(arr2,arr[i]) end
	end--for i

	IFTHEN_text = arr2;
	return true;
end


--Return the total number of pages in the array +1
function IfThen:GetRawtextPageNum()
	return (#IFTHEN_text +1); --We do +1 so that we support a new blank page at the end
end


--####################################################################################
--####################################################################################
--Slash, Macro, /ifs, IfScript, getQuest, ExtraSlash
--####################################################################################

--Handler for slash commands
function IfThen:Slash(cmd)
	cmd = strtrim(strlower(cmd)); --tweak the input string
	local n = "";

	if (StringParsing:startsWith(cmd, "edit")) then --edit <pagenumber> <linenumber>
		--Show the edit window
		local intPage = 1;   --always get the first page
		local intLine = nil; --line number
		local splits  = StringParsing:split(cmd," ");
		if (splits ~=nil and #splits >= 2) then
			intPage = tonumber(splits[2])
			if (#splits >= 3) then intLine = tonumber(splits[3]); end
		end

		self:Edit_Open(intPage, intLine);
		if (not cache_changePage) then n = n .. "Showing edit window..."; end

	elseif (StringParsing:startsWith(cmd, "morehelp")) then --morehelp <pagename> <search>
		--Show the morehelp window
		local title		= nil;
		local search	= nil;
		local splits	= StringParsing:split(cmd," ");
		if (splits ~= nil and #splits >= 2) then title  = strtrim(strlower(splits[2])); end
		if (splits ~= nil and #splits >= 3) then search = strtrim(strlower(splits[3])); end

		self:Help_Open(title, search);
		--n = n .. "Showing more help...";

	elseif (StringParsing:startsWith(cmd, "splitlink ") or StringParsing:startsWith(cmd, "linksplit ")) then
		--Output link info
		local print  = print; --local fpointer
		print("  Will now attempt to split the link into its base-parts (one part per line)...\n");
		local ff = cmd;
		ff = StringParsing:replace(ff, "splitlink ", "");
		ff = StringParsing:replace(ff, "linksplit ", "");
		ff = StringParsing:replace(ff, "|h|r", "");
		ff = StringParsing:replace(ff, "|c", "");
		ff = StringParsing:replace(ff, "|C", "");
		ff = StringParsing:replace(ff, "|r", "");
		ff = StringParsing:replace(ff, "|R", "");
		ff = StringParsing:replace(ff, "|H", ":");
		ff = StringParsing:replace(ff, "|h", ":");
		ff = strtrim(ff);
		local lst = StringParsing:split(ff, ":");
		if (lst == nil) then
			print("   Could not split the link that you passed in.");
			print("   Format: '/ifthen splitlink |cFFEABC32[link]|r'.");
		else
			print("   Result:");
			print("   ------------------------------");
			print("Raw:  '"..ff.."'")
			print("   ------------------------------");
			local tostring = tostring; --local fpointer
			for i=1, #lst do
				print("["..i.."]   "..tostring(lst[i]));
			end--for
			print("   ------------------------------");
		end--if nil
		print(" ");

	elseif (cmd == "refresh") then
		--Manually nil the timestamps so that we will reparse the text on the next call
		self:ParseText(true);

	elseif (cmd == "macro") then
		--Manually create a new default macro
		Macro:create();
		n = n .. "Macro created. Use /macro to view and drag the macro to your toolbar.";

	elseif (cmd == "spellcheck") then
		--Enabled/Disable Spellcheck
		local ln = self:HyperLink_Create("reload", "Click to reload");
		if (IFTHEN_settings[SETTING_Spellcheck] == false) then n = n .. "Spellcheck is now |cFFEABC32Enabled|r. You must do a /reload for it to take effect. ("..ln..")"; else n = n .. "Spellcheck is now |cFFEABC32Disabled|r. You must do a /reload for it to take effect. ("..ln..")"; end
		IFTHEN_settings[SETTING_Spellcheck] = not(IFTHEN_settings[SETTING_Spellcheck]);

	elseif (cmd == "minimal") then
		--Enabled/Disable Minimal
		local ln = self:HyperLink_Create("reload", "Click to reload");
		if (IFTHEN_settings[SETTING_Minimal] == false) then n = n .. "Minimal is now |cFFEABC32Enabled|r. You must do a /reload for it to take effect. ("..ln..")"; else n = n .. "Minimal is now |cFFEABC32Disabled|r. You must do a /reload for it to take effect. ("..ln..")"; end
		IFTHEN_settings[SETTING_Minimal] = not(IFTHEN_settings[SETTING_Minimal]);

	elseif (cmd == "color") then		--Enabled/Disable Syntax Coloring
		if (self:Toggle_Color(false)==true) then n=n.."Syntax coloring is now |cFFEABC32Enabled|r." else n=n.."Syntax coloring is now |cFFEABC32Disabled|r." end

	elseif (cmd == "easycast") then		--Enabled/Disable EasyCast
		if (self:Toggle_EasyCast(false)==true) then n=n.."EasyCast is now |cFFEABC32Enabled|r." else n=n.."EasyCast is now |cFFEABC32Disabled|r." end

	elseif (cmd == "linenumber") then	--Enabled/Disable LineNumbers
		if (self:Toggle_LineNumber(false)==true) then n=n.."Line numbers are now |cFFEABC32Enabled|r." else n=n.."Line numbers are now |cFFEABC32Disabled|r." end

	elseif (cmd == "onevent") then		--Enabled/Disable OnEvent()
		if (self:Toggle_OnEvent(false)==true) then n=n.."OnEvent() is now |cFFEABC32Enabled|r." else n=n.."OnEvent() is now |cFFEABC32Disabled|r." end
		self:ParseText(false); --Force a reparse. That will disable any OnEvent()'s background-events aswell

	elseif (cmd == "extraslash") then	--Enabled/Disable ExtraSlash
		if (self:Toggle_ExtraSlash(false)==true) then n=n.."ExtraSlash is now |cFFEABC32Enabled|r." else n=n.."ExtraSlash is now |cFFEABC32Disabled|r." end

	elseif (cmd == "getquest") then		--Enabled/Disable GetQuest
		if (IFTHEN_settings[SETTING_GetQuest] == false) then n = n .. "GetQuest is now |cFFEABC32Enabled|r."; else n = n .. "GetQuest is now |cFFEABC32Disabled|r."; end
		IFTHEN_settings[SETTING_GetQuest] = not(IFTHEN_settings[SETTING_GetQuest]);

	elseif (cmd == "macrorefresh") then		--Enabled/Disable MacroRefresh
		if (self:Toggle_MacroRefresh(false)==true) then n=n.."MacroRefresh is now |cFFEABC32Enabled|r." else n=n.."MacroRefresh is now |cFFEABC32Disabled|r." end

	elseif (cmd == "shift") then			--Enabled/Disable Shift
		if (IFTHEN_settings[SETTING_Shift] == false) then n = n .. "Shift is now |cFFEABC32Enabled|r."; else n = n .. "Shift is now |cFFEABC32Disabled|r."; end
		IFTHEN_settings[SETTING_Shift] = not(IFTHEN_settings[SETTING_Shift]);

	elseif (cmd == "version") then
		self:VersionRequest(); --will ask the other clients for their IfThen-version number
		return nil;

	elseif (cmd == "debug") then		--Enabled/Disable Debug
		if (IFTHEN_settings[SETTING_Debug] == 0) then
			IFTHEN_settings[SETTING_Debug] = 1; --we might in the future allow several values to determine a verbose level
			n = n .. "Debug is now |cFFEABC32Enabled|r.";
		else
			IFTHEN_settings[SETTING_Debug] = 0;
			n = n .. "Debug is now |cFFEABC32Disabled|r.";
		end

	else
		--Unknown command, just show help
		n = n .. "IfThen arguments :\n";
		n = n .. "  help                - Show this help message.\n";
		n = n .. "  edit <page>    - Show the main text window.\n";
		n = n .. "  morehelp        - Show the more help window.\n";
		n = n .. "  refresh            - Trigger a manual re-parsing of the text.\n";
		n = n .. "  macro             - Creates a new default macro for IfThen.\n";
		local en = "Enabled"; if (IFTHEN_settings[SETTING_Spellcheck]==false) then en="Disabled" end
		n = n .. "  spellcheck      - Enable/Disable Spellcheck feature. Currently |cFFEABC32"..en.."|r.\n";	--local link = " ("..self:HyperLink_Create("setting", "Click to toggle", "spellcheck")..")\n";
		local en = "Enabled"; if (IFTHEN_settings[SETTING_Minimal]==false) then en="Disabled" end
		n = n .. "  minimal          - Enable/Disable Minimal feature. Currently |cFFEABC32"..en.."|r.\n";
		local en = "Enabled"; if (IFTHEN_settings[SETTING_Color]==false) then en="Disabled" end
		n = n .. "  color               - Enable/Disable Syntax coloring feature. Currently |cFFEABC32"..en.."|r.\n";
		local en = "Enabled"; if (IFTHEN_settings[SETTING_EasyCast]==false) then en="Disabled" end
		n = n .. "  easycast         - Enable/Disable EasyCast feature. Currently |cFFEABC32"..en.."|r.\n";
		local en = "Enabled"; if (IFTHEN_settings[SETTING_LineNumber]==false) then en="Disabled" end
		n = n .. "  linenumber     - Enable/Disable Line numbers. Currently |cFFEABC32"..en.."|r.\n";
		local en = "Enabled"; if (IFTHEN_settings[SETTING_OnEvent]==false) then en="Disabled" end
		n = n .. "  onevent           - Enable/Disable OnEvent() feature. Currently |cFFEABC32"..en.."|r.\n";
		local en = "Enabled"; if (IFTHEN_settings[SETTING_ExtraSlash]==false) then en="Disabled" end
		n = n .. "  extraslash       - Enable/Disable ExtraSlash feature. Currently |cFFEABC32"..en.."|r.\n";
		local en = "Enabled"; if (IFTHEN_settings[SETTING_GetQuest]==false) then en="Disabled" end
		n = n .. "  getquest          - Enable/Disable GetQuest feature. Currently |cFFEABC32"..en.."|r.\n";
		local en = "Enabled"; if (IFTHEN_settings[SETTING_MacroRefresh]==false) then en="Disabled" end
		n = n .. "  macrorefresh  - Enable/Disable MacroRefresh feature. Currently |cFFEABC32"..en.."|r.\n";
		local en = "Enabled"; if (IFTHEN_settings[SETTING_Shift]==false) then en="Disabled" end
		n = n .. "  shift                - Enable/Disable Shift/Alt-Click macro feature. Currently |cFFEABC32"..en.."|r.\n";
		--local en = "Enabled"; if (IFTHEN_settings[SETTING_Debug]==0) then en="Disabled" end
		--n = n .. "  debug             - Enable/Disable Debug feature. Currently |cFFEABC32"..en.."|r.\n";
		n = n .. "  splitlink |cFFEABC32[link]|r  - Will take the |cFFEABC32[link]|r you pass in, and split it into its base parts. Use this to lookup link-id's.\n";
		n = n .. "  version           - Request the IfThen version number from players you are grouped with.\n";
		n = n .. " \n";
		n = n .. "ALT   + Click macro   - Reload the UI (/reload).\n";
		n = n .. "SHIFT + Click macro - Shows the main text window.\n";
		--print(n);
		local tt = StringParsing:split(n,"\n");
		local print = print; --local fpointer
		for i=1, #tt do --Calling print() for each line makes the output work better since the list is now so large that i cant be all seen even when the chat is maximized
			print(tt[i]);
		end--for i
		n = "";
	end

	if (strlen(n) >0) then self:msg(n) end
	return nil;
end


--Handler for ifthen slash manual event trigger
function IfThen:IFT_Slash(cmd)
	if (cmd == nil) then cmd = "" end	--prevent nil
	cmd = strtrim(strlower(cmd));		--tweak the input string

	if (strlen(cmd) == 0) then
		local n = 'Current slash events:\nCreate your own slash events by using OnEvent("Slash", "title"):\nThen use "/ifs <title>" or "/ifthenslash <title>" to trigger them.\n';
		local s = Parsing:getCurrentSlashList();

		if (s == nil) then
			n = n .. "\n  -|cFFEABC32no events found|r-";
		else
			local tostring = tostring; --local fpointer
			for i=1, #s do
				n = n .. "'|cFFEABC32"..tostring(s[i]).."|r' ";
			end--for i
		end--if s
		n = n .. "\n\n";
		if (strlen(n) >0) then self:msg(n) end
	else
		self:OnEvent_OnEvent(self, "IFTHEN_SLASH", cmd)	--call the event handler with the custom 'IFTHEN_SLASH' event
	end
	return nil;
end


--Handler for being triggered by macro
function IfThen:Macro()
	local macroName = Macro:getRunningMacroName();
	if (macroName == nil) then return nil; end

	local isDefault = false; --We only support getQuest and Shift on the default macro
	if (macroName == Macro:getDefaultMacroValues()) then isDefault = true; end

	--EasyCast cleanup?
	if (IFTHEN_settings[SETTING_EasyCast] and InCombatLockdown()==false and isDefault) then ClearOverrideBindings(IFTHEN_frame); end

	if (IFTHEN_settings[SETTING_Shift] and InCombatLockdown()==false and isDefault) then
		--Do /console reloadui if ALT is held down (and youre not in combat)
		if (IsAltKeyDown()==true) then
			ConsoleExec("reloadui");
			Macro:refresh(nil); --refresh the UI icon of the default macro only
			return nil;
		end

		--Show edit window if SHIFT is held down (and youre not in combat)
		if (IsShiftKeyDown()==true) then
			self:Edit_Open();
			return nil;
		end
	end --SETTING_Shift

	--process the text into actions
	Parsing:Process_If(macroName);

	--GetQuest feature?
	if (IFTHEN_settings[SETTING_GetQuest] and isDefault) then return self:getTheQuest(); end

	return nil;
end
--Short alias for IfThen:Macro()
function IFT()
	return IfThen:Macro();
end


--Shortcut that allows someone to quickly call a IfThen-method
function IfThen:Script(cmd,strArg)
	local tostring = tostring; --local fpointer
	cmd		= tostring(strlower(cmd));
	strArg	= Parsing:doEscaping(tostring(strArg), true);	--Do escaping on argument values
	local strMethod = cmd..'("'..strArg..'")';				--Format as a method
	self:msg(strMethod);
	local arrMethod = Parsing:parseMethod(strMethod);		--Array: {function pointer, argument table {}, function name as string, function type}

	if (arrMethod ~=nil) then return arrMethod[1](arrMethod[2]) end	--If we find the method then just call it and return its result back to the caller

	self:msg_error("Failed. Could not find the function named '"..tostring(cmd).."'.");
	return nil;	--If we didnt find the method then we return nil as opposed to false
end
--Short alias for IfThen:Script()
function IfScript(cmd,strArg)
	return IfThen:Script(cmd,strArg);
end


--Accept all quests from a targeted NPC
function IfThen:getTheQuest()
	--if (self:isDebug()) then print("IfThen:getTheQuest started") end
	--if (GetCVar("lockActionBars") == 0) then SetCVar("lockActionBars", 1) else SetCVar("lockActionBars", 0) end
	--Not all questgivers/deliveries uses a npc and this line would make the method now work with those
	--if (GetUnitName("target") == nil) then return nil end --no point in running this if we're not targeting something (hopefully an NPC questgiver)

	--Don't start anything if we are already channeling/casting a spell (like Fishing)
	local ch = UnitChannelInfo("player");
	local ca = UnitCastingInfo("player");
	--if (self:isDebug()) then print("    channeling: '"..tostring(ch).."' casting: '"..tostring(ca).."'") end
	if (ch~=nil or ca~=nil) then return nil end
	--if (self:isDebug()) then print("not channeling anything") end

	--[[
	/script SelectGossipActiveQuest(1)
	/script CompleteQuest()
	/script GetQuestReward(2)
	/script SelectGossipAvailableQuest(2)
	/script SelectGossipAvailableQuest(1)
	/script AcceptQuest()
	]]--

	--[[
	--Custom override for Stranglethorn Fishing Extravaganza
	if ( (Methods:InZone({"Booty Bay"}) == true) and (Methods:IsTargeted({"Riggle Bassbait"}) == true) ) then
		print ("Stranglethorn Fishing Extravaganza, picking reward 1");
		SelectGossipAvailableQuest(1);
		CompleteQuest();
		GetQuestReward(1); --Arcanite fishing pole
		return nil;
	end
	--Custom override for Kalu'ak Fishing Derby
	if ( (Methods:InZone({"Dalaran"}) == true) and (Methods:IsTargeted({"Elder Clearwater"}) == true) ) then
		print ("Kalu'ak Fishing Derby, picking reward 2");
		SelectGossipAvailableQuest(1);
		CompleteQuest();
		GetQuestReward(2); --Boots of the Bay
		return nil;
	end
	--Custom override for Scyers repeatable quest
	if (Methods:InZone({"Terrace of Light"}) == true) then
		SelectGossipAvailableQuest(1);
		CompleteQuest();
		GetQuestReward(nil);
		return nil;
	end
	--Custom override for Scyers repeatable quest
	if (Methods:InZone({"Scryer's Tier"}) == true) then
		SelectGossipAvailableQuest(3);
		CompleteQuest();
		GetQuestReward(nil);
		return nil;
	end]]--

	--Open Quests
	--------------------------------------------------------------
	local n = GetNumGossipAvailableQuests(); --Number of open quests
	AcceptQuest();	--Accept the quest
	if (n > 0) then
		SelectGossipAvailableQuest(1);				--Select the first  one in the list
		--This is the case of repeat deliver quests where there is no accept, just deliver
		CompleteQuest();							--Complete the quest
		local r = GetNumQuestChoices(); 			--Pickup the quest reward
		if (r == 0) then GetQuestReward(nil); end	--Quest without any choice in reward
		if (r == 1) then GetQuestReward(1); end
		--if (r > 1) then self:msg("====> Pick a reward!"); end
		return nil;
	end
	--------------------------------------------------------------

	--Deliver Quests
	--------------------------------------------------------------
	local n = GetNumGossipActiveQuests();			--Number of active quests
	if (n > 0) then SelectGossipActiveQuest(1) end; --Select the first one in the list
	CompleteQuest(); 								--Complete the quest
	local r = GetNumQuestChoices(); 				--Pickup the quest reward
	if (r == 0) then GetQuestReward(nil); end		--Quest without any choice in reward
	if (r == 1) then GetQuestReward(1); end
	if (r > 1) then
		--self:msg("====> Pick a reward !");
		--Custom overrides for known quests
		--if (Methods:InZone({"Argent Pavilion"})) then GetQuestReward(2) end --Quest's where its known what reward we want (Daily)
	end --if
	--------------------------------------------------------------

	--print("IfThen:getTheQuest finished");
	return nil;
end


--Event handler for the Extraslash feature
function IfThen:extraSlash(cmd)
	if (cmd == nil) then return nil; end

	cmd = strlower(cmd);
	if (cmd == "rolecheck")	then InitiateRolePoll();
	elseif (cmd == "rc")	then DoReadyCheck();
	else					self:msg("Extraslash: -Unknown command- '"..cmd.."'"); end
	return nil;
end


local EasyCastPrevClick = GetTime(); --Time when EasyCast_EventHandler() was last invoked. Used to determine double-click
--Event handler for the EasyCast feature
function IfThen:EasyCast_EventHandler(frame, button)
	--Return immediatly if its not rightclick, we're in combat or feature is disabled
	if (button ~= "RightButton" or InCombatLockdown() == true or IFTHEN_settings[SETTING_EasyCast] == false) then return nil; end

	local interval = GetTime() - EasyCastPrevClick; --Interval between this call and the previous one
	if (interval < CONST_MaxDoubleClickInterval) then --If the interval is small enough then we call it a double-click
		--if (UnitChannelInfo("player") ~=nil or UnitCastingInfo("player") ~=nil) then return nil; end --If we are currently channeling or casting something (like when fishing or mass ress) then skip
		if (IsMouselooking() == 1) then MouselookStop(); end --Turn off mouselook if its enabled
		--Source: http://www.wowwiki.com/SecureActionButtonTemplate
		--This is a protected function and it can't be called when in combat. EasyCast is therefore not possible when in combat.
		SetOverrideBindingMacro(IFTHEN_frame, true, "BUTTON2", "IfThen_Btn"); --Cleanup is done in IfThen:Macro();
	end--if

	EasyCastPrevClick = GetTime(); --Remember for next call
	return nil;
end


--####################################################################################
--####################################################################################
--Toggle features on/off
--####################################################################################

--Register/Unregister for an background event OnEvent() feature. Will return True when it has been registered
function IfThen:Register_BackgroundEvent(EventName, Register)
	local s = IFTHEN_frame_onevent_background;
	if (s==nil) then return false end

	if (StringParsing:startsWith(EventName, "IFTHEN_") == false) then s:UnregisterEvent(EventName); end
	if (EventName == "IFTHEN_TICK") then IFTHEN_TICK_Trigger_Bg = false end
	if (EventName == "IFTHEN_TIMER") then IFTHEN_TIMER_Trigger_Bg = false end

	if (Register == true) then
		if (StringParsing:startsWith(EventName, "IFTHEN_") == false) then s:RegisterEvent(EventName); end
		if (EventName == "IFTHEN_TICK") then IFTHEN_TICK_Trigger_Bg = true end --This event is raised by the OnEvent_OnUpdate() and we want to reduce its impact when not in use by having a local flag
		if (EventName == "IFTHEN_TIMER") then IFTHEN_TIMER_Trigger_Bg = true end --This event is raised by the OnEvent_OnUpdate() and we want to reduce its impact when not in use by having a local flag
		return true;
	end
	return false;
end


--Toggle OnEvent() feature. Will return True if its enabled
function IfThen:Toggle_OnEvent(refreshState)
	local s = IFTHEN_frame_onevent;
	if (s==nil) then return false end

	local c = not(IFTHEN_settings[SETTING_OnEvent]);
	if (refreshState == true) then c = not(c) end --We just want to refresh the state (used by :ParseText to refresh the events listened for)

	--Shorthand aliases for all the key's in the DocStruct
	local WOW = "wowevent"; --ingame event

	local evt = Parsing:getOnEventList();			--list of all events that OnEvent supports
	local curEvt = Parsing:getCurrentEventList();	--list of the few events that we need to listen for (has at least 1 line in the parsed structure associated with them)
	if (c == true) then
		--First unregister from ALL events,
		for i=1, #evt do
			if (StringParsing:startsWith(evt[i][WOW], "IFTHEN_") == false) then s:UnregisterEvent(evt[i][WOW]); end
		end --for
		IFTHEN_CLOCK_Trigger = false;
		IFTHEN_TICK_Trigger  = false;

		--Then we register to the few events that we need to listen for
		if (curEvt ~=nil) then
			for i=1, #curEvt do
				if (StringParsing:startsWith(curEvt[i][WOW], "IFTHEN_") == false) then s:RegisterEvent(curEvt[i][WOW]); end
				--This event is raised by the OnEvent_OnUpdate() and we want to reduce their impact when they are not in use by having a local flag
				if (curEvt[i][WOW] == "IFTHEN_CLOCK") then	IFTHEN_CLOCK_Trigger = true; TimeSinceLastClock  = 0; end
				if (curEvt[i][WOW] == "IFTHEN_TICK")  then	IFTHEN_TICK_Trigger  = true; TimeSinceLastUpdate = 0; end
			end --for
		end--if

	else
		--Unregister for ALL the events that we use with OnEvent()
		for i=1, #evt do
			if (not StringParsing:startsWith(evt[i][WOW], "IFTHEN_") == false) then s:UnregisterEvent(evt[i][WOW]); end
		end --for
		IFTHEN_CLOCK_Trigger = false;
		IFTHEN_TICK_Trigger  = false;
	end--if

	IFTHEN_settings[SETTING_OnEvent] = c;
	return c;
end


--Toggle ExtraSlash feature. Will return True if its enabled
function IfThen:Toggle_ExtraSlash(refreshState)
	local c = not(IFTHEN_settings[SETTING_ExtraSlash]);
	if (refreshState == true) then c = not(c) end --We just want to refresh the state (used at OnLoad to initally enable the feature)

	if (c == true) then
		--Register for the extra slash commands
		SLASH_ROLECHECK1 = "/rolecheck";
		SlashCmdList["ROLECHECK"] = function(cmd) return self:extraSlash("rolecheck") end;
		SLASH_RC1 = "/rc";
		SlashCmdList["RC"] = function(cmd) return self:extraSlash("rc") end;
		if (refreshState ~= true) then self:msg("ExtraSlash has been enabled. /rolecheck and /rc (readycheck) are now available."); end
	else
		local lnk = self:HyperLink_Create("reload", "Click to reload");
		if (refreshState ~= true) then self:msg("ExtraSlash has been disabled. Do a /reload for the commands to disappear. ("..lnk..")"); end
	end--if

	IFTHEN_settings[SETTING_ExtraSlash] = c;
	return c;
end


--Toggle MacroRefresh feature. Will return True if its enabled
function IfThen:Toggle_MacroRefresh(refreshState)
	local s = IFTHEN_frame;
	if (s==nil) then return false end

	local c = not(IFTHEN_settings[SETTING_MacroRefresh]);
	if (refreshState == true) then c = not(c) end --We just want to refresh the state (used at OnLoad to initally enable the feature)

	if (c == true) then
		--All these events will make us able to later refresh the macroicon
		s:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player"); --RegisterUnitEvent() should give better performance instead of RegisterEvent() since the filtering is then done in Blizzard C-code
		s:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player");
		s:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player");
		s:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player");
		s:RegisterUnitEvent("PLAYER_EQUIPMENT_CHANGED", "player");
	else
		--Unregister for the events
		s:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED");
		s:UnregisterEvent("UNIT_SPELLCAST_STOP");
		s:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED");
		s:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP");
		s:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED");
	end--if

	IFTHEN_settings[SETTING_MacroRefresh] = c;
	return c;
end


--Toggle Syntax coloring feature. Will return True if its enabled
function IfThen:Toggle_Color(refreshState)
	local c = not(IFTHEN_settings[SETTING_Color]);
	if (refreshState == true) then c = not(c) end --We just want to refresh the state (used at OnLoad to initally enable the feature)

	--If edit or help window is currently open, then close them before turning on/off coloring.
	if (IfThenXML_Edit_Frame:IsVisible() == true) then self:Edit_Close(); end
	if (IfThenXML_Help_Frame:IsVisible() == true) then self:Help_Close(); end

	if (c == true) then
		--Enable Syntax coloring
		local arrFunc, arrFuncN, arrVar = Documentation:getFullMethodListFunctionAndVariable();
		SyntaxColor:SetTables(arrFunc, arrFuncN, arrVar); --Set tables for known names of functions and enviroment variables.
		local func = function(n) return SyntaxColor:ColorText(n) end;
		Documentation:SetSyntaxColorFunction(func); --Pointer to the syntaxcolor function to use

	else
		--Disable Syntax coloring
		SyntaxColor:SetTables(nil, nil); --Clear tables to save memory
		Documentation:SetSyntaxColorFunction(nil);

	end--if
	--TimeColorInterval is recalculated every time Edit_ReColor() is run.
	--IFTHEN_COLOR_Trigger is set/unset when the frames are shown/closed

	--force a garbage collection
	self:collectGarbage();

	IFTHEN_settings[SETTING_Color] = c;
	return c;
end


--Toggle EasyCast feature. Will return True if its enabled
function IfThen:Toggle_EasyCast(refreshState)
	local c = not(IFTHEN_settings[SETTING_EasyCast]);
	if (refreshState == true) then c = not(c) end --We just want to refresh the state (used at OnLoad to initally enable the feature)

	if (c == true) then
		--Enable EasyCast
		if (cache_EasyCastHook == false) then --must remember this variable so that we wont create multiple hooks if the user turns the feature on/off several times
			local func = function(frame,button) return self:EasyCast_EventHandler(frame,button) end;
			WorldFrame:HookScript("OnMouseDown", func);
			cache_EasyCastHook = true;
		end
		if (refreshState ~= true) then self:msg("EasyCast has been enabled. Double right-clicking will now trigger the macro."); end
	else
		--Disable EasyCast
		--Need to do a /reload for the hook to be removed in code but it will no longer trigger
	end--if

	IFTHEN_settings[SETTING_EasyCast] = c;
	return c;
end


--Toggle LineNumber feature. Will return True if its enabled
function IfThen:Toggle_LineNumber(refreshState)
	local c = not(IFTHEN_settings[SETTING_LineNumber]);
	if (refreshState == true) then c = not(c) end --We just want to refresh the state (used at OnLoad to initally enable the feature)

	--If edit window is currently open, then close it first.
	if (IfThenXML_Edit_Frame:IsVisible() == true) then self:Edit_Close(); end
	local frm		= IfThenXML_Edit_SubFrame;
	local frmSub	= IfThenXML_Edit_ScrollFrame2;
	local intWidth	= 39; --Default offset X postision is 39px

	if (c == true) then
		--Enable Line numbers
		intWidth = 39; --Default offset X postision is 39px
		frmSub:SetPoint("RIGHT", frm, "TOPLEFT", intWidth, 0); --We adjust the RIGHT anchor width
	else
		--Disable Line numbers
		intWidth = 6; --Readjust to only 6px in width; effectivly hiding the linenumbers
	end--if

	--The edit form is now closed. its controls will be redrawn on the next call to Show().
	frmSub:SetPoint("RIGHT", frm, "TOPLEFT", intWidth, 0); --We adjust the RIGHT anchor width

	IFTHEN_settings[SETTING_LineNumber] = c;
	return c;
end


--####################################################################################
--####################################################################################
--Window Frame handling - Edit page
--####################################################################################

--Function to open the edit window
function IfThen:Edit_Open(intPage, intLine)
	--page : 1 or higher
	--line : nil or a number
	if (intPage == nil or type(intPage) ~= "number" or intPage < 1)	then intPage = 1; end							--must be a number between 1 and maxpages
	if (intPage > self:GetRawtextPageNum())							then intPage = self:GetRawtextPageNum(); end	--upperbound
	if (intLine == nil or type(intLine) ~= "number" or intLine < 1)	then intLine = nil; end							--must be nil or a number higher than 1

	--Is the help window open?
	if (IfThenXML_Help_Frame:IsVisible() == true) then self:Help_Close(); end --save and close window before showing the other one

	local frm = IfThenXML_Edit_Frame;
	if (frm:IsVisible() == true and (tonumber(IfThenXML_Edit_PageNum:GetText()) == intPage) and intLine == nil) then
		--Edit window currently open at the same page; close the window in that case.
		self:Edit_Close();
	else
		--Edit window is not open or the current shown page is not what we want...
		local txt = self:GetRawtextPage(intPage);

		--Change cursor position if line number is specified (:HighlightText() dosent work properly due to recolor etc)
		local intCursor = 0;
		if (intLine ~= nil and intLine > 1) then
			local strlen = strlen; --local fpointer
			local strsub = strsub;
			local currLine = 1;
			for i = 1, strlen(txt) do
				local char = strsub(txt,i,i);
				if (char == "\n") then
					currLine = currLine +1;
					if (currLine == intLine) then intCursor = i; break; end
				end--if
			end--for i
		end--if intLine

		local edt = IfThenXML_Edit_EditBox;
		edt:SetText(txt);					--Refresh text from memory
		edt:SetCursorPosition(intCursor);	--Set cursor position
		--edt:SetCursorPosition(edt:GetNumLetters()); --Set cursor position to the end of the text
		--src:SetVerticalScroll(0); --Reset the scrollbar to the top
		IfThenXML_Edit_PageNum:SetText(intPage);
		--if (IFTHEN_settings[SETTING_LineNumber] == true) then self:Edit_NumLinesChanged(edt, IfThenXML_Edit_LineNumberBox); end --Refresh linenumbers

		if (IFTHEN_settings[SETTING_Color] == true) then --Turn on color trigger if Syntax coloring is enabled
			self:Edit_ReColor();		--Manually trigger a recolor
			IFTHEN_COLOR_Trigger = true;--Every N seconds while the form is visible we will recolor the text
		else
			--If Syntax coloring is disabled, we still do a recolor if filtering is currently in use
			if (self:Edit_IsFiltering()) then self:Edit_ReColor(); end --Manually trigger a recolor
		end

		frm:Show();
		frm:Raise();
	end--if frm:IsVisible()
	return nil;--return intPage, intLine;
end


--Function for closing the edit window
function IfThen:Edit_Close()
	--Turn off color trigger when the form is not visible
	IFTHEN_COLOR_Trigger = false;

	--Get the pagenumber for this rawtext
	local strPage = IfThenXML_Edit_PageNum:GetText();

	--Get the text from the EditBox back into the variable and update timestamps
	local text = IfThenXML_Edit_EditBox:GetText();

	--Clear any colorstrings from the text
	text = SyntaxColor:ClearColor(text);

	--Update raw text in memory (note empty string pages will be ignored)
	self:SetRawtextPage(text, strPage);

	--Force a reparse of the raw text
	self:ParseText(true);

	--Set the frame to contain 0 characters to save memory.
	IfThenXML_Edit_EditBox:SetText("");
	IfThenXML_Edit_PageNum:SetText("-1");
	IfThenXML_Edit_LineNumberBox:SetText("");

	--Hide the window
	IfThenXML_Edit_Frame:Hide();

	--force a garbage collection
	self:collectGarbage();

	if (not cache_changePage) then self:msg("Text saved"); end
	return nil;
end


--Function to switch text page and update UI
function IfThen:Edit_ChangePage(direction)
	--Get the pagenumber for this rawtext
	local newPage = tonumber(IfThenXML_Edit_PageNum:GetText());
	if (newPage == nil) then return nil end

	if (direction == "previous") then newPage = newPage -1; else newPage = newPage +1; end
	if (newPage < 1 or newPage > self:GetRawtextPageNum()) then return nil; end --do nothing, we are at the first/last element

	cache_changePage = true; --flag to prevent verbose comments
	self:Edit_Close();		--close the window
	self:Edit_Open(newPage);--open the edit window again
	cache_changePage = false;

	return true;
end


--Event to Insert hyperlinks into edit box
function IfThen:Edit_InsertLink(text)
	if (text == nil) then return nil; end
	if (IfThenXML_Edit_Frame:IsVisible() == false) then return nil; end --If the edit frame is not visible then dont do anything

	text = tostring(text);
	local start, finish, value = strfind(text, '%[(.-)%]', 1); --Will either be an [itemlink] and we can then extract the text inside the [] or plain text
	if (start ~= nil) then text = value; end

	local edt = IfThenXML_Edit_EditBox;
	if (strlen(text) > 0 and edt:HasFocus() == true) then edt:Insert(text); end
	return nil;
end

	function IFTHEN_ChatEdit_InsertLink(text)
		return IfThen:Edit_InsertLink(text); --Link when shift-clicking items in bag, tradeskill, character window, bank, mount- pet- and toybox-list, etc.
	end
	hooksecurefunc("ChatEdit_InsertLink", IFTHEN_ChatEdit_InsertLink);
	function IFTHEN_AchievementButton_ToggleTracking(id)
		return IfThen:Edit_InsertLink(GetAchievementLink(id or 0)); --Link for the achivement in the achivement ui
	end
	--hooksecurefunc("AchievementButton_ToggleTracking", IFTHEN_AchievementButton_ToggleTracking); --The 'Blizzard_AchievementUI' addon is not loaded until the user presses the 'Y' button to show it so we cant hook into until its loaded

	--This hook makes us able to hook into the objective tracker (achievement & quest part)
	function IfThen_ACHIEVEMENT_TRACKER_MODULE(s, block, mouseButton)
		--Hook is done in IfThen:OnEvent()
		--Source: Blizzard_AchievementObjectiveTracker.lua
		local link = GetAchievementLink(block.id);
		IFTHEN_ChatEdit_InsertLink(link);
		--if (link ~= nil) then return nil; end --Skip calling original function if we have a link
		if (IfThenXML_Edit_Frame:IsVisible() == true) then return nil; end --If the edit frame is visible then skip the rest
		return cache_ACHIEVEMENT_TRACKER_MODULE(s, block, mouseButton); --Call original function
	end
	function IfThen_QuestLogPopupDetailFrame_Show(questLogIndex)
		--Hook is done in IfThen:OnEvent()
		--Post-hook on the questlog details frame.
		--Source: FrameXML\QuestMapFrame.lua
		if (QuestLogPopupDetailFrame:IsShown() == false) then return nil; end
		local link = GetQuestLink(questLogIndex);
		IFTHEN_ChatEdit_InsertLink(link);
		--disable this line or else it causes problems with other addons like LinksInChat...
		--if (link ~= nil) then QuestLogPopupDetailFrame:Hide(); end
		if (IfThenXML_Edit_Frame:IsVisible() == true) then QuestLogPopupDetailFrame:Hide(); end --If the edit frame is visible then skip the rest
	end


--Function to manual Recolor the text
function IfThen:Edit_ReColor()
	if cache_EditRecolorFlag then return nil end --prevents race conditions
	cache_EditRecolorFlag = true;

	--objEdit and objFilter are EditBox objects
	local objEdit		= IfThenXML_Edit_EditBox;
	local outputLabel	= IfThenXML_Edit_TextCount;
	local outputLabel2  = IfThenXML_Edit_FilterInfo;

	local intPos	= objEdit:GetCursorPosition();	--Current cursor position in the text: Using GetUTF8CursorPosition() seem to cause problems when typing non-english characters like ü and so on...
	local rawText	= objEdit:GetText();			--Get the full raw text
	local booFilter, newText, newPos, intRaw, intMatch, intMs = false,nil,nil,nil,nil,nil;
	if (self:Edit_IsFiltering()) then --If the filterbox is used then work from that
		booFilter = true;
		local filterText = IFTHEN_frame_Edit_FilterBox:GetText();
		newText, newPos, intRaw, intMatch, intMs = SyntaxColor:HighlightText(rawText, intPos, filterText); --Recolor the text (returns nil if its empty string)
		if (newText == nil and intRaw == nil) then
			--must strip away color before we calculate the rawText size since the text can be colored from before by syntax coloring
			rawText = SyntaxColor:ClearColor(rawText, intPos);
			intRaw = strlen(rawText);
		end
	else
		booFilter = false;
		newText, newPos, intRaw, intMs = SyntaxColor:ColorText(rawText, intPos); --Recolor the text (returns nil if its empty string)
	end --if IsFiltering()
	newPos	 = newPos	or 0; --New cursor position
	intRaw	 = intRaw	or 0; --Length of plain text before adding colortags, escapesequences, etc (the editbox doesn't count colortags towards the maxcharacters number)
	intMatch = intMatch or 0; --Number of matches found
	intMs	 = intMs 	or 0; --Time in milliseconds it took to run ColorText()

	--Re-adjust how many seconds to wait in between recoloring based on how long it took to run this time (that way it should reduce lag for the user)
	--						TimeColorInterval is used in OnEvent_OnUpdate()
	if		intMs > 50	then TimeColorInterval = 5; --If it took more than N ms then recolor only every C seconds
	elseif	intMs > 40	then TimeColorInterval = 4;
	elseif	intMs > 30	then TimeColorInterval = 3;
	elseif	intMs > 20  then TimeColorInterval = 2;
	else					TimeColorInterval = 0.5; --If it took less than N ms then recolor ever 0.5 seconds
	end
	--if (self:isDebug()) then print("SyntaxColor took "..tostring(StringParsing:numberFormat(intMs,3)).." ms. Interval set to "..tostring(TimeColorInterval).." sec"); end

	--Set the new text
	if (newText ~= nil) then
		objEdit:SetText(newText);
		objEdit:SetCursorPosition(newPos);--Must be called after SetText();
	end
	cache_EditTextChangedFlag = false; --Reset the flag set in Edit_TextChanged() when the user typed something

	local intMax = objEdit:GetMaxLetters();
	--Show warning that we are maxed out on characters
	if (intRaw >= intMax) then message("AAYou have reached the maximum number of characters ("..intRaw..") on this page."); end

	--outputLabel is a FontString
	if (booFilter) then
		if (newText == nil) then
			--Dont show anything if the string is too short to search for
			outputLabel:SetText(intRaw.."/"..intMax.." characters used");
			outputLabel2:SetText("");
		else
			outputLabel:SetText(intRaw.."/"..intMax.." characters used |cFF808080(found "..tostring(intMatch).." matches)|r"); --We add a gray number text shows the number of matches
			outputLabel2:SetText("(found |cFF00FF00"..tostring(intMatch).."|r matches)");
		end
	else
		outputLabel:SetText(intRaw.."/"..intMax.." characters used |cFF808080(refresh every "..tostring(TimeColorInterval).."sec)|r"); --We add a gray number text shows the refresh interval
		outputLabel2:SetText("");
	end

	cache_EditRecolorFlag = false;
	return nil;
end


--Event to refresh the counter
function IfThen:Edit_TextChanged(objEdit, userInput, outputLabel, objLine)
	--This method is only invoked if userInput == true. When :SetText() is used to change the text, userInput == false.

	if (userInput == true) then cache_EditTextChangedFlag = true; end --Used with syntax coloring. Is reset in Edit_ReColor()
	if (IFTHEN_settings[SETTING_LineNumber] == true) then self:Edit_NumLinesChanged(objEdit, objLine); end --Line numbering
	if (IFTHEN_settings[SETTING_Color] == true) then return nil; end --Textcount etc is done by Edit_ReColor() if Syntax coloring is enabled

	--objEdit is a EditBox
	local m = tonumber(objEdit:GetMaxLetters());
	local c = tonumber(objEdit:GetNumLetters());

	--Show warning that we are maxed out on characters
	if (c >= m) then message("You have reached the maximum number of characters ("..c..") on this page."); end

	--outputLabel is a FontString
	outputLabel:SetText(c.."/"..m.." characters used");
	return nil;
end


--Refresh linenumber editbox
function IfThen:Edit_NumLinesChanged(objEdit, objLine)
	--if (IFTHEN_settings[SETTING_LineNumber] ~= true) then return nil; end --Skip doing if linenumbers is not enabled

	--We add N number of lines in the raw text
	local res		= "";
	local txt		= objEdit:GetText(); --Raw text as it is from the editbox
	local arrText	= StringParsing:split(txt,"\n");
	if (arrText == nil) then
		res = "1"; --if emty string then assume 1 line
	else
		--Basically we use a Fontstring and use its width to determine wether a line of text spans multiple lines inside the editbox. If it does, we need to input some spaces before the next linenumber
		--Source: WowLua addon
		local w		= objEdit:GetWidth();
		local testW = 0;
		local objTest = IfThenXML_Edit_EditBox_LineTest; --Must refer directly to fontstring here. Fails otherwise

		for i = 1, #arrText do
			res	= res..i.."\n";
			--Incase the line spans several lines we need to add spaces
			objTest:SetText(arrText[i]);
			testW = objTest:GetWidth();
			if (testW >= w) then res = res..string.rep("\n", testW / w); end
		end--for i
		objTest:SetText("");
	end--if arrText

	objLine:SetText(res); --Output the linenumbers
	return nil;
end


--Filtering
function IfThen:Edit_IsFiltering()
	local t = IFTHEN_frame_Edit_FilterBox:GetText();
	local d = IFTHEN_frame_Edit_FilterBox:GetAttribute("defaultString");
	if (t == "" or t == d) then return false; end
	return true;
end
function IfThen:Edit_Filter(searchBox)
	if (IFTHEN_settings[SETTING_Color] == true) then
		return self:Edit_ReColor();		--Manually trigger a recolor, the function will detect wether to use filtering or not.
	else
		--If Syntax coloring is disabled, we still do a recolor if filtering is currently in use
		if (self:Edit_IsFiltering()) then
			return self:Edit_ReColor(); --Manually trigger a recolor
		else
			--Clear any textcolor
			local objEdit	= IfThenXML_Edit_EditBox;
			local intPos	= objEdit:GetCursorPosition();	--Current cursor position in the text
			local rawText	= objEdit:GetText();				--Get the full raw text
			local newText, newPos = SyntaxColor:ClearColor(rawText, intPos); --Clear any colorstrings from the text and return the new cursor position
			--Set the new text
			if (newText ~= nil) then
				objEdit:SetText(newText);
				objEdit:SetCursorPosition(newPos);--Must be called after SetText();
			end --if newText
			return nil;
		end --if IsFiltering
	end
end


--Search
function IfThen:Edit_Search(searchBox, outputBox)
	local text = strlower(strtrim(searchBox:GetText()));
	if (text == strlower(searchBox:GetAttribute("defaultString"))) then text = ""; end	--Ignore the default 'Search' text in the box

	local n = "";
	if (text ~= "") then
		--Filter the scrollText down to only those methods with with 'text' inside their methodnames
		local pairs   = pairs; --local fpointer
		local strfind = strfind;
		local tinsert = tinsert;

		--Edit frame: (we must search in ALL or the different scrolltext's)
		local scrollText = self:getScrollText("search"); --scrolltext is a table with key,{sign,type} here
		local tmp = {};

		for k,v in pairs(scrollText) do
			local intPos = strfind(k, text, 1, true); --Plain find, Will return nil if not found
			if (intPos ~= nil) then tinsert(tmp, v); end
		end--for
		sort(tmp); --Alphabetical Sort
		scrollText = tmp;

		--Display only N first matches
		local j = CONST_SearchResultLines; --Max N lines of text (usually 4 but if user got a screenwidth < 1280 it will be 2)
		if (j > #scrollText) then j = #scrollText; end

		for i=1, j do
			n = n..scrollText[i].."\n";
		end--for i
		n = strtrim(n);
	end --if scrollText

	outputBox:SetText(n);			--Populate the editBox with the short result
	outputBox:SetCursorPosition(0);	--Set cursor position to the start of the text

	return nil;
end


--####################################################################################
--####################################################################################
--Window Frame handling - Morehelp page
--####################################################################################

local booHelpIgnoreSearch = false; --Flag used to prevent extra calls when Help_Open() changes the searchbox

--Function to open the morehelp window
function IfThen:Help_Open(title, search)
	--title: string with name of page to show, defaults to 'syntax': settings, syntax, macrostart, argument, action, event, variable
	--search: empty string or a function name to filter for
	booHelpIgnoreSearch = true; --Set flag to prevent changes to IfThenXML_Help_SearchBox to call Help_Open() again
	cache_helpPageType = title;
	cache_helpPageOffset = 1; --reset

	if (title == nil 	or type(title) ~= "string")		then title = "syntax"; end	--defaults to 'syntax'
	if (search == nil	or type(search) ~= "string")	then search = ""; end		--defaults to empty string
	title	= strlower(title);
	search	= strlower(search);

	--Is the edit window open?
	if (IfThenXML_Edit_Frame:IsVisible() == true) then self:Edit_Close(); end --save and close window before showing the other one

	local frm		= IfThenXML_Help_Frame; --frm:Hide();
	local frmSearch = IfThenXML_Help_SearchBox;
	local frmSub	= IfThenXML_Help_SubFrameScroll;
	--local frmSrc	= IfThenXML_Help_ScrollFrameScroll;
	local edt    	= IfThenXML_Help_EditBox;

	if (title=="syntax" or title=="macrostart" or title=="settings") then
		--These do not use search, just a big editbox
		local helpText = self:getMoreHelpText(title);
		edt:SetText(helpText);
		edt:SetCursorPosition(0); --Set cursor position to the start of the text

		--Adjust IfThenXML_Help_SubFrameScroll
		local intWidth = 6; --Default offset X postision is 200px
		frmSub:SetPoint("BOTTOMRIGHT", frm, "BOTTOMLEFT", intWidth, 33); --We adjust the BOTTOMRIGHT anchor width visible
		frmSub:Hide(); --We Hide the whole subframe (if not then the scrollbar itself will be visible even after setting the width to 1px
		frmSearch:SetPoint("BOTTOMRIGHT", frm, "TOPLEFT", intWidth, -61); --We adjust the BOTTOMRIGHT anchor width visible
		frmSearch:Hide(); --We Hide the whole searchBox
		IfThenXML_Help_SubFrame:SetPoint("TOPLEFT", frm, "TOPLEFT", 14, -40); --If frmSearch is not visible we need to re-anchor the subframe to the parent frame or else it will not show

	else
		--These do use search
		local src = IfThenXML_Help_ScrollFrameList;
		src:SetMultiLine(true);
		src:SetIndentedWordWrap(false);
		src:EnableKeyboard(false);
		src:EnableMouseWheel(false);
		src:EnableMouse(true);


		--If we are switching between pages then we want to preserve search between them.
		if (search == "") then
			search = strlower(strtrim(frmSearch:GetText()));
			if (search == strlower(frmSearch:GetAttribute("defaultString"))) then search = ""; end	--Ignore the default 'Search' text in the box
		end
		local scrollText, first = self:Help_FormatSearchResult(search); --Get the finished formatted search result.

		if (scrollText ~= nil) then --is nil when frame is used with dump()
			local res = "";
			local intMax = 1 + CONST_HelpNavigateNum;
			if (intMax > #scrollText) then intMax = #scrollText; end --outofbounds

			if (search ~= "") then res = res.."Search '"..search.."'."; end
			if (#scrollText > intMax) then
				res = res.."\nShowing 1-"..intMax.. " of "..(#scrollText).." total.\nClick 'next' to see more...\n\n";
			else
				res = res.."\nShowing 1-"..intMax.. " of "..(#scrollText).." total.\n\n";
			end
			for i=1, intMax do
				res = res..scrollText[i].."\n";
			end--for

			src:SetText(res);
			src:SetCursorPosition(0); --Set cursor position to the start of the text
		end--if nil


		--All this must be done after src:AddMessage() orelse the hyperlinks are not clickable after you have gone from a page that has no scrollbar to one that has it shown (1. macrostart, 2. argument, 3. cant click hyperlinks unless you click 2. argument a second time in the UI)
		--Adjust IfThenXML_Help_SubFrameScroll
		local intWidth = 200; --Default offset X postision is 200px
		frmSub:SetPoint("BOTTOMRIGHT", frm, "BOTTOMLEFT", intWidth, 33); --We adjust the BOTTOMRIGHT anchor width visible
		frmSub:Show(); --Show the frame
		frmSearch:SetPoint("BOTTOMRIGHT", frm, "TOPLEFT", intWidth, -61); --We adjust the BOTTOMRIGHT anchor width visible
		frmSearch:Show();
		IfThenXML_Help_SubFrame:SetPoint("TOPLEFT", frmSearch, "TOPRIGHT", 2, 3); --If frmSearch is visible we anchor the left side of the subframe to align with that.
		--frmSrc:SetVerticalScroll(0); --Reset the Scrollbar itself to the top. Must be done after src:AddMessage() or you get weird behavior.

		if (search == "") then
			--Not a specific search, just display default helptext
			local helpText = self:getMoreHelpText(title);
			edt:SetText(helpText);
			edt:SetCursorPosition(0); --Set cursor position to the start of the text

		else
			local t = strlower(strtrim(frmSearch:GetText()));
			if (t == strlower(frmSearch:GetAttribute("defaultString"))) then t = ""; end	--Ignore the default 'Search' text in the box
			if (t ~= search) then frmSearch:SetText(search); end --Update the searchbox. That will in turn trigger Help_Search_OnTextChanged()
			--first contains the first match in the list
			if (first ~= nil and strlower(first) == search) then --is nil when frame is used with dump()
				self:Help_OnHyperlinkShow(nil, nil, first, nil); --If we got an atleast 1 match then show it directly in the mainbox
			else
				--no exact match found. show default text
				local helpText = self:getMoreHelpText(title);
				edt:SetText(helpText);
				edt:SetCursorPosition(0); --Set cursor position to the start of the text
			end--if first
		end--if search

	end--if

	frm:Show();
	frm:Raise();
	booHelpIgnoreSearch = false; --Reset flag
end


--Function for closing the morehelp window
function IfThen:Help_Close()
	--Set the frame to contain 0 characters to save memory.
	IfThenXML_Help_EditBox:SetText("");
	IfThenXML_Help_ScrollFrameList:SetText("");

	--Hide the window
	IfThenXML_Help_Frame:Hide();

	--force a garbage collection
	self:collectGarbage();
	return nil;
end


--Function to change the list of hyperlinks on the help page.
function IfThen:Help_Navigate(direction)
	local frmSearch = IfThenXML_Help_SearchBox;
	local src = IfThenXML_Help_ScrollFrameList;

	local search = strlower(strtrim(frmSearch:GetText()));
	if (search == strlower(frmSearch:GetAttribute("defaultString"))) then search = ""; end	--Ignore the default 'Search' text in the box
	local scrollText, first = self:Help_FormatSearchResult(search); --Get the finished formatted search result.

	if (direction == "previous") then
		cache_helpPageOffset = cache_helpPageOffset - CONST_HelpNavigateNum;
		if cache_helpPageOffset < 1 then cache_helpPageOffset = 1; end --outofbounds
	else
		cache_helpPageOffset = cache_helpPageOffset + CONST_HelpNavigateNum;
		if (cache_helpPageOffset > #scrollText) then cache_helpPageOffset = cache_helpPageOffset - CONST_HelpNavigateNum; end --outofbounds
	end
		local res = "";
		local intMax = cache_helpPageOffset + CONST_HelpNavigateNum;
		if (intMax > #scrollText) then intMax = #scrollText; end --outofbounds

		if (scrollText ~= nil) then --is nil when frame is used with dump()
			if (search ~= "") then res = res.."Search '"..search.."'."; end
			if (#scrollText > intMax) then
				res = res.."\nShowing "..cache_helpPageOffset.."-"..intMax.. " of "..(#scrollText).." total.\nClick 'next' to see more...\n\n";
			else
				res = res.."\nShowing "..cache_helpPageOffset.."-"..intMax.. " of "..(#scrollText).." total.\n\n";
			end
			for i=cache_helpPageOffset, intMax do --iterate in reverse so that the listing is the same as in the text
				res = res..scrollText[i].."\n";
			end--for

		end--if nil
		src:SetText(res);
		--src:SetCursorPosition(0); --Set cursor position to the start of the text

	return nil;
end

--Event handler for the scrolling list in Help window
function IfThen:Help_OnHyperlinkShow(s, link, text, button)
	local search = text;
	if (link ~= nil) then
		local strData = StringParsing:split(link,":");
		search = strData[2];
	end--if

	local strText = Documentation:printMethod(search, cache_helpPageType); --cache_helpPageType has the value 'argument, action, event or variable
	if (IFTHEN_settings[SETTING_Minimal] == true) then strText=strText.."\n\n\n  |cffc0c0c0The 'Minimal' feature is Enabled. Disable it to see more information.|r"; end --Show extra infotext if the Minimal feature is enabled.
	strText = "\n\n"..strText.."\n";

	local edt = IfThenXML_Help_EditBox;
	edt:SetText(strText);
	edt:SetCursorPosition(0);
	return nil;
end


function IfThen:Help_FormatSearchResult(text)
	--Help frame, we use cache_helpPageType to determine what data to search in
		--cache_helpPageType has the value 'argument', 'action', 'event' or 'variable'
	local scrollText = self:getScrollText(cache_helpPageType);
	if (scrollText == nil) then return nil; end

	if (text == "") then
		--Show full list; no filtering
	else
		--Filter the scrollText down to only those with 'text' inside it
		local strlower = strlower; --local fpointer
		local strfind  = strfind;
		local tinsert  = tinsert;

		local tmp = {};
		for i=1, #scrollText do
			local strTitle	= strlower(scrollText[i]);
			local intPos	= strfind(strTitle, text, 1, true); --Plain find, Will return nil if not found
			if (intPos ~= nil) then tinsert(tmp, scrollText[i]); end
		end--for
		scrollText = tmp;
	end

	--Populate the scrollframe with the result...
	local strlen = strlen; --local fpointer
	local strsub = strsub;
	local strCol = cache_Color_Function; --Blue for most things
	if (cache_helpPageType == "variable") then strCol = cache_Color_Variable; end --Variable color

	--Format result for the Help Search scrollframe...
	local tmp, first = {}, "";
	for i=1, #scrollText do
		if (i == 1) then first = scrollText[i]; end
		local strKey	= scrollText[i];
		local strTitle	= scrollText[i];
		if (strlen(strTitle) > 19) then strTitle = strsub(strTitle, 1, 16) .."..."; end --if the string is bigger than 18 chars then put a ... at the end
		local strRes = strCol.."|Hplayer:"..strKey.."|h>"..strTitle.."|h|r";			--max 19 characters in length -- XXOOXXOOXXOOXXOOXXO
		tinsert(tmp, strRes);
	end--for
	return tmp, first; --Cant re-insert and reuse scrollText-table. When we do it will do some funky stuff with the result
end


function IfThen:Help_Search_OnTextChanged(searchBox, outputBox)
	if (booHelpIgnoreSearch == true) then return nil; end --Flag used to prevent extra calls when Help_Open() changes the searchbox
	local text = strlower(strtrim(searchBox:GetText()));
	if (text == strlower(searchBox:GetAttribute("defaultString"))) then text = ""; end	--Ignore the default 'Search' text in the box

	self:Help_Open(cache_helpPageType, text);
	return nil;
end


function IfThen:Help_SearchClear(searchBox, clearButton)
	--We call this this function in the OnEscapePressed event of the searchbox
	local text = strlower(strtrim(searchBox:GetText()));
	if (text == "" or text == strlower(searchBox:GetAttribute("defaultString"))) then return nil; end --Box is already cleared
	clearButton:Click();
	return nil;
end


--####################################################################################
--####################################################################################
--Window Frame handling - Common
--####################################################################################

--Toggle a frame between being frontmost or behind any other frames that the user clicks on
function IfThen:ToggleFrameStrata(s, forceFront)
	--if true then return nil end

	if forceFront then
		--Frame has recived manual focus (mouseclick) and needs to be put topmost
		s:SetFrameStrata("HIGH");
		s:SetToplevel(true);
	else
		--Regular polling called from OnUpdate() to whether we shall change focus or not
		if (IsMouseButtonDown() == false) then return nil end		--if the mouse button is not pressed down, then skip the rest
		local objMouseFrame		= GetMouseFocus();				--get the name of the frame that the mouse is currently focusing on...
		if (objMouseFrame == nil or objMouseFrame["GetFrameStrata"] == nil) then return nil end			--GetMouseFocus will some cases return nil
		local strMouseStrata	= objMouseFrame:GetFrameStrata() or "BACKGROUND";	--keep the frame's strata until later...
		local strMainFrame		= s:GetName();

		repeat				--We do a loop where each element and their parent(s) is checked and we see if that eventually matches our frame,
			if (objMouseFrame ~= nil) then
				if (objMouseFrame:GetName() == strMainFrame) then return nil end --if we find our mainform then we skip the rest
			end--if
			objMouseFrame = objMouseFrame:GetParent();
		until (objMouseFrame == nil)

		--If we get down here then then:
		--			1. A mouse button is pressed down
		--			2. None of the controls on the frame is selected
		--We set the frame's strata to the lowest we can...

		--We set the frame's strata to that level just below what the mouse is focused on...
		if 	   strMouseStrata=="TOOLTIP"			then strMouseStrata="FULLSCREEN_DIALOG"
		elseif strMouseStrata=="FULLSCREEN_DIALOG"	then strMouseStrata="FULLSCREEN"
		elseif strMouseStrata=="FULLSCREEN"			then strMouseStrata="DIALOG"
		elseif strMouseStrata=="DIALOG"				then strMouseStrata="HIGH"
		elseif strMouseStrata=="HIGH"				then strMouseStrata="MEDIUM"
		elseif strMouseStrata=="MEDIUM"				then strMouseStrata="LOW"
		elseif strMouseStrata=="LOW"				then strMouseStrata="BACKGROUND"
		else										     strMouseStrata="BACKGROUND"
		end--if

		s:SetFrameStrata(strMouseStrata);
		s:SetToplevel(false);
	end

	return nil;
end


--Copy of the SearchBoxTemplate_OnLoad() functions from UIPanelTemplates.lua
function IfThen:FilterBoxTemplate_OnLoad(s)
	s:SetText(s:GetAttribute("defaultString"));
	s:SetFontObject("GameFontDisable");
	s.searchIcon:SetVertexColor(0.6, 0.6, 0.6);
	s:SetTextInsets(16, 20, 0, 0);
end
function IfThen:FilterBoxTemplate_OnEditFocusLost(s)
	s:HighlightText(0, 0);
	s:SetFontObject("GameFontDisable");
	s.searchIcon:SetVertexColor(0.6, 0.6, 0.6);
	if ( s:GetText() == "" or s:GetText() == s:GetAttribute("defaultString") ) then
		s:SetText(s:GetAttribute("defaultString"));
		s.clearButton:Hide();
	end
end
function IfThen:FilterBoxTemplate_OnEditFocusGained(s)
	s:HighlightText();
	s:SetFontObject("ChatFontSmall");
	s.searchIcon:SetVertexColor(1.0, 1.0, 1.0);
	if ( s:GetText() == s:GetAttribute("defaultString")	) then
		s:SetText("")
	end
	s.clearButton:Show();
end


--####################################################################################
--####################################################################################
--Window Frame handling - Settings window
--####################################################################################

--Settings frame
function IfThen:SettingsFrame_OnLoad(panel, title)
	local t = "";
	if (IFTHEN_addon_type ~= CONST_AddonFull) then t = IFTHEN_addon_type; end --Only show if its 'BETA' or something like that.
	title:SetText("IfThen "..tostring(IFTHEN_addon_version).." "..t); --<FontString> containing the title & version number

	-- Set the name of the Panel
	panel.name = "IfThen";

	--We dont use any of these since settings are set/unset directly when the user uses the checkboxes.
	--panel.okay	= function (self) IfThen:SettingsFrame_Ok(); end;
	--panel.cancel	= function (self) IfThen:SettingsFrame_Cancel(); end;
	panel.default	= function (self) IfThen:SettingsFrame_Default(); end;
	--panel.refresh	= function (self) IfThen:SettingsFrame_Refresh(); end;

	--Add the panel to the Interface Options
	InterfaceOptions_AddCategory(panel);
end
function IfThen:SettingsFrame_Default()
	self:msg("Resetting and reloading user interface..");
	IFTHEN_settings = {};	--Clear settings data for the whole Addon.
	ConsoleExec("reloadui");--Reload the UI so that the Addon will create default settings.
end


--####################################################################################
--####################################################################################
--Custom hyperlink handling
--####################################################################################

--Returns a ifthen: hyperlink in the correct format
function IfThen:HyperLink_Create(command, title, ...)
	--Format: |cFF000000|Hifthen:command:data1:data2:data3|h[title]|h|r
	local tostring	= tostring; --local fpointer
	local select	= select;

	command	= strlower(strtrim(tostring(command)));
	title	= tostring(title); --must manually add [ ] if you want that as part of the title

	--local tblColor = {["default"]="EABC32", ["edit"]="FF0000", ["morehelp"]="FF8000", ["setting"]="FF0000", ["reload"]="FF0000"}; --custom colors for different commands
	local color = cache_Color_HyperLinks;
	--if (tblColor[command] == nil) then color = tblColor["default"]; else color = tblColor[command]; end --set a color

	local data = "";
	if (select("#", ...) > 0) then
		for i = 1, select("#", ...) do
			if (i == 1) then data = tostring(select(i, ...)); --dont prepend : for the first value
			else 			 data = data..":"..tostring(select(i, ...)); end
		end--for i
	end--if

	local res = "|cFF@COLOR@|Hifthen:@COMMAND@:@DATA@|h@TITLE@|h|r";
	res = StringParsing:replace(res, "@COLOR@", color);
	res = StringParsing:replace(res, "@COMMAND@", command);
	res = StringParsing:replace(res, "@DATA@", data);
	res = StringParsing:replace(res, "@TITLE@", title);
	return res;
end


--Event handler for hyperlinks in chat
function IfThen:HyperLink_EventHandler(link, text, button)
	--print("HyperLink_EventHandler: link '"..tostring(link).."' text '"..tostring(text).."' button '"..tostring(button).."'");
	local lnkData = StringParsing:split(link,":"); --format: ifthen:command:data1,data2,data3...
	if (lnkData == nil) then return nil; end
	local command = lnkData[2];

	if		command == "edit" then
		local intPage = tonumber(lnkData[3]);
		local intLine = tonumber(lnkData[4]);
		self:Edit_Open(intPage, intLine); --Open edit window at the given page and linenumber

	elseif	command == "morehelp" then
		local strPage	= tostring(lnkData[3]);
		local strSearch	= tostring(lnkData[4]);
		self:Help_Open(strPage, strSearch); --Open morehelp window at the given page and show result for the search

	--[[elseif	command == "setting" then
		local strSetting = tostring(lnkData[3]);
		self:Slash(strSetting); --Toggle the specified setting value--]]

	elseif	command == "reload" then
		ConsoleExec("reloadui");--Reload the UI

	elseif	command == "playaudio" then
		local strAudio = tostring(lnkData[3]);
		Methods:do_PlayAudio({strAudio}); --Play the specified audio
		print(strAudio);

	end--if command
	return nil;
end


--####################################################################################
--####################################################################################
--Large size text functions
--####################################################################################

--Returns an simple array of function names
function IfThen:getScrollText(title)
	if (cache_getScrollText ~= nil and cache_getScrollText[title] ~= nil) then return cache_getScrollText[title] end --return from cache if its already been created

	if (cache_getScrollText == nil) then cache_getScrollText = {}; end
	--cache_getScrollText["syntax"]	= nil;
	if (title == "argument"	and cache_getScrollText["argument"]	== nil) then cache_getScrollText["argument"]= Documentation:getSimpleMethodList("argument");end
	if (title == "action"	and cache_getScrollText["action"]	== nil) then cache_getScrollText["action"]	= Documentation:getSimpleMethodList("action");	end
	if (title == "event"	and cache_getScrollText["event"]	== nil) then cache_getScrollText["event"]	= Documentation:getSimpleMethodList("event");	end
	if (title == "variable"	and cache_getScrollText["variable"]	== nil) then cache_getScrollText["variable"]= Documentation:getSimpleMethodList("variable");end
	if (title == "search"	and cache_getScrollText["search"]	== nil) then
		--local func = function(strType, tmpKey, tmpValue) return self:HyperLink_Create("morehelp", tmpValue, strType, tmpKey) end; --Formatting function will make the titles into ifthen:hyperlinks
		--Formatting function will make the titles into ifthen:hyperlinks without the color
		local func = function(strType, tmpKey, tmpValue) return StringParsing:replace(StringParsing:replace(self:HyperLink_Create("morehelp", tmpValue, strType, tmpKey), "|cFF"..cache_Color_HyperLinks.."|H", "|H"), "|h|r", "|h") end;
		cache_getScrollText["search"] = Documentation:getFullMethodList(func);
	end --Used with search in the Edit frame. Table with methodname as key and method signatures as value

	self:collectGarbage();
	return cache_getScrollText[title];
end


--Returns a properly formatted string used to display help
function IfThen:getMoreHelpText(title)
	if (cache_getMoreHelpText ~= nil and cache_getMoreHelpText[title] ~= nil) then return cache_getMoreHelpText[title] end --return from cache if its already been created
	if (self["getMoreHelpText_Declare"] ~= nil) then return self:getMoreHelpText_Declare(title); end --declare the text and store it in cache
	return "";
end
function IfThen:getMoreHelpText_Declare(title)

	if (IFTHEN_settings[SETTING_Minimal] == true) then
		local n		= "\n\n\n  |cffc0c0c0The 'Minimal' feature is Enabled. Disable it to see more information.|r"; --Show only infotext if the Minimal feature is enabled.
		local n2	= "\n\n\n<== Click on a function name to show its documentation."..n;
		cache_getMoreHelpText = {};
		cache_getMoreHelpText["settings"]	= "\n\nSettings:"..n;
		cache_getMoreHelpText["syntax"]		= "\n\nSyntax:"..n;
		cache_getMoreHelpText["macrostart"]	= "\n\nMacroStart:"..n;
		cache_getMoreHelpText["argument"]	= n2;
		cache_getMoreHelpText["action"]		= n2;
		cache_getMoreHelpText["event"]		= n2;
		cache_getMoreHelpText["variable"]	= "\n\n\n<== Click on a variable name to show its documentation."..n;
		return cache_getMoreHelpText[title];
	end--if


	local tmpColor	= SyntaxColor:GetColors();
	local tmpColor2	= Documentation:GetColors();
	local colRed	= "|cFFC30000"; -- red for keywords and statements

	--General syntax
	local n = "";
	n = n .. "\n\nLines starts with {IF} and ends with {;} (semicolon).\n";
	n = n .. "{AND} / {OR} separates each argument that must evaluate to true.\n";
	n = n .. "{THEN} separates the arguments and the action(s) to be done.\n\n";
	n = n .. "    {IF [argument] AND [argument] OR [argument] AND ... THEN [action] AND [action] ;}\n\n";
	n = n .. "{NOT} can be put before an argument to negate the result.\n\n";
	n = n .. "    {IF HaveEquipped(\"Fishing Pole\") AND NOT IsFlying() THEN Cast(\"Fishing\") ;}\n\n";
	n = n .. "Comments starts with {#} and ends with {;} (semicolon).\n\n";
	n = n .. "    {# This is a comment ;}\n\n";
	n = n .. "Lines that trigger on events starts with {OnEvent(\"\")} instead of {IF}, and ends with {;} (semicolon)\n\n";
	n = n .. "    {OnEvent(\"Dead\") AND InRaid() THEN Chat(\"Raid\",\"I am dead\") ;}\n\n";
	n = n .. "Lines are evaluated from top to bottom and the first one where all the arguments evaluate to true will be processed, and the rest will be ignored.\n\n";
	n = n .. "Hyperlinks can be indicated by using {[} and {]} in text arguments in these ways: {[type:title]} or {[type:id:title]} (type={{item,spell,achievement,currency,trade,instance,battlepet,talent}).\n";
	n = n .. "Due to ingame limitations not all text-links might work. For example {[spell:Time Warp]} (text) will not work on non-mage characters, but {[spell:80353:Time Warp]} will.\n";
	n = n .. "You can use websites like www.wowhead.com to lookup id numbers for spells, items and other stuff, just do a search and you'll see the id in the url.\n\n";
	n = n .. "    {OnEvent(\"Chat\",\"Whisper\") AND HaveEquipped(\"Fishing Pole\") THEN Reply(\"Don't bother me while i work on my [achievement:Accomplished Angler] achievement\") ;}\n\n";
	n = n .. "We also support variables like {%playerName%}, {%targetName%}, {%frameRate%} and many others. See the 'Variables' section of '/ifthen morehelp'.\n\n";
	n = n .. "Character escaping is supported by using \\ in front of the escaped characters: \\ % ( ) \" , ;\n\n";
	n = n .. "Technical restrictions makes it impossible to do more than one UseItem(), Cast(), CancelAura() or CancelForm() per line. These must also be the last action used on a line.\n";
	n = n .. "Combining OnEvent() with UseItem(), Cast() etc is also not possible because of technical restrictions (can only do a single /use, /cast etc with a buttonpress).\n\n";
	n = n .. "If you are in combat then the processing will also not work if the line has Cast(), UseItem() etc. This is because the addon needs to rewrite the macro and that is not allowed when you are in combat.\n";
	n = n .. "Beyond these few actions, then all the other actions work both in and out of combat.\n\n";
	n = n .. "If you need to just use a single function, you can also call a methods directly from your macro by using "..'"'.."/run IfScript('MethodName','ArgumentString');"..'"'.." from a macro.\n";
	n = n .. "(Notice that the arguments are all wrapped in a string)\n\n";
	n = n .. "Required arguments are written in |cFFEBB81FYellow|r, and optional arguments are in |cFF806EC5Purple|r in the documentation.";
	n = StringParsing:replace(n, "{{",	tmpColor2["VAL"]); --teal for OnEvent() arguments
	n = StringParsing:replace(n, "{",	colRed); -- red for keywords and statements
	n = StringParsing:replace(n, "}", "|r");

	--MacroStart
	local n5 = "";
	n5 = n5 .. "\n\nNormally all IF-statements change the behavior of a single, default macro.\n";
	n5 = n5 .. "By using MacroStart() you can create groups of IF-statements that are executed in separate macros (think of it like functions).\n\n";
	n5 = n5 .. "Example:\n\n";
	n5 = n5 .. "    {#These lines will be executed when pressing the default IfThen Macro ;}\n";
	n5 = n5 .. "    {IF HaveEquipped(\"Fishing Pole\") AND IsPVP() THEN Message(\"PVP with a Fishing Pole?!?\") ;}\n";
	n5 = n5 .. "    {IF HaveEquipped(\"Fishing Pole\") AND NOT IsFlying() THEN Cast(\"Fishing\") ;}\n\n";
	n5 = n5 .. "    MacroStart(\"{{MyMacro}\");\n";
	n5 = n5 .. "        {#These lines will be only be executed when using the macro called 'IfThen_MyMacro' ;}\n";
	n5 = n5 .. "        {IF IsDead(\"target\") AND IsTapped(\"target\") THEN UseItem(\"Loot-A-Rang\"); ;}\n";
	n5 = n5 .. "        {IF NOT IsDead(\"target\") AND IsTapped(\"target\") THEN Print(\"He's not dead yet!\"); ;}\n";
	n5 = n5 .. "    MacroEnd();\n\n";
	n5 = n5 .. "    {#These lines will also be executed when pressing the default IfThen Macro since they are not inside a MacroStart group ;}\n";
	n5 = n5 .. "    {OnEvent(\"PVP\") AND NOT IsPVP(\"player\") THEN Print(\"I am no longer pvp-flagged\"); ;}\n";
	n5 = n5 .. "    {OnEvent(\"Dead\") AND InRaid() THEN Chat(\"Raid\",\"I am dead\") ;}\n";
	n5 = n5 .. "    {...}\n\n\n";
	n5 = n5 .. "More info:\n";
	local _, _, maxLen = Macro:getDefaultMacroValues();
	n5 = n5 .. "    - The addon will automatically create one macro per group and it will be named \"IfThen_{{MyMacro}\".\n";
	n5 = n5 .. "    - If you remove a group then the addon will automatically delete the macro for it.\n";
	n5 = n5 .. "    - If you rename a group then the addon will automatically delete the old macro and create a new one.\n";
	n5 = n5 .. "    - You can not stack multiple MacroStart() inside each other.\n";
	n5 = n5 .. "    - The '{{Name}' for a MacroStart() can't be longer than "..tostring(maxLen).." characters.\n";
	n5 = n5 .. "    - Cooldown(), SetTimer() and SetFlag() variables are global and are not limited to a group.\n";
	n5 = n5 .. "    - OnEvent() statements are not affected by macro-groups. They run separately from IF-statements. You can place them inside a MacroStart() of course if it helps in organizing your text.\n";
	n5 = n5 .. "    - GetQuest and Shift features are only supported for the default IfThen-macro.\n\n\n";
	n5 = n5 .. "    MacroStart(\"{{Name}\")\n";
	n5 = n5 .. "        Begins a macro-group called '{{Name}' (max "..tostring(maxLen).." characters).\n\n";
	n5 = n5 .. "    MacroEnd()\n";
	n5 = n5 .. "        Marks the end of a macro-group.";
	n5 = StringParsing:replace(n5, "{{",tmpColor2["REQ"]); --yellow for required
	n5 = StringParsing:replace(n5, "{",	colRed); -- red for keywords and statements
	n5 = StringParsing:replace(n5, "}",	"|r");

	--General intro
	local n2 = "";
	n2 = n2 .. "\n\n\n<== Click on a function name to show its documentation.\n\n";
	n2 = n2 .. "    Required arguments are in |cFFEBB81FYellow|r, and optional arguments are in |cFF806EC5Purple|r.\n";
	n2 = n2 .. "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------\n\n";
	n2 = StringParsing:replace(n2, "{{",tmpColor2["VAL"]); --teal for OnEvent() arguments
	n2 = StringParsing:replace(n2, "{",	colRed); -- red for keywords and statements
	n2 = StringParsing:replace(n2, "}", "|r");

	--Variable intro
	local n4 = "";
	n4 = n4 .. "\n\n\n<== Click on a variable name to show its documentation.\n\n";
	n4 = n4 .. "    All variable names are written as {{{{%variableName%} and they are not case-sensitive.\n";
	n4 = n4 .. "    They can be used everywhere in all function-arguments, as long as they match on the datatype, and the values expected.\n\n";
	n4 = n4 .. "    Examples:\n";
	n4 = n4 .. "               {IsDead(\"%playerName%\")}  will not work since the IsDead() function expects '{{player}', '{{target}' '{{focus}' or '{{pet}' as an argument, and {{{{%playerName%} returns none of those.\n";
	n4 = n4 .. "               {SetTimer(\"MyTimer\", \"%playerLevel%\")}  will work since the SetTimer() function expects a number value, and the value of {{{{%playerLevel%} is between '{{1}' and '{{600}' (the max/min range of the argument).\n";
	n4 = n4 .. "               {Group(\"My name is %playerName% and i am level %playerLevel%\")}  will work too since the argument for Group() is a wide string with no restrictions.\n\n";
	n4 = n4 .. "    Variable names are case-insensitive so {{{{%PLAYERNAME%}, {{{{%PlayerName%} and {{{{%playerName%} will all refer to the same value, however you can control the formatting of the output by the way you write the variable name:\n";
	n4 = n4 .. "               {{{{%PLAYERNAME%}   -Outputs the whole string in uppercase ('{{{THE QUICK BROWN FOX}').                                  Numbers: no formatting and 0 decimals ('{{{12345}')\n";
	n4 = n4 .. "               {{{{%playername%}       -Outputs the whole string in lowercase ('{{{the quick brown fox}').                                            Numbers: with formatting and 0 decimals ('{{{12 345}')\n";
	n4 = n4 .. "               {{{{%Playername%}       -Only the first character of the whole string is capitalized ('{{{The quick brown fox}').                 Numbers: no formatting and 2 decimals ('{{{12345.67}')\n";
	n4 = n4 .. "               {{{{%PlayerName%}       -The first character in each word is capitalized ('{{{The Quick Brown Fox}').                             Numbers: with formatting and 2 decimals ('{{{12 345.67}')\n";
	n4 = n4 .. "               {{{{%playerName%}       -No formatting will be applied. The string will be returned the way that the game outputs it.  Numbers: returns raw number ('{{{12345.67890}')\n";
	n4 = n4 .. "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";
	n4 = StringParsing:replace(n4, "{{{{",	tmpColor["VAR"]); --golden for variable arguments
	n4 = StringParsing:replace(n4, "{{{",	tmpColor["STRING"]); --gray for string arguments
	n4 = StringParsing:replace(n4, "{{",	tmpColor2["VAL"]); --teal for OnEvent() arguments
	n4 = StringParsing:replace(n4, "{",		colRed); -- red for keywords and statements
	n4 = StringParsing:replace(n4, "}", "|r");

	--Settings info
	local n3 = "";
	n3 = n3 .. "\n{{IfThen} Settings:\n";
	n3 = n3 .. "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------\n\n";
	n3 = n3 .. "You can set all the settings for IfThen by using the slash command /ifthen or /ift.\n\n\n";
	n3 = n3 .. "{Spellcheck:}  Allows you to replace strings in the chatmessages you type before they are sent to the server.\n";
	n3 = n3 .. "                  Variables (%playerName%, etc) and hyperlinks ([type:text] or [type:id:text]) will also be replaced if Spellcheck is enabled.\n";
	n3 = n3 .. "                  However, if you turn on this feature commands like /target and /focus will not work in chat.\n";
	n3 = n3 .. "                  This feature is explained more under OnEvent(\"Spellcheck\"). Default is {{Disabled}.\n\n";
	n3 = n3 .. "{Minimal:}      When enabled it will remove almost all the documentation to reduce the memory footprint of the addon.\n";
	n3 = n3 .. "                  The Description, Returns, Remarks, Examples and See also fields will be cleared from memory.\n";
	n3 = n3 .. "                  There should be no need to enable this unless you are running on a very slow machine. Default is {{Disabled}.\n\n";
	n3 = n3 .. "{Color:}         When enabled, syntax coloring for the edit window and examples in documentation will be applied. Default is {{Enabled}.\n";
	n3 = n3 .. "                  The feature will dynamically adjust the frequency of coloring up/down based on the time it takes to process.\n";
	n3 = n3 .. "                  In other words: slow computer + large text in editor = takes longer time ==> coloring will adjust to run less often.\n\n";
	n3 = n3 .. "{EasyCast:}    When enabled, double right-clicking anywhere on the screen while not in combat will trigger the default macro. Default is {{Disabled}.\n";
	n3 = n3 .. "                  This feature might not work properly if you are using other addons that also provide a similar feature.\n\n";
	n3 = n3 .. "{LineNumber:} When enabled, line numbers will be shown in the editor. Default is {{Disabled}.\n";
	n3 = n3 .. "                   This feature might be useful if you are having a hard time tracking down errors.\n\n";
	n3 = n3 .. "{OnEvent:}     Turn on/off OnEvent. If this feature is turned off then none of the OnEvent()-statements will trigger. Recommended is to keep this {{Enabled}.\n\n";
	n3 = n3 .. "{ExtraSlash:}  Turn on/off extra slash commands. When enabled you get access to some extra slash commands (/rolecheck and /rc (readycheck). Default is {{Disabled}.\n\n";
	n3 = n3 .. "{GetQuest:}    Makes the IfThen-macro also try to accept/deliver any quests to the targeted NPC. Note: you must manually right-click the NPC, but you can then\n";
	n3 = n3 .. "                  press the macro-button repeatedly to step through the quests dialogues. This makes accepting and delivering quests extremely fast. Default is {{Enabled}.\n\n";
	n3 = n3 .. "{MacroRefresh:} Will make IfThen periodically refresh the macro-icon. Normally it will only refresh when the user presses the macro-button. Default is {{Disabled}.\n\n";
	n3 = n3 .. "{Shift:}           Will let the user be able to SHIFT+Click the macro button. This will then open the Edit window. ALT+Click will reload the user interface (/reload).\n";
	n3 = n3 .. "                   Shift- and Alt-clicking is disabled when you are in combat. Default is {{Enabled}.\n\n";
	--n3 = n3 .. "{Debug:}        Will turn on some extra output messages from IfThen. Default is {{Disabled}.\n\n";
	n3 = n3 .. "\nYou can also go into the 'Key Bindings' menu and bind a key to trigger the macro or to show the edit and morehelp window.";
	n3 = StringParsing:replace(n3, "{{",tmpColor2["REQ"]); --yellow for titles
	n3 = StringParsing:replace(n3, "{",	colRed); --red for keywords and statements
	n3 = StringParsing:replace(n3, "}", "|r");

	--[[NOTE: due to LUA restrictions we got to declare this in several separate variables and then later concat them together (think LUA runs out of stackspace for the string).
		Seems like a lua function cant return a string bigger than 4096 characters long, we therefore have to call the function several times and concat it all later]]--

	--Store in cache for later lookup
	local strList, intNum = nil, nil;
	cache_getMoreHelpText = {};

	strList, intNum = Documentation:printSimpleMethodList("argument");
	cache_getMoreHelpText["argument"]	= "Arguments (total "..tostring(intNum).."):\n"..strList;
	strList, intNum = Documentation:printSimpleMethodList("action");
	cache_getMoreHelpText["action"]		= "Actions (total "..tostring(intNum).."):\n"..strList;
	strList, intNum = Documentation:printSimpleMethodList("event");
	cache_getMoreHelpText["event"]		= "Events (total "..tostring(intNum).."):\n"..strList;
	--strList, intNum = Documentation:printSimpleMethodList("variable");
	--cache_getMoreHelpText["variable"]	= "Variables (total "..tostring(intNum).."):\n"..strList;


	cache_getMoreHelpText["settings"]	= n3;--.."\n";
	cache_getMoreHelpText["syntax"]		= n;--.."\n";
	cache_getMoreHelpText["macrostart"]	= n5;--.."\n";
	cache_getMoreHelpText["argument"]	= n2.."\n"..cache_getMoreHelpText["argument"];
	cache_getMoreHelpText["action"]		= n2.."\n"..cache_getMoreHelpText["action"];
	cache_getMoreHelpText["event"]		= n2.."\n"..cache_getMoreHelpText["event"];
	cache_getMoreHelpText["variable"]	= n4--.."\n"..cache_getMoreHelpText["variable"];

	--self:collectGarbage();
	return cache_getMoreHelpText[title];
end


--Returns a properly formatted string that is a list of example statements for first time installations
function IfThen:getExampleText()
	local n = "";
	n=n.."# ==First time install==;\n\n";
	n=n.."# If this is your first time using IfThen then you can look in 'faq.txt' and 'examples.txt' found in the addon folder for a list of examples and answers;\n";
	n=n.."# When you have the macro on your toolbar, then you can SHIFT-Click the macro to open the edit window or you can type '/ifthen edit' in your chat window;\n";
	n=n.."# If you Alt-Click the macro icon, then you reload the user interface (/reload);\n";
	n=n.."# You can learn alot more about syntax, arguments, variables and settings by using '/ifthen morehelp' or by simply pressing the 'More Help' button in the lower left corner of this window;\n\n\n";
	n=n.."# IF statements. These will be processed when you click the macro button;\n\n";
	n=n.."#Pandaria - Golden Lotus;\n";
	n=n.."IF InZone(\"Mistfall Village\") AND HaveOpenQuest(\"My Town, it's On Fire Again\") AND HaveItem(\"Mistfall Water Bucket\", \"1\", \"gte\") THEN UseItem(\"Mistfall Water Bucket\");\n";
	n=n.."IF InZone(\"The Golden Stair\") AND HaveOpenQuest(\"Cannonfire\") AND MouseOver(\"Cannon\",\"indexof\") THEN UseQuestItem(\"Cannonfire\");\n\n";
	n=n.."#Pandaria - Tillers faction;\n";
	n=n.."IF InZone(\"Sunsong Ranch\") AND MouseOver(\"Parched\", \"startswith\") THEN UseItem(\"Rusty Watering Can\");\n";
	n=n.."IF InZone(\"Sunsong Ranch\") AND MouseOver(\"Infested\", \"startswith\") THEN UseItem(\"Vintage Bug Sprayer\");\n\n";
	n=n.."# General stuff;\n";
	n=n.."IF NOT IsFlying() AND HaveEquipped(\"Fishing Pole\") THEN Cast(\"Fishing\");\n\n\n\n";
	n=n.."# OnEvent() statements. These lines will automatically be triggered when events occur in the game;\n\n";
	n=n.."# Auto decline invite if you are in the LFG queue, will trigger only every 30 seconds;\n";
	n=n.."OnEvent(\"GroupInvite\") AND Cooldown(\"30\") AND InLFGQueue() THEN DeclineGroup() AND Reply(\"Automated reply: I am in the LFG queue. Invite auto-declined.\");\n\n";
	n=n.."# Auto-reply when you are in combat;\n";
	n=n.."OnEvent(\"Chat\",\"Whisper\") AND Cooldown(\"60\") AND InInstance() AND InCombat() THEN Reply(\"Automated reply: Currently in combat.\");\n\n";
	n=n.."# Give us a beep and a message every 10 seconds when we have Heroism or Time Warp;\n";
	n=n.."OnEvent(\"Buff\") AND Cooldown(\"10\") AND HasBuff(\"Heroism\") OR HasBuff(\"Time Warp\") THEN PlayAudio(\"UI_BnetToast\") AND Print(\"!!!==Heroism / Time Warp==!!!\");\n\n";
	n=n.."# Say a line in group if we switch talents;\n";
	n=n.."OnEvent(\"TalentSpecChanged\") AND InInstance() AND InGroup() THEN Group(\"Wait a sec while i regen mana. I just switched talents.\");\n\n";
	n=n.."# Announce when deploying repairbot and remind people after 8 minutes.;\n";
	n=n.."OnEvent(\"Casted\",\"Jeeves\") AND InGroup() THEN Group(\"--> [item:Jeeves] repairbot is up\") AND Chat(\"Say\",\"Jeeves, repairbot is up\") AND SetTimer(\"JeevesBot\",\"480\");\n";
	n=n.."OnEvent(\"Timer\",\"JeevesBot\") AND InGroup() THEN Group(\"--> [item:Jeeves] repairbot will despawn soon.\");\n\n";
	n=n.."# Really only useful for a Mage to auto-mark just after they cast polymorph (too bad Blizzard don't allow Addons to use /focus);\n";
	n=n.."OnEvent(\"Casted\",\"Polymorph\") AND CoolDown(\"10\") AND HasBuff(\"Polymorph\",\"target\") THEN MarkTarget(\"MOON\");\n\n";
	n=n.."# Use the spellcheck feature (must be turned on with '/ifthen spellcheck');\n";
	n=n.."Onevent(\"Spellcheck\", \"rouge\", \"rogue\");\n\n";
	n=n.."# Type '/ifs level' in chat to trigger this event that will report the itemlevel of my equipped items;\n";
	n=n.."OnEvent(\"Slash\",\"level\") AND Report(\"Print\",\"ItemLevel\",\"equipped\");\n\n";
	return n;
end


--####################################################################################
--####################################################################################
--Development, Testing, Support
--####################################################################################

--Returns true/false if we are in debug-mode
function IfThen:isDebug(level)
	level = tonumber(level);
	if (level == nil or level < 1) then level = 1 end --Convert nil and negative numbers to 1
	if (IFTHEN_settings[SETTING_Debug] >= level) then return true end --We use a number so that we might in the future enable a verbose-level
	return false;
end


--Outputs a error message into the chat frame
function IfThen:msg_error(n)
	--To use color we can use ChatFrame1:AddMessage("text" [, red [, green [, blue [, alpha]]]])
	--or we can simply add |cFFFFFFFF into print(), |r will reset to the default color
	--print("|cFFFF0000Hello|rWorld"); will use the color 'FFFF0000' (red with Alpha) and then |r will reset the text to white

	n = "    " .. StringParsing:replace(strtrim(n),"\n","\n    "); --prepend all lines with 4 spaces
	n = "|cFFEABC32IfThen|cFFFFFFFF:|cFFB92828 ==>Error\n|r"..n;
	print(n);
	return true;
end


--Outputs a message into the chat frame
function IfThen:msg(n)
	n = "|cFFEABC32IfThen|cFFFFFFFF:|r "..n;
	print(n);
	return true;
end


--Checks the version number compared to saved values and will print a message
function IfThen:versionCheck(oldVersion, newVersion)
	if (oldVersion == newVersion) then return false end
	local n = "";
	if oldVersion == "0.0.0" then
		---First install
		n = n .. " - First time install.\n";
		n = n .. "If this is your first time using |cFFEABC32IfThen|cFFFFFFFF then you can look in 'faq.txt' and 'examples.txt' found in the addon folder for a list of examples and answers.\n";
		n = n .. "When you have the macro on your toolbar, then you can SHIFT-Click the macro to open the edit window or you can type '/ifthen edit <n>' in your chat window.\n";
		n = n .. "If you Alt-Click the macro icon, then you reload the user interface (/reload). The Shift and Alt-clicking is disabled while you are in combat.\n";

		---If this is version 0.0.0 and the text is nil then this is most likely a first time install. We therefore create a list of example statements in page 1
		if ((oldVersion == "0.0.0") and (IFTHEN_text == nil or #IFTHEN_text == 0)) then IFTHEN_settings[SETTING_Minimal] = false; IFTHEN_text = {self:getExampleText()} end
	else
		--Updated from older version
		n = n .. "- Updated from v"..oldVersion.." to v"..newVersion.."\n";
		n = n .. "Look in 'changelog.txt' found in the addon folder for a list of changes.\n";
		n = n .. "If any of the existing functions or events have had their method-signature changed, then you will see parser errors.\n";

		if (IFTHEN_settings[SETTING_Minimal] == true) then --Always reset 'Minimal' between version changes so that the user can quickly lookup changes
			IFTHEN_settings[SETTING_Minimal] = false;
			n = n.."\n==>Version change: The 'Minimal' feature has been re-enabled.\n";
		end

		IFTHEN_settings[SETTING_Debug] = 0; --Always disable debug on version change
		IFTHEN_cache = {}; --On a version change we clear the cache of all data
	end

	self:msg(n); --display the message
	return true;
end


--Returns 1 if strVersion1 is greater than strVersion2, -1 otherwise and 0 if they are equal.
function IfThen:compareVersionNumber(strVersion1, strVersion2)
	--We pad the version number with 0's so that they are identical in length
	local strNum1, intDots1, numSize1 = self:padVersionNumber(strVersion1);
	local strNum2, intDots2, numSize2 = self:padVersionNumber(strVersion2);

	--If one version number has more padding size, then we pad the other one with the same amount
	if (numSize1 > numSize2) then strNum2, intDots2, numSize2 = self:padVersionNumber(strVersion2, intDots2, numSize1) end
	if (numSize2 > numSize1) then strNum1, intDots1, numSize1 = self:padVersionNumber(strVersion1, intDots1, numSize2) end

	--If one version number has more . (dots), then we pad the other one with the correct amount of 0's
	if (intDots1 > intDots2) then strNum2, intDots2, numSize2 = self:padVersionNumber(strVersion2, intDots1, numSize2) end
	if (intDots2 > intDots1) then strNum1, intDots1, numSize1 = self:padVersionNumber(strVersion1, intDots2, numSize1) end

	local tostring = tostring;
	--If version1 is greater than version2 (stringcompare) then we return 1
	if (tostring(strNum1) > tostring(strNum2)) then return  1 end
	if (tostring(strNum1) < tostring(strNum2)) then return -1 end
	return 0; --Equal
end


--Will pad and add extra 0's so that the version number is of the proper length for comparison
function IfThen:padVersionNumber(strV, intExtra, intSize)
	local arrVersion = StringParsing:split(strV, ".");
	local strlen	= strlen; --local fpointer
	local tostring	= tostring;

	if (intSize == nil) then --If not specified then lookup the largest padding size we need
		intSize = 0;
		local curLen = "";
		for i=1, #arrVersion do --Traverse and get the largest length
			curLen = strlen(tostring(arrVersion[i]));
			if (intSize < curLen) then intSize = curLen end
		end--for i
	end--if intSize

	local strVersion = "";
	local strCur = "";
	for i=1, #arrVersion do
		--post-pad strings with 0's that are less than N char's in length
		strCur = tostring(arrVersion[i]);
		if (strlen(strCur) < intSize) then
			for j=(intSize-1), strlen(strCur), -1 do
				strCur = strCur.."0";
			end--for j
		end--if
		strVersion = strVersion..strCur;
	end--for i

	if (intExtra == nil) then
		intExtra = 0;
	else
		intExtra = intExtra - #arrVersion;
		for i=1, intExtra do
			--post-pad strings with 0's that are less than N char's in length
			strCur = "";
				for j=1, intSize do
					strCur = strCur.."0";
				end--for j
			strVersion = strVersion..strCur;
		end--for i
	end--if intExtra

	return tostring(strVersion), (#arrVersion+intExtra), intSize; --return the string, the number of dots we found, and paddingSize used
end


--Do a garbage Collection
local cache_collectGarbage_LastCall = time(); --Time when last invoked
function IfThen:collectGarbage(force)
	if (force ~= true and difftime(time(), cache_collectGarbage_LastCall) < 30) then return nil; end
	collectgarbage("collect"); --Force a garbage collection
	cache_collectGarbage_LastCall = time();
	return nil;
end


--[[Search through _G and return partial or exact matches to keys
function IfThen:g_find(strKey, exact, flip)
	strKey = strtrim(strupper(tostring(strKey)));	--all keys are uppercase
	if (exact ~= true) then exact = false end		--bool value exact match
	if (flip ~= true)  then flip  = false end		--bool value flip key & value before returning result

	local i, j, tbl = 0, 0, {};
	local sm					= function(str,item) return StringParsing:startsWith(str,item) end;	--partial match
	if (exact==true) then sm	= function(str,item) return (str==item) end end;					--exact match

	for k,v in pairs(_G) do
		--check that k is of type(k)=="string" or you might crash incase someone has put someting like a table in there
		if (sm(k,strKey) == true) then j=j+1; tbl[k]=v; end --add to result if it matches
		i = i +1;
	end--for
	if (not flip) then table.sort(tbl); end --Alphabetical sorting

	print("Searched _G ("..tostring(i).." entries) and found "..tostring(j).." matche(s)...");

	if (flip==true) then --flip the result so that the 'value' is used as the 'key' in the table.
		local r = {};
		for k,v in pairs(tbl) do
			r[strlower(v)] = k;
		end--for k,v
		table.sort(r); --Alphabetical sorting
		tbl = r;
	end--if flip

	self:dump(tbl);
	return tbl;
end
function g_find(strKey,exact,flip)
	return IfThen:g_find(strKey,exact,flip);
end

--Search through _G and return partial or exact matches to string-values
function IfThen:g_find2(strValue, exact)
	strValue = strtrim(strupper(tostring(strValue)));--all values are case-insensitive
	if (exact ~= true) then exact = false end					--bool value

	local i, j, tbl = 0, 0, {};
	--local sm					= function(str,item) return StringParsing:startsWith(str,item) end;	--partial match
	local sm					= function(str,item) if StringParsing:indexOf(str,item,1)==nil then return false else return true end end;	--partial match
	if (exact==true) then sm	= function(str,item) return (str==item) end end;					--exact match

	for k,v in pairs(_G) do
		--check that k is of type(k)=="string" or you might crash incase someone has put someting like a table in there
		if (type(v) == "string") then
			v = strupper(v);
			if (sm(v,strValue) == true) then j=j+1; tbl[k]=v; end --add to result if it matches
			i = i +1;
		end--if type
	end--for
	table.sort(tbl); --Alphabetical sorting

	print("Searched _G ("..tostring(i).." entries) and found "..tostring(j).." matche(s)...");
	self:dump(tbl);
	return tbl;
end
function g_find2(strValue,exact)
	return IfThen:g_find2(strValue,exact);
end


--Dumps the content of a variable
function IfThen:dump(tbl, preserve)
	local d = self:array_to_string(tbl);

	--using print() for large tables is completely shit, therefore using the helpframe to display it
	local frm = IfThenXML_Help_Frame;
	local scr = IfThenXML_Help_ScrollFrame;
	local edt = IfThenXML_Help_EditBox;

	if (preserve==true) then d = edt:GetText().."\n==============================\n"..d end --preserve existing text if told to

	edt:SetText(d);
	scr:SetVerticalScroll(0); --Reset the scrollbar to the top
	local b = frm:IsVisible(); --true or false
	if (b == false) then frm:Show() end
	frm:Raise();

	return nil;
end
function dump(tbl,preserve)
	return IfThen:dump(tbl,preserve);
end

--Helper function(s) used to make a output friendly view of tables, functions etc
function IfThen:array_to_string(tbl)
	--Source: http://lua-users.org/wiki/TableSerialization
	if "nil" == type( tbl ) then
		return tostring(nil);
	elseif "table" == type( tbl ) then
		return self:table_print(tbl);
	elseif "string" == type( tbl ) then
		return tbl;
	else
		return tostring(tbl);
	end--if
end
function IfThen:table_print(tt, indent, done)
	done = done or {};
	indent = indent or 0;

	if type(tt) == "table" then
		local sb = {};
		for key, value in pairs (tt) do
			table.insert(sb, string.rep (" ", indent)); -- indent it
			if type (value) == "table" and not done [value] then
				done [value] = true;
				--table.insert(sb, "{\n");
				table.insert(sb, "\n '"..tostring(key).."'\n{\n");
				--table.insert(sb, "{");
				table.insert(sb, self:table_print (value, indent + 2, done));
				table.insert(sb, string.rep (" ", indent)); -- indent it
				table.insert(sb, "}\n");
				--table.insert(sb, "}");
			elseif "number" == type(key) then
				table.insert(sb, string.format("\"%s\"\n", tostring(value)));
			else
				table.insert(sb, string.format(
					"%s = \"%s\"\n", tostring (key), tostring(value)));
			end--if
		end--for
		return table.concat(sb);
	else
		--return tt .. "\n";
		return self:array_to_string(tt) .. "\n";
	end--if
end

--Prints out all variables that are passed into the function
function pprint(...)
	local s="";
	for i = 1, select("#", ...) do
		s = s.." Arg"..tostring(i).." '"..tostring( select(i,...) );
	end--for i
	if (s ~= "") then s = s.."'"; end
	return print(strtrim(s));
end
--]]--


--####################################################################################
--####################################################################################
--External Hooks (Permanent hooks will be done as soon as the file is loaded. Hooks that the user can toggle on/off we must use the ToggleHooks() function for)
--####################################################################################

--This hook will make us able to trigger on invites to battlegrounds like Alterac Valley that does not give us a proper event that we can register for. We therefore have to hook into the OnShow() of the battleground dialog frame
local hook_CONFIRM_BATTLEFIELD_ENTRY = StaticPopupDialogs["CONFIRM_BATTLEFIELD_ENTRY"].OnShow;	--Original function
StaticPopupDialogs["CONFIRM_BATTLEFIELD_ENTRY"].OnShow = function(...)							--Our override function
	IfThen:OnEvent_OnEvent(nil, "IFTHEN_BATTLEFIELD_SHOW", ""); --Raise our own function that will trigger the rest of our code related to this event
	return hook_CONFIRM_BATTLEFIELD_ENTRY(...);--Pass the call to the original function
end


local hook_ItemRefTooltip_SetHyperlink = ItemRefTooltip["SetHyperlink"];
--Hook prevents addon hyperlinks to be propagated all the way down to Blizzard code
function ItemRefTooltip:SetHyperlink(link, ...)
	if (link:sub(0, 7) == "ifthen:") then return nil end;
	return hook_ItemRefTooltip_SetHyperlink(self, link, ...);
end


--Post-hook to default chatframes. Custom chatframes like what the WIM addon provides are not supported.
function IfThen_ChatFrame_OnHyperlinkShow(chatframe, link, text, button)
	--Hooked in OnEvent()
	local start = strfind(link, "ifthen:", 1, true); --plain find starting at pos 1 in the string
	if (start == 1) then
		IfThen:HyperLink_EventHandler(link, text, button);
	end
	return nil;
end


--Local variables that store hook pointers
local hook_ChatEdit_OnEnterPressed = ChatEdit_OnEnterPressed;	--Original function

function IfThen:ToggleHooks(refreshState)
	--This function is called after IfThen has been properly loaded, that way we can determine whether the hook should be done or not (values for variables like SETTING_Spellcheck is not loaded and set from storage until after the whole lua file is loaded so we need to do this hooking in a function)
	--This hook will make us able to edit any chat-text that the player writes before its sendt to the server
	if (IFTHEN_settings[SETTING_Spellcheck]==true) then
		--Lookup slash commands from _G so that we support their localized names.
		local arrList = {};
		arrList[#arrList+1] = strlower(tostring(_G["SLASH_FOCUS1"]));		--/focus
		arrList[#arrList+1] = strlower(tostring(_G["SLASH_FOCUS2"]));
		arrList[#arrList+1] = strlower(tostring(_G["SLASH_TARGET1"]));		--/target
		arrList[#arrList+1] = strlower(tostring(_G["SLASH_TARGET2"]));
		arrList[#arrList+1] = strlower(tostring(_G["SLASH_TARGET3"]));
		arrList[#arrList+1] = strlower(tostring(_G["SLASH_TARGET4"]));
		arrList[#arrList+1] = strlower(tostring(_G["SLASH_CLEARTARGET1"]));	--/cleartarget
		arrList[#arrList+1] = strlower(tostring(_G["SLASH_CLEARTARGET2"]));
		arrList[#arrList+1] = strlower(tostring(_G["SLASH_CLEARFOCUS1"]));	--/clearfocus
		arrList[#arrList+1] = strlower(tostring(_G["SLASH_CLEARFOCUS2"]));
		IfThen_cache_SpellCheckSlashList = arrList; --Store list in a globally declared variable for later use by the ChatEdit_OnEnterPressed function

		ChatEdit_OnEnterPressed = function(...)		--Our override function
			local objSelf = ...;							--First (and only) argument passed in to the function is 'self' (ChatFrame1EditBox)
			local orgText = objSelf.GetText(objSelf);		--Get the existing text that the player wrote
			local newText = IfThen:ReplaceInChat(orgText);	--Raise our own function that will replace anything in the text with our values
			if (orgText~=newText) then objSelf.SetText(objSelf, newText) end --Set the text in the chatframe to the new value
			local IFT_startsWith = IfThen_StringParsing["startsWith"];	--Stringparsing.lua: startsWith() function
			local slashList = IfThen_cache_SpellCheckSlashList or {};	--Global declared when Spellcheck is enabled
			local lowText = strlower(newText);

			for i=1, #slashList do
				--if (IFT_String:startsWith(lowText,sFocus1) == true) then
				if (IFT_startsWith(IFT_startsWith, lowText, slashList[i]) == true) then
					--If the user has typed any of these commands then we just show an error message since it will trigger a 'Blizzard invalid action message' if we pass it to the original function
					IfThen:msg_error("/focus, /target, /cleartarget and /clearfocus does not work from the Chatbox when the Spellcheck feature is enabled.");
					objSelf:Hide(); --The chatbox stays open until we hide it
					return nil;
				end--if
			end--for i
			return hook_ChatEdit_OnEnterPressed(...);--Pass the call to the original function
		end
		--hooksecurefunc("ChatEdit_OnEnterPressed", ChatEdit_OnEnterPressed2my); --a secure hook does not work with ChatEdit_OnEnterPressed since we need a pre-hook to change the text before its sendt to the chatserver
	end--SETTING_Spellcheck
end--ToggleHooks

--local startTime = debugprofilestop();
--print(format("IfThen %f ms", debugprofilestop()-startTime));
--####################################################################################
--####################################################################################
