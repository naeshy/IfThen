--####################################################################################
--####################################################################################
--####################################################################################
--####################################################################################
--Documentation library. This class contains a description of all the IfThen functions and methods
--####################################################################################
--Dependencies: StringParsing.lua, Methods.lua, IfThen.lua:HyperLink_Create()

local Documentation	= {};
Documentation.__index	= Documentation;
IfThen_Documentation	= Documentation; --Global declaration

local StringParsing	= IfThen_StringParsing;	--Local pointer
local Methods		= IfThen_Methods; 		--Local pointer
--local IfThen		= IfThen_IfThen;	 	--Local pointer


--Local variables that cache stuff so we dont have to recreate large objects
local cache_DeclareDocumentation	= nil;
local cache_DeclareEscaping			= nil;
local cache_EmptyEvent				= function() return true end; --default event handler that returns true, this is used so we all refer to the same address and dont waste memory
local cache_Minimize				= false;
local cache_SyntaxColorfunction		= nil;	--nil or a pointer to a function that does syntax coloring

local CONST_cVAL					= "|cFF149494"; --teal		Values
local CONST_cREQ					= "|cFFEBB81F"; --yellow	Required
local CONST_cOPT					= "|cFF806EC5"; --purple	Optional


--Shorthand aliases for all the key's in the DocStruct
local NAME	= "shortname";		--HasItem
local DESC	= "description";	--Are you the leader of the instance/party/raid
local SIGN	= "signature";		--HasItem(BUFFNAME,UNIT,COUNT)		--Note: Env-variables uses this field to store a boolean (Static value = true/false)
local ARG	= "arguments";		--TYPE, BUFFNAME -Description of the argument, TYPE, UNIT -Description of the argument, TYPE, COUNT -Description of the argument
local RET	= "returns";		--Returns true if have the item in inventory or equipped, false otherwise --Note: OnEvent()'s uses this field to store it's WOW eventname --Note: Env-variables uses this field to store a argumentvalue for the value lookup function
local REM	= "remarks";		--Will return false even if the item is in your bank
local EX	= "examples";		--IF HasItem("mana gem") THEN Print("i have managem in ready")
local REF	= "reference";		--Chat(), HasBuff(), Links
local MAX	= "maxarguments";	--Maximum number of arguments
local MIN   = "minarguments";	--Minimum number of arguments
local PTR   = "pointer";		--pointer to the function
									--We declare the function using colon-notation (:) in Methods.lua, but refer to them using dot-notation (.) here. This way we save a function wrapper
										--Since we use a dot-notation here we need to inlcude 'self' as the first input argument in Parsing.lua
										--Method signature for functions: function MyFunction(self,table)
										--Method signature for events: function MyEventHandler(self,table,table)
local EMPTY	= "";
local FU	= "func_";			--prefix to shortname for functions
local AR	= "argument_";		--prefix to shortname for arguments
local AC	= "action_";		--prefix to shortname for actions
local AM	= "action_macro_";	--prefix to shortname for action macro's
local EV	= "onevent_";		--prefix to shortname for events
local VA	= "var_";			--prefix to shortname for enviroment variables
local TAB	= "    ";			--one Tab is 4 spaces


--Local pointers to global functions
local type		= type;
local tostring	= tostring;
local pairs		= pairs;
local strlower	= strlower;
local strtrim	= strtrim;	--string.trim
local tinsert	= tinsert;	--table.insert
local sort		= sort;		--table.sort


--####################################################################################
--####################################################################################
--Public functions
--####################################################################################
--####################################################################################


--Removes functions that are not needed after initial startup.
function Documentation:CleanUp()
	self:DeclareDocumentation(); --Make sure this has been called before we remove anything
	self:doUnDeclareDocumentation();
	self:doUnDeclareEscaping();
	local d = {"DeclareDocumentation", "doUnDeclareDocumentation", "DeclareEscaping", "doUnDeclareEscaping", "argCount", "CreateOnDocStruct", "MinimizeDocStruct", "GetEmoteTokenList", "GetPlayAudioList"};
	for i=1, #d do self[d[i]] = nil; end --for
	return nil;
end


