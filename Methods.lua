--####################################################################################
--####################################################################################
--Method & Event functions, /Use and /Cast wrappers for macro methods aswell as all other functions
--####################################################################################
--Dependencies: StringParsing.lua, HiddenTooltip.lua, Macro.lua, Parsing.lua, IfThen.lua
--Note: All methods must accept 1 single argument and must return TRUE or FALSE in all codepaths
--		Some methods refer to global variables. For example Methods:do_Something() and Methods:do_OnEvent() but also others

local Methods	= {};
Methods.__index	= Methods;
IfThen_Methods	= Methods; --Global declaration

local StringParsing	= IfThen_StringParsing; --Local pointer
local HiddenTooltip	= IfThen_HiddenTooltip;	--Local pointer
local Macro			= IfThen_Macro;			--Local pointer
--local Parsing		= IfThen_Parsing;		--Local pointer (NOTE: this lua file is loaded before Parsing.lua so this reference would always be nil)
--local IfThen		= IfThen_IfThen;	 	--Local pointer


--Local variables that cache stuff so we dont have to recreate large objects
local cache_LastIncomingSender	= nil;	--Name of the player that last sendt you a /whisper or an /invite for a group
local cache_Countdown			= nil;	--Chat Channel and NextValue of the countdown function
local cache_StopWatch			= nil;	--Flag used to let it pass 1 more second before removing the stopwatch frame
local cache_LastCooldownToken	= nil;	--Unique string that is used by the do_Cooldown() function. Value is set by Parsing:Parse_If() or :Parse_Event() using Methods:SetCoolDownToken()
local cache_CooldownList		= {};	--List of tokens and their timestamp
local cache_TimerList			= {};	--List of timer-titles and their timestamp
local cache_FlagList			= {};	--List of flag-variables and their values
local cache_Background			= {};	--List of flags (value nil or true) used for background events
local cache_SpellCheckList		= nil;	--List of words to find/replace
local cache_TradeSkill			= nil;	--List of hyperlinks for the players tradeskills
local cache_PlayList_Normal		= nil;	--List of premapped audio files
local cache_PlayList_Lower		= nil;	--List of premapped audio files
local cache_PlayerPosition		= nil;	--List with Player coordinates and facing (1=X, 2=Y, 3=Zone, 4=SubZone, 5=Rad)
local cache_RandomNumber		= nil;	--Positive integer value outputted by %Random% and set by do_Random()
local cache_Report				= nil;	--Table with N values, outputted for %ReportN% and set by do_Report()
local cache_CurrencyList		= nil;	--Table with list of currencies that the user has been referencing (key=uppercase(name), value=id).
local cache_FactionList			= nil;	--Table with list of factions that the user has been referencing (key=uppercase(name), value=id).
local cache_InstanceList		= nil;	--Table with list of all instancenames found in encounterjournal (key=uppercase(name), value=name).
local cache_EncounterBossList	= nil;	--Table with list of all bossnames found in encounterjournal (key=uppercase(name), value=name).
local cache_PlayerName			= nil;  --Name of the current player
local cache_AFKorDNDFlag		= nil;	--Used by OnEvent_IFTHEN_AFKORDND to remember previous state
local cache_PVPFlag				= tostring(UnitIsPVP("player")); --Used by OnEvent_IFTHEN_PVP to remember previous state
local cache_InventoryIDList		= nil;	--Table with all slotID's ingame. Populated by self:getInventoryIDList() when its needed.
local cache_PowerTypes			= nil;	--Table with all powertypes ingame. Key = "english name in lowercase", Value = Powertype value (same as SPELL_POWER_* globals).
local cache_MacroName			= nil;	--nil or a string with the name of the macro to edit with Macro:update()
local cache_RaidMessageColor	= ChatTypeInfo["RAID_WARNING"];	--Default color for raid messages
local cache_NPCList				= nil;	--nil or table (key=npcID, value=negative or positive number or npcName (postive number means its a replacement npcID to use for name lookup)
local cache_CombatlogFrame		= nil;	--nil or a pointer to a frame used for the combatlog
local cache_DBM_hookCache		= nil;	--nil or table of what hooked function calls that have been sucessfully invoked (key=function+intRandom, value=nil or true)
local cache_DeathName			= nil;	--nil or a string
local cache_DeathSpell			= nil;	--nil or a string
local cache_DeathAmount			= nil;	--nil or a number used by the %DeathAmount% variable
local cache_DeathOverkill		= nil;	--nil or a number
local cache_EnvirSpell			= nil;	--nil or a string
local cache_EnvirAmount			= nil;	--nil or a number
local cache_SavedInstances		= time(); --timestamp
local cache_PlayerModel			= nil;	--nil or a PlayerModel frame. Set in InWorgenForm()


local CONST_GlobalChatChannels	= {["INSTANCE"]=1, ["INSTANCE_CHAT"]=1, ["GUILD"]=1, ["OFFICER"]=1, ["PARTY"]=1, ["RAID"]=1, ["RAID_WARNING"]=1, ["YELL"]=1, ["SAY"]=1, ["WHISPER"]=1, ["EMOTE"]=1, ["1"]=1, ["2"]=1, ["3"]=1, ["4"]=1}; --List of global chat channel names
local CONST_CooldownMaxSize		= 15;	--Max N unique tokens in the 'cache_CooldownList' & 'cache_TimerList' list before we start cleaning up
local CONST_CooldownMaxTime		= 600;	--The longest time a token can exist (10 minutes)
local CONST_StopWatchTimerTitle = "StopWatchTimer"; --Title for the timer that the stopwatch uses


--Local pointers to global functions
local _G		= _G;
local type		= type;
local tonumber	= tonumber;
local tostring	= tostring;
local pairs		= pairs;
local math_floor= floor;	--math.floor
local math_random=random;	--math.random
local format	= format;
local strlen	= strlen;
local strfind	= strfind;
local strsub	= strsub;
local strlower	= strlower;
local strupper	= strupper;
local strrep	= strrep;
local strtrim	= strtrim;	--string.trim
local tinsert	= tinsert;	--table.insert
local sort		= sort;		--table.sort
local select 	= select;
local unpack	= unpack;

--Some of the most used functions, either by number of references or assumed behavior of users.
local GetUnitName		= GetUnitName;
local UnitInBattleground= UnitInBattleground;	--InBattleGround
local IsInInstance		= IsInInstance;			--InInstance
local GetLFGMode		= GetLFGMode;			--InLFGQueue
local IsWargame			= IsWargame;
local IsInRaid			= IsInRaid; --InParty
local IsInGroup			= IsInGroup;
local UnitIsUnit		= UnitIsUnit;		--do_OnEvent_UNIT_SPELLCAST_SUCCEEDED
local CalendarGetDate	= CalendarGetDate;	--do_OnEvent_IFTHEN_CLOCK
local GetGameTime		= GetGameTime;
local BNIsSelf			= BNIsSelf; 		--do_OnEvent_IFTHEN_CHAT_MSG
local GetChannelName	= GetChannelName;	--do_Chat
local SendChatMessage	= SendChatMessage;
local BNSendConversationMessage	= BNSendConversationMessage;
local PlaySoundFile		= PlaySoundFile;	--do_PlayAudio
local GetQuestLogTitle	= GetQuestLogTitle;	--HaveOpenQuest
local GetNumQuestLogEntries	= GetNumQuestLogEntries;
local print				= print;			--do_Print


--####################################################################################
--####################################################################################


--Removes functions that are not needed after initial startup.
function Methods:CleanUp()
	self:get_PlayAudioList(nil); --Make sure this has been called before we remove anything
	local d = {"get_PlayAudioListDeclare"};
	for i=1, #d do self[d[i]] = nil; end --for
	return nil;
end


--Re-initializes any local variables and resets the class
function Methods:ReInit(tabIf, tabEvent, varIf, varEvent)
	cache_LastIncomingSender	= nil;
	cache_PlayerName			= UnitName("player");
	cache_AFKorDNDFlag			= nil;
	cache_PVPFlag				= tostring(UnitIsPVP("player"));

	cache_SpellCheckList		= nil;
	self:SetCoolDownToken(nil,nil); --reset all cooldown tokens that is used by Methods:do_Cooldown()
	cache_TimerList				= {}; --reset all timers
	cache_FlagList				= {}; --reset all flags

	--Tear down any background events
	self:Setup_BackgroundEvent("ACCEPT_GROUP", true);

	self:Setup_BackgroundEvent("IFTHEN_CHAT_MSG", true);
	--Iterate through tabEvent and find out what specific events that we need to register for
	local IFTHEN_CHAT_MSG = tabEvent["IFTHEN_CHAT_MSG"];
	if (IFTHEN_CHAT_MSG ~= nil) then
		local ExtraArguments = "";
		local subEvent = IFTHEN_CHAT_MSG[1]; --we know that this event only has 1 subevent under it

		local strlower = strlower; --local fpointer
		local startI = 3; --skip the eventhandler (+2)
		for i=startI, #subEvent do
			local line = subEvent[i];
			local event_filter = line[1]; --first element on the line contains the table with arguments for the eventhandler

			local tmpChannel = event_filter[2]; --"Channel" argument is the second argument
			tmpChannel = strlower(tmpChannel);
			if (StringParsing:indexOf("instance,group,party,raid,guild,officer,whisper,say,yell,channel,battle.net,system",tmpChannel,1) == nil) then tmpChannel="channel"; end --anything that does not match the standard channels names must be either a custom channelname or a numerical channel
			ExtraArguments = ExtraArguments..","..tmpChannel;
		end--for i

		self:Setup_BackgroundEvent("IFTHEN_CHAT_MSG", false, ExtraArguments);
	end --if IFTHEN_CHAT_MSG

	self:Setup_BackgroundEvent("IFTHEN_AFKORDND", true);
	local IFTHEN_AFKORDND = tabEvent["IFTHEN_AFKORDND"];
	if (IFTHEN_AFKORDND ~= nil) then
		self:Setup_BackgroundEvent("IFTHEN_AFKORDND", false);
	end --if IFTHEN_AFKORDND

	self:Setup_BackgroundEvent("IFTHEN_PVP", true);
	local IFTHEN_PVP = tabEvent["IFTHEN_PVP"];
	if (IFTHEN_PVP ~= nil) then
		self:Setup_BackgroundEvent("IFTHEN_PVP", false);
	end --if IFTHEN_PVP

	self:Setup_BackgroundEvent("IFTHEN_UI_ERROR", true);
	local IFTHEN_UI_ERROR = tabEvent["IFTHEN_UI_ERROR"];
	if (IFTHEN_UI_ERROR ~= nil) then
		self:Setup_BackgroundEvent("IFTHEN_UI_ERROR", false);
	end --if IFTHEN_UI_ERROR

	self:Setup_BackgroundEvent("IFTHEN_LFGINVITE", true);
	local IFTHEN_LFGINVITE = tabEvent["IFTHEN_LFGINVITE"];
	if (IFTHEN_LFGINVITE ~= nil) then
		self:Setup_BackgroundEvent("IFTHEN_LFGINVITE", false);
	end --if IFTHEN_LFGINVITE

	local IFTHEN_SPELLCHECK = tabEvent["IFTHEN_SPELLCHECK"];
	if (IFTHEN_SPELLCHECK ~= nil) then
		--Go though the event and build the cache_SpellCheckList array
		local subEvent = IFTHEN_SPELLCHECK[1]; --we know that this event only has 1 subevent under it
		if (#subEvent > 2) then
			cache_SpellCheckList = {};
			local startI = 3; --skip the eventhandler (+2)
			local tinsert = tinsert; --local fpointer
			for i=startI, #subEvent do
				local line = subEvent[i];
				local event_filter = line[1]; --first element on the line contains the table with arguments for the eventhandler
				local tmpOldWord = event_filter[2]; --"Old" argument is the second argument
				local tmpNewWord = event_filter[3]; --"New" argument is the third argument
				local tmpOldNewArr = {tmpOldWord, tmpNewWord}; --first element is old word, second element is the new word
				tinsert(cache_SpellCheckList, tmpOldNewArr);
			end--for i
			if (#cache_SpellCheckList==0) then cache_SpellCheckList = nil end
		end--if #subEvent
	end --if IFTHEN_SPELLCHECK

	--TRADE_SKILL_SHOW
	--cache_TradeSkill = {};								--reset variable
	self:Setup_BackgroundEvent("TRADE_SKILL_SHOW", true);	--tear it down
	cache_TradeSkill = IfThen:GetCache("TradeSkillLinks");	--get data from persistent cache
	--if (cache_TradeSkill==nil) then cache_TradeSkill={} end--just incase its nil then we set it to {}
	self:Setup_BackgroundEvent("TRADE_SKILL_SHOW", false);	--start listening for the event again

	--IFTHEN_TICK_COUNTDOWN
	cache_Countdown = nil;										--reset variable
	self:Setup_BackgroundEvent("IFTHEN_TICK_COUNTDOWN", true);	--tear it down

	--IFTHEN_TICK_STOPWATCH
	--cache_StopWatch = nil;
	self:Setup_BackgroundEvent("IFTHEN_TICK_STOPWATCH", true);	--tear it down


	--VARIABLES: DeathName,DeathSpell,DeathAmount,DeathOverkill
	--If the variables are in use we need to monitor the combat log for events that kill the player.
	local booDeath = false;
	if varIf["deathname"]~=nil or varIf["deathspell"]~=nil or varIf["deathamount"]~=nil or varIf["deathoverkill"]~=nil				then booDeath=true; end
	if (varEvent ~= nil) then
		if varEvent["deathname"]~=nil or varEvent["deathspell"]~=nil or varEvent["deathamount"]~=nil or varEvent["deathoverkill"]~=nil	then booDeath=true; end
	end

	if (booDeath == false and cache_CombatlogFrame ~= nil) then
		cache_CombatlogFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED"); --Frame exists already from previous reparsing, just unregister the event
	elseif (booDeath == true) then
		if (cache_CombatlogFrame == nil) then --Create frame if it does not already exist
			cache_CombatlogFrame = CreateFrame("FRAME");
			cache_CombatlogFrame:SetScript("OnEvent", IfThen_Methods.do_COMBAT_LOG_EVENT_UNFILTERED);
		end
		cache_CombatlogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	end--if booDeath

	return nil;
end
--[[
function Methods:argumentCheck(t, title, numMin, numMax)
	--Global reference since the object does not exist until later
	local d = IfThen_Documentation:getMethod(title, "argument");
	if (d == nil) then d = IfThen_Documentation:getMethod(title, "action") end
	if (d == nil) then d = IfThen_Documentation:getMethod(title, "action macro") end
	if (d == nil) then
		IfThen:msg_error("Function is not defined '"..tostring(title).."'.");
		return false;
	end

	--Shorthand aliases for all the key's in the DocStruct
	local MAX	= "maxarguments";	--Maximum number of arguments
	local MIN   = "minarguments";	--Minimum number of arguments

	numMin = d[MIN];
	numMax = d[MAX];

	local c = 0;
	if (t ~= nil) then c = #t end

	if (c < numMin) then
		IfThen:msg_error("Too few arguments was passed to the function '"..tostring(title).."'.");
		return false;
	end
	if (c > numMax) then
		IfThen:msg_error("Too many arguments was passed to the function '"..tostring(title).."'.");
		return false;
	end
	return true;
end]]--


--Setup or teardown a background event
function Methods:Setup_BackgroundEvent(BackgroundEvent, TearDown, ExtraArguments)
	BackgroundEvent = strupper(BackgroundEvent);
	if (TearDown == nil) then TearDown = false end
	--ExtraArguments is an optional argument and its content/type varies with each event

	local register = true;
	if (TearDown==true) then register = false end

	--custom setup code for the various background events
	if (BackgroundEvent == "ACCEPT_GROUP") then
		if (register == true) then
			IfThen:Register_BackgroundEvent("GROUP_ROSTER_UPDATE", true); --register for the background event
		else
			if (cache_Background["GROUP_ROSTER_UPDATE"] ~= true) then
				--GROUP_ROSTER_UPDATE is a separate event on its own as well as used by ACCEPT_GROUP, we therefore must be careful not to unregister if GROUP_ROSTER_UPDATE is enabled on its own.
				IfThen:Register_BackgroundEvent("GROUP_ROSTER_UPDATE", false); --unregister from the background event
			end--if
		end--if register

	elseif (BackgroundEvent == "IFTHEN_SAVEDINSTANCE") then
		if (register == true) then
			IfThen:Register_BackgroundEvent("UPDATE_INSTANCE_INFO", true); --register for the background event
			RequestRaidInfo(); --Server request for the latest info. Data should be available after UPDATE_INSTANCE_INFO has been fired
		else
			IfThen:Register_BackgroundEvent("UPDATE_INSTANCE_INFO", false); --unregister from the background event
		end--if register

	elseif (BackgroundEvent == "IFTHEN_CHAT_MSG") then
		if (register == true) then
			if (ExtraArguments == nil) then ExtraArguments = "" end
			ExtraArguments = strlower(ExtraArguments);
			if (StringParsing:indexOf(ExtraArguments,"group",1) ~=nil) then ExtraArguments = ExtraArguments..",instance,party,raid" end --group is == instance,party,raid

			--register for the background events that we need only
			if (StringParsing:indexOf(ExtraArguments,"instance",1) ~=nil) then
				IfThen:Register_BackgroundEvent("CHAT_MSG_INSTANCE_CHAT", true);
				IfThen:Register_BackgroundEvent("CHAT_MSG_INSTANCE_CHAT_LEADER", true);
			end
			if (StringParsing:indexOf(ExtraArguments,"party",1) ~=nil) then
				IfThen:Register_BackgroundEvent("CHAT_MSG_PARTY", true);
				IfThen:Register_BackgroundEvent("CHAT_MSG_PARTY_LEADER", true);
			end
			if (StringParsing:indexOf(ExtraArguments,"raid",1) ~=nil) then
				IfThen:Register_BackgroundEvent("CHAT_MSG_RAID", true);
				IfThen:Register_BackgroundEvent("CHAT_MSG_RAID_LEADER", true);
			end
			if (StringParsing:indexOf(ExtraArguments,"battle.net",1) ~=nil) then
				IfThen:Register_BackgroundEvent("CHAT_MSG_BN_WHISPER", true);
				--IfThen:Register_BackgroundEvent("CHAT_MSG_BN_CONVERSATION", true);
				IfThen:Register_BackgroundEvent("CHAT_MSG_BN_INLINE_TOAST_BROADCAST", true);
			end
			if (StringParsing:indexOf(ExtraArguments,"guild",1) ~=nil)		then IfThen:Register_BackgroundEvent("CHAT_MSG_GUILD", true) end
			if (StringParsing:indexOf(ExtraArguments,"officer",1) ~=nil)	then IfThen:Register_BackgroundEvent("CHAT_MSG_OFFICER", true) end
			if (StringParsing:indexOf(ExtraArguments,"whisper",1) ~=nil)	then IfThen:Register_BackgroundEvent("CHAT_MSG_WHISPER", true) end
			if (StringParsing:indexOf(ExtraArguments,"say",1) ~=nil)		then IfThen:Register_BackgroundEvent("CHAT_MSG_SAY", true); end
			if (StringParsing:indexOf(ExtraArguments,"yell",1) ~=nil)		then IfThen:Register_BackgroundEvent("CHAT_MSG_YELL", true); end
			if (StringParsing:indexOf(ExtraArguments,"channel",1) ~=nil)	then IfThen:Register_BackgroundEvent("CHAT_MSG_CHANNEL", true); end
			if (StringParsing:indexOf(ExtraArguments,"system",1) ~=nil)		then IfThen:Register_BackgroundEvent("CHAT_MSG_SYSTEM", true); end

		else
			IfThen:Register_BackgroundEvent("CHAT_MSG_INSTANCE_CHAT", false); --unregister for the background event
			IfThen:Register_BackgroundEvent("CHAT_MSG_INSTANCE_CHAT_LEADER", false);
			IfThen:Register_BackgroundEvent("CHAT_MSG_PARTY", false);
			IfThen:Register_BackgroundEvent("CHAT_MSG_PARTY_LEADER", false);
			IfThen:Register_BackgroundEvent("CHAT_MSG_RAID", false);
			IfThen:Register_BackgroundEvent("CHAT_MSG_RAID_LEADER", false);
			IfThen:Register_BackgroundEvent("CHAT_MSG_GUILD", false);
			IfThen:Register_BackgroundEvent("CHAT_MSG_OFFICER", false);
			IfThen:Register_BackgroundEvent("CHAT_MSG_WHISPER", false);
			IfThen:Register_BackgroundEvent("CHAT_MSG_SAY", false);
			IfThen:Register_BackgroundEvent("CHAT_MSG_YELL", false);
			IfThen:Register_BackgroundEvent("CHAT_MSG_CHANNEL", false);
			IfThen:Register_BackgroundEvent("CHAT_MSG_SYSTEM", false);
			IfThen:Register_BackgroundEvent("CHAT_MSG_BN_WHISPER", false);
			--IfThen:Register_BackgroundEvent("CHAT_MSG_BN_CONVERSATION", false);
			IfThen:Register_BackgroundEvent("CHAT_MSG_BN_INLINE_TOAST_BROADCAST", false);
		end--if register

	elseif (BackgroundEvent == "IFTHEN_AFKORDND") then
		if (register == true) then
			IfThen:Register_BackgroundEvent("PLAYER_FLAGS_CHANGED", true); --register for the background event
		else
			if (cache_Background["IFTHEN_PVP"] ~= true) then
				--IFTHEN_PVP also uses the same background event, we therefore must be careful not to unregister if that is still using it.
				IfThen:Register_BackgroundEvent("PLAYER_FLAGS_CHANGED", false); --unregister from the background event
			end--if
		end--if register

	elseif (BackgroundEvent == "IFTHEN_PVP") then
		if (register == true) then
			IfThen:Register_BackgroundEvent("PLAYER_FLAGS_CHANGED", true); --register for the background event
		else
			if (cache_Background["IFTHEN_AFKORDND"] ~= true) then
				--IFTHEN_AFKORDND also uses the same background event, we therefore must be careful not to unregister if that is still using it.
				IfThen:Register_BackgroundEvent("PLAYER_FLAGS_CHANGED", false); --unregister from the background event
			end--if
		end--if register

	elseif (BackgroundEvent == "IFTHEN_UI_ERROR") then
		IfThen:Register_BackgroundEvent("UI_ERROR_MESSAGE", register); --register for the background events
		IfThen:Register_BackgroundEvent("UI_INFO_MESSAGE",  register);


	elseif (BackgroundEvent == "IFTHEN_LFGINVITE") then
		IfThen:Register_BackgroundEvent("LFG_PROPOSAL_SHOW", register); --register for the background events
		IfThen:Register_BackgroundEvent("PET_BATTLE_QUEUE_PROPOSE_MATCH",  register);
		IfThen:Register_BackgroundEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",  register);


	elseif (BackgroundEvent == "TRADE_SKILL_SHOW") then
		IfThen:Register_BackgroundEvent("TRADE_SKILL_SHOW", register); --register for the background event


	elseif (BackgroundEvent == "IFTHEN_TIMER") then
		IfThen:Register_BackgroundEvent("IFTHEN_TIMER", register); --register for the background event, IFTHEN_TIMER event is then automatically raised by IfThen:OnEvent_OnUpdate() every 100ms


	elseif (BackgroundEvent == "IFTHEN_TICK_COUNTDOWN") then
		if (register == true) then
			IfThen:Register_BackgroundEvent("IFTHEN_TICK", true); --register for the background event, IFTHEN_TICK event is then automatically raised by IfThen:OnEvent_OnUpdate() every 1 seconds
		else
			if (cache_Background["IFTHEN_TICK_STOPWATCH"] ~= true and cache_Background["IFTHEN_SCREENSHOT1"] ~= true) then
				--IFTHEN_TICK_STOPWATCH and IFTHEN_SCREENSHOT1 also uses the same background event, we therefore must be careful not to unregister if they are still using it.
				IfThen:Register_BackgroundEvent("IFTHEN_TICK", false); --unregister from the background event
			end--if
		end--if register

	elseif (BackgroundEvent == "IFTHEN_TICK_STOPWATCH") then
		cache_Countdown = nil; --Reset this internal flag whenever we create or teardown this event
		if (register == true) then
			IfThen:Register_BackgroundEvent("IFTHEN_TICK", true); --register for the background event, IFTHEN_TICK event is then automatically raised by IfThen:OnEvent_OnUpdate() every 1 seconds
		else
			if (cache_Background["IFTHEN_TICK_COUNTDOWN"] ~= true and cache_Background["IFTHEN_SCREENSHOT1"] ~= true) then
				--IFTHEN_TICK_COUNTDOWN and IFTHEN_SCREENSHOT1 also uses the same background event, we therefore must be careful not to unregister if they are still using it.
				IfThen:Register_BackgroundEvent("IFTHEN_TICK", false); --unregister from the background event
			end--if
		end--if register

	elseif (BackgroundEvent == "IFTHEN_SCREENSHOT1") then
		if (register == true) then
			IfThen:Register_BackgroundEvent("IFTHEN_TICK", true); --register for the background event, IFTHEN_TICK event is then automatically raised by IfThen:OnEvent_OnUpdate() every 1 seconds
		else
			if (cache_Background["IFTHEN_TICK_COUNTDOWN"] ~= true and cache_Background["IFTHEN_TICK_STOPWATCH"] ~= true) then
				--IFTHEN_TICK_COUNTDOWN and IFTHEN_TICK_STOPWATCH also uses the same background event, we therefore must be careful not to unregister if they are still using it.
				IfThen:Register_BackgroundEvent("IFTHEN_TICK", false); --unregister from the background event
			end--if
		end--if register

	elseif (BackgroundEvent == "IFTHEN_SCREENSHOT2") then
		IfThen:Register_BackgroundEvent("SCREENSHOT_SUCCEEDED",	register); --register for the background events
		IfThen:Register_BackgroundEvent("SCREENSHOT_FAILED",	register);
	end

	--cleanup is handeled in Methods:BackgroundEvent()
	cache_Background[BackgroundEvent] = true; --internal flag set
	if (TearDown==true) then cache_Background[BackgroundEvent] = nil end --internal flag reset
	return nil;
end


--EventHandler that is raised by background event(s) after various events/functions have been called
function Methods:BackgroundEvent(EventName, ...)
	--This method wil contain a lot of custom code that will have to handle various background scenarios that occurs after some event or funcion has been called
	--The idea here is that we setup and teardown events quickly so that we have as little overhead as possible.

	--do_AcceptGroup()
	if (cache_Background["ACCEPT_GROUP"] ~= nil and EventName == "GROUP_ROSTER_UPDATE") then
			--Started in: do_AcceptGroup()
			--Description:	Calling the line below just after AcceptGroup() would cause us to not get accepted into the party.
			--				We need to wait for the GROUP_ROSTER_UPDATE event to be raised first before we call this function that will hide the Accept/Decline dialogue box
			StaticPopup_Hide("PARTY_INVITE"); --this will hide the Yes/No invitation dialogue that appears when you recive an invite

			self:Setup_BackgroundEvent("ACCEPT_GROUP", true); --tear down the background event

	elseif (cache_Background["IFTHEN_SAVEDINSTANCE"] ~= nil and EventName == "UPDATE_INSTANCE_INFO") then
			--Started in: getSavedInstances()
			--Description:	We need to wait for the UPDATE_INSTANCE_INFO after the RequestRaidInfo() has been called
			cache_SavedInstances = time(); --Timestamp updated

			self:Setup_BackgroundEvent("IFTHEN_SAVEDINSTANCE", true); --tear down the background event

	elseif (cache_Background["IFTHEN_CHAT_MSG"] ~= nil and StringParsing:startsWith(EventName, "CHAT_MSG_")) then
			--Started in: IfThen:OnEvent() (startup of the addon)
			--Description:	We have 15 events that all trigger for various chat channels, we hovever have merged them all into 1 event in IfThen and use a simple filter to tell the difference.
			--				If any of the CHAT_MSG_* events trigger then we just call OnEvent('IFTHEN_CHAT_MSG')
			--				We never unregister from these Background events (until ReInit is done)
			--				The CHAT_MSG_BN_* events have a slightly different method signature to the CHAT_MSG_* so we reformat them here

			if (StringParsing:startsWith(EventName, "CHAT_MSG_BN_")) then
				--Battle.net events do not have the exact same signature like other channels so we neeed to reformat it here so that it matches the rest of them

				--CHAT_MSG_BN_WHISPER					("message", "realid name of sender", "", "", 				"", "", 0, 0, 								"", 0, 2069, "", 45 (bnetIDAccount of sender), false)
				--CHAT_MSG_BN_INLINE_TOAST_BROADCAST	("message", "realid name of sender", "", "",				"", "", 0, 0,								"", 0, 2111, "", 45 (bnetIDAccount of sender), false")
				local strMessage	= select(1, ...);
				local strSender		= "BATTLE.NET:"..select(13, ...)..":"..select(2, ...); --format: "BATTLE.NET:bnetIDAccount:realid-name" (We prepend BATTLE.NET so that we later can in use the correct color on the link and use the correct BN functions)
				local intChannelNum = tonumber(tostring(select(8, ...)));
				local strChannel	= ""; --channel-name is not used by Battle.Net

				if (intChannelNum ~= nil and intChannelNum == 0) then intChannelNum = nil; end	--if the channel is 0 then the field is not in use
				if (intChannelNum ~= nil) then intChannelNum = intChannelNum +10 end			--We need to add +10 to the channel number so that it matches that of the UI

				--CHAT_MSG_*	("message", "sender", "language", "channelString", "target", "flags", unknown, channelNumber, "channelName", unknown, counter)
				--1 message
				--2 sender
				--8 channelnumber
				--9 channelname
				--We simply pre-pend the WOW eventname to the list of arguments (we know that there are 15 arguments for these events)
				IfThen_Parsing:Process_Event("IFTHEN_CHAT_MSG", EventName, strMessage,strSender,nil,nil,nil,nil,nil,intChannelNum,strChannel,nil,nil,nil,nil,nil,nil); --call the eventhandler
			else
				--We simply pre-pend the WOW eventname to the list of arguments (we know that there are 15 arguments for these events)
				IfThen_Parsing:Process_Event("IFTHEN_CHAT_MSG", EventName, ...); --call the eventhandler
			end--if

			--self:Setup_BackgroundEvent("IFTHEN_CHAT_MSG", true); --we never tear down this event once its running

	elseif ((cache_Background["IFTHEN_AFKORDND"] ~= nil or cache_Background["IFTHEN_PVP"] ~= nil) and EventName == "PLAYER_FLAGS_CHANGED") then
			--Started in: IfThen:OnEvent() (startup of the addon)
			--Description: PLAYER_FLAGS_CHANGED tell us about AFK/DND and PVP state, we use provide 2 different events for this

			IfThen_Parsing:Process_Event("IFTHEN_AFKORDND", ...);	--call the eventhandler
			IfThen_Parsing:Process_Event("IFTHEN_PVP", ...);		--call the eventhandler

			--self:Setup_BackgroundEvent("IFTHEN_AFKORDND", true);	--we never tear down this event once its running
			--self:Setup_BackgroundEvent("IFTHEN_PVP", true);		--we never tear down this event once its running

	elseif (cache_Background["IFTHEN_UI_ERROR"] ~= nil and EventName == "UI_ERROR_MESSAGE" or EventName == "UI_INFO_MESSAGE") then
			--Started in: IfThen:OnEvent() (startup of the addon)
			--Description: We have 2 events that tells us about UI messages. One for error- and one for info-messages, both have the same signature. We have merged these two into one event

			IfThen_Parsing:Process_Event("IFTHEN_UI_ERROR", ...); --call the eventhandler

			--self:Setup_BackgroundEvent("IFTHEN_UI_ERROR", true); --we never tear down this event once its running

	elseif (cache_Background["IFTHEN_LFGINVITE"] ~= nil and EventName == "LFG_PROPOSAL_SHOW" or EventName == "PET_BATTLE_QUEUE_PROPOSE_MATCH" or EventName == "LFG_LIST_APPLICATION_STATUS_UPDATED") then
			--Started in: IfThen:OnEvent() (startup of the addon)
			--Description: We have 3 events that tells us about when the LFG is done searching. They have no arguments and we have merged these into a single event

			if (EventName == "LFG_LIST_APPLICATION_STATUS_UPDATED") then
				local __id, newStatus, oldStatus = ...;
				--Status can be: "applied" just after you apply. Result can be "declined", "invited" or some sort of timeout, "invitedeclined" if the user clicks decline or "cancelled"
				if (strlower(newStatus) == "invited") then IfThen_Parsing:Process_Event("IFTHEN_LFGINVITE", ...); end --call the eventhandler
			else
				IfThen_Parsing:Process_Event("IFTHEN_LFGINVITE", ...); --call the eventhandler
			end--if
			--self:Setup_BackgroundEvent("IFTHEN_LFGINVITE", true); --we never tear down this event once its running

	elseif (cache_Background["TRADE_SKILL_SHOW"] ~= nil and EventName == "TRADE_SKILL_SHOW") then
			--Started in: IfThen:OnEvent() (startup of the addon)
			--Description:	We have to cache the tradeskill links from when the user opens up his/her tradeskill window
			local isLinked, name = C_TradeSkillUI.IsTradeSkillLinked();		--are we seeing our own list or someone else's?
			local id, tradeskillName, rank, maxLevel = C_TradeSkillUI.GetTradeSkillLine(); --get the name of the current opened tradeskill
			local link = C_TradeSkillUI.GetTradeSkillListLink();			--might return nil
			if (isLinked==false and tradeskillName~="UNKNOWN" and link~=nil) then
				if (cache_TradeSkill==nil) then cache_TradeSkill={} end	--just incase its nil then we set it to {}
				cache_TradeSkill[strlower(tradeskillName)] = link;
				IfThen:SetCache("TradeSkillLinks", cache_TradeSkill); --store to persistent cache aswell
			end --if we have our own tradeskill windows open then save it
			--self:Setup_BackgroundEvent("TRADE_SKILL_SHOW", true); --we never tear down this event once its running

	elseif (cache_Background["IFTHEN_TIMER"] ~= nil and EventName == "IFTHEN_TIMER") then
			--Started in: IfThen:OnEvent_OnUpdate() (is raised every 100ms)
			--Description: Every 100ms, this method will be called, we need to determine whether a timer has been expired and if so trigger it. If there are no more timers left we unregister from the event

			local booNil = true;
			local strKey = nil;
			local difftime = difftime; --local fpointer
			local pairs	= pairs;
			local c = time();
			for key,value in pairs(cache_TimerList) do
				if (value ~= nil) then booNil = false end
				local d = difftime(c, value[1]); --value == array: {time,seconds}
				if (d > value[2]) then
					--We must break out of the loop before we call Process_Event() or else we crash if we modify cache_TimerList while still in this loop
					strKey = key;
					break;
				end--if
			end--for
			if (strKey ~=nil) then
				--A token has expired, we call Process_Event() for the given timer
				cache_TimerList[strKey] = nil;
				IfThen_Parsing:Process_Event("IFTHEN_TIMER", strKey);
			end--if strKey

			if (booNil == true) then
				--No timers left in array, we stop listening for them
				cache_TimerList = {}; --reset to an empty array
				self:Setup_BackgroundEvent("IFTHEN_TIMER", true);
				IfThen:collectGarbage(); --This event eats up memory fast, so we do a GC after its done
			end --if booNil

	elseif (EventName == "IFTHEN_TICK") then
		--All the background events that use IFTHEN_TICK need to be using If and not ElseIf since ElseIf will only trigger a single block and not all of them.

		if (cache_Background["IFTHEN_TICK_COUNTDOWN"] ~= nil and EventName == "IFTHEN_TICK") then
			--Started in: IfThen:OnEvent_OnUpdate() (is raised every 1 seconds)
			--Description: Every 1 seconds, this method will be called

			if (cache_Countdown ~= nil) then
				--local channel = cache_Countdown[1];
				--local intStart = cache_Countdown[2];

				self:do_Chat(cache_Countdown[1],cache_Countdown[2]);	--output to chat
				cache_Countdown[2] = cache_Countdown[2]-1; --reduce by 1
				--self:do_Chat(channel,intStart);	--output to chat
				--intStart = intStart - 1;			--reduce by 1
				--if (intStart > 0) then
				if (cache_Countdown[2] > 0) then
					--cache_Countdown = {channel, intStart};	--continue if the coundown has not reached 0 yet
				else
					cache_Countdown = nil;					--reset the values
					self:Setup_BackgroundEvent("IFTHEN_TICK_COUNTDOWN", true); --teardown the background event
				end--if intStart
			end--if cache_Countdown
		end--if IFTHEN_TICK_COUNTDOWN

		if (cache_Background["IFTHEN_TICK_STOPWATCH"] ~= nil and EventName == "IFTHEN_TICK") then
			--Started in: IfThen:OnEvent_OnUpdate() (is raised every 1 seconds)
			--Description: Every 1 seconds, this method will be called

			if (StopwatchFrame ~= nil and StopwatchFrame:IsShown() ~= 1) then
				--The stopwatch frame is not shown, just do the teardown now.
				self:do_StopWatchStop("true");
			else
				if (StopwatchTicker ~= nil and StopwatchTicker.timer == 0) then --StopwatchTicker is a Blizzard object
					if (cache_StopWatch ~= nil) then
						self:do_StopWatchStop("true");	--this will hide the frame and also do the teardown the background event
						--cache_StopWatch = nil;		--reset the flag
					else
						cache_StopWatch = true; --We set flag and then let there pass 1 more second before we get invoked again. Then we hide the frame
					end--if cache_StopWatch
				end--if StopwatchTicker
			end--if StopwatchFrame
		end--if IFTHEN_TICK_STOPWATCH

		if (cache_Background["IFTHEN_SCREENSHOT1"] ~= nil and EventName == "IFTHEN_TICK") then
			--Started in: IfThen:OnEvent_OnUpdate() (is raised every 1 seconds)
			--Description: Every 1 seconds, this method will be called, but we stop it after the first call

			self:Setup_BackgroundEvent("IFTHEN_SCREENSHOT1", true); --tear down the background event for the first stage
			self:Setup_BackgroundEvent("IFTHEN_SCREENSHOT2", false); --setup the next stage of the chain of events
			Screenshot(); --Take the screenshot...
		end--if IFTHEN_SCREENSHOT1

	elseif (cache_Background["IFTHEN_SCREENSHOT2"] ~= nil and StringParsing:startsWith(EventName, "SCREENSHOT_")) then
			--Started in: IfThen:OnEvent() (raised after Screenshot() is completed)
			--Description: Will be called after Screenshot() has completed taking the screenshot.

			if (UIParent:IsVisible() == false) then UIParent:Show(); end --Show the user interface again
			self:Setup_BackgroundEvent("IFTHEN_SCREENSHOT2", true); --tear down the background event

	end--if

	return nil;
end


function Methods:SpellCheck(orgText)
	--if (cache_SpellCheckList == nil) then return orgText end --no text to replace
	local newText = tostring(orgText);

	newText = self:replaceTextureLinks(newText);--replace any textures found in the string
	newText = self:replaceHyperLinks(newText);	--replace any hyperlinks found in the string
	if (cache_SpellCheckList == nil) then return newText end --no text to replace

	local tostring = tostring; --local fpointer
	for i=1, #cache_SpellCheckList do
		local curr = cache_SpellCheckList[i];	--is always an array with 2 elements
		newText = StringParsing:replace(newText, tostring(curr[1]), tostring(curr[2]));
	end--for i

	return newText;
end


--####################################################################################
--####################################################################################
--Actions
--####################################################################################


--Set the macroName that do_ ***() functions will pass along to Macro: on their function call.
function Methods:do_SetMacroName(macroName)
	cache_MacroName = macroName;
	return nil;
end


--Rewrites macro without a /use or /cast at the end
function Methods:do_Nothing(t)
	return self:do_Something(nil, nil);
end


--Rewrites macro with a /cast at the end
function Methods:do_Cast(t)
	--if self:argumentCheck(t,"Cast",1,1) == false then return false end
	return self:do_Something("/cast", t[1]);
end


--Rewrites macro with a /use at the end
function Methods:do_UseItem(t)
	--if self:argumentCheck(t,"UseItem",1,1) == false then return false end
	return self:do_Something("/use", t[1]);
end


--Rewrites macro with a /click at the end
function Methods:do_ClickActionBar(t)
	--if self:argumentCheck(t,"ClickActionBar",1,2) == false then return false end

	local n			= "";
	local toolbar	= ""; --can be 'main' (default), 'extra', 'bottomleft, 'bottomright', 'right', 'right2' or 'stance'
	if (t ~= nil and #t>0) then n		= strtrim(strlower(t[1])) end
	if (t ~= nil and #t>1) then toolbar	= strtrim(strlower(t[2])) end

	local intN = tonumber(n);
	if (intN == nil) then
		IfThen:msg_error("Button argument for ClickActionBar() must be a number.");
		return false;
	end
	if (intN < 1 or intN > 12) then
		IfThen:msg_error("Button argument for ClickActionBar() must be a number between 1 and 12.");
		return false;
	end

	local r = "";
	if		toolbar == "extra"		then
		--TODO: These can have different names for their bars.
		local a, b, c, d, e = HasVehicleActionBar(), HasOverrideActionBar(), HasBonusActionBar(), IsPossessBarVisible(), HasExtraActionBar();
		if		a == true	then r = "OverrideActionBarButton";	--NOT confirmed
		elseif	b == true	then r = "OverrideActionBarButton";	--Confirmed.	Tillers faction uprooting weeds / Darkmoon faire whack-a-mole
		elseif	c == true	then r = "OverrideActionBarButton";	--NOT confirmed
		elseif	d == true	then r = "PossessButton";			--NOT confirmed
		elseif	e == true	then r = "ExtraActionButton";		--Confirmed.	Klaxxi Mind control enhancement / Raid abilities
		else					 r = "ExtraActionButton";		--Default
		end
	elseif	toolbar == "pet"		then	r = "PetActionButton"; --Warlocks
	elseif	toolbar == "right"		then	r = "MultiBarRightButton";
	elseif	toolbar == "right2"		then	r = "MultiBarLeftButton";
	elseif	toolbar == "bottomleft"	then	r = "MultiBarBottomLeftButton";
	elseif	toolbar == "bottomright"then	r = "MultiBarBottomrightButton";
	elseif	toolbar == "stance"		then	r = "StanceButton"; --Druids
	else									r = "ActionButton";	--Main toolbar
	end
	r = r..tostring(intN);	--Append the buttonnumber to the toolbarname
							--We do not check if the button is valid or not.

	return self:do_Something("/click", r); --Macro.lua will find "/click" in the string and try to lookup the icon texture.
end


--Rewrites macro with a /use at the end with the item associated with a given quest that the player has in his questlog
function Methods:do_UseQuestItem(t)
	local strlower = strlower; --local fpointer
	--if self:argumentCheck(t,"UseQuestItem",1,1) == false then return false end
	local strTitle  = "";
	if (#t >= 1) then strTitle = t[1]; end
	local n			= strtrim(strlower(strTitle));
	local qIndex	= nil;
	local qLink		= nil;
	local tmp		= nil;
	local GetQuestLogSpecialItemInfo = GetQuestLogSpecialItemInfo; --local fpointer

	if (n == "") then
		--no name specified, look for the first one in the tracked list that has a questitem
		local GetQuestIndexForWatch	= GetQuestIndexForWatch; --local fpointer
		local wMax					= GetNumQuestWatches();
		for i=1, wMax do
			tmp		= GetQuestIndexForWatch(i);
			qLink	= GetQuestLogSpecialItemInfo(tmp);
			if (qLink ~= nil) then
				qIndex = tmp;
				break;
			end
		end--for i

	else
		--iterate though quests and find a matcing title
		local GetQuestLogTitle	= GetQuestLogTitle; --local fpointer
		local qMax				= GetNumQuestLogEntries();
		for i=1, qMax do
			tmp = strlower(GetQuestLogTitle(i));
			if (n == tmp) then
				qIndex = i;
				break;
			end
		end--for i
	end

	if (qIndex == nil) then
		IfThen:msg_error("UseQuestItem()  Did not find the quest '"..strTitle.."' in your questlog.");
	else
		qLink = GetQuestLogSpecialItemInfo(qIndex);
		if (qLink == nil) then
			IfThen:msg_error("UseQuestItem()  No item is associated with the quest '"..strTitle.."'.");
		else
			local name = GetItemInfo(qLink);
			self:do_Something("/use", name);
		end--if qLink
	end--if qIndex
	return true; --always returns true
end


--Rewrites macro with a /cancelaura at the end
function Methods:do_CancelAura(t)
	--if self:argumentCheck(t,"CancelAura",1,1) == false then return false end

	if (InCombatLockdown() == true) then
		IfThen:msg_error("You are in combat. Can't do CancelAura('"..t[1].."') while in combat.");
		return false;
	end

	CancelUnitBuff("player", t[1]);
	return true;
	--return self:do_Something("/cancelaura", t[1]); --This is the same, just using the macro.
end


--Rewrites macro with a /cancelform at the end
function Methods:do_CancelForm(t)
	--if self:argumentCheck(t,"CancelForm",1,1) == false then return false end
	return self:do_Something("/cancelform", "");
end


--Rewrites macro with whatever text the user wants
function Methods:do_RawMacro(t)
	--RawMacro(Text,MacroName);
	local text		= t[1];
	local macroName	= nil;
	if (#t >= 2) then macroName = strtrim(t[2]); end
	if (macroName == nil or macroName == "") then macroName = cache_MacroName; end
	return Macro:update(macroName, "", "RAWMACRO", text, false);
end


--Just a wrapper for do_Nothing/Cast/Use/Click/Macro so that we dont have to repeat the same code thrice
function Methods:do_Something(extraCommand, extraItem)
	return Macro:update(cache_MacroName, nil, extraCommand, extraItem, true);
end


--Will accept the request for a duel
function Methods:do_AcceptDuel(t)
	--if self:argumentCheck(t,"AcceptDuel",0,0) == false then return false end
	AcceptDuel();
	StaticPopup_Hide("DUEL_REQUESTED"); --Dialog box is not hidden when AcceptDuel() is called so we must do that manually

	return true;
end


--Will accept the invite for a party or raid
function Methods:do_AcceptGroup(t)
	--if self:argumentCheck(t,"AcceptGroup",0,0) == false then return false end
	--Calling the code to hide the dialoge just after AcceptGroup() will cause us to not get into the party, we need to wait for the GROUP_ROSTER_UPDATE event to be raised first before we call this function
	self:Setup_BackgroundEvent("ACCEPT_GROUP");

	AcceptGroup();
	return true;
end


--Will try to automatically set all party/raidmember's roles based on their class
function Methods:do_AutoSetRoles(t)
	--if self:argumentCheck(t,"AutoSetRoles",0,0) == false then return false end

	--Are we in a party or raid?
	local i = self:InInstanceGroup(t);
	local b = self:InBattleGround(t);
	local p = self:InParty(t);
	local r = self:InRaid(t);

	local intMax  = 0;  --max number of party/raid memebers
	local strType = ""; --unit prefix

	if (i or b or r) then	--in a raid
		strType	= "raid";
		intMax	= GetNumGroupMembers();
		if (UnitIsGroupLeader("player") == false and UnitIsGroupAssistant("player") == false) then	--true,false or the inputted name
			IfThen:msg_error("AutoSetRoles() fails as you are not the raid leader or assistant.");
			return false;
		end--if

	elseif (p) then		--in a party
		strType	= "party";
		intMax	= GetNumGroupMembers();
		if (UnitIsGroupLeader("player") == false) then
			IfThen:msg_error("AutoSetRoles() fails as you are not the party leader.");
			return false;
		end--if

	else	--player is not grouped at all
		IfThen:msg_error("AutoSetRoles() fails as you are not in a group.");
		return false;
	end--if

	local strlower					= strlower; --local fpointer
	local tostring					= tostring;
	--local UnitClass				= UnitClass;
	local UnitSetRole				= UnitSetRole;
	local UnitGroupRolesAssigned	= UnitGroupRolesAssigned;
	local UnitGetAvailableRoles		= UnitGetAvailableRoles;

	--Iterate though all members of the party/raid
	for i=1, intMax do
		local strUnitID		= strType..tostring(i);
		local strCurRole = strlower(UnitGroupRolesAssigned(strUnitID));
		if (strCurRole == "none") then
				--Try with Blizzard's API;
				local canBeTank, canBeHealer, canBeDPS = UnitGetAvailableRoles(strUnitID);
				local strRole = "";
				if (canBeDPS == true)	 then strRole="damager"; end
				if (canBeHealer == true) then strRole="healer";	 end --if you can dps and heal we prefer heal
				if (canBeTank == true)	 then strRole="tank";	 end --if you can dps, heal and tank we prefer tank
				if (strRole ~= "") then UnitSetRole(strUnitID, strRole) end
		end--strCurRole
	end--for

	--[[
	FIX
	for i=1, intMax do
		local strUnitID		= strType..tostring(i);
		local xx, strClass	= UnitClass(strUnitID); --2nd argument is locale-agnostic
		if (strClass == nil or strClass == "") then
			strUnitID = "player";
			xx, strClass = UnitClass(strUnitID); --2nd argument is locale-agnostic
		end
		if (strClass ~= nil and strClass ~= "") then
			local strCurRole = strlower(UnitGroupRolesAssigned(strUnitID));
			if (strCurRole == "none") then
				--Try with Blizzard's API;
				local canBeTank, canBeHealer, canBeDPS = UnitGetAvailableRoles(strUnitID);
				local strRole = "";
				if (canBeTank==true  and canBeHealer==false and canBeDPS==false) then strRole="tank"    end
				if (canBeTank==false and canBeHealer==true  and canBeDPS==false) then strRole="healer"  end
				if (canBeTank==false and canBeHealer==false and canBeDPS==true)  then strRole="damager" end
				if (strRole ~= "") then UnitSetRole(strUnitID, strRole) end
			end--strCurRole
		end--strClass
	end--for]]

	return true;
end


--Sets the Cooldown Token value
function Methods:SetCoolDownToken(token, t)
	if (t ~= nil and type(t) == "table" and #t > 1 and t[2] ~= nil and strlen(strtrim(t[2])) > 0 ) then
		--if the user has specified a custom title then we use that
		token = "custom_title_" .. strtrim( strlower(t[2]) );
	end--if

	cache_LastCooldownToken = token;
	if (token == nil) then cache_CooldownList = {} end --if we receive nil then that means that we are to reset the whole tokenlist (called from Parsing:ParseText)

	--reduce the size of cache_CooldownList if it exceeds a threshhold value by expired tokens
	if (#cache_CooldownList > CONST_CooldownMaxSize) then
		local difftime	= difftime; --local fpointer
		local pairs		= pairs;
		local c	= time();
		for k,v in pairs(cache_CooldownList) do
			local d = difftime(c, v);
			if (d > CONST_CooldownMaxTime) then cache_CooldownList[k] = nil end --if any token is older than N seconds then clear it
		end--for
		--if we still after a cleanup got alot of tokens, then print a warning to the user
		if (#cache_CooldownList > CONST_CooldownMaxSize) then
			IfThen:msg_error("Warning: Cooldown() has now over "..tostring(#cache_CooldownList).." uniqe cases to track. Performance might decrease if this continues.")
		end--if
	end--if

	return nil;
end


--Will return True/False whether the Current token is still N seconds away from being finished
function Methods:do_Cooldown_TABLE(t) return self:do_Cooldown(t[1]); end
function Methods:do_Cooldown(intSeconds)
	--if self:argumentCheck(t,"Cooldown",1,1) == false then return false end
	local n = StringParsing:tonumber(intSeconds);
	if (n == nil) then
		IfThen:msg_error("Seconds argument for Cooldown() must be a number.)");
		return false;
	end --must be a number
	if (n < 1) then
		IfThen:msg_error("Seconds argument for Cooldown() can not be smaller than 1 second.)");
		return false;
	end --cant be less than 1 second
	if (n > CONST_CooldownMaxTime) then
		IfThen:msg_error("Seconds argument for Cooldown() can not exceed "..CONST_CooldownMaxTime.." seconds.)");
		return false;
	end --cant be larger than N seconds

	local currToken = cache_LastCooldownToken;
	if (currToken == nil) then return true end	--if the token hasn't been set then just return true to keep processing going

	local c = cache_CooldownList[currToken];
	if (c == nil) then --this token hasn't been seen before
		cache_CooldownList[currToken] = time();
		return true; --we return true now, the next time it's triggered we will have a timestamp to compare with
	else
		--token exists in our list, lets see if its expired
		local d = difftime(time(), c);
		if (d > n) then
			--token has expired, refresh it and return true until next time
			cache_CooldownList[currToken] = time();
			return true;
		else
			--token hasn't expired yet, return false and stop processing
			return false;
		end--if
	end--if

	--Parsing:Parse_If() and :Parse_Event() will set a uniqe token that allows us to identify the position we are currently at in the list of functions being executed
	--When we know the position, we can then lookup the last time that, the same related invokation of do_Cooldown() was done and compare it to the argument received.
	--If the timestamp recorded at the last invocation tells us that there has passed more than N seconds since the last call, then we return true, if it still hasnt' expired then we return false

	--This function is very useful if for example you have an line like this:
	--		OnEvent("Buff") AND HasBuff("Time Warp") THEN Print("Time Warp!!!");
	--That line will in practice be printing 'time warp' to the chatwindow several times because it will be triggered every time the buff event is raised.
	--By adding Cooldown("20") as the first statement then it will print 'time warp' once and then not until 20 seconds has passed.
	--		OnEvent("Buff") Cooldown("20") AND HasBuff("Time Warp") THEN Print("Time Warp!!!");

	return true;--will never be able to reach here
end


--Outputs a line in chat that count downs to 1
function Methods:do_Countdown(t)
	--if self:argumentCheck(t,"Countdown",2,3) == false then return false end
	local channel  = strtrim(strupper(t[1])); --AFK, DND, EMOTE, INSTANCE_CHAT, GUILD, OFFICER, PARTY, RAID, RAID_WARNING, YELL, SAY
	local strStart = strtrim(strlower(t[2])); --Number of seconds to countdown
	local strMessage = "";								 --Optional message
	if (#t >= 3) then strMessage = strtrim(t[3]); end

	local intStart = StringParsing:tonumber(strStart);
	if (intStart == nil) then
		IfThen:msg_error("Startvalue for Countdown() must be a number.");
		return false;
	end
	if (intStart < 1) then
		IfThen:msg_error("Startvalue for Countdown() must be a number higher than 1.");
		return false;
	end
	--CountDown ("Channel", Start, Message)

	--Output the message in the channel
	if (strMessage ~= "") then self:do_Chat(channel,strMessage) end

	--Set the cache_Countdown list with the values needed for the next call to chat (in 1 second from now)
	--	The rest of the code, the code that actually outputs the numbers are found in Methods:BackgroundEvent()
	cache_Countdown = {channel, intStart};
	self:Setup_BackgroundEvent("IFTHEN_TICK_COUNTDOWN", false); --setup the background event so that it will trigger

	return true;
end


--Show/Hide the DBM Range-radar
--[[REMOVED: Patch 7.1: Blizzard removed use of player coordinate functions inside instances.
function Methods:do_DBMRange(t)
	--if self:argumentCheck(t,"DBMRange",2,1) == false then return false end
	local strRange= strtrim(t[1]);	--Range
	local booShow = nil; --true, false or nil
	if (#t >= 2) then booShow = strtrim(strlower(t[2])); end
	if (booShow == "true" ) then booShow=true;  end
	if (booShow == "false") then booShow=false; end

	local intRange = StringParsing:tonumber(strRange);
	if (intRange == nil) then
		IfThen:msg_error("Range for DBMRange() must be a number.");
		return false;
	end
	if (intRange < 1) then
		IfThen:msg_error("Range for DBMRange() must be a number higher than 1.");
		return false;
	end

	local isLoaded1 = self:tryAndLoadAddon("DBM-Core");
	if (isLoaded1 == false) then
		IfThen:msg_error("DBMRange() can not proceed since 'Deadly Boss Mods - Core' is not loaded");
		return false;
	end--if

	if (booShow == nil) then
		local slash = SlashCmdList["DBMRANGE"]; --DBM will toggle the radar on/off by its own code
		if (slash == nil) then
			IfThen:msg_error("DBMRange() could not find the '/range' command");
			return false;
		end
		slash(intRange);
	else
		local objDBM = DBM; --Global DBM object.
		if (objDBM == nil) then
			IfThen:msg_error("DBMRange() could not find the 'DBM' object");
			return false;
		end
		local objRange = objDBM["RangeCheck"];
		if (objRange == nil) then
			IfThen:msg_error("DBMRange() could not find the 'DBM.RangeCheck' object");
			return false;
		end
		if (booShow == false) then objRange:Hide(true); end
		if (booShow == true)  then objRange:Show(intRange,nil,true,nil,true); end --if the user provides a value that is not supported, then DBM will show a warning.
	end
	return true;
end]]


--Creates a DBM-Timer
function Methods:do_DBMTimer(t)
	--if self:argumentCheck(t,"DBMTimer",3,2) == false then return false end
	local strMessage= strtrim(t[1]);--Text for the timer
	local strStart	= t[2];			--Number of seconds to countdown
	local booBroadcast = "false";
	if (#t >= 3) then booBroadcast = strtrim(strlower(t[3])); end
	if (booBroadcast == "true") then booBroadcast=true; else booBroadcast=false; end

	local intStart = StringParsing:tonumber(strStart);
	if (intStart == nil) then
		IfThen:msg_error("Startvalue for DBMTimer() must be a number.");
		return false;
	end
	if (intStart < 1) then
		IfThen:msg_error("Startvalue for DBMTimer() must be a number higher than 1.");
		return false;
	end

	local isLoaded1 = self:tryAndLoadAddon("DBM-Core");
	if (isLoaded1 == false) then
		IfThen:msg_error("DBMTimer() can not proceed since 'Deadly Boss Mods - Core' is not loaded");
		return false;
	end--if

	local slash = SlashCmdList["DEADLYBOSSMODS"]; --We call DBM by using the /dbm slashcommand
	if (slash == nil) then
		IfThen:msg_error("DBMTimer() could not find the '/dbm' command");
		return false;
	else
		if (booBroadcast == true) then	slash("broadcast timer "..tostring(intStart).." "..tostring(strMessage));	--/dbm broadcast timer <x> <message>
		else							slash("timer "..tostring(intStart).." "..tostring(strMessage)); end			--/dbm timer <x> <message>
		return true;
	end

	--DBM:CreatePizzaTimer(intStart, strMessage, booBroadcast);
	return true;
end


--Creates a DBM-Pull Timer
function Methods:do_DBMPull(t)
	--if self:argumentCheck(t,"DBMPull",1,1) == false then return false end
	local strStart	= t[1];			--Number of seconds to countdown
	local intStart = StringParsing:tonumber(strStart);
	if (intStart == nil) then
		IfThen:msg_error("Startvalue for DBMPull() must be a number.");
		return false;
	end
	if (intStart < 1) then
		IfThen:msg_error("Startvalue for DBMPull() must be a number higher than 1.");
		return false;
	end

	local isLoaded1 = self:tryAndLoadAddon("DBM-Core");
	if (isLoaded1 == false) then
		IfThen:msg_error("DBMPull() can not proceed since 'Deadly Boss Mods - Core' is not loaded");
		return false;
	end--if

	local slash = SlashCmdList["DEADLYBOSSMODS"]; --We call DBM by using the /dbm slashcommand
	if (slash == nil) then
		IfThen:msg_error("DBMPull() could not find the '/dbm' command");
		return false;
	else
		slash("pull "..tostring(intStart)); -- /dbm pull <x>
		return true;
	end
end


--Will accept the request for a duel
function Methods:do_DeclineDuel(t)
	--if self:argumentCheck(t,"DeclineDuel",0,0) == false then return false end
	CancelDuel();
	--StaticPopup_Hide("DUEL_REQUESTED"); --Dialog box is automatically hidden when not hidden when CancelDuel() is called

	return true;
end


--Will decline the invite for a party or raid
function Methods:do_DeclineGroup(t)
	--if self:argumentCheck(t,"DeclineGroup",0,0) == false then return false end
	DeclineGroup();

	StaticPopup_Hide("PARTY_INVITE"); --Will hide the dialoge option for party invite
	return true;
end


--Will dismount from the player's summoned mount
function Methods:do_Dismount(t)
	--if self:argumentCheck(t,"Dismount",0,0) == false then return false end
	Dismount();

	return true;
end


--Will summon a random or specified mount
function Methods:do_SummonMount(t)
	--if self:argumentCheck(t,"SummonMount",0,1) == false then return false end
	local n	= "";
	if (#t >= 1) then n = strtrim(strlower(t[1])); end

	if (InCombatLockdown() == true) then return false; end --Calls to C_MountJournal.SummonByID() while in combat does not cause a LUA error but we just as well check here too.

	if (n =="random" or n =="") then
		C_MountJournal.SummonByID(0); --Summon a random mount among those marked as favorites. Some logic is applied so it will favor flying above groundmounts mostly
		return true;
	else
		local intNum = C_MountJournal.GetNumMounts();
		if (intNum > 0) then
			local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID = nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil;
			for i=1, intNum do
				creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID = C_MountJournal.GetDisplayedMountInfo(i);
				if (n == strtrim(strlower(creatureName)) ) then
					C_MountJournal.SummonByID(mountID);
					return true;
				end
			end --for i
		end--if intNum
		return false;
	end--if n
end


--Will summon a random or specified pet
function Methods:do_SummonPet(t)
	--if self:argumentCheck(t,"SummonPet",0,1) == false then return false end
	local n	= "";
	if (#t >= 1) then n = strtrim(strlower(t[1])); end

	if (InCombatLockdown() == true) then return false; end --Calls to C_MountJournal.SummonByID() while in combat does not cause a LUA error but we just as well check here too.

	if (n =="random" or n =="") then
		C_PetJournal.SummonRandomPet(); --No argument: Summon a random pet in the pool marked as favorite. If no pets are marked as favorite nothing happens. If you add an argument it will pick from all the pets.
		--C_PetJournal.SummonRandomPet(true); --If you add an argument it will pick from all pets.
		return true;
	else
		local speciesID, strFirstGUID = C_PetJournal.FindPetIDByName(n); --if the speciesID provided isnt working then try looking it up using the name
		if (strFirstGUID ~= nil) then
			C_PetJournal.SummonPetByGUID(strFirstGUID);
			return true;
		end
		return false;
	end--if n
end


--Will perform a emote
function Methods:do_Emote(t)
	--if self:argumentCheck(t,"Emote",1,2) == false then return false end
	local strToken	= strupper(t[1]);
	local strUnit	= "player"; --only player or target are valid options.
	if (#t >= 2) then strUnit = strtrim(strlower(t[1])); end
	if (strUnit ~= "player") then strUnit = ""; end
	--[[
	DoEmote do not work with UnitID's as other functions.
	If strUnit has a value then it will to the solo emote (as if nothing was targeted).
	If strUnit is empty, then it will do the target emote; if you have something targeted, otherwise not.
	The only thing we can do then is to force the solo emote if 'player' is specified, anytime else its dynamic.
	]]--
	DoEmote(strToken, strUnit); --There are over 300 different emotes ingame, instead of checking against a large list at runtime we rely on the parser and STR[] in Documentation to filter invalid arguments at compile-time.
	return true;
end


--Will make the player equip the equipmentset named by argument.
function Methods:do_EnableEquipmentSet(t)
	--if self:argumentCheck(t,"EnableEquipmentSet",1,1) == false then return false end
	--NOTE: n is case sensitive here
	local n = t[1];
	if (n ~= "") then UseEquipmentSet(n) end

	return true;
end


--Will set the players active specialization to the value of argument.
function Methods:do_EnableSpec(t)
	--if self:argumentCheck(t,"EnableSpec",1,1) == false then return false end
	local strSpec = strtrim(strlower(t[1])); --Localized name of the spec.
	if (strSpec == "") then return false end

	local currI = GetSpecialization(); --Returns the index for the currently used spec (1,2,3,4).
	local ptr = GetSpecializationInfo; --local fpointer
	local id, name, description, icon, background, _, primaryStat = ptr(currI, false); --GetSpecializationInfo(specIndex, isInspect, isPet, instpecTarget, sex);
	if (name ~=nil and strlower(name) == strSpec) then return true end --If this spec is already enabled then skip the rest.

	for i=1, 5 do --HARDCODED: 2016-05-16 (Legion beta 7.0.3). Harcoded i to go from 1 to 5
		id, name, description, icon, background, _, primaryStat = ptr(i, false); --GetSpecializationInfo(specIndex, isInspect, isPet, instpecTarget, sex);
		if (name ~=nil and strlower(name) == strSpec) then
			SetSpecialization(i,false); --Will start casting the change specialization spell
			return true;
		end--if
	end--for i

	return false;
end


--Will equip the item on the player named by argument.
function Methods:do_EquipItem(t)
	--if self:argumentCheck(t,"EquipItem",1,1) == false then return false end
	--n = strtrim(strlower(n));
	local n = t[1];
	if (n ~= "") then EquipItemByName(n) end

	return true;
end


--Send a chat message to either /instance, /party or /raid depending if you are currently in a raid or party
function Methods:do_Group_TABLE(t) return self:do_Group(t[1]); end
function Methods:do_Group(strMessage)
	--if self:argumentCheck(t,"Group",1,1) == false then return false end
	local n = strMessage;
	if (strlen(n) == 0) then return false end --no message to print
	local i = self:InInstanceGroup(nil);
	local b = self:InBattleGround(nil);
	local p = self:InParty(nil);
	local r = self:InRaid(nil);
	if (i==false and b==false and p==false and r==false) then return false end --incase we're not in a battleground, part or raid at all

	local c = "";
	if (b==false and p==true and r==false)	then c = "PARTY"; end			--send to /party if we're in a party
	if (b==false and r==true and p==false)	then c = "RAID"; end			--send to /raid if we're in a raid
	if (i==true or b==true) 				then c = "INSTANCE_CHAT"; end	--send to /instance if we're in a instancegroup or battleground
	--if (p and r) then IfThen:msg_error("You are both in a Party and a Raid at the same time, What the hell is going on?!?!?!") end

	return self:do_Chat(c,n); --this function is basically a wrapper around Methods:do_Chat() for PARTY and RAID
end


--Send a chat message to /guild
function Methods:do_Guild(t)
	--if self:argumentCheck(t,"Guild",1,1) == false then return false end
	local n = t[1];
	if (strlen(n) == 0) then return false end --no message to print

	if (not self:InGuild()) then return false end
	return self:do_Chat("GUILD", n); --this function is basically a wrapper around Methods:do_Chat() for GUILD
end


--Will mark the unit or current target with a raid marker
function Methods:do_MarkTarget(t)
	--if self:argumentCheck(t,"MarkTarget",1,2) == false then return false end
	local mark = strtrim(strlower(t[1]));
	local strUnit = "target";
	if (#t >= 2) then strUnit = strtrim(strlower(t[1])); end

	local index = 0;		--no mark
	if (mark == "star")		then index = 1 end
	if (mark == "circle")	then index = 2 end
	if (mark == "diamond")	then index = 3 end
	if (mark == "triangle")	then index = 4 end
	if (mark == "moon")		then index = 5 end
	if (mark == "square")	then index = 6 end
	if (mark == "cross")	then index = 7 end
	if (mark == "skull")	then index = 8 end

	--Note: this function seems to only work properly if use use player, target, focus, pet
	SetRaidTarget(strUnit, index);
	return true;
end


--Will display the argument in a messagebox.
function Methods:do_Message(t)
	--if self:argumentCheck(t,"Message",1,1) == false then return false end
	local text = t[1];
	--text = self:replaceTextureLinks(text);
	text = self:inputRaidTextureLinks(text); --Replace {star} with the proper texture
	text = self:replaceHyperLinks(text);
	message(text);
	return true;
end


--Send a chat message to /officer
function Methods:do_Officer(t)
	--if self:argumentCheck(t,"Officer",1,1) == false then return false end
	local n = t[1];
	if (strlen(n) == 0) then return false end --no message to print

	if (not self:InGuild()) then return false end
	return self:do_Chat("OFFICER", n); --this function is basically a wrapper around Methods:do_Chat() for GUILD
end


--Returns an array of title/filename of audio files we support
function Methods:get_PlayAudioList(LowerCase)
	--returned cached result for performance if its available
	if (LowerCase == nil and cache_PlayList_Normal ~=nil) then return cache_PlayList_Normal end
	if (LowerCase ~= nil and cache_PlayList_Lower  ~=nil) then return cache_PlayList_Lower end
	return self:get_PlayAudioListDeclare(LowerCase);
end
function Methods:get_PlayAudioListDeclare(LowerCase)
	--returned cached result for performance if its available
	--if (LowerCase == nil and cache_PlayList_Normal ~=nil) then return cache_PlayList_Normal end
	--if (LowerCase ~= nil and cache_PlayList_Lower ~=nil) then return cache_PlayList_Lower end
	local p = {};

	--Sounds
	p["Alarm 1"]			= "Sound\\Interface\\AlarmClockWarning1.ogg";
	p["Alarm 2"]			= "Sound\\Interface\\AlarmClockWarning2.ogg";
	p["Alarm 3"]			= "Sound\\Interface\\AlarmClockWarning3.ogg";
	p["Archanite Ripper"]	= "Sound\\Events\\ArchaniteRipper.ogg";
	p["AuctionWindowOpen"]	= "Sound\\Interface\\AuctionWindowOpen.ogg";
	p["Baby Murloc"]		= "Sound\\Creature\\BabyMurloc\\BabyMurlocDance.ogg";
	p["Bell - Alliance"]	= "Sound\\Doodad\\BellTollAlliance.ogg";
	p["Bell - Horde"]		= "Sound\\Doodad\\BellTollHorde.ogg";
	p["Bell - Night Elf"]	= "Sound\\Doodad\\BellTollNightElf.ogg";
	p["Bell - Shays"]		= "Sound\\Spells\\ShaysBell.ogg";
	p["Bonestorm"]			= "Sound\\Creature\\LordMarrowgar\\IC_Marrowgar_WW01.ogg";
	p["Cartoon FX"]			= "Sound\\Doodad\\Goblin_Lottery_Open03.ogg";
	p["Cheer"]				= "Sound\\Event Sounds\\OgreEventCheerUnique.ogg";
	p["Cheering"]			= "Sound\\Events\\GuldanCheers.ogg";
	p["Clockwork Gnome"]	= "Sound\\Creature\\ClockworkGiantPet\\ClockWorkGianttPet_Clickable_01.ogg";
	p["Cow"]				= "Sound\\Creature\\Cow\\CowWound.ogg";
	p["Ding"]				= "Sound\\Creature\\Mandokir\\VO_ZG2_MANDOKIR_LEVELUP_EVENT_01.ogg";
	p["Explosion"]			= "Sound\\Doodad\\Hellfire_Raid_FX_Explosion05.ogg"
	p["Fel Nova"]			= "Sound\\Spells\\SeepingGaseous_Fel_Nova.ogg";
	p["Fel Portal"]			= "Sound\\Spells\\Sunwell_Fel_PortalStand.ogg";
	p["Felreaver"]			= "Sound\\Creature\\FelReaver\\FelReaverPreAggro.ogg";
	p["Ghostly Laugh"]		= "Sound\\Creature\\BabyLich\\GhostlySkullPetLaugh.ogg";
	p["Gnome Male Roar"]	= "Sound\\Character\\PlayerRoars\\CharacterRoarsGnomeMale.ogg";
	p["Gruntling horn"]		= "Sound\\Events\\gruntling_horn_bb.ogg";
	p["Headless"]			= "Sound\\Creature\\HeadlessHorseman\\Horseman_Laugh_01.ogg";
	p["Heads roll"]			= "Sound\\Creature\\Mandokir\\VO_ZG2_MANDOKIR_DECAPITATE_02.ogg";
	p["Heroism"]			= "Sound\\Spells\\Heroism_Cast.ogg";
	p["Horn - Dwarf"]		= "Sound\\Doodad\\DwarfHorn.ogg";
	p["Horn - Scourge"]		= "Sound\\Events\\scourge_horn.ogg";
	p["Humm"]				= "Sound\\Spells\\SimonGame_Visual_GameStart.ogg";
	p["Ill be back"]		= "Sound\\Creature\\Hansgar\\VO_60_FR_HANSGAR_SPELL_03.ogg";
	p["Kara Bell Toll"]		= "Sound\\Doodad\\KharazahnBellToll.ogg";
	p["LevelUp"]			= "Sound\\Interface\\LevelUp.ogg";
	p["Magic Wand"]			= "Sound\\Item\\UseSounds\\iMagicWand1.ogg";
	p["Midsummer"]			= "Sound\\Spells\\MidSummer-TorchGameComplete.ogg";
	p["Mjau"]				= "Sound\\Creature\\Cat\\CatStepB.ogg";
	p["No escape"]			= "Sound\\Creature\\Kargath\\VO_60_HMR_KARGATH_SPELL2.ogg";
	p["Not prepared"]		= "Sound\\Creature\\Illidan\\BLACK_Illidan_04.ogg";
	p["Ogre Cheer"]			= "Sound\\Event Sounds\\OgreEventCheer1.ogg";
	p["Ogre Wardrum"]		= "Sound\\Event Sounds\\Event_wardrum_ogre.ogg";
	p["PVPFlagTakenHordeMono"] = "Sound\\Interface\\PVPFlagTakenHordeMono.ogg";
	p["Quit hitting yourself"] = "Sound\\Creature\\Hansgar\\VO_60_FR_HANSGAR_SPELL_01.ogg";
	p["ReadyCheck"]			= "Sound\\Interface\\ReadyCheck.ogg";
	p["Rubber Ducky"]		= "Sound\\Doodad\\Goblin_Lottery_Open01.ogg";
	p["Scream"]				= "Sound\\Events\\EbonHold_WomanScream4_01.ogg";
	p["Shadowmourne"]		= "Sound\\Spells\\ShadowMourne_Cast_High_02.ogg";
	p["Shing!"]				= "Sound\\Doodad\\PortcullisActive_Closed.ogg";
	p["Short Circuit"]		= "Sound\\Spells\\SimonGame_Visual_BadPress.ogg";
	p["Simon Chime"]		= "Sound\\Doodad\\SimonGame_LargeBlueTree.ogg";
	p["Simon Game"]			= "Sound\\Spells\\SimonGame_Visual_GameStart.ogg";
	p["Sindragosa Frost"]	= "Sound\\Spells\\Sindragosa_Xplosion_Frost_Impact_01.ogg";
	p["Sonar Ping"]			= "Sound\\Spells\\Spell_Uni_SonarPing_04.ogg";
	p["Squire horn"]		= "Sound\\Events\\squire_horn_bb.ogg";
	p["TalentScreenOpen"]	= "Sound\\INTERFACE\\TalentScreenOpen.ogg";
	p["Tick Tack"]			= "Sound\\Creature\\ChronoLordEpoch\\CS_Epoch_TimeWarp01.ogg";
	p["UI_BnetToast"]		= "Sound\\Interface\\UI_BnetToast.ogg";
	p["Unworthy"]			= "Sound\\Creature\\Gruul\\VO_60_FR_GRUUL_KILL01.ogg";
	p["War Drums"]			= "Sound\\Event Sounds\\Event_wardrum_ogre.ogg";
	p["Water Giant"]		= "Sound\\Character\\footsteps\\EnterWaterSplash\\EnterWaterGiantA.ogg";
	p["Water Medium"]		= "Sound\\Character\\footsteps\\EnterWaterSplash\\EnterWaterMediumA.ogg";
	p["Water Small"]		= "Sound\\Character\\footsteps\\EnterWaterSplash\\EnterWaterSmallA.ogg";
	p["Wham!"]				= "Sound\\Doodad\\PVP_Lordaeron_Door_Open.ogg";
	p["Yarrr"]				= "Sound\\Spells\\YarrrrImpact.ogg";
	p["You Will Die!"]		= "Sound\\Creature\\CThun\\CThunYouWillDIe.ogg";
	p["You fail"]			= "Sound\\Creature\\Kologarn\\UR_Kologarn_Slay02.ogg";

	--p["Omen: Aoogah!"] = "Interface\\AddOns\\Omen\\aoogah.ogg";

	--make a lowercase version of the whole list
	local pL = {};
	local strlower	= strlower; --local fpointer
	local pairs		= pairs;
	for title,path in pairs(p) do --key = title, value = path to soundfile
		pL[strlower(title)] = path;
	end--for p

	cache_PlayList_Normal = p; --save for cache later
	cache_PlayList_Lower = pL;

	if (LowerCase == true) then return pL end
	return p;
end


--Will play a soundfile from WoW's CASC files or for a shorthand alias
function Methods:do_PlayAudio(t)
	--if self:argumentCheck(t,"PlayAudio",1,1) == false then return false end
	local n = strtrim(t[1]);

	if (n == "") then return true end
	if (cache_PlayList_Lower == nil) then self:get_PlayAudioList(true); end
	local soundFile = cache_PlayList_Lower[strlower(n)];
	if (soundFile ~= nil) then
		PlaySoundFile(soundFile, "Master");
	else
		if (n ~= "") then PlaySoundFile(n, "Master") end --PlaySound()
	end--if

	return true;
end


--Kill all playing sounds
function Methods:do_StopAllSound(t)
	for i=1,600000 do
		StopSound(i);
	end
	return true;
end


--Will simply print() the argument.
function Methods:do_Print(t)
	--if self:argumentCheck(t,"Print",1,1) == false then return false end
	local n = t[1];
	local strColor = self:colorLookup("red"); --Red
	if (#t >= 2)		then strColor = self:colorLookup(t[2]); end
	if (strColor == nil)then strColor = self:colorLookup("red"); end --Red

	--n = self:replaceTextureLinks(n);	--replace any textures found in the string
	n = self:inputRaidTextureLinks(n); --replace {star} with the proper texture
	n = self:replaceHyperLinks(n);		--replace any hyperlinks found in the string
	--n = StringParsing:replace(n,"|r", "|r|c"..strColor); --replace any color reset's with the red color we are using
	n = gsub(n, "(|c)(........)", "");	--Clear any color strings from inside the string (SyntaxColor:ClearColor() function)
	n = gsub(n, "|r", "");				--Remove any color reset's
	print("    |c"..strColor..n.."|r");
	return true;
end


--Will display the argument in the RaidWarning frame
function Methods:do_RaidMessage(t)
	--if self:argumentCheck(t,"RaidMessage",1,2) == false then return false end
	--ChatTypeInfo["RAID_BOSS_EMOTE"] is a table that has a bunch of subtables with predefined colorinfo and other values in it
	local text = t[1];
	local color	= self:colorLookup("red"); --Red --hexColorToRGB()
	if (#t >= 2)		then color = self:colorLookup(t[2]); end
	if (color == nil)	then color = self:colorLookup("red"); end --Red

	--text = self:replaceTextureLinks(text);	--replace any textures found in the string
	text = self:inputRaidTextureLinks(text);	--replace {star} with the proper texture
	text = self:replaceHyperLinks(text);		--replace any hyperlinks found in the string
	text = StringParsing:replace(text, "|r", "|r|c"..color); --put the color behind any reset of color in the string
	text = "|c"..color..text.."|r";

	--Use the default color for the raidframe itself and rather use a color around the string.
	--This is because you can see multiple strings at once in the scrolling frame and then the last call to this funcion would color everything identical
	RaidNotice_AddMessage(RaidBossEmoteFrame, text, cache_RaidMessageColor);
	--PlaySound("RaidBossEmoteWarning", "Master"); --Blizzard UI also plays this sound when it shows a raidmessage
	return true;
end


--Send a whisper to the player that last sendt a /whisper
function Methods:do_Reply_TABLE(t) return self:do_Reply(t[1]); end
function Methods:do_Reply(strMessage)
	--if self:argumentCheck(t,"Reply",1,1) == false then return false end
	if (strlen(strMessage) == 0) then
		IfThen:msg_error("Expected argument for Reply() in the format: Reply(\"Message\"). Message was empty");
		return false;
	end

	if (cache_LastIncomingSender == nil) then
		IfThen:msg_error("Could not find a player to send the /reply to.");
		return false;
	end

	return self:do_Whisper(cache_LastIncomingSender, strMessage); --a /reply is just an automatic whisper
end


--Outputs a line in chat about an item, cooldown, faction reputation etc
function Methods:do_Report(t)
	--if self:argumentCheck(t,"Report",3,3) == false then return false end
	local channel = strtrim(strupper(t[1]));	--AFK, DND, EMOTE, GUILD, INSTANCE_CHAT, OFFICER, PARTY, RAID, RAID_WARNING, YELL, SAY, print, group, reply
	local strType = strtrim(strlower(t[2]));	--ITEM, COOLDOWN, HEALTH, POWER, BUFF, DEBUFF, REPUTATION, EXPERIENCE, CURRENCY, ITEMLEVEL, SAVEDINSTANCE, statistic.
	local itemName = t[3];						--name of item, spell, faction, currency, equipmentset to get ilevel for or statistic-title.
	local strUnit = "player";					--player, target, focus, pet.
	if (#t >= 4) then strUnit = strtrim(strlower(t[4])) end
	if (cache_Report == nil) then cache_Report = {"","",""}; end	--Table has 3 elements that are all empty
	for i=1, #cache_Report do cache_Report[i] = ""; end				--Just wipe all the fields in the table at start

	local strUnitName = GetUnitName(strUnit, false); --Name of the current unit
	if (strUnitName == nil) then strUnitName = "" end
	local strMessage = "";

	if (strType=="item") then
		local includeBank	 = false;
		local includeCharges = true;
		local count = StringParsing:numberFormat(GetItemCount(itemName, includeBank, includeCharges));
		local name, link = GetItemInfo(itemName); --will get us the link of the item

		if (count == nil or count == 0) then
			strMessage="'"..itemName.."' not found.";
		else
			if (count == 1) then
				strMessage=link.." 1 item.";
			else
				strMessage=link.." "..count.." items.";
			end --if count
			cache_Report[1] = link;
			cache_Report[2] = count;
		end--if

	elseif (strType=="cooldown") then
		--Maybe we are dealing with an item?
		local name, link = GetItemInfo(itemName);		 --Will get us the link of the item
		local itemID = self:getItemIDfromItemLink(link); --If we get an itemID then this is an item

		--Maybe we are dealing with a spell?
		local start, duration, enable = nil, nil, nil;
		if (itemID == nil) then
			start, duration, enable = GetSpellCooldown(itemName);
			link = GetSpellLink(itemName); --Will get us the link of the spell
		else
			start, duration, enable = GetItemCooldown(itemID);
		end

		--Format the output
		if (duration == nil) then
			strMessage="'"..itemName.."' not found.";
		else
			cache_Report[1] = link;
			cache_Report[2] = duration;
			if (duration == 0) then
				strMessage=link.." has no cooldown.";
			else
				duration = math_floor((duration - (GetTime()-start)) +0.5); --Calculate the remaining duration and round it to the nearest whole integer
				strMessage=link.." "..duration.." sec left on cooldown.";
				if (duration > 60) then
					local m = math_floor(duration / 60);		--Total minutes (integer rounded downwards)
					local s = duration - (m*60);				--Subtract total minutes and get leftover seconds
					strMessage=link.." "..m.." min "..s.." sec left on cooldown.";
					cache_Report[2] = m..":"..s;
				end
			end--if duration==0
		end--nil

	elseif (strType=="buff") then
		local link = GetSpellLink(itemName); --Will get us the link of the spell
		local name, rank, icon, count, dispelType, duration, expires, caster, isStealable, shouldConsolidate, spellID; -- = UnitAura("player", itemName, "", "HARMFUL|NOT_CANCELABLE|CANCELABLE");

		for i=1,100 do
			name, rank, icon, count, dispelType, duration, expires, caster, isStealable, shouldConsolidate, spellID = UnitAura(strUnit, i);
			if (name == nil) then break; end --no more found
			if (strtrim(strlower(name)) == itemName) then break; end --found the buff/debuff/spell/aura/item with the correct name
		end--if

		if (name == nil) then
			if (link == nil) then	strMessage="Buff '"..itemName.."' not found.";
			else					strMessage="Buff "..link.." not found.";		end
		else
			--[link] (dispeltype), (spellsteal is possible), Expires in n min, c sec
			if (link ~= nil) then	strMessage="Buff "..link;		cache_Report[1] = link;
			else					strMessage="Buff '"..name.."'";	cache_Report[1] = name; end

			cache_Report[2] = count;
			if (count >1)			then strMessage=strMessage.." ("..count.." stacks),"; end
			if (dispelType ~=nil)	then strMessage=strMessage.." ("..dispelType..")," end
			if (isStealable ==true)	then strMessage=strMessage.." (spellsteal is possible)," end

			if (expires ==0) then --If expires is 0 then it never expires.
				cache_Report[3] = expires;
				strMessage=strMessage.." Does not expire.";
			else
				expires = math_floor((expires - GetTime()) +0.5); --Calculate how much time remains and round it to the nearest whole integer
				cache_Report[3] = expires;
				if (expires > 60) then
					local m = math_floor(expires / 60);		--Total minutes (integer rounded downwards)
					local s = expires - (m*60);				--Subtract total minutes and get leftover seconds
					strMessage=strMessage.." Expires in "..m.." min "..s.." sec.";
					cache_Report[3] = m..":"..s;
				else
					strMessage=strMessage.." Expires in "..expires.." sec.";
				end --if duration
			end--if 0
		end --if nil
		if (strUnitName ~="") then strMessage = strUnitName.." "..strMessage; end

	elseif (strType=="reputation") then
		local rep = self:getFactionInfoByName(itemName); --Get the info of the faction or nil

		if (rep == nil) then
			strMessage="Faction '"..itemName.."' not found.";
		else
			cache_Report[1] = rep["Name"];				--Name should be localized already
			cache_Report[2] = rep["StandingLocalized"]; --We return the localised standing-name for %Report% variable
			cache_Report[3] = rep["PointsLeft"];

			--strMessage="Faction '"..rep["Name"].."' |c"..rep["StandingColor"]..rep["StandingLocalized"].."|r standing."; --Can't send colors in chat so this wont work
			if (rep["Friendship"]==false) then
				--Faction reputation
				if (rep["Standing"]=="Exalted") then
					strMessage="Faction '"..rep["Name"].."' -"..rep["Standing"].."- standing.";
					cache_Report[3] = ""; --No more points needed when at Exalted
				else
					strMessage="Faction '"..rep["Name"].."' -"..rep["Standing"].."- standing currently.";
					if (rep["PointsLeft"]==1) then	strMessage=strMessage.." Need "..rep["PointsLeft"].." point to reach "..rep["NextStanding"]..".";
					else							strMessage=strMessage.." Need "..StringParsing:numberFormat(rep["PointsLeft"]).." points to reach "..rep["NextStanding"].."."; end
				end--if standing
			else
				--Friendship reputation
				strMessage="Friendship with '"..rep["Name"].."' -"..rep["StandingLocalized"].."- standing currently.";
				if (rep["PointsLeft"] > 0) then --For friendships we don't display the name of the next rank since we can't determine it's name
					if (rep["PointsLeft"]==1) then	strMessage=strMessage.." Need "..rep["PointsLeft"].." point to reach the next rank.";
					else							strMessage=strMessage.." Need "..StringParsing:numberFormat(rep["PointsLeft"]).." points to reach the next rank."; end
				end--if PointsLeft
			end--if Friendship
		end--if nil

	elseif (strType=="experience") then
		local currLevel	= UnitLevel("player");	--Current players level
		local maxLevel	= GetMaxPlayerLevel();	--Depends on what expansion pack you have on your account (85 for Cata, 90 for MOP, 100 for WOD, 110 for Legion)

		if (currLevel == maxLevel) then
			strMessage="You are at the maximum level ("..tostring(maxLevel)..") available for your account.";
		else
			local nextLevel = currLevel + 1;
			local currXP	= UnitXP("player");		--Current xp value
			local maxXP		= UnitXPMax("player");	--Max xp for this level
			local XPLeft	= maxXP - currXP;		--How many xp points left until the next level
			--local restID, restName, restMultiplier	= GetRestState(); --1== rested, 2== normal
			--local restPstBonus						= (restMultiplier or 0) * 100;

			cache_Report[1] = tostring(currLevel); --We tostring() level values so that it wont be padded with .00 in variable lookup
			cache_Report[2] = XPLeft;
			cache_Report[3] = tostring(maxLevel);

			--currXP	= StringParsing:numberFormatK(currXP,nil,true); --Convert to a K/M number and round it
			--maxXP	= StringParsing:numberFormatK(maxXP,nil,true);
			XPLeft	= StringParsing:numberFormatK(XPLeft,nil,true);

			--strMessage="Experience Level "..tostring(currLevel).." ("..currXP.."/"..maxXP..") points currently. Need "..XPLeft.." points to reach level "..tostring(nextLevel)..".";
			strMessage="Experience Level "..tostring(currLevel)..". Need about "..XPLeft.." points to reach level "..tostring(nextLevel)..".";
			--if (restID == 1) then strMessage=strMessage.." ("..tostring(restPstBonus).."% rested bonus currently)."; else strMessage=strMessage.."."; end
		end--if currLevel

	elseif (strType=="statistic") then
		local stat = self:findStatisticByName(itemName, false); --Get the info for the statistic or nil

		if (stat == nil) then
			strMessage="Statistic with the name '"..itemName.."' not found.";
		else
			if (type(stat["Points"]) == "number") then	strMessage="Statistic '"..stat["Name"].."' has the value '"..StringParsing:numberFormat(stat["Points"]).."'.";  --'Points' is not always a number
			else										strMessage="Statistic '"..stat["Name"].."' has the value '"..stat["Points"].."'.";	end
			cache_Report[1] = stat["Name"];
			cache_Report[2] = stat["Points"];
		end--if nil

	elseif (strType=="currency") then
		local cur  = self:getCurrencyInfoByName(itemName); --Get the info of the currency or nil

		if (cur == nil) then
			strMessage="Currency '"..itemName.."' not found.";
		else
			local link = cur["Link"]; --might be nil
			if (link == nil) then link = cur["Name"] end

			if (cur["Amount"]==1) then
				strMessage="Currency "..link..". Have "..StringParsing:numberFormat(cur["Amount"]).." token.";
			else
				strMessage="Currency "..link..". Have "..StringParsing:numberFormat(cur["Amount"]).." tokens.";
			end--if amount

			cache_Report[1] = link;
			cache_Report[2] = cur["Amount"];
		end--if nil

	elseif (strType=="itemlevel") then
		local booTarget = false;
		if (itemName == "equipped") then itemName="" end

		if (strUnit == "player") then
			--itemName	= ""; --Whatever specified
			booTarget	= false;
		elseif (strUnit == "target") then
			itemName	= ""; --Not relevant
			booTarget	= true;
		else
			--itemName	= ""; --Whatever specified
			strUnit		= "player";
			booTarget	= false;
		end
		strUnitName	= GetUnitName(strUnit);
		if (strUnitName==nil) then strUnitName="" end

		local iLevel = self:getEquipmentItemLevel(itemName, booTarget); --Get the itemlevel or nil

		if (iLevel == nil) then
			if (itemName=="") then
				if (booTarget) then
					IfThen:msg_error("Itemlevel for currently equipped items on "..strUnit.." could not be calculated. Make sure you have done /inspect on the unit first.");
					return false;
				else
					IfThen:msg_error("Itemlevel for currently equipped items on "..strUnit.." could not be calculated.");
					return false;
				end--if booTarget
			else
				IfThen:msg_error("Itemlevel for equipmentset '"..itemName.."' could not be calculated. Equipment-set names are case-sensitive.");
				return false;
			end--if itemName
		else
			if (itemName=="") then
				if (booTarget) then
					strMessage="Itemlevel for currently equipped items on "..strUnitName.." is "..StringParsing:numberFormat(iLevel["EquippedRounded"])..".";
				else
					strMessage="Itemlevel for currently equipped items on "..strUnitName.." is "..StringParsing:numberFormat(iLevel["EquippedRounded"])..". ItemLevel for all items is "..StringParsing:numberFormat(iLevel["TotalRounded"])..".";
				end--if booTarget
			else
				strMessage="Itemlevel for equipmentset '"..itemName.."' for "..strUnitName.." is "..StringParsing:numberFormat(iLevel["EquippedRounded"])..". ItemLevel for all items is "..StringParsing:numberFormat(iLevel["TotalRounded"])..".";
			end--if itemName
			cache_Report[1] = strUnitName;
			cache_Report[2] = iLevel["EquippedRounded"];
		end--if nil


	elseif (strType=="savedinstance") then
		local strInstType = "all";	--can either be empty string/'all', 'party', 'raid' or 'world'
		if (itemName == "party")	then strInstType = "party" end
		if (itemName == "raid")		then strInstType = "raid" end
		if (itemName == "world")	then strInstType = "world" end

		local lstInstances, isASYNC = self:getSavedInstances(strInstType, channel);
		if (isASYNC == "ASYNC") then --Async call. Data will is re-queried from server now and returned soon. Will return now and then call ourself again in n seconds
			local callback = function() self:do_Report(t) end;
			C_Timer.After(2, callback); --Trigger function in N seconds from now
			strMessage = nil;
			return true; --Doing an Async call. Return immedialty; we call ourselves again in N seconds
		end

		if (lstInstances == nil) then
			if (strInstType=="all")			then strMessage="Not saved for any instances.";
			elseif (strInstType=="party")	then strMessage="Not saved for any party-instances.";
			elseif (strInstType=="raid")	then strMessage="Not saved for any raid-instances.";
			elseif (strInstType=="world")	then strMessage="Not saved for any world-bosses."; end
		else
			if (strInstType=="all")			then strMessage="Saved instances:";
			elseif (strInstType=="party")	then strMessage="Saved party-instances:";
			elseif (strInstType=="raid")	then strMessage="Saved raid-instances:";
			elseif (strInstType=="world")	then strMessage="Saved world-bosses:"; end

			--self:do_Chat(channel, strMessage);
			for i=1, #lstInstances-1 do
				local tt  = lstInstances[i]["link"];
				strMessage = self:do_MultiChat(channel,strtrim(strMessage), " "..tt..",");  --will output and split the text so that it won't get more than 255 chars per line
				strMessage = strtrim(strMessage).." "..tt..",";
			end--for i
			local tt  = lstInstances[#lstInstances]["link"];
			strMessage = self:do_MultiChat(channel,strtrim(strMessage), " "..tt.."."); --will output and split the text so that it won't get more than 255 chars per line
			strMessage = strtrim(strMessage).." "..tt..".";
			self:do_Chat(channel, strtrim(strMessage)); --print the remaining text

			local b, j = false, 1;
			strMessage = "";
			for i=1, #lstInstances-1 do
				if (j > #cache_Report) then break; end --no more than N %Report% variables available
				local tt  = lstInstances[i]["link"];
				b = self:do_MultiChat2(strtrim(strMessage), " "..tt..",");  --will output and split the text so that it won't get more than 255 chars per line
				if (b == false) then
					cache_Report[j] = strMessage;
					j = j+1;
					strMessage = "";
				else
					strMessage = strtrim(strMessage).." "..tt..",";
				end--if
			end--for i
			if (j <= #cache_Report) then --no more than N %Report% variables available
				local tt  = lstInstances[#lstInstances]["link"];
				b = self:do_MultiChat2(strtrim(strMessage), " "..tt.."."); --will output and split the text so that it won't get more than 255 chars per line
				if (b == false) then
					cache_Report[j] = strMessage;
					j = j+1;
					strMessage = "";
				else
					strMessage = strtrim(strMessage).." "..tt..".";
				end--if
				if (j <= #cache_Report) then cache_Report[j] = strMessage; end --no more than N %Report% variables available
			end--if
			strMessage = nil;
		end--if

	else
		IfThen:msg_error("Report() failed. '"..strType.."' is not a valid TYPE.");
		return false;
	end --if strType

	if (strMessage == nil) then
		return true;
	else
		return self:do_Chat(channel, strMessage);
	end
	--end--if
end


--Support function that returns true/false if the message + newText will go over the 255 char limit for chat.
function Methods:do_MultiChat2(strMessage, newText)
	local newLen = strlen(strMessage) + strlen(newText);
	if (newLen > 255) then return false; end --Chat lines can be max 255 char long
	return true;
end

--Support function that will print the message if the message + newText will go over the 255 char limit for chat.
function Methods:do_MultiChat(channel, strMessage, newText)
	if (strlower(channel) == "print") then return strMessage end --print can be any length

	local newLen = strlen(strMessage) + strlen(newText);
	if (newLen > 255) then --Chat lines can be max 255 char long
		self:do_Chat(channel, strMessage); --print the current text
		strMessage = ""; --reset the line
	end

	return strMessage;
end


--Will set the role of the player to either 'TANK' 'HEALER', 'DPS' or 'NONE'
function Methods:do_SetRole(t)
	--if self:argumentCheck(t,"SetRole",1,1) == false then return false end
	local n = strtrim(strlower(t[1]));
	if (n == "dps") then n = "damager" end

	local i = UnitSetRole("player", n);
	return true;
end


--Will enable/disable all sound, effects or music
function Methods:do_SetSound(t)
	if (#t > 0) then strType	= strtrim(strlower(t[1])) end --Type: 'Effects', 'Music' or 'All' (default)
	if (#t > 1) then strEnable	= strtrim(strlower(t[2])) end --Enabled: 'True', 'False' or 'Toggle' (default)
	local s_all		= tonumber(GetCVar("Sound_EnableAllSound"));--all sound is enabled/disabled
	local s_effects = tonumber(GetCVar("Sound_EnableSFX"));		--sound effects are enabled/disabled
	local s_music	= tonumber(GetCVar("Sound_EnableMusic"));	--music is enabled/disabled

	if (strEnable == "true") then
		s_all = 1;
		s_effects = 1;
		s_music = 1;
	elseif (strEnable == "false") then
		s_all = 0;
		s_effects = 0;
		s_music = 0;
	else --toggle
		if (s_all==0)	  then s_all=1 	 	else s_all=0 end
		if (s_effects==0) then s_effects=1	else s_effects=0 end
		if (s_music==0)	  then s_music=1	else s_music=0 end
	end--if strEnable

	if (strType == "all")			then SetCVar("Sound_EnableAllSound", s_all);
	elseif (strType == "effects")	then SetCVar("Sound_EnableSFX", s_effects);
	elseif (strType == "music")		then SetCVar("Sound_EnableMusic", s_music);
	end--if strType

	return true;
end


--Will create a new timer
function Methods:do_SetTimer(t)
	--if self:argumentCheck(t,"SetTimer",2,3) == false then return false end
	--Timer(title,seconds,type)
	local strTitle	= strtrim(strlower(t[1]));	--uniqe string to remember the timer by
	local strSec	= strtrim(strlower(t[2]));	--positive integer
	local intSec	= StringParsing:tonumber(strSec);
	local strType	= "ignore";								--either 'ignore' or 'overwrite'
	if (#t >= 3) then strType = strtrim(strlower(t[3]));	end

	if (intSec == nil) then
		IfThen:msg_error("Seconds argument for SetTimer() must be a number.");
		return false;
	end --must be a number
	if (intSec < 1) then
		IfThen:msg_error("Seconds argument for SetTimer() can not be smaller than 1 second.)");
		return false;
	end --cant be less than 1 second
	if (intSec > CONST_CooldownMaxTime) then
		IfThen:msg_error("Seconds argument for SetTimer() can not exceed "..CONST_CooldownMaxTime.." seconds.)");
		return false;
	end --cant be larger than N seconds


	strTitle = "timer_"..strTitle; --we add a prefix incase the timer title is a number so that we dont accidentally index the table
	local c = cache_TimerList[strTitle];
	if (c == nil) then --this token hasn't been seen before, create it
		cache_TimerList[strTitle] = {time(), intSec};
		self:Setup_BackgroundEvent("IFTHEN_TIMER", false); --turn on monitoring for timer ticks
	else
		if (strType == "overwrite") then
			cache_TimerList[strTitle] = {time(), intSec}; --overwrite the existing timer so it resets
			self:Setup_BackgroundEvent("IFTHEN_TIMER", false); --turn on monitoring for timer ticks
		end
	end--if

	--reduce the size of cache_TimerList if it exceeds a threshhold value by expired tokens
	if (#cache_TimerList > CONST_CooldownMaxSize) then
		local difftime = difftime; --local fpointer
		local pairs		= pairs;
		local c = time();
		for k,v in pairs(cache_TimerList) do
			local d = difftime(c, v[1]);
			if (d > CONST_CooldownMaxTime) then cache_TimerList[k] = nil end --if any token is older than N seconds then clear it
		end--for
		--if we still after a cleanup got alot of tokens, then print a warning to the user
		if (#cache_TimerList > CONST_CooldownMaxSize) then
			IfThen:msg_error("Warning: SetTimer() has now over "..tostring(#cache_TimerList).." unique cases to track. Performance might decrease if this continues.")
		end--if
	end--if

	return true; --the token is set/updated, we return immediately
end


--Will set the title of the player to nohing or the localized string
function Methods:do_SetTitle(t)
	--if self:argumentCheck(t,"SetTitle",1,1) == false then return false end
	local n = "";
	if (#t >= 1) then n = strtrim(strlower(t[1])); end

	if (n=="none" or n=="") then
		SetCurrentTitle(-1); --"-1" is "no title"
		return true;
	else
		local b = SetTitleByName(n); --Located in ..\FrameXML\PaperdollFrame.lua
		if (b==false) then SetTitleByName(" "..n); end --prefix with a space for some titles like "Assistant Professor %PLAYERNAME%"
		if (b==false) then SetTitleByName(n.." "); end --postfix with a space for some titles like "%PLAYERNAME% of Darnassus"
		return b;
	end--if n
end


--Will take a screenshot
function Methods:do_Screenshot(t)
	--if self:argumentCheck(t,"Screenshot",0,1) == false then return false end
	local strHide = "true";	--true or false
	if (t ~= nil and #t >= 1) then strHide = strtrim(strlower(t[1])); end
	local boolHide = true;
	if (strHide ~= "true") then boolHide = false; end

	if (boolHide) then
		--Hide UI, Wait 1 second for it to take effect, Take screenshot, Show UI again after screenshot has been taken
		if (UIParent:IsVisible() == true) then UIParent:Hide(); end
		self:Setup_BackgroundEvent("IFTHEN_SCREENSHOT1", false); --Rest of the process happens after 1 second in the background eventhandler.
		--Screenshot();	--Need to wait 1 second before we take the screenshot.
		--UIParent:Show();	--Need to wait for the SCREENSHOT_SUCCEEDED or SCREENSHOT_FAILED event to be raised first before we show the UI again.
	else
		--Just take the screenshot without hiding anything
		Screenshot();
	end--if
	return true;
end


--Will set a flag
function Methods:do_SetFlag(t)
	--if self:argumentCheck(t,"SetFlag",2,2) == false then return false end
	--SetFlag(title,value)
	local strTitle	= strtrim(strupper(t[1]));	--uniqe string to remember the flag by, all uppercase
	local strValue	= strtrim(strlower(t[2]));	--string, ignore letter-casing

	strTitle = "FLAG_"..strTitle;		--We add a prefix incase the flag title is a number so that we dont accidentally index the table
	cache_FlagList[strTitle] = strValue;--We don't check to see if it already exist, we simply set the value
	return true;
end


--Check the value of a flag
function Methods:Flag(t)
	--if self:argumentCheck(t,"Flag",2,3) == false then return false end
	--Flag(title,value,match)
	local strTitle	= strtrim(strupper(t[1]));	--Uniqe string to remember the flag by, all uppercase
	local strValue	= strtrim(strlower(t[2]));	--Ignore letter-casing
	local strFilter	= "exact";					--Can be 'exact', 'startswith' or 'indexof'. Defaults to 'exact'.
	if (#t >= 3) then strFilter = strtrim(strlower(t[3])); end

	strTitle = "FLAG_"..strTitle; --We add a prefix incase the flag title is a number so that we dont accidentally index the table
	local strFlagValue = cache_FlagList[strTitle];
	if (strFlagValue == nil) then return false; end --Doesn't exist

	return self:doCompare(strFlagValue, strValue, strFilter, true);
end


--Send a chat message to a given channel. Argument is in the format: 'Channel,Message'
function Methods:do_Chat_TABLE(t) return self:do_Chat(t[1],t[2]); end
function Methods:do_Chat(strChannel, strText)
	--if self:argumentCheck(t,"Chat",1,2) == false then return false end
	local channel = strtrim(strupper(strChannel)); --can be one of the following: AFK, INSTANCE_CHAT, DND, EMOTE, GUILD, OFFICER, PARTY, RAID, RAID_WARNING, YELL, SAY
	local text    = strText;
	if (strlen(text) == 0) then return true end --skip sending empty strings
	if (channel == "INSTANCE") then channel = "INSTANCE_CHAT"; end --Blizzard not beign consistent in their input arguments.

	local id, name = GetChannelName(channel); --tries to lookup the channel name, will return 0 as id if it wasnt found
	if (id ~=0) then channel = id end

	local n = tonumber(channel); --if the channel argument is a number then send to that channel
	if (n == nil) then
		if     (channel == "PRINT") then	self:do_Print({text});
		elseif (channel == "GROUP") then	self:do_Group(text);
		elseif (channel == "REPLY") then	self:do_Reply(text);
		else
			if (strlen(text) > 255) then text = strsub(text,1,255) end --truncate text if its more than 255 characters long
			text = self:replaceTextureLinks(text);
			text = self:replaceHyperLinks(text);
			if (self:channelNameCheck(channel) == true) then
				SendChatMessage(text, channel, nil, nil);
			else
				IfThen:msg_error("Channel-name '"..tostring(strChannel).."' does not exist.");
			end--if
		end--if
	else
		if (strlen(text) > 255) then text = strsub(text,1,255) end --truncate text if its more than 255 characters long
		text = self:replaceTextureLinks(text);
		text = self:replaceHyperLinks(text);

		if (n > 9) then
			--Chat channels of 10 and higher are Battle.Net channels (have to subtract 10 before sending tho);
			BNSendConversationMessage((n-10), text);
		else
			if (self:channelNameCheck(tostring(n)) == true) then
				SendChatMessage(text, "CHANNEL", nil, n);
			else
				IfThen:msg_error("Channel-name '"..tostring(strChannel).."' does not exist.");
			end--end
		end--if n
	end
	return true;
end


--Send a chat message to a given channel. Argument is in the format: 'Channel,Message'
function Methods:do_RandomChat_TABLE(t) return self:do_RandomChat(t[1],t[2]); end
function Methods:do_RandomChat(strChannel, strText)

	local arrText = StringParsing:split(strText, ";"); --split the string into parts
	if (arrText == nil) then return self:do_Chat(strChannel, strText); end --only 1 element in string to send

	local i = math_random(1, #arrText); --pick a random string in the table
	return self:do_Chat(strChannel, arrText[i]);
end


--Will toggle the display of the raid party frame
function Methods:do_ToggleRaidDisplay(t)
	--if self:argumentCheck(t,"ToggleRaidDisplay",1,1) == false then return false end
	local n = strtrim(strlower(t[1]));

	if (InCombatLockdown() == true) then
		--IfThen:msg_error("You are in combat. Can't run ToggleRaidDisplay() while in combat.");
		return false;
	end
	--CompactRaidFrameManager is the CompactRaidFrameContainer's parent and if that's hidden then this code will have no visual effect, so if this function is called and the raidframes isn't used then it will have no effect
	if (CompactRaidFrameContainer == nil) then return true end --incase the frame dosent exist.
	if (n == "show") then	CompactRaidFrameContainer:Show();
	else					CompactRaidFrameContainer:Hide(); end
	return true;
end


--Send a chat message to a given channel. Argument is in the format: 'Message,Player' or just 'Message' (will then send whisper to the current target)
function Methods:do_Whisper_TABLE(t) return self:do_Whisper(t[1],t[2]); end
function Methods:do_Whisper(strName, strMessage)
	--if self:argumentCheck(t,"Whisper",1,2) == false then return false end
	local name = strName;	--unitid or playername
	local text = strMessage;--the message

	local strUnit = GetUnitName(name, true); --try to resolve any unitid
	if (strUnit ~= nil and strUnit ~= "") then name = strUnit end

	--is it 'leader'?
	if (strupper(name) == "LEADER") then
		name = self:getLeaderName(true);
		if (name == nil) then
			IfThen:msg_error("Failed to send a whisper to 'leader', since you are not in a group.");
			return true;
		end
	end--if leader

	text = self:replaceTextureLinks(text);			--replace any textures found in the string
	text = self:replaceHyperLinks(text);			--replace any hyperlinks found in the string
	if (strlen(text) > 255) then text = strsub(text, 1, 255) end --truncate text if its more than 255 characters long

	if (StringParsing:startsWith(name,"BATTLE.NET")) then
		--This is a Battle.net name
		local tmpSplit = StringParsing:split(name,":"); --format: "BATTLE.NET:bnetIDAccount:realid-name"
		local bnetIDAccount = tmpSplit[2];				--We need the bnetIDAccount to send a whisper back to a player on Battle.Net

		--2016-03-23: Wow patch 6.2.4: Changes done to Battle.net. Removed 'presenceId' and instead added bnetIDAccount and bnetIDGameAccount types that are not interchangeable
		--TODO: Test this: http://us.battle.net/wow/en/forum/topic/20742784697
		--	Search for BNSendWhisper on page. Test this code with ppl on real realms
		--	local bnetIDGameAccount = select(6, BNGetFriendInfoByID(bnetIDAccount)); --check that the argument list for BNGetFriendInfoByID is correct
		--	local _,toonName, client, realmName = BNGetGameAccountInfo(bnetIDGameAccount);

		BNSendWhisper(bnetIDAccount, text);
	else
		SendChatMessage(text, "WHISPER", nil, name);
	end--if Battle.net
	return true;
end

--Invokes a Server-Side roll.
function Methods:do_Roll_TABLE(t) return self:do_Roll(t[1],t[2]); end
function Methods:do_Roll(strMin, strMax)
	--if self:argumentCheck(t,"Roll",2,0) == false then return false end
	local intMin	= StringParsing:tonumber(strMin);
	local intMax	= StringParsing:tonumber(strMax);

	--if no arguments we use 1 and 100
	if (intMin == nil or intMax == nil) then intMin = 1; intMax = 100; end

	--validate arguments
	--if (intMin == nil or intMax == nil) then IfThen:msg_error("All arguments for Roll() must be numbers.)");					return false; end --must be a number
	if (intMin == 0 and intMax == 0)	then IfThen:msg_error("You must provide values higher than 0 for Roll().");				return false; end --must be higher than 0
	if (intMin < 0 or intMin > 1000000)	then IfThen:msg_error("Min argument for Roll() must be between 0 and 1 000 000.");		return false; end --out of bounds
	if (intMax < 0 or intMax > 1000000)	then IfThen:msg_error("Max argument for Roll() must be between 0 and 1 000 000.");		return false; end
	if (intMin > intMax)				then IfThen:msg_error("Max argument for Roll() must be higher than the Min argument.");	return false; end

	RandomRoll(intMin,intMax); --initate a server-side random roll. Will output a standard message in chat
	return true;
end


--Generates a random number (client side).
function Methods:do_Random_TABLE(t) return self:do_Random(t[1],t[2]); end
function Methods:do_Random(strMin, strMax)
	--if self:argumentCheck(t,"Random",2,0) == false then return false end
	local intMin	= StringParsing:tonumber(strMin);
	local intMax	= StringParsing:tonumber(strMax);

	--if no arguments we use 1 and 100
	if (intMin == nil or intMax == nil) then intMin = 1; intMax = 100; end

	--validate arguments
	--if (intMin == nil or intMax == nil) then IfThen:msg_error("All arguments for Roll() must be numbers.)");					return false; end --must be a number
	if (intMin == 0 and intMax == 0)	then IfThen:msg_error("You must provide values higher than 0 for Random().");				return false; end --must be higher than 0
	if (intMin < 0 or intMin > 1000000)	then IfThen:msg_error("Min argument for Random() must be between 0 and 1 000 000.");		return false; end --out of bounds
	if (intMax < 0 or intMax > 1000000)	then IfThen:msg_error("Max argument for Random() must be between 0 and 1 000 000.");		return false; end
	if (intMin > intMax)				then IfThen:msg_error("Max argument for Random() must be higher than the Min argument.");	return false; end

	cache_RandomNumber = math_random(intMin,intMax); --Creates a random number. Can be retreived by using the %Random% variable.
	return true;
end


--Start StopWatch
function Methods:do_StopWatchStart_TABLE(t) return self:do_StopWatchStart(t[1],t[2],t[3],t[4]); end
function Methods:do_StopWatchStart(strHour, strMinute, strSecond, strHide)
	--if self:argumentCheck(t,"StopWatchStart",4,3) == false then return false end
	local intHour	= StringParsing:tonumber(strHour);
	local intMinute	= StringParsing:tonumber(strMinute);
	local intSecond	= StringParsing:tonumber(strSecond);
	local booHide	= strlower(tostring(strHide));--optional, true (default) or false

	--validate arguments
	if (booHide == "false") then booHide=false else booHide=true end
	if (intHour == nil or intMinute == nil or intSecond == nil)	then IfThen:msg_error("All arguments for StopWatchStart() must be numbers.");			return false; end --must be a number
	if (intHour == 0 and intMinute == 0 and intSecond == 0)		then IfThen:msg_error("You must provide values higher than 0 for StopWatchStart().");	return false; end --must be higher than 0
	if (intHour < 0 or intHour > 23)		then IfThen:msg_error("Hour argument for StopWatchStart() must be between 0 and 23.");		return false; end --out of bounds
	if (intMinute < 0 or intMinute > 59)	then IfThen:msg_error("Minute argument for StopWatchStart() must be between 0 and 59.");	return false; end
	if (intSecond < 0 or intSecond > 59)	then IfThen:msg_error("Seconds argument for StopWatchStart() must be between 0 and 59.");	return false; end

	--Setup the background event so that it will check for the stopwatch to be finished and then hide it
	if (booHide) then self:Setup_BackgroundEvent("IFTHEN_TICK_STOPWATCH", false); end

	--Set and start the stopwatch
	--		the Stopwatch_StartCountdown function supports inputting values higher and lower for hour,minute, second and so on, but we limit that in our API.
	Stopwatch_StartCountdown(intHour, intMinute, intSecond);	--this will set the value of the stopwatch and also show the Stopwatch frame if its hidden
	Stopwatch_Play();											--starts the countdown
	return true;
end


--Stop StopWatch
function Methods:do_StopWatchStop_TABLE(t) return self:do_StopWatchStop(t[1]); end
function Methods:do_StopWatchStop(strHide)
	--if self:argumentCheck(t,"StopWatchStop",0,1) == false then return false end
	local booHide = strlower(tostring(strHide));--optional, true (default) or false
	if (booHide == "false") then booHide=false else booHide=true end

	Stopwatch_Clear();	--Resets the stopwatch to 0 and stops the countdown
	if (booHide == true and StopwatchFrame ~= nil) then StopwatchFrame:Hide(); end --Hide the Stopwatch frame if its visible

	self:Setup_BackgroundEvent("IFTHEN_TICK_STOPWATCH", true); --teardown the background event
	return true;
end


--Pause StopWatch
function Methods:do_StopWatchPause()
	--if self:argumentCheck(t,"StopWatchPause",0,0) == false then return false end
	Stopwatch_Pause(); --Pause the stopwatch countdown
	return true;
end


--Resume StopWatch
function Methods:do_StopWatchResume()
	--if self:argumentCheck(t,"StopWatchResume",0,0) == false then return false end
	Stopwatch_Play(); --Resume the stopwatch countdown
	return true;
end


--Open TradeSkillUI
function Methods:do_OpenTradeSkill(t)
	--if self:argumentCheck(t,"OpenTradeSkill",1,1) == false then return false end
	local strProfession	= ""; --Profession name; localized name.
	if (t ~= nil and #t >=1) then strProfession = strtrim(strlower(t[1])) end

	--Does player have the specific profession learned?
		--All professions: Archaeology, Fishing, Engineering, Cooking, First Aid, Mining, Enchanting, Inscription, Alchemy, Jewelcrafting, Leatherworking, Blacksmithing, Tailoring, Herbalism, Skinning
		--Not usable with this function: Archaeology, Fishing
	local intProfession = -1; --the ProfessionID is only constant for the current player. (6 can be Mining on this char but 6==Enchanting on another char)
	local list = {GetProfessions()}; --Can't use #list for some reason, use 20 as hardcoded maxvalue
	local GetProfessionInfo = GetProfessionInfo; --local fpointer
	for i=1, 20 do --HARDCODED: 2016-05-15 (Legion beta 7.0.3) Cant use #list so we use a arbitrary value here.
		--need to wrap this in a pcall() since it sometimes for no reason just fails
		local b, name, texture, rank, maxRank, numSpells, spelloffset, skillLine, rankModifier = pcall(GetProfessionInfo, list[i]);--GetProfessionInfo(list[i]);
		if (b==true and strProfession == strtrim(strlower(name))) then
			if (texture == "INTERFACE\\ICONS\\trade_archaeology" or texture == "Interface\\Icons\\Trade_Fishing") then --HARDCODED: 2016-08-08 Archaeology and Fishing does not use the TradeSkill UI
				--print("professions that can't craft "..name);
				return false;
			end--if texture
			--print("player has "..name.. "  '"..texture.."'");
			intProfession = list[i];
			break;
		end--if b
	end--for i
	if (intProfession == -1) then return false; end --does not have the profession

	--Open the Tradeskill window...
	--Lookup spellID for Tradeskill.
		--A hardcoded table is not feasible since spellid's for each profession change with profession ranks (artisan, trade, master, etc)
		--For some profession the name of the spell does not match that of the profession (Mining -> spellname == "Mining Skills")
	--Try a simple lookup first
	local name, rank, icon, castingTime, minRange, maxRange, spellID = GetSpellInfo(strProfession); --To open the TradeSkill UI you need to cast the spell associated with that profession

	if (name == nil) then
		--Simple approach did not work. Try getting the spell name from the UI...
		local prof1, prof2, archaeology, fishing, cooking, firstAid = GetProfessions();
		local y = nil;
		if (intProfession == prof1)			then y = "PrimaryProfession1SpellButtonBottomSpellName";  end
		if (intProfession == prof2)			then y = "PrimaryProfession2SpellButtonBottomSpellName";  end
		if (intProfession == archaeology)	then y = "SecondaryProfession1SpellButtonRightSpellName"; end
		if (intProfession == fishing)		then y = "SecondaryProfession2SpellButtonRightSpellName"; end
		if (intProfession == cooking)		then y = "SecondaryProfession3SpellButtonRightSpellName"; end
		if (intProfession == firstAid)		then y = "SecondaryProfession4SpellButtonRightSpellName"; end

		if (y ~= nil and _G[y] ~= nil) then
			local n = _G[y]:GetText();
			--print("name found in UI "..tostring(n));
			name, rank, icon, castingTime, minRange, maxRange, spellID = GetSpellInfo(n); --Call again with the name found in the UI...
		end--if _G
	end

	if (spellID ~= nil) then
		--Start opening the TradeSkillUI
		--C_TradeSkillUI.CloseTradeSkill()
		--C_TradeSkillUI.OpenTradeSkill() --Does not work
		CastSpellByID(spellID); --Tradeskill spells are allowed by addons to cast at any time.
		return true;
	end
	return false;
end


--Close TradeSkillUI
function Methods:do_CloseTradeSkill(t)
	--if self:argumentCheck(t,"CloseTradeSkill",0,0) == false then return false end
	C_TradeSkillUI.CloseTradeSkill();
	return true;
end


--Craft an item (TradeSkillUI must already be open)
function Methods:do_Craft(t)
	--if self:argumentCheck(t,"Craft",1,2) == false then return false end
	local strRecipe		= ""; --Recipe name; localized name.
	local intRepeat		= 1;  --Number: 1 to 10000 (arbitrary maxvalue)
	if (t ~= nil and #t >=1) then strRecipe		= strtrim(strlower(t[1])) end
	--if (t ~= nil and #t >=2) then intRepeat	= tonumber(t[1]) end
	if (intRepeat < 1)		then intRepeat = 1; end
	if (intRepeat > 10000)	then intRepeat = 10000; end

	--Game does not accept callback to start crafting. Must be done in the 'hw'-event triggered thread.
	--Therefore we have OpenTradeskill() and Craft() as separate functions. Furthermore the intRepeat argument is not reliable. Only works sometimes. Therefore its not supported.
	if (C_TradeSkillUI.IsTradeSkillReady() ~= true) then return false; end--tradeskill not ready

	--Does player have the recipe learned?
	local tblRecipe = nil;
	local list = C_TradeSkillUI.GetAllRecipeIDs(); --After Tradeskill window is open, this will return all possible recipes for that profession. Filters in UI is ignored.
	for i=1, #list do
		local tblCurr = C_TradeSkillUI.GetRecipeInfo(list[i]);
		local name = strtrim(strlower(tostring( tblCurr["name"] )));
		if (name == strRecipe) then
			--print("found "..name.. " "..tblCurr.recipeID);
			tblRecipe = tblCurr;
			break;
		end--if name
	end--for i
	if (tblRecipe == nil) then
		--print("did not find "..strRecipe);
		return false;
	end--if

	--Is recipe craftable? (learned, got ingredients)
	if (tblRecipe.learned == false) then --recipe is learned by plager
		--print("recipe not learned "..strRecipe);
		return false;
	end--if learned

	if (tblRecipe.numAvailable < 1) then --number of items you can craft right now (ingredients are there)
		--print("ingredients not available "..strRecipe);
		return false;
	end--if numAvailable

	if (tblRecipe.craftable == false) then -- ??
		--print("not craftable "..strRecipe);
		return false;
	end--if craftable

	--Filters (have no effect on the ability to craft a recipe or not)
	--C_TradeSkillUI.ClearInventorySlotFilter();
	--C_TradeSkillUI.ClearRecipeSourceTypeFilter();
	--C_TradeSkillUI.ClearRecipeCategoryFilter();

	--Set repeat count
	if (intRepeat > tblRecipe.numAvailable) then intRepeat = tblRecipe.numAvailable; end --Don't overflow repeat
	C_TradeSkillUI.SetRecipeRepeatCount(tblRecipe.recipeID, intRepeat); --Works only sometimes. It's unreliable so we don't provide that option to the user

	--Craft the recipe
	--print("C_TradeSkillUI.CraftRecipe '"..strRecipe.."' ("..tblRecipe.recipeID..")  '"..intRepeat.."' time(s).");
	C_TradeSkillUI.CraftRecipe(tblRecipe.recipeID, intRepeat);
	return true;
end


--####################################################################################
--####################################################################################
--Support functions
--####################################################################################


--Support function that returns true/false whether a channel name/number is valid. Argument is expected to be a string and in uppercase letters
function Methods:channelNameCheck(channel)
	--Global channels: INSTANCE BATTLEGROUND GUILD OFFICER PARTY RAID RAID_WARNING YELL SAY WHISPER 1 2 3 4
	if (CONST_GlobalChatChannels[channel] ~= nil) then return true end --Channel is one of the global constants

	local strChannel, strChannelName, intInstanceID = GetChannelName(channel); --Lookup either by stringname or channel number
	if (strChannel ~= 0) then return true; end --this is a custom channel that exists

	return false; --no match on global channel names or custom channel name/number
end


--Support function used to lookup statistical/achievement info from it's title
function Methods:findStatisticByName(strStatisticName, booAchievement)
	strStatisticName = strtrim(strlower(strStatisticName));
	local arr = GetStatisticsCategoryList();
	if (booAchievement == true) then arr = GetCategoryList(); end

	local strlower	 					= strlower; --local fpointer
	local GetCategoryNumAchievements	= GetCategoryNumAchievements;
	local GetAchievementInfo			= GetAchievementInfo;

	for i=1, #arr do
		local id  = arr[i];
		local num = GetCategoryNumAchievements(id);

		for j=1, num do
			local _id, _name, _points = GetAchievementInfo(id, j);
			if (_name ~= nil and strlower(_name) == strStatisticName) then
				if (booAchievement ~= true) then _points = GetStatistic(_id); end
				--print ("_id; ".._id.." _name; '".._name.."' _points; '".._points.."' ");
				if (tonumber(_points) ~= nil) 						then _points = tonumber(_points) end	--try to cast to numbers if possible
				if (type(_points) == "string" and _points == "--")	then _points = 0; end					--convert '--' into 0
				return {["Id"]=_id, ["Name"]=_name, ["Points"]=_points};
			end--if
		end--for j
	end--for i

	return nil; --nothing found
end


--Support function used by do_Report that outputs a list of saved instances and their acronyms
function Methods:getSavedInstances(strInstanceType, strChannel)
	local d = difftime(time(), cache_SavedInstances); --Async: Request the latest instance info from the server if the data is too old
	if (d > 60) then
		self:Setup_BackgroundEvent("IFTHEN_SAVEDINSTANCE", false);
		return nil, "ASYNC";
	end

	strInstanceType = strtrim(strlower(strInstanceType));
	local res = {};
	if (strInstanceType == "party" or strInstanceType == "raid" or strInstanceType == "all") then
		--Party or Raid instances
		local GetSavedInstanceInfo		= GetSavedInstanceInfo; --local fpointer
		local GetSavedInstanceChatLink	= GetSavedInstanceChatLink;
		local numInstances = GetNumSavedInstances();
		for i=1, numInstances do
			local instanceName, instanceID, instanceReset, instanceDifficulty, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, maxBosses, defeatedBosses = GetSavedInstanceInfo(i);
			if (instanceReset <= 0) then instanceName = nil; end
			if (strInstanceType == "party" and isRaid == true)  then instanceName = nil; end
			if (strInstanceType == "raid"  and isRaid == false) then instanceName = nil; end

			if (instanceName ~= nil) then
				local tmp = {};
				tmp["name"] = instanceName;
				if (isRaid == false and strupper(strChannel) ~= "PRINT") then
					tmp["link"] = instanceName; --links for party instances will not be outputted by chat, but they are still there. We can therefore allow them when the user uses Print()
				else
					tmp["link"] = GetSavedInstanceChatLink(i);
				end
				--tmp["link"] = GetSavedInstanceChatLink(i);
				res[#res+1] = tmp;
			end--if instanceName
		end--for i
	end--if strInstanceType

	if (strInstanceType == "world" or strInstanceType == "all") then
		--World bosses. Added in patch 5.4
		--Does not work with WOD bosses. Blizzard bug.
		local GetSavedWorldBossInfo	= GetSavedWorldBossInfo; --local fpointer
		local savedWorldBosses		= GetNumSavedWorldBosses();
		for i=1, savedWorldBosses do
			local bossName, worldBossID, bossReset = GetSavedWorldBossInfo(i);
			if (bossName ~= nil) then
				local tmp = {};
				tmp["name"] = bossName;
				tmp["link"] = bossName;
				res[#res+1] = tmp;
			end--if bossName
		end--for i
	end--if strInstanceType

	if (#res == 0) then return nil end
	sort(res, function(a,b) return a["name"]<b["name"] end); --Sort alphabetically on the instance name

	return res, nil;
end



--Support function that pre-pads a number with the proper amount of 0's
function Methods:padNumber(intValue, intLength)
	local strValue = tostring(intValue);

	local strlen = strlen;
	for i=strlen(strValue), (intLength-1), 1 do
		strValue = "0"..strValue;
	end--for i

	return strValue;
end


--Support function that will lookup a string/numeric weeknumber value and return the opposite numeric/string value ("Saturday" returns 1 and 1 returns "Saturday")
function Methods:weekdayLookup(strValue, isNumeric, forceEnglish)

	local arrWeekday = {[1]=strlower(_G["WEEKDAY_SUNDAY"]), [2]=strlower(_G["WEEKDAY_MONDAY"]), [3]=strlower(_G["WEEKDAY_TUESDAY"]), [4]=strlower(_G["WEEKDAY_WEDNESDAY"]), [5]=strlower(_G["WEEKDAY_THURSDAY"]), [6]=strlower(_G["WEEKDAY_FRIDAY"]), [7]=strlower(_G["WEEKDAY_SATURDAY"])}; --Sunday=1
	if (forceEnglish ~=nil) then
		arrWeekday = {[1]="sunday", [2]="monday", [3]="tuesday", [4]="wednesday", [5]="thursday", [6]="friday", [7]="saturday"}; --Sunday=1
	end--if

	if (isNumeric == true) then
		local intValue = tonumber(strValue);
		if (intValue == nil) then return ""; end
		return arrWeekday[intValue];
	else
		if (strValue == nil) then return -1 end
		strValue = strtrim(strlower(strValue));
		for i=1, #arrWeekday do
			if (arrWeekday[i] == strValue) then return i end
		end--for i
		return -1; --error
	end
end


--Support function that will try to load the named addon and its dependencies. Returns false if it fails.
function Methods:tryAndLoadAddon(strAddonName)
	if (strAddonName == nil or strAddonName == "") then return false end

	--Is the addon loaded?
	local isLoaded = IsAddOnLoaded(strAddonName);
	if (isLoaded == true) then return true end --the addon is loaded, all is good

	--Can we load the addon without a /reload?
	local isLoadable = IsAddOnLoadOnDemand(strAddonName);
	if (isLoadable == false) then return false end --the addon can't be loaded without a /reload so we fail

	if (isLoadable == true) then
		EnableAddOn(strAddonName); --flag the addon as enabled if it should happen to be disabled...
		local lstDep = GetAddOnDependencies(strAddonName); --iterate though dependencies...
		if (lstDep ~= nil) then
			for i=1, select("#", lstDep) do
				self:tryAndLoadAddon( select(i, lstDep) ); --recursive call to ourself to try and load the dependency
			end--for i
		end--if lstDep
		local loaded, reason = LoadAddOn(strAddonName);	--will attempt to load the addon
		if (loaded == true) then return true end			--we sucessfully loaded the addon, so its all good now.
	end--if isLoadable

	return false;
end


--Support function that returns the name of the leader of the party/raid/battleground
function Methods:getLeaderName(showServerName)
	if (showServerName == nil) then showServerName = false end

	--Are we in a party or raid?
	local i = self:InInstanceGroup(t);
	local b = self:InBattleGround(t);
	local p = self:InParty(t);
	local r = self:InRaid(t);

	local intMax	= 0;  --max number of party/raid members
	local strType	= ""; --unit prefix

	if (i or b or r) then	--in a raid
		intMax = GetNumGroupMembers();
		strType = "raid";
	elseif (p) then		--in a party
		intMax = GetNumGroupMembers();
		strType = "party";
	else	--player is not grouped at all
		return nil;
	end--if

	local tostring			= tostring; --local fpointer
	local UnitIsGroupLeader	= UnitIsGroupLeader;
	--Iterate though all members of the party/raid
	for i=1, intMax do
		local strUnitID = strType..tostring(i);
		local intLeader = UnitIsGroupLeader(strUnitID); --true or false
		if (intLeader == true) then return GetUnitName(strUnitID, showServerName); end
	end--for
	--Seems that if you call UnitIsGroupLeader and you are the leader yourself then it will always return false
	local intLeader = UnitIsGroupLeader("player"); --try with 'player'
	if (intLeader == true) then return GetUnitName(strUnitID, showServerName); end

	return nil;
end


--Support function that returns true/false based on the input value's and the comparison operator: eq (default), gt, lt, gte, lte, neq
function Methods:doOP(strValue1, strValue2, strOP, ignoreCase, isNumeric)
	strOP = strtrim(strlower(strOP));

	local objValue1 = strValue1; --Are either stings or numbers
	local objValue2 = strValue2;

	if (ignoreCase == true) then
		objValue1 = strlower(strValue1);
		objValue2 = strlower(strValue2);
	end--if ignoreCase

	if (isNumeric == true) then
		objValue1 = StringParsing:tonumber(strValue1);
		objValue2 = StringParsing:tonumber(strValue2);
		if (objValue1 == nil or objValue2 == nil) then
			IfThen:msg_error("Failed to do numerical comparison since the values to be compared are not numbers: '"..strValue1.."', '"..strValue2.."'.");
			return false;
		end
	end--if isNumeric

	if (strOP == "eq") then
		if (objValue1 == objValue2) then return true end
	elseif (strOP == "gt") then
		if (objValue1 > objValue2) then return true end
	elseif (strOP == "lt") then
		if (objValue1 < objValue2) then return true end
	elseif (strOP == "gte") then
		if (objValue1 >= objValue2) then return true end
	elseif (strOP == "lte") then
		if (objValue1 <= objValue2) then return true end
	elseif (strOP == "neq") then
		if (objValue1 ~= objValue2) then return true end
	else
		--default comparison is 'eq'
		if (objValue1 == objValue2) then return true end
		--IfThen:msg_error("Failed to do comparison since '"..strOP.." is not an valid operator.");
		--return false;
	end--if
	return false;
end


--Support function that returns true/false based on the input value's and the comparison operator: indexof, startswith or equals (default)
function Methods:doCompare(strValue1, strValue2, strOperator, ignoreCase)
	local strlower = strlower; --local fpointer
	strOperator = strtrim(strlower(strOperator));
	if (ignoreCase == true) then
		strValue1 = strlower(strValue1);
		strValue2 = strlower(strValue2);
	end
	if (strOperator =="indexof") then
		if (StringParsing:indexOf(strValue1, strValue2, 1) == nil) then return false end --not even found an occurrence of the Value2 inside Value1
	elseif (strOperator =="startswith") then
		if (not StringParsing:startsWith(strValue1, strValue2)) then return false end --not a partial match either from the start
	else --default is a plain and simple comparison
		if (not (strValue1 == strValue2)) then return false end --not an exact match
	end--strOperator
	return true;
end


--Support function that returns the hex value for a given colorstring
function Methods:colorLookup(strName)
	strName = strlower(strName);
	if (strName=="aqua")		then return "ff00ffff"; end
	if (strName=="black")		then return "ff000000"; end
	if (strName=="blue")		then return "ff0000ff"; end
	if (strName=="fuchsia")		then return "ffff00ff"; end
	if (strName=="gray")		then return "ff808080"; end
	if (strName=="green")		then return "ff008000"; end
	if (strName=="lightgreen")	then return "ff00aa00"; end
	if (strName=="lime")		then return "ff00ff00"; end
	if (strName=="maroon")		then return "ff800000"; end
	if (strName=="navy")		then return "ff000080"; end
	if (strName=="olive")		then return "ff808000"; end
	if (strName=="purple")		then return "ff800080"; end
	if (strName=="red")			then return "ffc30000"; end
	if (strName=="silver")		then return "ffc0c0c0"; end
	if (strName=="teal")		then return "ff008080"; end
	if (strName=="white")		then return "ffffffff"; end
	if (strName=="yellow")		then return "ffffff00"; end
	if (strName=="gold")		then return "ffd4a017"; end --Used for player hyperlinks

	if (strName=="battle.net")	then return "ff82c5ff"; end --Used for battle.net hyperlinks (BATTLENET_FONT_COLOR_CODE)

	local i = -1;
	--HARDCODED: Last updated on 2012-08-25 (MOP beta /Patch 4.3.3), total of 8 colors
	if (strName=="poor")		then i = 0 end
	if (strName=="common")		then i = 1 end
	if (strName=="uncommon")	then i = 2 end
	if (strName=="rare")		then i = 3 end
	if (strName=="epic")		then i = 4 end
	if (strName=="legendary")	then i = 5 end
	if (strName=="artifact")	then i = 6 end
	if (strName=="heirloom")	then i = 7 end
	if (i ~= -1) then
		local r,g,b,hex = GetItemQualityColor(i); --lookup the color values for the item values directly from WoW, that way if there are any changes in the future we are following wow
		return hex;
	end--if i

	local i = nil;
	--HARDCODED: Last updated on 2016-05-10 (Legion beta /Patch 7.0.3), Total of 11 classes
	if (strName=="hunter")		then i = "HUNTER" end
	if (strName=="warrior")		then i = "WARRIOR" end
	if (strName=="paladin")		then i = "PALADIN" end
	if (strName=="mage")		then i = "MAGE" end
	if (strName=="priest")		then i = "PRIEST" end
	if (strName=="warlock")		then i = "WARLOCK" end
	if (strName=="deathknight")	then i = "DEATHKNIGHT" end
	if (strName=="death knight")then i = "DEATHKNIGHT" end --alternate spelling
	if (strName=="druid")		then i = "DRUID" end
	if (strName=="shaman")		then i = "SHAMAN" end
	if (strName=="rogue")		then i = "ROGUE" end
	if (strName=="monk")		then i = "MONK" end
	if (strName=="demonhunter")	then i = "DEMONHUNTER" end

	if (i ~= nil and RAID_CLASS_COLORS ~= nil) then
		local rgbTable = RAID_CLASS_COLORS[i]; --lookup rgb format
		--if (rgbTable ~= nil) then return self:rgbColorToHEX(rgbTable) end --return as hex
		if (rgbTable ~= nil) then return rgbTable["colorStr"]; end --return as hex
	end--if i

	return strName; --if not identified just return the string itself
end


--[[Support function that returns the Hex string for a given RGB structure
function Methods:rgbColorToHEX(rgbTable)
	--Expects: {a=0, r=0, g=0, b=0} --Alpha, Red, Green, Blue (Alpha is optional)
	if (rgbTable == nil or type(rgbTable) ~= "table") then return nil end

	if (rgbTable["colorStr"] ~= nil) then return rgbTable["colorStr"]; end --If the rgbtable got a hex string inside it already then simply return that
	local tonumber = tonumber; --local fpointer

	local intA = tonumber(rgbTable["a"],10);
	local intR = tonumber(rgbTable["r"],10);
	local intG = tonumber(rgbTable["g"],10);
	local intB = tonumber(rgbTable["b"],10);
	if (intR == nil or intG == nil or intB == nil) then return nil end --Alpha might not be included in the string...

	local pst = true;										--Percent values
	if (intR >1 or intG >1 or intB >1) then pst = false end --0-255 values

	if (pst) then
		if (intA == nil) then intA = 1 end --FF if not defined
		--Takes a RGB percent set (0.0-1.0) and converts it to a hex string.	Source: http://www.wowwiki.com/RGBPercToHex
		intA = intA <= 1 and intA >= 0 and intA or 0
		intR = intR <= 1 and intR >= 0 and intR or 0
		intG = intG <= 1 and intG >= 0 and intG or 0
		intB = intB <= 1 and intB >= 0 and intB or 0
		return format("%02x%02x%02x%02x", intA*255, intR*255, intG*255, intB*255);

	else
		if (intA == nil) then intA = 255 end --FF if not defined
		--Takes a RGB value set (0-255) and converts it into a hex string.		Source: http://www.wowwiki.com/RGBToHex
		intA = intA <= 255 and intA >= 0 and intA or 0
		intR = intR <= 255 and intR >= 0 and intR or 0
		intG = intG <= 255 and intG >= 0 and intG or 0
		intB = intB <= 255 and intB >= 0 and intB or 0
		return format("%02x%02x%02x%02x", intA, intR, intG, intB);
	end--if pst
end

--Support function that returns the RGB structure for a given hex colorstring value hex
function Methods:hexColorToRGB(strHexColor, booPercent)
	--Expects: AARRGGBB  --Alpha, Red, Green, Blue
	if (strlen(strHexColor) ~= 8) then return nil end
	if (booPercent ~= true) then booPercent = false; end

	local tonumber	= tonumber; --local fpointer
	local strsub	= strsub;

	local intA = tonumber( strsub(strHexColor,1,2), 16);
	local intR = tonumber( strsub(strHexColor,3,4), 16);
	local intG = tonumber( strsub(strHexColor,5,6), 16);
	local intB = tonumber( strsub(strHexColor,7,8), 16);

	if (intA==nil or intR==nil or intG==nil or intB==nil) then return nil end
	if (booPercent) then r=r/255; g=g/255; b=b/255; end--Divide by 255 to get percent values
	return {r=intR, g=intG, b=intB};--colorStr=strHexColor
end--]]


--Support function that returns the ItemID from a hyperlink
function Methods:getItemIDfromItemLink(itemLink)
	if (itemLink == nil) then return nil end
	local s = StringParsing:split(itemLink,":");
	if (s == nil or #s < 2) then return nil end
	return s[2];--second element is the itemID
end


--Support function that replaces raid-marker strings like {star} with its textures.
function Methods:inputRaidTextureLinks(Input)
	--Source: \FrameXML\Chatframe.lua
	--	ICON_LIST and ICON_TAG_LIST are declared in chatframe.lua and we iterate over the input text using those.
	--	Code copied from ChatFrame_MessageEventHandler(). Removed some stuff related to group-refereneces {group1} etc.
	if (Input == nil or Input == "") then return Input end

	-- Search for icon links and replace them with texture links.
	for tag in string.gmatch(Input, "%b{}") do
		local term = strlower(string.gsub(tag, "[{}]", ""));
		if ( ICON_TAG_LIST[term] and ICON_LIST[ICON_TAG_LIST[term]] ) then
			Input = string.gsub(Input, tag, ICON_LIST[ICON_TAG_LIST[term]] .. "0|t");
		end--if
	end--for tag

	return Input;
end


--Support function that will strip out any texture sequences with empty string. Currency textures are a special case that will be translated into text
function Methods:replaceTextureLinks(Input)
	--A Texture sequence starts with |T and ends with |t. We simply remove them from the string.
	--If we find any references to the currency textures (gold, silver, copper) then we will replace those with literal strings
	if (Input == nil or Input == "") then return Input end

	local strfind = strfind; --local fpointer
	local res = Input;
	local ppp = "%|T(.-)%|t"; --our texture sequence pattern
	local start, finish, value = strfind(res, ppp, 1); --sequences have the stringvalue "|T<data>|t" format
	if (start == nil) then return Input; end --finish here if no texture sequences are found in the string at all

	local booGold, booSilver, booCopper = false, false, false;
	local txtGold, txtSilver, txtCopper = "Interface\\MoneyFrame\\UI-GoldIcon", "Interface\\MoneyFrame\\UI-SilverIcon", "Interface\\MoneyFrame\\UI-CopperIcon";

	while (start ~= nil) do
		if 		(StringParsing:startsWith(value, txtGold))		then res = StringParsing:replace(res, "|T"..value.."|t", "@GOLD@");		booGold=true;
		elseif	(StringParsing:startsWith(value, txtSilver))	then res = StringParsing:replace(res, "|T"..value.."|t", "@SILVER@");	booSilver=true;
		elseif	(StringParsing:startsWith(value, txtCopper))	then res = StringParsing:replace(res, "|T"..value.."|t", "@COPPER@");	booCopper=true;
		else	res = StringParsing:replace(res, "|T"..value.."|t", ""); end --Any other textures we simply strip away

		start, finish, value = strfind(res, ppp, 1); --sequences have the stringvalue "|T<data>|t" format
	end--while

	if (booGold or booSilver or booCopper) then
		--_G["GOLD_AMOUNT"],_G["SILVER_AMOUNT"],_G["COPPER_AMOUNT"]; -- Localised names: '%d Gold', '%d Silver', '%d Copper'
		if (booGold) then
			value = " "..strtrim(StringParsing:replace(_G["GOLD_AMOUNT"], "%d", "")); -- Localised name: '%d Gold'. We remove %d and spaces in the strings
			if (booSilver or booCopper) then	res = StringParsing:replace(res, "@GOLD@", value..",");
			else								res = StringParsing:replace(res, "@GOLD@", value); end
		end--if
		if (booSilver) then
			value = " "..strtrim(StringParsing:replace(_G["SILVER_AMOUNT"], "%d", ""));
			if booCopper then	res = StringParsing:replace(res, "@SILVER@", value..",");
			else				res = StringParsing:replace(res, "@SILVER@", value); end
		end--if
		if (booCopper) then
			value = " "..strtrim(StringParsing:replace(_G["COPPER_AMOUNT"], "%d", ""));
			res = StringParsing:replace(res, "@COPPER@", value);
		end--if
	end--if

	return res;
end


--Support function that replaces any escaped links found in the string with the properly formatted hyperlinks
function Methods:replaceHyperLinks(Input)
	--Hyperlinks are written in the format;
	--		[Mana Gem]				the name of the item/spell/achivement
	--		[type:title]			shorthand format of a hyperlink
	--		[type:id:title]			shorthand format of a hyperlink
	if (Input == nil or Input == "") then return Input end

	--This must be done just before displaying the hyperlinks since many links can change between parsetime and runtime (its like a dynamic variable).
	--	Achivements can change state ('earned by player at ddmmyyhhmmss' etc). Battlepets could have been added to the petjournal.
	--	Tradeskills can be updated by adding new recipes. Instance-links can be changed by killing bosses.

	local booLTrim, booRTrim = false, false; --if we got a hyperlink at the very start or end of the string, then the pattern matching does not work properly, we therefore add a single space at the start/beginning
	if (StringParsing:startsWith(Input, "[")) then booLTrim = true; Input = " "..Input; end
	if (StringParsing:endsWith(Input, "]")  ) then booRTrim = true; Input = Input.." "; end

	local strfind	= strfind; --local fpointer
	local strsub	= strsub;
	local strlen	= strlen;

	local res = Input;
	local ppp = "[^|h]%[(.-)%][^|h]"; --our hyperlink pattern
	local start, finish, value = strfind(res, ppp, 1); --existing hyperlinks have the stringvalue "|h[TITLE]|h" format so we need to look for [ and ] witout |h before and after them

	while (start ~= nil) do
		--Sometimes we will get a char before the [ and we will here simply adjust the indexes properly
		if (StringParsing:startsWith(value, "[") == false) then start  = StringParsing:indexOf(res, "[", start); end
		if (StringParsing:endsWith(value, "]")   == false) then finish = StringParsing:indexOf(res, "]", start); end
		local currString = strsub(res, (start+0), (finish-0)); --include the [ ]
		local currValue  = value; --just whats inside the [ ]
		local newLink    = self:getHyperLink(currValue);

		if (newLink ~=nil) then
			newLink = StringParsing:escapeMagicalCharacters(newLink);
			res = StringParsing:replace(res,currString,newLink);
			finish = start + strlen(newLink);
		end--if

		start, finish, value = strfind(res, ppp, finish);
	end--while

	if (booLTrim == true) then res = StringParsing:ltrim(res); end --trim only left side
	if (booRTrim == true) then res = StringParsing:rtrim(res); end --trim only right side
	return res;
end


--Support function that will attempt to get a hyperlink for the item/spell/achivement, whatever that is found in the string
function Methods:getHyperLink(objName)
	if (objName == nil or objName == "") then return nil end
	if (tonumber(objName) ~= nil) then return nil end --we dont accept [1234] since its impossible to predict what this refers to (a spell? an item?)

	--Check and see if the string is a simple hyperlink in the format 'type:id:title'
	local link = self:parseSimpleHyperlink(objName, false);
	if (link ~=nil) then return link end

	--if the hypelink simply is just [title] then we need to guess, we start with the item: and move towards the instance: the order of guessing is important to prevent collisions
	local tbl = {[1]="item",[2]="spell",[3]="achievement",[4]="battlepet",[5]="currency",[6]="trade",[7]="talent",[8]="instance"};
	for i = 1, #tbl do
		local link = self:parseSimpleHyperlink(tbl[i]..":"..objName, true); --try with the different subtypes if the link cant be resolved
		if (link ~=nil) then return link end
	end--for i

	return nil; --nothing was found, return nil
end


--Support function that will return nil or a hyperlink, expects the input in the format of 'type:id:title' which we call a shorthand hyperlink
function Methods:parseSimpleHyperlink(objName, returnNil)
	if (objName == nil or objName == "") then return nil end
	if (returnNil == nil) then returnNil = false end

	local split = StringParsing:split(objName, ":"); --type:id:title
	if (split == nil) then return nil end

	local strType	= "";
	local strID		= 0;
	local strTitle	= "";
	--local strColor	= "|r";
	local strlower = strlower; --local fpointer

	--We support 2 formats: [type:text] and [type:id:text]
	if (#split == 2) then
		strType		= strlower(split[1]);
		strID		= 0;
		strTitle	= split[2];

	elseif (#split == 3) then
		strType		= strlower(split[1]);
		strID		= tonumber(split[2]) or 0;
		strTitle	= split[3];

	elseif (#split > 3) then
		--some recipes got : in their names, we now try to split the string into 3 elements and try it again...
		-- [item:1234:Schematic: my recipe]		We support this
		-- [item:Schematic: my recipe]    		We do not support this
		local a,b,c = strsplit(":", objName, 3);
		if (c ~= nil) then c = StringParsing:replace(c, ":", "@COLON_PLACEHOLDER@"); end
		local link = self:parseSimpleHyperlink(tostring(a)..":"..tostring(b)..":"..tostring(c), true);
		if (link ~= nil) then return link end

		if (returnNil == true) then return nil end
		IfThen:msg_error("Failed to parse the hyperlink '"..objName.."'.");
		return nil;
	else
		return nil; --Wrong length of arguments
	end--if

	strTitle = StringParsing:replace(strTitle, "@COLON_PLACEHOLDER@", ":");

	--if (strType=="recipe" or strType=="schematic" or strType=="plans") then strType="enchant"; end --ingame all tradeskills are using the 'enchant' type but we support these two variations
	if		(strType=="achi")	then strType="achievement";		--a few shortcuts
	elseif	(strType=="pet")	then strType="battlepet";
	elseif	(strType=="pvptal")	then strType="talent"; end

	if (strType == "achievement") then
		--strColor="ffffff00";
		local link = GetAchievementLink(strID);
		if (link ~= nil) then return link end
		local tbl = self:findStatisticByName(strTitle, true); --Cant match on ID, try searching by the name.
		if (tbl ~= nil) then
			link = GetAchievementLink(tbl["Id"]);
			if (link ~= nil) then return link end
		end--if tbl
		if (returnNil == true) then return nil end
		IfThen:msg_error("Failed to find the achivement with the id '"..strID.."'  ("..strTitle..").");
		return "["..strTitle.."]"; --no link found, we return a default placeholder (can't use color since it won't be outputted in chat then)

	elseif (strType == "item") then
		--strColor="ffffffff";
		local name, link, quality = GetItemInfo(strID); --is it an item? (if item isnt in cache then it will return nil)
		if (name == nil) then name, link, quality = GetItemInfo(strTitle); end
		if (name ~= nil) then
			--local r,g,b,hex = GetItemQualityColor(quality);
			--strColor = hex;
			return link;
		end--if
		if (returnNil == true) then return nil end
		--IfThen:msg_error("Failed to find the item with the id '"..strID.."'  ("..strTitle..").");
		return "["..strTitle.."]"; --no link found, we return a default placeholder (can't use color since it won't be outputted in chat then)

	elseif (strType == "spell") then
		--strColor="ff71d5ff";
		local link = GetSpellLink(strID); --is it an item? (if item isnt in cache then it will return nil)
		if (link == nil) then link = GetSpellLink(strTitle); end
		if (link ~= nil) then return link end
		if (returnNil == true) then return nil end
		--IfThen:msg_error("Failed to find the spell with the id '"..strID.."'  ("..strTitle..").");
		return "["..strTitle.."]"; --no link found, we return a default placeholder (can't use color since it won't be outputted in chat then)

	elseif (strType == "instance") then
		--strColor="ffff8000";
		local lowTitle = strlower(strTitle);
		local numInstances = GetNumSavedInstances();

		local GetSavedInstanceInfo = GetSavedInstanceInfo; --local fpointer
		for i=1, numInstances do
			local instanceName, instanceID, instanceReset = GetSavedInstanceInfo(i); --instanceName, instanceID, instanceReset, instanceDifficulty, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, maxBosses, defeatedBosses = GetSavedInstanceInfo(index);
			if (strlower(instanceName) == lowTitle and instanceReset > 0) then
				return GetSavedInstanceChatLink(i);
			end--if
		end--for i
		if (returnNil == true) then return nil end
		IfThen:msg_error("Failed to find the instance with the name '"..strTitle.."'.");
		return "["..strTitle.."]"; --no link found, we return a default placeholder (can't use color since it won't be outputted in chat then)
		--return "|c"..strColor.."["..strTitle.."]|r";

	elseif (strType == "battlepet") then
		--strColor="ffffd200";
		--strID is expected to be the speciesID of the pet, not the GUID of one specific pet. We dont support GUID's
		local lowTitle = C_PetJournal.GetPetInfoBySpeciesID(strID);
		if (lowTitle == nil) then
			local speciesID = C_PetJournal.FindPetIDByName(strTitle) or 0; --If the speciesID provided isnt working then try looking it up using the name
			lowTitle = C_PetJournal.GetPetInfoBySpeciesID(speciesID);
			if (lowTitle == nil) then
				if (returnNil == true) then return nil end
				IfThen:msg_error("Failed to find the battlepet with the id '"..strID.."'  ("..strTitle..").");
				return "["..strTitle.."]"; --no link found, we return a default placeholder (can't use color since it won't be outputted in chat then)
			end--if
		end--if lowTitle

		--The function returns speciesID and the 1st of many petID's that you can have (a GUID unique for each pet)
		local speciesID, strFirstGUID = C_PetJournal.FindPetIDByName(lowTitle); --if the speciesID provided isnt working then try looking it up using the name
		if (strFirstGUID == nil) then
			if (returnNil == true) then return nil end
			IfThen:msg_error("Can not create link for battlepet with the id '"..strID.."'  ("..strTitle.."). Because you have not collected it yet");
			--Attempting to do another lookup for "item:" with the same name or constructing a "battlepet:" link has proved to be unreliable.
			return "["..strTitle.."]"; --no link found, we return a default placeholder (can't use color since it won't be outputted in chat then)
		end--Didnt find a pet in the users petjournal since he hasn't collected it yet
		return C_PetJournal.GetBattlePetLink(strFirstGUID);

	elseif (strType == "currency") then
		--strColor="ff00aa00";
		local link = GetCurrencyLink(strID); --First try by using the id
		if (link ~= nil) then return link end
		local lowTitle = strlower(strTitle);
		local currData = self:getCurrencyInfoByName(lowTitle);
		if (currData ~= nil and currData["Link"] ~= nil) then return currData["Link"]; end
		if (currData ~= nil and currData["Link"] == nil and currData["Name"] ~= nil) then return "["..currData["Name"].."]"; end --link will not work, but at least it will be outputted correctly
		if (returnNil == true) then return nil end
		return "["..strTitle.."]"; --no link found, we return a default placeholder (can't use color since it won't be outputted in chat then)
		--return "|c"..strColor.."["..strTitle.."]|r";

	elseif (strType == "trade") then
		--strColor="ffffd000";
		local lowTitle = strlower(strTitle);
		local list = {GetProfessions()}; --Can't use #list for some reason, use 20 as hardcoded maxvalue
		local GetProfessionInfo = GetProfessionInfo; --local fpointer
		for i=1, 20 do --HARDCODED: 2016-05-15 (Legion beta 7.0.3) Cant use #list so we use a arbitrary value here.
			--need to wrap this in a pcall() since it sometimes for no reason just fails
			local b, name, texture, rank, maxRank, numSpells, spelloffset, skillLine, rankModifier = pcall(GetProfessionInfo, list[i]);--GetProfessionInfo(list[i]);
			if (b == false) then name = ""; end
			if (strlower(name) == lowTitle) then
				--local link = cache_TradeSkill[lowTitle];
				local link = nil;
				if (cache_TradeSkill ~= nil) then link = cache_TradeSkill[lowTitle]; end
				if (link ~= nil) then return link; end
				--the player has the tradeskill but the link is not cached.
				if (returnNil == true) then return nil end
				IfThen:msg_error("Failed to output the tradeskill link for '"..name.."'. Please open the tradeskill window for "..strlower(name).." so that the link can be cached.");
				return "["..name.."]";
			end--if
		end--for
		--the player does not have the tradeskill
		if (returnNil == true) then return nil end
		IfThen:msg_error("You do not have the tradeskill '"..strTitle.."'.");
		return "["..strTitle.."]";

	elseif (strType == "talent") then
		--strColor="ff4e96f7";

		local link = GetTalentLink(strID) or GetPvpTalentLink(strID); --id number specified?
		if (link ~= nil) then print("id found") return link end


		local lowTitle	= strlower(strTitle);
		--Non-pvp talents
		--local intSpec	= GetSpecialization(); --Currently enabled spec. Returns 1,2,3 or 4
		local intSpec	= 1; --Seems to only work with 1
		local intRow	= MAX_TALENT_TIERS or 7;	--Defined in FrameXML\TalentFrameBase.lua
		local intCol	= NUM_TALENT_COLUMNS or 3;
		local ptr		= GetTalentInfo; --local fpointer
		local ptr2		= GetTalentLink;

		for k=1, 2 do
			if (k == 2) then
				--Searched though non-pvp-talents on first round. Do another pass with PVP talents
				intSpec	= 1; --Seems to only work with 1
				intRow	= MAX_PVP_TALENT_TIERS or 6;	--Defined in FrameXML\TalentFrameBase.lua
				intCol	= MAX_PVP_TALENT_COLUMNS or 3;
				ptr		= GetPvpTalentInfo; --local fpointer
				ptr2	= GetPvpTalentLink;
			end--if

			--Note: We are here just looking at the currently enabled spec of the player. However that will not include -all- of the the available talents for a class; only the one's that the current player has access to.
			--local GetTalentInfo = GetTalentInfo; --local fpointer
			for i=1, intRow do
				for j=1, intCol do
					local talentID, name, iconTexture, selected, available = ptr(i,j,intSpec,false); --Will return data even if a spec hasnt been picked
					if (strlower(name) == lowTitle) then
						local link = ptr2(talentID); --The talentgroups are not identical based on spec's
						if (link ~= nil) then return link; end
					end--if name
				end--for j
			end--for i

		end--for k
		if (returnNil == true) then return nil end
		IfThen:msg_error("You do not have the talent '"..strTitle.."'.");
		return "["..strTitle.."]"; --no link found, we return a default placeholder (can't use color since it won't be outputted in chat then)

	--elseif (strType == "enchant") then strColor="ffffd000";
	--elseif (strType == "quest") then strColor="ffffff00";
	--elseif (strType == "player") then strColor="";
	else
		return nil;
	end
	--return "|c"..strColor.."|H"..strType..":"..strID.."|h["..strTitle.."]|h|r";
end


--Support function used by do_Report, returns nil or the raw data about a players currency
function Methods:getCurrencyInfoByName(name)
	if (name == nil) then return nil end
	name = strtrim(strupper(name)); --uppercase comparison of currency names
	if (strlen(name) == 0) then return nil end

	local NOTFOUND			= -1;		--local constant
	local strupper			= strupper; --local fpointer
	local GetCurrencyInfo	= GetCurrencyInfo;
	local GetCurrencyLink	= GetCurrencyLink;
	local numID, strName, amount, texture, link = nil, nil, nil, nil, nil;

	if (cache_CurrencyList ~= nil and cache_CurrencyList[name] ~= nil) then
		--Attempt lookup as it might be cached from earlier calls.
		numID = tonumber(cache_CurrencyList[name]);
		if (numID == NOTFOUND) then return nil end --The currency does not exists. It has been searched for ealier and was not found (-1)

		strName, amount, texture	= GetCurrencyInfo(numID); --There are more arguments returned from this function but they vary depending on the currency and they are not documented
		link						= GetCurrencyLink(numID);
		return { ["Name"]=strName, ["Amount"]=amount, ["Texture"]=texture, ["Link"]=link, ["ID"]=numID };
	else
		--Currency not found in cache, we iterate and look for it...

		--HARDCODED: Last updated on 2016-05-16 (Legion Beta 7.0.3), Highest number found was 1268: http://www.wowhead.com/currencies
		--			 The maxvalue that the loop will iterate to look for currencies.
		local maxID = 9000;

		--Earlier versions used a hardcoded list. This didn't work well with localized versions and was not very flexible when changes was made to the game.
		--An additional loop that used the UI to lookup currencies was also implemented, but that might fail if/when blizzard or other addons make changes to the UI.
		--When you look at the frequency of use (number of [currency] links in text) as well the time it takes for an 2000 iteration loop to complete then this is the best solution.
		--It's only done when its needed (no startup cost), it caches only those currencies that are referenced (less memory footprint). It does however use more CPU, as for each new currency you might get 2000/2 iterations per lookup.
		for i=1, maxID do
			strName, amount, texture = GetCurrencyInfo(i); --There are more arguments returned from this function but they vary depending on the currency and they are not documented
			if (strName ~= nil and strName ~= "" and strupper(strName) == name) then
				--Cache for later...
				if (cache_CurrencyList == nil) then cache_CurrencyList = {} end	--Keep as nil until we need a table
				cache_CurrencyList[name] = i;									--Store in cache for fast lookup later

				--Return data
				link = GetCurrencyLink(i);
				return { ["Name"]=strName, ["Amount"]=amount, ["Texture"]=texture, ["Link"]=link, ["ID"]=i };
			end--if
		end--for i

		--No match found. Store that in cache as well
		if (cache_CurrencyList == nil) then cache_CurrencyList = {} end	--Keep as nil until we need a table
		cache_CurrencyList[name] = NOTFOUND;							--Store in cache for fast lookup later
		return nil;
	end--if
end


--Support function used by do_Report, returns nil or the raw data from a faction
function Methods:getFactionInfoByName(name)
	if (name == nil) then return nil end
	name = strtrim(strupper(name)); --uppercase comparison of faction names
	if (strlen(name) == 0) then return nil end

	local NOTFOUND				= -1;		--local constant
	local strupper				= strupper; --local fpointer
	local GetFactionInfoByID	= GetFactionInfoByID;

	--Check if name has already been cached...
	if (cache_FactionList == nil or cache_FactionList[name] == nil) then
		--Faction not found in cache, we iterate and look for it...

		--HARDCODED: Last updated on 2016-05-16 (Legion Beta 7.0.3), Highest number found was 1948: http://www.wowhead.com/factions
		--			 The maxvalue that the loop will iterate to to look for factions.
		local maxID = 3000;

		--Earlier versions used a hardcoded list. This didn't work well with localized versions and was not very flexible when changes was made to the game.
		--An additional loop that used the UI to lookup factions was also implemented, but that might fail if/when blizzard or other addons make changes to the UI.
		--When you look at the frequency of use (uses of Report() ) as well the time it takes for an 3000 iteration loop to complete then this is the best solution.
		--It's only done when its needed (no startup cost), it caches only those factions that are referenced (less memory footprint). It does however use more CPU, as for each new search you might get 3000/2 iterations.
		if (cache_FactionList == nil) then cache_FactionList = {} end	--Keep as nil until we need a table
		cache_FactionList[name] = NOTFOUND;								--Assume its not found until we find it.

		for i=1, maxID do
			local strName = GetFactionInfoByID(i);
			if (strName ~= nil and strName ~= "" and strupper(strName) == name) then
				cache_FactionList[name] = i; --Store in cache for fast lookup later
				break; --Its now cached so we break out of our loop
			end--if
		end--for i
	end--if cache_FactionList


	--Attempt lookup as it might be cached from earlier calls.
	local numID = tonumber(cache_FactionList[name]);
	if (numID == NOTFOUND) then return nil end --The faction does not exists. It has been searched for ealier and was not found (-1)

	local gender		= UnitSex("player");
	local engStanding	= {[1]="Hated", [2]="Hostile", [3]="Unfriendly", [4]="Neutral", [5]="Friendly", [6]="Honored", [7]="Revered", [8]="Exalted"}; --Hardcoded list of English reputation names
	--local engFriendship	= {[1]="Stranger", [2]="Acquaintance", [3]="Buddy", [4]="Friend", [5]="Good Friend", [6]="Best Friend"}; --Hardcoded list of English friendship names

	local strName, description, standingID, barMin, barMax, barValue = GetFactionInfoByID(numID);
	local standingLabel		= GetText("FACTION_STANDING_LABEL"..tostring(standingID), gender);	--Localized name with masculine/feminine form based on the players gender
	local strStanding		= engStanding[standingID];											--English
	local strNextStanding	= engStanding[standingID+1] or "";
	local pointsLeft		= barMax - barValue;												--Number of points left until next level
	local booFriend			= false;															--Boolean. Friendship faction or not.

	--[[Not in use so disabled
	local standingColor = self:rgbColorToHEX( FACTION_BAR_COLORS[standingID] ); --"|c"..self:rgbColorToHEX( FACTION_BAR_COLORS[stID] )..stName.."|r";
	local nextStandingColor, nextStandingLabel = "", "";
	if ((standingID+1) > 0 and (standingID+1) < 9) then
		nextStandingColor	= self:rgbColorToHEX( FACTION_BAR_COLORS[(standingID+1)] );
		nextStandingLabel	= GetText("FACTION_STANDING_LABEL"..tostring((standingID+1)), gender); end --Localized name
	end]]--

	--print("name" ..name);
	--print("numID" ..tostring(numID));
	--Is this a friendship faction or a regular faction?
	--local standingID, maxID = GetFriendshipReputationRanks(numID); --2015-07-10: Patch 6.2. Not returning values anymore. Broken by Blizzard?
	local b = GetFriendshipReputation(numID);
	if (b ~= nil) then --nil if its a regular faction --if (maxID ~= 0) then --0 if its a regular faction
		booFriend = true;
		--local id, rep, maxRep, name, text, texture, reaction, threshold, nextThreshold = GetFriendshipReputation(friendshipID);  --Blizzard (ReputationFrame.lua)
		local _numID, rep, maxRep, strName, description, _unknown, friendTextLevel, threshold, nextThreshold = GetFriendshipReputation(numID);
		standingLabel	= friendTextLevel;				--Localized string.
		--strStanding		= engFriendship[standingID];	--English
		--strNextStanding	= engFriendship[standingID+1] or "";
		strStanding		= ""; --Can't determine english standard name since different factions use different values
		strNextStanding	= ""; --Can't determine next rank

		if (threshold ~= 0 and nextThreshold ~= nil) then
			--Some friendships like 'Nomi' (numID=1357) are not using the 0 to 8400 range for treshold but must be calculated in another way.
			--'Nomi' also uses different titles like 'Journeyman' and that is correctly outputted in the localized string.
			--However we don't care about it too much and simply use the english friendship titles (they use the 1-6 ranks etc like a friendship rep anyway).
			barMax		= nextThreshold - threshold;
			pointsLeft	= nextThreshold - rep;
			barValue	= barMax - pointsLeft;
			barMin		= 0;

		else
			--This works with all normal friendships
			barMax		= nextThreshold or 0; --is nil if you are at maxlevel (Best Friend), but then the numbers dont matter.
			barValue	= rep - threshold;
			barMin		= threshold;
			pointsLeft	= barMax - barValue;
		end--if

		--[[Not in use so disabled
		--Friendship uses the color of the parent faction so no change there
		if ((standingID+1) > 0 and (standingID+1) < 6) then
			nextStandingLabel	= GetText("FACTION_STANDING_LABEL"..tostring((standingID+1)), gender); end --TODO: So far no globalstrings list to return friendship names: Localized name
		end]]--
	end--if friendID

	--Unused fields: ["barMin"]=barMin, ["barMax"]=barMax, ["barValue"]=barValue, ["Description"]=description, ["StandingID"]=standingID, ["FactionID"]=numID, ["StandingColor"]=standingColor, ["NextStandingColor"]=nextStandingColor, ["NextStandingLocalized"]=nextStandingLabel
	return { ["Name"]=strName, ["StandingLocalized"]=standingLabel, ["Standing"]=strStanding, ["NextStanding"]=strNextStanding, ["PointsLeft"]=pointsLeft, ["Friendship"]=booFriend };
end


--Support function that returns list of SlotID's ingame, result is cached in cache_InventoryIDList
function Methods:getInventoryIDList()
	--If its already cached then return that list immediatly
	if (cache_InventoryIDList ~= nil) then return cache_InventoryIDList; end

	--If its not already done, then populate the cache_InventoryIDList table with the the slotID numbers that are used for equipped item slots
	cache_InventoryIDList		= {};
	local slots					= {"MainHandSlot", "BackSlot", "ChestSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "HandsSlot", "HeadSlot", "LegsSlot", "NeckSlot", "SecondaryHandSlot", "ShoulderSlot", "Trinket0Slot", "Trinket1Slot", "WaistSlot", "WristSlot"}; --ShirtSlot and TabardSlot are ignored, Relic slot was removed in MOP
	local GetInventorySlotInfo	= GetInventorySlotInfo; --local fpointer
	for i=1, #slots do
		local slotID = GetInventorySlotInfo(slots[i]);--fill up with the slotid we need
		cache_InventoryIDList[#cache_InventoryIDList+1] = slotID;
	end--for i

	return cache_InventoryIDList;
end


--Support function that returns a instancename or nil, result is cached in cache_InstanceList
function Methods:isInstanceInEncounterJournal(name)
	if (name ~= nil and IsInInstance() == false) then return nil; end --returns true or false
	if (name == nil) then name = GetInstanceInfo(); end --use current instance name if name is nil
	name = strtrim(strupper(name)); --uppercase comparison of instance names
	if (strlen(name) == 0) then return nil; end

	if (cache_InstanceList ~= nil) then return cache_InstanceList[name]; end --nil or a instance name

	--HARDCODED: Last updated on 2016-05-16 (Legion Beta 7.0.3). Highest number found was 822: http://wowpedia.org/Encounter_Journal_Dump#Encounter_ID
	---			 The maxvalue that the loop will iterate to to look for instanceid's.
	local maxInstance	= 1000;	--Highest found was 822

	--local intInstance = 0; --maxvalues encountered
	local res = {};
	local EJ_GetInstanceInfo = EJ_GetInstanceInfo; --local fpointer
	local strupper	= strupper;
	local strtrim	= strtrim;

	for instanceID=1, maxInstance do
		local instanceName = EJ_GetInstanceInfo(instanceID) --, description, bgImage, buttonImage, loreImage, dungeonAreaMapID, link
		if (instanceName ~= nil) then
			local key = strtrim(strupper(instanceName));
			res[key] = instanceName;
			--if (instanceID > intInstance) then intInstance = instanceID; end
		 end --if
	end--for instanceID
	--print("highest intInstance:"..tostring(intInstance));
	cache_InstanceList = res;
	return cache_InstanceList[name];
end


--Support function that returns a encountername or nil, result is cached in cache_EncounterBossList
function Methods:getEncounterNameFromBossName(name)
	--Remember; An 'Encounter' can have a different name than the boss  (or bosses) you are fighting in that encounter (often its the same tho).
	--Example: Pandaria's "Siege of Orgrimmar". Encounter name: "The fallen Protectors". Bosses: Rook Stonetoe, He Softfoot and Sun Tenderheart.
	if (name == nil) then return nil; end
	name = strtrim(strupper(name)); --uppercase comparison of boss names
	if (strlen(name) == 0) then return nil; end

	local b = self:isInstanceInEncounterJournal(nil); --Are we currently in an instance and is that instance in the encounter journal?
	if (b == nil) then return nil; end --If the current instance isn't listed in the encounter journal then there's no point in continuing.

	if (cache_EncounterBossList ~= nil) then return cache_EncounterBossList[name]; end --nil or a bossname

	--HARDCODED: Last updated on 2016-05-16 (Legion beta 7.0.3). Highest number found was 1796: http://wowpedia.org/Encounter_Journal_Dump#Encounter_ID
	--			 The maxvalue that the loop will iterate to to look for encounterid's.
	local maxEncounter	= 3000;	--Highest found was 1796
	local maxCreature	= 15;	--Highest found was 10

	--local intEncounter, intCreature = 0, 0; --maxvalues encountered
	local res = {};
	local EJ_GetCreatureInfo	= EJ_GetCreatureInfo;
	local EJ_GetEncounterInfo	= EJ_GetEncounterInfo;
	local strupper	= strupper;
	local strtrim	= strtrim;

	for encounterID=1, maxEncounter do
		for creatureID=1, maxCreature do
			local bossid, bossname = EJ_GetCreatureInfo(creatureID, encounterID); --, description, displayInfo, iconImage
			if (bossid == nil) then break; end --skip to next encounterID
			local encountername = EJ_GetEncounterInfo(encounterID); --, description, encounterID, rootSectionID, link
			local key = strtrim(strupper(bossname));
			res[key] = encountername; --One problem we can face is cases where we can get the same boss found in different instances (Onyxia is found both in 'Onyxias Lair' and 'Blackwing Descent')
			--if (creatureID > intCreature) then intCreature = creatureID; end
			--if (encounterID > intEncounter) then intEncounter = encounterID; end
		end--for creatureID
	end--for encounterID
	--print("highest intEncounter:"..tostring(intEncounter).." highest intCreature:"..tostring(intCreature));
	cache_EncounterBossList = res;
	return cache_EncounterBossList[name]; --nil or a bossname
end


--Support function that returns an array with items and their stats (returns nil if it fails to find a named equipmentset. If the player is naked it will return an empty table)
function Methods:getEquippedItems(equipmentSet, ofTarget, booStats, booIlevel)
	if (equipmentSet == nil) then equipmentSet = ""; end
	if (ofTarget ~= true)	 then ofTarget = false;  end --bool
	if (booStats ~= true)	 then booStats = false;  end --bool true/false whether to return stat-table aswell
	if (booIlevel ~= true)	 then booIlevel = false;  end --bool true/false whether to return itemlevel aswell
	equipmentSet = strtrim(equipmentSet);	 --equipment-set names are case-sensitive

	local res 					= {}; --table for storing the data
	local tinsert				= tinsert; --local fpointer
	local GetInventoryItemLink	= GetInventoryItemLink;
	local GetContainerItemLink	= GetContainerItemLink;
	local GetItemInfo			= GetItemInfo;
	local GetItemStats			= GetItemStats;
	local slotID, statTable = nil, nil;
	local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil;
	--NOTE:	GetItemInfo() and GetItemStats() will return the base stats for an item, even tho the specific item the player is wearing might have transmorg, enchants, upgrades, reforging or gems on it.
	--		To get the correct info we need to use the HiddenTooltip class.

	if (equipmentSet == "") then
		--get itemlevel of currently equipped items
		local unit = "player";					--We are looking at ourself
		if (ofTarget) then unit = "target" end	--We are looking at /target and not ourselves
		local slots = self:getInventoryIDList(); --A list of slot id numbers

		for i=1, #slots do
			slotID = slots[i];
			link = GetInventoryItemLink(unit, slotID);	--get the itemlink for the equipped item
			if (link ~= nil) then
				name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(link); --get info about the item
				if (link ~= nil) then
					if (booIlevel) then iLevel = HiddenTooltip:GetEquipmentItemInfo(link, "ITEM_LEVEL"); else iLevel = 0; end --Itemlevel returned by GetItemInfo() will not be correct due to possible upgrades/transmorg to the item
					if (booStats) then statTable = GetItemStats(link); end --This will only be the base stats for the item
					local tmp = { ["Name"]=name, ["Link"]=link, ["Quality"]=quality, ["iLevel"]=tonumber(iLevel), ["Slot"]=equipSlot, ["Stats"]=statTable };
					tinsert(res, tmp); --store for later calculation
				end--if nil
			end--if nil
		end--for i

	else
		--get data of a specific equipmentset of the player
		local items = GetEquipmentSetLocations(equipmentSet); --Returns a table listing the locations of the items in an equipment set
		if (items == nil) then return nil end --equipment set not found
		for i=1, #items do
			local location = items[i]; --1==Ignored/Missing, 0==Nothing, Anything else is something we can find in our bags, bank or inventory
			local player, bank, bags, slot, bag = EquipmentManager_UnpackLocation(location);
			link = nil;

			if (location == 1) then --1==Ignored/Missing
				link = GetInventoryItemLink("player", i); --If itemslot is ignored/missing then we use the currently equipped item.
			elseif (location == 0) then --0==Nothing
				link = nil; --Nothing
			else
				if (bags == true) then
					link = GetContainerItemLink(bag, slot); --Player got the item in his bag+slot
				else
					link = GetInventoryItemLink("player", slot); --Player got the item equipped and we look it up using itemslow
				end
			end--if location

			if (link ~= nil) then
				name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(link);
				if (booIlevel) then iLevel = HiddenTooltip:GetEquipmentItemInfo(link, "ITEM_LEVEL"); else iLevel = 0; end --Itemlevel returned by GetItemInfo() will not be correct due to possible upgrades/transmorg to the item
				if (booStats) then statTable = GetItemStats(link); end
				local tmp = { ["Name"]=name, ["Link"]=link, ["Quality"]=quality, ["iLevel"]=tonumber(iLevel), ["Slot"]=equipSlot, ["Stats"]=statTable };
				tinsert(res, tmp); --store for later calculation
			end--if link
		end--for i

	end--if equipmentSet

	--if no items were found (naked player), then we return and empty table (#==0) instead of nil
	return res;
end


--Support function used by do_Report, returns the average itemlevel of the currently equipped items or of the named itemset. Returns nil if equipmentset is not found
function Methods:getEquipmentItemLevel(equipmentSet, ofTarget)
	if (equipmentSet == nil) then equipmentSet = ""; end
	if (ofTarget ~= true)	 then ofTarget = false;  end --bool
	equipmentSet = strtrim(equipmentSet);	 --equipment-set names are case-sensitive

	local items	= self:getEquippedItems(equipmentSet, ofTarget, false, true); --get all the item data into a table
	if (items == nil) then return nil end --nil == equipment set not found. If the player is naked then an empty table is returned

	local sum					= 0;	--Sum of the gear's item levels
	local DIVIDE				= 16;	--Always divide by 16 when calculating with 1 handed weapon.
	local DIVIDE2				= 15;	--Used when a 2handed weapon is equipped.
	local intWeapon				= 0;	--integer
											--0 nothing equipped in mainslot
											--1 one handed weapon equipped (offhand equipped or not)
											--2 two handed weapon equipped
	local isOffhand				= false; --bool
	local equipSlot				= nil;
	local intWeaponCount		= 0;	--Counter to see how many weapons the player has equipped
	local intOffhandIlevel		= 0;	--Itemlevel value of the offhand (if the player only got a offhand equipped but nothing in mainhand then we must subtract the offhand and divide by DIVIDE2)

	--Before MOP (with ranged slot)
	--DIVIDE	= 17;
	--DIVIDE2	= 16;
	DIVIDE	= 16;
	DIVIDE2	= 15;

	--iterate though and determine if its 1/2 handed and if offhand is equipped...

	for i=1, #items do
		equipSlot = items[i]["Slot"];
		if		(equipSlot == "INVTYPE_WEAPON")			then intWeaponCount = intWeaponCount +1;
		elseif	(equipSlot == "INVTYPE_WEAPONMAINHAND")	then intWeaponCount = intWeaponCount +1; intWeapon = 1;
		elseif	(equipSlot == "INVTYPE_2HWEAPON")		then intWeaponCount = intWeaponCount +1; intWeapon = 2;
		elseif	(equipSlot == "INVTYPE_HOLDABLE")		then intWeaponCount = intWeaponCount +1; isOffhand = true; intOffhandIlevel = items[i]["iLevel"]; end
		--print(" "..items[i]["Name"].." "..items[i]["iLevel"].." "..equipSlot.." ");
		sum = sum + items[i]["iLevel"];
	end--for i

	--Do the final division
	local final = 0;
	if (intWeapon == 2) then
		final = sum / DIVIDE2; --For 2 handers
	elseif (intWeapon == 1) then
		final = sum / DIVIDE; --For 1 handed weapon
	elseif (intWeapon == 0) then
		if (intWeaponCount == 1) then
			if (isOffhand == true) then
				sum = sum - intOffhandIlevel;	--If offhand is equipped but nothing in the mainhand slot then subtract the offhand
				final = sum / DIVIDE2;			--Only offhand, nothing in mainhand
			else
				final = sum / DIVIDE; --1 weapon in mainhand
			end
		elseif (intWeaponCount == 2) then
			final = sum / DIVIDE; --2 weapons
		else
			final = sum / DIVIDE2; --0 weapons
		end
	end

	local Equipped	= final; 					--We use our own calculation since we also might be looking at /target and not only the player himself
	local Total		= GetAverageItemLevel();	--Returns the players average item level as displayed in the character pane.
	if (ofTarget == true) then Total = 0; end 	--We cant determine the total itemlevel of another player so we set it to 0

	--[[
	if (equipmentSet == "" and ofTarget == false) then
		--2012-12-06:	There is currently no way to determine the proper itemlevel of an item that has been upgraded or transmorgified.
		--				GetItemInfo() and GetItemStats() will return the base stats for an itemID, and not the stats for the specific item that the user has equipped.
		--				Therefore the numbers returned when looking at other players or itemsets will not be accurate. If the player is asking for the stats of his currently equipped items then GetAverageItemLevel() return the correct numbers.
		Total, Equipped = GetAverageItemLevel();
	end]]--

	local rounded_Equipped	= math_floor(Equipped);	--Blizzard uses floor() for this rounding --math_floor( (totalAverage+0.5) );
	local rounded_Total		= math_floor(Total);

	--print("ofTarget "..tostring(ofTarget).." intWeapon "..tostring(intWeapon).." isOffhand "..tostring(isOffhand).." total: "..Total.." equipped: "..Equipped);
	return {["Equipped"]=Equipped, ["EquippedRounded"]=rounded_Equipped, ["Total"]=Total, ["TotalRounded"]=rounded_Total};
end


--Support function used by %StatUniquePets%, returns the number of uniqe pets or 0.
function Methods:StatUniquePets()
	local ff	= C_PetJournal.GetPetInfoBySpeciesID; --speciesName, speciesIcon, petType, companionID, tooltipSource, tooltipDescription, isWild, canBattle, isTradeable, isUnique, obtainable = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
	local yy	= C_PetJournal.GetOwnedBattlePetString;
	local res	= 0;
	--local iMax = 0;

	--HARDCODED: Last updated on 2016-05-16 (Legion beta 7.0.3), largest speciesID found was 1936.
	local maxID = 4000;

	for i=1, maxID do
		local speciesName = ff(i); --returns i if ID is not valid
		if (speciesName ~= nil and speciesName ~= i) then
			--if (i > iMax) then iMax=i; end
			local ownedString = yy(i); --returns nil if you dont have any pets of this species collected, otherwise a formatted string
			if (ownedString ~= nil) then res = res +1; end
		end--if
	end--for i

	--print("iMax "..iMax);
	return res;
end


--Support function used to lookup npcNames from units by using Tooltipscanner and GUID's. This function also supports the DBM-hooks and will replace some npcid's with the name of others.
function Methods:getNPCNameFromGUID(unit)
	local guid = UnitGUID(unit); --GUID format was changed in patch 6.0 to use a delimted format.
	if (guid == nil) then return nil; end
	--New Globally Unique Identifier format: Source: http://wowpedia.org/Patch_6.0.1/API_changes#Changes
		--For players: Player-[server ID]-[player UID] (Example: "Player:976:0002FD64")
		--For creatures, pets, objects, and vehicles: [Unit type]-0-[server ID]-[instance ID]-[zone UID]-[ID]-[Spawn UID] (Example: "Creature-0-976-0-11-31146-000136DF91")
		--Unit Type Names: "Creature", "Pet", "GameObject", and "Vehicle"
		--For vignettes: Vignette-0-[server ID]-[instance ID]-[zone UID]-0-[spawn UID] (Example: "Vignette-0-970-1116-7-0-0017CAE465" for rare mob Sulfurious)
	local tmp = StringParsing:split(guid, "-"); --"Creature-0-1135-1116-82308-00006376D9"  - Shadowmoon Stalker (lvl 90 beast), 6th element is the NPCID
	if (tmp == nil) then return nil; end
	if (strlower(tostring(tmp[1])) ~= "creature") then return nil; end --ignore anything but creatures
	local npcID = tonumber(tmp[6]); --6th element in the array is the NPC ID
	if (npcID == nil) then return nil; end
	--print("getNPCNameFromGUID '"..tostring(guid).."'");
	--print("npcID" '"..tostring(npcID).."'");

	--Check if the id has already been cached
	local value = nil;
	if (cache_NPCList ~= nil) then value = cache_NPCList[npcID]; end
	if (type(value) == "string") then return value; end	--Cached data; already looked up before

	local link = nil;
	if (type(value) == "number") then
		--DBM-hooks input numbers into the cache table. If these numbers are positive, it means we should output the name of that NpcID instead.
		--This allows us to replace a npc's name with another. We do this for bossfights that can only be detected through other npcs like Galakras: King Varian Wrynn, Jaina Proudmoore etc are reported by BossN but 'Galakras' is what we want to show
		--If value is a negative number it's merely a random number.
		if (value >= 0) then
			--if the value is a positive number, then its a NpcID and we use that for the name lookup instead (this also allows us to replace a npcid with the title of another like on the galakras bossfight)
			--link = ("unit:0xF53%05X00000000"):format(value);
			link = "unit:Creature-0-"..tmp[3].."-"..tmp[4].."-"..tmp[5].."-"..value.."-0"; --Construct a guid that got the new npcid inside it.
		else
			--link = ("unit:0xF53%05X00000000"):format(npcID); --The NpcName is not cached
			link = "unit:"..guid; --The NpcName is not cached
		end--if value
	else
		--link = ("unit:0xF53%05X00000000"):format(npcID); --The NpcName is not in the table
		--link = "unit:"..guid;
		return nil;
		--The NpcID is not in the list (only DBM-hooks can add things to the list).
		--To prevent the list from constantly filling with useless npcnames (we just want a few bosses) we simply return nil. The calling code can use GetUnitName() to return the name.
	end--if type

	--Try looking up using a tooltip scanner. If it fails it means that the unit isnt cached (really weird since all units in range should be cached)
	local name = HiddenTooltip:GetEquipmentItemInfo(link, "TITLE");
	--print("name '"..tostring(name).."'");
	if (name == nil) then return nil; end

	if (cache_NPCList == nil) then cache_NPCList = {}; end
	cache_NPCList[npcID] = name; --Cache name for later lookup
	return name;
end


--Support function that returns True/False if 'NameAndServer' matches 'Name'
function Methods:playernameCompare(NameAndServer, Name)
	--NameAndServer: either "Player-Server" or "Player" (hypen or no hypen)
	--Name: either "Player-Server" or "Player" (hypen or no hypen)
	if (NameAndServer == nil or Name == nil) then return false; end
	NameAndServer	= strlower(NameAndServer);
	Name			= strlower(Name);

	if ( strfind(Name, "-", 1, true) ~= nil ) then --if 'Name' contains a hypen then that means that the user wants an exact match with both name and server specified
		if (NameAndServer == Name) then return true; end --They match
		return false;
	end--if strfind

	local tmpPlayer = StringParsing:split(NameAndServer, "-"); --Strip away the servername from the string
	if (tmpPlayer == nil) then
		--Servername hypen not found in 'NameAndServer' string. Do a simple compare
		if (NameAndServer == Name) then return true; end --They match
	else
		if (type(tmpPlayer) == "table" and #tmpPlayer==2) then
			if (tmpPlayer[1] == Name) then return true; end --They match
		end
	end
	return false;
end


--####################################################################################
--####################################################################################
--Variable functions
--####################################################################################


--Function that is called by Parsing.lua to replace variable names with values
function Methods:VariableLookup(strVariable, strFormat)
	if (strVariable == nil or strVariable == "") then return "%"..strFormat.."%" end --Return %VarName% if we fail
	strVariable = strtrim(strlower(strVariable));
	local objResult = "";		--The value to return (number or string)
	----------------------------------------------

	if strVariable=="playergold" then
		local n = GetMoney(); --Amount of money the player currently has (in copper)
		objResult = (n); --Returns a texture string. This will later be converted into a text string if so needed because of output to Chat()

	elseif strVariable=="playername" or strVariable=="targetname" or strVariable=="focusname" or strVariable=="petname" then
		local n = StringParsing:replace(strVariable, "name","");
		objResult = GetUnitName(n,true);
		if objResult == nil then objResult = "<no "..strlower(n)..">" end

	elseif strVariable=="mouseovername" then
		objResult = GetUnitName("mouseover",true);
		if objResult == nil then
			local i = GameTooltip:NumLines(); --nil or a number
			if (i ~=nil and i > 0) then objResult = GameTooltipTextLeft1:GetText(); end --only care about the 1st line
		end--if
		if objResult == nil then
			local i = ItemRefTooltip:NumLines(); --nil or a number
			if (i ~=nil and i > 0) then objResult = ItemRefTooltipTextLeft1:GetText(); end --only care about the 1st line
		end--if
		if objResult == nil then objResult = "<no mouseover>" end

	elseif strVariable=="playerlevel"  or strVariable=="targetlevel" or strVariable=="focuslevel" or strVariable=="petlevel" then
		local n = StringParsing:replace(strVariable, "level","");
		objResult = tonumber(UnitLevel(n,true));
		if objResult == nil then objResult = 0 end

	elseif strVariable=="playerclass" or strVariable=="targetclass" or strVariable=="focusclass" then
		local n = StringParsing:replace(strVariable, "class","");
		objResult = UnitClassBase(n); --Is the localised name of the class
		if objResult == nil then objResult = "" end

	elseif strVariable=="playerrace" or strVariable=="targetrace" or strVariable=="focusrace" then
		local n = StringParsing:replace(strVariable, "race","");
		objResult = UnitRace(n); --Is the localised name of the class, will be nil when NPC's are targeted
		if objResult == nil then objResult = "" end

	elseif strVariable=="playergender" or strVariable=="targetgender" or strVariable=="focusgender" then
		local n = StringParsing:replace(strVariable, "gender","");
		local i = UnitSex(n); --1=Neuter, 2=Male, 3=Female
		objResult = "";
		if i == 2 then objResult = _G["MALE"]   end
		if i == 3 then objResult = _G["FEMALE"] end

	elseif strVariable=="playerfaction" or strVariable=="targetfaction" or strVariable=="focusfaction" then
		local n = StringParsing:replace(strVariable, "faction","");
		objResult = UnitFactionGroup(n); --Is the localised name of the faction (Alliance, Horde) (MOP: Adds 'Neutral' but with no texture)
		if objResult == nil then objResult = "" end

	elseif strVariable=="playercreaturetype" or strVariable=="targetcreaturetype" or strVariable=="focuscreaturetype" or strVariable=="petcreaturetype" then
		local n = StringParsing:replace(strVariable, "creaturetype","");
		objResult = UnitCreatureType(n); --Is the localised name of the type of creature (Beast, Humanoid, Undead) or nil
		if objResult == nil then objResult = "" end

	elseif strVariable=="playerguild" or strVariable=="targetguild" or strVariable=="focusguild" then
		local n = StringParsing:replace(strVariable, "guild","");
		local guildName, guildRankName, guildRankIndex, realm = GetGuildInfo(n);
		objResult = guildName;
		if objResult == nil then objResult = "" end

	elseif strVariable=="playerrealm" or strVariable=="targetrealm" or strVariable=="focusrealm" then
		local n = StringParsing:replace(strVariable, "realm","");
		if (n == "player") then
			objResult = GetRealmName();
		else
			local b = UnitIsPlayer(n); --true or false
			if (b == false) then
				objResult = ""; --NPC's dont got realms
			else
				local name = GetUnitName(n, true);
				if (name == nil) then
					objResult = ""; --nothing is targeted/focused on
				else
					local tmpSplit = StringParsing:split(name, "-"); --if the playername got a hypen (-) in it then we split on that ('name - realm')
					if (tmpSplit == nil) then
						objResult = GetRealmName(); --no realm part in player's name, must be from our own realm
					else
						objResult = strtrim(tmpSplit[2]);
					end--if tmpSplit
				end--if name
			end--if b
		end--

	elseif strVariable=="playermark" or strVariable=="targetmark" or strVariable=="focusmark" or strVariable=="petmark" then
		local n = StringParsing:replace(strVariable, "mark","");
		local i = GetRaidTargetIndex(n);

		if i == nil then objResult = ""
		elseif i == 1 then objResult = "{rt1}"--star
		elseif i == 2 then objResult = "{rt2}"--circle
		elseif i == 3 then objResult = "{rt3}"--diamond
		elseif i == 4 then objResult = "{rt4}"--triangle
		elseif i == 5 then objResult = "{rt5}"--moon
		elseif i == 6 then objResult = "{rt6}"--square
		elseif i == 7 then objResult = "{rt7}"--cross
		elseif i == 8 then objResult = "{rt8}"--skull
		else objResult = ""
		end--if i

	elseif strVariable=="playerhealth" or strVariable=="targethealth" or strVariable=="focushealth" or strVariable=="pethealth" then
		local n = StringParsing:replace(strVariable, "health","");
		objResult = UnitHealth(n); --numerical value
		if objResult == nil then objResult = "0"; else objResult = StringParsing:numberFormatK(objResult, nil, true); end --format with K/M
		strFormat = strupper(strFormat); --always format with large K/M letter

	elseif strVariable=="playermaxhealth" or strVariable=="targetmaxhealth" or strVariable=="focusmaxhealth" or strVariable=="petmaxhealth" then
		local n = StringParsing:replace(strVariable, "maxhealth","");
		objResult = UnitHealthMax(n); --numerical value
		if objResult == nil then objResult = "0"; else objResult = StringParsing:numberFormatK(objResult, nil, true); end --format with K/M
		strFormat = strupper(strFormat); --always format with large K/M letter

	elseif strVariable=="playerpsthealth" or strVariable=="targetpsthealth" or strVariable=="focuspsthealth" or strVariable=="petpsthealth" then
		local n = StringParsing:replace(strVariable, "psthealth","");
		local h = UnitHealth(n);	--numerical value
		local m = UnitHealthMax(n);	--numerical value
		if h == 0 or h == nil then	objResult = 0
		else						objResult = math_floor( ((h * 100) / m) + 0.5)  --convert the value to a percent value and round it to the nearest integer
		end

	elseif strVariable=="playerpower" or strVariable=="targetpower" or strVariable=="focuspower" or strVariable=="petpower" then
		local n = StringParsing:replace(strVariable, "power","");
		objResult = UnitPower(n); --numerical value
		if objResult == nil then objResult = "0"; else objResult = StringParsing:numberFormatK(objResult, nil, true); end --format with K/M
		strFormat = strupper(strFormat); --always format with large K/M letter

	elseif strVariable=="playermaxpower" or strVariable=="targetmaxpower" or strVariable=="focusmaxpower" or strVariable=="petmaxpower" then
		local n = StringParsing:replace(strVariable, "maxpower","");
		objResult = UnitPowerMax(n) or 0; --numerical value
		if objResult == nil then objResult = "0"; else objResult = StringParsing:numberFormatK(objResult, nil, true); end --format with K/M
		strFormat = strupper(strFormat); --always format with large K/M letter

	elseif strVariable=="playerpstpower" or strVariable=="targetpstpower" or strVariable=="focuspstpower" or strVariable=="petpstpower" then
		local n = StringParsing:replace(strVariable, "pstpower","");
		local h = UnitPower(n)		or 0; --numerical value
		local m = UnitPowerMax(n)	or 0; --numerical value
		if h == 0 or m == 0 then	objResult = 0
		else						objResult = math_floor( ((h * 100) / m) + 0.5)  --convert the value to a percent value and round it to the nearest integer
		end

	elseif strVariable=="playerpowertype" or strVariable=="targetpowertype" or strVariable=="focuspowertype" or strVariable=="petpowertype" then
		local n = StringParsing:replace(strVariable, "powertype","");
		local i, s = UnitPowerType(n); --numerical value, string that points to localized name in _G

		if (s ~= nil and s~= "") then objResult = _G[s]; --i==0 and s=="" (empty string) if you have no target.
		else objResult = "";
		end--if i

	elseif strVariable=="playernameandtitle" then
		local strName	= GetUnitName("player", true);
		local strTitle	= GetTitleName(GetCurrentTitle());
		if (strTitle == nil) then
			objResult = strName; --Player have no title selected
		else
			if (StringParsing:startsWith(strTitle, " ")) then
				if (StringParsing:startsWith(strTitle, " of") or StringParsing:startsWith(strTitle, " the")) then
					objResult = strName..strTitle; --Title is appended after the name
				else
					objResult = strName..","..strTitle; --Title is appended after the name (with a comma)
				end--if
			else
				objResult = strTitle..strName; --Title is prepended before the name
			end--if
		end--if strTitle

	elseif strVariable=="playertitle" then
		objResult = GetTitleName(GetCurrentTitle());
		if (objResult == nil) then objResult = "" end
		objResult = strtrim(objResult);

	elseif strVariable=="playercoordinates" then
		SetMapToCurrentZone();
		local dblX, dblY = GetPlayerMapPosition("player"); --apparently in some instances this function does not work.
		if (dblX == nil) then dblX = 0 end
		if (dblY == nil) then dblY = 0 end
		objResult = format("%.1f, %.1f", (dblX*100), (dblY*100));
		objResult = strtrim(objResult);

	elseif strVariable=="playerlocation" then
		SetMapToCurrentZone();
		local dblX, dblY = GetPlayerMapPosition("player"); --apparently in some instances this function does not work.
		if (dblX == nil) then dblX = 0 end
		if (dblY == nil) then dblY = 0 end
		local strZone, strSub = GetZoneText(), GetSubZoneText();
		if (strlen(strSub) == 0) then
			objResult = format("%s: %.1f, %.1f", strZone, (dblX*100), (dblY*100));
		else
			objResult = format("%s, %s: %.1f, %.1f", strZone, strSub, (dblX*100), (dblY*100));
		end
		objResult = strtrim(objResult);

	elseif strVariable=="crittername" then
		objResult = "";
		local summonedPetID = C_PetJournal.GetSummonedPetGUID();
		if (summonedPetID ~= nil) then
			local _a,_b,_c,_d,_e,_f,_g,strName = C_PetJournal.GetPetInfoByPetID(summonedPetID);
			objResult = strName;
		end--if

	elseif strVariable=="deathname" then
		objResult = cache_DeathName or "";

	elseif strVariable=="deathspell" then
		objResult = cache_DeathSpell or "";

	elseif strVariable=="deathamount" then
		objResult = tonumber(cache_DeathAmount) or 0;

	elseif strVariable=="deathoverkill" then
		objResult = tonumber(cache_DeathOverkill) or 0;

	elseif strVariable=="mountname" then
		objResult = "";
		local intNum = C_MountJournal.GetNumMounts();
		if (intNum > 0) then
			local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID = nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil;
			for i=1, intNum do
				creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID = C_MountJournal.GetDisplayedMountInfo(i);
				if (active == true) then objResult = creatureName; break; end
			end --for i
		end--if intNum

	elseif strVariable=="battletag" then
		objResult = "";
		local presenceID, battleTag, toonID, currentBroadcast, bnetAFK, bnetDND, isRIDEnabled  = BNGetInfo();
		if (battleTag ~= nil and strlen(battleTag) > 1) then objResult = battleTag; end

	elseif strVariable=="pvptimer" then
		objResult = ""; --not PVP flagged
		local b = UnitIsPVP("player"); --true or false
		if (b == true) then
			local intMS	= GetPVPTimer(); --Returns 301000 when you are not flagged or you are permanently flagged.
			if (intMS == 301000 or intMS == -1) then
				objResult = "Permanent"; --Permanent flagged for pvp
			else
				intMS 			= intMS / 1000;				--Transform into seconds from MS
				local intMin	= math_floor( (intMS/60) );	--Divide by 60 for minutes and round it down for whole minutes
				local intSec	= math_floor(intMS % 60);	--Seconds MOD 60
				intMin = self:padNumber(intMin, 2); --Prepad 0 if needed
				intSec = self:padNumber(intSec, 2);
				objResult = tostring(intMin)..":"..tostring(intSec);
			end --if intMS
		end--if b

	elseif strVariable=="leadername" then
		objResult = self:getLeaderName(false);
		if objResult == nil then objResult = "<no leader>" end

	elseif strVariable=="replyname" then
		objResult = "<no reply>";
		if (cache_LastIncomingSender ~= nil) then
			objResult = cache_LastIncomingSender;
			if (StringParsing:startsWith(objResult,"BATTLE.NET")) then objResult = ""; end --If this is a Battle.net name then we dont support %replyName% when that happends
		end--if

	elseif strVariable=="report1" or strVariable=="report2" or strVariable=="report3" then --or strVariable=="report4"
		objResult = "";
		local n = tonumber( StringParsing:replace(strVariable, "report",""), 10 );
		if (n ~= nil and cache_Report ~= nil and n >= 1 and n <= #cache_Report) then
			objResult = cache_Report[n]; --if n is inside the table bounds then its ok. (if the element is a number then do_Report saves those unformatted and we format them later on)
		end--if

	elseif strVariable=="raidrollname" then
		objResult = ""; --empty string if you are alone
		local strPrefix, intMin, intMax = "", 1, 0;
		intMax = GetNumGroupMembers(); --party or group, dosent matter
		strPrefix = "party"; --party
		if (self:InRaid(nil) == true) then strPrefix = "raid"; end --if raid

		if (intMax > 0) then --must be grouped
			local r			= math_random(intMin,intMax); --the random value includes the min/max values themselves
			local strName	= GetUnitName(strPrefix..tostring(r), true); --returns the playername with server postfix aswell
			if (strName == nil) then strName = GetUnitName("player", true); end --if it returns nil then its 'player'
			objResult		= tostring(strName);
		end

	elseif strVariable=="random" then
		if (cache_RandomNumber == nil) then self:do_Random(); end --Call Random() if it's not initialized
		objResult = cache_RandomNumber; --a numerical value

	elseif strVariable=="guildrank" then
		local guildName, guildRankName, guildRankIndex, realm = GetGuildInfo("player");
		if (guildName == nil or guildName == "") then	objResult = ""
		else											objResult = guildRankName
		end--if

	elseif strVariable=="guildachievementpoints" then
		local guildAch = GetTotalAchievementPoints(true); --GetTotalAchievementPoints() with an argument returns the guilds achivement point score
		if (guildAchiv == nil) then	objResult = 0
		else						objResult = guildAch
		end--if

	elseif strVariable=="itemlevel" then
		local tblLevel = self:getEquipmentItemLevel("", false); --get the itemlevel or nil
		objResult = 0;
		if (tblLevel ~= nil) then objResult = tonumber(tblLevel["EquippedRounded"]); end

	elseif strVariable=="itemleveltotal" then
		local tblLevel = self:getEquipmentItemLevel("", false); --get the itemlevel or nil
		objResult = 0;
		if (tblLevel ~= nil) then objResult = tonumber(tblLevel["TotalRounded"]); end

	elseif strVariable=="zonename" then
		objResult = GetRealZoneText() or "";

	elseif strVariable=="areaname" then
		objResult = GetMinimapZoneText() or "";

	elseif strVariable=="talentspec" then
		objResult = "";
		local i = GetSpecialization(); --Returns the index for the currently used spec (1,2,3,4).
		if (i ~= nil) then
			local id, name, description, icon, background, _, primaryStat = GetSpecializationInfo(i, false); --GetSpecializationInfo(specIndex, isInspect, isPet, instpecTarget, sex);
			objResult = name;
		end

	elseif strVariable=="framerate" then
		objResult = math_floor(GetFramerate() + 0.5); --framerate of the client, rounded to the nearest integer

	elseif strVariable=="screenresolution" then
		local dblWidth, dblHeight = math_floor(GetScreenWidth() + 0.5), math_floor(GetScreenHeight() + 0.5); --width& height of the client, rounded to the nearest integer
		objResult = tostring(dblWidth).."x"..tostring(dblHeight);

	elseif strVariable=="latencyhome" then
		local bandwidthIn, bandwidthOut, latencyHome, latencyWorld = GetNetStats();
		objResult = latencyHome;

	elseif strVariable=="latencyworld" then
		local bandwidthIn, bandwidthOut, latencyHome, latencyWorld = GetNetStats();
		objResult = latencyWorld;

	elseif strVariable=="localtime" then
		local intHour, intMinute = tonumber(date("%H")), tonumber(date("%M"));
		objResult = self:padNumber(intHour, 2)..":"..self:padNumber(intMinute, 2);

	elseif strVariable=="localtime12" then
		local intHour, intMinute = tonumber(date("%H")), tonumber(date("%M"));
		local strAP = " AM";
		if (intHour > 12) then intHour=intHour-12; strAP=" PM"; end
		if (intHour == 12 and intMinute == 00) then strAP = ""; end --no prefix when exactly 12:00
		objResult = self:padNumber(intHour, 2)..":"..self:padNumber(intMinute, 2)..strAP;

	elseif strVariable=="servertime" then
		local intHour, intMinute = GetGameTime();
		objResult = self:padNumber(intHour, 2)..":"..self:padNumber(intMinute, 2);

	elseif strVariable=="servertime12" then
		local intHour, intMinute = GetGameTime();
		local strAP = " AM";
		if (intHour > 12) then intHour=intHour-12; strAP=" PM"; end
		if (intHour == 12 and intMinute == 00) then strAP = ""; end --no prefix when exactly 12:00
		objResult = self:padNumber(intHour, 2)..":"..self:padNumber(intMinute, 2)..strAP;

	elseif strVariable=="watchedfactionname" then
		objResult = "";
		local strName = GetWatchedFactionInfo();
		if (strName ~= nil) then objResult = strName; end

	elseif strVariable=="weekday" then
		local intWeekday, intMonth, intDay, intYear = CalendarGetDate();
		local strWeekday = self:weekdayLookup(intWeekday, true, false);	--Lookup the weekday name from the number
		objResult = StringParsing:capitalizeWords(strWeekday, "Abc");	--First letter is uppercase by default

	elseif strVariable=="bossname" then
		objResult = "";

		if (InCombatLockdown() == true) then
			local GetUnitName	= GetUnitName; --local fpointer
			local tostring		= tostring;

			--Try bossN loop
			local maxBosses = 15;
			for i=1, maxBosses do --do a loop from 1 to 15 and compare boss names to the values we get
				local bossN = self:getNPCNameFromGUID("boss"..tostring(i)) or GetUnitName("boss"..tostring(i));
				if (bossN == nil) then break; end

				local bossName = self:getEncounterNameFromBossName(bossN); --Will return nil if youre not in an instance and the bossname isnt found in the encounter journal.
				if (bossName ~= nil) then
					--You are inside an instance and the boss is listed in the encounter journal.
					objResult = bossName;
					break;
				else
					--Not in a instance or bossname not found in the encounter journal: can be an old instance thats not listed or bossN isnt listed like the Galakras fight
					--	We still do not know the ecountername or correct bossname.
					objResult = ""; --Set to empty string and hope the other attempts will be fruitful (we will also iterate the bossN loop and try the next bossN aswell).
									--Note: 'bossN' is not used for world bosses so we dont need to check for unit classification.
				end--if bossName
			end--for i
			--print("bossA "..tostring(objResult));

			--Try target, focus and mouseover of player
			if (objResult == "") then
				local strTarget, strFocus, strMouse = self:getNPCNameFromGUID("target") or GetUnitName("target"), self:getNPCNameFromGUID("focus") or GetUnitName("focus"), self:getNPCNameFromGUID("mouseover") or GetUnitName("mouseover");
				local booTarget, booFocus, booMouse = UnitIsPlayer("target"), UnitIsPlayer("focus"), UnitIsPlayer("mouseover"); --ignore target/focus/mouseover if its a player and not a npc
				if (booTarget == true)	then strTarget = nil; end
				if (booFocus == true)	then strFocus = nil; end
				if (booMouse == true)	then strMouse = nil; end
				objResult = self:getEncounterNameFromBossName(strTarget) or self:getEncounterNameFromBossName(strFocus) or self:getEncounterNameFromBossName(strMouse) or "";
				if (objResult == "") then
					--A second check incase your target/focus is classified as a world boss (many world bosses are not classified as such though).
					local classTarget, classFocus, classMouse = UnitClassification("target"), UnitClassification("focus"), UnitClassification("mouseover");
					if (classTarget == "worldboss")	then objResult = strTarget; end
					if (classFocus	== "worldboss")	then objResult = strFocus; end
					if (classMouse	== "worldboss")	then objResult = strMouse; end
				end--if
			end--if objResult
			--print("bossB "..tostring(objResult));

			--Try target of party/raidmembers
			if (objResult == "") then
				local strType = ""; --unit prefix
				if		self:InRaid()	then strType = "raid";
				elseif	self:InParty()	then strType = "party"; end
				if (strType ~= "") then
					local intMax = GetNumGroupMembers();  --max number of party/raid members
					for i=1, intMax do
						local strUnitID	= strType..tostring(i).."target"; --want to get the name of whatever raid/partyN's target is
						local strTarget = self:getNPCNameFromGUID(strUnitID) or GetUnitName(strUnitID);
						local booTarget = UnitIsPlayer(strUnitID); --true or false
						if (booTarget == false and strTarget ~= nil) then
							local bossName	= self:getEncounterNameFromBossName(strTarget);
							if (bossName ~= nil) then
								--You are inside an instance and the boss is listed in the encounter journal.
								objResult = bossName;
								break;
							else
								--A second check incase the unit is a world boss.
								local classTarget = UnitClassification(strUnitID);
								if (classTarget == "worldboss")	then
									objResult = strTarget;
									break;
								end--if classTarget
							end--if bossName
						end--if booTarget
					end--for i
				end--if strType
			end--if objResult
			--print("bossC "..tostring(objResult));
		end--if InCombatLockdown

	elseif strVariable=="enabledequipmentset" then
		objResult = "";
		for i=1, GetNumEquipmentSets() do
			local name, icon, setID, isEquipped = GetEquipmentSetInfo(i); --, numItems, numEquipped, numInventory, numMissing, numIgnored
			if (isEquipped == true) then
				objResult = tostring(name);
				break;
			end--if
		end--for i

	elseif StringParsing:startsWith(strVariable, "equipment") then
		local n = StringParsing:replace(strVariable, "equipment", "");

		if n == "main"		then n = "MainHand"; end
		if n == "offhand"	then n = "SecondaryHand"; end
		if n == "finger1"	then n = "Finger0"; end
		if n == "finger2"	then n = "Finger1"; end
		if n == "trinket1"	then n = "Trinket0"; end
		if n == "trinket2"	then n = "Trinket1"; end

		local strSlot = n .."Slot";
		local intSlot = GetInventorySlotInfo(strSlot); --List of all slot names: http://wowprogramming.com/docs/api/GetInventorySlotInfo
		objResult = "";
		if (intSlot ~= nil) then
			objResult = GetInventoryItemLink("player", intSlot);
			if (objResult == nil) then objResult = "" end
		end--if

	elseif strVariable == "groupcount" then
		local n = GetNumGroupMembers();
		objResult = tostring(n);

	elseif strVariable == "instancedifficulty" then
		objResult = ""; --For PVP and Arena we return nothing
		if (IsInInstance() == true) then
			local strName, strType, intDifficulty = GetInstanceInfo(); --local strName, strType, intDifficulty, strDifficultyName, maxPlayers, playerDifficulty, isDynamicInstance, mapID, instanceGroupSize = GetInstanceInfo();

			if (intDifficulty==7)																then objResult = _G["PLAYER_DIFFICULTY3"]; end		--Raid Finder (25man)
			if (intDifficulty==14)																then objResult = _G["PLAYER_DIFFICULTY4"]; end		--Flexible (10-25man)
			if (intDifficulty==1 or intDifficulty==3 or intDifficulty==4 or intDifficulty==9)	then objResult = _G["PLAYER_DIFFICULTY1"]; end		--Normal (5man, 10man, 25man, 40man)
			if (intDifficulty==2 or intDifficulty==5 or intDifficulty==6)						then objResult = _G["PLAYER_DIFFICULTY2"]; end		--Heroic (5man, 10man, 25man)

			--2016-05-16 Legion beta (7.0.3): Confirmed from Blue post that Mythic+ is reported as intDifficulty==8. Maybe further API to check Keystone level.
			if (intDifficulty==8)																then objResult = _G["CHALLENGE_MODE"]; end			--WOD: Challenge Mode (5man) --Legion: Renamed to 'Mythic dungeon'. Blue post confirmed its still intDifficulty==8
			if (intDifficulty==12)																then objResult = _G["GUILD_CHALLENGE_TYPE4"]; end	--Scenario (3man)
			if (intDifficulty==11)																then objResult = _G["HEROIC_SCENARIO"]; end			--Heroic Scenario (3man)
			--Added in Warlords
			if (intDifficulty==15)																then objResult = _G["PLAYER_DIFFICULTY2"]; end		--10-30-player flexible heroic raid
			if (intDifficulty==16 or intDifficulty==23)											then objResult = _G["PLAYER_DIFFICULTY6"]; end		--20-player mythic raid or 5-player mythic dungeon
			if (intDifficulty==17)																then objResult = _G["PLAYER_DIFFICULTY3"]; end		--10-30-player flexible LFR
			if (intDifficulty==24)																then objResult = _G["PLAYER_DIFFICULTY_TIMEWALKER"]; end --5-player Timewalking




			--[[
				Source: http://wowprogramming.com/docs/api/GetInstanceInfo
				0 - None; not in an Instance.
				1 - 5-player Instance.
				2 - 5-player Heroic Instance.
				3 - 10-player Raid Instance.
				4 - 25-player Raid Instance.
				5 - 10-player Heroic Raid Instance.
				6 - 25-player Heroic Raid Instance.
				7 - Raid Finder Instance.
				8 - Challenge Mode Instance.
				9 - 40-player Raid Instance.
				10 - Not used.
				11 - Heroic Scenario Instance.
				12 - Scenario Instance.
				13 - Not used.
				14 - Flexible Raiding

				15 - 10-30-player flexible heroic raid
				16 - 20-player mythic raid
				17 - 10-30-player flexible LFR

				23 - Mythic 5 player dungeon
				24 - Timewalker 5 player dungeon
			--]]
		end--if IsInInstance()

	elseif strVariable == "instancename" then
		if (IsInInstance() == true) then
			local strName = GetInstanceInfo();
			objResult = strName;
		end--if IsInInstance()

	elseif strVariable == "instancesize" then
		objResult = 0;
		if (IsInInstance() == true) then
			local strName, strType, intDifficulty, strDifficultyName, maxPlayers = GetInstanceInfo();
			objResult = maxPlayers;
		end--if IsInInstance()

	elseif strVariable == "instancetype" then
		if (IsInInstance() == true) then
			local strName, strType = GetInstanceInfo();
			if     (strType == "raid")		then objResult = _G["RAID"];
			elseif (strType == "party")		then objResult = _G["PARTY"];
			elseif (strType == "arena")		then objResult = _G["ARENA"];
			elseif (strType == "pvp")		then objResult = _G["BATTLEGROUND"];
			elseif (strType == "scenario")	then objResult = _G["SCENARIOS"]; --Scenarios (plural);
			end
		end--if IsInInstance()

	elseif strVariable == "statachievementpoints" then
		objResult = GetTotalAchievementPoints();

	elseif strVariable == "statmounts" then
		local points = GetStatistic(339); --'Mounts owned'
		if (tonumber(points) == nil) then objResult=0 else objResult=tonumber(points) end --Some have the value '--' if they are not recorded, we always a number

	elseif strVariable == "statpets" then
		--local points = GetStatistic(338); --'Vanity pets owned'
		--if (tonumber(points) == nil) then objResult=0 else objResult=tonumber(points) end
		local numPets, numOwned = C_PetJournal.GetNumPets(true);
		if (tonumber(numOwned) == nil) then objResult=0 else objResult=tonumber(numOwned) end

	elseif strVariable == "stattoys" then
		local points = C_ToyBox:GetNumLearnedDisplayedToys();
		if (tonumber(points) == nil) then objResult=0 else objResult=tonumber(points) end --Some have the value '--' if they are not recorded, we always a number

	elseif strVariable == "statuniquepets" then
		objResult = self:StatUniquePets();

	elseif strVariable == "statdeaths" then
		local points = GetStatistic(60); --'Total deaths'
		if (tonumber(points) == nil) then objResult=0 else objResult=tonumber(points) end

	elseif strVariable == "stathonorkills" then
		local points = GetStatistic(588); --'Total Honorable Kills'
		if (tonumber(points) == nil) then objResult=0 else objResult=tonumber(points) end

	elseif strVariable == "statkills" then
		local points = GetStatistic(1197); --'Total kills'
		if (tonumber(points) == nil) then objResult=0 else objResult=tonumber(points) end

		--LFGQueueTimePassed, LFGQueueTimeEstimated,
		--Broadcastmessage
		--GoldValue

	--elseif strVariable=="" then

	end--if strVariable

	----------------------------------------------
	if (type(objResult) == "number") then return StringParsing:stringFormatNumber(objResult, strFormat); end --Format the number
	if (StringParsing:indexOf(objResult, "|H", 1) ~= nil) then return objResult end --Dont capitalize hyperlinks
	if (StringParsing:indexOf(objResult, "|T", 1) ~= nil) then return objResult end --Dont capitalize texture sequences
	return StringParsing:capitalizeWords(objResult, strFormat);	--Capitalize the string according to the inputted formatting...;
end



--####################################################################################
--####################################################################################
--OnEvent event handlers
--####################################################################################


--[[Eventhandler that will return True/False whether the current triggered event matches
function Methods:do_OnEvent(t, ...)
	--If this method is called then that means that OnEvent() was used somewhere inside an IF statement, in that case we just return False (User-Fucked-Up Scenario);
	IfThen:msg_error("OnEvent() was called even though no event was triggered.\nMake sure that OnEvent() is only used instead of IF at the beginning of a line.");
	return false;
end
--This method is used to dump out all info about a event.
function Methods:do_OnEvent_TEST(filters, currentArguments, EventName)
	if (EventName == nil) then EventName="nil" end
	IfThen:msg("OnEvent_TEST() was called for event '"..EventName.."'");

	IfThen:dump(filters,false);
	IfThen:dump(currentArguments,true);
	IfThen:dump(EventName,true);
	return true;
end]]--


--Returns True/False whether to continue processing the ACHIEVEMENT_EARNED event
function Methods:do_OnEvent_ACHIEVEMENT_EARNED(filters, ...)
	--ACHIEVEMENT_EARNED is raised when someone earns and achievement.
	local achID = tonumber( tostring(select(1, ...)) );

	if (filters == nil) then
		--coarse filter: we dont do anything

	else
		--fine filter: we filter achievement id if specified
		local achTitle	= "";		--Title of the achievement
		local strFilter	= "exact";	--Can be 'exact', 'startswith' or 'indexof'. Defaults to 'exact'.

		if (#filters >= 2) then	achTitle  = strtrim(strlower(filters[2])); end
		if (#filters >= 3) then	strFilter = strtrim(strlower(filters[3])); end

		if (achTitle ~= "" and achID ~= nil) then
			local id, name = GetAchievementInfo(achID);
			return self:doCompare(name, achTitle, strFilter, true); --case insensitive compare
		end--if achTitle
	end
	return true;
end


--Returns True/False whether to continue processing the IFTHEN_AFKORDND event
function Methods:do_OnEvent_IFTHEN_AFKORDND(filters, ...)
	--PLAYER_FLAGS_CHANGED is raised when a player goes /afk or /dnd or /pvp
	--If the unitid is myself then we continues otherwise we ignore it

	if (filters == nil) then
		--coarse filter: we accept player only player and check if the state has changed compared to earlier calls
		--filter: player
		local unitid = select(1, ...);
		if (unitid ~= "player") then return false; end

		local A = tostring(UnitIsAFK("player")); --combine 2 values into 1
		local D = tostring(UnitIsDND("player"));
		local AD = A..D; --either 'nil1' '1nil', '11' or 'nilnil'

		if cache_AFKorDNDFlag == nil then --first time when cache isn't set
			cache_AFKorDNDFlag = AD;
			return true; --we can safely return true since afk/dnd cant be a state that the user logs in as
		else
			if cache_AFKorDNDFlag == AD then return false; end --unchanged
			cache_AFKorDNDFlag = AD;
			return true;
		end
	else
		--fine filter: we do not filter.
		return true;
	end
end


--Returns True/False whether to continue processing the IFTHEN_PVP event
function Methods:do_OnEvent_IFTHEN_PVP(filters, ...)
	--PLAYER_FLAGS_CHANGED is raised when a player goes /afk or /dnd or /pvp
	--If the unitid is myself then we continues otherwise we ignore it

	if (filters == nil) then
		--coarse filter: we accept player only player and check if the state has changed compared to earlier calls
		--filter: player
		local unitid = select(1, ...);
		if (unitid ~= "player") then return false; end

		local P = tostring(UnitIsPVP("player"));
		if cache_PVPFlag == P then return false; end --unchanged
		cache_PVPFlag = P;
		return true;
	else
		--fine filter: we do not filter.
		return true;
	end
end


--Returns True/False whether to continue processing the UNIT_AURA event
function Methods:do_OnEvent_UNIT_AURA(filters, ...)
	--UNIT_AURA is raised when a player goes receives a buff or debuff
	--If the unitid is myself then we continues otherwise we ignore it
	local unitid = select(1, ...);

	if (filters == nil) then
		--coarse filter: we accept player, focus, target and pet
		--filter: player
		if (unitid == "player" or unitid == "focus" or unitid == "target" or unitid == "pet") then return true end
	else
		--fine filter: we filter on what the user has specified, but defaults to 'player'
		local unitFilter = "player";
		if (#filters >= 2) then	unitFilter = strtrim(strlower(filters[2]));	end
		if (unitid == unitFilter) then return true end
	end
	return false;
end


--Returns True/False whether to continue processing the UNIT_SPELLCAST_SUCCEEDED event
function Methods:do_OnEvent_UNIT_SPELLCAST_SUCCEEDED(filters, ...)
	--UNIT_SPELLCAST_SUCCEEDED is raised when someone sucessfully casts a spell
	local unitid = strtrim(strlower(select(1, ...)));

	if (filters == nil) then
		--coarse filter:
		--if it's the player's own cast then return false if its reported as i.e. 'party1', 'raid2' or something like that
		if (unitid ~= "player" and UnitIsUnit(unitid, "player") == true) then return false end
		--if you are in a raid, then there is no need to capture the 'partyN' events since they are the same
		if (self:InRaid(nil) and StringParsing:startsWith(unitid, "party")) then return false end

	else
		--fine filter: we filter on what the user has specified, but defaults to 'player'
		-- Arguments : ("unitID", "spell", "rank", ?, spellID)
		-- We do all the spellfilter code first so if we can filter on that, then we dont need to even look at the rest (should be slightly faster, but not pretty)
		local spell = strtrim(strlower(select(2, ...)));
		local spellFilter = "";
		if (#filters >= 2) then	spellFilter = strtrim(strlower(filters[2])); end
		if (spellFilter ~= "" and spellFilter ~= spell) then return false end

		local unitFilter = "player"; --can be 'group', 'player', 'target', 'focus' or 'pet'
		if (#filters >= 3) then	unitFilter = strtrim(strlower(filters[3]));	end
		if (unitFilter == "group" and (StringParsing:startsWith(unitid, "raid") or StringParsing:startsWith(unitid, "party") )) then unitFilter = unitid; end --'group' is the same as 'raidN' or 'partyN'
		if (unitFilter ~= unitid) then return false end

		cache_LastIncomingSender = GetUnitName(unitid, true); --set the name as the player that last /whispered us, that way we can use Methods:do_reply() later
		return true;
	end
	return true;
end


--Returns True/False whether to continue processing the PARTY_INVITE_REQUEST event
function Methods:do_OnEvent_PARTY_INVITE_REQUEST(filters, ...)
	--PARTY_INVITE_REQUEST is raised when we receive an invite for a party or raid
	local sender = select(1, ...); --name of the player that sendt the /invite

	if (filters == nil) then
		--coarse filter: we dont do anything

	else
		--fine filter: we filter on playername
		--filter: player
		local playerFilter = "";
		if (#filters >= 2) then	playerFilter = strtrim(strlower(filters[2])); end

		--if playername is specified then filter on that
		if (playerFilter ~= "" and self:playernameCompare(sender,playerFilter) ~= true) then return false; end
	end --if filter

	cache_LastIncomingSender = sender;--set the name as the player that last /whispered us, that way we can use Methods:do_reply() later
	return true;
end


--Returns True/False whether to continue processing the PLAYER_EQUIPMENT_CHANGED event
function Methods:do_OnEvent_PLAYER_EQUIPMENT_CHANGED_equipped(filters, ...)
	--PLAYER_EQUIPMENT_CHANGED is raised when a item is equipped or unequipped
	--local slot = select(1, ...); --inventory slot affected
	local hasItem = select(2, ...); --1 or nil (1 == item was equipped, nil == item was unequipped)

	if (hasItem == 1) then return true end --return true if the item was equipped
	return false;
end


--Returns True/False whether to continue processing the PLAYER_EQUIPMENT_CHANGED event
function Methods:do_OnEvent_PLAYER_EQUIPMENT_CHANGED_unequipped(filters, ...)
	return (not self:do_OnEvent_PLAYER_EQUIPMENT_CHANGED_equipped(filters, ...)); --just negate the result from the _equipped function
end


--Returns True/False whether to continue processing the ROLE_POLL_BEGIN event
function Methods:do_OnEvent_ROLE_POLL_BEGIN(filters, ...)
	--ROLE_POLL_BEGIN is raised when a party/raidleader or assistant does a role check
	if (filters == nil) then
		--coarse filter: we dont do anything

	else
		--fine filter: we filter on playername, and autohide will tell us whether to hide the frame
		--filter: player, autohide
		local sender		= select(1, ...); --name of the player that sendt the rolecheck
		local playerFilter	= "";
		local autoHide		= "";
		if (#filters >= 2) then playerFilter = strtrim(strlower(filters[2])); end
		if (#filters >= 3) then autoHide	 = strtrim(strlower(filters[3])); end

		--if playername is specified then filter on that
		if (playerFilter ~= "" and self:playernameCompare(sender,playerFilter) ~= true) then return false end

		if (autoHide ~= "" and autoHide == "true") then autoHide=true else autoHide=false end

		--If we are to hide the frame then we simply hide it
		if (autoHide) then
			--RolePollPopup_Show(RolePollPopup); --Will display the frame
			StaticPopupSpecial_Hide(RolePollPopup); --Will hide the frame
		end

		cache_LastIncomingSender = sender; --set the name as the player that last /whispered us, that way we can use Methods:do_reply() later
	end --if filter

	return true;
end


--Returns True/False whether to continue processing the LFG_ROLE_CHECK_SHOW event
function Methods:do_OnEvent_LFG_ROLE_CHECK_SHOW(filters, ...)
	--LFG_ROLE_CHECK_SHOW is raised when the LFG tool displays the "Confirm your role window", however the event is triggered several times, even after the window is shown.
	if (filters == nil) then
		--coarse filter: check the cooldown timer if its set...
		--if (LFDRolecheckPopup ~= nil and LFDRolecheckPopup:IsVisible() == true) then return false end --cant rely on the UI since that might be faster than the event triggering
		self:SetCoolDownToken("LFG_ROLE_CHECK_SHOW",nil); --This is to prevent the event from being triggered multiple times quickly after each other
		return self:do_Cooldown(5); --True the first time, False after that
	else
		--fine filter: we dont do anything

	end --if filter
	return true;
end


--Returns True/False whether to continue processing the PET_BATTLE_FINAL_ROUND event
function Methods:do_OnEvent_PET_BATTLE_FINAL_ROUND(filters, ...)
	--PET_BATTLE_FINAL_ROUND is raised when a a pet battle is finished and contains the result of the match

	if (filters == nil) then
		--coarse filter: we dont do anything
	else
		--fine filter: compare intStatus from event with what the user wants to filter on (strStatus).
		local intStatus	= select(1, ...); --1==Win, 2=Lose/Forfeit
		local strStatus	= strtrim(strlower(filters[2]));

		if (strStatus == "any"  or strStatus == "")	then return true end
		if (strStatus == "win"  and intStatus == 1)	then return true end
		if (strStatus == "lose" and intStatus == 2)	then return true end
		return false;
	end --if filter

	return true;
end


--Returns True/False whether to continue processing the READY_CHECK event
function Methods:do_OnEvent_READY_CHECK(filters, ...)
	--READY_CHECK is raised when a party/raidleader or assistant does a readycheck
	local sender = select(1, ...); --name of the player that sendt the readycheck

	--[[if (filters == nil) then
		--coarse filter: we dont do anything
	else
		--fine filter: we dont do anything
	end --if filter]]--

	cache_LastIncomingSender = sender;--set the name as the player that last /whispered us, that way we can use Methods:do_reply() later
	return true;
end
--[[These two are identical with do_OnEvent_READY_CHECK and is therefore disable to save memory
--Returns True/False whether to continue processing the RESURRECT_REQUEST event
function Methods:do_OnEvent_RESURRECT_REQUEST(filters, ...)
	--RESURRECT_REQUEST is raised when a player offers to resurrect you
	local sender = select(1, ...); --name of the player that sendt the resurrect

	--[ [if (filters == nil) then
		--coarse filter: we dont do anything
	else
		--fine filter: we dont do anything
	end --if filter] ]--

	cache_LastIncomingSender = sender;--set the name as the player that last /whispered us, that way we can use Methods:do_reply() later
	return true;
end


--Returns True/False whether to continue processing the DUEL_REQUESTED event
function Methods:do_OnEvent_DUEL_REQUESTED(filters, ...)
	--DUEL_REQUESTED is raised when a player wants to duel you
	local sender = select(1, ...); --name of the player that sendt the duel

	--[ [if (filters == nil) then
		--coarse filter: we dont do anything
	else
		--fine filter: we dont do anything
	end --if filter] ]--

	cache_LastIncomingSender = sender;--set the name as the player that last /whispered us, that way we can use Methods:do_reply() later
	return true;
end]]--


--Returns True/False whether to continue processing the CHAT_MSG_* events
function Methods:do_OnEvent_IFTHEN_CHAT_MSG(filters, ...)
	if (filters == nil) then
		--coarse filter: we dont do anything

	else
		--fine filter: we filter on channel, playername and message
		--filter: channel, player, message, type
		if (#filters < 2) then
			IfThen:msg_error("Too few arguments was passed to the 'Chat' event. You must provide at least a 'Channel' argument");
			return false;
		end

		--Arguments for this event are: (WOW_EventName, "message", "sender", "language", "channelString", "target", "flags", unknown, channelNumber, "channelName", unknown, counter)
		local channel		= tostring(strtrim(strlower(filters[2])));
		local wowEvent		= select(1, ...);
		local channelNum	= tostring( select(9, ...) ); --must use tostring() orelse we will compare numerical and string values and they will never match
		local channelName	= select(10, ...);
		local LastIncomingSender = select(3, ...);

		if ( wowEvent == "CHAT_MSG_INSTANCE_CHAT"		 and not (channel == "instance"		or channel == "group"))	then return false end
		if ( wowEvent == "CHAT_MSG_INSTANCE_CHAT_LEADER" and not (channel == "instance"		or channel == "group"))	then return false end
		if ( wowEvent == "CHAT_MSG_PARTY"				and not (channel == "party"			or channel == "group")) then return false end
		if ( wowEvent == "CHAT_MSG_PARTY_LEADER"		and not (channel == "party"			or channel == "group")) then return false end
		if ( wowEvent == "CHAT_MSG_RAID"				and not (channel == "raid"			or channel == "group")) then return false end
		if ( wowEvent == "CHAT_MSG_RAID_LEADER"			and not (channel == "raid"			or channel == "group")) then return false end
		if ( wowEvent == "CHAT_MSG_GUILD"				and channel ~= "guild") 									then return false end
		if ( wowEvent == "CHAT_MSG_OFFICER"				and channel ~= "officer") 									then return false end
		if ( wowEvent == "CHAT_MSG_WHISPER"				and channel ~= "whisper") 									then return false end
		if ( wowEvent == "CHAT_MSG_SAY"					and channel ~= "say") 										then return false end
		if ( wowEvent == "CHAT_MSG_YELL"				and channel ~= "yell") 										then return false end
		if ( wowEvent == "CHAT_MSG_SYSTEM"				and channel ~= "system") 									then return false end
		if ( wowEvent == "CHAT_MSG_CHANNEL"				and not (channel == channelNum or channel == channelName))	then return false end
		if ( wowEvent == "CHAT_MSG_BN_WHISPER"			and channel ~= "battle.net") 								then return false end
		--if ( wowEvent == "CHAT_MSG_BN_CONVERSATION"	and channel ~= "battle.net") 								then return false end
		if ( wowEvent == "CHAT_MSG_BN_INLINE_TOAST_BROADCAST" and channel ~= "battle.net") 							then return false end

		--To prevent a condition where we get a infinite loop going on between OnEvent("Chat") and Reply(), we have to check if the last /whisper was done by the player itself
		--	There is still the possibility to get a loop between a chat channel and our reaction to it but that would be throtteled by the game
		if ((wowEvent == "CHAT_MSG_WHISPER" or wowEvent == "CHAT_MSG_BN_WHISPER")) then --and IfThen:isDebug() == false
			if (StringParsing:startsWith(LastIncomingSender, "BATTLE.NET")) then
				--If this is a Battle.Net real-id name then we check if the bnetIDAccount is our own
				local bnetIDAccount = StringParsing:split(LastIncomingSender,":")[2]; --format: "BATTLE.NET:bnetIDAccount:realid-name"
				if (BNIsSelf(bnetIDAccount) == true) then return false end --Stop processing the event further
			else
				--local playerName, playerRealm = GetUnitName("player");
				--if (strlower(playerName) == strlower(LastIncomingSender)) then return false end --stop processing the event further
				if (cache_PlayerName == LastIncomingSender) then return false end --stop processing the event further if we are looking at our own chat
			end
		end--if

		local LastIncomingMessage = strtrim(strlower(select(2, ...)));
		local unitFilter		= "";
		local messageFilter		= "";
		local typeFilter		= ""; 	--can be 'exact', 'startswith' or 'indexof'. Defaults to 'exact'.

		if (#filters >= 3) then	unitFilter		= strtrim(strlower(filters[3]));	end
		if (#filters >= 4) then	messageFilter	= strtrim(strlower(filters[4]));	end
		if (#filters >= 5) then	typeFilter		= strtrim(strlower(filters[5]));	end

		--if playername is specified then filter on that
		if (strlen(unitFilter) > 0 and strlen(LastIncomingSender) > 0) then
			--If this is a Battle.Net real-id name then we can't do a compare on the name since they are escaped |K links, we then have to ignore the argument
			if (not StringParsing:startsWith(LastIncomingSender, "BATTLE.NET")) then
				if (self:playernameCompare(LastIncomingSender,unitFilter) ~= true) then return false; end
				--if (unitFilter ~= strlower(LastIncomingSender)) then return false end
			end--if BATTLE.NET
		end--unitFilter

		--if message is specified then filter on that
		if (strlen(messageFilter) > 0) then
			if (self:doCompare(LastIncomingMessage, messageFilter, typeFilter, true) == false) then return false end
		end--messageFilter

		if (strlen(LastIncomingSender) > 0) then --CHAT_MSG_SYSTEM have an empty value and we dont accept that
			cache_LastIncomingSender = LastIncomingSender; --We just want to remember the name of the sender so that Methods:do_Reply() might use it later
		end
	end --if filter

	return true;
end


--Returns True/False whether to continue processing the CHAT_MSG_* events
function Methods:do_OnEvent_IFTHEN_UI_ERROR(filters, ...)
	if (filters == nil) then
		--coarse filter: we dont do anything

	else
		--fine filter: we filter on message

		--Arguments for this event are: (number, "message")
		local LastIncomingMessage = strtrim(strlower(select(2, ...)));
		local messageFilter		= "";
		local typeFilter		= ""; 	--can be 'exact', 'startswith' or 'indexof'. Defaults to 'exact'.

		if (#filters >= 2) then		messageFilter	= strtrim(strlower(filters[2]));	end
		if (#filters >= 3) then		typeFilter		= strtrim(strlower(filters[3]));	end
		
		--if message is specified then filter on that
		if (messageFilter ~= "" and self:doCompare(LastIncomingMessage, messageFilter, typeFilter, true) == false) then return false end

	end --if filter

	return true;
end


--Returns True/False whether to continue processing the IFTHEN_SLASH event
function Methods:do_OnEvent_IFTHEN_SLASH(filters, ...)
	if (filters == nil) then
		--coarse filter: we dont do anything

	else
		--fine filter: we filter on title
		if (#filters < 2) then
			IfThen:msg_error("Too few arguments was passed to the 'Slash' event. You must provide at least a 'Title' argument");
			return false;
		end
		local title		= strtrim(strlower(filters[2]));
		local currTitle	= strtrim(strlower(select(1, ...)));

		if (title ~= currTitle) then return false end -- if the title does match then return false
	end --if filter

	return true;
end


--Returns True/False whether to continue processing the IFTHEN_CLOCK event
function Methods:do_OnEvent_IFTHEN_CLOCK(filters, ...)
	if (filters == nil) then
		--coarse filter: we dont do anything

	else
		--fine filter: we filter on hour, minute and weekday
		local intHour		= StringParsing:tonumber(filters[2]);
		local intMinute		= StringParsing:tonumber(filters[3]);
		if (intHour == nil or intMinute == nil) then return false end			--Invalid values

		local strWeekday	= "";
		if (#filters >=4) then strWeekday = strtrim(strlower(filters[4])); end
		local intWeekday	= self:weekdayLookup(strWeekday, false, true); --lookup the weekday number from the string

		local srvWeekday, srvMonth, srvDay, srvYear = CalendarGetDate();
		if (intWeekday ~= -1 and intWeekday ~= srvWeekday) then return false end --Wrong day of the week

		local srvHour, srvMinute = GetGameTime();
		if (intMinute == srvMinute and intHour == srvHour) then
			--Exact hour/minute match
			self:SetCoolDownToken("IFTHEN_CLOCK_"..tostring(intWeekday).."_"..tostring(intHour).."_"..tostring(intMinute),nil); --This is to prevent the event from being triggered multiple times
			return self:do_Cooldown(70); --True the first time, False after that (we set a cooldown for this specific weekday/hour/minute combo that lasts for 70 seconds)
		end
		return false;
	end --if filter

	return true;
end


--Returns True/False whether to continue processing the IFTHEN_TIMER event
function Methods:do_OnEvent_IFTHEN_TIMER(filters, ...)
	if (filters == nil) then
		--coarse filter: we dont do anything

	else
		--fine filter: we filter on title
		local eventTitle	= strtrim(strlower(select(1, ...)));
		local title 		= strtrim(strlower(filters[2]));

		title = "timer_"..title; --we added a prefix incase the timer title is a number so that we dont accidentally index the table
		if (title == eventTitle) then return true end
		return false;
	end --if filter

	return true;
end


--Standalone eventhandler that is used for the DeathName, DeathSpell, DeathAmount and DeathOverkill variables.
function Methods:do_COMBAT_LOG_EVENT_UNFILTERED(event1, timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2, destGUID, destName, destFlags, destFlags2, ...)
	if (destName ~= cache_PlayerName) then return nil; end --Ignore events not related to myself
	--The event always have these 11 arguments, the remaining argument vary depending on the event
	--Source: http://www.wowwiki.com/API_COMBAT_LOG_EVENT

	if (event=="RANGE_DAMAGE" or event=="SPELL_DAMAGE" or event=="SPELL_PERIODIC_DAMAGE" or event=="SPELL_BUILDING_DAMAGE") then
		--We want to monitor all _DAMAGE suffixes, we are looking for the 'overkill' value to have a positive value
		--local spellID, spellName, spellSchool = nil, nil, nil;																					--RANGE_, SPELL_, SPELL_PERIODIC_ and SPELL_BUILDING_ use these prefixes
		--local amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = nil, nil, nil, nil, nil, nil, nil, nil, nil;	--The suffix _DAMAGE uses these arguments
		local spellID, spellName, spellSchool, amount, overkill = ...;																				--prefix and suffix combined on the same line (just the one we use)

		if (overkill > 0) then
			--We just died, log the data
			cache_EnvirSpell	= nil; --ENVIRONMENTAL_DAMAGE was not the last thing that happened to us.
			cache_DeathName		= sourceName;
			cache_DeathSpell	= spellName;
			cache_DeathAmount	= amount;
			cache_DeathOverkill	= overkill;
		end--if

	elseif (event=="SWING_DAMAGE") then
		--We want to monitor all _DAMAGE suffixes, we are looking for the 'overkill' value to have a positive value
																																					--no variables for this prefix (SWING_)
		--local amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = nil, nil, nil, nil, nil, nil, nil, nil, nil;	--The suffix _DAMAGE uses these arguments
		local amount, overkill = ...;																												--prefix and suffix combined on the same line (just the one we use)

		if (overkill > 0) then
			--We just died, log the data
			cache_EnvirSpell	= nil; --ENVIRONMENTAL_DAMAGE was not the last thing that happened to us.
			cache_DeathName		= sourceName;
			cache_DeathSpell	= ""; --Autoattack
			cache_DeathAmount	= amount;
			cache_DeathOverkill	= overkill;
		end--if

	elseif (event=="ENVIRONMENTAL_DAMAGE") then
		--We want to monitor all _DAMAGE suffixes, we are looking for the 'overkill' value to have a positive value
		--local environmentalType = nil;																											--ENVIRONMENTAL_ use this single prefix
		--local amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = nil, nil, nil, nil, nil, nil, nil, nil, nil;	--The suffix _DAMAGE uses these arguments
		local environmentalType, amount = ...;																										--prefix and suffix combined on the same line (just the one we use)

		--'overkill' will always have the value 0, the player simply dies.
		--The solution is to always remember the last ENVIRONMENTAL_DAMAGE and if UNIT_DIED is triggered then we will use the last logged cache_Envir-values (if they were the last damage that hit us).
		cache_EnvirSpell	= environmentalType; --Will be localized strings (Falling, Fire etc)
		cache_EnvirAmount	= amount;

	elseif (event=="UNIT_DIED" and cache_EnvirSpell ~= nil) then
		--if ENVIRONMENTAL_DAMAGE was the last thing that damaged us it was most likely what killed the player.
		cache_DeathName		= "";				--sourceName is always nil for ENVIRONMENTAL_DAMAGE event
		cache_DeathSpell	= cache_EnvirSpell;	--Will be localized strings (Falling, Fire etc)
		cache_DeathAmount	= cache_EnvirAmount;
		cache_DeathOverkill	= 0;				--Will always be 0
		cache_EnvirSpell	= nil;
	end--if event

	return nil;
end


--####################################################################################
--####################################################################################
--Conditional methods
--####################################################################################


--Returns True/False whether String1 compares to String2.
function Methods:Compare(t)
	--Compare ( String1, String2, OP, IgnoreCase )
	local strString1	= t[1];
	local strString2	= t[2];
	local strOP			= "eq";
	local booIgnoreCase	= "true";
	if (#t >=3) then strOP			= strtrim(strlower(t[3])) end
	if (#t >=4) then booIgnoreCase	= strtrim(strlower(t[4])) end
	if (booIgnoreCase == "true") then booIgnoreCase = true; else booIgnoreCase = false; end

	local cmp = self:doOP(strString1, strString2, strOP, booIgnoreCase, false); --does a string compare based on the values
	return cmp;
end


--Returns True/False whether Value1 compares to Value2.
function Methods:CompareNum(t)
	--CompareNum ( Value1, Value2, OP, IntegerRound )
	local intValue1		= StringParsing:tonumber(t[1]);
	local intValue2		= StringParsing:tonumber(t[2]);
	local strOP			= "eq";
	local booIntRound	= "true";
	if (#t >=3) then strOP			= strtrim(strlower(t[3])) end
	if (#t >=4) then booIntRound	= strtrim(strlower(t[4])) end
	if (booIntRound == "true") then booIntRound = true; else booIntRound = false; end

	if (intValue1 == nil or intValue2 == nil) then
		IfThen:msg_error("Value arguments for CompareNum() must be numbers.)");
		return false;
	end --must be a number

	if (booIntRound) then
		--Round the numbers to the nearest whole integer. ('10.4' becomes '10' and '10.5' becomes '11'
		intValue1 = math_floor(intValue1 +0.5);
		intValue2 = math_floor(intValue2 +0.5);
	end--if booIntRound

	local cmp = self:doOP(intValue1, intValue2, strOP, nil, true); --does a string compare based on the values
	return cmp;
end


--Will return True/False whether the UI is showing any of the special actionbar's
function Methods:ExtraActionBarVisible(t)
	--if self:argumentCheck(t,"ExtraActionBarVisible",1,0) == false then return false end
	local n = nil; --number between 1 and 6. If not specified we use nil.
	if (t ~= nil and #t>0) then n = strtrim(strlower(t[1])) end

	local intN = nil;
	if (n ~= nil) then
		intN = tonumber(n);
		if (intN == nil) then
			IfThen:msg_error("Button argument for ExtraActionBarVisible() must be a number.");
			return false;
		end
		if (intN < 1 or intN > 6) then
			IfThen:msg_error("Button argument for ExtraActionBarVisible() must be a number between 1 and 6.");
			return false;
		end
	end--if n

	local a = HasVehicleActionBar();
	local b = HasOverrideActionBar();
	local c = HasBonusActionBar();
	local d = IsPossessBarVisible();
	local e = HasExtraActionBar();

	if (intN == nil) then
		--just check if the toolbar is visible
		if (a==true or b==true or c==true or d==true or e==true) then return true; end
	else
		--Check to see if the button is available
		local r = "";
		if		a == true	then r = "OverrideActionBarButton";	--NOT confirmed
		elseif	b == true	then r = "OverrideActionBarButton";	--Confirmed.	Tillers faction uprooting weeds.
		elseif	c == true	then r = "OverrideActionBarButton";	--NOT confirmed
		elseif	d == true	then r = "PossessButton";			--NOT confirmed
		elseif	e == true	then r = "ExtraActionButton";		--Confirmed.	Klaxxi Mind control enhancement
		else	return false; --no bar is visible.
		end
		r = r..tostring(intN);	--Append the buttonnumber to the toolbarname
		local btn = _G[r];		--These are all "CheckButton" objects so they should have :IsVisible() defined
		if (btn ~= nil and btn:IsVisible() == true) then return true; end
	end--if intN

	return false;
end


function Methods:HasBuff(t)
	--if self:argumentCheck(t,"HasBuff",1,3) == false then return false end
	local n		= strtrim(strlower(tostring(t[1])));
	local unit	= "player";	--can either be 'player', 'focus' or 'target'
	local stack	= 0;		--must be a positive integer value (0 means we do not check for stackcount)
	local strOP	= "eq";		--gt/lte/eq etc
	if (#t >= 2) then unit  = strtrim(strlower(t[2])); end
	if (#t >= 3) then stack = StringParsing:tonumber(t[3]);	end
	if (#t >= 4) then strOP = strtrim(strlower(t[4])); end
	if (stack == nil or stack < 0) then
		IfThen:msg_error("Count argument for HasBuff() must be a positive number.)");
		return false;
	end

	--local name, rank, icon, count = UnitAura(unit, n, "", "HELPFUL");
	for i=1,100 do
		local name, rank, icon, count = UnitAura(unit, i);
		if (name == nil) then return false end --no more found
		if (strtrim(strlower(name)) == n) then
			if (count == 0) then count = 1; end --count is returned as 0 for many spells and ablities when they are active.
			if (stack > 0) then return self:doOP(count, stack, strOP, nil, true); end --if stack is 0 then we do not check for stackcount
			return true; --found the buff/debuff/spell/aura/item with the correct name (and possibly stackcount)
		end--if name
	end--if
	return false;
end


--Returns True/False whether the player has a given talent enabled or not.
function Methods:HaveTalent(t)
	--if self:argumentCheck(t,"HaveTalent",1,1) == false then return false end
	local n		= strtrim(strlower(t[1])); --String. Localized name of talent.
	local boo	= "false"; --Boolean. PvP. True== check PVP honor talents
	if (#t >= 2) then boo = strtrim(strlower(t[2])); end
	if (boo == "true") then boo = true; else boo = false; end

	--Non-pvp talents
	--local intSpec	= GetSpecialization(); --Currently enabled spec. Returns 1,2,3 or 4
	local intSpec	= 1; --Seems to only work with 1
	local intRow	= MAX_TALENT_TIERS or 7;	--Defined in FrameXML\TalentFrameBase.lua
	local intCol	= NUM_TALENT_COLUMNS or 3;
	local ptr		= GetTalentInfo; --local fpointer

	if (boo == true) then --Check PVP talents.
		intSpec	= 1; --Seems to only work with 1
		intRow	= MAX_PVP_TALENT_TIERS or 6;	--Defined in FrameXML\TalentFrameBase.lua
		intCol	= MAX_PVP_TALENT_COLUMNS or 3;
		ptr		= GetPvpTalentInfo; --local fpointer
	end--if boo

	local talentID, name, iconTexture, selected, available = nil,nil,nil,nil,nil;
	for i=1, intRow do
		for j=1, intCol do
			talentID, name, iconTexture, selected, available = ptr(i,j,intSpec,false);
			if (selected == true and strlower(name) == n) then return true; end
		end--for j
	end--for i
	return false;
end


--Returns True/False whether a given spell or item has no cooldown
function Methods:HaveCooldown(t)
	--if self:argumentCheck(t,"HaveCooldown",1,1) == false then return false end
	local itemName = t[1];

	--Maybe we are dealing with an item?
	local name, link = GetItemInfo(itemName);	--will get us the link of the item
	local itemID = self:getItemIDfromItemLink(link); --if we get an itemID then this is an item


	local start, duration, enable, msLength = nil, nil, nil, 0;
	--Maybe we are dealing with a spell?
	if (itemID == nil) then
		start, duration, enable	= GetSpellCooldown(itemName);
		msLength				= GetSpellBaseCooldown(itemName) or 0; --Only works for spells and returns milliseconds
		if (msLength > 0) then msLength = msLength / 1000; end --Convert from millisecond to whole seconds
	else
		start, duration, enable = GetItemCooldown(itemID);
	end--if itemID

	if (duration == nil) then
		IfThen:msg_error("HaveCooldown('"..itemName.."') is not an item/spell.");
		return false;
	end --no item or spell found


	if (itemID == nil) then
		--Spell
		--both start and duration are linked. meaning that start and duration will either give the value of the global cooldown triggered last OR
		--if we are past the global cooldown then start and duration will return the values for the spell in question.

		if (duration == 0) then
			--print(itemName.." FALSE  have no cooldown at the moment "..duration);
			return false; --spell has no cooldown

		elseif (duration == msLength) then
			--print(itemName.." TRUE  this is not off the cooldown of "..duration);
			return true; --GCD is over, but the spell still has a cooldown

		elseif (duration > 0 and msLength == 0) then
			--print(itemName.." FALSE  we are seeing the GCD on a instant cast spell "..duration);
			return false; --GCD right now, but nothing after it

		elseif (duration > msLength) then
			--print(itemName.." TRUE  this spell got a cooldown longer than its basevalue. probably due to talent or something changing its cooldown "..duration.." "..msLength);
			return true;	--GCD is (maybe) over, but the spell still has a cooldown
							--Side effect: spells that are >0 in msLength but less than the global cooldown (i.e. haste over-buffed) will also trigger here. This is acceptable.
		--[[
		elseif (duration < msLength) then
			--This is exactly the same as when the GCD happens (duration is less than the msLength), we simply ignore it.
			print(itemName.."  this spell got a cooldown shorter than its basevalue. probably due to talents or something changing its cooldown "..duration.." "..msLength);
			return true; --still has a cooldown (might just be the GCD tho)

		elseif (duration > 0 and msLength > 0) then
			--This will also be true if we cast a completely different spell, and that triggers the GCD, the base spell will still have a value
			print(itemName.."  we are seeing the GCD on a spell that has a cooldown aswell after the GCD is done "..(duration+msLength) )
			return true; --GCD right now, and we got a cooldown after it
		--]]
		else
			--print(itemName.." FALSE  end of the line, GCD is up but we cant determine if its this spell or some other spell that triggered it");
			return false; --no cooldown
		end--if

	else
		--Item
		if (duration == 0) then
			return false; --no cooldown on this item
		else
			return true;
		end--if
	end--if itemID
	return false;
end


--Returns True/False whether the player is in control of the character
function Methods:HaveLostControl(t)
	--if self:argumentCheck(t,"HaveLostControl",1,1) == false then return false end

	--local c = HasFullControl(); --1 or nil
	local i = C_LossOfControl.GetNumEvents(); --0 or a number
	if (i ~= 0) then return true; end

	return false;
end


--Return True/False whether the input name matches that of the unit
function Methods:HasName(t)
	--if self:argumentCheck(t,"HasName",1,2) == false then return false end
	local strName = strtrim(strlower(t[1]));
	local strUnit = "player";
	if (#t >= 2) then strUnit = strtrim(strlower(t[2])); end

	local name = GetUnitName(strUnit, true);
	if (name == nil) then return false end --nothing targeted
	if (strName == strlower(name)) then return true end
	return false;
end


--Returns True/False whether the unit has the given amount of health or not.
function Methods:HasHealth(t)
	--HasHealth ( unit, value, valueType, op)
	--	unit		== player, target, focus
	--	value		== numerical value
	--	valueType	== percent, numeric
	--	op			== gt/lte/eq etc
	local strUnit		= strtrim(strlower(t[1]));
	local intValue		= StringParsing:tonumber(t[2]);
	local strValueType	= "percent";
	local strOP			= "eq";
	if (#t >=3) then strValueType	= strtrim(strlower(t[3])) end
	if (#t >=4) then strOP			= strtrim(strlower(t[4])) end

	if (strOP == "") then
		IfThen:msg_error("OP argument for HasHealth() can not be an empty string.)");
		return false;
	end --must be a string

	if (intValue == nil) then
		IfThen:msg_error("Value argument for HasHealth() must be a number.)");
		return false;
	end --must be a number

	if (intValue < 0) then
		IfThen:msg_error("Value argument for HasHealth() must be a number above 0.)");
		return false;
	end

	local intHealth		= UnitHealth(strUnit);
	local intHealthMax	= UnitHealthMax(strUnit);
	if (intHealth == nil or intHealthMax == nil or intHealthMax == 0) then return false end

	local intP = (intHealth * 100) / intHealthMax; --convert the value to a percent value
	if (strValueType ~= "percent") then intP = intHealth end

	local cmp = self:doOP(intP, intValue, strOP, nil, true); --does a numerical compare based on the values
	return cmp;
end


--Returns True/False whether the player has a given quest.
function Methods:HaveOpenQuest(t)
	--if self:argumentCheck(t,"HaveOpenQuest",1,1) == false then return false end
	local n			= strtrim(strlower(t[1]));
	local qMax		= GetNumQuestLogEntries(); --Will return number of quests + category headings.

	--iterate though quests and find a matcing title
	local GetQuestLogTitle	= GetQuestLogTitle; --local fpointer
	local strlower			= strlower;
	for i=1, qMax do
		local title = strlower(GetQuestLogTitle(i));
		if (n == title) then return true; end
	end--for i

	return false;
end


--Returns True/False whether the player has a given quest.
function Methods:IsQuestCompleted(t)
	--if self:argumentCheck(t,"IsQuestCompleted",1,1) == false then return false end
	local n			= strtrim(strlower(t[1]));
	local qMax		= GetNumQuestLogEntries(); --Will return number of quests + category headings.

	--iterate though quests and find a matcing title
	local GetQuestLogTitle	= GetQuestLogTitle; --local fpointer
	local strlower			= strlower;
	for i=1, qMax do
		local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID = GetQuestLogTitle(i);
		if (n == strlower(title) and questID ~= nil) then return IsQuestComplete(questID); end
	end--for i
	return false;
end


--Return True/False whether the input name matches that of the players summoned non-combat pet
function Methods:HaveCritter(t)
	--if self:argumentCheck(t,"HaveCritter",0,1) == false then return false end
	local strName = "";
	if (#t >= 1) then strName = strtrim(strlower(t[1])); end

	local summonedPetID = C_PetJournal.GetSummonedPetGUID();
	if (summonedPetID == nil) then return false; end --no pet summoned at the moment
	if (strName == "") then return true; end

	--Exact match on name
	local a,b,c,d,e,f,g,name = C_PetJournal.GetPetInfoByPetID(summonedPetID) --8th argument is name
	if (strName == strlower(name)) then return true; end

	return false;
end


--Return True/False whether the input name matches that of the players summoned mount
function Methods:HaveMount(t)
	--if self:argumentCheck(t,"HaveMount",0,1) == false then return false end
	local strName = "";
	if (#t >= 1) then strName = strtrim(strlower(t[1])); end

	local intNum = C_MountJournal.GetNumMounts();
	if (intNum == nil or intNum < 1) then return false; end --player got no pets/mounts

	local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID = nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil, nil;
	for i=1, intNum do
		creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID = C_MountJournal.GetDisplayedMountInfo(i);
		if (strName == "") then --any pet/mount will do
			if (active == true) then return true; end
		else
			if (active == true and strlower(creatureName) == strName) then return true; end
		end
	end --for i
	return false; --no active pet/mount found or didn't find a match on the name
end


--Return True/False whether the input name matches that of the players pet
function Methods:HavePet(t)
	--if self:argumentCheck(t,"HavePet",0,1) == false then return false end
	local strName = "";
	if (#t >= 1) then strName = strtrim(strlower(t[1])); end

	local name = GetUnitName("pet", false);
	if (name == nil)					then return false end --nothing targeted
	if (strName == "" and name ~= nil)	then return true end  --no name provided and we got something targeted
	if (strName == strlower(name))		then return true end  --exact match on name
	return false;
end


--[[Returns True/False whether the unit has the given amount of health or not.
function Methods:HasPower(t)
	--HasPower ( unit, value, valueType, op )
	--	unit		== player, target, focus
	--	value		== numerical value
	--	valueType	== percent, numeric
	--	op			== gt/lte/eq etc
	--	powertype	== mana,rage,runic power etc
	local strUnit		= strtrim(strlower(t[1]));
	local intValue		= StringParsing:tonumber(t[2]);
	local strValueType	= "percent";
	local strOP			= "eq";
	local strType		= "";
	if (#t >=3) then strValueType	= strtrim(strlower(t[3])) end
	if (#t >=4) then strOP			= strtrim(strlower(t[4])) end

	if (strOP == "") then
		IfThen:msg_error("OP argument for HasPower() can not be an empty string.)");
		return false;
	end --must be a string

	if (intValue == nil) then
		IfThen:msg_error("Value argument for HasPower() must be a number.)");
		return false;
	end --must be a number

	if (intValue < 0) then
		IfThen:msg_error("Value argument for HasPower() must be a number above 0.)");
		return false;
	end

	local intPowerType	= UnitPowerType(strUnit);
	local intPower		= UnitPower(strUnit, intPowerType);
	local intPowerMax	= UnitPowerMax(strUnit, intPowerType);
	if (intPower == nil or intPowerMax == nil or intPowerMax == 0) then return false end

	local intP = (intPower * 100) / intPowerMax; --convert the value to a percent value
	if (strValueType ~= "percent") then intP = intPower end

	local cmp = self:doOP(intP, intValue, strOP, nil, true); --does a numerical compare based on the values
	return cmp;
end]]--


--Returns true/false whether the unit currently got the correct amount of power or secondary power.
function Methods:HasPower(t)
	--HasPower ( Unit, Value, ValueType, OP, PowerType )
	--	Unit		== player, target, focus
	--	Value		== numerical value
	--	ValueType	== percent, numeric
	--	OP			== gt/lte/eq etc
	--	PowerType	== mana,rage,runic power etc
	--if self:argumentCheck(t,"HasPower",2,5) == false then return false end
	local strUnit		= strtrim(strlower(t[1]));
	local intValue		= StringParsing:tonumber(t[2]);
	local strValueType	= "percent";
	local strOP			= "eq";
	local strPowerType	= "";
	if (#t >=3) then strValueType	= strtrim(strlower(t[3])) end
	if (#t >=4) then strOP			= strtrim(strlower(t[4])) end
	if (#t >=5) then strPowerType	= strtrim(strlower(t[5])) end

	if (strOP == "") then
		IfThen:msg_error("OP argument for HasPower() can not be an empty string.");
		return false;
	end --must be a string

	if (intValue == nil) then
		IfThen:msg_error("Value argument for HasPower() must be a number.");
		return false;
	end --must be a number

	if (intValue < 0) then
		IfThen:msg_error("Value argument for HasPower() must be a number above 0.");
		return false;
	end

	--PowerType can be a secondary resource that a class/spec has in addition to its primary resource.
	--For example: Rogue's got Energy as the primary and Combo points as the secondary for all its specs.
	--Another example: Windwalker Monks got Mana + Chi. The other monk specs dont use Chi.

	--If strUnit=="target" and you ask about a secondary resource then it will return 0.
	--Example strUnit=="target", strPowerType="combo points". Even if you are targeting a Rogue, then the function will always return 0.

	--Get the value of the unit's default, primary resource (mana, rage, energy, whatever)
	local intPowerType	= UnitPowerType(strUnit);
	local intPower		= UnitPower(strUnit, intPowerType); --We dont care what type it is, just that it has a value.
	local intPowerMax	= UnitPowerMax(strUnit, intPowerType);

	--If the user has specified to ask for a named resource then the code below will ask for that one.
	--If the unit's class does not have that resource; like asking for 'Chi' from a Mage then it will return 0.
	--In that case, it's the user that has fucked up by asking for an impossible combination.
	if (strPowerType ~= "") then
		if (cache_PowerTypes == nil) then --Create cache object first time we need it.
			--Source: \FrameXML\Constants.lua	See also: http://www.wowinterface.com/forums/showthread.php?t=53140    http://www.wowpedia.org/PowerType
			--HARDCODED: 2016-05-18 (Legion beta 7.0.3) Hardcoded list of localized name linked to the SPELL_POWER_* global constants defined in WoW.
				--Remember to also update the Documentation page for HasPower()
				--This way the user can specify 'lunar power' and we know what powertype it means. Also added a few different versions: both 'combo point' and 'combo' are accepted.
				--To check for changes you can do a g_find("SPELL_POWER")
			local f = {};
			f["mana"]				= SPELL_POWER_MANA;			--0
			f["rage"]				= SPELL_POWER_RAGE;			--1
			f["focus"]				= SPELL_POWER_FOCUS;		--2
			f["energy"]				= SPELL_POWER_ENERGY;		--3
			f["combo points"]		= SPELL_POWER_COMBO_POINTS;	--4
			f["combo"]				= SPELL_POWER_COMBO_POINTS;	--extra
			f["runes"]				= SPELL_POWER_RUNES;		--5
			f["rune"]				= SPELL_POWER_RUNES;		--extra
			f["runic power"]		= SPELL_POWER_RUNIC_POWER;	--6
			f["soul shards"]		= SPELL_POWER_SOUL_SHARDS;	--7
			f["soul"]				= SPELL_POWER_SOUL_SHARDS;	--extra
			f["lunar power"]		= SPELL_POWER_LUNAR_POWER;	--8
			f["lunar"]				= SPELL_POWER_LUNAR_POWER;  --extra
			f["holy power"]			= SPELL_POWER_HOLY_POWER;	--9
			f["holy"]				= SPELL_POWER_HOLY_POWER;	--extra
			--f["alternate power"]	= SPELL_POWER_ALTERNATE_POWER;--10
			f["maelstrom"]			= SPELL_POWER_MAELSTROM;	--11
			f["chi"]				= SPELL_POWER_CHI;			--12
			f["insanity"]			= SPELL_POWER_INSANITY;		--13
			--f["obsolete"]			= SPELL_POWER_OBSOLETE;		--14
			--f["obsolete2"]		= SPELL_POWER_OBSOLETE2;	--15
			f["arcane charges"]		= SPELL_POWER_ARCANE_CHARGES;--16
			f["arcane"]				= SPELL_POWER_ARCANE_CHARGES;--extra
			f["fury"]				= SPELL_POWER_FURY;			--17
			f["pain"]				= SPELL_POWER_PAIN;			--18

			cache_PowerTypes = f;--cache values for later lookup.
		end--cache_PowerTypes

		intPowerType = cache_PowerTypes[strPowerType];
		if (intPowerType == nil) then
			IfThen:msg_error("HasPower() Could not find a PowerType called '"..tostring(strPowerType).."'. Check your spelling.");
			return false;
		else
			intPower	= UnitPower(strUnit, intPowerType); --Current value of the unit's specified resource.
			intPowerMax	= UnitPowerMax(strUnit, intPowerType);
		end--if
	end--if strPowerType

	--Special Case: With Death Knights we need to iterate over each rune and check to see if its up or not...
	if (intPowerType == SPELL_POWER_RUNES) then
		if (strUnit ~= "player") then
			--If the player himself is a DK and he is targeting a DK then not returning false could return the result for yourself and not your target.
			IfThen:msg_error("HasPower() You can not count the runes of another player.");
			return false;
		end

		intPower = 0;
		for i=1, intPowerMax do
			if (GetRuneCount(i) == 1) then intPower = intPower +1; end --If the rune isn't on a cooldown then increment
		end--for i
	end--if intPowerType

	if (intPower == nil or intPowerMax == nil or intPowerMax == 0) then return false end
	local intP = (intPower * 100) / intPowerMax; --convert the value to a percent value
	if (strValueType ~= "percent") then intP = intPower end

	local cmp = self:doOP(intP, intValue, strOP, nil, true); --Does a numerical compare based on the values
	return cmp;
end


--Returns true/false whether the player has learned the specified profession
function Methods:HaveProfession(t)
	--if self:argumentCheck(t,"HaveProfession",1,1) == false then return false end
	local lowTitle = ""; --localized profession name
	if (t ~= nil and #t >=1) then lowTitle = strtrim(strlower(t[1])) end
	if (lowTitle == nil or lowTitle == "") then print("NNN"); return false end

	local list = {GetProfessions()}; --Can't use #list for some reason, use 20 as hardcoded maxvalue
	local GetProfessionInfo = GetProfessionInfo; --local fpointer
	local pcall				= pcall;
	for i=1, 20 do --HARDCODED: 2016-05-15 (Legion beta 7.0.3) Cant use #list so we use a arbitrary value here.
		--Need to wrap this in a pcall() since it sometimes for no reason just fails
		local b, name, texture, rank, maxRank, numSpells, spelloffset, skillLine, rankModifier = pcall(GetProfessionInfo, list[i]);
		if (b == false) then name = ""; end
		if (strlower(name) == lowTitle) then return true; end
	end--for i
	return false;
end


--Returns true/false whether the tradeskill windows is open
function Methods:IsTradeSkillReady(t)
	--if self:argumentCheck(t,"IsTradeSkillReady",0,1) == false then return false end
	local strProfession	= ""; --Profession name; localized name.
	if (t ~= nil and #t >=1) then strProfession = strtrim(strlower(t[1])) end

	local b = C_TradeSkillUI.IsTradeSkillReady();--true or false
	if (b == true and strProfession ~= "" and _G["TradeSkillFrameTitleText"] ~= nil) then --Compare strProfession with what the UI is showing..
		if (strProfession == strtrim(strlower(tostring(TradeSkillFrameTitleText:GetText()))) ) then
			print("tradeskillready names match");
			return true;
		else
			print("tradeskillready do not match");
		end
		return false;
	end--if b
	return b;
end


--Returns True/False whether there are temporary enchantments on the player's weapons. Does not return information about permanent enchantments added via Enchanting, Runeforging, etc; refers instead to temporary buffs such as wizard oils, sharpening stones, rogue poisons, and shaman weapon enhancements
function Methods:HasTempWeaponEnchant(t)
	--if self:argumentCheck(t,"HasTempWeaponEnchant",0,1) == false then return false end

	local weaponSlot = "main"; --can either be 'main' (default), 'offthand' or 'both'
	if (#t == 1) then weaponSlot = strtrim(strlower(t[1])) end

	local hasMainHandEnchant, mainHandExpiration, mainHandCharges, hasOffHandEnchant, offHandExpiration, offHandCharges = GetWeaponEnchantInfo(); --bug?? offHandExpiration returns true/false. not hasOffHandEnchant
	if (hasMainHandEnchant == false and offHandExpiration == false) then return false end --no enchants at all, return false

	if (weaponSlot == "both") then
	  if (hasMainHandEnchant == true and offHandExpiration == true) then return true end
	elseif (weaponSlot == "offhand") then
		if (offHandExpiration == true) then return true end
	else --defaults to 'main'
		if (hasMainHandEnchant == true) then return true end
	end--if

	return false;
end


--Returns True/False whether the player's got the achievement
function Methods:HaveAchievement(t)
	--if self:argumentCheck(t,"HaveAchievement",1,1) == false then return false end
	local n = strtrim(strlower(t[1]));

	local tbl = self:findStatisticByName(n, true);
	if (tbl == nil) then return false; end --no achievement by that name
	local _id, _name, _points, completed = GetAchievementInfo(tbl["Id"]);
	if (completed == true) then return true; end

	return false;
end


--Returns True/False whether the player's item got the proper durability
function Methods:HaveDurability(t)
	--if self:argumentCheck(t,"HaveDurability",0,1) == false then return false end
	local n = "working"; --repaired,working,low,broken
	if (t ~= nil and #t>0) then n = strtrim(strlower(t[1])) end

	local booRepaired		= true;
	local intHighestStatus	= -1;	--status is between 0 and 2, higher value means its more broken.

	local GetInventoryAlertStatus		= GetInventoryAlertStatus; --local fpointer
	local GetInventoryItemDurability	= GetInventoryItemDurability;

	local slots = self:getInventoryIDList(); --A list of slot id numbers
	for i=1, #slots do
		local slotID			= slots[i];								--fill up with the slotid we need
		local intStatus			= GetInventoryAlertStatus(slotID);		--0=normal, 1=low, 2=broken  (0 if no item in slot)
		local currDur, maxDur	= GetInventoryItemDurability(slotID);	--current and max durability of an item. (nil if no item in slot or item has no durabiliy like trinkets)
		if (intHighestStatus < intStatus)	then intHighestStatus = intStatus; end
		if (currDur ~= maxDur)				then booRepaired = false; end
	end--for i

	--Compare what the user is asking for with the equipped item(s) durability status
	if		n == "repaired" and booRepaired	== true		then return true;
	elseif	n == "working"	and intHighestStatus == 0	then return true;
	elseif	n == "low"		and intHighestStatus == 1	then return true;
	elseif	n == "broken"	and intHighestStatus == 2	then return true;
	end
	return false;
end


--Returns True/False whether the player has a named item equipped.
function Methods:HaveEquipped(t)
	--if self:argumentCheck(t,"HaveEquipped",1,1) == false then return false end
	return IsEquippedItem(t[1]); --true or false
end


--Returns True/False whether the player has a named item in inventory or equipped. Note this will check using the local cache, and it will sometimes return false positives.
function Methods:HaveItem(t)
	--if self:argumentCheck(t,"HaveItem",1,3) == false then return false end
	local itemName = t[1];
	local stackCount = 1;
	local op = "eq";
	if (#t >= 2) then stackCount = StringParsing:tonumber(t[2]); end
	if (#t >= 3) then op = strtrim(strlower(t[3])); end

	if (op == "") then
		IfThen:msg_error("OP argument for HaveItem() can not be an empty string.)");
		return false;
	end --must be a string

	if (stackCount == nil) then
		IfThen:msg_error("Count argument for HaveItem() must be a number.)");
		return false;
	end --must be a number

	if (stackCount < 1) then
		IfThen:msg_error("Count argument for HaveItem() must be a number above 1.)");
		return false;
	end

	local includeBank = false;
	local includeCharges = true;
	local cc = GetItemCount(itemName, includeBank, includeCharges);
	if (cc == nil or cc == 0) then return false end

	local cmp = self:doOP(cc, stackCount, op, nil, true); --does a numerical compare based on the values
	return cmp;
end


--Returns True/False if you are in a party. Argument is not used.
function Methods:InBattleGround(t)
	--if self:argumentCheck(t,"InBattleGround",0,0) == false then return false end
	local raidNum = UnitInBattleground("player");
	if (raidNum ~= nil) then return true end

	return false;
end


--Returns True/False if you are in a wargame. Argument is not used.
function Methods:InWargame(t)
	--if self:argumentCheck(t,"InWargame",0,0) == false then return false end
	return IsWargame() or false; --boolean
end


--Returns True/False whether the player is in combat. Argument is not used.
function Methods:InCombat(t)
	--if self:argumentCheck(t,"InCombat",0,0) == false then return false end
	return InCombatLockdown();--true or false
end


--Returns True/False if you are in a instancegroup, battleground, party or raid. Argument is not used.
function Methods:InGroup(t)
	--if self:argumentCheck(t,"InGroup",0,0) == false then return false end
	local i = self:InInstanceGroup(t);
	local b = self:InBattleGround(t);
	local p = self:InParty(t);
	local r = self:InRaid(t);

	if (i or b or p or r) then return true end
	return false;
end


--Returns True/False whether the unit in the same guild.
function Methods:InGuild(t)
	--if self:argumentCheck(t,"InGuild",0,1) == false then return false end
	local strUnit = "player";
	if (t ~= nil and #t >= 1) then strUnit = strtrim(strlower(t[1])); end

	if (strUnit == "player" and IsInGuild() == false) then return false end

	local guildName, guildRankName, guildRankIndex, realm = GetGuildInfo(strUnit);
	if (guildName == nil or guildName == "") then return false end

	return true;
end


--Returns True/False if you are in a guild group (party or raid). Argument is not used.
function Methods:InGuildGroup(t)
	--if self:argumentCheck(t,"InGuildGroup",0,0) == false then return false end
	local b = self:InBattleGround(t);
	local p = self:InParty(t);
	local r = self:InRaid(t);

	if (b or p or r) then  --is the player in a battleground, party or raid?
		if (IsInGuild() == false) then return false end--Is the player in a guild?
		local bool, numGuildMembers, numRequired, unknown = InGuildParty(); --Is the player in a guildparty/raid/battleground
		if (bool == true) then return true end
	end--if b,p,r

	return false;
end


--Returns True/False whether the player is in an instance. Argument can be: ARENA, PARTY, PVP, RAID.
function Methods:InInstance(t)
	--if self:argumentCheck(t,"InInstance",0,1) == false then return false end
	local n = "";
	if (t ~= nil and #t>0) then	n = strtrim(strlower(t[1])); end
	local isInstance, instanceType = IsInInstance();

	if (n == "scenario") then
		if (C_Scenario.IsInScenario() == true)		then return true; end --Scenarios dont appear to return a instanceType
	else
		if (n=="" and isInstance==true)				then return true; end --return true whether we are in an instance or not
		if (n~="" and n==strlower(instanceType))	then return true; end --match with argument if provided
	end

	return false;
end


--CHECK: Cant seem to test on Beta server
function Methods:InBGQueue(t)
	--if self:argumentCheck(t,"InBGQueue",0,0) == false then return false end

	--Determine the max number of BG's in the list
	local intMax = 1;
	local GetBattlegroundInfo = GetBattlegroundInfo;
	while (true) do --We need to do this each time since it might change due to Wintergrasp and Tol Barad that pops in and out of the queueable state
		--local localizedName, canEnter, isHoliday, isRandom, BattleGroundID, mapDescription = GetBattlegroundInfo(intMax);
		local localizedName = GetBattlegroundInfo(intMax);
		if (localizedName == nil) then
			intMax = intMax -1;
			break; --This breaks out of the While-Do instead of using a boolean exit condition
		end
		intMax = intMax +1; --Go for another round
	end --while
	if (intMax == 0) then return false; end

	--Check each for the queue or waittime
	local waitTime, timeInQueue = nil,nil;
	local GetBattlefieldEstimatedWaitTime	= GetBattlefieldEstimatedWaitTime; --local fpointer
	local GetBattlefieldTimeWaited			= GetBattlefieldTimeWaited;
	for i=1, intMax do
		waitTime	= GetBattlefieldEstimatedWaitTime(i);
		timeInQueue	= GetBattlefieldTimeWaited(i);
		if (waitTime > 0 or timeInQueue > 0) then return true; end --We are in queue for something
	end --for i
	return false; --Nothing found
end


--Returns True/False whether the player is in the LFG queue
function Methods:InLFGQueue(t)
	--if self:argumentCheck(t,"InLFGQueue",0,1) == false then return false end
	--in MOP we support an optional 'Type' argument: All,DF,RF,SC,Pet
	local n = "all";
	if (t ~= nil and #t>0) then	n = strtrim(strlower(t[1])); end

	local _lfg		= -1; --All
	local strMode	= "queued"; --The return value is 'queued' for most scenarios except old school raid finder.
	if		n == "df"	then _lfg = _G["LE_LFG_CATEGORY_LFD"]; --Global constants defined by Blizzard
	elseif	n == "rf"	then _lfg = _G["LE_LFG_CATEGORY_RF"];
	elseif	n == "sc"	then _lfg = _G["LE_LFG_CATEGORY_SCENARIO"];
	elseif	n == "pet"	then _lfg = "pet";
	--elseif	n == "flex"	then _lfg = _G["LE_LFG_CATEGORY_FLEXRAID"];
	--elseif	n == "lfr"	then _lfg = _G["LE_LFG_CATEGORY_LFR"]; strMode = "listed"; --For old school raid finder we accept 'listed' as the proper response.
	end

	local mode, submode = nil, nil;
	if (_lfg ~= -1) then
		if (_lfg == "pet") then
			mode = C_PetBattles.GetPVPMatchmakingInfo(); --returns empty string or 'queued'
		else
			mode, submode = GetLFGMode(_lfg); --just 1 check against a single queue
		end--if pet
		if (mode ~= nil and mode == strMode) then return true end
	else
		--check all modes
		mode, submode = GetLFGMode(_G["LE_LFG_CATEGORY_LFD"]);
		if (mode ~= nil and mode == "queued") then return true end
		mode, submode = GetLFGMode(_G["LE_LFG_CATEGORY_RF"]);
		if (mode ~= nil and mode == "queued") then return true end
		mode, submode = GetLFGMode(_G["LE_LFG_CATEGORY_SCENARIO"]);
		if (mode ~= nil and mode == "queued") then return true end
		mode = C_PetBattles.GetPVPMatchmakingInfo();
		if (mode ~= nil and mode == "queued") then return true end
		--mode, submode = GetLFGMode(_G["LE_LFG_CATEGORY_FLEXRAID"]);
		--if (mode ~= nil and mode == "queued") then return true end
		--mode, submode = GetLFGMode(_G["LE_LFG_CATEGORY_LFR"]);
		--if (mode ~= nil and mode == "listed") then return true end
	end--if _lfg
	return false;
end


--Returns True/False whether the unit is in the same battleground as the player. Argument is either 'target' or 'focus'.
function Methods:InMyBattleground(t)
	--if self:argumentCheck(t,"InMyBattleground",1,1) == false then return false end
	local strUnit = "target";
	if (#t >= 1) then strUnit = strtrim(strlower(t[1])); end
	if (self:InBattleGround(t) == false) then return false end --if the player is not grouped then return false

	local b = UnitInBattleground(strUnit); --number pos of unit in raid
	if (b ~= nil) then return true end
	return false;
end


--Returns True/False whether the unit is in the same group as the player. Argument is either 'target' or 'focus'.
function Methods:InMyGroup(t)
	--if self:argumentCheck(t,"InMyGuild",1,1) == false then return false end
	local b = self:InMyBattleground(t);
	local p = self:InMyParty(t);
	local r = self:InMyRaid(t);

	if (b or p or r) then return true end
	return false;
end


--Returns True/False whether the unit is in the same guild as the player. Argument is either 'target' or 'focus'.
function Methods:InMyGuild(t)
	--if self:argumentCheck(t,"InMyGuild",1,1) == false then return false end
	local strUnit = "target";
	if (#t >= 1) then strUnit = strtrim(strlower(t[1])); end
	if (IsInGuild() == false) then return false end --if the player is not guilded then return false

	local my_guildName, my_guildRankName, my_guildRankIndex, my_realm = GetGuildInfo("player");
	local guildName, guildRankName, guildRankIndex, realm = GetGuildInfo(strUnit);

	if (guildName == nil or guildName == "") then return false end --unit is not in guild, but the player is
	if (strlower(guildName) == strlower(my_guildName)) then return true end --match on guildname
	return false;
end


--Returns True/False whether the unit is in the same party as the player. Argument is either 'target' or 'focus'.
function Methods:InMyParty(t)
	--if self:argumentCheck(t,"InMyParty",1,1) == false then return false end
	local strUnit = "target";
	if (#t >= 1) then strUnit = strtrim(strlower(t[1])); end
	if (self:InParty(t) == false) then return false end --if the player is not grouped then return false

	local p = UnitInParty(strUnit); --nil or 1
	if (p ~= nil) then return true end
	return false;
end


--Returns True/False whether the unit is in the same raid as the player. Argument is either 'target' or 'focus'.
function Methods:InMyRaid(t)
	--if self:argumentCheck(t,"InMyRaid",1,1) == false then return false end
	local strUnit = "target";
	if (#t >= 1) then strUnit = strtrim(strlower(t[1])); end
	if (IsInRaid() == false) then return false end --if the player is not grouped then return false

	local r = UnitInRaid(strUnit); --number pos of unit in raid
	if (r ~= nil) then return true end
	return false;
end


--Returns True/False if you are in a /instance group. Argument is not used.
function Methods:InInstanceGroup(t)
	--if self:argumentCheck(t,"InInstanceGroup",0,0) == false then return false end
	--local r = IsInRaid();	--true or false
	local g = IsInGroup(LE_PARTY_CATEGORY_INSTANCE); --true or false (will be true when you are in a raid as well)
	--					LE_PARTY_CATEGORY_HOME=1		when in a normal party/raid
	--					LE_PARTY_CATEGORY_INSTANCE=2	when you are in an instance group
	if (g == true) then return true end
	return false;
end


--Returns True/False if you are in a party. Argument is not used.
function Methods:InParty(t)
	--if self:argumentCheck(t,"InParty",0,0) == false then return false end
	local r = IsInRaid();	--true or false
	local g = IsInGroup(LE_PARTY_CATEGORY_HOME); --true or false (will be true when you are in a raid as well)
	--					LE_PARTY_CATEGORY_HOME=1		when in a normal party/raid
	--					LE_PARTY_CATEGORY_INSTANCE=2	when you are in an instance group
	if (r == false) and (g == true) then return true end

	return false;
end


--Returns True/False whether the player is in a pet battle. Argument is not used.
function Methods:InPetBattle(t)
	--if self:argumentCheck(t,"InPetBattle",0,0) == false then return false end
	return C_PetBattles.IsInBattle(); --true or false;
end


--Returns True/False if you are in a raid. Argument is not used.
function Methods:InRaid(t)
	--if self:argumentCheck(t,"InRaid",0,0) == false then return false end
	return IsInRaid(); --true or false;
end


--Returns True/False whether the player is in range of the unit with the given spell/item.
function Methods:InRange(t)
	--if self:argumentCheck(t,"InRange",2,1) == false then return false end
	local n	   = t[1];
	local unit = "target";	--can either be 'player', 'focus', 'target' or 'pet'
	if (#t >= 2) then unit = strtrim(strlower(t[2])); end

	--Updated 2014-08-17: WOD 6.0.1 Beta. Some spells return nil instead of 0 or 1

	local booItem,  booItemRange  = ItemHasRange(n),  IsItemInRange(n, unit);
	local booSpell, booSpellRange = SpellHasRange(n), IsSpellInRange(n, unit);

	if (booItem  ~= nil and booItemRange  == 1) then return true end
	if (booSpell ~= nil and booSpellRange == 1) then return true end
	return false;
end

--Returns True/False whether the player is inside a digsite area where he can cast Survey.
function Methods:InDigsite(t)
	--if self:argumentCheck(t,"InDigsite",0,0) == false then return false end
	return CanScanResearchSite() or false; --Returns false if you don't have the profession
end


--Returns True/False whether the player is in range of using the questitem.
function Methods:QuestItemInRange(t)
	local strlower = strlower; --local fpointer
	--if self:argumentCheck(t,"QuestItemInRange",1,0) == false then return false end
	local strTitle  = "";
	if (#t >= 1) then strTitle = t[1]; end
	local n			= strtrim(strlower(strTitle));
	local qIndex	= nil;
	local qLink		= nil;
	local tmp		= nil;
	local GetQuestLogSpecialItemInfo = GetQuestLogSpecialItemInfo; --local fpointer

	if (n == "") then
		--no name specified, look for the first one in the tracked list that has a questitem
		local GetQuestIndexForWatch	= GetQuestIndexForWatch; --local fpointer
		local wMax					= GetNumQuestWatches();
		for i=1, wMax do
			tmp		= GetQuestIndexForWatch(i);
			qLink	= GetQuestLogSpecialItemInfo(tmp);
			if (qLink ~= nil) then
				qIndex = tmp;
				break;
			end
		end--for i
	else
		--iterate though quests and find a matcing title
		local GetQuestLogTitle	= GetQuestLogTitle; --local fpointer
		local qMax				= GetNumQuestLogEntries();
		for i=1, qMax do
			tmp = strlower(GetQuestLogTitle(i));
			if (n == tmp) then
				qIndex = i;
				break;
			end
		end--for i
	end

	if (qIndex == nil) then return false; end	--quest not found
	qLink = GetQuestLogSpecialItemInfo(qIndex);
	if (qLink == nil) then return false; end	--quest dont have questitem
	local b = IsQuestLogSpecialItemInRange(qIndex);
	if (b == 1) then return true; end			--questitem is in range
	return false;
end


--Returns True/False whether the player is in the specified stance. If the class dont have stances then it will always return false
function Methods:InStance(t)
	--if self:argumentCheck(t,"InStance",1,1) == false then return false end
	local strForm = strtrim(strlower(t[1]));

	local i = GetShapeshiftForm(); --Get the character's current stance/form. It can be 0 or higher
	if (i == 0 and strForm == "none") then return true;  end --not in any form
	if (i == 0 and strForm ~= "none") then return false; end --not in any form or might be a class that dont have any forms or a low level character

	--This is the only real way to ask wow for what stance you are in.
	--The GetShapeshiftFormID() function returns a global ID for most stances, but not all of them. Also there is no way to lookup these ID's without a hardcoded list.
	local texture, name, isActive, isCastable = GetShapeshiftFormInfo(i);
	name = strtrim(strlower(name)); --name is localized and is for example 'Bear Form' (english), 'Bärengestalt' (german), "Stance of the Wise Serpent" etc.

	--if (StringParsing:indexOf(name, strForm, 1)) then return true end --to simplify the arguments we just use indexof
	if (name == strForm) then return true end --exact match
	return false;
end


--Returns True/False whether the unit is a worgen (race) and currently in worgen-form.
function Methods:InWorgenForm(t)
	--if self:argumentCheck(t,"InWorgenForm",0,1) == false then return false end
	local strUnit = "player";
	if (t ~= nil and #t >= 1) then strUnit = strtrim(strlower(t[1])); end

	--local strLocalized, strENG = UnitRace(strUnit); --Is this character a worgen? (localized name, english name) --UnitRace() Returns nil when targeting NPC's.
	--if (strENG == nil)					then return false; end --not a unit that has race (critters)
	--if (strupper(strENG) ~= "WORGEN")	then return false; end --returns false for all other races than worgen

	if (cache_PlayerModel == nil) then cache_PlayerModel = CreateFrame('PlayerModel'); end --Save for faster lookup later.
	cache_PlayerModel:SetUnit(strUnit);
	--local strModel = strupper(cache_PlayerModel:GetModel()); --GetModel() Removed with Legion patch. Must now use GetModelFileID() that returns a hardcoded value for each playermodel-type (male, female, human, orc, etc)
	--if (strmatch(strModel,'WORGEN')) then return true; end

	local strModelID = cache_PlayerModel:GetModelFileID();
	if (strModelID == 307453 or strModelID == 307454) then return true; end --307453=female worgen, 307454=male worgen
	return false;
end


--Returns True/False whether the player is in the given zone/subzone.
function Methods:InZone(t)
	--if self:argumentCheck(t,"InZone",1,1) == false then return false end
	local n	= strtrim(strlower(t[1]));
	local currSub	= GetMinimapZoneText()	or "";	--Minimap title
	local currZone	= GetRealZoneText() 	or "";	--Real zone title

	if (n == strlower(currSub) or n == strlower(currZone)) then return true end
	return false;
end


--Returns True/False whether the player is AFK, will check player if no argument is supplied.
function Methods:IsAFK(t)
	--if self:argumentCheck(t,"IsAFK",0,1) == false then return false end
	local n = "player";
	if (t ~= nil and #t>0) then n = t[1] end
	return UnitIsAFK(n);--true or false
end


--Returns True/False whether the unit is an assistant in the players raid.
function Methods:IsAssistant(t)
	--if self:argumentCheck(t,"IsAssistant",0,0) == false then return false end
	local n = "player";
	if (t ~= nil and #t>0) then n = t[1] end

	local r  = self:InRaid(t);			--true or false
	local rO = UnitIsGroupAssistant(n); --true, false or inputted name
	if (r and rO==true) then return true end

	return false;
end


--Returns True/False whether a addon is loaded.
function Methods:IsAddOnLoaded(t)
	--if self:argumentCheck(t,"IsAddOnLoaded",1,1) == false then return false end
	local n = strtrim(strlower(t[1]));

	--First, compare with the addon's folder name or filename of it's .TOC file
	if (IsAddOnLoaded(n) == true) then return true; end --true or false

	--Secondly, compare against TITLE property in the .TOC files
	local IsAddOnLoaded		= IsAddOnLoaded; --local fpointer
	local GetAddOnMetadata	= GetAddOnMetadata;
	local gsub				= gsub;
	local strtrim			= strtrim;
	local strlower			= strlower;
	local intMax = GetNumAddOns();
	for i=1, intMax do
		if (IsAddOnLoaded(i) == true) then --true or false
			local curTitle = GetAddOnMetadata(i, "Title");
			if (curTitle ~= nil) then
				curTitle = gsub(curTitle, "(|c)(........)", "");	--Clear any color strings from inside the string (SyntaxColor:ClearColor() function)
				curTitle = gsub(curTitle, "|r", "");				--Remove any color reset's
				curTitle = strtrim(strlower(curTitle));
				if (n == curTitle) then return true; end
			end--if curTitle
		end--if IsAddOnLoaded
	end--for i

	return false;
end


--Returns True/False whether the player has a boss targeted. Argument is either 'target' or 'focus'.
function Methods:IsBoss(t)
	--if self:argumentCheck(t,"IsBoss",0,1) == false then return false end
	local strUnit = "target"; --target or focus
	if (t ~= nil and #t>0) then strUnit = strtrim(strlower(t[1])) end
	--Is anything actually targeted
	local strName = self:getNPCNameFromGUID(strUnit) or GetUnitName(strUnit);
	if (strName == nil) then return false; end --Nothing is targeted/focused

	--Is this a player or NPC?
	if (UnitIsPlayer(strUnit) == true) then return false; end --true or false

	--Is the NPC classified as a world boss or something other than an elite/rarelite?
	local classification = UnitClassification(strUnit); --elite, normal, rare, rareelite, worldboss
	if (classification == "worldboss") then return true; end
	if not (classification == "elite" or classification == "rareelite" or classification == "worldboss") then return false; end

	--Is the NPC name matched against something in the Encounter Journal?
	local strBoss = self:getEncounterNameFromBossName(strName); --Will return nil if youre not in an instance and the bossname isnt found in the encounter journal.
	if (strBoss ~= nil) then return true; end

	--Is the NPC level -1?
	local level = UnitLevel(strUnit);
	if (level == -1) then return true; end --many bosses are -1 in level

	--Check bossN against our target/focus (if we are in combat)
	if (InCombatLockdown() == true and IsInInstance() == true) then --bossN are only populated when in combat and inside instances
		local tostring		= tostring; --local fpointer
		local UnitIsUnit	= UnitIsUnit;
		local GetUnitName	= GetUnitName;
		local maxBosses = 15;
		for i=1, maxBosses do --Do a loop from 1 to 15 and compare bossN to our target/focus
			local bossN = "boss"..tostring(i);
			local strBoss = self:getNPCNameFromGUID(bossN) or GetUnitName(bossN);
			if (strBoss == nil) then break; end
			if (UnitIsUnit(bossN, strUnit) == true)	then return true; end --compare if the unit we are targeting/focus is the same as bossN
			if (strBoss == strName)					then return true; end --compare on names if target/focus matches bossN
		end--for i
	end--if InCombatLockdown
	return false;
end


--Returns True/False whether the player is channeling or casting a spell. If no argument is provided then it will return True no matter what spell is being cast.
function Methods:IsChanneling(t)
	--if self:argumentCheck(t,"IsChanneling",0,2) == false then return false end
	local n			= "";		--spellname
	local strUnit	= "player";	--player, target, focus
	if (#t >= 1) then n			= strtrim(strlower(t[1])); end
	if (#t >= 2) then strUnit	= strtrim(strlower(t[2])); end
	local ch = UnitChannelInfo(strUnit);
	local ca = UnitCastingInfo(strUnit);

	if (ch==nil and ca==nil) then return false end --nothing is being channeled or casted
	if (n == "") then
		if (ch~=nil or ca~=nil) then return true end --something is being channeled or casted
	else
		--Check for a specific spellname
		if (ch~= nil and n == strtrim(strlower(ch))) then return true end --is channeling spell n
		if (ca~= nil and n == strtrim(strlower(ca))) then return true end --is casting spell n
	end

	return false;
end


--Return True/False whether the input class matches that of the player
function Methods:IsClass(t)
	--if self:argumentCheck(t,"IsClass",1,1) == false then return false end
	local strClass	= strtrim(strupper(t[1])); --uppercase compare
	local strUnit	= "player";
	if (#t >= 2) then strUnit = strtrim(strlower(t[2])); end

	local class, classFileName = UnitClass(strUnit); --class is localized, classFileName is not localized
	if (classFileName == nil) then return false end --nothing targeted
	if (strClass == classFileName) then return true end
	return false;
end


--Returns True/False whether the NPC targeted is rare/elite/worldboss etc. Default arguments are "elite" and "target".
function Methods:IsClassified(t)
	--if self:argumentCheck(t,"IsClassified",1,2) == false then return false end
	local strClassification		= "elite"; --worldboss, rareelite, elite, rare, normal, trivial or minus
	local strUnit				= "target"; --target or focus
	if (#t >= 1) then strClassification	= strtrim(strlower(t[1])); end
	if (#t >= 2) then strUnit			= strtrim(strlower(t[2])); end

	--Source: http://www.wowwiki.com/API_UnitClassification
	local classification = UnitClassification(strUnit); --worldboss, rareelite, elite, rare, normal, trivial, minus
	if (classification == strClassification) then return true; end
	return false;
end


--Returns True/False whether the players currently enabled specialization is the same as the argument.
function Methods:IsCurrentSpec(t)
	--if self:argumentCheck(t,"IsCurrentSpec",1,1) == false then return false end
	local strSpec = strtrim(strlower(t[1])); --Localized name of the spec.

	local i = GetSpecialization(); --Returns the index for the currently used spec (1,2,3,4).
	local id, name, description, icon, background, _, primaryStat = GetSpecializationInfo(i, false); --GetSpecializationInfo(specIndex, isInspect, isPet, instpecTarget, sex);

	if (name ~=nil and strlower(name) == strSpec) then return true end --Localized name comparison.
	return false;
end


--Returns True/False whether the player is DND, will check player if no argument is supplied.
function Methods:IsDND(t)
	--if self:argumentCheck(t,"IsDND",0,1) == false then return false end
	local n = "player";
	if (t ~= nil and #t>0) then n = t[1] end
	return UnitIsDND(n);--true or false
end


--Returns True/False whether the player is dead or a ghost, will check player if no argument is supplied.
function Methods:IsDead(t)
	--if self:argumentCheck(t,"IsDead",0,1) == false then return false end
	local n = "player";
	if (t ~= nil and #t>0) then n = t[1] end
	return UnitIsDeadOrGhost(n);--true or false
end


--Returns True/False whether the players is falling.
function Methods:IsFalling(t)
	--if self:argumentCheck(t,"IsFalling",0,0) == false then return false end
	return IsFalling();--true or false
end


--Returns True/False whether the player is in a flyable area. Argument is not used. Notes: will still return true in Dalaran.
function Methods:IsFlyableArea(t)
	--if self:argumentCheck(t,"IsFlyableArea",0,0) == false then return false end
	--Even though the function can return true. You as a player might not be able to fly in the area. That is dependent on your flying skill ability.
	return IsFlyableArea();--true or false
end


--Returns True/False whether the player is flying. Argument is not used.
function Methods:IsFlying(t)
	--if self:argumentCheck(t,"IsFlying",0,0) == false then return false end
	return IsFlying();--true or false
end


--Returns True/False whether the player has a npc/player with the given name focused.
function Methods:IsFocused(t)
	--if self:argumentCheck(t,"IsFocused",0,1) == false then return false end
	local n = "";
	if (t ~= nil and #t>0) then n = strtrim(strlower(t[1])) end
	local res = GetUnitName("focus",true);

	if (n=="" and res ~=nil)	then return true	end	--if no argument and the player has 'something' focused then return true
	if (res == nil)				then return false	end	--nothing focused, return false
	if (n == strlower(res))		then return true	end	--name matches, return true
	return false;	--name does not match, return false
end


--Returns True/False whether the target is hostile
function Methods:IsHostile(t)
	--if self:argumentCheck(t,"IsHostile",0,1) == false then return false end
	local n = "target";
	if (#t >=1) then n = t[1] end --'target' or 'focus'
	return UnitIsEnemy("player", n); --returns true or false (if nothing is targeted then it will return false)
end


--Returns True/False whether the players is in doors.
function Methods:IsIndoors(t)
	--if self:argumentCheck(t,"IsIndoors",0,0) == false then return false end
	return IsIndoors();--true or false
end


--Returns True/False whether the player is leader of the instancegroup/party/raid. Argument is not used.
function Methods:IsLeader(t)
	--if self:argumentCheck(t,"IsLeader",0,1) == false then return false end
	local n = "player";
	if (t ~=nil and #t >= 1) then n = t[1] end --player, target, focus

	local i = self:InInstanceGroup(t); --true or false
	local p = self:InParty(t);
	local r = self:InRaid(t);
	local l = UnitIsGroupLeader(n); --works with player,target,focus
	if ((i or p or r) and l == true) then return true end

	return false;
end


--Return True/False whether the input mark matches that the player has
function Methods:IsMarked(t)
	--if self:argumentCheck(t,"IsMarked",1,2) == false then return false end
	local strUnit = "player";
	local strMark = "";
	if (#t >= 1) then strUnit  = strtrim(strlower(t[1])); end
	if (#t >= 2) then strMark  = strtrim(strlower(t[2])); end

	local i = GetRaidTargetIndex(strUnit);
	if (i == nil and strMark=="")		then return false end	--any mark goes and the unit has no mark
	if (i ~= nil and strMark=="")		then return true end	--any mark goes and the unit has a mark on it
	if (i == nil and strMark=="none")	then return true end
	if (i == 1 and strMark=="star")		then return true end
	if (i == 2 and strMark=="circle")	then return true end
	if (i == 3 and strMark=="diamond")	then return true end
	if (i == 4 and strMark=="triangle")	then return true end
	if (i == 5 and strMark=="moon")		then return true end
	if (i == 6 and strMark=="square")	then return true end
	if (i == 7 and strMark=="cross")	then return true end
	if (i == 8 and strMark=="skull")	then return true end
	return false;
end


--Returns True/False whether a modifer key is currently pressed down on the keyboard.
function Methods:IsModifierKeyDown(t)
	--if self:argumentCheck(t,"IsModifierKeyDown",0,1) == false then return false end
	local n = ""; --Optional, can be 'Alt', 'Control', 'Shift'
	if (t ~=nil and #t >= 1) then n = strtrim(strlower(t[1])); end

	local func = IsModifierKeyDown; --default (any modifier key is pressed)
	if		(n == "alt")	then func = IsAltKeyDown;
	elseif	(n == "control")then func = IsControlKeyDown; --Should also work with Mac clients
	elseif	(n == "shift")	then func = IsShiftKeyDown;
	end

	return func(); --true or false
end


--Returns True/False whether the player is riding a summoned mount. Argument is not used.
function Methods:IsMounted(t)
	--if self:argumentCheck(t,"IsMounted",0,0) == false then return false end
	return IsMounted(); --true or false
end


--Return True/False whether the sound is currently muted. Argument can be ALL (default), EFFECTS or MUSIC
function Methods:IsMuted(t)
	--if self:argumentCheck(t,"IsMuted",0,1) == false then return false end
	local n			= "all";
	if (#t > 0) then n = strtrim(strlower(t[1])) end
	local s_all		= tonumber(GetCVar("Sound_EnableAllSound"));--all sound is enabled/disabled
	local s_effects = tonumber(GetCVar("Sound_EnableSFX"));		--sound effects are enabled/disabled
	local s_music	= tonumber(GetCVar("Sound_EnableMusic"));	--music is enabled/disabled

	if		(s_all == 0)						then return true; --if the whole soundsystem is disabled then we return true of corse
	elseif	(n=="all"	  and s_all == 0)		then return true; --all
	elseif	(n=="effects" and s_effects == 0)	then return true; --effects
	elseif	(n=="music"   and s_music   == 0)	then return true; --music
	end
	return false;
end


--Returns True/False whether the player is PVP flagged, will check player if no argument is supplied.
function Methods:IsPVP(t)
	--if self:argumentCheck(t,"IsPVP",1,1) == false then return false end
	local n = "player";
	if (#t >=1) then n = t[1] end
	return UnitIsPVP(n); --true or false
end


--Returns True/False whether the player is Saved for a particular instance.
function Methods:IsSaved(t)
	--if self:argumentCheck(t,"IsSaved",1,1) == false then return false end
	local lowTitle = strtrim(strlower(t[1]));
	if (lowTitle == nil or lowTitle == "") then
		IfThen:msg_error("You must provide a instance name argument for IsSaved().)");
		return false;
	end--if

	local numInstances = GetNumSavedInstances();
	local strlower				= strlower; --local fpointer
	local GetSavedInstanceInfo	= GetSavedInstanceInfo;
	for i=1, numInstances do
		local instanceName, instanceID, instanceReset = GetSavedInstanceInfo(i); --instanceName, instanceID, instanceReset, instanceDifficulty, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, maxBosses, defeatedBosses = GetSavedInstanceInfo(index);
		if (strlower(instanceName) == lowTitle) then
			if (instanceReset > 0) then return true end --we are still saved to the instance
			return false; --the instance is in the list but it's expired
		end--if
	end--for i

	return false;--didn't find the instance in the list
end


--Returns True/False whether the player is stealthed.
function Methods:IsStealthed(t)
	--if self:argumentCheck(t,"IsStealthed",0,0) == false then return false end
	--This does returns false if a mage uses invisibility so it does not cover 'Invisibility' only 'Stealth'
	return IsStealthed(); --true if rogue Stealth, druid cat form Prowl or a similar ability is active on the player; otherwise false;
end


--Returns True/False whether the players is swimming.
function Methods:IsSwimming(t)
	--if self:argumentCheck(t,"IsSwimming",0,0) == false then return false end

	--Returns whether the player is currently swimming. 'Swimming' as defined by this function corresponds to the ability to use swimming abilities (such as druid Aquatic Form) or inability to use land-restricted abilities (such as eating or summoning a flying mount), not necessarily to whether the player is in water.
	return IsSwimming(); --true or false
end


--Return True/False whether the target is tapped by the player og his group
function Methods:IsTapped(t)
	--if self:argumentCheck(t,"IsTapped",0,1) == false then return false end
	local strUnit = "target"; --'target' (default) or 'focus'
	if (#t >= 1) then strUnit  = strtrim(strlower(t[1])); end

	--return UnitIsTappedByPlayer(strUnit); UnitIsTapped(strUnit) --true or false
	return (not UnitIsTapDenied(strUnit)); --true or false
end


--Returns True/False whether the player has a npc/player with the given name targeted.
function Methods:IsTargeted(t)
	--if self:argumentCheck(t,"IsTargeted",0,2) == false then return false end
	local n			= "";
	local filter	= ""; --can be 'exact', 'startswith' or 'indexof'. Defaults to 'exact'.
	if (t ~= nil and #t>0) then n		= strtrim(strlower(t[1])) end
	if (t ~= nil and #t>1) then filter	= strtrim(strlower(t[2])) end

	local res = GetUnitName("target",true);

	if (n=="" and res ~=nil)	then return true	end	--if no argument and the player has 'something' targeted then return true
	if (res == nil)				then return false	end	--nothing targeted, return false
	return self:doCompare(res, n, filter, true);
end


--Returns True/False whether the player has a item/npc/player with the given name under his mouse cursor.
function Methods:MouseOver(t)
	--if self:argumentCheck(t,"MouseOver",0,1) == false then return false end
	local n			= "";
	local filter	= ""; --can be 'exact', 'startswith' or 'indexof'. Defaults to 'exact'.
	if (t ~= nil and #t>0) then n		= strtrim(strlower(t[1])) end
	if (t ~= nil and #t>1) then filter	= strtrim(strlower(t[2])) end

	--1 Try getting the name of a player/npc (note does not return player titles, something that GameTooltip will)
	local res = GetUnitName("mouseover",true);

	--Source: http://www.wowwiki.com/UIOBJECT_GameTooltip | http://wowprogramming.com/docs/widgets/GameTooltip
	--Note: if any other addons are messing with the first line in the tooltips then this can fail

	--2 Use the GameTooltip to get a match. For items like 'Forge', 'Mailbox' etc then this is the only way
	if (res == nil) then
		local i = GameTooltip:NumLines(); --nil or a number
		if (i ~=nil and i > 0) then res = GameTooltipTextLeft1:GetText(); end --only care about the 1st line
	end--if res

	--3 Try the ItemRefTooltip that is used for links in chat.
	if (res == nil) then
		local i = ItemRefTooltip:NumLines(); --nil or a number
		if (i ~=nil and i > 0) then res = ItemRefTooltipTextLeft1:GetText(); end --only care about the 1st line
	end--if res

	if (n=="" and res ~=nil)	then return true	end	--if no argument and the player has 'something' under the mouse then return true
	if (res == nil)				then return false	end	--nothing under the mouse, return false
	return self:doCompare(res, n, filter, true);
end


--Will return True/False whether the player has moved since last time the function was called
function Methods:PlayerHasMoved(t)
	--if self:argumentCheck(t,"PlayerHasMoved",1,1) == false then return false end
	local strCheck = ""; --both, position, facing
	if (t ~= nil and #t >=1) then strCheck = strtrim(strlower(t[1])) end

	if (cache_PlayerPosition == nil) then cache_PlayerPosition = {} end --dont create empty table until this function is first called

	SetMapToCurrentZone();
	local currX, currY		= GetPlayerMapPosition("player"); --apparently in some instances this function does not work.
	if (currX == nil) then currX = 0 end
	if (currY == nil) then currY = 0 end
	local currZone, currSub	= GetRealZoneText(), GetMinimapZoneText();	--We use Zonename and SubZone as a extra insurance to make sure we are at the correct map.
	local currRad			= GetPlayerFacing();
	local prevX, prevY, prevZone, prevSub, prevRad = cache_PlayerPosition[1], cache_PlayerPosition[2], cache_PlayerPosition[3], cache_PlayerPosition[4], cache_PlayerPosition[5]; --1=X, 2=Y, 3=Zone, 4=SubZone, 5=Rad

	--Store the current position for subsequent calls
	--1=X, 2=Y, 3=Zone, 4=SubZone, 5=Rad
	cache_PlayerPosition[1] = currX;
	cache_PlayerPosition[2] = currY;
	cache_PlayerPosition[3] = currZone;
	cache_PlayerPosition[4] = currSub;
	cache_PlayerPosition[5] = currRad;

	if (strCheck == "position") then
		--Only compare the player coordinates, but not facing
		if (prevX ~= currX or prevY ~= currY or prevZone ~= currZone or prevSub ~= currSub) then return true end
	elseif (strCheck == "facing") then
		--Only compare to the player facing, but not coordinates
		if (prevRad ~= currRad) then return true end
	else
		--Compare to all the values
		if (prevX ~= currX or prevY ~= currY or prevZone ~= currZone or prevSub ~= currSub or prevRad ~= currRad) then return true end
	end

	return false;
end



--####################################################################################
--####################################################################################
--Hooks for Deadly Boss Mods
--####################################################################################


--Works as a wrapper for hooks that will call objFunction and if that fails, it will call orgFunction.
function Methods:ProtectedHookCall(objFunction, message, orgFunction, ...)
	--objFunction	:pointer to my own function that i want to wrap in pCall()
	--message		:some string-message that i want to output if objFunction fails. nil if you want to supress the output.
	--orgFunction	:original function that we want to call if objFunction fails
	local booResult, strMessage, a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z = pcall(objFunction, ...);

	if (booResult == false) then
		--Our function failed, print the message but call the original function to keep the chain intact.
		if (message ~= nil) then
			IfThen:msg_error(tostring(message).."\n\n"..tostring(strMessage));
		end
		return orgFunction(...);
	else
		return strMessage, a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z; --Our call suceeded, just return any return values
	end--if booResult
end


--This function specifies the NpcID(s) of the boss.
--	If multiple id's are specified then hook_DBM_NewMod_SetMainBossID() might tell us what NpcID we should return. If not we must take a guess with the Encounter Journal.
function Methods:hook_DBM_NewMod_SetCreatureID(intRandom, orgMod, orgFunction, ...)
	--Skip processing if we have already been called.
	if (cache_DBM_hookCache ~= nil and cache_DBM_hookCache["SetCreatureID_"..tostring(intRandom)] ~= nil) then return orgFunction(...); end

	--HARDCODED: 2014-10-10: Tested with DBM version 6.0.0 alpha r11743
	--Keep the input arguments (1 or several NpcID's)
	if (cache_NPCList == nil) then cache_NPCList = {}; end
	for i=2, select("#", ...) do --Must start at 2 for some reason
		local npcID = select(i, ...);
		cache_NPCList[npcID] = intRandom; --NpcID's and randomvalue. Will lookup name later when needed
	end--for i

	if (cache_DBM_hookCache == nil) then cache_DBM_hookCache = {}; end
	cache_DBM_hookCache["SetCreatureID_"..tostring(intRandom)] = true; --Set flag to never call this function again
	return orgFunction(...); --Invoke the original function
end


--This function specifies the main boss's NpcID if there are several NpcID's specified with SetCreatureID()
--	Example: In the Galakras fight we need to ID the fight from friendly npc's (King Varian Wrynn, Jaina Proudmoore etc) that bossN returns. This function will then specify the main boss.
--	The cache_NPCList table supports overriding a NpcID with another one so we will do that here by using the common intRandom value.
function Methods:hook_DBM_NewMod_SetMainBossID(intRandom, orgMod, orgFunction, ...)
	--Skip processing if we have already been called.
	if (cache_DBM_hookCache ~= nil and cache_DBM_hookCache["SetMainBossID_"..tostring(intRandom)] ~= nil) then return orgFunction(...); end

	--HARDCODED: 2014-10-10: Tested with DBM version 6.0.0 alpha r11743
	--Keep the input argument (One NpcID)
	if (select("#", ...) >= 2) then
		local npcID = select(2, ...); --Should always be just 1 NpcID. We support for now only 1 bossname
		if (cache_NPCList == nil) then cache_NPCList = {}; end
		for key,value in pairs(cache_NPCList) do
			if (value == intRandom) then cache_NPCList[key] = npcID; end --find the intRandom value used with SetCreatureID() and replace that with the NpcID of the main boss.
		end--for
	end--if npcID

	if (cache_DBM_hookCache == nil) then cache_DBM_hookCache = {}; end
	cache_DBM_hookCache["SetMainBossID_"..tostring(intRandom)] = true; --Set flag to never call this function again
	return orgFunction(...); --Invoke the original function
end


--This function is called each time a submodule for a specific bossfight is loaded.
--	Example: 'DBM-SiegeOfOrgrimmar' will trigger this function X number of times (1 time per bossfight in that raid).
function Methods:hook_DBM_NewMod(orgFunction, ...)
	local objMod = orgFunction(...); --Call original function and get the object returned
	if (type(objMod) ~= "table") then IfThen:msg_error("IfThen detects that DBM is loaded but could not access the function NewMod() like expected. Please update both IfThen and 'Deadly Boss Mods' to the latest version."); return objMod; end --Not what we expect; just pass it along and gracefully fail.

	local intRandom = math_random(1, 1000000) * -1; --A negative random number per NewMod()-object created; Used to keep the two sub-hooks associated with each other.

	--This hook into DBM's NewMod() function is permanent and so are the hooks into SetCreatureID() and SetMainBossID()
	--We cant risk unhooking since we might break other addons that have also hooked into these function after us.
	--We wrap our own eventhandlers in a ProtectedHookCall() so that incase this code crashes it will not affect other addons that are hooking into these functions.
	local hook_SetCreatureID = objMod["SetCreatureID"];
	if (type(hook_SetCreatureID) ~= "function") then
		IfThen:msg_error("IfThen could not access DBM's SetCreatureID(). Please update both IfThen and 'Deadly Boss Mods' to the latest version.");
	else
		local over_SetCreatureID	= function(...) return Methods:hook_DBM_NewMod_SetCreatureID(intRandom, objMod, hook_SetCreatureID, ...) end;
		local prot_SetCreatureID	= function(...) return Methods:ProtectedHookCall(over_SetCreatureID, "IfThen failed internally when acessing DBM's SetCreatureID() function. Will call the next function in the chain to prevent cascasing failure for other addons. Please report this error and update your version of IfThen.", hook_SetCreatureID, ...) end;
		objMod["SetCreatureID"]		= prot_SetCreatureID;
	end--if hook_

	local hook_SetMainBossID = objMod["SetMainBossID"];
	if (type(hook_SetMainBossID) ~= "function") then
		IfThen:msg_error("IfThen could not access DBM's SetMainBossID(). Please update both IfThen and 'Deadly Boss Mods' to the latest version.");
	else
		local over_SetMainBossID	= function(...) return Methods:hook_DBM_NewMod_SetMainBossID(intRandom, objMod, hook_SetMainBossID, ...) end;
		local prot_SetMainBossID	= function(...) return Methods:ProtectedHookCall(over_SetMainBossID, "IfThen failed internally when acessing DBM's SetMainBossID() function. Will call the next function in the chain to prevent cascasing failure for other addons. Please report this error and update your version of IfThen.", hook_SetMainBossID, ...) end;
		objMod["SetMainBossID"]		= prot_SetMainBossID;
	end--if hook_

	return objMod;
end


--Creates a permanent hook into DBM-Core's NewMod() function that is loaded each time a submodule of the addon is loaded.
--	What we are really interested is in the mod.SetCreatureID() and mod.SetMainBossID() that will give us the NpcID's of the boss(es). This way we dont need to hardcode these things into our own addon.
--	Later we use getNPCNameFromGUID() with %BossName%'s 'bossN' to improve the bossname lookup.
function Methods:hook_DBM()
	--DBM/VEM must be loaded
	if (self:tryAndLoadAddon("DBM-Core") == false) then return false; end --Not having DBM loaded is not a sin. We simply dont enable hooks then.

	--DBM is loaded. Hook into DBM:NewMod()
	local objDBM = DBM; --Global 'DBM'-object
	if (type(objDBM) ~= "table" or objDBM["NewMod"] == nil) then
		IfThen:msg_error("IfThen detects that DBM is loaded but could not access it like expected. Please update both IfThen and 'Deadly Boss Mods' to the latest version.");
		return false; --Graceful fail
	end--if

	local orgFunction	= objDBM["NewMod"]; --Original pointer
	objDBM["NewMod"]	= function(...) return Methods:hook_DBM_NewMod(orgFunction, ...) end; --Can't wrap this in a ProtectedHookCall() since the first thing the function do is to call the orignal function.
	return true;
end


--####################################################################################
--####################################################################################
