--####################################################################################
--####################################################################################
--Macro methods
--####################################################################################
--Dependencies: StringParsing.lua

local Macro = {};
Macro.__index = Macro;
IfThen_Macro = Macro; --Global declaration

local StringParsing	= IfThen_StringParsing;	--Local pointer
--local IfThen		= IfThen_IfThen;	 	--Local pointer


--Local constants
local CONST_MacroTexture_Blank	= "INV_MISC_QUESTIONMARK";	--134400 --"INV_MISC_QUESTIONMARK"; --Default blank [?] icon used when /use or /cast is in the macro
local CONST_MacroTexture		= "252184";					--"Ability_Vehicle_ShellShieldGenerator" --"Interface\\Icons\\Ability_Vehicle_ShellShieldGenerator";
local CONST_MacroName			= "IfThen_Btn";				--The name for the Default IfThen Macro
local CONST_MacroPrefix			= "IfThen_";				--Prefix that all IfThen Macros uses (case-sensitive)
local CONST_ScriptName			= "IFT()";					--"IfThen:Macro()"; -- Made it shorter for keeping more space in macro
local CONST_MacroNameLength		= 16;						--Macroname can be max 16 characters long
local CONST_MAX_ACCOUNT_MACROS  = _G["MAX_ACCOUNT_MACROS"]   or 120; --120 macros for the account (we use OR since the variables are not loaded until the /macro interface is loaded
local CONST_MAX_CHARACTER_MACROS= _G["MAX_CHARACTER_MACROS"] or 18;  --18 macros per character


--Local pointers to global functions
local strlen	= strlen;
local strfind	= strfind;
local strsub	= strsub;
local strtrim	= strtrim;	--string.trim
local tinsert	= tinsert;	--table.insert
local pairs		= pairs;

local EditMacro			= EditMacro;
local CreateMacro		= CreateMacro;
local GetMacroBody		= GetMacroBody;
local SetMacroSpell		= SetMacroSpell;
local SetMacroItem		= SetMacroItem;
local InCombatLockdown	= InCombatLockdown;
local GetMacroIndexByName=GetMacroIndexByName;
local GetRunningMacro	= GetRunningMacro;
local GetMacroInfo		= GetMacroInfo;
local GetNumMacros		= GetNumMacros;


--####################################################################################
--####################################################################################


--Return the default macro name, prefix and maxlength for a macroblock name
function Macro:getDefaultMacroValues()
	return CONST_MacroName, CONST_MacroPrefix, (CONST_MacroNameLength - strlen(CONST_MacroPrefix)); --Default Macro Name , Prefix for all Ifthen-macros, How long a MacroBlock name can be
end


--Create any missing macros and will delete any macros that start with the prefix but that is not in the MacroList passed in
function Macro:manageMacros(MacroList)
	if (MacroList == nil) then return nil; end

	--Get list of all macros
	local intAccount, intCharacter = GetNumMacros();
	--Macros shared by all characters on player's account are indexed from 1 to MAX_ACCOUNT_MACROS
	--Macros specific to the current character are indexed from MAX_ACCOUNT_MACROS + 1 to MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS

	local pairs			= pairs;	--local fpointer
	local GetMacroInfo	= GetMacroInfo;

	local nameList = {};	--(macro names are not uniqe, therefore we remember the index so that we dont accidentally delete the wrong one).
	for i=1, intAccount do	--Get list of all Shared 'IfThen_' macros
		local name = GetMacroInfo(i);
		if (name ~= nil and StringParsing:startsWith(name, CONST_MacroPrefix) == true) then nameList[i] = name; end --store both the index and the name
	end--for i

	local intStart	= CONST_MAX_ACCOUNT_MACROS + 1; --119
	local intEnd	= intStart + intCharacter;
	for i=intStart, intEnd do --Get list of all Character specific 'IfThen_' macros
		local name = GetMacroInfo(i);
		if (name ~= nil and StringParsing:startsWith(name, CONST_MacroPrefix) == true) then nameList[i] = name; end --store both the index and the name
	end--for i


	--Create missing macros (any macro from MacroList that doesn't already exist will be created)
	for i=1, #MacroList do
		local currName = MacroList[i];
		local booFound = false;
		for j,v in pairs(nameList) do --ireggular indexed array
			if (currName == v) then booFound = true; break; end
		end--for j,v
		if (booFound == false) then
			self:create(currName); --Create a new macro since its missing.
			--if (IfThen:isDebug()) then print("Create macro: '"..currName.."'"); end
		end--if
	end--for i


	--Delete unused macros (any macro not listed in MacroList that has a name starting with 'IfThen_' will be deleted)
	for j,v in pairs(nameList) do --ireggular indexed array
		local currName = v;
		local booFound = false;
		for i=1, #MacroList do
			if (currName == MacroList[i]) then booFound = true; break; end
		end--for i
		if (booFound == false) then
			DeleteMacro(tonumber(j)); --Delete the macro using the index so we are sure we are deleting the correct one (incase there are duplicate names)
			--if (IfThen:isDebug()) then print("Delete macro: '"..currName.." index: '"..j.."'"); end
		end--if
	end--for j,v

	return nameList;
end


--Return the name of the currently running macro
function Macro:getRunningMacroName()
	local index = GetRunningMacro();
	if (index == nil) then return nil; end
	local name = GetMacroInfo(index);
	if (name == nil) then return nil; end
	if (StringParsing:startsWith(name, CONST_MacroPrefix) == true) then return name; end --return only if its one of our macros (it has a name starting with the proper prefix)
	return nil;
end


--Refresh the macro with its default icon
function Macro:refresh(MacroList)
	local GetMacroIndexByName	= GetMacroIndexByName; --local fpointer
	local EditMacro				= EditMacro;

	if (MacroList == nil) then --refresh the default macro only
		local mIndex = GetMacroIndexByName(CONST_MacroName);
		EditMacro(mIndex, nil, CONST_MacroTexture, nil);
	else
		for i=1, #MacroList do --refresh all the macros in the list
			local mIndex = GetMacroIndexByName(MacroList[i]);
			EditMacro(mIndex, nil, CONST_MacroTexture, nil);
		end--for i
	end
	return true;
end


--Rewrites a macro with an additonal command at the end
function Macro:update(macroName, scriptName, extraCommand, extraItem, changeIcon)
	if (changeIcon ~= true)						then changeIcon = false; end
	if (macroName  == nil or macroName  == "")	then changeIcon = true; macroName = CONST_MacroName end
	if (scriptName == nil)						then scriptName = CONST_ScriptName end --If its nil we use default, empty string means that we use no defaultBody at all

	local mIndex = GetMacroIndexByName(macroName);
	if (mIndex == 0) then
		--message("|cFFEABC32IfThen|r\nCan't find the macro named '|cFFC0C0C0"..macroName.."|r' in the list.");
		IfThen:msg_error("Can't find the macro named '"..macroName.."' in the list.");
		return false;
	end

	--Check to see if the current MacroBody has the extraCommand + extraItem in it already, if it does then we dont have to refresh it
	local curBody		= GetMacroBody(mIndex);
	local newCommand	= "/nil;";
	if (extraCommand ~= nil and extraCommand == "RAWMACRO") then newCommand = extraItem end
	if (extraCommand ~= nil and extraCommand ~= "RAWMACRO") then newCommand = extraCommand.." "..extraItem end
	local sPos1 = strfind(curBody, newCommand, 1, true); --plain find starting at pos 1 in the string
	if (sPos1 ~= nil) then
		--Make the macro icon interactive (must be done after the macro has been edited)
		if (extraCommand ~= nil and changeIcon == true) then
			if (extraCommand == "/cast") then SetMacroSpell(macroName, extraItem) end
			if (extraCommand == "/use")  then SetMacroItem(macroName, extraItem) end
			--if (extraCommand == "/click")  then we dont do anything with the icon
			--if (extraCommand == "RAWTEXT") then we dont do anything with the icon
			--if (extraCommand == "/cancelaura") then we dont do anything with the icon
			--if (extraCommand == "/cancelform") then we dont do anything with the icon
		end

		--if (IfThen:isDebug()) then print("    Macro body already contains the command '"..newCommand.."'. Skipping the macro refresh.") end
		return true; --if we find the current extracommand in the body already then we just return true
	end--if

	--If we are attemtping to write a new command to the macro and we are in combat then we need to just abort now, because Blizzard dosent allow that sort of thing
	if (InCombatLockdown()==1) then
		if (extraCommand ~= nil) then
			if (extraCommand == "RAWMACRO") then
				IfThen:msg_error("You are in combat. Can't rewrite the macro with '"..extraItem.."' while in combat.");
			else
				IfThen:msg_error("You are in combat. Can't rewrite the macro with '"..extraCommand.." "..extraItem.."' while in combat.");
			end
		else
			IfThen:msg_error("You are in combat. Can't rewrite the macro while in combat.");
		end
		return false;
	end

	--Put in a #showtooltip at the top of the macro --if (extraCommand ~= nil) then mBody = "#showtooltip "..extraItem.."\n"..mBody end

	--Add Simple default macro line
	local mBody = "";
	if (scriptName ~= "") then mBody = self:getDefaultBody(scriptName); end --empty string == no defaultBody

	--Add the extracommand (if one is defined)
	if (extraCommand ~= nil) then
		if (extraCommand == "RAWMACRO") then
			mBody = mBody..extraItem; --Don't add ; at the end. That mess up icon-identification for any /use or /cast
			mBody = StringParsing:replace(mBody, "\\/",	"@ESCAPE_SLASH@");
			--There are so many slash commands possible and they vary with localization. Its therefore more efficient to just do a single, simple, replace (much faster than enumerating _G[SLASH_] etc).
			mBody = StringParsing:replace(mBody, " /",	"\n/");	--put a newline before the / (slash)
			mBody = StringParsing:replace(mBody, "\n\n","\n");	--replace double \n with a single \n
			mBody = StringParsing:replace(mBody, "@ESCAPE_SLASH@", "/");
		else
			mBody = mBody..extraCommand.." "..extraItem; --..";\n";
		end
	else
		mBody = mBody.."/nil;\n";
	end
	mBody = strtrim(mBody);
	if (strlen(mBody) > 255) then mBody = strsub(mBody,1,255) end --truncate mBody if its more than 255 characters long

	if (changeIcon == true) then SetMacroSpell(macroName, ""); end --reset beforehand so that icon will update even when theres no /use /cast

	--Update the macro body
	local icon = CONST_MacroTexture;
	--if (extraCommand ~= nil and (extraCommand == "/cast" or extraCommand == "/use")) then icon = CONST_MacroTexture_Blank end --We reset the icon to the blank template if we got a /cast or /use
	if (extraCommand ~= nil and (extraCommand == "/cast" or extraCommand == "/use")) then
		icon = CONST_MacroTexture_Blank; --We reset the icon to the blank template if we got a /cast or /use

		if (GetItemIcon(extraItem) == nil and GetSpellTexture(extraItem) == nil) then --BLIZZARD BUG: 2016-08-03 Check the item/spell to see if it has a texture or not (ToyBox bug:> Returns nil for items that are in the toybox)
			local _, _, _, _, _, _, _, _, _, texture1 = GetItemInfo(extraItem); --Use GetItemInfo to get texture for toybox items.
			local _, _, texture2 = GetSpellInfo(extraItem);
			if (texture1 ~= nil) then icon = texture1; end
			if (texture2 ~= nil) then icon = texture2; end
			--If we reach here we have manually set the icon to the same id as the toy has
		end--if nil
	end
	if (extraCommand ~= nil and extraCommand == "RAWMACRO" and ( strfind(mBody,"/cast",1,true)~=nil or strfind(mBody,"/use",1,true)~=nil )) then icon = CONST_MacroTexture_Blank end --If the rawmacro got a /cast and /use then the UI will auto-id the icon to use.
	if (extraCommand ~= nil and (extraCommand == "/click")) then --If the rawmacro got a /click then we try to get the texture for the extra toolbar.
		--If this is a /click we will try to get the texture from the button and use that. If the button is called 'OverrideActionBarButton1' then the texture is found in 'OverrideActionBarButton1Icon:GetTexture()'
		icon = _G[extraItem.."Icon"];
		if (icon ~= nil and icon["GetTexture"] ~= nil) then
			icon = icon:GetTexture();
			--TODO: 2016-08-03 Legion. Texture string have been replaced with Texture ID's. This code can probably be deprecated.
			if (StringParsing:startsWith(icon, "\\Interface\\Icons\\") == true or StringParsing:startsWith(icon, "Interface\\Icons\\") == true) then
				icon = StringParsing:replace(icon, "\\Interface\\Icons\\", ""); --Must strip away the start of the path for it to work. Otherwise it will just show a green texture.
				icon = StringParsing:replace(icon, "Interface\\Icons\\",   "");
			--else
				--icon = CONST_MacroTexture; --If the texture is found in another subfolder than Interface\Icons we dont risk using it; it might otherwise show a green texture.
			end--if startsWith
		else
			icon = CONST_MacroTexture;
		end--if icon
	end --if
	if (changeIcon == false) then icon = nil; end; --Will not use modify icon if flag isnt set.
	EditMacro(mIndex, nil, icon, mBody);

	--Make the macro icon interactive (must be done after the macro has been edited)
	--Note: this does not change the icon of the macro, just the cooldown animation, and stacknumber/uses left on the item show up
	if (extraCommand ~= nil and changeIcon == true) then
		if (extraCommand == "/cast")	then SetMacroSpell(macroName, extraItem) end
		if (extraCommand == "/use")		then SetMacroItem(macroName, extraItem) end
		--if (extraCommand == "/click") then we dont do anything with the icon
		--if (extraCommand == "RAWMACRO") then we dont do anything with the icon
		--if (extraCommand == "/cancelaura") then we dont do anything with the icon
		--if (extraCommand == "/cancelform") then we dont do anything with the icon
	end

	return true;
end


--Returns true/false whether the macro exists
function Macro:exists(macroName)
	if (macroName == nil or macroName == "") then macroName = CONST_MacroName; end

	local mIndex = GetMacroIndexByName(macroName);
	if (mIndex == 0) then return false; end
	return true;
end


--Will create a new default macro
function Macro:create(macroName, scriptName)
	if (macroName == nil or macroName == "") 	then macroName	= CONST_MacroName;	end
	if (scriptName == nil or scriptName == "")	then scriptName	= CONST_ScriptName;	end
	if (strlen(macroName) > CONST_MacroNameLength) then
		--message("|cFFEABC32IfThen|r\nName for a macro can't be\n longer than "..tostring(CONST_MacroNameLength).." characters: '|cFFC0C0C0"..macroName.."|r'"); --Show message in the users face and then we fail
		IfThen:msg_error("Name for a macro can't be longer than "..tostring(CONST_MacroNameLength).." characters: '"..macroName.."'");
		return nil;
	end

	local mIndex	= GetMacroIndexByName(macroName);	--If the macro already exists then overwrite it
	local mBody		= self:getDefaultBody(scriptName);	--Simple default macro
	if (strlen(mBody) > 255) then mBody = strsub(mBody,1,255) end --truncate mBody if its more than 255 characters long

	if (mIndex == 0) then
		local intAccount, intCharacter = GetNumMacros();
		if (intAccount >= CONST_MAX_ACCOUNT_MACROS) then
			--message("|cFFEABC32IfThen|r\nYour general macro list is full.\nDelete a macro to make space."); --Show message in the users face and then we fail
			IfThen:msg_error("Your general macro list is full. Delete a macro to make space for '"..macroName.."'");
			return nil;
		end
		--Create a new macro
		mIndex = CreateMacro(macroName, CONST_MacroTexture, mBody, nil); --Always created as a shared macro (not per character)
	else
		--Update existing macro
		mIndex = EditMacro(mIndex, nil, nil, mBody);
	end

	return mIndex;
end


--Returns the default body of the macro
function Macro:getDefaultBody(scriptName)
	if (scriptName == nil or scriptName == "") then scriptName = CONST_ScriptName end
	return "/run "..scriptName..";\n"; --Simple default macro
end


--####################################################################################
--####################################################################################