--Formats an array of "See also:" reference links into ifthen: hyperlinks that can be clicked
function Documentation:formatMethodLinks(tbl, currType)
	local res = {}; --Must create new table that we return the results in so that we dont taint the data in tbl
	for i = 1, #tbl do	--for each string in the array, replace it with a ifthen: link
		local strName	= tbl[i];
		local strSearch	= strlower(strName);
		local strType	= currType;
		local p = StringParsing:indexOf(strSearch, "::", 1); -- '::' is used to override strType
		if (p ~= nil and p > 2) then
			strType = strtrim(strsub(strSearch, p+2));	--From :: to the end of the string is the override for strType
			strName = strtrim(strsub(strName, 1, p-1));	--Infront of the :: is the title
			strSearch = strlower(strName);
		end
		--Strip out any colorstrings
		strSearch = StringParsing:replace(strSearch, strlower(CONST_cVAL), "");
		strSearch = StringParsing:replace(strSearch, strlower(CONST_cREQ), "");
		strSearch = StringParsing:replace(strSearch, strlower(CONST_cOPT), "");
		strSearch = StringParsing:replace(strSearch, "|r", "");

		if (StringParsing:startsWith(strSearch, "onevent") == true) then
			--Custom override for OnEvent statements since their references for both the string 'onevent' and color in their titles
			strSearch = StringParsing:replace(strSearch, 'onevent("', "");	--'OnEvent("Timer")'
			strSearch = StringParsing:replace(strSearch, '")', "");
		elseif (StringParsing:startsWith(strSearch, "%") == true) then
			--Custom override for variables
			strSearch = StringParsing:replace(strSearch, '%', "");	--'%PlayerClass%'
		else
			p = StringParsing:indexOf(strSearch, "(", 1); --find the first (
			if (p ~= nil and p > 2) then strSearch = strtrim(strsub(strSearch, 1, p-1)); end --just use the stuff up until the first (
		end--if

		strName = StringParsing:replace(strName, "%", "PLACEHOLDER_PERCENT"); --Must replace % for this to work
		--print ("strName '"..strName.."' strSearch '"..strSearch.."' strType '"..strType.."'");
		--"morehelp", <name>, strType, <name in lowercase before (
		local link = IfThen:HyperLink_Create("morehelp", strName, strType, strSearch); --command, title, page, search
		link = StringParsing:replace(link, "|cFFFF0000|H", "|H"); --Strip out the IfThen.cache_Color_HyperLinks
		link = StringParsing:replace(link, "|h|r", "|h");
		link = StringParsing:replace(link, "PLACEHOLDER_PERCENT", "%%"); --Replace % back again

		res[i] = link;
	end--for i
	return res;
end


--Return a simple preformatted description of a method\event\variable
function Documentation:printMethod(Name, strType)
	--Determine whether this is an event or not
	local isEvent	= false;
	local isVar		= false;
	local d			= nil;
	local booMin 	= cache_Minimize; --if true then we return fewer fields

	strType = strlower(strType);
	if     strType == "event"    then isEvent = true;
	elseif strType == "variable" then isVar   = true; end
	local d = self:getMethod(Name, strType);
	if (d == nil) then d = self:getMethod(Name, "action macro"); end

	if (d == nil) then return "not found" end
	d = self:doEscaping({d})[1]; --must wrap it in a temporary outer table before we call it, and then we discard it again after
	local n = "";

	if (isVar) then
		--Output a formatted description of the enviroment variable
		n = n..d[NAME].."\n\n";
		if (not booMin) then n = n..d[DESC].."\n\n"; end

		--n = n..d[SIGN].."\n\n\n";		--Boolean. True for static value, False for dynamic value
		--n = n..d[ARG].."\n\n\n";		--Datatype, 'STR[' or 'INT['
		n = n.."Type: ";
		if (d[ARG] ~= nil) then
			if (StringParsing:startsWith(d[ARG], "STR[")) then n = n.."String";
			else														n = n.."Number"; end
			--[[if (d[SIGN] == true) then								n = n..", Static";
			else														n = n..", Dynamic"; end]]--
		end--d[ARG] ~= nil
		n = n.."\n\n";

		if (not booMin) then
			n = n.."Remarks:\n";
			if (d[REM] == nil) then	n = n..TAB.."none\n\n";
			else					n = n..TAB..d[REM].."\n\n"; end
			n = n.."Example:\n";
			if (d[EX] == nil) then	n = n..TAB.."none\n\n\n";
			else
				local tmp = d[EX];
				if (cache_SyntaxColorfunction ~= nil) then
					tmp = StringParsing:replace(tmp, "\n"..TAB, "\n"); --Need to replace the TAB with just a newline orelse the coloring for FU functions like OnEvent() and MacroStart() will not be correct
					tmp = cache_SyntaxColorfunction(tmp);
					tmp = StringParsing:replace(tmp, "\n", "\n"..TAB);
				end
				n = n..TAB..tmp.."\n\n\n";
			end
			n = n.."See also:"..TAB.."|cFF9D9D9D(click names below to goto documentation-page)|r\n";
			if (d[REF] ~= nil and #d[REF] >=1) then
				local tbl = d[REF];
				sort(tbl); --Alphabetical sorting of arguments
				tbl = self:formatMethodLinks(tbl, strType); --format from strings into ifthen: hyperlinks
				n = n..TAB..tbl[1];
				for i=2, #tbl do
					n = n..", "..tbl[i];
				end--for
			else
				n = n..TAB.."none";
			end--if
		end--if not booMin
		n = n.."\n\n";
	else

		--Output a formatted description of the function/event
		n = n..d[NAME].."\n\n";
		if (not booMin) then n = n..d[DESC].."\n\n"; end
		n = n..d[SIGN].."\n\n\n";

		n = n.."Arguments:\n";
		if (isEvent ~= true) then --OnEvent starts at position 2, otherwise identical
			if (d[ARG] == nil or #d[ARG] == 0) then
				n = n..TAB.."none\n";
			else
				for i=1, #d[ARG], 2 do
					n = n..TAB..d[ARG][i+1].."\n";
				end--for
				--if (#d[ARG] == 0) then 	n = n..TAB.."none\n"; end
			end--d[ARG] == nil

		else
			if (d[ARG] == nil or #d[ARG] == 0) then
				n = n..TAB.."none\n";
			else
				for i=3, #d[ARG], 2 do
					n = n..TAB..d[ARG][i+1].."\n";
				end--for
				if (#d[ARG] == 2) then 	n = n..TAB.."none\n"; end
			end--d[ARG] == nil

		end--if
		n = n.."\n\n";

		if (not booMin) then
			if (isEvent ~= true) then --OnEvent does not have 'Returns' otherwise identical
				n = n.."Returns:\n";
				n = n..TAB..d[RET].."\n\n";
			end--if

			n = n.."Remarks:\n";
			if (d[REM] == nil) then	n = n..TAB.."none\n\n";
			else					n = n..TAB..d[REM].."\n\n"; end
			n = n.."Example:\n";
			if (d[EX] == nil) then	n = n..TAB.."none\n\n\n";
			else
				local tmp = d[EX];
				if (cache_SyntaxColorfunction ~= nil) then
					tmp = StringParsing:replace(tmp, "\n"..TAB, "\n"); --Need to replace the TAB with just a newline orelse the coloring for FU functions like OnEvent() and MacroStart() will not be correct
					tmp = cache_SyntaxColorfunction(tmp);
					tmp = StringParsing:replace(tmp, "\n", "\n"..TAB);
				end
				n = n..TAB..tmp.."\n\n\n";
			end
			n = n.."See also:"..TAB.."|cFF9D9D9D(click names below to goto documentation-page)|r\n";
			if (d[REF] ~= nil and #d[REF] >=1) then
				local tbl = d[REF];
				sort(tbl); --Alphabetical sorting of arguments
				tbl = self:formatMethodLinks(tbl, strType); --format from strings into ifthen: hyperlinks
				n = n..TAB..tbl[1];
				for i=2, #tbl do
					n = n..", "..tbl[i];
				end--for
			else
				n = n..TAB.."none";
			end--if
		end--if not booMin
		n = n.."\n\n";

	end--isVar

	return strtrim(n);
end


--Returns a simple preformatted string of functions + number of items in the list
function Documentation:printSimpleMethodList(strType)
	local d = self:getSimpleMethodList(strType, true);
	if (d == nil) then return "" end

	local n = "";
	for i=1, #d do
		n = n..d[i].."\n";
	end--for

	return strtrim(n), #d; --string, #number of items
end


--Returns 3 arrays with all function and variable names in lowercase
function Documentation:getFullMethodListFunctionAndVariable()
	if (cache_DeclareDocumentation == nil) then self:DeclareDocumentation(); end

	local pairs		= pairs;	--local fpointer
	local strlower	= strlower;

	local func	= {}; --All other functions
	local funcN = {}; --OnEvent, MacroStart, MacroEnd; functions that can start on a newline but nowhere else.
	local var	= {}; --Enviroment Variables
	local va = strlower(VA);
	local ev = strlower(EV);
	local fu = strlower(FU);

	--iterate through the whole list of functions and return those that match
	for key,value in pairs(cache_DeclareDocumentation) do
		if (StringParsing:startsWith(key, va) == true) then
			 var[#var+1] = strlower(value[NAME]); --Variable array
		elseif (StringParsing:startsWith(key, fu) == true) then
			funcN[#funcN+1] = strlower(value[NAME]); --Function2 array
		else
			--Include everything (argument,action,action macro) except OnEvent-events (variables are excluded by the first if-statement)
			if (StringParsing:startsWith(key, ev) == false) then func[#func+1] = strlower(value[NAME]); end --Function array
		end--if
	end--for

	return func, funcN, var;
end


--Returns a table with a function-signatures as values and function-names as keys
function Documentation:getFullMethodList(formatFunction)
	if (cache_DeclareDocumentation == nil) then self:DeclareDocumentation(); end

	if (formatFunction == nil) then formatFunction = function(strType, tmpKey, tmpValue) return tmpValue end; end

	local pairs		= pairs;	--local fpointer
	local strlower	= strlower;

	local d	= {};
	local fu = strlower(FU);
	local ar = strlower(AR);
	local ac = strlower(AC);
	local am = strlower(AM);
	local ev = strlower(EV);
	local va = strlower(VA);

	--iterate through the whole list of functions and return those that match
	for key,value in pairs(cache_DeclareDocumentation) do
		local strType = "function";
		if		(StringParsing:startsWith(key, fu) == true) then strType = "function";
		elseif	(StringParsing:startsWith(key, ar) == true) then strType = "argument";
		elseif	(StringParsing:startsWith(key, ac) == true) then strType = "action";
		elseif	(StringParsing:startsWith(key, am) == true) then strType = "action"; --action macro is the same as action
		elseif	(StringParsing:startsWith(key, ev) == true) then strType = "event";
		elseif	(StringParsing:startsWith(key, va) == true) then strType = "variable"; end

		if (strType ~= "function")	then
			local tmpKey	= strlower(value[NAME]);
			local tmpValue	= value[SIGN];
			if (strType == "variable") then tmpValue = "%%"..value[NAME].."%%"; end --Variable (must use double % or the formatting function fails)
			tmpValue = formatFunction(strType, tmpKey, tmpValue); --Function will format the values into ifthen:hyperlinks

			--We can get collisions on keys. Like with 'Chat' that exist both as an action and a event. We therefore check if the key is uniqe, if it isnt then we simply expand it until it is.
			--The key itself isnt used for display, only searching so this works fine.
			if (d[tmpKey] ~= nil) then
				while true do
					tmpKey = tmpKey..tmpKey;
					if (d[tmpKey] == nil) then break; end
				end--while
			end--if

			d[tmpKey] = tmpValue;
		end--if strType
	end--for
	--sort(d); --Alphabetical sort (not possible with tables, only arrays)
	return d;
end


--Returns a simple array of function-names
function Documentation:getSimpleMethodList(strType, useSignature)
	local d = self:getMethodList(strType);
	if (d == nil) then return nil end

	if (strlower(strType) == "variable") then useSignature = false end --Override for Enviroment variables since they dont have signatures

	local tinsert = tinsert; --local fpointer
	local r = {};
	for i=1, #d do
		if (useSignature == true) then	tinsert(r, d[i][SIGN]);
		else							tinsert(r, d[i][NAME]); end
	end--for
	sort(r); --Alphabetical sort

	return r;
end


--Return an array of doc-structs
function Documentation:getMethodList(strType)
	if (cache_DeclareDocumentation == nil) then self:DeclareDocumentation(); end

	local d = {};
	local tinsert	= tinsert; --local fpointer
	local pairs		= pairs;
	local strlower	= strlower;

	strType = strtrim(strlower(strType));
	local strPrefix = ""; --prepend a prefix based on the function type
	if		strType == "argument"		then strPrefix = strlower(AR)
	elseif	strType == "action"			then strPrefix = strlower(AC)
	elseif	strType == "action macro"	then strPrefix = strlower(AM) --strPrefix = strlower(AM) both 'action' and 'action macro' are considered the same
	elseif	strType == "event"			then strPrefix = strlower(EV)
	elseif	strType == "variable"		then strPrefix = strlower(VA)
	else									 strPrefix = strlower(FU) end

	--iterate through the whole list of functions and return those that match on prefix
	for key,value in pairs(cache_DeclareDocumentation) do
		--Return only one specific category
		if (StringParsing:startsWith(key, strPrefix)) then tinsert(d, value); end
	end--for
	d = self:doEscaping(d);

	if (d == nil or #d == 0) then return nil; end
	return d;
end


--Return a specified function/event's doc-struct
function Documentation:getMethod(Name, strType)
	if (cache_DeclareDocumentation == nil) then self:DeclareDocumentation(); end

	local strlower = strlower; --local fpointer

	strType = strtrim(strlower(strType));
	local strName = ""; --prepend a prefix based on the function type
	if		strType == "argument"		then strName = strlower(AR..Name)
	elseif	strType == "action"			then strName = strlower(AC..Name)
	elseif	strType == "action macro"	then strName = strlower(AM..Name)
	elseif	strType == "event"			then strName = strlower(EV..Name)
	elseif	strType == "variable"		then strName = strlower(VA..Name)
	else									 strName = strlower(FU..Name) end

	return cache_DeclareDocumentation[strName];
end


--Set/Unset Minimize parameter
function Documentation:MinimizeDocStruct(b)
	if (b == true) then	cache_Minimize = true; self:SetSyntaxColorFunction(nil);
	else				cache_Minimize = false; end
	return cache_Minimize; --This flag is looked at by doUnDeclareDocumentation()
end


--Set pointer to Syntax coloring function or nil
function Documentation:SetSyntaxColorFunction(func)
	if (cache_Minimize == true) then func = nil; end --no point in having this if minimal is enabled, save the memory
	if type(func) == "function" then	cache_SyntaxColorfunction = func;
	else								cache_SyntaxColorfunction = nil; end
	return nil;
end


--Return a string with all emote tokens possible (used in DeclareDocumentation for the 'Emote' function)
function Documentation:GetEmoteTokenList(intLineBreak)
	--We do not cache the result from this function since its only used once in the documentation for the 'Emote()' function. After that its deleted by CleanUp()

	--HARDCODED: Last updated on 2016-05-16 (Legion 7.0.3), highest value found was 518: \Interface\FrameXML\ChatFrame.lua
	---			 The maxvalue that the loop will iterate to to look for emote tokens.
	local maxID = 700;

	--All emote tokens are defined in \Interface\FrameXML\ChatFrame.lua  They are defined in global variables called "EMOTE<number>_TOKEN"
	--They are sequential up until 170, then there is suddenly a gap. We therefore have to use a hardcoded value as a celing instead of just checking for nil.
	local tostring	= tostring; --local fpointer
	local type		= type;
	local strlen	= strlen;
	local G			= _G;
	local tbl		= {};
	for i=1, maxID do
		local tmpName	= "EMOTE"..tostring(i).."_TOKEN";
		local tmpToken	= G[tmpName];
		if (tmpToken ~= nil and type(tmpToken) == "string") then tbl[#tbl+1] = StringParsing:capitalizeString(tmpToken); end --We capitalize the tokens for pretty presentation.
	end--for i
	sort(tbl); --Alphabetical sort (for the Documentation display format)

	local res1		= tbl[1];				--res1 is the STR[] datatype format
	local res2		= "VAL{"..tbl[1].."}";	--res2 is the Documentation display format
	local atBreak	= tonumber(intLineBreak) or 100;--linebreak at N characters
	local curr		= strlen(tbl[1]);				--counter for pretty presentation

	for i=2, #tbl-1 do
		res1 = res1..";"..tbl[i];
		if (curr >= atBreak) then
			res2 = res2..",TAB{}VAL{"..tbl[i].."}";
			curr = strlen(tbl[i]);
		else
			res2 = res2..", VAL{"..tbl[i].."}";
			curr = curr + strlen(tbl[i]);
		end
	end--for
	res1 = strtrim(strlower(res1..";"..tbl[#tbl]));								--add the last one without the ; at the end
	res2 = res2..", VAL{"..tbl[#tbl].."} ("..tostring(#tbl).." tokens total).";	--add the last one without the , at the end

	return res1, res2;
end


--Return a string with all aliases for PlayAudio() (used in DeclareDocumentation for the 'PlayAudio' function)
function Documentation:GetPlayAudioList(intLineBreak)
	--We do not cache the result from this function since its only used once in the documentation for the 'PlayAudio()' function. After that its deleted by CleanUp()

	local lst = Methods:get_PlayAudioList(); --List of all the sounds (unsorted)
	local srt = {};
	local tinsert	= tinsert; --local fpointer
	local pairs		= pairs;
	local strlen	= strlen;
	for key,value in pairs(lst) do
		tinsert(srt, key);
	end--for
	sort(srt); --Alphabetical sort (for the Documentation display format)
	--Hyperlinks are the same as described in IfThen:HyperLink_Create() with exception of the coloring

	local res		= "VAL{|Hifthen:playaudio:"..srt[1].." |h["..srt[1].."]|h}";	--res is the Documentation display format (with hyperlinks in them)
	local atBreak	= tonumber(intLineBreak) or 100;--linebreak at N characters
	local curr		= strlen(srt[1]);				--counter for pretty presentation

	for i=2, #srt-1 do
		if (curr >= atBreak) then
			res = res..",TAB{}VAL{|Hifthen:playaudio:"..srt[i].." |h["..srt[i].."]|h}";
			curr = strlen(srt[i]);
		else
			res = res..",  VAL{|Hifthen:playaudio:"..srt[i].." |h["..srt[i].."]|h}";
			curr = curr + strlen(srt[i]);
		end
	end--for
	res = res..",  VAL{|Hifthen:playaudio:"..srt[#srt].." |h["..srt[#srt].."]|h}  ("..tostring(#srt).." aliases total)."; --add the last one without the , at the end
	return res;
end



--Return a table with all colorvalues used
function Documentation:GetColors()
	return {["VAL"]=CONST_cVAL, ["REQ"]=CONST_cREQ, ["OPT"]=CONST_cOPT};
end
--[[Not in use
function Documentation:SetColors(colValue, colRequired, colOptional)
	CONST_cVAL = colValue;
	CONST_cREQ = colRequired;
	CONST_cOPT = colOptional;
	return nil;
end]]--


--####################################################################################
--####################################################################################
--Support functions
--####################################################################################
--####################################################################################


--Remove all unused fields from the docstruct in cache_DeclareDocumentation
function Documentation:doUnDeclareDocumentation()
	if (cache_DeclareDocumentation == nil) then self:DeclareDocumentation(); end
	local objStruct		= cache_DeclareDocumentation;
	local newStruct		= {};
	local booMinimize	= cache_Minimize; --if true then we set alot of stuff to nil to save space

	local pairs = pairs; --local fpointer

	for rowKey,rowValue in pairs(objStruct) do
		--for each element in the struct...
			if (StringParsing:startsWith(rowKey, EV)) then
				--Events got even more unused stuff
				rowValue[RET]	= nil; --returns

			elseif (StringParsing:startsWith(rowKey, VA)) then
				--Variables got even more unused stuff
				rowValue[RET]	= nil; --returns
				rowValue[SIGN]	= nil; --signature
				--rowValue[ARG]	= nil; --arguments
			end

			--rowValue[NAME]	= EMPTY; --shortname	--HasItem()
			--rowValue[DESC]	= EMPTY; --description	--Are you the leader of the instance/party/raid/battleground
			--rowValue[SIGN]	= EMPTY; --signature	--HasItem(BUFFNAME,UNIT,COUNT)
			--rowValue[ARG]		= nil;   --arguments	--BUFFNAME, Description of the argument, UNIT, Description of the argument, COUNT, Description of the argument	--table or nil
			if (StringParsing:startsWith(rowKey, VA) ~= true) then --if this isnt a variable then remove the datatype field.
				if (rowValue[ARG] ~= nil) then
					for i=1, #rowValue[ARG], 2 do--for each argument
						rowValue[ARG][i] = nil; --set the datatype field to nil (but keep the string description)
					end--for i
				end--if
			end--if

			if (booMinimize == true) then
				rowValue[DESC]	= nil; --description	--Are you the leader of the instance/party/raid/battleground
				if (StringParsing:startsWith(rowKey, VA) ~= true) then --if this isnt a variable then remove the return field.
					rowValue[RET]	= nil; --returns	--Returns true if have the item in inventory or equipped, false otherwise
				end
				rowValue[REM]	= nil; --remarks	--Will return false even if the item is in your bank
				rowValue[EX]	= nil; --examples	--IF HasItem("mana gem") THEN Print("i have managem in ready")
				rowValue[REF]	= nil; --reference 	--Chat(), HasBuff(), Links 	--table or nil
			end--if booMinimize

			--rowValue[RET]	= EMPTY; --returns		--Returns true if have the item in inventory or equipped, false otherwise
			--rowValue[REM]	= EMPTY; --remarks		--Will return false even if the item is in your bank
			--rowValue[EX]	= EMPTY; --examples		--IF HasItem("mana gem") THEN Print("i have managem in ready")
			--rowValue[REF]	= nil;   --reference 	--Chat(), HasBuff(), Links 	--table or nil
			rowValue[MIN]	= nil;   --min arguments
			rowValue[MAX]	= nil;   --max arguments
			rowValue[PTR]	= nil;   --pointer


			--Create a new table where we simple cut out all the nil fields (save about 80KB just from this)
			local tmpRow = {};
			for key,value in pairs(rowValue) do
				if (value ~= nil and value ~= "") then tmpRow[key] = value; end
			end--for key
			newStruct[rowKey] = tmpRow;

	end--for objStruct

	cache_DeclareDocumentation = newStruct;
	--return cache_DeclareDocumentation;
	return nil;
end


--Remove all unused fields from the array in cache_DeclareEscaping
function Documentation:doUnDeclareEscaping()
	if (cache_DeclareEscaping == nil) then self:DeclareEscaping(); end
	local objStruct = cache_DeclareEscaping;
	local d = {};

	--After startup, and when datatypes have been cached by Parsing.lua then we no longer need to remember the entries with '[]' inside them.
	--We therefore remove them from the array.
	for i=1, #objStruct do
		local key, value = objStruct[i][1], objStruct[i][2];
		if (StringParsing:indexOf(key,"[",1) == nil) then d[#d+1] = {key,value}; end --"[]"
	end--for i
	cache_DeclareEscaping = d;
	return nil;
end


--Replace placeholders in a doc-struct with its placeholders (this must be done in a specific order and is therefore done using an numeric array)
function Documentation:doEscaping(objStruct)
	if (cache_DeclareEscaping == nil) then self:DeclareEscaping(); end
	local objEscape = cache_DeclareEscaping;
	if (objStruct == nil or objEscape == nil) then return objStruct end

	--local intNil = 0;
	local type	= type; --local fpointer
	local pairs	= pairs;

	--for each string to replace...
	for i=1, #objEscape do
		local key	= objEscape[i][1];
		local value	= objEscape[i][2];
		--for each row in the table...
		for rowKey,rowValue in pairs(objStruct) do
			--for each element in the struct...
			for k,v in pairs(rowValue) do
				if type(v) == "string" then
					objStruct[rowKey][k] = StringParsing:replace(v, key , value);	--Replace @KEY@ with the escaped value
				elseif type(v) == "table" then
					--objStruct[k] = self:doEscaping(v, objEscape);	 	--Recursive call if it's a sub-table;
					--These sub-tables are arrays so we cant use recursion
					if (#v == 0) then
						objStruct[rowKey][k] = nil; --Remove empty tables and replace them with nil so we save memory
						--intNil = intNil+1;
						--print("nilled '"..rowKey.."' '"..k.."' "..tostring(intNil));
					else
						for j=1, #v do
							if (v[j] ~= nil) then
								objStruct[rowKey][k][j] = StringParsing:replace(v[j], key , value);	--Replace @KEY@ with the escaped value
							end--if v[j]
						end--for j
					end--if #v

				else
					--do nothing
				end--if
			end--for rowValue
		end--for objStruct
	end--for objEscape

	return objStruct;
end


--Count the number of required and optional arguments in a array of arguments
function Documentation:argCount(objArguments, isMin)
	if (objArguments == nil or #objArguments == 0) then return 0 end

	if (isMin == true) then
		--Return the minimum number of required parameters
		local req = 0;
		for i=1, #objArguments, 2 do
			--Count the number of optional arguments in the array
			if (StringParsing:startsWith(objArguments[i+1], "REQ{")) then req = req + 1 end
		end--for
		return req;
	else
		--We simply return the total number of arguments in the array (minus the datatype definitions)
		return (#objArguments / 2);
	end--if
end


--Creates a table with all the doc-elements in it
function Documentation:CreateOnDocStruct()
	local d = {};
	d[NAME]	= EMPTY; --shortname	--HasItem()
	d[DESC]	= EMPTY; --description	--Are you the leader of the instance/party/raid/battleground
	d[SIGN]	= EMPTY; --signature	--HasItem(BUFFNAME,UNIT,COUNT)
	d[ARG]	= nil;   --arguments	--BUFFNAME, Description of the argument, UNIT, Description of the argument, COUNT, Description of the argument	--table or nil
	d[RET]	= EMPTY; --returns		--Returns true if have the item in inventory or equipped, false otherwise
	d[REM]	= nil;   --remarks		--Will return false even if the item is in your bank
	d[EX]	= nil;   --examples		--IF HasItem("mana gem") THEN Print("i have managem in ready")
	d[REF]	= nil;   --reference 	--Chat(), HasBuff(), Links 	--table or nil
	d[MIN]	= 0;     --min arguments
	d[MAX]	= 0;     --max arguments
	d[PTR]	= nil;   --pointer
	return d;
end


--####################################################################################
--####################################################################################
--Declaration functions
--####################################################################################
--####################################################################################

	--Note; when adding support for more events and functions we need to update this list, and then add nil or an function to handle the event to Methods.lua
	--List of ingame events: http://wowprogramming.com/docs/events

function Documentation:DeclareDocumentation()
	if (cache_DeclareDocumentation ~= nil) then return cache_DeclareDocumentation end
	local d = {};	--Complete documentation
	local p = nil;	--A single doc-struct
	local _G		= _G; --local fpointer
	local strlower	= strlower;

	-- --------------------------------------------
	--[[
	p = self:CreateOnDocStruct();
	p[NAME]	=	''; --shortname		--HasItem()
	p[DESC]	=	''; --description	--Are you the leader of the instance/party/raid/battleground
	p[SIGN]	=	''; --signature		--HasItem(BUFFNAME,UNIT,COUNT)
	p[ARG]	=	{}; 				--arguments	--"BUFFNAME Description of the argument", "UNIT Description of the argument", "COUNT Description of the argument"
	p[RET]	=	''; --returns		--Returns true if have the item in inventory or equipped, false otherwise --Note: OnEvent()'s uses this field to store it's WOW eventname
	p[REM]	=	''; --remarks		--Will return false even if the item is in your bank
	p[EX]	=	nil; --examples		--IF HasItem("mana gem") THEN Print("i have managem in ready")
	p[REF]	=	nil; --reference		--Chat(), HasBuff(), Links
	p[MIN]	=	self:argCount(p[ARG],true);		--minimum number of required arguments
	p[MAX]	=	self:argCount(p[ARG],false);	--maximum number of required arguments
	p[PTR]	=	Methods.XXXX(n) end;	--pointer to the method's function
	d[strlower(p[NAME])] = p;		--d[FU..p[strlower(p[NAME])]=p;	--"func_hasitem()" or "event_hasitem()"
	]]--
	-- --------------------------------------------


	-- Arguments ----------------------------------
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Compare";
	p[DESC]	=	"Compares two string-values.";
	p[SIGN]	=	'Compare("REQ{String1}", "REQ{String2}", "OPT{OP}", "OPT{IgnoreCase}")';
	p[ARG]	=	{
				"STR[]",	"REQ{String1}         -String on left side in comparison.",
				"STR[]",	"REQ{String2}         -String on right side in comparison.",
				"OP[]",		"OPT{OP}               -Comparison operator:  @OP@.",
				"BOOL[]",	"OPT{IgnoreCase}   -Can either be @BOOL@. If omitted it defaults to 'VAL{true}'."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"This method uses standard string-comparison rules when comparing the two strings. If you pass in two numbers as arguments, then the result will not be what you expect.TAB{}If the values are for example '14' and '123' then '14' will be deemed as the highest value (string-comparison rules). You can use CompareNum() to correctly compare numbers.";
	p[EX]	=	'IF Compare("A","B") THEN Print("This will never happen");TAB{}IF Compare("A","B", "neq") THEN Print("This will always happen");TAB{}IF Compare("%playerName%","%targetName%", "eq") THEN Print("Why am i targeting myself?");';
	p[REF]	=	{"CompareNum()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.Compare;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"CompareNum";
	p[DESC]	=	"Compares two number-values.";
	p[SIGN]	=	'CompareNum("REQ{Value1}", "REQ{Value2}", "OPT{OP}", "OPT{IntegerRound}")';
	p[ARG]	=	{
				"INT[]",	"REQ{Value1}            -Number on left side in comparison.",
				"INT[]",	"REQ{Value2}            -Number on right side in comparison.",
				"OP[]",		"OPT{OP}                  -Comparison operator:  @OP@.",
				"BOOL[]",	"OPT{IntegerRound}   -Can either be @BOOL@. If omitted it defaults to 'VAL{true}'."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"If OPT{IntegerRound} is 'VAL{true}' then the function will round the numbers to the nearest whole integer before comparing them (10.4 becomes 10 and 10.5 becomes 11).";
	p[EX]	=	'IF CompareNum("1","2", "lt") THEN Print("1 is less than 2");TAB{}IF CompareNum("1","1", "eq") THEN Print("Both numbers are equal");TAB{}IF CompareNum("%targetLevel%","%playerLevel%", "lt") THEN Print("You are lower level than me %targetName%.");';
	p[REF]	=	{"Compare()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.CompareNum;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"ExtraActionBarVisible";
	p[DESC]	=	"Is a extra actionbar currently visible.";
	p[SIGN]	=	'ExtraActionBarVisible("OPT{Button}")';
	p[ARG]	=	{
				"INT[1;6]",	"OPT{Button}    -Optional. A number between VAL{1} and VAL{6} to check if the button is visible."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"An extra actionbar is the bar with special abilites that is shown with certain raid encounters, daily quests, mindcontrol, vehicles, tillers faction, etc.";
	p[EX]	=	'#Tillers - Uproot those weeds;TAB{}IF InZone("Sunsong Ranch") AND ExtraActionBarVisible() THEN ClickActionBar("1", "Extra");';
	p[REF]	=	{"ClickActionBar()::action"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.ExtraActionBarVisible;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Flag";
	p[DESC]	=	"Checks the value of an internal variable that has been set using SetFlag().";
	p[SIGN]	=	'Flag("REQ{Name}", "REQ{Value}", "OPT{Match}")';
	p[ARG]	=	{
				"STR[]",	"REQ{Name}   -Unique name of the variable.",
				"STR[]",	"REQ{Value}   -String value to check variable against.",
				"COMPARE[]",	"OPT{Match}   -Comparison operator. Can either be @COMPARE@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"With this function you can check the value of a variable set earlier with SetFlag().TAB{}Both 'REQ{Name}' and REQ{Value} are case-insensitive so 'Buff', 'buff', 'BUFF' and 'bUff' are all considered the same.TAB{}These internal variables are not the same as regular variables; i.e. %playerName% and so on.TAB{}All variables are reset when you save and close the edit window or type '/ifthen refresh' and reparses the rawtext.";
	p[EX]	=	'OnEvent("Slash", "happy") THEN SetFlag("Mood", "happy");TAB{}OnEvent("Slash", "angry") THEN SetFlag("Mood", "angry");TAB{}TAB{}OnEvent("Chat","Whisper","","portal", "indexof") AND Flag("Mood", "happy") THEN Reply("Here have a portal my good fellow");TAB{}OnEvent("Chat","Whisper","","portal", "indexof") AND Flag("Mood", "angry") THEN Reply("Go away!");';
	p[REF]	=	{"SetFlag()::action"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.Flag;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"HasBuff";
	p[DESC]	=	"Do you currently have the buff/debuff/aura/ability.";
	p[SIGN]	=	'HasBuff("REQ{Name}", "OPT{Unit}", "OPT{Count}", "OPT{OP}")';
	p[ARG]	=	{
				"STR[]",	"REQ{Name}     -Name of the buff/debuff/aura/ability.",
				"UNIT[]",	"OPT{Unit}        -Can be @UNIT@. If omitted it defaults to @DEFAULTUNIT@.",
				"INT[]",	"OPT{Count}     -Number of stacks of the buff/debuff/aura/ability, If omitted it will not check the stack-count.'.",
				"OP[]",		"OPT{OP}         -Comparison operator: @OP@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"This method will return true if the buff/debuff/aura/ability is found. It does not consider whether its considered harmful (debuff), helpful (buff), or otherwise.";
	p[EX]	=	'IF HasBuff("Heroism") THEN Print("[Heroism] is triggered");TAB{}OnEvent("Buff") AND HasBuff("Heroism") THEN Print("[Heroism] is triggered");';
	p[REF]	=	{"HaveCooldown()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.HasBuff;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"HaveCooldown";
	p[DESC]	=	"Does the specified item/spell have a remaining cooldown?";
	p[SIGN]	=	'HaveCooldown("REQ{ItemName}")';
	p[ARG]	=	{
				"STR[]", "REQ{ItemName}    -Name of item/spell to check for."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"HasBuff()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.HaveCooldown;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"HaveTalent";
	p[DESC]	=	"Do you currently have REQ{TalentName} enabled.";
	p[SIGN]	=	'HaveTalent("REQ{TalentName}", "OPT{PvP}")';
	p[ARG]	=	{
				"STR[]",	"REQ{TalentName}    -Name of talent (localized name).",
				"BOOL[]",	"OPT{PvP}               -Can either be @BOOL@. If omitted it defaults to 'VAL{false}'."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Requires the localized name of a talent as it's written in the talent tab like 'Momentum' (english) or 'Schwung' (german) for the monk.TAB{}Set OPT{PvP} to 'VAL{true}' if you want to check Honor talents.";
	p[EX]	=	nil;
	p[REF]	=	{"IsCurrentSpec()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.HaveTalent;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"HasHealth";
	p[DESC]	=	"Does the unit have this much health?";
	p[SIGN]	=	'HasHealth("REQ{Unit}", "REQ{Value}", "OPT{Type}", "OPT{OP}")';
	p[ARG]	=	{
				"UNIT[]",				"REQ{Unit}       -Can be one of the following: @UNIT@.",
				"INT[]",				"REQ{Value}     -Health value.",
				"STR[percent;numeric]",	"OPT{Type}      -Either 'VAL{percent}' (default) or 'VAL{numeric}'.",
				"OP[]",					"OPT{OP}         -Comparison operator: @OP@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	'IF HasHealth("target", "30", "percent", "lte") THEN Print("Target is at 30% or less!");';
	p[REF]	=	{"HasPower()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.HasHealth;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"HasName";
	p[DESC]	=	"Does REQ{Name} match the name of the unit.";
	p[SIGN]	=	'HasName("REQ{Name}", "OPT{Unit}")';
	p[ARG]	=	{
				"STR[]",	"REQ{Name}    -Name of a player.",
				"UNIT[]",	"OPT{Unit}       -Can be of the following: @UNIT@. If omitted it defaults to @DEFAULTUNIT@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.HasName;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"HaveOpenQuest";
	p[DESC]	=	"Do you have REQ{QuestName} in your questlog.";
	p[SIGN]	=	'HaveOpenQuest("REQ{QuestName}")';
	p[ARG]	=	{
				"STR[]", "REQ{QuestName}    -Name of a quest."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"IsQuestCompleted"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.HaveOpenQuest;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsQuestCompleted";
	p[DESC]	=	"Is REQ{QuestName} in your questlog completed.";
	p[SIGN]	=	'IsQuestCompleted("REQ{QuestName}")';
	p[ARG]	=	{
				"STR[]", "REQ{QuestName}    -Name of a quest."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"HaveOpenQuest"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsQuestCompleted;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"HaveCritter";
	p[DESC]	=	"Do you currently have a non-combat pet summoned.";
	p[SIGN]	=	'HaveCritter("OPT{Name}")';
	p[ARG]	=	{
				"STR[]",	"OPT{Name}    -Name of the non-combat pet. If omitted it will return true no matter what non-combat pet you have summoned."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"This function looks for your summoned non-combat pet (like Core Hound Pup). Non-Combat Pets are not the same as the pets that some classes have (like a warlock's imp).TAB{}You can use '%critterName%' in functions like Chat(), and Print() to output the non-combat pet's name.";
	p[EX]	=	nil;
	p[REF]	=	{"HavePet()", "%critterName%::variable", "HaveMount()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.HaveCritter;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"HaveMount";
	p[DESC]	=	"Do you currently have a mount summoned.";
	p[SIGN]	=	'HaveMount("OPT{Name}")';
	p[ARG]	=	{
				"STR[]",	"OPT{Name}    -Name of the mount. If omitted it will return true no matter what mount you have summoned."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"This function looks for your summoned mount (like Swift Red Gryphon).TAB{}You can use '%mountName%' in functions like Chat(), and Print() to output the mount's name.";
	p[EX]	=	nil;
	p[REF]	=	{"HavePet()", "%mountName%::variable", "HaveCritter()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.HaveMount;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"HavePet";
	p[DESC]	=	"Do you currently have a pet summoned.";
	p[SIGN]	=	'HavePet("OPT{Name}")';
	p[ARG]	=	{
				"STR[]", "OPT{Name}     -Name of the pet. If omitted it will return true no matter what pet you have summoned."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"This function looks for your summoned pets (like a warlock's imp). Pets are not the same as non-combat companions.TAB{}You can use '%petName%' in functions like Chat(), and Print() to output the pet's name.";
	p[EX]	=	'IF HavePet("MyDog") THEN Chat("Say", "Aww, hello cute doggie!");TAB{}IF HavePet() THEN Chat("Say", "Have no fear, %petName% is here to save us.");TAB{}';
	p[REF]	=	{"HaveCritter()", "%petName%::variable", "HaveMount()", "SummonPet()::action"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.HavePet;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"HasTempWeaponEnchant";
	p[DESC]	=	"Do you have a temporary enchant on a equipped weapon (like a fishing lure or wizard oil).";
	p[SIGN]	=	'HasTempWeaponEnchant("OPT{Slot}")';
	p[ARG]	=	{
				"STR[main;offhand;both}", "OPT{Slot}    -Can either be 'VAL{main}' (default), 'VAL{offhand}' or 'VAL{both}'."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Does not work for Rogue poisions.";
	p[EX]	=	nil;
	p[REF]	=	{"HasBuff()", "HaveCooldown()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.HasTempWeaponEnchant;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"HaveDurability";
	p[DESC]	=	"Do your equipped items have OPT{Status} in durability.";
	p[SIGN]	=	'HaveDurability("OPT{Status}")';
	p[ARG]	=	{
				"STR[repaired;working;low;broken]",	"OPT{Status}    -Status of equipped items: 'VAL{repaired}', 'VAL{working}', 'VAL{low}' or 'VAL{broken}'. If omitted it defaults to 'VAL{working}'."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"The method looks over your equipped items and determines what durability they have.TAB{}'VAL{repaired}' - All items are fully repaired.TAB{}'VAL{working}'  - Items are in working order.TAB{}'VAL{low}'        - One or more items are almost broken (yellow).TAB{}'VAL{broken}'   - One or more items are broken (red).";
	p[EX]	=	'If HaveDurability("broken") AND InGroup() THEN Group("My gear is broken. Anybody have a repair-bot?");';
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.HaveDurability;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"HaveAchievement";
	p[DESC]	=	"Does you or your guild have the specified achievement.";
	p[SIGN]	=	'HaveAchievement("REQ{Title}")';
	p[ARG]	=	{
				"STR[]",	"REQ{Title}   -Title of the achievement (localized)."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"REQ{Title} must be the localized name of the achievement as it's written in the achievement tab. E.g 'Accomplished Angler' (english) or 'Versierter Angler' (german).";
	p[EX]	=	nil;
	p[REF]	=	{'OnEvent("REQ{Achievement}")::event'};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.HaveAchievement;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"HaveEquipped";
	p[DESC]	=	"Do you have REQ{ItemName} equipped.";
	p[SIGN]	=	'HaveEquipped("REQ{ItemName}")';
	p[ARG]	=	{
				"STR[]", "REQ{ItemName}    -Name of an item."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"HaveItem()"}; --, "HavePVPEquipped()"
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.HaveEquipped;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"HaveItem";
	p[DESC]	=	"Do you have at least OPT{Count} number of the REQ{ItemName} in your inventory or equipped.";
	p[SIGN]	=	'HaveItem("REQ{ItemName}, "OPT{Count}", "OPT{OP}")';
	p[ARG]	=	{
				"STR[]",	"REQ{ItemName}    -Name of an item to look for.",
				"INT[]",	"OPT{Count}          -Number of items to check for. If omitted it defaults to 'VAL{1}'.",
				"OP[]",		"OPT{OP}              -Comparison operator: @OP@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"The method looks both in your inventory and at what you have equipped, but it does not check your bank.";
	p[EX]	=	nil;
	p[REF]	=	{"HaveEquipped()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.HaveItem;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"HaveLostControl";
	p[DESC]	=	"Do you currently have control of your character.";
	p[SIGN]	=	'HaveLostControl()';
	p[ARG]	=	{
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	'IF HaveLostControl() AND IsPVP() THEN Group("I am currently crowd controlled.");';
	p[REF]	=	{'OnEvent("REQ{LostControl}")::event'};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.HaveLostControl;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"HasPower";
	p[DESC]	=	"Does the unit have this much power (mana/rage/energy/etc)?";
	p[SIGN]	=	'HasPower("REQ{Unit}", "REQ{Value}", "OPT{Type}", "OPT{OP}", "OPT{PowerType}")';
	p[ARG]	=	{
				"UNIT[]",				"REQ{Unit}             -Can be one of the following: @UNIT@.",
				"INT[]",				"REQ{Value}           -Power value.",
				"STR[percent;numeric]",	"OPT{Type}            -Either 'VAL{percent}' (default) or 'VAL{numeric}'.",
				"OP[]",					"OPT{OP}               -Comparison operator: @OP@.",
				"STR[mana;rage;focus;energy;combo points;combo;runes;rune;runic power;soul shards;soul;lunar power;lunar;holy power;holy;maelstrom;chi;insanity;arcane charges;arcane;fury;pain]",				"OPT{PowerType}   -What powertype to ask for. Used with classes with several powerypes."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"OPT{PowerType} can be one of the following: 'VAL{mana}', 'VAL{rage}', 'VAL{focus}', 'VAL{energy}', 'VAL{combo points}', 'VAL{combo}', 'VAL{runes}', 'VAL{rune}', 'VAL{runic power}', 'VAL{soul shards}', 'VAL{soul}', TAB{}'VAL{lunar power}', 'VAL{lunar}', 'VAL{holy power}', 'VAL{holy}', 'VAL{maelstrom}', 'VAL{chi}', 'VAL{insanity}', 'VAL{arcane charges}', 'VAL{arcane}', 'VAL{fury}' or 'VAL{pain}'.TAB{}TAB{}If a unit has multiple powertypes (like a Rogue that has Energy and Combo points) you can use OPT{PowerType} to specify what powertype you want to look at.TAB{}If OPT{PowerType} is not specified, the function it will use the default resource for the class (for Rogues that is Energy).TAB{}Some combinations of REQ{Unit} and OPT{PowerType} will not work. Asking for the secondary powertype of a targeted unit; like Combo Points for a Rogue or Runes for a Death Knight will always return false since the game does not allow that.";
	p[EX]	=	'IF HasPower("target", "30", "percent", "lte") THEN Print("Target is at 30% or less with %targetPowerType%!");TAB{}IF HasPower("player", "5", "numeric", "eq", "combo points") THEN Print("I am now at max combo-points!!");TAB{}IF HasPower("target", "1", "numeric", "gte", "combo points") THEN Print("Targeting another Rogue and asking about combo-points does not work!!");';
	p[REF]	=	{"HasHealth()", "%targetPowerType%::variable"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.HasPower;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"HaveProfession";
	p[DESC]	=	"Do you have the specified profession.";
	p[SIGN]	=	'HaveProfession("REQ{Title}")';
	p[ARG]	=	{
				"STR[]",	"REQ{Title}   -Title of the profession (localized)."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"REQ{Title} must be the localized name of the profession as it's written in the profession tab. E.g 'First Aid' (english) or 'Erste Hilfe' (german).";
	p[EX]	=	nil;
	p[REF]	=	{"IsTradeSkillReady()", "OpenTradeSkill()::action", "Craft()::action"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.HaveProfession;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsTradeSkillReady";
	p[DESC]	=	"Is the tradeskill window open and ready for crafting.";
	p[SIGN]	=	'IsTradeSkillReady("OPT{Profession}")';
	p[ARG]	=	{
				"STR[]", "OPT{Profession}  -Name of the profession (localized)."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"If provided, OPT{Profession} must be the localized name of the profession as it's written in the tradeskill window. E.g 'First Aid' (english) or 'Erste Hilfe' (german) and so on.";
	p[EX]	=	'IF NOT IsTradeSkillReady() AND HaveItem("Simple Flour", "5", "gte") THEN OpenTradeSkill("Cooking");TAB{}IF IsTradeSkillReady("Cooking") AND HaveItem("Simple Flour", "5", "gte") THEN Craft("Spice Bread");';
	p[REF]	=	{"OpenTradeSkill()::action", "Craft()::action", "HaveProfession()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsTradeSkillReady;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InBGQueue";
	p[DESC]	=	"Are you currently in a Battleground queue.";
	p[SIGN]	=	'InBGQueue()';
	p[ARG]	=	nil;
	p[REM]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[EX]	=	nil;
	p[REF]	=	{"InLFGQueue()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InBGQueue;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InBattleGround";
	p[DESC]	=	"Are you currently in a battleground.";
	p[SIGN]	=	'InBattleGround()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"InRaid()", "InParty()", "InGroup()", "InGuildGroup()", "InInstanceGroup()", "InWargame()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InBattleGround;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InCombat";
	p[DESC]	=	"Are you currently in combat.";
	p[SIGN]	=	'InCombat()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	'OnEvent("Chat", "Whisper") AND InCombat() THEN Reply("um, i\'m sort of busy killing stuff right now... Can i call you back?");';
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InCombat;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InDigsite";
	p[DESC]	=	"Are you inside a archaeology digsite.";
	p[SIGN]	=	'InDigsite()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"This method will only return true if you have the archaeology profession and you are currently standing in a digsite.";
	p[EX]	=	'IF InDigsite() THEN Cast("Survey");';
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InDigsite;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InGroup";
	p[DESC]	=	"Are you currently in a instancegroup, battleground, party or raid.";
	p[SIGN]	=	'InGroup()';
	p[ARG]	=	nil;
	p[RET]	=	"Returns true if you are in a InstanceGroup, Raid, Party or BattleGround, and false if you are not grouped at all.";
	p[REM]	=	"This function is a merged functionality and would be the same as calling InInstanceGroup(), InBattleGround(), InParty() and InRaid().";
	p[EX]	=	nil;
	p[REF]	=	{"InRaid()", "InParty()", "InBattleGround()", "InGuildGroup()", "InInstanceGroup()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InGroup;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InGuild";
	p[DESC]	=	"Is OPT{Unit} in a guild."
	p[SIGN]	=	'InGuild("OPT{Unit}")';
	p[ARG]	=	{
				"UNIT2[]", "OPT{Unit}      -Can either be @UNIT2@. If omitted it defaults to @DEFAULTUNIT@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"InMyGuild()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InGuild;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InGuildGroup";
	p[DESC]	=	"Are you currently in a guild-party/raid or battleground.";
	p[SIGN]	=	'InGuildGroup()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"This function will return true only if have enough guildmembers in the raid, you are inside the instance and, you are in close enough range to the other guildmembers.TAB{} Party: minimum 3/5 guildmembers, 10man Raid: minimum 8/10 guildmembers, 25man Raid: minimum 20/25 guildmembers.";
	p[EX]	=	nil;
	p[REF]	=	{"InRaid()", "InParty()", "InGroup()", "InBattleGround()", "InInstanceGroup()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InGuildGroup;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InInstance";
	p[DESC]	=	"Are you inside an instance.";
	p[SIGN]	=	'InInstance("OPT{InstanceType}")';
	p[ARG]	=	{
				"STR[arena;party;pvp;raid;scenario]", "OPT{InstanceType}    -Can be one of the following: 'VAL{arena}', 'VAL{party}', 'VAL{pvp}', 'VAL{raid}', 'VAL{scenario}'."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"If OPT{InstanceType} is not specified it will return true regardless of what type of instance you are in.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InInstance;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InLFGQueue";
	p[DESC]	=	"Are you in a LFG queue.";
	p[SIGN]	=	'InLFGQueue("OPT{Type}")';
	p[ARG]	=	{
				"STR[all;df;rf;sc;pet]", "OPT{Type}    -Optional, can be one of the following: 'VAL{All}' (default), 'VAL{DF}', 'VAL{RF}', 'VAL{SC}' or 'VAL{Pet}'."
				};
	p[REM]	=	"If you specify no argument it defaults to 'VAL{All}'.TAB{}VAL{DF} - Dungeon Finder.TAB{}VAL{RF} - Raid Finder.TAB{}VAL{SC} - Scenarios.TAB{}VAL{Pet} - Pet Battles.";
	p[RET]	=	"@TRUEFALSE@";
	p[RET]	=	"@TRUEFALSE@";
	p[EX]	=	nil;
	p[REF]	=	{"InBGQueue()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InLFGQueue;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InMyBattleground";
	p[DESC]	=	"Is OPT{Unit} a member of the same battleground that you are."
	p[SIGN]	=	'InMyBattleground("OPT{Unit}")';
	p[ARG]	=	{
				"UNIT3[]", "OPT{Unit}      -Can either be @UNIT3@. If omitted it defaults to @DEFAULTUNIT3@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"If you are not in a battleground then the function will return false.";
	p[EX]	=	nil;
	p[REF]	=	{"InMyGroup()", "InMyParty()", "InMyRaid()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InMyBattleground;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InMyGroup";
	p[DESC]	=	"Is OPT{Unit} a member of the same group that you are."
	p[SIGN]	=	'InMyGroup("OPT{Unit}")';
	p[ARG]	=	{
				"UNIT3[]", "OPT{Unit}      -Can either be @UNIT3@. If omitted it defaults to @DEFAULTUNIT3@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"This function is a merged functionality and would be the same as calling InMyBattleGround(), InMyParty() and InMyRaid()";
	p[EX]	=	nil;
	p[REF]	=	{"InMyBattleGround()", "InMyParty()", "InMyRaid()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InMyGroup;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InMyGuild";
	p[DESC]	=	"Is OPT{Unit} a member of the same guild that you are."
	p[SIGN]	=	'InMyGuild("OPT{Unit}")';
	p[ARG]	=	{
				"UNIT3[]", "OPT{Unit}      -Can either be @UNIT3@. If omitted it defaults to @DEFAULTUNIT3@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"If you are not in a guild then the function will return false.";
	p[EX]	=	nil;
	p[REF]	=	{"InMyGroup()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InMyGuild;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InMyParty";
	p[DESC]	=	"Is OPT{Unit} a member of the same party that you are."
	p[SIGN]	=	'InMyParty("OPT{Unit}")';
	p[ARG]	=	{
				"UNIT3[]", "OPT{Unit}      -Can either be @UNIT3@. If omitted it defaults to @DEFAULTUNIT3@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"If you are not in a party then the function will return false.";
	p[EX]	=	nil;
	p[REF]	=	{"InMyBattleGround()", "InMyGroup()", "InMyRaid()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InMyParty;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InMyRaid";
	p[DESC]	=	"Is OPT{Unit} a member of the same raid that you are."
	p[SIGN]	=	'InMyRaid("OPT{Unit}")';
	p[ARG]	=	{
				"UNIT3[]", "OPT{Unit}      -Can either be @UNIT3@. If omitted it defaults to @DEFAULTUNIT3@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"If you are not in a raid then the function will return false.";
	p[EX]	=	nil;
	p[REF]	=	{"InMyBattleGround()", "InMyGroup()", "InMyParty()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InMyRaid;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------


-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InInstanceGroup";
	p[DESC]	=	"Are you currently in a instance group.";
	p[SIGN]	=	'InInstanceGroup()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Instance groups are groups created when using LFR or queueing for battlegrounds. You use /instance or /i to chat in them.";
	p[EX]	=	nil;
	p[REF]	=	{"InRaid()", "InBattleGround()", "InGroup()", "InGuildGroup()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InInstanceGroup;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InParty";
	p[DESC]	=	"Are you currently in a party.";
	p[SIGN]	=	'InParty()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"This function will return false if you are in an instance group. Use InInstanceGroup() for that.";
	p[EX]	=	nil;
	p[REF]	=	{"InRaid()", "InBattleGround()", "InGroup()", "InGuildGroup()", "InInstanceGroup()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InParty;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InPetBattle";
	p[DESC]	=	"Are you currently in a pet battle.";
	p[SIGN]	=	'InPetBattle()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	'OnEvent("Chat", "Whisper") AND InPetBattle() THEN Reply("um, i\'m sort of busy in a pet battle... Can i call you back?");';
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InPetBattle;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InRaid";
	p[DESC]	=	"Are you currently in a raid.";
	p[SIGN]	=	'InRaid()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"InBattleGround()", "InParty()", "InGroup()", "InGuildGroup()", "InInstanceGroup()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InRaid;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InRange";
	p[DESC]	=	"Are you in range of the target to use the item/spell.";
	p[SIGN]	=	'InRange("REQ{Name}", "OPT{Unit}")';
	p[ARG]	=	{
				"STR[]",	"REQ{Name}     -Name of spell or item to use on target.",
				"UNIT[]",	"OPT{Unit}        -Can be one of the following: @UNIT@. If omitted it defaults to @DEFAULTUNIT3@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"This method will only return true if REQ{Unit} is within the range that the spell/item can be used on it.TAB{}Note that the function will return false if the item/spell can't do anything on the target; i.e. 'Fireball' on a target that is dead will return false even though the target might be in range.";
	p[EX]	=	'IF InRange("Fireball", "target") THEN Print("This will not work if the target is dead");';
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InRange;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"QuestItemInRange";
	p[DESC]	=	"Is the item associated with OPT{QuestName} within range to be used.";
	p[SIGN]	=	'QuestItemInRange("OPT{QuestName}")';
	p[ARG]	=	{
				"STR[]", "OPT{QuestName}    -Optional. Name of quest in your questlog. If omitted it will pick from the list of tracked quests."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"A 'questitem' is the item that is sometimes given when you accept a quest.TAB{}If you do not specify a OPT{QuestName} then the function will look for the first quest with a questitem associated with it in your list of tracked quests and use that.TAB{}Note that the function only checks if the item is in range and that not all questitems requires a set range to work. It can return true even if the item/spell can't do anything on the target. TAB{}I.e. If the quest is to skin 'Prowling Panthers' and you are in range and targeting a panther that is not dead yet, it will still return true.";
	p[EX]	=	'#Try to use the questitem of one of the quest currently tracked -Useful while leveling;TAB{}IF QuestItemInRange("") THEN UseQuestItem("");TAB{}#Using questname for a specific quest;TAB{}IF HaveOpenQuest("Hue") AND QuestItemInRange("Hue")THEN UseQuestItem("Hue");';
	p[REF]	=	{"UseQuestItem()", "InRange()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.QuestItemInRange;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InStance";
	p[DESC]	=	"Are you currently using the specified stance, form or aura.";
	p[SIGN]	=	'InStance("REQ{Stance}")';
	p[ARG]	=	{
				"STR[]", "REQ{Stance}    -The name of the stance/form/aura that you want to check for. This argument requires a localized string."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"You can use 'VAL{none}' to check if you are not in a stance.TAB{}You must write the exact, localized name of the stance: 'Bear Form' (english client), 'Bärengestalt' (german client) and so on.";
	p[EX]	=	nil;
	p[REF]	=	{"InWorgenForm()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InStance;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InWorgenForm";
	p[DESC]	=	"Are you currently using the worgen form or not.";
	p[SIGN]	=	'InWorgenForm("OPT{Unit}")';
	p[ARG]	=	{
				"UNIT2[]", "OPT{Unit}      -Can either be @UNIT2@. If omitted it defaults to @DEFAULTUNIT@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Will return true if OPT{Unit} is a worgen (race), and OPT{Unit's} appearance is currently that of a worgen.";
	p[EX]	=	nil;
	p[REF]	=	{"InStance()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InWorgenForm;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InWargame";
	p[DESC]	=	"Are you currently in a wargame.";
	p[SIGN]	=	'InWargame()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"InRaid()", "InParty()", "InGroup()", "InGuildGroup()", "InInstanceGroup()", "InBattleGround()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InWargame;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InZone";
	p[DESC]	=	"Are you in a specific zone.";
	p[SIGN]	=	'InZone("REQ{ZoneName}")';
	p[ARG]	=	{
				"STR[]", "REQ{ZoneName}    -Name of a zone."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"The function will check REQ{ZoneName} against both the name of the immediate area (e.g. 'Old Town') and the name of the wider zone (e.g. 'Stormwind City') that you are currently in. If either matches, it will return true.";
	p[EX]	=	nil;
	p[REF]	=	{"%zoneName%::variable", "%areaName%::variable"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.InZone;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsAFK";
	p[DESC]	=	"Is the player Away-From-Keyboard?.";
	p[SIGN]	=	'IsAFK("OPT{Unit}")';
	p[ARG]	=	{
				"UNIT2[]", "OPT{Unit}    -Can be of the following: @UNIT2@. If omitted it defaults to @DEFAULTUNIT@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"IsDND()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsAFK;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsAssistant";
	p[DESC]	=	"Is OPT{Unit} an assistant in the player's raid."
	p[SIGN]	=	'IsAssistant("OPT{Unit}")';
	p[ARG]	=	{
				"UNIT2[]", "OPT{Unit}    -Can be of the following: @UNIT2@. If omitted it defaults to @DEFAULTUNIT@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"The function checks if OPT{Unit} is an assistant in the raid that you are currently in.TAB{}If you are not in a raid or OPT{Unit} is not in your raid, then it will return false.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsAssistant;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsAddOnLoaded";
	p[DESC]	=	"Checks if REQ{Name} matches that of any addons currently loaded."
	p[SIGN]	=	'IsAddOnLoaded("REQ{Name}")';
	p[ARG]	=	{
				"STR[]", "REQ{Name}    -Foldername or Title of an addon."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"First, it will compare REQ{Name} against the addons foldername as found in the 'Interface\\AddOns\\' folder.TAB{}Secondly it will compare REQ{Name} with the 'Title' tag specified in the .TOC file for each addon.TAB{}The function ignores any color-strings used in titles.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsAddOnLoaded;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsBoss";
	p[DESC]	=	"Are you targeting a boss."
	p[SIGN]	=	'IsBoss("OPT{Unit}")';
	p[ARG]	=	{
				"UNIT3[]", "OPT{Unit}    -Can either be @UNIT3@. If omitted it defaults to @DEFAULTUNIT3@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"This function will not always work. This is because there is no single way to determine whether your target is a boss or not.TAB{}Especially in low level instances like the Stormwind Stockade, (Hogger) the function can return false.TAB{}Also note that scenarios do not have bosses.TAB{}The function will try the following tactics:TAB{}    -Is the unit an NPC? (other players are ignored)TAB{}    -Is the unit classified as a worldboss?TAB{}    -Is the unit's name found in the encounter journal?TAB{}    -Is the unit's level -1 (bosslevel)?TAB{}    -If you are currently in combat and inside an instance; Does the unit's name match with what's returned by 'boss1', 'boss2' etc unitstrings.TAB{}    -If the addon 'Deadly Boss Mods' (DBM) or 'Voice Encounter Mods' (VEM) is installed and enabled it will attempt to use it's list of bosses to determine if you are targeting a boss.";
	p[EX]	=	'OnEvent("Slash", "AnnouncePull") AND IsBoss("target") THEN Chat("Say", "Pulling the boss %TargetName% in 30 seconds...") AND DBMPull("30");';
	p[REF]	=	{"%BossName%::variable", "IsClassified()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsBoss;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsChanneling";
	p[DESC]	=	"Are you currently casting/channeling.";
	p[SIGN]	=	'IsChanneling("OPT{SpellName}", "OPT{Unit}")';
	p[ARG]	=	{
				"STR[]", "OPT{SpellName}    -Name of spell. If OPT{SpellName} is not provided, it will return true if you are currently casting or channeling something.",
				"UNIT2[]","OPT{Unit}             -Can be of the following: @UNIT2@. If omitted it defaults to @DEFAULTUNIT@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsChanneling;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsClass";
	p[DESC]	=	"Does REQ{Class} match the class of the unit.";
	p[SIGN]	=	'IsClass("REQ{Class}", "OPT{Unit}")';
	p[ARG]	=	{
				"STR[deathknight;demonhunter;druid;hunter;mage;monk;paladin;priest;rogue;shaman;warlock;warrior]",	"REQ{Class}    -Name of a class: 'VAL{deathknight}', 'VAL{demonhunter}', 'VAL{druid}', 'VAL{hunter}', 'VAL{mage}', 'VAL{monk}', 'VAL{paladin}', 'VAL{priest}', 'VAL{rogue}', 'VAL{shaman}', 'VAL{warlock}' or 'VAL{warrior}'.",
				"UNIT[]",	"OPT{Unit}      -Can be of the following: @UNIT@. If omitted it defaults to @DEFAULTUNIT@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsClass;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsClassified";
	p[DESC]	=	"Does OPT{Type} match the classification of the unit.";
	p[SIGN]	=	'IsClassified("OPT{Type}", "OPT{Unit}")';
	p[ARG]	=	{
				"STR[worldboss;rareelite;elite;rare;normal;trivial;minus]", "OPT{Type}    -Name of classification: 'VAL{worldboss}', 'VAL{rareelite}', 'VAL{elite}' (default), 'VAL{rare}', 'VAL{normal}', 'VAL{trivial}' or 'VAL{minus}'.",
				"UNIT3[]","OPT{Unit}     -Can be of the following: @UNIT3@. If omitted it defaults to @DEFAULTUNIT3@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Most types are self-explanatory. 'VAL{minus}' means a minion of another NPC. They do not give experience or reputation.TAB{}Note: many npc's are not classified as one should expect. Onyxia inside the Onyxia's Lair have for example the classification 'worldboss'.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsClassified;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	--FIX (Renamed IsCurrentTalentSpec to IsCurrentSpec)
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsCurrentSpec";
	p[DESC]	=	"Is your currently enabled specialization the same as REQ{Name}.";
	p[SIGN]	=	'IsCurrentSpec("REQ{Name}")';
	p[ARG]	=	{
				"STR[]", "REQ{Name}    -Localized name of the specialization."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Requires the localized name of a spec as it's written in the specialization tab.";
	p[EX]	=	'If IsClass("Mage") AND IsCurrentSpec("Fire") THEN Cast("Fireball");';
	p[REF]	=	{"HaveTalent()", "EnableSpec()::action", "%talentSpec%::variable"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsCurrentSpec;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	--[[REMOVED
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsCurrentTalentTree";
	p[DESC]	=	"Is the main talent tree of your current talent spec the same as REQ{Index}.";
	p[SIGN]	=	'IsCurrentTalentTree("REQ{Index}")';
	p[ARG]	=	{
				"INT[1;4]", "REQ{Index}    -Can either be 'VAL{1}', 'VAL{2}', 'VAL{3}' or 'VAL{4}' (4th is Druid only)."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"IsCurrentSpec()", "HaveTalent()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsCurrentTalentTree;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------]]

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsDND";
	p[DESC]	=	"Is OPT{Unit} flagged as Do-Not-Disturb.";
	p[SIGN]	=	'IsDND("OPT{Unit}")';
	p[ARG]	=	{
				"UNIT2[]", "OPT{Unit}    -Can be of the following: @UNIT2@. If omitted it defaults to @DEFAULTUNIT@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"IsAFK()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsDND;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsDead";
	p[DESC]	=	"Is OPT{Unit} dead.";
	p[SIGN]	=	'IsDead("OPT{Unit}")';
	p[ARG]	=	{
				"UNIT[]", "OPT{Unit}    -Can be of the following: @UNIT@. If omitted it defaults to @DEFAULTUNIT@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsDead;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsFalling";
	p[DESC]	=	"Are you falling.";
	p[SIGN]	=	'IsFalling()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Will return true if you are currently falling.";
	p[EX]	=	nil;
	p[REF]	=	{"IsFlying()", "IsSwimming()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsFalling;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsFlyableArea";
	p[DESC]	=	"Are you currently in an area where flying is possible.";
	p[SIGN]	=	'IsFlyableArea()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Even though the function can return true. You as a player might not be able to fly in the area. That is dependent on your flying skill ability.";
	p[EX]	=	nil;
	p[REF]	=	{"IsFlying()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsFlyableArea;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsFlying";
	p[DESC]	=	"Are you flying."
	p[SIGN]	=	'IsFlying()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Will return true if you are currently in the air.";
	p[EX]	=	nil;
	p[REF]	=	{"IsFlyableArea()", "IsMounted()", "IsSwimming()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsFlying;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsFocused";
	p[DESC]	=	"Will return true if the current focus has the name OPT{Player}.";
	p[SIGN]	=	'IsFocused("OPT{Player}")';
	p[ARG]	=	{
				"STR[]", "OPT{Player}    -Name of the focused player/npc."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"If OPT{Player} is omitted, then it will return true as long as the player has something selected with /focus.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsFocused;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsHostile";
	p[DESC]	=	"Is your current target hostile towards you.";
	p[SIGN]	=	'IsHostile("OPT{Unit}")';
	p[ARG]	=	{
				"UNIT3[]", "OPT{Unit}      -Can either be @UNIT3@. If omitted it defaults to @DEFAULTUNIT3@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsHostile;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsIndoors";
	p[DESC]	=	"Is the player indoors.";
	p[SIGN]	=	'IsIndoors()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"The function will return true if the game considers the area you are currently standing in as 'indoors'.TAB{}In many cases you don't actually have to be inside an building for it to return true.TAB{}Many instances for example can have outdoor areas, but will still be considered 'indoor' by the game.";
	p[EX]	=	'IF IsIndoors() THEN Print("Can not use mounts when indoors");';
	p[REF]	=	{"IsSwimming()", "IsFlying()", "IsFlyableArea()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsIndoors;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsLeader";
	p[DESC]	=	"Is OPT{Unit} the leader of your instancegroup/raid/party.";
	p[SIGN]	=	'IsLeader("OPT{Unit}")';
	p[ARG]	=	{
				"UNIT2[]", "OPT{Unit}     -Can be of the following: @UNIT2@. If omitted it defaults to @DEFAULTUNIT@.",
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"IsAssistant()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsLeader;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsMarked";
	p[DESC]	=	"Is OPT{Unit} dead.";
	p[SIGN]	=	'IsMarked("OPT{Unit}", "OPT{Mark}")';
	p[ARG]	=	{
				"UNIT[]", "OPT{Unit}     -Can be of the following: @UNIT@. If omitted it defaults to @DEFAULTUNIT@.",
				"MARK[]", "OPT{Mark}    -Can be of the following: @MARK@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"If OPT{Mark} is not specified, then the function will return true no matter what mark the unit has on.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsMarked;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsModifierKeyDown";
	p[DESC]	=	"Is a modifier key currently held down on the keyboard.";
	p[SIGN]	=	'IsModifierKeyDown("OPT{Key}")';
	p[ARG]	=	{
				"STR[alt;control;shift]", "OPT{Key}     -Optional, can be of the following: 'VAL{Alt}', 'VAL{Control}' or 'VAL{Shift}'."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"If OPT{Key} is not specified, then the function will return true no matter what modifier key (Alt/Control/Shift) is pressed down.TAB{}Note: if you have the Shift-feature of IfThen enabled (VAL{/ifthen shift}) then that will take presedence before IF-statements.";
	p[EX]	=	'#This will not work if the Shift feature (/ifthen shift) is also enabled;TAB{}IF IsModifierKeyDown("Shift") AND IsDead("target") THEN Cast("Mass Resurrection");';
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsModifierKeyDown;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsMounted";
	p[DESC]	=	"Are you riding a summoned mount.";
	p[SIGN]	=	'IsMounted()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"IsFlying()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsMounted;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsMuted";
	p[DESC]	=	"Is the sound muted.";
	p[SIGN]	=	'IsMuted("OPT{Type}")';
	p[ARG]	=	{
				"STR[all;effects;music]", "OPT{Type}    -Can be one of the following: 'VAL{all}' (default), 'VAL{effects}' or 'VAL{music}'."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"StopAllSound()::action", "SetSound()::action", "PlayAudio()::action"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsMuted;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsPVP";
	p[DESC]	=	"Is OPT{Unit} PVP flagged.";
	p[SIGN]	=	'IsPVP("OPT{Unit}")';
	p[ARG]	=	{
				"UNIT2[]", "OPT{Unit}    -Can be of the following: @UNIT2@. If omitted it defaults to @DEFAULTUNIT@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"%PVPTimer%::variable"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsPVP;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsSaved";
	p[DESC]	=	"Are you currently saved to the named instance.";
	p[SIGN]	=	'IsSaved("REQ{Instance}")';
	p[ARG]	=	{
				"STR[]", "REQ{Instance}    -The name of the instance."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsSaved;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsStealthed";
	p[DESC]	=	"Are you stealthed.";
	p[SIGN]	=	'IsStealthed()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Will return true if you are stealthed. Note that 'Stealth' (what Rogues and Druids can do) is not the same as 'Invisibility' (what Mages can do and certain flasks etc).";
	p[EX]	=	nil;
	p[REF]	=	{"IsFlying()", "IsSwimming()", "IsFalling()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsStealthed;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsSwimming";
	p[DESC]	=	"Are you swimming.";
	p[SIGN]	=	'IsSwimming()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Will return true if you are in water and swimming. Simply standing in water will return false.";
	p[EX]	=	nil;
	p[REF]	=	{"IsFlying()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsSwimming;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsTapped";
	p[DESC]	=	"Is OPT{Unit} tapped by the player, the player's group or faction.";
	p[SIGN]	=	'IsTapped("OPT{Unit}")';
	p[ARG]	=	{
				"UNIT3[]", "OPT{Unit}      -Can either be @UNIT3@. If omitted it defaults to @DEFAULTUNIT3@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Normally, credit for killing a unit and loot is available only to the player, the player's group or faction (horde/alliance) who first damaged it.";
	p[EX]	=	'IF InCombat() AND IsTapped("target") THEN Print("This kill is ours.");';
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsTapped;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"IsTargeted";
	p[DESC]	=	"Will return true if the current target is OPT{Name}.";
	p[SIGN]	=	'IsTargeted("OPT{Name}", "OPT{Match}")';
	p[ARG]	=	{
				"STR[]", "OPT{Name}    -Name of the targeted player/npc.",
				"COMPARE[]",	"OPT{Match}    -Comparison operator. Can either be @COMPARE@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"If OPT{Name} is omitted, then it will return true whatever you have targeted.";
	p[EX]	=	'#Print a message if i got something targeted. Dont care what it is;TAB{}IF IsTargeted() THEN Print("I have something targeted");TAB{}#If i have a plant on my Tillers farm targeted that has a name that starts with "Infested" then use the bugspray on it;TAB{}IF InZone("Sunsong Ranch") AND IsTargeted("Infested", "StartsWith") THEN UseItem("Vintage Bug Sprayer");';
	p[REF]	=	{"MouseOver()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.IsTargeted;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"MouseOver";
	p[DESC]	=	"Will return true if your mousecursor is currently hovering over OPT{Name}.";
	p[SIGN]	=	'MouseOver("OPT{Name}", "OPT{Match}")';
	p[ARG]	=	{
				"STR[]", "OPT{Name}    -Name of the npc/player/item that the mousecursor is over.",
				"COMPARE[]",	"OPT{Match}    -Comparison operator. Can either be @COMPARE@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"If OPT{Name} is omitted, then it will return true whatever you have under your mousecursor.TAB{}If you are hovering over a npc/player then it will lookup that players name only (title is excluded).TAB{}For all other cases if will check the first line in the tooltip displayed.TAB{}Note: if you have other addons installed that modify the first line of tooltips then the function might not work as intended.";
	p[EX]	=	'#Print a message if im mousing over a mailbox;TAB{}IF MouseOver("Mailbox") THEN Print("I am standing close to a %MouseOverName%");TAB{}#If i have a plant on my Tillers farm that has a name that starts with "Infested" then use the bugspray on it;TAB{}IF InZone("Sunsong Ranch") AND MouseOver("Infested", "StartsWith") THEN UseItem("Vintage Bug Sprayer");';
	p[REF]	=	{"IsTargeted()", "%MouseOverName%::variable"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.MouseOver;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerHasMoved";
	p[DESC]	=	"Has your player character moved since the last time the function was called.";
	p[SIGN]	=	'PlayerHasMoved("OPT{Match}")';
	p[ARG]	=	{
				"STR[both;position;facing]",	"OPT{Match}    -Can be one of the following: 'VAL{position}', 'VAL{facing}' or 'VAL{both}'. If omitted it defaults to 'VAL{both}'."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"If OPT{Match} is 'VAL{position}' then the function will only look at the player's X- and Y-coordinates.TAB{}If OPT{Match} is 'VAL{facing}' then the function will only check the player's facing, and not it's coordinates. Note that 'VAL{facing}' is the direction the player character is facing, not the position of the camera.TAB{}Blizzard has restricted the use of coordinates since patch 7.1. This function might not work as expected when in instances.";
	p[EX]	=	'IF NOT PlayerHasMoved() THEN Print("You have not moved since last time.");';
	p[REF]	=	{"InZone()", "%PlayerCoordinates%::variable", "%PlayerLocation%::variable"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.PlayerHasMoved;
	d[strlower(AR..p[NAME])] = p;
	-- --------------------------------------------






	-- Actions Macro-------------------------------
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Cast";
	p[DESC]	=	"Will /cast the named spell.";
	p[SIGN]	=	'Cast("REQ{SpellName}")';
	p[ARG]	=	{
				"STR[]", "REQ{SpellName}    -Spell you want to cast."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"Note: Due to restrictions in the game, only one spell can be cast per button click, and this function can not be used with OnEvent()";
	p[EX]	=	nil;
	p[REF]	=	{"UseItem()", "UseQuestItem()", "RawMacro()", "Craft()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Cast;
	d[strlower(AM..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"UseItem";
	p[DESC]	=	"Will /use the named item.";
	p[SIGN]	=	'UseItem("REQ{ItemName}")';
	p[ARG]	=	{
				"STR[]", "REQ{ItemName}    -Item you want to use."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"Note: Due to restrictions in the game, only one item can be used per button click, and this function can not be used with OnEvent()";
	p[EX]	=	nil;
	p[REF]	=	{"UseQuestItem()", "Cast()", "RawMacro()", "Craft()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_UseItem;
	d[strlower(AM..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"OpenTradeSkill";
	p[DESC]	=	"Will open the tradeskill window for a given profession.";
	p[SIGN]	=	'OpenTradeSkill("REQ{Profession}")';
	p[ARG]	=	{
				"STR[]", "REQ{Profession}  -Name of the profession (localized)."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"REQ{Profession} must be the localized name of the profession as it's written in the tradeskill window. E.g 'First Aid' (english) or 'Erste Hilfe' (german) and so on.";
	p[EX]	=	'IF NOT IsTradeSkillReady() AND HaveItem("Simple Flour", "5", "gte") THEN OpenTradeSkill("Cooking");TAB{}IF IsTradeSkillReady("Cooking") AND HaveItem("Simple Flour", "5", "gte") THEN Craft("Spice Bread");';
	p[REF]	=	{"IsTradeSkillReady()::argument", "Craft()", "HaveProfession()::argument", "CloseTradeSkill()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OpenTradeSkill;
	d[strlower(AM..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"CloseTradeSkill";
	p[DESC]	=	"Will close the currently open tradeskill window.";
	p[SIGN]	=	'CloseTradeSkill()';
	p[ARG]	=	{
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"IsTradeSkillReady()::argument", "Craft()", "HaveProfession()::argument", "OpenTradeSkill()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_CloseTradeSkill;
	d[strlower(AM..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Craft";
	p[DESC]	=	"Will craft a recipe.";
	p[SIGN]	=	'Craft("REQ{Recipe}")'; --", OPT{Repeat}"
	p[ARG]	=	{
				"STR[]", "REQ{Recipe}  -Name of the recipe you want to craft (localized)."
				--"INT[1-10000]", "OPT{Repeat}       -Number of repeats of the recipe you want to craft. If omitted it defaults to 'VAL{1}'."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Can only be called when the TradeSkill window is open.TAB{}REQ{Recipe} must be the localized name of the recipe as it's written in the tradeskill window. E.g 'Spice Bread' (english) or 'Gewürzbrot' (german) and so on.TAB{}TAB{}Note: This function will only craft a single item per call due to inconsistent behavior from the Blizzard API.";
	p[EX]	=	'IF NOT IsTradeSkillReady() AND HaveItem("Simple Flour", "5", "gte") THEN OpenTradeSkill("Cooking");TAB{}IF IsTradeSkillReady("Cooking") AND HaveItem("Simple Flour", "5", "gte") THEN Craft("Spice Bread");';
	p[REF]	=	{"IsTradeSkillReady()::argument", "HaveProfession()::argument", "OpenTradeSkill()", "CloseTradeSkill()", "UseItem()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Craft;
	d[strlower(AM..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"ClickActionBar";
	p[DESC]	=	"Will /click the button on the specified actionbar.";
	p[SIGN]	=	'ClickActionBar("REQ{Button}", "OPT{Toolbar}")';
	p[ARG]	=	{
				"INT[1;12]",	"REQ{Button}    -A number between VAL{1} and VAL{12}.",
				"STR[main;extra;pet;right;right2;bottomleft;bottomright;stance]", "OPT{Toolbar}   -Optional. Is either 'VAL{Main}' (default), 'VAL{Extra}', 'VAL{Pet}', 'VAL{Right}', 'VAL{Right2}', 'VAL{BottomLeft}', 'VAL{BottomRight} or 'VAL{Stance}' to specify which actionbar."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"Note: Due to restrictions in the game, only one /click can be done per button click, and this function can not be used with OnEvent()";
	p[EX]	=	'#Tillers - Uproot those weeds;TAB{}IF InZone("Sunsong Ranch") AND ExtraActionBarVisible() THEN ClickActionBar("1", "Extra");TAB{}#Click the 5th button on my main toolbar if im dead;TAB{}IF IsDead() THEN ClickActionBar("5");TAB{}#If my warlock has one of his pets out then click the 1st button on the petbar;TAB{}IF IsClass("Warlock") AND HavePet() THEN ClickActionBar("1", "Pet");TAB{}#Switch to Cat form when on my druid;TAB{}IF IsClass("Druid") AND NOT InCombat() THEN ClickActionBar("2", "Stance");';
	p[REF]	=	{"ExtraActionBarVisible()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_ClickActionBar;
	d[strlower(AM..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"UseQuestItem";
	p[DESC]	=	"Will /use the item associated with a quest in your questlog.";
	p[SIGN]	=	'UseQuestItem("OPT{QuestName}")';
	p[ARG]	=	{
				"STR[]", "OPT{QuestName}    -Optional. Name of quest in your questlog. If omitted it will pick from the list of tracked quests."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"A 'questitem' is the item that is sometimes given when you accept a quest. Not all quests give questitems at start, and in those cases the function will still return true but print an error.TAB{}If you do not specify a OPT{QuestName} then the function will look for the first quest with a questitem associated with it in your list of tracked quests and use that.TAB{}The function is intended as a shortcut and you can use UseItem() to do the same thing.TAB{}Note: Due to restrictions in the game, only one item can be used per button click, and this function can not be used with OnEvent()";
	p[EX]	=	'IF InZone("Garm\'s Bane") AND HaveOpenQuest("Overstock") THEN UseQuestItem("Overstock");TAB{}#If i remember the name of the questitem then i can type that directly. UseQuestItem() is just a shortcut;TAB{}IF InZone("Garm\'s Bane") AND HaveOpenQuest("Overstock") THEN UseItem("Improved Land Mines");';
	p[REF]	=	{"UseItem()", "Cast()", "QuestItemInRange()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_UseQuestItem;
	d[strlower(AM..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"CancelForm";
	p[DESC]	=	"Will cancel your current shapeshift form (/cancelform).";
	p[SIGN]	=	'CancelForm()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUE@";
	p[REM]	=	"You can also use Cast() and CancelAura() to switch in/out of forms.TAB{}Note: Due to restrictions in the game, only one /cancelform can be used per button click, and this function can not be used with OnEvent().";
	p[EX]	=	'IF IsClass("Druid") AND InStance("Cat Form") THEN CancelForm();TAB{}#Alternative with Cast() and CancelAura();TAB{}IF IsClass("Druid") AND NOT InStance("Cat Form") THEN Cast("Cat Form");TAB{}IF IsClass("Druid") AND InStance("Cat Form") THEN CancelAura("Cat Form");';
	p[REF]	=	{"CancelAura()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_CancelForm;
	d[strlower(AM..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"RawMacro";
	p[DESC]	=	"Output REQ{Text} directly into the currently running IfThen-Macro.";
	p[SIGN]	=	'RawMacro("REQ{Text}", "OPT{MacroName}")';
	p[ARG]	=	{
				"STR[]", "REQ{Text}              -Text you want to put in the macro.",
				"STR[]", "OPT{MacroName}   -Optional. Name of the macro to write to. If omitted it will write to the currently executing IfThen-Macro.",
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"Allows you to output REQ{Text} directly into the currently executing IfThen-Macro.TAB{}Normal Macro-logic applies (i.e. the macro stops at the first successful /use, /cast and so on).TAB{}A newline will be added before any / (slash). Use '\\/' to escape a slash if you need to.TAB{}A macro is limited to maximum 255 characters, anything more will be truncated.TAB{}Note: Due to restrictions in the game, the macro can not be changed once you have entered combat, and this function can not be used with OnEvent().TAB{}If you are using OPT{MacroName} then it will not be executed until you actually press that button on your toolbar.";
	p[EX]	=	'#Remeber to add "/run IFT()" when modifying the default macro as the first line or else the macro wont trigger IfThen to re-evaluate it the next time its executed;TAB{}IF IsClass("Mage") AND NOT InCombat() THEN RawMacro("/run IFT() /target Hogger /dance /cast Arcane Power /use Mana Gem /cast Arcane Blast /say Text with slash\\/inside it");TAB{}TAB{}#When MacroName is specified it will not modify the macro icon. You can however use #showtooltip to change it;TAB{}OnEvent("PVP") AND IsPVP() AND NOT InCombat() THEN Print("Pvp flagged - rewriting macros") AND RawMacro("/cast Vanish", "MacroA") AND RawMacro("#showtooltip backstab /yell Kill the healers", "MacroB");TAB{}OnEvent("PVP") NOT IsPVP() AND NOT InCombat() THEN Print("Back to normal") AND RawMacro("/cast Sap", "MacroA") AND RawMacro("#showtooltip backstab /cast backstab", "MacroB");';
	p[REF]	=	{"UseItem()", "Cast()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_RawMacro;
	d[strlower(AM..p[NAME])] = p;
	-- --------------------------------------------






	-- Actions ------------------------------------
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"AcceptDuel";
	p[DESC]	=	"Accepts the requested duel.";
	p[SIGN]	=	'AcceptDuel()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUE@";
	p[REM]	=	nil;
	p[EX]	=	'#Will only accept duels when you are in Goldshire;TAB{}OnEvent("DuelStart") AND InZone("GoldShire") THEN AcceptDuel() AND Reply("Bring it on %replyName%!!");';
	p[REF]	=	{"DeclineDuel()", 'OnEvent("REQ{DuelStart}")::event', 'OnEvent("REQ{DuelEnd}")::event'};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_AcceptDuel;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"AcceptGroup";
	p[DESC]	=	"Accepts the invitation to a party or raid.";
	p[SIGN]	=	'AcceptGroup()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"DeclineGroup()", 'OnEvent("REQ{GroupInvite}")::event'};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_AcceptGroup;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"AutoSetRoles";
	p[DESC]	=	"Will try to automatically set all the group-member's roles based on their class.";
	p[SIGN]	=	'AutoSetRoles()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"This function will fail if you are not the leader of the group or an assistant.TAB{}The function iterates through all the members of the group and will determine based on their class what role they should be ('VAL{tank}', 'VAL{healer}' or 'VAL{dps}').TAB{}Some classes can fill multiple roles and in those cases the function will not set a role.TAB{} If a player already has a role set, then the function will not override that role.";
	p[EX]	=	'#Will auto set roles as soon as possible for all my group-members;TAB{}OnEvent("GroupChanges") AND IsLeader() THEN AutoSetRoles();';
	p[REF]	=	{"SetRole()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_AutoSetRoles;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"CancelAura";
	p[DESC]	=	"Will cancel the named aura/buff.";
	p[SIGN]	=	'CancelAura("REQ{BuffName}")';
	p[ARG]	=	{
				"STR[]", "REQ{BuffName}    -Name of the buff you want to cancel."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"This function does not use the macro like UseItem() or Cast() does and it is possible to execute it from an Event. However it will not work when you are in combat.";
	p[EX]	=	'OnEvent("Casted", "Levitate", "group") AND NOT InCombat() THEN Group("Ey! I dont like levitate!") AND CancelAura("Levitate");';
	p[REF]	=	{"CancelForm()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_CancelAura;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Cooldown";
	p[DESC]	=	"Will prevent further statements on a line being processed until REQ{Seconds} has passed.";
	p[SIGN]	=	'Cooldown("REQ{Seconds}", "OPT{Title}")';
	p[ARG]	=	{
				"SECOND[]", "REQ{Seconds}    -Number of seconds to wait. @SECOND@.",
				"STR[]",	"OPT{Title}          -Optional title to use if you need to share a cooldown between multiple lines."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"The function will set an internal marker (line and statement reference) and return true on the first call. All subsequent calls will return false until the cooldown has expired.TAB{}The OPT{Title} field should only be used if you have a need for a cooldown that needs to be shared between mutiple lines.TAB{}All Cooldowns are reset when you save and close the edit window or type '/ifthen refresh' and reparses the rawtext.";
	p[EX]	=	'#The "Tick" event is triggered once a second, but Cooldown() will stop further processing of the line\'s statements until after 10 seconds;TAB{}OnEvent("Tick") AND Cooldown("10") THEN Print("Will print this text every 10 seconds.");TAB{}#Regardless of which one of these two that is triggered first, the second one will not trigger inside the 60 second cooldown since they both use the same title (Hero_Warp);TAB{}OnEvent("Casted","Heroism") THEN Cooldown("60", "Hero_Warp") AND Print("Heroism/Time warp casted!");TAB{}OnEvent("Casted","Time Warp") THEN Cooldown("60", "Hero_Warp")  AND Print("Heroism/Time warp casted!");';
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Cooldown_TABLE;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Countdown";
	p[DESC]	=	"Will output a countdown in the given channel starting at REQ{Seconds}.";
	p[SIGN]	=	'Countdown("REQ{Channel}", "REQ{Seconds}", "OPT{Message}")';
	p[ARG]	=	{
				"STR[]",	"REQ{Channel}    -@CHATCHANNEL@",
				"SECOND[]",	"REQ{Seconds}    -Number of seconds. @SECOND@.",
				"STR[]",	"OPT{Message}    -Text to display at the start of the countdown."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"The countdown will stop at 1.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Countdown;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"DBMPull";
	p[DESC]	=	"Startes a DBM pull timer.";
	p[SIGN]	=	'DBMPull("REQ{Seconds}"")';
	p[ARG]	=	{
				"SECOND[]",	"REQ{Seconds}    -Number of seconds. @SECOND@."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"You must be the raidleader or assistant to initiate a pull-timer.TAB{}Will return false and print an error message if 'Deadly Boss Mods' (DBM) is not installed and enabled.";
	p[EX]	=	nil;
	p[REF]	=	{"DBMTimer()", "SetTimer()", "Countdown()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_DBMPull;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	--[[p = self:CreateOnDocStruct();
	--REMOVED: Patch 7.1: Blizzard removed use of player coordinate functions inside instances.
	p[NAME]	=	"DBMRange";
	p[DESC]	=	"Shows/Hides the DBM range-radar.";
	p[SIGN]	=	'DBMRange("REQ{Range}","OPT{Show}")';
	p[ARG]	=	{
				"INT[]",	"REQ{Range}   -A numerical range value for the radar.",
				"BOOL[]",	"OPT{Show}    -Show or hide the radar (@BOOL@). If omitted it will be toggled on/off."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Will return false and print an error message if 'Deadly Boss Mods' (DBM) is not installed and enabled.";
	p[EX]	=	nil;
	p[REF]	=	{"DBMTimer()", "DBMPull()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_DBMRange;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------]]
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"DBMTimer";
	p[DESC]	=	"Startes a DBM timer. ";
	p[SIGN]	=	'DBMTimer("REQ{Title}","REQ{Seconds}","OPT{Broadcast}")';
	p[ARG]	=	{
				"STR[]",	"REQ{Title}          -A title for the timer.",
				"SECOND[]",	"REQ{Seconds}    -Number of seconds. @SECOND@.",
				"BOOL[]",	"OPT{Broadcast}  -Broadcast the timer to the rest of your raid. Values: @BOOL@ (default)."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Will return false and print an error message if 'Deadly Boss Mods' (DBM) is not installed and enabled.";
	p[EX]	=	nil;
	p[REF]	=	{"SetTimer()", "Countdown()", "DBMPull()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_DBMTimer;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"DeclineDuel";
	p[DESC]	=	"Declines the requested duel.";
	p[SIGN]	=	'DeclineDuel()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"AcceptDuel()", 'OnEvent("REQ{DuelStart}")::event', 'OnEvent("REQ{DuelEnd}")::event'};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_DeclineDuel;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"DeclineGroup";
	p[DESC]	=	"Declines the invitation to a party or raid.";
	p[SIGN]	=	'DeclineGroup()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"AcceptGroup()", 'OnEvent("REQ{GroupInvite}")::event'};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_DeclineGroup;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Dismount";
	p[DESC]	=	"Dismounts from your summoned mount.";
	p[SIGN]	=	'Dismount()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"IsMounted()::argument", "HaveMount()::argument", "SummonMount()", "%MountName%::variable"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Dismount;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"SummonMount";
	p[DESC]	=	"Will summon a mount.";
	p[SIGN]	=	'SummonMount("OPT{Name}")';
	p[ARG]	=	{
				"STR[]", "OPT{Name}     -Localized name of the mount. Use 'VAL{random}' or empty string to summon a random favorite mount."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Will not work when you are in combat.";
	p[EX]	=	'OnEvent("Slash", "randomMount") THEN SummonMount();';
	p[REF]	=	{"IsMounted()::argument", "HaveMount()::argument", "Dismount()", "%MountName%::variable"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_SummonMount;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

		-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"SummonPet";
	p[DESC]	=	"Will summon a pet.";
	p[SIGN]	=	'SummonPet("OPT{Name}")';
	p[ARG]	=	{
				"STR[]", "OPT{Name}     -Localized name of the pet. Use 'VAL{random}' or empty string to summon a random favorite pet."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Will not work when you are in combat.";
	p[EX]	=	nil;
	p[REF]	=	{"HavePet()::argument", "%PetName%::variable"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_SummonPet;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------



	-- --------------------------------------------
	local strDataFormat, strDisplayFormat = self:GetEmoteTokenList(100); --GetEmoteTokenList() returns 2 formatted strings with a list of all the EmoteToken strings. It is set to NIL in CleanUp()
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Emote";
	p[DESC]	=	"You character will do the emote specified in REQ{Token}.";
	p[SIGN]	=	'Emote("REQ{Token}, OPT{Unit}")';
	p[ARG]	=	{
				"STR["..strDataFormat.."]", "REQ{Token}    -A token for a specific emote.",
				"UNIT[player;target]", "OPT{Unit}      -Can either be 'VAL{player}' or 'VAL{target}'. If omitted it defaults to @DEFAULTUNIT@."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"If you for OPT{Unit} specify 'VAL{target}' and you have no target, then it will play the event for you yourself.TAB{}Some emotes have animations and sounds (like 'VAL{Train}').TAB{}If you want to do chat emotes; i.e. /me or /emote then use the Chat() function with 'emote' specified as the channel.TAB{}TAB{}The complete list of REQ{Tokens} that are possible is listed below:TAB{}TAB{}"..strDisplayFormat;
	p[EX]	=	'OnEvent("Casted", "Vanish") AND IsTargeted() THEN Emote("Chicken", "target");';
	p[REF]	=	{"Chat()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Emote;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EnableEquipmentSet";
	p[DESC]	=	"Equips a equipment-set.";
	p[SIGN]	=	'EnableEquipmentSet("REQ{Name}")';
	p[ARG]	=	{
				"STR[]", "REQ{Name}    -Case-sensitive name of an equipment set."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"%EnabledEquipmentSet%::variable"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_EnableEquipmentSet;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EnableSpec";
	p[DESC]	=	"Changes the players specialization.";
	p[SIGN]	=	'EnableSpec("REQ{Name}")';
	p[ARG]	=	{
				"STR[]", "REQ{Name}    -Localized name of specialization."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"Requires the localized name of a spec as it's written in the specialization tab.TAB{}Note: If you use this function it will not ask about gold-cost before changing the specialization.";
	p[EX]	=	nil;
	p[REF]	=	{"IsCurrentSpec()::argument", "%talentSpec%::variable"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_EnableSpec;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipItem";
	p[DESC]	=	"Will equip an item.";
	p[SIGN]	=	'EquipItem("REQ{ItemName}")';
	p[ARG]	=	{
				"STR[]", "REQ{ItemName}  -Name of item to equip."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"HaveItem()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_EquipItem;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Group";
	p[DESC]	=	"Sends a message to either /instance, /party or /raid depending on what you are currently grouped in.";
	p[SIGN]	=	'Group("REQ{Message}")';
	p[ARG]	=	{
				"STR[]", "REQ{Message}    -Message to send."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"Chat()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Group_TABLE;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Guild";
	p[DESC]	=	"Sends a message to /guild.";
	p[SIGN]	=	'Guild("REQ{Message}")';
	p[ARG]	=	{
				"STR[]", "REQ{Message}    -Message to send."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"This is just a shortcut and is the same as using Chat('Guild', 'Message');";
	p[EX]	=	nil;
	p[REF]	=	{"Chat()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Guild;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"MarkTarget";
	p[DESC]	=	"Put a mark on your current target.";
	p[SIGN]	=	'MarkTarget("REQ{Mark}", "OPT{Unit}")';
	p[ARG]	=	{
				"MARK[]", "REQ{Mark}    -Can  be one of the following: @MARK@.",
				"UNIT[]", "OPT{Unit}     -Can be @UNIT@. If omitted it defaults to 'VAL{target}'."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"This function will always return true but if do not have the rights to assign marks, then it will have no visible effect.TAB{}I.e. you are in a raid but you're not the raidleader or an assistant.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_MarkTarget;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Message";
	p[DESC]	=	"Displays a messagebox with a message in it. This message is only visible to yourself.";
	p[SIGN]	=	'Message("REQ{Message}")';
	p[ARG]	=	{
				"STR[]", "REQ{Message}    -Message to display."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"Print()", "RaidMessage()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Message;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Officer";
	p[DESC]	=	"Sends a message to /officer.";
	p[SIGN]	=	'Officer("REQ{Message}")';
	p[ARG]	=	{
				"STR[]", "REQ{Message}    -Message to send."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"This is just a shortcut and is the same as using Chat('Officer', 'Message');";
	p[EX]	=	nil;
	p[REF]	=	{"Chat()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Officer;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	local strDisplayFormat = self:GetPlayAudioList(100); --GetPlayAudioList() returns a formatted string with a list of all the shorthand aliases. It is set to NIL in CleanUp()
	p[NAME]	=	"PlayAudio";
	p[DESC]	=	"Plays a sound effect";
	p[SIGN]	=	'PlayAudio("REQ{Audio}")';
	p[ARG]	=	{
				"STR[]", "REQ{Audio}    -Full path to a audiofile or a shorthand alias."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"This sound is only audible to yourself. The function uses the master channel and will be audible even when you have muted the game.TAB{}The function also supports using a full path to the audiofile. You can use various CASC file-viewer software to open and browse the game's resource files.TAB{}TAB{}A list of short-hand aliases available is listed below. Click on a link to play it's audio:TAB{}TAB{}"..strDisplayFormat;
	p[EX]	=	'#Play a sound on readycheck when i am muted;TAB{}OnEvent("ReadyCheck") AND IsMuted() THEN PlayAudio("ReadyCheck");TAB{}#Play a sound if someone sends me a whisper;TAB{}OnEvent("Chat", "Whisper") AND Cooldown("10") THEN PlayAudio("UI_BnetToast");TAB{}TAB{}#Example with full path to a audio file;TAB{}OnEvent("Slash", "PowerOfTheHorde") THEN PlayAudio("Sound\\Music\\ZoneMusic\\DMF_L70ETC01.mp3");';
	p[REF]	=	{"StopAllSound()", "SetSound()", "IsMuted()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_PlayAudio;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"StopAllSound";
	p[DESC]	=	"Stops all playing sound files/effects.";
	p[SIGN]	=	'StopAllSound()';
	p[ARG]	=	nil
	p[RET]	=	"@TRUE@";
	p[REM]	=	"Instantly stops all currently playing music, enviromental or sound effects. TAB{}The game will continue to play sounds after the function is called. This is not the same a muting the game.";
	p[EX]	=	nil;
	p[REF]	=	{"IsMuted()::argument", "PlayAudio()", "SetSound()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_StopAllSound;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Print";
	p[DESC]	=	"Prints a message in the default chatframe. This message is only visible to yourself.";
	p[SIGN]	=	'Print("REQ{Message}", "OPT{Color}")';
	p[ARG]	=	{
				"STR[]",	"REQ{Message}    -Message to display.",
				"COLOR[]",	"OPT{Color}         -What color to use. If omitted it will use '@DEFAULTCOLOR@'."
				};
	p[RET]	=	"@TRUE@";
	--p[REM]	=	"Available colors are: @COLOR@.";
	p[REM]	=	"Available colors are:TAB{}    @COLOR1@,TAB{}    @COLOR2@,TAB{}    @COLOR3@.";
	p[EX]	=	nil;
	p[REF]	=	{"Message()", "RaidMessage()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Print;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"RaidMessage";
	p[DESC]	=	"Displays a raid message. This message is only visible to yourself.";
	p[SIGN]	=	'RaidMessage("REQ{Message}", "OPT{Color}")';
	p[ARG]	=	{
				"STR[]",	"REQ{Message}    -Message to display.",
				"COLOR[]",	"OPT{Color}         -What color to use. If omitted it will use '@DEFAULTCOLOR@'."
				};
	p[RET]	=	"@TRUE@";
	--p[REM]	=	"Uses the default UI's raidmessage container, the size and duration of the message depends on it's settings.TAB{}Available colors are: @COLOR@.";
	p[REM]	=	"Uses the default UI's raidmessage container, the size and duration of the message depends on it's settings.TAB{}Available colors are:TAB{}    @COLOR1@,TAB{}    @COLOR2@,TAB{}    @COLOR3@.";
	p[EX]	=	nil;
	p[REF]	=	{"Print()", "Message()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_RaidMessage;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Reply";
	p[DESC]	=	"Sends a message as a reply to the last incoming event/whisper/chat.";
	p[SIGN]	=	'Reply("REQ{Message}")';
	p[ARG]	=	{
				"STR[]", "REQ{Message}    -Message to send."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"This method is used in combination with various event's that allow us to capture the name of the player that initiated it. Like OnEvent(\"REQ{Chat}\").TAB{}Wherever Reply() is possible, then '%replyName%' is also available to be used in strings as a placeholder for that players name.TAB{}The only exception to this is when using '%replyName%' as a response to Battle.Net whisper/chat. The Reply() function itself will then work, but not '%replyName%'.";
	p[EX]	=	'OnEvent("GroupInvite") THEN Reply("Thanks for the invite.");TAB{}OnEvent("ReadyCheck") THEN Group("%replyName% just started a readycheck.");';
	p[REF]	=	{"Chat()", "Whisper()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Reply_TABLE;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Report";
	p[DESC]	=	"Outputs a message about the given item, spell, faction, currency or equipmentset.";
	p[SIGN]	=	'Report("REQ{Channel}", "REQ{Type}", "REQ{Name}", "OPT{Unit}")';
	p[ARG]	=	{
				"STR[]",																		"REQ{Channel}     -Can be one of the following: @REPORTCHANNEL@",
				"STR[item;cooldown;buff;reputation;experience;currency;itemlevel;savedinstance;statistic]",	"REQ{Type}          -Can be one of the following: 'VAL{item}', 'VAL{cooldown}', 'VAL{buff}', 'VAL{reputation}', 'VAL{experience}', 'VAL{currency}', 'VAL{itemlevel}', 'VAL{savedinstance}', or 'VAL{statistic}'.",
				"STR[]",																		"REQ{Name}        -The name of the spell/item/faction/currency/equipmentset/statistic-title that is asked about.",
				"UNIT[]",																		"OPT{Unit}           -Can be @UNIT@. If omitted it defaults to @DEFAULTUNIT@."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"Will output a message to the specified channel about the given item, spell, faction, currency or equipmentset.TAB{} If REQ{Type} is 'VAL{experience}' then REQ{Name} is ignored.TAB{} If REQ{Type} is 'VAL{item}', 'VAL{cooldown}', 'VAL{reputation}', 'VAL{experience}', 'VAL{currency}' or 'VAL{statistic}' then OPT{Unit} is ignored and it will always report the players own stats.TAB{} If REQ{Type} is 'VAL{itemlevel}' then REQ{Name} should be 'VAL{equipped}' to report itemlevel of currently worn items or the name of a equipmentset (case-sensitive). If OPT{Unit} is provided then only 'VAL{player}' and 'VAL{target}' will work.TAB{} If REQ{Type} is 'VAL{savedinstance}' then REQ{Name} should be 'VAL{all}', 'VAL{party}', 'VAL{raid}' or 'VAL{world}' to output a list of saved instances. Note that 'VAL{world}' only works for content before Warlords of Draenor.TAB{}TAB{}This function outputs it's reports in English, if you wish to format your own reports, then look at using the %Report% variables.";
	p[EX]	=	'OnEvent("Slash","saved") THEN Report("Print","savedinstance","raid") AND Report("Print","savedinstance","party");TAB{}#Will report the statistic with the name "Creatures killed";TAB{}OnEvent("Slash", "stats") THEN Report("Print", "statistic", "creatures killed");TAB{}TAB{}#Will output the itemlevel for our currently equipped items using print;TAB{}OnEvent("Slash", "level") THEN Report("Print", "itemlevel", "", "player");TAB{}#Will output the itemlevel the equipmentset named "MyPVPSet" (case-sensitive);TAB{}OnEvent("Slash", "pvplevel") THEN Report("Print", "itemlevel", "MyPVPSet", "player");TAB{}#Will output the itemlevel for your current target using print;TAB{}OnEvent("Slash", "targetlevel") THEN Report("Print", "itemlevel", "", "target");TAB{}#Will output the number of stacks of "Mana Gem" in inventory;TAB{}OnEvent("Slash", "managem") THEN Report("Print", "item", "mana gem");TAB{}#Will output the reputation level of the player with the Stormwind faction;TAB{}OnEvent("Slash", "rep") THEN Report("Print", "reputation", "Stormwind");';
	p[REF]	=	{"%Report1%::variable", "%Report2%::variable", "%Report3%::variable"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Report;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Roll";
	p[DESC]	=	"Will output a /roll message in chat.";
	p[SIGN]	=	'Roll("OPT{Min}", "OPT{Max}")';
	p[ARG]	=	{
				"INT[0;1000000]", "OPT{Min}     -Number between VAL{0} and VAL{1 000 000}.",
				"INT[0;1000000]", "OPT{Max}    -Number between VAL{0} and VAL{1 000 000}. Must be higher than OPT{Min}."
				};
	p[RET]	=	"@TRUEFALSE@";
	--p[REM]	=	"This function will initate a server-side roll. The server will then return a random number. The output will be same as using /roll in the chat window.";
	p[REM]	=	"Initiates a public, server-side 'dice roll' (the same as /roll).TAB{}When called, the server generates a random integer and sends it to the player and all others nearby (or in the same party/raid) via the chat system.TAB{}If no arguments are provided it will use 1-100 as range.";
	p[EX]	=	'OnEvent("Slash", "roll") THEN Roll();TAB{}OnEvent("Slash", "raidroll") AND InGroup() THEN Group("Doing a raid roll: 1-%GroupCount%...") AND Roll("1", "%GroupCount%");';
	p[REF]	=	{"%RaidRollName%::variable", "Random()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Roll_TABLE;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Random";
	p[DESC]	=	"Will generate a random number that can be retrieved by using %Random%.";
	p[SIGN]	=	'Random("OPT{Min}", "OPT{Max}")';
	p[ARG]	=	{
				"INT[0;1000000]", "OPT{Min}     -Number between VAL{0} and VAL{1 000 000}.",
				"INT[0;1000000]", "OPT{Max}    -Number between VAL{0} and VAL{1 000 000}. Must be higher than OPT{Min}."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"The function will generate a random number that can be retrieved using the variable %Random%.TAB{}The numbers generated are integers and include the min-max values themselves.TAB{}If no arguments are provided it will use 1-100 as a range.";
	p[EX]	=	'OnEvent("Slash", "hello") THEN Random("1", "4") AND Print("Will trigger in %Random% seconds") AND SetTimer("hello","%Random%");TAB{}OnEvent("Timer", "hello") THEN Print("hello world");';
	p[REF]	=	{"%RaidRollName%::variable", "%Random%::variable", "Roll()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Random_TABLE;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"RandomChat";
	p[DESC]	=	"Randomly selects a message and sends it to a chat-channel.";
	p[SIGN]	=	'RandomChat("REQ{Channel}", "REQ{MessageList}")';
	p[ARG]	=	{
				"STR[]", "REQ{Channel}         -Can one of the following: @CHATCHANNEL@",
				"STR[]", "REQ{MessageList}   -List of message(s) to send. Separated using \\; (escaped semicolon)."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"Use escaped semicolon (\\;) inside REQ{MessageList} to separate the multiple messages from each other. The function will randomly pick one of the messages.";
	p[EX]	=	'OnEvent("Slash", "hello") AND InGroup() THEN RandomChat("Group", "Hello \\; Howdy \\; How are you \\; Hi");';
	p[REF]	=	{"Chat()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_RandomChat_TABLE;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Screenshot";
	p[DESC]	=	"Takes a screenshot.";
	p[SIGN]	=	'Screenshot("OPT{Hide}")';
	p[ARG]	=	{
				"BOOL[]",	"OPT{Hide}   -Can either be 'VAL{true}' (default) or 'VAL{false}' to automatically hide the user interface while taking the screenshot."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Screenshot;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"SetFlag";
	p[DESC]	=	"Sets the value of an internal variable. Use the Flag() function to check the value of the variable.";
	p[SIGN]	=	'SetFlag("REQ{Name}", "REQ{Value}")';
	p[ARG]	=	{
				"STR[]",	"REQ{Name}   -Unique name of the variable.",
				"STR[]",	"REQ{Value}   -String value to set variable to."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"With this function you can set a variable to a specified value. You can then use Flag() to later check this variable's value.TAB{}Both 'REQ{Name}' and REQ{Value} are case-insensitive so 'Buff', 'buff', 'BUFF' and 'bUff'' are all considered the same.TAB{}These internal variables are not the same as regular variables; i.e. %playerName% and so on.TAB{}All variables are reset when you save and close the edit window or type '/ifthen refresh' and reparses the rawtext.";
	p[EX]	=	'OnEvent("Slash", "happy") THEN SetFlag("Mood", "happy");TAB{}OnEvent("Slash", "angry") THEN SetFlag("Mood", "angry");TAB{}TAB{}OnEvent("Chat","Whisper","","portal", "indexof") AND Flag("Mood", "happy") THEN Reply("Here have a portal my good fellow");TAB{}OnEvent("Chat","Whisper","","portal", "indexof") AND Flag("Mood", "angry") THEN Reply("Go away!");';
	p[REF]	=	{"Flag()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_SetFlag;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"SetRole";
	p[DESC]	=	"Changes the players group role.";
	p[SIGN]	=	'SetRole("REQ{Type}")';
	p[ARG]	=	{
				"STR[tank;healer;dps;none]", "REQ{Type}    -Can either be 'VAL{tank}', 'VAL{healer}', 'VAL{dps}' or 'VAL{none}'."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	nil;
	p[EX]	=	'OnEvent("RoleCheck","","true") AND IsClass("Druid") AND IsCurrentSpec("Restoration") THEN SetRole("Healer") AND Print("Rolecheck done, set to Healer automatically since i got Restoration spec enabled");TAB{}OnEvent("RoleCheck","","true") AND IsClass("mage") THEN SetRole("DPS") AND Print("Rolecheck done, set to DPS automatically");';
	p[REF]	=	{"AutoSetRoles()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_SetRole;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"SetSound";
	p[DESC]	=	"Enable/Disable sound or music ingame.";
	p[SIGN]	=	'SetSound("OPT{Type}", "OPT{Enable}")';
	p[ARG]	=	{
				"STR[all;effects;music]", "OPT{Type}     -Can either be 'VAL{all}' (default), 'VAL{effects}', or 'VAL{music}'.",
				"STR[toggle;true;false]", "OPT{Enable}  -Can either be 'VAL{toggle}' (default), 'VAL{enable}', or 'VAL{disable}'."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"Note that the 'VAL{all}' option will turn off all sounds. This value supersedes the 'VAL{effects}' and 'VAL{music}' values.TAB{}I.e if all sounds are disabled you will still not hear anything if you later enable just the music.";
	p[EX]	=	'OnEvent("Zoning") AND InZone("Lunarfall") THEN Print("Turning on music" THEN SetSound("music", "true");';
	p[REF]	=	{"StopAllSound()", "IsMuted()::argument", "PlayAudio()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_SetSound;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"SetTimer";
	p[DESC]	=	"Startes a timer that will after REQ{Seconds} trigger the related OnEvent('Timer') event.";
	p[SIGN]	=	'SetTimer("REQ{Name}", "REQ{Seconds}", "OPT{Type}")';
	p[ARG]	=	{
				"STR[]",					"REQ{Name}        -Unique name of the timer.",
				"SECOND[]",					"REQ{Seconds}    -Number of seconds the timer will last. @SECOND@.",
				"STR[ignore;overwrite]",	"OPT{Type}         -Can either be 'VAL{ignore}' (default) or 'VAL{overwrite}'."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"Will return false if REQ{Seconds} is not a number and if the value is above/below maxvalues.TAB{} The value of OPT{Type} determines what the function will do if its told to create a new timer with the same name; Shall it VAL{overwrite} it, effectively resetting the timer or shall it VAL{ignore} creating a new timer until the existing one has run out.";
	p[EX]	=	'#Will create a 10 second timer called MySpecialTimer that will be reset every time someone does /ifs mytimer;TAB{}OnEvent("Slash", "mytimer") THEN SetTimer("MySpecialTimer", "10", "overwrite");TAB{}#Creates a timer that will run for 40 seconds;TAB{}OnEvent("Buff") AND HasBuff("Heroism") THEN SetTimer("HeroTimer", "40", "ignore");';
	p[REF]	=	{'OnEvent("REQ{Timer}")::event', "Cooldown()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_SetTimer;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"SetTitle";
	p[DESC]	=	"Changes the players title.";
	p[SIGN]	=	'SetTitle("OPT{Name}")';
	p[ARG]	=	{
				"STR[]", "OPT{Name}    -The localized name of the title. Use 'VAL{none}' or empty string for no title."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerTitle%::variable"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_SetTitle;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"StopWatchPause";
	p[DESC]	=	"Pauses the Stopwatch.";
	p[SIGN]	=	'StopWatchPause()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"StopWatchStop()", "StopWatchResume()", "StopWatchStart()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_StopWatchPause;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"StopWatchResume";
	p[DESC]	=	"Resumes the Stopwatch.";
	p[SIGN]	=	'StopWatchResume()';
	p[ARG]	=	nil;
	p[RET]	=	"@TRUE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"StopWatchStop()", "StopWatchPause()", "StopWatchStart()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_StopWatchResume;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"StopWatchStart";
	p[DESC]	=	"Starts the Stopwatch that will count down until 0.";
	p[SIGN]	=	'StopWatchStart("REQ{Hour}", "REQ{Minute}", "REQ{Second}", "OPT{Hide}")';
	p[ARG]	=	{
				"HOUR[]",		"REQ{Hour}        -@HOUR@.",
				"MINUTE[]",		"REQ{Minute}     -@MINUTE@.",
				"MINUTE[]",		"REQ{Second}    -@MINUTE@.", --SECOND[] goes between 1 and 600 so we use MINUTE[]
				"BOOL[]",		"OPT{Hide}        -Can either be 'VAL{true}' (default) or 'VAL{false}' to automatically hide the stopwatch dialog after it has completed."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"The position of the Stopwatch window on screen is not managed by this function. You can move it wherever you want.";
	p[REM]	=	"The position of the StopWatch window on screen is not managed by this function. You can move it wherever you want.";
	p[EX]	=	'OnEvent("Slash", "pizza") THEN Print("Starting a 15 minute pizza timer...") AND StopWatchStart("0","15","0");';
	p[REF]	=	{"StopWatchStop()", "StopWatchPause()", "StopWatchResume()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_StopWatchStart_TABLE;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"StopWatchStop";
	p[DESC]	=	"Starts the Stopwatch.";
	p[SIGN]	=	'StopWatchStop("OPT{Hide}")';
	p[ARG]	=	{
				"BOOL[]",		"OPT{Hide}      -Can either be 'VAL{true}' (default) or 'VAL{false}' to automatically hide the stopwatch dialog after it has been stopped."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"StopWatchStart()", "StopWatchPause()", "StopWatchResume()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_StopWatchStop_TABLE;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Chat";
	p[DESC]	=	"Sends a message to a chat-channel.";
	p[SIGN]	=	'Chat("REQ{Channel}", "REQ{Message}")';
	p[ARG]	=	{
				"STR[]", "REQ{Channel}    -Can be one of the following: @CHATCHANNEL@",
				"STR[]", "REQ{Message}   -Message to send."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	"Use 'VAL{1}' for General chat. 'VAL{2}' for Trade channel. 'VAL{3}' for LocalDefense and 'VAL{4}' for the LookingForGroup channel.TAB{}Each message can be a maximum of 255 characters long.TAB{}Also take into account that hyperlinks contains several characters that are not visible i.e. |cFFD4A017[MyLink]|r is much longer than the 6 characters you see.TAB{}Public channels also have a flood limit.";
	p[EX]	=	nil;
	p[REF]	=	{"Group()","Guild()","Officer()","Print()","Whisper()","RandomChat()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Chat_TABLE;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"ToggleRaidDisplay";
	p[DESC]	=	"Toggles the list of raid groups that is shown.";
	p[SIGN]	=	'ToggleRaidDisplay("REQ{Type}")';
	p[ARG]	=	{
				"STR[hide;show]",	"REQ{Type}    -Can either be 'VAL{hide}' or 'VAL{show}'."
				};
	p[RET]	=	"@TRUEFALSE@";
	p[REM]	=	"This function will not work when you are in combat.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_ToggleRaidDisplay;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Whisper";
	p[DESC]	=	"Whispers a message to a player.";
	p[SIGN]	=	'Whisper("REQ{Player}", "REQ{Message}")';
	p[ARG]	=	{
				"STR[]",	"REQ{Player}       -Name of a player ('name-server' format can also be used). Also supports the following: 'VAL{leader}', @UNIT2@.",
				"STR[]",	"REQ{Message}   -Message to send."
				};
	p[RET]	=	"@TRUE@";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"Chat()"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_Whisper_TABLE;
	d[strlower(AC..p[NAME])] = p;
	-- --------------------------------------------






	-- Functions ----------------------------------
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"OnEvent";
	p[DESC]	=	"";--Instead of IF you can start a statement with OnEvent() and that statement will then be evaluated when the game triggers that event.
	p[SIGN]	=	'';--OnEvent("REQ{EventName}",OPT{Filters...})
	p[ARG]	=	nil;
	p[RET]	=	"";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	1; --In Parsing.lua we check the max/min values in the against the specific event.
	p[MAX]	=	100;
	p[PTR]	=	cache_EmptyEvent;	--function(n) return Methods:do_OnEvent;
	d[strlower(FU..p[NAME])] = p;	--This function is stored with the prefix 'func_' so that it wont be visible for the user in morehelp
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"MacroStart";
	p[DESC]	=	"";
	p[SIGN]	=	'';
	p[ARG]	=	nil;
	p[RET]	=	"";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	1;
	p[MAX]	=	1;
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(FU..p[NAME])] = p;	--This function is stored with the prefix 'func_' so that it wont be visible for the user in morehelp
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"MacroEnd";
	p[DESC]	=	"";
	p[SIGN]	=	'';
	p[ARG]	=	nil;
	p[RET]	=	"";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	1;
	p[MAX]	=	1;
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(FU..p[NAME])] = p;	--This function is stored with the prefix 'func_' so that it wont be visible for the user in morehelp
	-- --------------------------------------------





	-- Events -------------------------------------
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Achievement";
	p[DESC]	=	"Triggered when you earn an achievement.";
	p[SIGN]	=	'OnEvent("REQ{Achievement}", "OPT{Title}", "OPT{Match}")';
	p[ARG]	=	{
				"STR[]",	"REQ{Achievement}",
				"STR[]",	"OPT{Title}     -Title of the achievement earned (localized).",
				"COMPARE[]","OPT{Match}   -Comparison operator. Can either be @COMPARE@."
				};
	p[RET]	=	"ACHIEVEMENT_EARNED";
	p[REM]	=	"OPT{Title} must be the localized name of the achievement as it's written in the achievement tab. E.g. 'Accomplished Angler' (english) or 'Versierter Angler' (german).";
	p[EX]	=	'OnEvent("Achievement") THEN Screenshot();';
	p[REF]	=	{"HaveAchievement()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_ACHIEVEMENT_EARNED;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"AfkOrDnd";
	p[DESC]	=	"Triggered when your status changes to/from AFK or DND.";
	p[SIGN]	=	'OnEvent("REQ{AfkOrDnd}")';
	p[ARG]	=	{
				"STR[]", "REQ{AfkOrDnd}"
				};
	p[RET]	=	"IFTHEN_AFKORDND";
	p[REM]	=	"This event is triggered when the player's status changes. This is can be done manually by using the /afk and /dnd commands.TAB{}It will also be automatically set by the game after approximately 5 minutes.";
	p[EX]	=	'OnEvent("AfkOrDnd") AND IsAFK("player") THEN Print("Ey, wake up!");TAB{}OnEvent("AfkOrDnd") AND NOT IsAFK("player") THEN Print("I am back again");';
	p[REF]	=	{"IsAFK()::argument", "IsDnd()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_IFTHEN_AFKORDND; --PLAYER_FLAGS_CHANGED
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PVP";
	p[DESC]	=	"Triggered when your pvp-flag changes.";
	p[SIGN]	=	'OnEvent("REQ{PVP}")';
	p[ARG]	=	{
				"STR[]", "REQ{PVP}"
				};
	p[RET]	=	"IFTHEN_PVP";
	p[REM]	=	nil;
	p[EX]	=	'OnEvent("PVP") AND NOT IsPVP("player") THEN Print("I am no longer pvp-flagged");';
	p[REF]	=	{"IsPVP()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_IFTHEN_PVP;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"BattlegroundInvite";
	p[DESC]	=	"Triggered when you receive an invitation to enter a battleground (like Alterac Valey).";
	p[SIGN]	=	'OnEvent("REQ{BattlegroundInvite}")';
	p[ARG]	=	{
				"STR[]", "REQ{BattlegroundInvite}"
				};
	p[RET]	=	"IFTHEN_BATTLEFIELD_SHOW"; --Dynamically setup as a background event
	p[REM]	=	"This event will not trigger on invites for world pvp events like Wintergrasp and Tol Barad.";
	p[EX]	=	nil;
	p[REF]	=	{'OnEvent("REQ{WorldPVPInvite}")'};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Buff";
	p[DESC]	=	"Triggered when you gain/lose a buff/debuff.";
	p[SIGN]	=	'OnEvent("REQ{Buff}", "OPT{Unit}")';
	p[ARG]	=	{
				"STR[]",	"REQ{Buff}",
				"UNIT[]",	"OPT{Unit}    -Can be @UNIT@. If omitted it defaults to @DEFAULTUNIT@."
				};
	p[RET]	=	"UNIT_AURA";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"HasBuff()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_UNIT_AURA;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Casted";
	p[DESC]	=	"Triggered when a spell has been sucessfully casted or at the start of channeled-spells.";
	p[SIGN]	=	'OnEvent("REQ{Casted}", "OPT{SpellName}", "OPT{Unit}")';
	p[ARG]	=	{
				"STR[]",	"REQ{Casted}",
				"STR[]",	"OPT{SpellName}    -Name of the spell casted.",
				"UNIT4[]",	"OPT{Unit}             -Can be @UNIT4@. If omitted it defaults to @DEFAULTUNIT@."
				--"UNIT4[]",	"OPT{Unit}             -Can be 'VAL{group}', @UNIT@. If omitted it will not apply any filter and any party/raid member or whomever that is currently targeted or focused on can trigger the event."
				--"STR[]",	"OPT{Unit}             -Can be a player name, 'VAL{raidN}', 'VAL{partyN}' or @UNIT@. If omitted it defaults to @DEFAULTUNIT@."
				};
	p[RET]	=	"UNIT_SPELLCAST_SUCCEEDED";
	p[REM]	=	"This event is triggered at the start of channeled spells, and at the end of a sucessfully casted (non-channeling) spell.TAB{}For channeled spells it might trigger multiple times while the spell is being channeled.TAB{}TAB{}If you specify 'VAL{group}' then anyone in your party/raid can trigger the event.TAB{}@REPLY@";
	p[EX]	=	'TAB{}OnEvent("Casted", "Heroism", "group") THEN Group("%replyName% just casted Heroism");TAB{}OnEvent("Casted","Focus Magic","player") AND NOT HasBuff("Focus Magic", "target") THEN Whisper("target","[Focus Magic] casted on you.");TAB{}TAB{}#Casted is triggered once per tick for the channeled blizzard spell so i use a cooldown to prevent spamming the chat;TAB{}OnEvent("Casted", "Blizzard") AND Cooldown("8") THEN Group("Casting [Blizzard]");TAB{}#Evocate is a channeled spell too, but does not trigger the event multiple times so i don\'t need a cooldown;TAB{}OnEvent("Casted", "Evocation") AND THEN Group("Casting [Evocation]");';
	p[REF]	=	{'OnEvent("REQ{Casting}")', "HasBuff()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_UNIT_SPELLCAST_SUCCEEDED;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Casting";
	p[DESC]	=	"Triggered when a non-channeled spell is started to be cast.";
	p[SIGN]	=	'OnEvent("REQ{Casting}", "OPT{SpellName}", "OPT{Unit}")';
	p[ARG]	=	{
				"STR[]",	"REQ{Casting}",
				"STR[]",	"OPT{SpellName}    -Name of the spell casted.",
				"UNIT4[]",	"OPT{Unit}             -Can be @UNIT4@. If omitted it defaults to @DEFAULTUNIT@."
				};
	p[RET]	=	"UNIT_SPELLCAST_START";
	p[REM]	=	"This event is triggered as someone start casting a spell. It has not yet been completed so it might miss, fail or be interrupted.TAB{}NOTE: This event will not trigger for channeled spells. Look at OnEvent(\"REQ{Casted}\") for that.TAB{}TAB{}If you specify 'VAL{group}' then anyone in your party/raid can trigger the event.TAB{}@REPLY@";
	p[EX]	=	'OnEvent("Casting","Mass Resurrection", "player") AND InGroup() THEN Group("Hold on, im Casting [Mass Resurrection]");TAB{}OnEvent("Casting","Mass Resurrection", "group") AND InGroup() THEN Group("%replyName% is casting [Mass Resurrection]...");';
	p[REF]	=	{'OnEvent("REQ{Casted}")', "HasBuff()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_UNIT_SPELLCAST_SUCCEEDED; --Points to the same eventhandler as UNIT_SPELLCAST_SUCCEEDED
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Chat";
	p[DESC]	=	"Triggered on a chat statement.";
	p[SIGN]	=	'OnEvent("REQ{Chat}", "REQ{Channel}", "OPT{Player}", "OPT{Message}", "OPT{Match}")';
	p[ARG]	=	{
				"STR[]",		"REQ{Chat}",
				"STR[]",		"REQ{Channel}     -Can be one of the following: @EVENTCHANNEL@",
				"STR[]",		"OPT{Player}        -The name of the player sending the chat (both 'playername' and 'playername-realm' are supported).",
				"STR[]",		"OPT{Message}    -The message that was received.",
				"COMPARE[]",	"OPT{Match}        -Comparison operator. Can either be @COMPARE@."
				};
	p[RET]	=	"IFTHEN_CHAT_MSG"; --Dynamically setup as a background event to merge over 15 different ingame CHAT_MSG_* and CHAT_MSG_BN_* events into a single event
	p[REM]	=	"If REQ{Channel} has the value 'VAL{battle.net}' or 'VAL{system}', then the OPT{Player} argument is not checked.TAB{}@REPLY@TAB{}The only exception to this is when using '%replyName%' in text for Chat() or Whisper() as a response to 'VAL{battle.net}'. The Reply() function itself will then work, but not '%replyName%'.";
	p[EX]	=	'#Will trigger when the string "portal" is found somewhere in the whisper;TAB{}OnEvent("Chat","Whisper","","portal","indexof") AND InLFGQueue() THEN Reply("I am in the LFG queue. No portals.");';
	p[REF]	=	{"Reply()::action", "Group()::action", "Whisper()::action", "RaidMessage()::action", "Message()::action", "Print()::action"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_IFTHEN_CHAT_MSG;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"CombatEnd";
	p[DESC]	=	"Triggered when you leave combat.";
	p[SIGN]	=	'OnEvent("REQ{CombatEnd}")';
	p[ARG]	=	{
				"STR[]", "REQ{CombatEnd}"
				};
	p[RET]	=	"PLAYER_REGEN_ENABLED";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{'OnEvent("REQ{CombatStart}")', "InCombat()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"CombatStart";
	p[DESC]	=	"Triggered when you enter combat.";
	p[SIGN]	=	'OnEvent("REQ{CombatStart}")';
	p[ARG]	=	{
				"STR[]", "REQ{CombatStart}"
				};
	p[RET]	=	"PLAYER_REGEN_DISABLED";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{'OnEvent("REQ{CombatEnd}")', "InCombat()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Dead";
	p[DESC]	=	"Triggered when you die.";
	p[SIGN]	=	'OnEvent("REQ{Dead}")';
	p[ARG]	=	{
				"STR[]", "REQ{Dead}"
				};
	p[RET]	=	"PLAYER_DEAD";
	p[REM]	=	nil;
	p[EX]	=	'OnEvent("Dead") AND InGroup() AND Compare("%DeathName%", "", "neq") THEN Group("Killed by %DeathName%. %DeathSpell% - %DeathAmount%");TAB{}OnEvent("Dead") AND InGroup() THEN Group("Oops, i am dead!");';
	p[REF]	=	{"IsDead()::argument", "%DeathName%::variable"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"DuelEnd";
	p[DESC]	=	"Triggered at the end of a duel.";
	p[SIGN]	=	'OnEvent("REQ{DuelEnd}")';
	p[ARG]	=	{
				"STR[]",		"REQ{DuelEnd}"
				};
	p[RET]	=	"DUEL_FINISHED";
	p[REM]	=	"Will trigger at the end of a duel.TAB{}The event will trigger regardless if its a win, loss, draw or the player cancelled the duel.";
	p[EX]	=	nil;
	p[REF]	=	{'OnEvent("REQ{DuelStart}")', "AcceptDuel()::action", "DeclineDuel()::action"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	cache_EmptyEvent; --Nothing is returned by the event. Dont know if its a win, loss, draw or user cancelled the duel
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"DuelStart";
	p[DESC]	=	"Triggered on the start of a duel.";
	p[SIGN]	=	'OnEvent("REQ{DuelStart}")';
	p[ARG]	=	{
				"STR[]",		"REQ{DuelStart}"
				};
	p[RET]	=	"DUEL_REQUESTED";
	p[REM]	=	"@REPLY@";
	p[EX]	=	'#Will decline duels unless you are in Goldshire;TAB{}OnEvent("DuelStart") AND NOT InZone("GoldShire") THEN DeclineDuel() AND Reply("Sorry %replyName%. I only duel when in Goldshire.");';
	p[REF]	=	{'OnEvent("REQ{DuelEnd}")', "AcceptDuel()::action", "DeclineDuel()::action"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_READY_CHECK; --Function identical to Methods.do_OnEvent_DUEL_REQUESTED;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentSetChanged";
	p[DESC]	=	"Triggered when you equip a equipment set.";
	p[SIGN]	=	'OnEvent("REQ{EquipmentSetChanged}")';
	p[ARG]	=	{
				"STR[]", "REQ{EquipmentSetChanged}"
				};
	p[RET]	=	"EQUIPMENT_SWAP_FINISHED";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"HaveEquipped()::argument", "HaveItem()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"GroupChanges";
	p[DESC]	=	"Triggered whenever someone joins/leaves your group or when its created/disbanded.";
	p[SIGN]	=	'OnEvent("REQ{GroupChanges}")';
	p[ARG]	=	{
				"STR[]", "REQ{GroupChanges}"
				};
	p[RET]	=	"GROUP_ROSTER_UPDATE";
	p[REM]	=	"This event is triggered on almost every possible change in a raid or party. Rolechange, Lootrules, Join, Leave.";
	p[EX]	=	'OnEvent("GroupChanges") AND IsLeader() THEN AutoSetRoles();';
	p[REF]	=	{"AutoSetRoles()::action"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"GroupInvite";
	p[DESC]	=	"Triggered when you receive an invite to a party/raid.";
	p[SIGN]	=	'OnEvent("REQ{GroupInvite}", "OPT{Player}")';
	p[ARG]	=	{
				"STR[]", "REQ{GroupInvite}",
				"STR[]", "OPT{Player}    -Name of the player sending the invite (both 'playername' and 'playername-realm' are supported)."
				};
	p[RET]	=	"PARTY_INVITE_REQUEST";
	p[REM]	=	"@REPLY@";
	p[EX]	=	nil;
	p[REF]	=	{"AcceptGroup()::action", "DeclineGroup()::action", "InLFGQueue()::argument", "Reply()::action"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_PARTY_INVITE_REQUEST;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"ItemEquipped";
	p[DESC]	=	"Triggered when you equip an item.";
	p[SIGN]	=	'OnEvent("REQ{ItemEquipped}")';
	p[ARG]	=	{
				"STR[]", "REQ{ItemEquipped}"
				};
	p[RET]	=	"PLAYER_EQUIPMENT_CHANGED";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"HaveEquipped()::argument", "HaveItem()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_PLAYER_EQUIPMENT_CHANGED_equipped;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"ItemUnEquipped";
	p[DESC]	=	"Triggered when you unequip an item.";
	p[SIGN]	=	'OnEvent("REQ{ItemUnEquipped}")';
	p[ARG]	=	{
				"STR[]", "REQ{ItemUnEquipped}"
				};
	p[RET]	=	"PLAYER_EQUIPMENT_CHANGED";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"HaveEquipped()::argument", "HaveItem()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_PLAYER_EQUIPMENT_CHANGED_unequipped;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"LFGInvite";
	p[DESC]	=	"Triggered when your LFG group is ready.";
	p[SIGN]	=	'OnEvent("REQ{LFGInvite}")';
	p[ARG]	=	{
				"STR[]", "REQ{LFGInvite}"
				};
	p[RET]	=	"IFTHEN_LFGINVITE";
	p[REM]	=	"AcceptGroup() does not work with this event.TAB{}Accepting a LFG group invitation requires the user to manually press the accept button.";
	p[EX]	=	nil;
	p[REF]	=	{"InLFGQueue()::argument", 'OnEvent("REQ{LFGRolecheck}")'};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"LFGRolecheck";
	p[DESC]	=	"Triggered when your LFG group does role-check.";
	p[SIGN]	=	'OnEvent("REQ{LFGRolecheck}")';
	p[ARG]	=	{
				"STR[]", "REQ{LFGRolecheck}"
				};
	p[RET]	=	"LFG_ROLE_CHECK_SHOW";
	p[REM]	=	"SetRole() does not work with this event.";
	p[EX]	=	nil;
	p[REF]	=	{"InLFGQueue()::argument", 'OnEvent("REQ{LFGInvite}")'};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_LFG_ROLE_CHECK_SHOW;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"LevelUp";
	p[DESC]	=	"Triggered when the player gain one level.";
	p[SIGN]	=	'OnEvent("REQ{LevelUp}")';
	p[ARG]	=	{
				"STR[]", "REQ{LevelUp}"
				};
	p[RET]	=	"PLAYER_LEVEL_UP";
	p[REM]	=	"Note that the %PlayerLevel% variable will most likely return an incorrect value if used with this event handler or shortly after.";
	p[EX]	=	'OnEvent("LevelUp") THEN ScreenShot();';
	p[REF]	=	{"%PlayerLevel%::variable"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"LostControl";
	p[DESC]	=	"Triggered when you lose control of your character.";
	p[SIGN]	=	'OnEvent("REQ{LostControl}")';
	p[ARG]	=	{
				"STR[]",	"REQ{LostControl}"
				};
	p[RET]	=	"LOSS_OF_CONTROL_ADDED";
	p[REM]	=	nil;
	p[EX]	=	'OnEvent("LostControl") AND IsPVP() THEN Group("I am crowd controlled.");';
	p[REF]	=	{"HaveLostControl()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PetBattleStart";
	p[DESC]	=	"Triggered when a pet battle starts.";
	p[SIGN]	=	'OnEvent("REQ{PetBattleStart}")';
	p[ARG]	=	{
				"STR[]", "REQ{PetBattleStart}"
				};
	p[RET]	=	"PET_BATTLE_OPENING_START";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{'OnEvent("REQ{PetBattleEnd}")'};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PetBattleEnd";
	p[DESC]	=	"Triggered when a pet battle is finished.";
	p[SIGN]	=	'OnEvent("REQ{PetBattleEnd}")';
	p[ARG]	=	{
				"STR[]", "REQ{PetBattleEnd}",
				"STR[win;lose;any]", "OPT{Status}    -Optional, can be 'VAL{Win}', 'VAL{Lose}' or 'VAL{Any}' (default)."
				};
	p[RET]	=	"PET_BATTLE_FINAL_ROUND";
	p[REM]	=	"If you forfeit a game it will be the same as 'VAL{Lose}'.";
	p[EX]	=	nil;
	p[REF]	=	{'OnEvent("REQ{PetBattleStart}")'};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_PET_BATTLE_FINAL_ROUND;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"ReadyCheck";
	p[DESC]	=	"Triggered when a /readcheck is done in your party/raid.";
	p[SIGN]	=	'OnEvent("REQ{ReadyCheck}")';
	p[ARG]	=	{
				"STR[]", "REQ{ReadyCheck}"
				};
	p[RET]	=	"READY_CHECK";
	p[REM]	=	"@REPLY@";
	p[EX]	=	nil;
	p[REF]	=	{"Reply()::action"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_READY_CHECK;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Resurrect";
	p[DESC]	=	"Triggered when another character offers to resurrect you.";
	p[SIGN]	=	'OnEvent("REQ{Resurrect}")';
	p[ARG]	=	{
				"STR[]", "REQ{Resurrect}"
				};
	p[RET]	=	"RESURRECT_REQUEST";
	p[REM]	=	"@REPLY@";
	p[EX]	=	nil;
	p[REF]	=	{"Reply()::action"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_READY_CHECK; --Function identical to Methods.do_OnEvent_RESURRECT_REQUEST;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"RoleCheck";
	p[DESC]	=	"Triggered when a rolecheck is requested.";
	p[SIGN]	=	'OnEvent("REQ{RoleCheck}", "OPT{Player}", "OPT{Hide}")';
	p[ARG]	=	{
				"STR[]", "REQ{RoleCheck}",
				"STR[]", "OPT{Player}    -The name of the player initiating the rolecheck (both 'playername' and 'playername-realm' are supported).",
				"BOOL[]", "OPT{Hide}      -Can either be @BOOL@ (default) to automatically hide the rolecheck dialog."
				};
	p[RET]	=	"ROLE_POLL_BEGIN";
	p[REM]	=	"@REPLY@";
	p[EX]	=	nil;
	p[REF]	=	{"SetRole()::action"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_ROLE_POLL_BEGIN;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"ServerTime";
	p[DESC]	=	"Event that is triggered when the server's time is reached.";
	p[SIGN]	=	'OnEvent("REQ{ServerTime}", "REQ{Hour}", "REQ{Minute}", "OPT{Weekday}")';
	p[ARG]	=	{
				"STR[]",		"REQ{ServerTime}",
				"HOUR[]",		"REQ{Hour}          -@HOUR@.",
				"MINUTE[]",		"REQ{Minute}       -@MINUTE@.",
				"STR[monday;tuesday;wednesday;thursday;friday;saturday;sunday]",	"OPT{Weekday}    -Day of the week: 'VAL{monday}', 'VAL{tuesday}', 'VAL{wednesday}', 'VAL{thursday}', 'VAL{friday}', 'VAL{saturday}' or 'VAL{sunday}'. If omitted the field will be ignored."
				};
	p[RET]	=	"IFTHEN_CLOCK"; --Is fired every 30 seconds
	p[REM]	=	"The time is checked against the server-time (not local time). The input values are expected to be in a 24hour format.";
	p[EX]	=	nil;
	p[REF]	=	{'OnEvent("REQ{Tick}")'};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_IFTHEN_CLOCK;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Slash";
	p[DESC]	=	"Triggered when you type '/ifs REQ{Title}' in the chatwindow.";
	p[SIGN]	=	'OnEvent("REQ{Slash}","REQ{Title}")';
	p[ARG]	=	{
				"STR[]", "REQ{Slash}",
				"STR[]", "REQ{Title}    -Unique title of a slash-event."
				};
	p[RET]	=	"IFTHEN_SLASH"; --Dynamically setup as a background event
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{'OnEvent("REQ{Tick}")', 'OnEvent("REQ{Timer}")', "SetTimer()::action"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_IFTHEN_SLASH;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Spellcheck";
	p[DESC]	=	"Spellcheck feature. Must be enabled using /ifthen spellcheck.";
	p[SIGN]	=	'OnEvent("REQ{Spellcheck}", "REQ{Old}", "REQ{New}")';
	p[ARG]	=	{
				"STR[]", "REQ{Spellcheck}",
				"STR[]", "REQ{Old}    -A string to be replaced.",
				"STR[]", "REQ{New}  -The string to replace REQ{Old} with."
				};
	p[RET]	=	"IFTHEN_SPELLCHECK"; --Dynamically setup as a background event
	p[REM]	=	"Replaces the REQ{Old} string with REQ{New} before the chat is sendt to the server.TAB{}Strings are Case-Sensitive and the event must have no other statements (they won't be executed).TAB{}This event is never raised unless the spellcheck feature is enabled by using '/ifthen spellcheck'.TAB{}Typing commands like /focus and /target will not work when the spellcheck feature is enabled.TAB{}Variables (%playerName%, etc) and hyperlinks ([text], [type:text] or [type:id:text]) will also be replaced if spellcheck is enabled.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Summon";
	p[DESC]	=	"Triggered when you receive a summon.";
	p[SIGN]	=	'OnEvent("REQ{Summon}")';
	p[ARG]	=	{
				"STR[]", "REQ{Summon}"
				};
	p[RET]	=	"CONFIRM_SUMMON";
	p[REM]	=	"@REPLY@";
	p[EX]	=	nil;
	p[REF]	=	{"Reply()::action"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TalentSpecChanged";
	p[DESC]	=	"Triggered when you switch from one talent spec to another.";
	p[SIGN]	=	'OnEvent("REQ{TalentSpecChanged}")';
	p[ARG]	=	{
				"STR[]", "REQ{TalentSpecChanged}"
				};
	p[RET]	=	"ACTIVE_TALENT_GROUP_CHANGED";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"IsCurrentSpec()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Tick";
	p[DESC]	=	"Event that is triggered every 1 seconds. Always combine this event with Cooldown().";
	p[SIGN]	=	'OnEvent("REQ{Tick}")';
	p[ARG]	=	{
				"STR[]", "REQ{Tick}"
				};
	p[RET]	=	"IFTHEN_TICK"; --Dynamically setup as a background event
	p[REM]	=	"This event is triggered roughly every 1 seconds. You should always combine this event with Cooldown() so that you do not overwhelm the system.TAB{}Note: there is no guarantee that this event will fire exactly every 1 seconds. There might be some time-drift. This is dependent on the framerate of the gameclient (i.e. more lag == more drift).";
	p[EX]	=	nil;
	p[REF]	=	{"Cooldown()::action", 'OnEvent("REQ{ServerTime}")'};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Timer";
	p[DESC]	=	"Timer event that is raised N seconds after the related SetTimer() action was called.";
	p[SIGN]	=	'OnEvent("REQ{Timer}", "REQ{Name}")';
	p[ARG]	=	{
				"STR[]", "REQ{Timer}",
				"STR[]", "REQ{Name}    -A unique name for this specific timer event."
				};
	p[RET]	=	"IFTHEN_TIMER"; --Dynamically setup as a background event after SetTimer() is called
	p[REM]	=	"The countdown for this event to be triggered is started after a call to the function SetTimer() with the same REQ{Name}-argument.";
	p[EX]	=	nil;
	p[REF]	=	{'OnEvent("REQ{Timer}")', 'OnEvent("REQ{Tick}")'};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_IFTHEN_TIMER;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"UIError";
	p[DESC]	=	"Triggered when UI error- or info-message is shown.";
	p[SIGN]	=	'OnEvent("REQ{UIError}", "OPT{Message}", "OPT{Match}")';
	p[ARG]	=	{
				"STR[]",		"REQ{UIError}",
				"STR[]",		"OPT{Message}      -The message that was shown.",
				"COMPARE[]",	"OPT{Match}          -Comparison operator. Can either be @COMPARE@."
				};
	p[RET]	=	"IFTHEN_UI_ERROR"; --Dynamically setup as a background event to merge UI_ERROR_MESSAGE and UI_INFO_MESSAGE into a single event
	p[REM]	=	"This event is triggered whenever the user interface (UI) is showing an error-message like 'There is nothing to attack' or an info-message like 'No fish are hooked'.";
	p[EX]	=	'OnEvent("UIError","nothing to attack.","indexof") THEN Print("You are attacking nothing.");';
	p[REF]	=	nil;
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	Methods.do_OnEvent_IFTHEN_UI_ERROR;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"WorldPVPInvite";
	p[DESC]	=	"Triggered when you receive an invitation to enter a world pvp battleground (like Wintergrasp or Tol Barad).";
	p[SIGN]	=	'OnEvent("REQ{WorldPVPInvite}")';
	p[ARG]	=	{
				"STR[]", "REQ{WorldPVPInvite}"
				};
	p[RET]	=	"BATTLEFIELD_MGR_ENTRY_INVITE";
	p[REM]	=	"This event will not trigger on invites for instanced battlegrounds like Alterac Valley.";
	p[EX]	=	nil;
	p[REF]	=	{'OnEvent("REQ{BattlegroundInvite}")',};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Zoning";
	p[DESC]	=	"Triggered when you move between major zones or enters/exits an instance.";
	p[SIGN]	=	'OnEvent("REQ{Zoning}")';
	p[ARG]	=	{
				"STR[]", "REQ{Zoning}"
				};
	p[RET]	=	"ZONE_CHANGED_NEW_AREA";
	p[REM]	=	"Triggers whenever the player changes geographical area, but also when moving in/out of instances and battlegrounds.";
	p[EX]	=	nil;
	p[REF]	=	{"InZone()::argument"};
	p[MIN]	=	self:argCount(p[ARG],true);
	p[MAX]	=	self:argCount(p[ARG],false);
	p[PTR]	=	cache_EmptyEvent;
	d[strlower(EV..p[NAME])] = p;
	-- --------------------------------------------





	-- Enviroment variables -----------------------
	-- --------------------------------------------
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerGold";
	p[DESC]	=	"Amount of gold the player (yourself) have.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";		--holds datatype
	p[RET]	=	"playergold";	--holds argument for value lookup function
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"BattleTag";
	p[DESC]	=	"Your Battle.Net tag (i.e Something#1234).";
	p[SIGN] =	true;
	p[ARG]	=	"STR[]";
	p[RET]	=	"battletag";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerName%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerName";
	p[DESC]	=	"Name of the player (yourself).";
	p[SIGN] =	true;
	p[ARG]	=	"STR[]";		--holds datatype
	p[RET]	=	"playername";	--holds argument for value lookup function
	p[REM]	=	"Is the players name. Use PlayerNameAndTitle to get both the name and the title.";
	p[EX]	=	'IF Compare("%TargetName%", "%PlayerName%") THEN Print("I am targeting myself");';
	p[REF]	=	{"%PlayerTitle%", "%PlayerNameAndTitle%", "%BattleTag%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TargetName";
	p[DESC]	=	"Name of your /target.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"targetname";
	p[REM]	=	"If nothing is currently targeted the value will be 'VAL{<no target>}'.";
	p[EX]	=	nil;
	p[REF]	=	{"%FocusName%", "%PetName%", "%LeaderName%", "%ReplyName%", "%MouseOverName%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FocusName";
	p[DESC]	=	"Name of your /focus.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"focusname";
	p[REM]	=	"If nothing is currently focused the value will be 'VAL{<no focus>}'.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetName%", "%PetName%", "%LeaderName%", "%ReplyName%", "%MouseOverName%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PetName";
	p[DESC]	=	"Name of your pet.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"petname";
	p[REM]	=	"If no pet is summoned the value will be 'VAL{<no pet>}'.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetName%", "%FocusName%", "%LeaderName%", "%ReplyName%", "%MouseOverName%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"MouseOverName";
	p[DESC]	=	"Name of the npc/player/item your mousecursor is hovering over.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"mouseovername";
	p[REM]	=	"If nothing is currently moused over the value will be 'VAL{<no mouseover>}'.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetName%", "%FocusName%", "%PetName%", "%LeaderName%", "%ReplyName%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerLevel";
	p[DESC]	=	"Level of the player (yourself).";
	p[SIGN] =	false;		if (UnitLevel("player") == GetMaxPlayerLevel()) then p[SIGN] = true end --Variable is static if the player is at max level
	p[ARG]	=	"INT[1;"..tostring(GetMaxPlayerLevel()).."]"; --This allows this datatype to dynamically adjust to the players expansionlevel
	p[RET]	=	"playerlevel";
	p[REM]	=	"Will be a value between 'VAL{1}' and 'VAL{"..tostring(GetMaxPlayerLevel()).."}'.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetLevel%", "%FocusLevel%", "%PetLevel%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TargetLevel";
	p[DESC]	=	"Level of the currently targeted unit.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[-1;110]";
	p[RET]	=	"targetlevel";
	p[REM]	=	"If nothing is currently targeted the value will be 'VAL{0}'.TAB{}Note: value is 'VAL{-1}' for bosses and hostile units whose level is ten levels or more above the players own level.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerLevel%", "%FocusLevel%", "%PetLevel%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FocusLevel";
	p[DESC]	=	"Level of the currently focuses unit.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[-1;110]";
	p[RET]	=	"focuslevel";
	p[REM]	=	"If nothing is currently focused on the value will be 'VAL{0}'.TAB{}Note: value is 'VAL{-1}' for bosses and hostile units whose level is ten levels or more above the players own level.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetLevel%", "%PlayerLevel%", "%PetLevel%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PetLevel";
	p[DESC]	=	"Level of the players pet.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[0;"..tostring(GetMaxPlayerLevel()).."]"; --This allows this datatype to dynamically adjust to the players expansionlevel
	p[RET]	=	"petlevel";
	p[REM]	=	"Will be a value between 'VAL{1}' and 'VAL{"..tostring(GetMaxPlayerLevel()).."}'.TAB{}If no pet is summoned, the value will be 'VAL{0}'.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetLevel%", "%FocusLevel%", "%PlayerLevel%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerClass";
	p[DESC]	=	"Class of the player (yourself).";
	p[SIGN] =	true;
	p[ARG]	=	"STR[]";
	p[RET]	=	"playerclass";
	p[REM]	=	"Is the players class.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetClass%", "%FocusClass%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TargetClass";
	p[DESC]	=	"Class of your /target.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"targetclass";
	p[REM]	=	"Is the targets class.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerClass%", "%FocusClass%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FocusClass";
	p[DESC]	=	"Class of your /focus.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"focusclass";
	p[REM]	=	"Is the class of /focus.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerClass%", "%TargetClass%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerRace";
	p[DESC]	=	"Race of the player (yourself).";
	p[SIGN] =	false; --various spells and abilities can change player's race
	p[ARG]	=	"STR[]";
	p[RET]	=	"playerrace";
	p[REM]	=	"Is the players race.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetRace%", "%FocusRace%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TargetRace";
	p[DESC]	=	"Race of your /target.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"targetrace";
	p[REM]	=	"Is the targets race. Note that only players have a race. NPC's return empty string.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerRace%", "%FocusRace%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FocusRace";
	p[DESC]	=	"Race of your /focus.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"focusrace";
	p[REM]	=	"Is the race of /focus. Note that only players have a race. NPC's return empty string.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerRace%", "%TargetRace%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerGender";
	p[DESC]	=	"Gender of the player (yourself).";
	p[SIGN] =	false; --various spells and abilities can change player's gender
	p[ARG]	=	"STR[]";
	p[RET]	=	"playergender";
	p[REM]	=	"Is the players gender.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetGender%", "%FocusGender%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TargetGender";
	p[DESC]	=	"Gender of your /target.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"targetgender";
	p[REM]	=	"Is the targets gender. Note that some things will return emtpy string as they have no gender.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerGender%", "%FocusGender%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FocusGender";
	p[DESC]	=	"Gender of your /focus.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"focusgender";
	p[REM]	=	"Is the gender of /focus. Note that some things will return emtpy string as they have no gender.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerGender%", "%TargetGender%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerFaction";
	p[DESC]	=	"Faction of the player (yourself).";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"playerfaction";
	p[REM]	=	"Is the players faction. 'Alliance', 'Horde' or 'Neutral' (localized).";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetFaction%", "%FocusFaction%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TargetFaction";
	p[DESC]	=	"Faction of your /target.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"targetfaction";
	p[REM]	=	"Is the targets faction (localized).";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerFaction%", "%FocusFaction%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FocusFaction";
	p[DESC]	=	"Faction of your /focus.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"focusfaction";
	p[REM]	=	"Is the faction of /focus (localized).";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerFaction%", "%TargetFaction%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerCreatureType";
	p[DESC]	=	"CreatureType of the player (yourself).";
	p[SIGN] =	false; --Players can change form
	p[ARG]	=	"STR[]";
	p[RET]	=	"playercreaturetype";
	p[REM]	=	"Is the players creaturetype. Localized string: Beast, Humanoid, Undead, etc.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetCreatureType%", "%FocusCreatureType%", "%PetCreatureType%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TargetCreatureType";
	p[DESC]	=	"CreatureType of your /target.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"targetcreaturetype";
	p[REM]	=	"Is the targets creaturetype. Localized string: Beast, Humanoid, Undead, etc.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerCreatureType%", "%FocusCreatureType%", "%PetCreatureType%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FocusCreatureType";
	p[DESC]	=	"CreatureType of your /focus.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"focuscreaturetype";
	p[REM]	=	"Is the creaturetype of /focus. Localized string: Beast, Humanoid, Undead, etc.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerCreatureType%", "%TargetCreatureType%", "%PetCreatureType%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PetCreatureType";
	p[DESC]	=	"CreatureType of your pet.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"petcreaturetype";
	p[REM]	=	"Is the creaturetype of your pet. Localized string: Beast, Humanoid, Undead, etc.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerCreatureType%", "%TargetCreatureType%", "%FocusCreatureType%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerGuild";
	p[DESC]	=	"Guild of the player (yourself).";
	p[SIGN] =	false; --players can change guild
	p[ARG]	=	"STR[]";
	p[RET]	=	"playerguild";
	p[REM]	=	"Is the players guild.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetGuild%", "%FocusGuild%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TargetGuild";
	p[DESC]	=	"Guild of your /target.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"targetguild";
	p[REM]	=	"Is the targets guild.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerGuild%", "%FocusGuild%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FocusGuild";
	p[DESC]	=	"Guild of your /focus.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"focusguild";
	p[REM]	=	"Is the guild of /focus.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerGuild%", "%TargetGuild%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerRealm";
	p[DESC]	=	"Realm of the player (yourself).";
	p[SIGN] =	true; --players cant change realm witout a relog
	p[ARG]	=	"STR[]";
	p[RET]	=	"playerrealm";
	p[REM]	=	"Is the players realm.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetRealm%", "%FocusRealm%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TargetRealm";
	p[DESC]	=	"Realm of your /target.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"targetrealm";
	p[REM]	=	"Is the targets realm. Note that NPC's do not have realms and will return empty string.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerRealm%", "%FocusRealm%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FocusRealm";
	p[DESC]	=	"Realm of your /focus.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"focusrealm";
	p[REM]	=	"Is the realm of /focus. Note that NPC's do not have realms and will return empty string.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerRealm%", "%TargetRealm%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerMark";
	p[DESC]	=	"Mark of the player (yourself).";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"playermark";
	p[REM]	=	"Is the raidmark currently on the player.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetMark%", "%FocusMark%", "%PetMark%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TargetMark";
	p[DESC]	=	"Mark of your /target.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"targetmark";
	p[REM]	=	"Is the raidmarker currently on your target.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerMark%", "%FocusMark%", "%PetMark%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FocusMark";
	p[DESC]	=	"Mark of your /focus.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"focusmark";
	p[REM]	=	"Is the raidmarker currently on your /focus.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerMark%", "%TargetMark%", "%PetMark%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PetMark";
	p[DESC]	=	"Mark of your pet.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"petmark";
	p[REM]	=	"Is the raidmarker currently on your pet.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerMark%", "%TargetMark%", "%FocusMark%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerHealth";
	p[DESC]	=	"Health of the player (yourself).";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"playerhealth";
	p[REM]	=	"Current health of the player.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetHealth%", "%FocusHealth%", "%PetHealth%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TargetHealth";
	p[DESC]	=	"Health of your /target.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"targethealth";
	p[REM]	=	"Current health of your target.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerHealth%", "%FocusHealth%", "%PetHealth%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FocusHealth";
	p[DESC]	=	"Health of your /focus.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"focushealth";
	p[REM]	=	"Current health of /focus.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerHealth%", "%TargetHealth%", "%PetHealth%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PetHealth";
	p[DESC]	=	"Health of your pet.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"pethealth";
	p[REM]	=	"Current health of the player's pet.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerHealth%", "%TargetHealth%", "%FocusHealth%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerMaxHealth";
	p[DESC]	=	"MaxHealth of the player (yourself).";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"playermaxhealth";
	p[REM]	=	"Maximum health of the player.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetMaxHealth%", "%FocusMaxHealth%", "%PetMaxHealth%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TargetMaxHealth";
	p[DESC]	=	"MaxHealth of your /target.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"targetmaxhealth";
	p[REM]	=	"Maximum health of your target.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerMaxHealth%", "%FocusMaxHealth%", "%PetMaxHealth%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FocusMaxHealth";
	p[DESC]	=	"MaxHealth of your /focus.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"focusmaxhealth";
	p[REM]	=	"Maximum health of /focus.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerMaxHealth%", "%TargetMaxHealth%", "%PetMaxHealth%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PetMaxHealth";
	p[DESC]	=	"MaxHealth of your pet.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"petmaxhealth";
	p[REM]	=	"Maximum health of the player's pet.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerMaxHealth%", "%TargetMaxHealth%", "%FocusMaxHealth%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerPstHealth";
	p[DESC]	=	"Health of the player (yourself) in percent.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"playerpsthealth";
	p[REM]	=	"Current health of the player in percent.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetPstHealth%", "%FocusPstHealth%", "%PetPstHealth%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TargetPstHealth";
	p[DESC]	=	"Health of your /target in percent.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"targetpsthealth";
	p[REM]	=	"Current health of your target in percent.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerPstHealth%", "%FocusPstHealth%", "%PetPstHealth%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FocusPstHealth";
	p[DESC]	=	"Health of your /focus in percent.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"focuspsthealth";
	p[REM]	=	"Current health of /focus in percent.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerPstHealth%", "%TargetPstHealth%", "%PetPstHealth%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PetPstHealth";
	p[DESC]	=	"Health of your pet in percent.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"petpsthealth";
	p[REM]	=	"Current health of the player's pet in percent.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerPstHealth%", "%TargetPstHealth%", "%FocusPstHealth%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerPower";
	p[DESC]	=	"Power of the player (yourself).";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"playerpower";
	p[REM]	=	"Current power of the player.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetPower%", "%FocusPower%", "%PetPower%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TargetPower";
	p[DESC]	=	"Power of your /target.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"targetpower";
	p[REM]	=	"Current power of your target.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerPower%", "%FocusPower%", "%PetPower%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FocusPower";
	p[DESC]	=	"Power of your /focus.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"focuspower";
	p[REM]	=	"Current power of /focus.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerPower%", "%TargetPower%", "%PetPower%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PetPower";
	p[DESC]	=	"Power of your pet.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"petpower";
	p[REM]	=	"Current power of the player's pet.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerPower%", "%TargetPower%", "%FocusPower%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerMaxPower";
	p[DESC]	=	"MaxPower of the player (yourself).";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"playermaxpower";
	p[REM]	=	"Maximum power of the player.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetMaxPower%", "%FocusMaxPower%", "%PetMaxPower%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TargetMaxPower";
	p[DESC]	=	"MaxPower of your /target.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"targetmaxpower";
	p[REM]	=	"Maximum power of your target.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerMaxPower%", "%FocusMaxPower%", "%PetMaxPower%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FocusMaxPower";
	p[DESC]	=	"MaxPower of your /focus.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"focusmaxpower";
	p[REM]	=	"Maximum power of /focus.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerMaxPower%", "%TargetMaxPower%", "%PetMaxPower%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PetMaxPower";
	p[DESC]	=	"MaxPower of your pet.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[ARG]	=	"STR[]";
	p[RET]	=	"petmaxpower";
	p[REM]	=	"Maximum power of the player's pet.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerMaxPower%", "%TargetMaxPower%", "%FocusMaxPower%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerPstPower";
	p[DESC]	=	"Power of the player (yourself) in percent.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"playerpstpower";
	p[REM]	=	"Current power of the player in percent.";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetPstPower%", "%FocusPstPower%", "%PetPstPower%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TargetPstPower";
	p[DESC]	=	"Power of your /target in percent.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"targetpstpower";
	p[REM]	=	"Current power of your target in percent.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerPstPower%", "%FocusPstPower%", "%PetPstPower%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FocusPstPower";
	p[DESC]	=	"Power of your /focus in percent.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"focuspstpower";
	p[REM]	=	"Current power of /focus in percent.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerPstPower%", "%TargetPstPower%", "%PetPstPower%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PetPstPower";
	p[DESC]	=	"Power of your pet in percent.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"petpstpower";
	p[REM]	=	"Current power of the player's pet in percent.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerPstPower%", "%TargetPstPower%", "%FocusPstPower%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerPowerType";
	p[DESC]	=	"PowerType of the player (yourself).";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"playerpowertype";
	p[REM]	=	"What type of power the player has ('".._G["MANA"].."', '".._G["RAGE"].."', '".._G["PAIN"].."', '".._G["ENERGY"].."', etc).";
	p[EX]	=	nil;
	p[REF]	=	{"%TargetPowerType%", "%FocusPowerType%", "%PetPowerType%", "HasPower()::argument"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TargetPowerType";
	p[DESC]	=	"PowerType of your /target.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"targetpowertype";
	p[REM]	=	"What type of power the target has ('".._G["MANA"].."', '".._G["RAGE"].."', '".._G["PAIN"].."', '".._G["ENERGY"].."', etc).";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerPowerType%", "%FocusPowerType%", "%PetPowerType%", "HasPower()::argument"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FocusPowerType";
	p[DESC]	=	"PowerType of your /focus.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"focuspowertype";
	p[REM]	=	"What type of power the /focus has ('".._G["MANA"].."', '".._G["RAGE"].."', '".._G["PAIN"].."', '".._G["ENERGY"].."', etc).";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerPowerType%", "%TargetPowerType%", "%PetPowerType%", "HasPower()::argument"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PetPowerType";
	p[DESC]	=	"PowerType of your pet.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"petpowertype";
	p[REM]	=	"What type of power the player's pet has ('".._G["MANA"].."', '".._G["RAGE"].."', '".._G["PAIN"].."', '".._G["ENERGY"].."', etc).";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerPowerType%", "%TargetPowerType%", "%FocusPowerType%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerNameAndTitle";
	p[DESC]	=	"Name of the player and current title.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"playernameandtitle";
	p[REM]	=	"Is the players name and title combined. Use %PlayerName% or %PlayerTitle% to get separate values.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerTitle%", "%PlayerName%", "SetTitle()::action"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerTitle";
	p[DESC]	=	"Current title of the player (yourself).";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";		--holds datatype
	p[RET]	=	"playertitle";	--holds argument for value lookup function
	p[REM]	=	"Is the players current title. Use %PlayerNameAndTitle% to get both the name and the title.";
	p[EX]	=	nil;
	p[REF]	=	{"%PlayerName%", "%PlayerNameAndTitle%", "SetTitle()::action"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerCoordinates";
	p[DESC]	=	"Current coordinates of the player (yourself).";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"playercoordinates";
	p[REM]	=	"Is the players current coordinates. Use %PlayerLocation% to get both the coordinates and zone-names.TAB{}Blizzard has restricted the use of coordinates since patch 7.1. This function will return 0.0 when in instances.";
	p[EX]	=	'"72.3, 88.8"';
	p[REF]	=	{"%PlayerLocation%", "%ZoneName%", "%AreaName%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PlayerLocation";
	p[DESC]	=	"Current coordinates and zone name of where the player (yourself) is.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"playerlocation";
	p[REM]	=	"Is the players current coordinates and zone name. Use %PlayerCoordinates% to get just the coordinates.TAB{}Blizzard has restricted the use of coordinates since patch 7.1. This function will return 0.0 when in instances.";
	p[EX]	=	'"Stormwind City, Valley Of Heroes: 72.3, 88.8"TAB{}"Elwynn Forest: 32.9, 51.1"';
	p[REF]	=	{"%PlayerCoordinates%", "%ZoneName%", "%AreaName%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"DeathName";
	p[DESC]	=	"Name of the player/npc that last killed you.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"deathname";
	p[REM]	=	"If you died from enviromental damage (falling, campfires etc) then the variable will be an empty string.";
	p[EX]	=	'OnEvent("Dead") THEN Group("I just got killed by %DeathName%");';
	p[REF]	=	{"%PlayerName%", 'OnEvent("REQ{Dead}")::event', "%DeathSpell%", "%DeathAmount%", "%DeathOverkill%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"DeathSpell";
	p[DESC]	=	"Name of the spell/ability/enviromental type that last killed you.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"deathspell";
	p[REM]	=	"Will return the name of the spell or ability that last killed you.TAB{}For enviromental damage you will see 'Falling', 'Fire' and so on.TAB{}If you got killed by an autoattack the variable will be an empty string.";
	p[EX]	=	nil;
	p[REF]	=	{"%DeathName%", "%DeathAmount%", "%DeathOverkill%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"DeathAmount";
	p[DESC]	=	"Amount of damage the spell/ability that last killed you did.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"deathamount";
	p[REM]	=	"Will return the total damage of the spell/ability/autoattack/enviromental that killed you.";
	p[EX]	=	nil;
	p[REF]	=	{"%DeathName%", "%DeathSpell%", "%DeathOverkill%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"DeathOverkill";
	p[DESC]	=	"Amount of overkill-damage the spell/ability that last killed you did.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"deathoverkill";
	p[REM]	=	"For enviromental damage the value will return 0.";
	p[EX]	=	nil;
	p[REF]	=	{"%DeathName%", "%DeathSpell%", "%DeathAmount%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"CritterName";
	p[DESC]	=	"Name of your currently summoned non-combat pet.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"crittername";
	p[REM]	=	"This variable returns the name of your summoned non-combat pet (like Core Hound Pup).TAB{}Non-Combat Pets are not the same as the pets that some classes have (like a warlock's imp). Use %PetName% for combat-pets.";
	p[EX]	=	nil;
	p[REF]	=	{"%MountName%", "%PetName%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"MountName";
	p[DESC]	=	"Name of your currently summoned mount.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"mountname";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"%CritterName%", "%PetName%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"PVPTimer";
	p[DESC]	=	"Time left until you are no longer PVP flagged.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"pvptimer";
	p[REM]	=	"Returns a string in the format 'VAL{MM:SS}' with how long until you are no longer flagged for PVP.TAB{}If you are currently not flagged it returns an empty string.TAB{}If you are permanently flagged (like when manually using the /pvp command), it returns 'VAL{Permanent}'.";
	p[EX]	=	nil;
	p[REF]	=	{"IsPVP()::argument"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"LeaderName";
	p[DESC]	=	"Name of your current instancegroup/raid/party/battleground leader.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"leadername";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"%TargetName%", "%FocusName%", "%PetName%", "%ReplyName%", "%MouseOverName%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"ReplyName";
	p[DESC]	=	"Name of the player that last whispered/invited etc.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"replyname";
	p[REM]	=	"If your last incoming event was from a Battle.net event then the variable will be an empty string.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Report1";
	p[DESC]	=	"Outputs the first value reported by the Report() function.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"report1";
	p[REM]	=	"By using the Report() function you can set the values that you later can retrieve using the %Report1%, %Report2% and %Report3% variables.TAB{}Exactly what value each variable has depends on what arguments you use with Report().TAB{}Note: when outputting saved instances you might go over the maximum number of characters allowed for a single line (255), therefore the %Report% variables might not return a complete list of instance-names.";
	p[EX]	=	'OnEvent("Slash","saved") THEN Report("Print","savedinstance","raid") AND Group("Saved raids:") AND Group("%Report1%") AND Group("%Report2%") AND Group("%Report3%");TAB{}OnEvent("Slash", "rep") THEN Report("Print", "reputation", "Darkmoon Faire") AND Group("My standing with %Report1% is -%Report2%-. I need %Report3% points for the next reputation level.");TAB{}OnEvent("Slash", "stats") THEN Report("Print", "statistic", "creatures killed") AND Group("my stats on %Report1% is %Report2%.");';
	p[REF]	=	{"Report()::action", "%Report2%", "%Report3%"};--, "%Report4%"
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Report2";
	p[DESC]	=	"Outputs the second value reported by the Report() function.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"report2";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"Report()::action", "%Report1%", "%Report3%"};--, "%Report4%"
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Report3";
	p[DESC]	=	"Outputs the third value reported by the Report() function.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"report3";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"Report()::action", "%Report1%", "%Report2%"};--, "%Report4%"
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	--[[p = self:CreateOnDocStruct();
	p[NAME]	=	"Report4";
	p[DESC]	=	"Outputs the fourth value reported by the Report() function.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"report4";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"Report()::action", "%Report1%", "%Report2%", "%Report3%"};
	d[strlower(VA..p[NAME])] = p;--]]
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"RaidRollName";
	p[DESC]	=	"Name of a random player in your instancegroup/party/raid/battleground.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"raidrollname";
	p[REM]	=	"IfThen will randomly pick a player in your current group and output that players name. The addon will do another random pick each time the variable is used.TAB{}If you are not grouped then the variable will be an empty string.TAB{}Note that this variable uses a client-side function to randomly pick a player. The Roll() function uses a server-side roll that is shown in chat.";
	p[EX]	=	'OnEvent("Slash", "raidroll") AND InGroup() THEN Group("Raid-rolling a random player: >> %RaidRollName% << is the winner!");';
	p[REF]	=	{"Roll()::action"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Random";
	p[DESC]	=	"Outputs the number generated by the Random() function.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[1;2]"; --We set this to 1-2 to fool the parser so that it will work with most integer arguments that we have, however in realtime the user can call random with anything from 0 to 1 000 000. That is then handeled in realtime by the functions themselves
	p[RET]	=	"random";
	p[REM]	=	"By using the Random() function you can generate a random number that you later can retrieve using the %Random% variable.TAB{}The variable will return the same value until you call Random() to generate a new value.";
	p[EX]	=	'OnEvent("Slash", "hello") THEN Random("1", "4") AND Print("Will trigger in %Random% seconds") AND SetTimer("hello","%Random%");TAB{}OnEvent("Timer", "hello") THEN Print("hello world");';
	p[REF]	=	{"Random()::action"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"GuildRank";
	p[DESC]	=	"The player's current guildrank";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"guildrank";
	p[REM]	=	"Will return empty string if the player is not in a guild.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"GuildAchievementPoints";
	p[DESC]	=	"Number of achievement points for your guild.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"guildachievementpoints";
	p[REM]	=	"Will return 0 if the player is not in a guild.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"ItemLevel";
	p[DESC]	=	"ItemLevel of the player's currently equipped items.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"itemlevel";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"%ItemLevelTotal%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"ItemLevelTotal";
	p[DESC]	=	"ItemLevel of all the items the player have equipped and in his bags.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"itemleveltotal";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"%ItemLevel%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"ZoneName";
	p[DESC]	=	"Name of the Zone that the player is currently in.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"zonename";
	p[REM]	=	"%ZoneName% is the name of the larger geographical region that the player is in. For example 'Stormwind City'.TAB{}You can use %AreaName% if you need the name of the immediate area.";
	p[EX]	=	nil;
	p[REF]	=	{"%AreaName%", "%PlayerCoordinates%", "%PlayerLocation%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"AreaName";
	p[DESC]	=	"Name of the immediate area that the player is currently in.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"areaname";
	p[REM]	=	"%AreaName% is the name of the immediate area that the player is in. For example 'Old Town'.TAB{}It's the same name that you see above the minimap.TAB{}You can use %ZoneName% if you need the name of the wider geographical region.";
	p[EX]	=	nil;
	p[REF]	=	{"%ZoneName%", "%PlayerCoordinates%", "%PlayerLocation%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"TalentSpec";
	p[DESC]	=	"Name of the players current talentspec.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"talentspec";
	p[REM]	=	nil;
	p[EX]	=	nil;
	p[REF]	=	{"IsCurrentSpec()::argument", "EnableSpec()::action"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"FrameRate";
	p[DESC]	=	"Current framerate of the players gameclient.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"framerate";
	p[REM]	=	"The value returned is rounded to the nearest integer.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"ScreenResolution";
	p[DESC]	=	"Current screen resolution of the players gameclient.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"screenresolution";
	p[REM]	=	"If you are running in Windowed mode then numbers returned might be different compared to the value in the settings screen. The values returned is the actual screen resolution used.";
	p[EX]	=	'"1920x1080"';
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"LatencyHome";
	p[DESC]	=	"Home latency of the players gameclient.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"latencyhome";
	p[REM]	=	"'Home' refers to your connection to your realm server.TAB{}This connection sends chat data, auction house stuff, guild chat and info, some addon data, and various other data.TAB{}It is a pretty slim connection in terms of bandwidth requirements.TAB{}TAB{}'World' is a reference to the connection to the servers that transmits all the other data; combat, data from the people around you (specs, gear, enchants, etc.), NPCs, mobs, casting, professions, etc.TAB{}Going into a highly populated zone (like a capital city) will drastically increase the amount of data being sent over this connection and will raise the reported latency.";
	p[EX]	=	nil;
	p[REF]	=	{"%LatencyWorld%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"LatencyWorld";
	p[DESC]	=	"World latency of the players gameclient.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"latencyworld";
	p[REM]	=	"'Home' refers to your connection to your realm server.TAB{}This connection sends chat data, auction house stuff, guild chat and info, some addon data, and various other data.TAB{}It is a pretty slim connection in terms of bandwidth requirements.TAB{}TAB{}'World' is a reference to the connection to the servers that transmits all the other data; combat, data from the people around you (specs, gear, enchants, etc.), NPCs, mobs, casting, professions, etc.TAB{}Going into a highly populated zone (like a capital city) will drastically increase the amount of data being sent over this connection and will raise the reported latency.";
	p[EX]	=	nil;
	p[REF]	=	{"%LatencyHome%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"LocalTime";
	p[DESC]	=	"Current local time in 24-hour format.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"localtime";
	p[REM]	=	"Will return the times as 'VAL{HH:MM}' Where HH is based on the 24hour clock.";
	p[EX]	=	nil;
	p[REF]	=	{"%LocalTime12%", "%WeekDay%", "%ServerTime%", "%ServerTime12%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"LocalTime12";
	p[DESC]	=	"Current local time in AM/PM format.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"localtime12";
	p[REM]	=	"Will return the times as 'VAL{HH:MM AM/PM}' Where HH is based on the 12hour clock.";
	p[EX]	=	nil;
	p[REF]	=	{"%LocalTime%", "%WeekDay%", "%ServerTime%", "%ServerTime12%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"ServerTime";
	p[DESC]	=	"Current server time in 24-hour format.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"servertime";
	p[REM]	=	"Will return the times as 'VAL{HH:MM}' Where HH is based on the 24hour clock.";
	p[EX]	=	nil;
	p[REF]	=	{"%ServerTime12%", "%WeekDay%", "%LocalTime%", "%LocalTime12%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"ServerTime12";
	p[DESC]	=	"Current server time in AM/PM format.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"servertime12";
	p[REM]	=	"Will return the times as 'VAL{HH:MM AM/PM}' Where HH is based on the 12hour clock.";
	p[EX]	=	nil;
	p[REF]	=	{"%ServerTime%", "%WeekDay%", "%LocalTime%", "%LocalTime12%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"WatchedFactionName";
	p[DESC]	=	"Name of the faction shown on the experience bar.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"watchedfactionname";
	p[REM]	=	"Will return the name of the faction marked to show on your experience bar. If nothing is watched it will return an empty string.";
	p[EX]	=	'OnEvent("Slash", "rep") THEN Report("print", "reputation", "%WatchedFactionName%");';
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"Weekday";
	p[DESC]	=	"Day of the week.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"weekday";
	p[REM]	=	"Will return the current day of the week (localized).";
	p[EX]	=	nil;
	p[REF]	=	{"%ServerTime%", "%ServerTime12%", "%LocalTime%", "%LocalTime12%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"BossName";
	p[DESC]	=	"Name of the boss you are currently engaged in combat with.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"bossname";
	p[REM]	=	"This variable will not always work. This is because there is no single way to determine if you are fighting a boss or not.TAB{}Especially in low level instances like the Stormwind Stockade, (Hogger).The variable will in those cases return empty string.TAB{}Also note that scenarios do not have bosses.TAB{}The variable will try the following tactics:TAB{}    -It will return empty string if you are not in in combat.TAB{}    -Does the unitstrings 'boss1', 'boss2' etc return a value?TAB{}    -Does the name of your current target/focus/mouseover exist in the encounter journal? (ignores other players)TAB{}    -If you are in a raid/party; Does anyone of the other groupmembers have a target that is found in the encounter journal?TAB{}    -If the addon 'Deadly Boss Mods' (DBM) or 'Voice Encounter Mods' (VEM) is installed and enabled it will attempt to use it's list of bosses to determine if you are targeting a boss.";
	p[EX]	=	'OnEvent("Chat", "Whisper") AND InInstance() AND InCombat() AND Compare("%BossName%", "", "neq") THEN Reply("Automated reply: Currently fighting %BossName% in %InstanceName%");';
	p[REF]	=	{"IsBoss()::argument"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EnabledEquipmentSet";
	p[DESC]	=	"Name of the equipmentset currently equipped.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"enabledequipmentset";
	p[REM]	=	"Will return the name of the equipmentset currently equipped or an empty string.";
	p[EX]	=	nil;
	p[REF]	=	{"EnableEquipmentSet()::action"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentMainhand";
	p[DESC]	=	"Link for the equipped item in the main hand slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmentmainhand";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentOffhand";
	p[DESC]	=	"Link for the equipped item in the offhand slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmentoffhand";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentHead";
	p[DESC]	=	"Link for the equipped item in the head slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmenthead";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentNeck";
	p[DESC]	=	"Link for the equipped item in the neck slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmentneck";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentShoulder";
	p[DESC]	=	"Link for the equipped item in the shoulder slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmentshoulder";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentBack";
	p[DESC]	=	"Link for the equipped item in the back slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmentback";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentChest";
	p[DESC]	=	"Link for the equipped item in the chest slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmentchest";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentShirt";
	p[DESC]	=	"Link for the equipped item in the shirt slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmentshirt";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentTabard";
	p[DESC]	=	"Link for the equipped item in the tabard slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmenttabard";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentWrist";
	p[DESC]	=	"Link for the equipped item in the wrist slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmentwrist";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentHands";
	p[DESC]	=	"Link for the equipped item in the hands slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmenthands";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentWaist";
	p[DESC]	=	"Link for the equipped item in the waist slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmentwaist";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentLegs";
	p[DESC]	=	"Link for the equipped item in the legs slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmentlegs";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentFeet";
	p[DESC]	=	"Link for the equipped item in the feet slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmentfeet";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentFinger1";
	p[DESC]	=	"Link for the equipped item in the first finger slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmentfinger1";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentFinger2";
	p[DESC]	=	"Link for the equipped item in the second finger slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmentfinger2";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentTrinket1";
	p[DESC]	=	"Link for the equipped item in the first trinket slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmenttrinket1";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"EquipmentTrinket2";
	p[DESC]	=	"Link for the equipped item in the second trinket slot";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"equipmenttrinket2";
	p[REM]	=	"@EQUIPMENTREM@";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------


	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"GroupCount";
	p[DESC]	=	"Number of players in your instancegroup, party, raid or battleground.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[0;40]";
	p[RET]	=	"groupcount";
	p[REM]	=	"Will return 0 if you are not grouped";
	p[EX]	=	nil;
	p[REF]	=	{"%InstanceSize%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InstanceDifficulty";
	p[DESC]	=	"Difficulty of the instance you are currently in.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"instancedifficulty";
	p[REM]	=	"Will return '".._G["PLAYER_DIFFICULTY3"].."', '".._G["PLAYER_DIFFICULTY1"].."', '".._G["PLAYER_DIFFICULTY2"].."', '".._G["PLAYER_DIFFICULTY6"].."', '".._G["PLAYER_DIFFICULTY_TIMEWALKER"].."', '".._G["CHALLENGE_MODE"].."', '".._G["GUILD_CHALLENGE_TYPE4"].."' or '".._G["HEROIC_SCENARIO"].."'. Empty string is returned if you are not in an instance.TAB{}For Arena's and Battlegrounds it will return empty string.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InstanceName";
	p[DESC]	=	"Name of the instance you are currently in.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"instancename";
	p[REM]	=	"Will return empty string if you are not in an instance";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InstanceSize";
	p[DESC]	=	"Maximum number of players allowed in the instance you are currently in.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[0;40]";
	p[RET]	=	"instancesize";
	p[REM]	=	"Will return 0 if you are not in an instance";
	p[EX]	=	nil;
	p[REF]	=	{"%GroupCount%"};
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"InstanceType";
	p[DESC]	=	"Type of instance you are currently in.";
	p[SIGN] =	false;
	p[ARG]	=	"STR[]";
	p[RET]	=	"instancetype";
	p[REM]	=	"Will return '".._G["RAID"].."', '".._G["PARTY"].."', '".._G["ARENA"].."', '".._G["BATTLEGROUND"].."', '".._G["SCENARIOS"].."' or empty string if you are not in an instance";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------

	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"StatAchievementPoints";
	p[DESC]	=	"Number of achievement points for your character.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"statachievementpoints";
	p[REM]	=	"Will return the number of achievement points you character has earned.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"StatDeaths";
	p[DESC]	=	"Total number of deaths.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"statdeaths";
	p[REM]	=	"Will return the number of times your character has died.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"StatHonorKills";
	p[DESC]	=	"Total number of honorable kills.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"stathonorkills";
	p[REM]	=	"Will return the number of honorable kills you character has done.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"StatKills";
	p[DESC]	=	"Total number of kills.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"statkills";
	p[REM]	=	"Will return the total number of kills your character has.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"StatMounts";
	p[DESC]	=	"Total number of mounts.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"statmounts";
	p[REM]	=	"Will return the total number of mounts you character has.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"StatPets";
	p[DESC]	=	"Total number of vanity pets.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"statpets";
	p[REM]	=	"Will return the total number of vanity pets you character has.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"StatToys";
	p[DESC]	=	"Total number of toys.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"stattoys";
	p[REM]	=	"Will return the number of toys you have in your toybox.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------
	-- --------------------------------------------
	p = self:CreateOnDocStruct();
	p[NAME]	=	"StatUniquePets";
	p[DESC]	=	"Number of unique pets.";
	p[SIGN] =	false;
	p[ARG]	=	"INT[]";
	p[RET]	=	"statuniquepets";
	p[REM]	=	"Will return the number of unique pets you character has.";
	p[EX]	=	nil;
	p[REF]	=	nil;
	d[strlower(VA..p[NAME])] = p;
	-- --------------------------------------------




	--[[
		NAME:	PlayerName / Itemlevel
		DESC:	Name of the player
		SIGN:	-- true (if false then it's dynamic)
		ARG:	STR[], Will be a string. OR INT[1;10000], will be a number higher than 1
		RET:	-- playername / itemlevel (used to hold argumentvalue passed to env-function)
		REM:	This variable will always be the name of the logged in player. / This is a numerical value
		EX:		IF Compare("%TargetName%", "%playername%") THEN Print("i am targeting myself");
		REF:	Compare(), IsDead()
		MIN:	-- not needed since its always 1
		MAX:	-- not needed since its always 1
		PTR:	-- dont need a function pointer since we plan on having just 1 function for all env-variables.
	]]--

	-- --------------------------------------------
	--d = self:doEscaping(d);
	cache_DeclareDocumentation = d;	--store in cache for later re-use
	return cache_DeclareDocumentation;
end



function Documentation:DeclareEscaping()
	if (cache_DeclareEscaping ~= nil) then return cache_DeclareEscaping end
	local d = {};
	--Here we use an array which will let us replace the string in a specific order.

	--Placeholders:
	--  Text replacements
	--d[#d+1] = {"@DEPRECATED@",	"TAB{}|cffc30000This function is deprecated and should no longer be used as it might be removed in future versions.|rTAB{}TAB{}"};
	--d[#d+1] = {"@REMOVED@",		"TAB{}|cffc30000This function has been removed from the API, and is no longer available.|rTAB{}TAB{}"};
	d[#d+1] = {"@TRUEFALSE@",		"Returns true or false."};
	d[#d+1] = {"@TRUE@",			"Always returns true."};
	d[#d+1] = {"@INDEX@",			"'VAL{1}', 'VAL{2}', 'VAL{3}' or 'VAL{4}'"};
	d[#d+1] = {"@SECOND@",			"Must be between VAL{1} and VAL{600}"};
	d[#d+1] = {"@MINUTE@",			"Must be between VAL{0} and VAL{59}"};
	d[#d+1] = {"@HOUR@",			"Must be between VAL{0} and VAL{23}"};
	d[#d+1] = {"@BOOL@",			"'VAL{true}' or 'VAL{false}'"};
	d[#d+1] = {"@OP@",				"'VAL{eq}' (default), 'VAL{gt}', 'VAL{lt}', 'VAL{gte}', 'VAL{lte} or 'VAL{neq}'"};
	d[#d+1] = {"@COMPARE@",			"'VAL{StartsWith}', 'VAL{IndexOf}' or 'VAL{Exact}' (default)"};
	d[#d+1] = {"@UNIT@",			"'VAL{player}', 'VAL{target}', 'VAL{focus}', 'VAL{pet}'"};
	d[#d+1] = {"@UNIT2@",			"'VAL{player}', 'VAL{target}' or 'VAL{focus}'"};	--this the same as @UNIT@ but is without 'pet' since it makes no sense to have it supported for some functions
	d[#d+1] = {"@UNIT3@",			"'VAL{target}' or 'VAL{focus}'"}; 					--this the same as @UNIT@ but is without 'player' and 'pet' since it makes no sense to have it supported for some functions
	d[#d+1] = {"@UNIT4@",			"'VAL{group}', 'VAL{player}', 'VAL{target}', 'VAL{focus}', 'VAL{pet}'"};
	d[#d+1] = {"@DEFAULTUNIT@",		"'VAL{player}'"};
	d[#d+1] = {"@DEFAULTUNIT3@",	"'VAL{target}'"};
	d[#d+1] = {"@EVENTCHANNEL@",	"'VAL{guild}', 'VAL{instance}', 'VAL{officer}', 'VAL{party}', 'VAL{raid}', 'VAL{yell}', 'VAL{say}', 'VAL{group}', 'VAL{whisper}', 'VAL{battle.net}', 'VAL{system}' or a channel name/number."};
	d[#d+1] = {"@CHATCHANNEL@",		"'VAL{afk}', 'VAL{dnd}', 'VAL{emote}', 'VAL{guild}', 'VAL{instance}', 'VAL{officer}', 'VAL{party}', 'VAL{raid}', 'VAL{raid_warning}', 'VAL{yell}', 'VAL{say}', 'VAL{print}', 'VAL{group}' or a channel name/number."};
	d[#d+1] = {"@REPORTCHANNEL@",	"'VAL{afk}', 'VAL{dnd}', 'VAL{emote}', 'VAL{guild}', 'VAL{instance}', 'VAL{officer}', 'VAL{party}', 'VAL{raid}', 'VAL{raid_warning}', 'VAL{yell}', 'VAL{say}', 'VAL{print}', 'VAL{group}', 'VAL{reply}' or a channel name/number."};
	d[#d+1] = {"@REPLY@",			"You can use Reply() to send a whisper to the player that triggered the event. You can also use the variable '%%replyName%%' in chat-messages and similar to insert the players name."};
				--Black (ff000000) is written instead  with white color (ffFFFFFF) so that its visible against the morehelp window background
	d[#d+1] = {"@COLOR1@",			"|cff00ffffAqua|r, |cffFFFFFFBlack|r, |cff0000ffBlue|r, |cffff00ffFuchsia|r, |cff808080Gray|r, |cff008000Green|r, |cff00aa00LightGreen|r, |cff00ff00Lime|r, |cff800000Maroon|r, |cff000080Navy|r, |cff808000Olive|r, |cff800080Purple|r, |cffc30000Red|r, |cffc0c0c0Silver|r, |cFF008080Teal|r, |cffffffffWhite|r, |cffffff00Yellow|r, |cffd4a017Gold|r"};
	d[#d+1] = {"@COLOR2@",			"|cff9d9d9dPoor|r, |cffffffffCommon|r, |cff1eff00Uncommon|r, |cff0070ddRare|r, |cffa335eeEpic|r, |cffff8000Legendary|r, |cffe6cc80Artifact|r, |cffe6cc80Heirloom|r"};
	d[#d+1] = {"@COLOR3@",			"|cffc41f3bDeathKnight|r, |cffa330c9Demon Hunter|r, |cffff7d0aDruid|r, |cffabd473Hunter|r, |cff69ccf0Mage|r, |cff00ff96Monk|r, |cfff58cbaPaladin|r, |cffffffffPriest|r, |cfffff569Rogue|r, |cff0070deShaman|r, |cff9482c9Warlock|r, |cffc79c6eWarrior|r"};
	d[#d+1] = {"@DEFAULTCOLOR@",	"|cffc30000Red|r"};
	d[#d+1] = {"@MARK@",			"'VAL{star}', 'VAL{circle}', 'VAL{diamond}', 'VAL{triangle}', 'VAL{moon}', 'VAL{square}', 'VAL{cross}', 'VAL{skull}' or 'VAL{none}'"};
	d[#d+1] = {"@EQUIPMENTREM@",	"Will return empty string or a link for the equipped item."};

	--Data types:
	--		These are some shortcuts to simplify the documentation, they all go back to INT[] and STR[]
	d[#d+1] = {"INDEX[]",		"INT[1;2;3;4]"};					--index is used by talent-spec functions
	d[#d+1] = {"SECOND[]",		"INT[1;600]"};						--second interval is from 1 to 600 seconds
	d[#d+1] = {"MINUTE[]",		"INT[0;59]"};						--minute interval is from 0 to 59 hours
	d[#d+1] = {"HOUR[]",		"INT[0;23]"};						--hour interval is from 0 to 23 hours
	d[#d+1] = {"BOOL[]",		"STR[true;false]"};					--boolean
	d[#d+1] = {"OP[]",			"STR[eq;gt;lt;gte;lte;neq]"};		--operators
	d[#d+1] = {"COMPARE[]",		"STR[startswith;indexof;exact]"};	--comparison operator
	d[#d+1] = {"UNIT[]",		"STR[player;target;focus;pet]"};	--unitid's
	d[#d+1] = {"UNIT2[]",		"STR[player;target;focus]"}; 		--this the same as UNIT[] but is without 'pet' since it makes no sense to have it supported for some functions
	d[#d+1] = {"UNIT3[]",		"STR[target;focus]"}; 				--this the same as UNIT[] but is without 'player' and 'pet' since it makes no sense to have it supported for some functions
	d[#d+1] = {"UNIT4[]",		"STR[group;player;target;focus;pet]"};
	d[#d+1] = {"COLOR[]",		"STR[aqua;black;blue;fuchsia;gray;green;lightgreen;lime;maroon;navy;olive;purple;red;silver;teal;white;yellow;gold;poor;common;uncommon;rare;epic;legendary;artifact;heirloom;deathknight;demonhunter;druid;hunter;mage;monk;paladin;priest;rogue;shaman;warlock;warrior]"}; --color
	d[#d+1] = {"MARK[]",		"STR[star;circle;diamond;triangle;moon;square;cross;skull;none]"};	--raid markers

	--These must be at the end since there are other strings that also use curly bracers {}
	--		Color escaping for REQ{Required}, OPT{Optional} and , VAL{Values} Must be done at the end of the list in a specific order. that is why we use an array
	d[#d+1] = {"TAB{}TAB{}","\n\n"..TAB};	--inline tab-spacing over 2 lines
	d[#d+1] = {"TAB{}",		"\n"..TAB};		--inline tab-spacing
	d[#d+1] = {"VAL{",		CONST_cVAL};	--Color for Values
	d[#d+1] = {"REQ{",		CONST_cREQ};	--Color for Required
	d[#d+1] = {"OPT{",		CONST_cOPT};	--Color for Optional
	d[#d+1] = {"}",			"|r"};			--reset coloring

	cache_DeclareEscaping = d;
	return cache_DeclareEscaping;
end

--####################################################################################
--####################################################################################