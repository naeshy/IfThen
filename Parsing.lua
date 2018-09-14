--####################################################################################
--####################################################################################
--Lexical Parser
--####################################################################################
--Dependencies: StringParsing.lua, Methods.lua, Documentation.lua

local Parsing	= {};
Parsing.__index	= Parsing;
IfThen_Parsing	= Parsing; --Global declaration

local StringParsing	= IfThen_StringParsing;	--Local pointer
local Methods		= IfThen_Methods; 		--Local pointer
local Documentation	= IfThen_Documentation;	--Local pointer
--local IfThen		= IfThen_IfThen;	 	--Local pointer


--Local variables that cache stuff so we dont have to recreate large objects
local cache_getMethodList			= nil;	--Table with all methods
local cache_getOnEventList			= nil;	--Table with all events
local cache_getVarList_Static		= nil;	--Table with all static variables
local cache_getVarList_Dynamic		= nil;	--Table with all dynamic variables
local cache_parsed_if				= nil;	--Parsed array (IF statements)
local cache_parsed_event			= nil;	--Parsed array (OnEvent statements)
local cache_macroBlocks				= nil;	--Array or nil, list of current macro blocks, is reset to nil by ParseText()
local cache_parsed_if_varlist		= nil;	--Array of dynamic variables used with IF statements		(this array only contains those variables that are used by cache_parsed_if)
local cache_parsed_event_varlist	= nil;	--Array of dynamic variables used with OnEvent statements	(this array only contains those variables that are used by cache_parsed_event)
local cache_parsed_errors			= nil;	--Nil or table with parsing errors
local cache_emptyTable				= {};	--pointer to an empty table, this is used so we all refer to the same address and dont waste memory


--Shorthand aliases for all the key's in the DocStruct
local NAME	= "shortname";		--name of event
local ARG	= "arguments";		--{TYPE, BUFFNAME -Description of the argument, ...}
local WOW	= "wowevent";		--ingame event
local VALARG= "argumentvalue";	--argument passed to value-lookup function
local TYPE	= "functype";		--type of method (argument, action, action_macro)
local MAX	= "maxarguments";	--Maximum number of arguments
local MIN   = "minarguments";	--Minimum number of arguments
local PTR   = "pointer";		--pointer to the function


--Local pointers to global functions
local tonumber	= tonumber;
local tostring	= tostring;
local pairs		= pairs;
local strlen	= strlen;
local strfind	= strfind;
local strsub	= strsub;
local strlower	= strlower;
local strupper	= strupper;
local strchar	= strchar;
local strtrim	= strtrim;	--string.trim
local tinsert	= tinsert;	--table.insert
local sort		= sort;		--table.sort
local select	= select;

--####################################################################################
--####################################################################################


--Removes functions that are not needed after initial startup.
function Parsing:CleanUp()
	self:getMethodList(); --Make sure this has been called before we remove anything
	self:getOnEventList();
	self:getVarList();
	local d = {"getMethodList_Declare", "getOnEventList_Declare", "getVarList_Declare"};
	for i=1, #d do self[d[i]] = nil; end --for
	return nil;
end


---Return a list of all the methods supported, their function and their description
function Parsing:getMethodList()
	if (cache_getMethodList ~= nil) then return cache_getMethodList end --if the array is cached from earlier call then return that
	return self:getMethodList_Declare();
end
function Parsing:getMethodList_Declare()
	--if (cache_getMethodList ~= nil) then return cache_getMethodList end --if the array is cached from earlier call then return that

	--We retreive all the functions from Documentation.lua
	--'NOT' is simply implemented by adding it as a prefix for all the methods that support it and putting a wrapper method around its returned result.
	local m = {};

	local dArg = Documentation:getMethodList("argument");
	local dAtm = Documentation:getMethodList("action macro");
	local dAct = Documentation:getMethodList("action");
	local dFnc = Documentation:getMethodList("function");

	local strlower	= strlower; --local fpointer
	local tinsert	= tinsert;

	local objArg = nil;
	local d = dArg;
	for i=1, #d do
		--name, pointer, max, min, arguments, type
		objArg = self:getDataTypes(d[i][ARG]); --we trim away the descriptions from the Arguments-array
		tinsert(m, {[NAME]=strlower(d[i][NAME]), [PTR]=d[i][PTR], [MAX]=d[i][MAX], [MIN]=d[i][MIN], [ARG]=objArg, [TYPE]="argument"});
		--We implement NOT by negating the function result and prepending 'not ' to the title (NOTE: declaring FuncPTR outside the loop will cause it to fail)
		local FuncPTR = d[i][PTR]; --must output it into a local variable before we insert it into the function
		tinsert(m, {[NAME]="not "..strlower(d[i][NAME]), [PTR]=function(s,n) return (not FuncPTR(s,n)) end, [MAX]=d[i][MAX], [MIN]=d[i][MIN], [ARG]=objArg, [TYPE]="argument not"});
	end--for

	d = dAtm;
	for i=1, #d do
		--name, pointer, max, min, arguments, type
		objArg = self:getDataTypes(d[i][ARG]); --we trim away the descriptions from the Arguments-array
		tinsert(m, {[NAME]=strlower(d[i][NAME]), [PTR]=d[i][PTR], [MAX]=d[i][MAX], [MIN]=d[i][MIN], [ARG]=objArg, [TYPE]="action macro"});
	end--for

	d = dAct;
	for i=1, #d do
		--name, pointer, max, min, arguments, type
		local booFound = false; --make sure that the action-macro functions are not added twice to the list
		for j=1, #dAtm do
			if (dAtm[j][NAME] == d[i][NAME]) then booFound = true; break; end
		end--for j
		if (booFound==false) then
			objArg = self:getDataTypes(d[i][ARG]); --we trim away the descriptions from the Arguments-array
			tinsert(m, {[NAME]=strlower(d[i][NAME]), [PTR]=d[i][PTR], [MAX]=d[i][MAX], [MIN]=d[i][MIN], [ARG]=objArg, [TYPE]="action"});
		end--if
	end--for

	--This should contain only 1 function and that is OnEvent(). These are functions that are implemented, but not visible for the user in morehelp
	d = dFnc;
	for i=1, #d do
		--name, pointer, max, min, arguments, type
		objArg = self:getDataTypes(d[i][ARG]); --we trim away the descriptions from the Arguments-array
		tinsert(m, {[NAME]=strlower(d[i][NAME]), [PTR]=d[i][PTR], [MAX]=d[i][MAX], [MIN]=d[i][MIN], [ARG]=objArg, [TYPE]="function"});
	end--for

	cache_getMethodList = m; --update cache
	return m;
end


---Return a list of all the OnEvent events supported, their function and their description
function Parsing:getOnEventList()
	if (cache_getOnEventList ~= nil) then return cache_getOnEventList end --if the array is cached from earlier call then return that
	return self:getOnEventList_Declare();
end
function Parsing:getOnEventList_Declare()
	if (cache_getOnEventList ~= nil) then return cache_getOnEventList end --if the array is cached from earlier call then return that
	local m = {};

	local RET	= "returns"; --we use this field to store the WOW eventname in the docstruct, we switch to the WOW field in Parsing.lua

	local strlower	= strlower; --local fpointer
	local tinsert	= tinsert;

	local d = Documentation:getMethodList("event");
	for i=1, #d do
		--name, woweventname, pointer, max, min, arguments
		local objArg = self:getDataTypes(d[i][ARG]); --we trim away the descriptions from the Arguments-array
		tinsert(m, {[NAME]=strlower(d[i][NAME]), [WOW]=d[i][RET], [PTR]=d[i][PTR], [MAX]=d[i][MAX], [MIN]=d[i][MIN], [ARG]=objArg});
	end--for

	cache_getOnEventList = m; --update cache
	return m;
end


---Return a list of all the Variables supported, their value and their datatype
function Parsing:getVarList(isStatic)
	if (isStatic == true  and cache_getVarList_Static  ~= nil) then return cache_getVarList_Static  end --if the array is cached from earlier call then return that
	if (isStatic == false and cache_getVarList_Dynamic ~= nil) then return cache_getVarList_Dynamic end
	return self:getVarList_Declare(isStatic);
end
function Parsing:getVarList_Declare(isStatic)
	local mS = {};	--Static
	local mD = {};	--Dynamic

	local RET	= "returns";	--we use this field to store the argument-value that will passed to the lookup function, we switch to the VALARG field in Parsing.lua
	local SIGN	= "signature";	--we use this field to store a Boolean. True == Static values that can be replaced at parsetime, False == Dynamic value that must be replaced at runtime
	--Unlike with methods, and events, then ARG here is a string with the datatype of the variable (STR[], INT[])

	local strlower	= strlower; --local fpointer

	local d = Documentation:getMethodList("variable");
	for i=1, #d do
		--%name%, value-lookup argument, datatype
		--[[
		if (d[i][SIGN] == true) then	tinsert(mS, {[NAME]=strlower(d[i][NAME]), [VALARG]=d[i][RET], [ARG]=d[i][ARG]});
		else							tinsert(mD, {[NAME]=strlower(d[i][NAME]), [VALARG]=d[i][RET], [ARG]=d[i][ARG]}); end
		]]--

		--Unlike methods and events, we store this in a key/value format for faster lookup on variable names later.
		local strKey	= strlower(d[i][NAME]);
		local tblValue	= {[VALARG]=d[i][RET], [ARG]=d[i][ARG]};

		if (d[i][SIGN] == true) then	mS[strKey] = tblValue;
		else 							mD[strKey] = tblValue; end
	end--for

	cache_getVarList_Static	 = mS; --update cache
	cache_getVarList_Dynamic = mD;

	if (isStatic == true) then return mS end
	return mD;
end


--Return a list of all the OnEvent events that the currently parsed structure contains
function Parsing:getCurrentEventList()
	local list = cache_parsed_event;
	if (list == nil) then return nil end

	local ev  = self:getOnEventList();
	local res = {};
	local tinsert = tinsert; --local fpointer

	for i=1, #ev do
		local eventName = ev[i][WOW];	--World of Warcraft EventName
		if (list[eventName] ~= nil) then tinsert(res, ev[i]) end
	end--for i

	if (#res == 0) then return nil end
	return res;
end


--Receives the arguments-array part from a DocStruct object and removes everything but the Datatypes from it.
function Parsing:getDataTypes(arrArguments)
	if (arrArguments == nil or #arrArguments == 0) then return arrArguments end
	--A DocStruct ARG elements is an array like this:
	--		{ TYPE1, Description1, TYPE2, Description2, TYPE3, Description3... }
	--We will remove the Descriptions and return only the TYPE's

	local d = {};
	local tinsert = tinsert; --local fpointer
	for i=1, #arrArguments, 2 do
		tinsert(d, arrArguments[i]);
	end--for
	return d;
end


--Return a list of all the OnEvent("Slash") titles that the currently parsed structure contains
function Parsing:getCurrentSlashList()
	local list = cache_parsed_event;
	if (list == nil) then return nil; end

	local ev = list["IFTHEN_SLASH"];
	if (ev == nil) then return nil; end
	ev = ev[1]; --This event (IFTHEN_SLASH) only got 1 subevent so we hardcode that in here
	local res = {};
	local tinsert = tinsert; --local fpointer

	for i=3, #ev do
		--element 1 and 2 contains ifthen event title and event handler so we skip those first two
		for j=1, #ev[i] do
			--for each subelement ( {event-arguments}, pointer1, {pointerarguments1}, pointerN, {pointerargumentsN}... )
			local title = ev[i][j][2]; --table {"slash", "title"}
			title 		= StringParsing:capitalizeWords(title, "AaaBbb"); --Capitalize first letter of every word
			tinsert(res, title);
			break; --We are only interested in the first element of each subevent so we skip iterating over the rest
		end--for j
	end--for i

	if (#res == 0) then return nil end
	sort(res);	--Alphabetical sorting
	return res;	--This result is not cached since it probably will not make sense to cache such a little thing.
end


--Return an array of all the names of the MacroBlocks that the currently parsed structure contains
function Parsing:getCurrentMacroBlocks()
	--This data is cached since it will be asked for multiple times when MacroRefresh is enabled.
	if (cache_macroBlocks ~= nil) then return cache_macroBlocks; end --Reset by ParseText()

	local list = cache_parsed_if;
	if (list == nil) then return nil; end

	local res = {};
	local tinsert	= tinsert; --local fpointer
	local pairs		= pairs;

	for k,v in pairs(list) do
		tinsert(res,k);
	end--for k,v
	if (#res == 0) then return nil end
	cache_macroBlocks = res;
	return cache_macroBlocks;
end


--####################################################################################
--####################################################################################
--Processing of conditions and lines
--####################################################################################


function Parsing:Process_If(macroBlock)
	if (macroBlock == nil or cache_parsed_if == nil) then return nil; end
	local list = cache_parsed_if[macroBlock]; --local ref
	if (list == nil) then return nil; end

	for i=1, #list do
		local line			= list[i];
		local badLine		= false; --flag to tell us whether a whole line returned TRUE
		local resetMacro	= false; --flag to tell us whether to reset the macro or not
		local booOR 		= false;
		local intOR			= 0;

		for j=1, #line, 5 do --iterate 5 elements at a time
			local m_function	= line[j]; 		--function pointer
			local m_args		= line[j+1];	--argument table
			local m_name		= line[j+2];	--plain string function name
			local m_type		= line[j+3];	--plain string function type
			local m_var			= line[j+4];	--boolean. dynamic variables present (true, then we must parse and replace before calling function with arguments)
			local m_result		= nil;			--will contain the result of the function call

			if (m_var == true and #m_args > 0) then--if the arguments contain dynamic variables then we iterate though them all and expand them now
				local tmpArg = {};
				for tmpI=1, #m_args do
					tmpArg[tmpI] = self:doVarReplacement(m_args[tmpI], cache_parsed_if_varlist);
				end--for tmpI
				m_args = tmpArg; --we use a temp variable so that we dont overwrite the data in cache_parsed_*
			end--if m_var

			if (intOR == 0) then booOR = false end --reset flag when we are done

			if (m_name=="OR") then
				--We use a prefix style style parsing
				--			IF a OR b OR c will be parsed into: OR a OR b c
				--			IF a OR b will be parsed into: OR a b
				if (intOR == 0) then
					intOR = 2;			--This is an 'OR [statement] [statement]' or atleast the first OR we have encountered and that is always between 2 statements
					booOR = false;		--this is a brand new independent OR in the line and we reset our flag
				else
					intOR = intOR +1;	--'This is an 'OR [statement] OR [statement] [statement]' this is the second or more OR's in a sequence and we just increase the OR counter with 1
					--booOR = false;	--the flag can not be reset since this OR is still in progress
				end--if
				--this is just an OR marker so we skip until the next iteration
			else
				if (m_name=="cooldown") then Methods:SetCoolDownToken("if_line_"..i.."_part_"..j.."_block_"..macroBlock.."_token", m_args) end --sets a unique token that is used by Methods:do_Cooldown() to identify the line and statement we are at
				if (m_type == "action macro") then resetMacro = true end	--the function just modified the macro

				if (intOR == 0) then
					--regular call
					if (resetMacro==true) then Methods:do_SetMacroName(macroBlock); end --set macroName just before and reset it just after the method is invoked (prevent race-condition)
					m_result = m_function(Methods, m_args);	--run the function and get the result
					if (resetMacro==true) then Methods:do_SetMacroName(nil); end

				else
					--this in an OR call
					if (intOR > 0) then intOR = intOR -1 end --decrement OR counter with 1
					if (booOR == true) then
						--if the previous [statement] which is part of the OR evaluated to true then we skip this statement (short circuit OR evaluation) and continue to the next part of the line
						m_result = true;
					else
						if (resetMacro==true) then Methods:do_SetMacroName(macroBlock); end
						m_result = m_function(Methods, m_args);	--the previous statement evaluated to false, lets see if this one becomes true...
						if (resetMacro==true) then Methods:do_SetMacroName(nil); end
						if (m_result == true) then booOR = true end --if the function returned true and this is an OR statement then remember the result so we can skip later statements
						if (m_result == false and intOR > 0) then m_result = true end --set it to true so that we can iterate through the rest of the OR's without failing
					end--if booOR
				end--if intOR

				if (not (m_result == true or m_result == false)) then
					--if the function returns neither true or false then something's wrong in the method itself
					IfThen:msg_error("The method '"..m_name.."' returned the value '"..tostring(m_result).."'. It shold have either returned TRUE or FALSE.");
					badLine = true;
					break;
				end--if

				if (m_result == false) then	--stop processing this line and go to the next one
					badLine=true;
					break;
				end--if
			end--if OR
		end --for j

		--If we reach here and the line failed then we will reset the macro if it was modified
		--Otherwise we might get scenarios that a /case from a failed, earlier processed line will be done, when only a later line's /whisper is what the user intended to do
		--the resetMacro flag will improve performance by only beign set whenever a method that actually modifies the macro has been executed (so we dont have to rewrite the macro N times, where N = number of lines)
		if (badLine == true and resetMacro == true) then
			Methods:do_SetMacroName(macroBlock);--set macroName just before and reset it just after the method is invoked (prevent race-condition)
			Methods:do_Nothing(nil);			--will rewrite the macro to do nothing (no /use and no /cast)
			Methods:do_SetMacroName(nil);
		end

		--if we reach here then that can mean that all the functions on the line returned TRUE, and we stop processing of all further lines
		--if (badLine == false) then return nil end --return immediatly
		if (badLine == false) then
			if (resetMacro == false) then
				Methods:do_SetMacroName(macroBlock);--set macroName just before and reset it just after the method is invoked (prevent race-condition)
				Methods:do_Nothing(nil);
				Methods:do_SetMacroName(nil);
			end --if we got a good line and it didnt modify the macro then we reset the macro incase it was already changed on the preceeding buttonpress
			return nil;
		end --return immediatly

	end --for i

	--If we reach here then none of the lines evaluated to true so we just tell the macro to do nothing. This so that we dont accidentally /use or /cast whatever the previously executed line put in there
	--	If this call to Parsing:process_All is triggered by an 'event' then we dont want that event to reset the macro.
	--	When we didnt have this if-statement then what happened was the following:
	--[[
		 the user pressed the button
			--> rewrites macro to use item
				--> macro uses item on npc
		 --> OnEvent() triggers
			--> rewrites macro to /nil  (just before macroediting is locked by combat i guess)
		user is by now in combat and the macro is locked to nil;
		the user presses the button a second time
			--> error message about incombat + macro edit = false
	]]--
	Methods:do_SetMacroName(macroBlock);--set macroName just before and reset it just after the method is invoked (prevent race-condition)
	Methods:do_Nothing(nil);			--will rewrite the macro to do nothing (no /use and no /cast)
	Methods:do_SetMacroName(nil);

	return nil;
end



--EventArguments
function Parsing:Process_Event(EventName, ...)
	if (cache_parsed_event == nil) then return nil; end
	local event = cache_parsed_event[EventName];
	if (event == nil) then
		--if (IfThen:isDebug()) then print("The event '"..EventName.."' triggered Process_Event() no lines was found for the event.");
		return nil; --if an event got 0 lines under itself then it will be nil, we just stop processing and return nil
	end--if

	--for each subEvent for this WoW EventName...
	for t=1, #event do
		local subEvent = event[t];
		if (subEvent ~= nil) then --there might be subevents after this position in the array that we also need to look at

			--run this subEvent's eventhandler
			local event_subtitle	= subEvent[1];	--element 1 in line 1 contains the OnEvent() title to the eventhandler
			local event_handler		= subEvent[2];	--element 2 in line 1 contains the function-pointer to the eventhandler or its nil
			local event_result		= true;

			if (event_handler ~= nil) then
				local event_filter = nil; --when we call the eventhandler with nil, then that works as a coarse filter that allows us to stop processing if the event does not match anything that we want (i.e return false if PLAYER_AURA is raised for anything other than 'player','target' or 'focus'
				event_result = event_handler(Methods, event_filter, ...);

				if (not (event_result == true or event_result == false)) then
					--if the function returns neither true or false then something's wrong in the method itself
					IfThen:msg_error("The eventhandler for  '"..EventName.."' / '"..event_subtitle.."' returned the value '"..tostring(event_result).."'. It shold have either returned TRUE or FALSE.");
					break; --stop all further processing
				end--if

				--if (event_result == false) then break end --stop processing if the eventhandler returns FALSE
			end--if

			--process all the lines for this subEvent
			if (event_result == true) then
				local startI = 3; --skip the eventhandler
				for i=startI, #subEvent do
					local line		= subEvent[i];
					local badLine	= false; --flag to tell us whether a whole line returned TRUE
					local booOR		= false;
					local intOR		= 0;
					local booFirstLineIteration = true;

					for j=2, #line, 5 do --first element contains subevent filters, we iterate 5 elements at a time
						if (booFirstLineIteration) then
							if (event_handler ~= nil) then
								local event_filter = line[(j-1)]; --we have already called the event handler with a coarse filter, we now use the specific filter for this line
								if (#event_filter > 0) then
									local tmpArg = {};
									for tmpI=1, #event_filter do --expand any dynamic enviroment variables found in the filter
										tmpArg[tmpI] = self:doVarReplacement(event_filter[tmpI], cache_parsed_event_varlist);
									end--for tmpI
									event_filter = tmpArg; --we use a temp variable so that we dont overwrite the data in cache_parsed_*
								end--if #event_filter
								local event_result = event_handler(Methods, event_filter, ...);
								if (not (event_result == true or event_result == false)) then
									--if the function returns neither true or false then something's wrong in the method itself
									IfThen:msg_error("The eventhandler for  '"..EventName.."' / '"..tostring(event_filter).."' returned the value '"..tostring(event_result).."'. It shold have either returned TRUE or FALSE.");
									break; --stop all further processing
								end--if

								--stop processing this line and go to the next one
								--if (event_result == false) then break end --stop processing if the eventhandler returns FALSE
								if (event_result == false) then
									badLine = true;
									break;
								end
							end
						end --booFirstLineIteration
						booFirstLineIteration = false; --only do this first part once

						local m_function	= line[j];		--function pointer
						local m_args		= line[j+1];	--argument table
						local m_name		= line[j+2];	--plain string function name
						local m_type		= line[j+3];	--plain string function type
						local m_var			= line[j+4];	--boolean. dynamic variables present (true, then we must parse and replace before calling function with arguments)
						local m_result		= nil;			--will contain the result of the function call

						if (m_var == true and #m_args > 0) then--if the arguments contain dynamic variables then we iterate though them all and expand them now
							local tmpArg = {};
							for tmpI=1, #m_args do
								tmpArg[tmpI] = self:doVarReplacement(m_args[tmpI], cache_parsed_event_varlist);
							end--for tmpI
							m_args = tmpArg; --we use a temp variable so that we dont overwrite the data in cache_parsed_*
						end--if m_var

						if (intOR == 0) then booOR = false end --reset flag when we are done

						if (m_name=="OR") then
							--We use a prefix style style parsing
							--			IF a OR b OR c will be parsed into: OR a OR b c
							--			IF a OR b will be parsed into: OR a b
							if (intOR == 0) then
								intOR = 2;			--This is an 'OR [statement] [statement]' or atleast the first OR we have encountered and that is always between 2 statements
								booOR = false;		--this is a brand new independent OR in the line and we reset our flag
							else
								intOR = intOR +1;	--'This is an 'OR [statement] OR [statement] [statement]' this is the second or more OR's in a sequence and we just increase the OR counter with 1
								--booOR = false;	--the flag can not be reset since this OR is still in progress
							end--if
							--this is just an OR marker so we skip until the next iteration
						else
							if (m_name=="cooldown") then Methods:SetCoolDownToken("event_"..event_subtitle.."_line_"..i.."_part_"..j.."_token", m_args) end --sets a unique token that is used by Methods:do_Cooldown() to identify the line and statement we are at

							if (intOR == 0) then
								--regular call
								m_result = m_function(Methods, m_args);	--run the function and get the result
							else
								--this in an OR call
								if (intOR > 0) then intOR = intOR -1 end --decrement OR counter with 1
								if (booOR == true) then
									--if the previous [statement] which is part of the OR evaluated to true then we skip this statement (short circuit OR evaluation) and continue to the next part of the line
									m_result = true;
								else
									m_result = m_function(Methods, m_args);	--the previous statement evaluated to false, lets see if this one becomes true...
									if (m_result == true) then booOR = true end --if the function returned true and this is an OR statement then remember the result so we can skip later statements
									if (m_result == false and intOR > 0) then m_result = true end --set it to true so that we can iterate through the rest of the OR's without failing
								end--if booOR
							end--if intOR

							if (not (m_result == true or m_result == false)) then
								--if the functions returns neither true or false then something's wrong in the method itself
								IfThen:msg_error("The method '"..m_name.."' returned the value '"..tostring(m_result).."'. It shold have either returned TRUE or FALSE.");
								badLine = true;
								break;
							end

							if (m_result == false) then	--stop processing this line and go to the next one
								badLine=true;
								break;
							end--if
						end--if OR

					end --for j

					--if we reach here then that can mean that all the functions on the line returned TRUE, and we stop processing of all further lines
					--NOTE: we use 'break' here instead of 'return nil', since the outer loop can contain more subevents that needs to be iterated though. The result is the same; 1 line per subevent is executed
					if (badLine == false) then break end
					--[[
					We DO break here, so only 1 true statement is allowed per subevent, this makes the behavior consistent with the behavior when using a macro press
					--		We disable the breaking at the first TRUE line in OnEvent(). Thereby, all the TRUE lines for an subevent is executed and not just the first match
					--		This makes sense here since the reason we only allow 1 line is mostly because of IF and the /use, /cast issue with macros.
					]]--

				end --for i
			end --if event_result
		end --if subevent ~= nil
	end--for t

	return nil;
end


--####################################################################################
--####################################################################################
--Support functions for parsing of text
--####################################################################################
--####################################################################################


--Creates a table with all the OnEvent's in it
function Parsing:CreateOnEventStruct()
	--Creates a table with all the eventnames as key's
	--It will also add the event's eventhandler-function as the first element into the table
	local ev = self:getOnEventList();
	local s = {};
	local tinsert = tinsert; --local fpointer

	--Some OnEvent's (ItemEquipped, ItemUnEquipped) are using the same WoW Events (PLAYER_EQUIPMENT_CHANGED) there is therefore not a one-to-one mapping between these.
	--Because of this we need to create a treestructure where WoW events are topmost
	for i=1, #ev do
		local eventName = ev[i][WOW];	--World of Warcraft EventName
		if (s[eventName] == nil) then s[eventName] = {} end

		local subEvent	= ev[i][NAME];	--OnEvent eventnames
		local pointer	= ev[i][PTR];	--nil or reference to a eventhandler function

		--local sub = {};
		--tinsert(sub, {subEvent, pointer}); --Creates a sub-array inside the element
		--		whether it points to nil or a function we don't care about here. We will set the whole element to nil after the parsing if no lines exists for a specific event so that its more efficient when executing

		--insert this Onevent subevent at the bottom of the list of subevents
		tinsert(s[eventName], {subEvent, pointer});
	end--for
	return s;
end


--Remove empty entries from the OnEvent table
function Parsing:TrimOnEventStruct(EventStruct)
	--Iterates through the eventStrcuture and sets any entries that got 0 lines to nil
	local ev = self:getOnEventList();
	local s  = EventStruct;

	for i=1, #ev do
		local eventName	= ev[i][WOW]; --World of Warcraft EventName
		local subTree	= s[eventName];
		local allEmpty	= true;

		if (subTree ~=nil) then	--if we have removed the WoW event on a previous iteration then we might get nil
			for j=1, #subTree do
				--if (subTree[j] == nil) then dump(eventName,true); dump(j,true); dump(subTree,true); return nil; end
				if (subTree[j] ~=nil) then	--if we have removed the sub-event on a previous iteration then we might get nil
					if (#subTree[j] == 2) then
						--	Only 2 elements in the array, (that will be the title & pointer to the eventhandler)
						--	Since there are no actual lines for this event we just set the whole thing to nil
						s[eventName][j] = nil;
					else
						allEmpty = false; --if one of the subtree(s) has more than 1 line in it then we cant clear the whole tree
					end--if
				end--if
			end--for j
		end--if (subTree ~=nil)

		--If there are no filled subtree's then clear the whole subtree
		if (allEmpty == true) then s[eventName] = nil end
	end --for i

	return s;
end


--Returns nil or a string with the name for the Macro-block: MacroStart("Name")
function Parsing:isMacroStart(strPart)
	--Expects a part that looks like this 'MacroStart("foo");'
	local part = strtrim(strlower(strPart));
	if (strlen(part) == 0) then return nil; end
	if (StringParsing:startsWith(part, 'macrostart(') == false) then return nil; end

	part = StringParsing:removeAtStart(part, 'macrostart(', false);	-- macrostart(

	local i = StringParsing:indexOf(part,'"',1); --find the first quote marker
	if (i == nil) then return nil; end
	local j = StringParsing:indexOf(part,'"',i+1); --find the second quote marker after the first one
	if (j == nil) then return nil; end

	i = i+1; -- +1 and -1 for the " itself
	j = j-1;
	part = strsub(part, i, j);
	if (part == nil or strtrim(part) == "") then return nil; end
	return strtrim(part);
end


--Returns true or false if it's a MacroEnd()
function Parsing:isMacroEnd(strPart)
	--Expects a part that looks like this 'MacroEnd();'
	local part = strtrim(strlower(strPart));
	if (strlen(part) == 0) then return false; end
	if (StringParsing:startsWith(part, 'macroend(') == false) then return false end
	return true;
end


--Returns nil or WoW eventname
function Parsing:isEvent(strPart)
	--Expects a part that looks like this "OnEvent("foo")
	--We then find out which WoW eventname that is associated with 'foo'
	local part = strtrim(strlower(strPart));
	if (strlen(part) == 0) then return nil end
	if (StringParsing:startsWith(part, 'onevent("') == false) then return nil end

	part = StringParsing:removeAtStart(part, 'onevent("', false);	-- onevent("
	--part = StringParsing:replace(part, '")', '');			-- ")

	local ev = self:getOnEventList();
	for i=1, #ev do
		local title		= ev[i][NAME];		--OnEvent() title for the event
		local strTitle	= title .. '"';		--there should be a quote (") at the end of the eventname, there might also be a ") or a "," too but a single " is the common denominator
		local eventName	= ev[i][WOW];		--World of Warcraft EventName
		--if (part==title) then return {eventName, title} end
		if (StringParsing:startsWith(part,strTitle)) then
		--if (part==title) then
			local tmp		= self:parseMethod(strPart);	--use parseMethods to extract the arguments for the onevent() method (hardcoded 3 element)
			local argMax	= ev[i][MAX];						--maximum number of arguments allowed
			local argMin	= ev[i][MIN];						--minimum number of arguments allowed
			local argType	= ev[i][ARG];
			--The onEvent() is set to accept as many as 10 arguments so that any onevent() will be accepted, however in practice each event (event, not function) accepts various number of arguments
			--We therefore compare against the onevent's argumentcount here before we move on
			if (tmp == nil) then return "" end
			if (#tmp[2] >= argMin and #tmp[2] <= argMax) then
				if (self:checkDataTypes(tmp[2], argType) == false) then return "" end
				return {eventName, title, tmp[2]};
			else
				return ""; --no match found, we return empty string to signal that it was an OnEvent() statement but that no match was found
			end
		end--startsWith
	end --for

	return ""; --no match found, we return empty string to signal that it was an OnEvent() statement but that no match was found
end


--Returns nil if this isnt an OR-statement or the or the part without the 'OR' in it
function Parsing:isORStatement(part)
	--Expects a string that starts with the word 'OR'
	local n = strtrim(strlower(part));
	if (strlen(n) == 0) then return nil; end
	if (StringParsing:startsWith(n, "or ")) then
		part = strsub(part, strlen("or ")+1); --preserves the letter-casing of the rest of the part
		return part;
	end--if

	return nil;
end


function Parsing:parseMethod(part)
	local res = {nil, nil, nil, nil, nil}; --Array result hardcoded
		--element 1 is function pointer
		--element 2 is argument table {}
		--element 3 is function name as string
		--element 4 is function type
		--element 5 is true/false whether dynamic variables are in the arguments

	local nilMode = false;
	--determine the function name
	--get max argument count for function
	--split the arguments and count them
	--too many or too few arguments

	met = strtrim(strlower(part)); --case insensitive compare of methodname
	local m = self:getMethodList();	--2-dimentional array with all the accepted methodnames
										--element 1 is the methodname, element 2 is the functionpointer, element 5 is the argumentCount
	local argType = nil;
	local strlen = strlen; --local fpointer
	local strsub = strsub;

	--Just iterate through a list of items and return true if we find a match
	for i = 1, #m do
		local c	= m[i];	--first element in the sub-array will contain the methodname in lowercase
		nilMode	= false;
		if (StringParsing:startsWith(met, c[NAME].."(")) then
			res[1] = c[PTR];		--element 2 is the functionpointer of the method
			res[3] = c[NAME];		--element 1 is the methodname as string
			res[4] = c[TYPE];		--element 3 is the methodtype
			argType = c[ARG];
			if (StringParsing:startsWith(c[NAME], "onevent")) then argType = nil end --this is to prevent us from validating datatypes here
			local argMax = c[MAX];	--element 4 contains the maximum number of arguments the method supports
			local argMin = c[MIN];	--element 5 contains the minimum number of arguments the method supports
			if (argMax == 0) then nilMode = true end	--will set argument to nil if everything else works

			local strStart	= "(\"";	--use ("
			local strEnd	= "\")";	--use ")
			if (argMax == 0) then strStart	= "(" end	--use only ( if method has 0 arguments
			if (argMax == 0) then strEnd	= ")" end	--use only ) if method has 0 arguments

			--verify the syntax of the function 'bar("arg")', 'bar("arg1","arg2")' or 'bar()'
			local iStart = StringParsing:indexOf(met,strStart,1); --find the next (" in the string (it should be at the very end of the string)
			if (iStart==nil and argMin == 0) then --Scenario where function got 0 arguments but accepts >0
			--if (iStart==nil and argMax > 0) then --Scenario where function got 0 arguments but accepts >0
				strStart	= "(";	--use only (
				strEnd		= ")";	--use only )
				iStart		= StringParsing:indexOf(met,strStart,1);
				nilMode		= true;
			end

			if (iStart == nil) then return nil end						--Syntax error: missing ("
			local iEnd = StringParsing:indexOf(met,strEnd,iStart);		--Find the next ") in the string (it should be at the very end of the string)
			if (iEnd == nil) then return nil end						--Syntax error: missing ")
			iEnd = iEnd + strlen(strEnd);								--add the length of the ") itself
			if (iEnd < strlen(met)) then return nil end					--if we find another ") before the end then that indicates that we got a double joined string, something thats invalid syntax

			---Get the argument
			local argStart = iStart;
			argStart = argStart + (strlen(strStart));

			local argEnd = StringParsing:indexOf(part,strEnd,argStart)-1;
			local arg    = strsub(part, argStart, argEnd); --get the argument

			local separator = "\",\"";	-- "," is the separator between arguments
			--[[
			local pattern1, pattern2 = '"%s+,"', '",%s+"';
			arg = StringParsing:replaceAllPattern(arg,pattern1,separator); --replace " ," and ", "  with "," so we have no spaces in between the arguments
			arg = StringParsing:replaceAllPattern(arg,pattern2,separator); --(if we did this in 1 operation the string would match "," and we wold get an infinite loop)
			]]--
			local multiArgs = StringParsing:split(arg, separator);

			local argCount = 0;
			if (multiArgs ~= nil) then
				--several arguments
				argCount = #multiArgs;
			else
				--atleast 1 argument
				if (strlen(arg) ~= 0) then argCount = 1 end
			end

			if (argMax == 0 and argCount > 0) then
				IfThen:msg_error("The method '"..c[NAME].."' accepts no arguments. Syntax error: '"..part.."'");
				return nil;
			end
			if (argCount < argMin) then
				IfThen:msg_error("Too few arguments for '"..c[NAME].."' the method requires atleast "..argMin.." argument(s). Syntax error: '"..part.."'");
				return nil;
			end
			if (argCount > argMax) then
				IfThen:msg_error("Too many arguments for '"..c[NAME].."' the method accepts only "..argMax.." argument(s). Syntax error: '"..part.."'");
				return nil;
			end

			--[[
			if (argMax == 0) and (strlen(arg) ~= 0) then
				IfThen:msg_error("The method '"..c[NAME].."' accepts no arguments. Syntax error: '"..part.."'");
				return nil;
			end --if

			if (argMax > 0) and (multiArgs ~=nil) and (#multiArgs > argMax) then
				IfThen:msg_error("Too many arguments for '"..c[NAME].."' the method accepts only "..argMax.." argument(s). Syntax error: '"..part.."'");
				return nil;
			end --if

			if (argMin > 0) and (multiArgs ~=nil) and (#multiArgs < argMin) then
				IfThen:msg_error("Too few arguments for '"..c[NAME].."' the method requires atleast "..argMin.." argument(s). Syntax error: '"..part.."'");
				return nil;
			end --if
			]]--

			--set argument collection
			if (nilMode and strlen(arg) == 0) then
				res[2] = cache_emptyTable; --empty array must be used as nil is mis-understood by tinsert() as a non-existent array-element later on (and promptly overwritten)
			else
				res[2] = {arg};
			end
			if (multiArgs ~= nil) and (#multiArgs > 0) then res[2] = multiArgs end

			break; --jump out of loop
		end--if
	end--for

	--if the res array has no methodname for the method then we haven't identified it, and we simply return nil
	if (res[3] == nil) then return nil end

	--if we come down here then everything is ok, we replace the placeholder characters with their real characters
	local booVar = false;
	if (res[2] ~=nil) then
		local objVarList = self:getVarList(true);
		local tmpArg = nil;
		for i = 1, #res[2] do
			--res[2][i] = self:doEscaping(res[2][i], false); --we reverse what we did in Parsing:trimLine() earlier
			tmpArg = res[2][i];
			tmpArg = self:doVarReplacement(tmpArg, objVarList);					--Expand in any static variables (if they are the wrong type then checkDataTypes() will react on it)
			tmpArg = self:doEscaping(tmpArg, false);							--We reverse what we did in Parsing:trimLine() earlier
			if (self:haveVariables(tmpArg) == true) then booVar = true end		--We might still have dynamic variables left in the arguments and those we will have to deal with at runtime.
			res[2][i] = tmpArg;
		end--for i
	end--if
	res[5] = booVar; --True if there re dynamic variables in the arguments, False if there isnt any

	--check if the argument data has a valid datatype
	if (argType ~=nil) then
		if (self:checkDataTypes(res[2], argType) == false) then return nil end
	end--if

	return res;
end


--Returns a user-friendly string describing the datatype
function Parsing:printDataTypes(strType, phraze)
	--This function is used by :checkDataTypes() to output a bit more understanable error message to the user then the datatype's dont match.
	local intPhraze = 0;
	if (phraze ~= nil) then intPhraze = phraze end
		--0 ==	" with one of these values: '"
		--1 ==	" that accepts only the values '"
		--2 ==	" that will be one of these values '"

	local strTypeName = "";
	local strValues = "";

	if (StringParsing:startsWith(strType, "INT[")) then
		strTypeName = "number";
	else
		strTypeName = "string";
	end--if startsWith

	--Split
	strType = StringParsing:replace(strType, "INT[", "");
	strType = StringParsing:replace(strType, "STR[", "");
	strType = StringParsing:replace(strType, "]", "");
	strType = StringParsing:split(strType, ";");

	if (strType == nil) then
		--Wide and anything goes
		if (strlower(strTypeName) == "number") then
			strValues = "";
		else
			strValues = "";
		end--if strTypeName

	else
		--Narrow
		if (strlower(strTypeName) == "number") then
			strValues = strValues.." with a value from '"..strType[1].."' to '"..strType[2].."'";
		else
			if (intPhraze==0) then	strValues = strValues.." with one of these values: '"..strType[1].."'"; end
			if (intPhraze==1) then	strValues = strValues.." that accepts only the values '"..strType[1].."'"; end
			if (intPhraze==2) then	strValues = strValues.." that will be one of these values '"..strType[1].."'"; end
			local intMax	= 7; --Max number of arguments that we will print
			local intFinal	= #strType-1;
			if (intFinal > intMax) then intFinal = intMax; end --If we go over the max number then trim it down (otherwise we just get these insane long error messages)
			for i=2, intFinal do
				strValues = strValues..", '"..strType[i].."'";
			end--for i
			if (#strType > intMax) then
				strValues = strValues.."... ("..#strType.." possible values)";
			else
				strValues = strValues.." or '"..strType[#strType].."'";
			end--if
		end--if strTypeName
	end--if strType

	return (strTypeName..strValues);
end


--Return true/false whether an array contains the correct datatypes
function Parsing:checkDataTypes(arrArguments, arrTypes)
	if (arrArguments == nil or #arrArguments == 0) then return true end
	--[[
		There are 2 different types we can run into: STR[] and INT[]
		These types can have different variations:
		STR[]				--any type of string
		STR[value;value]	--value delimited string, only the things in the list are accepted
		INT[]				--any type of integer
		INT[min;max]		--any type of integer between min and max

		We also have to check if the values are variables.
		If they are variables we dont check the actual values of the variable, but the datatype of the variable.
		That way we can determine which variables will be compatible with the datatype of the argument
		Examples:
			argument == STR[]		variable == STR[foo;bar]	--this is acceptable, since argument is a much 'wider' type
			argument == STR[a;b;c]	variable == STR[a;b]		--this is acceptable, since all of variable's values are found in the argument.
			argument == STR[a;b]	variable == STR[a;b;c]		--this is not acceptable, since not all of variable's values are found in the argument.

			argument == INT[]		variable == STR[foo;bar]	--this will not work, STR can not be casted into an INT
			argument == INT[1;2]	variable == INT[]			--this will not work, the variable is too wide compared to the argument
			argument == INT[]		variable == INT[]			--this will work, the variable is just as wide/narrow as the argument

		Note:
			arrTypes is MaxArguments long, that means that in all scenarios it will be equal or longer than arrArguments.
			Since the position of the datatypes are identical in both arrTypes and arrArguments, we use a single loop and [i] in one array matches the datatype in the other
			(all methodsignatures must start with required arguments first and any optional arguments at the end)
	]]--

	local strupper = strupper; --local fpointer
	local tonumber = tonumber;
	local tostring = tostring;

	for i=1, #arrArguments do
		local strType = strtrim(strupper(arrTypes[i]));
		strType = StringParsing:replace(strType, "]", ""); --remove ] at the end

		local strValue = strtrim(strupper(arrArguments[i]));

		--Is the whole argument a single variable? (in some cases then this does not matter, but we check that further down)
		local booVar, strVarType = self:haveSingleVariable(strValue, false);
		if (booVar) then
			strValue	= tostring(strVarType); --Use this variable to store a copy of the datatype
			strVarType	= StringParsing:replace(strupper(strVarType), "]", ""); --remove ] at the end

			--If the type is an INT[] but the value isn't then we can just fail here.
			if (StringParsing:startsWith(strType, "INT[") and StringParsing:startsWith(strVarType, "INT[") == false) then
				IfThen:msg_error("The variable '"..arrArguments[i].."' is a "..self:printDataTypes(strValue)..". Expected a "..self:printDataTypes(arrTypes[i])..".");
				return false;
			end
		end--if booVar

		if (StringParsing:startsWith(strType, "INT[")) then
			strType = StringParsing:replace(strType, "INT[", "");
			strType = StringParsing:split(strType, ";");

			if (strType == nil) then
				--All integer values are valid (there is no max/min range to check)

				if (booVar == true) then
					--We already know that the datatype of the variable is INT[]. Can't check any further with dynamic variables (they have no value until runtime)
				else
					--Verify that the value the user has written can be casted to an number
					local intValue = tonumber(strValue);

					if (intValue == nil) then
						IfThen:msg_error("The value is '"..arrArguments[i].."'. Argument requires a numerical value.");
						return false;
					end--if intValue
				end--if booVar

			else
				--check to see if the integer is within the min;max values
				local intArgMin = tonumber(strType[1]);
				local intArgMax = tonumber(strType[2]);

				if (intArgMin == nil or intArgMax == nil) then
					--This would be an error in the declaration found in Documentation.lua
					IfThen:msg_error("The argument has defined invalid min/max values for the integer datatype. Min='"..strType[1].."', Max='"..strType[2].."'.");
					return false;
				end--if intMin

				if (booVar) then
					strVarType = StringParsing:replace(strVarType, "INT[", "");
					strVarType = StringParsing:split(strVarType, ";");

					if (strVarType == nil) then
						--Is a wide INT[]. Not acceptable when the argument is narrowing

						IfThen:msg_error("The variable '"..arrArguments[i].."' is a wide "..self:printDataTypes(strValue)..". The argument requires a "..self:printDataTypes(arrTypes[i])..".");
						return false;
					end

					--Check to see if the variable is within the min;max range
					local intMin = tonumber(strVarType[1]);
					local intMax = tonumber(strVarType[2]);

					if (intMin == nil or intMax == nil) then
						--This would be an error in the declaration found in Documentation.lua
						IfThen:msg_error("The variable '"..arrArguments[i].."'. Has defined invalid min/max values for the integer datatype. Min='"..strVarType[1].."', Max='"..strVarType[2].."'.");
						return false;
					end--if intMin
					if (intMin < intArgMin or intMax > intArgMax) then
						IfThen:msg_error("The variable '"..arrArguments[i].."' (max='"..strVarType[1].."', min='"..strVarType[2].."') falls outside the range of the argument: Min='"..tostring(intArgMin).."', Max='"..tostring(intArgMax).."'.");
						return false;
					end--if intMin

				else
					--Check to see if the value is within the min;max range
					local intValue = tonumber(strValue);

					if (intValue == nil) then
						IfThen:msg_error("The value is '"..arrArguments[i].."'. Argument requires a numerical value.");
						return false;
					end--if intValue
					--[[
					if (intValue < 0) then --So far we only got methods that accept positive integers so we dont like negative values
						IfThen:msg_error("The value is '"..arrArguments[i].."' Argument requires postive numerical value.");
						return false;
					end--if intValue]]--
					if (intValue < intArgMin or intValue > intArgMax) then
						IfThen:msg_error("The value '"..tostring(intValue).."' is outside the accepted range of the argument: Min='"..tostring(intArgMin).."', Max='"..tostring(intArgMax).."'.");
						return false;
					end--if intValue
				end--if booVar

			end--if strType

		elseif (StringParsing:startsWith(strType, "STR[")) then
			strType = StringParsing:replace(strType, "STR[", "");
			strType = StringParsing:split(strType, ";");

			if (strType == nil) then
				--All strings are valid. (we dont even need to check if its a variable or not)

			else
				if (booVar) then
					--Check that all possible return values from the variable are found within the argument
					strVarType = StringParsing:replace(strVarType, "STR[", ""); --Whether its STR[] or INT[] does not matter since STR[] handles it all
					strVarType = StringParsing:replace(strVarType, "INT[", "");
					strVarType = StringParsing:split(strVarType, ";");

					if (strVarType == nil) then
						--Is either a wide STR[] or wide INT[]. Not acceptable when the argument is narrowing
						IfThen:msg_error("The variable '"..arrArguments[i].."' is a wide "..self:printDataTypes(strValue)..". The argument requires a "..self:printDataTypes(arrTypes[i])..".");
						return false;
					end

					local booValid = false;
					for m=1, #strVarType do														--For each item in the variable...
						booValid = false;														--Assume we dont match
						for k=1, #strType do													--For each item in the argument...
							if (strVarType[m] == strType[k]) then booValid=true; break; end		--If variable and argument item matches then we are good and skip the rest.
						end--for k
						if (booValid == false) then break end									--If the variable item does not match any of the argument-items then we fail.
					end--for m
					if (booValid == false) then
						IfThen:msg_error("The variable '"..arrArguments[i].."' is a "..self:printDataTypes(strValue,2)..". However, the argument is a "..self:printDataTypes(arrTypes[i],1)..".");
						return false;
					end--if booValid

				else
					--Check with list to see that the value the user has written is valid
					local booValid = false;
					for k=1, #strType do
						if (strType[k] == strValue) then booValid=true; break; end
					end--for k
					if (booValid == false) then
						IfThen:msg_error("The value is '"..arrArguments[i].."'. However, the argument is a "..self:printDataTypes(arrTypes[i],1)..".");
						return false;
					end--if booValid
				end--if booVar
			end--if strType

		else
			--This would be an error in the declaration found in Documentation.lua
			IfThen:msg_error("Unknown datatype encountered: '"..strType.."'.");
			return false;
		end--if

	end--for i

	return true;
end


--Return the linenumber in the text or 0
function Parsing:getLineNumber(text, arrLine, index)
	--OutOfBounds checks
	if (index == 1) then return 1; end --first line
	if (index == #arrLine) then
		local arrText = StringParsing:split(text, "\n"); --get the total number of lines in the raw text
		return #arrText;
	end

	local start = 1; --start index in the search

	--To prevent mistakes due to very short error lines we lookup the line that came before the error'd line. That will give us a closer startposition inside the text
	if (index > 1) then
		local line = arrLine[index-1];
		start = StringParsing:partialIndexOf(text, line, 1); --This is partialIndexOf() so it will search recursivly by reducing the 'line' string by 1 char at a time until it finds a match (or return nil)
		if (start == nil) then start = StringParsing:partialIndexOf(text, line, 1, nil, true); end --Reverse the lookup by removing 1 char from the start of the string
		if (start == nil) then start = 1; end --Did not find the previous line at all (!).
	end--if index

	local line	= arrLine[index];
	local pos	= StringParsing:partialIndexOf(text, line, start); --This is partialIndexOf() so it will search recursivly by reducing the 'line' string by 1 char at a time until it finds a match (or return nil)
	if (pos == nil) then pos = StringParsing:partialIndexOf(text, line, start, nil, true); end --Reverse the lookup by removing 1 char from the start of the string
	if (pos == nil) then return 0; end --Did not find the line at all.

	local strCurr = strsub(text, 1, pos);
	local i = 1;
	local gmatch = gmatch; --local fpointer
	for n in gmatch(strCurr, "\n") do i = i +1; end --Count the number of lines

	return i;
end


--Parse a blob of raw text into a an IF structure and a EVENT structure
function Parsing:ParseText(arrText, booOnEvent, DefaultMacroBlock, MacroPrefix, MaxMacroLength)
	--reset cache to nothing
	if (booOnEvent ~= true) then booOnEvent = false end --shall OnEvent()'s be parsed or not?
	cache_parsed_errors = nil; --is reset after calling ParseErrorPrint()
	cache_parsed_if		= nil;
	cache_parsed_event	= nil;
	cache_macroBlocks	= nil;
	if (cache_getVarList_Static == nil or cache_getVarList_Dynamic == nil) then self:getVarList(nil) end --if these for some reason have not been declared yet, then do so now.

	--create a set of blank tables
	local tabIfCount= 0;
	local tabIf		= {};
	local tabEvent	= self:CreateOnEventStruct();
	local macroBlock= DefaultMacroBlock;

	local strlen	= strlen; --local fpointer
	local strlower	= strlower;
	local strtrim	= strtrim;
	local tinsert	= tinsert;

	for txtIndex=1, #arrText do ---receives an array of raw text pages that we will iterate though and append to the whole list
		text = strtrim(arrText[txtIndex]);
		if (strlen(text) >= 0) then
			--split into individual lines
			local newLine		= ";";
			local newLineIgnore	= "\\;";
			local lines			= self:split(text, newLine, newLineIgnore);	--Custom split function that ignores splitting on \; and only accepts ;
																			--We have do do it this way since string.replace() does not work on strings longer than 4096 characters

			--local lines = StringParsing:split(text, newLine);
			--[[if (lines == nil) then
				IfThen:msg_error("Not a single line found in the text. Remember that lines must end with ; (semicolon)");
				return false;
			end]]--
			if (lines ~= nil) then
				for i=1, #lines do
					lines[i] = strtrim(lines[i]); --incase of \n at the beginning of the string
					--print("i="..i);
					--If this is a comment then just skip it
					if (StringParsing:startsWith(lines[i], "#") == false) then
						lines[i] = self:trimLine(lines[i]); --trim and tweak the current line

						--split the line into its parts
						local parsedLine	= {};
						local space			= " AND ";
						local parts			= StringParsing:split(lines[i], space);
						local skipLine		= false;
						local isEvent		= nil;	-- nil==IF statement, othewise its the WoW eventname for the event in question


						--Special case: MacroEnd()
						-----------------------------------------------------------------------------
						if (parts == nil) then
							local isMacro = self:isMacroEnd(lines[i]);	--sets the isMacro to true or false
							if (isMacro==true) then --switch back to the default block (we don't support nesting)
								macroBlock = DefaultMacroBlock;
								skipLine = true;
								lines[i] = strtrim(lines[i])..' AND IsDead("player")'; --This is alone on the line, but we add one so that the parser works. It will be skipped further down
								parts = StringParsing:split(lines[i], space);
							end--if nil
						else
							local isMacro = self:isMacroEnd(parts[1]);	--sets the isMacro to true or false
							if (isMacro==true) then
								--This method should have no statements after it. This will force the user to use proper syntax and not fool himself
								self:ParseError("The line '"..lines[i].."' should have no statements after it, since they are ignored.", txtIndex, text, lines, i);
								skipLine = true;
							end--if nil
						end--if parts
						--/Special case: MacroEnd()
						-----------------------------------------------------------------------------

						--Special case: MacroStart("Name")
						-----------------------------------------------------------------------------
						if (parts == nil) then
							local isMacro = self:isMacroStart(lines[i]);	--sets the isMacro string to nil, or the title for the block
							if (isMacro~=nil) then --isMacro has a new value, now we use that until the end or isMacroEnd() returns true
								macroBlock = MacroPrefix..isMacro; --'IfThen_macroname'
								if (strlen(isMacro) > MaxMacroLength) then
									--if someone creates a macroblock with a too long name, we fail.
									macroBlock = DefaultMacroBlock;
									self:ParseError("MacroStart(): Too long name. Maximum "..tostring(MaxMacroLength).." characters. Make it shorter.", txtIndex, text, lines, i);
									skipLine = true;
								elseif (strlower(macroBlock) == strlower(DefaultMacroBlock)) then
									--if someone creates a macroblock with the exact same name as the default, we fail.
									macroBlock = DefaultMacroBlock;
									self:ParseError("MacroStart(): Invalid name. It's the same as the default macro-name. Pick a different name.", txtIndex, text, lines, i);
									skipLine = true;
								else
									skipLine = true;
									lines[i] = strtrim(lines[i])..' AND IsDead("player")'; --This is alone on the line, but we add one so that the parser works. It will be skipped further down
									parts = StringParsing:split(lines[i], space);
								end
							end--if nil
						else
							local isMacro = self:isMacroStart(parts[1]);	--sets the isMacro string to nil, or the title for the block
							if (isMacro~=nil) then
								--This method should have no statements after it. This will force the user to use proper syntax and not fool himself
								self:ParseError("The line '"..lines[i].."' should have no statements after it, since they are ignored.", txtIndex, text, lines, i);
								skipLine = true;
							end--if nil
						end--if parts
						--/Special case: MacroStart("Name")
						-----------------------------------------------------------------------------

						--Special case: OnEvent("Spellcheck")
						-----------------------------------------------------------------------------
						if (parts == nil) then
							isEvent = self:isEvent(lines[i]);	--sets the isEvent string to nil, empty string or {wow-eventname, onevent-title, {array of arguments} }
							if (isEvent~=nil) then
								if (isEvent~="") then
									if (isEvent[1] == "IFTHEN_SPELLCHECK") then --This OnEvent method has no statements since they will never be evaluated, but we add one so that the parser works
										lines[i] = strtrim(lines[i])..' AND IsDead("player")';
										parts = StringParsing:split(lines[i], space);
									end--if IFTHEN_SPELLCHECK
								end--if ""
							end--if nil
						else
							isEvent = self:isEvent(parts[1]);	--sets the isEvent string to nil, empty string or {wow-eventname, onevent-title, {array of arguments} }

							if (isEvent~=nil) then
								if (isEvent~="") then
									if (isEvent[1] == "IFTHEN_SPELLCHECK") then --This OnEvent method should have no statements after it. This will force the user to use proper syntax and not fool himself
										self:ParseError("The line '"..lines[i].."' should have no statements after it, since they are ignored.", txtIndex, text, lines, i);
										skipLine = true;
									end--if IFTHEN_SPELLCHECK
								end--if ""
							end--if nil
						end--if parts
						isEvent = nil;
						--/Special case: OnEvent("Spellcheck")
						-----------------------------------------------------------------------------


						if (parts == nil) then
							self:ParseError("The line '"..lines[i].."' contain only one or no statements at all.", txtIndex, text, lines, i);
							skipLine = true;

						else
							--Determine whether this is an IF statement or an OnEvent statement
							isEvent = self:isEvent(parts[1]);		--sets the isEvent string to nil, empty string or {wow-eventname, onevent-title, {array of arguments} }
																	--empty string means that is was an OnEvent but that the eventtitle wasnt found
							if (isEvent~=nil and isEvent=="") then
								self:ParseError("The OnEvent() event '"..lines[i].."' does not exists.", txtIndex, text, lines, i);
								skipLine = true;
							end

							if (skipLine == false) then
								local startJ = 1;
								if (isEvent ~= nil) then startJ=startJ+1 end --skip OnEvent("...") part if this is an OnEvent statement
								for j=startJ, #parts do
									parts[j] = strtrim(parts[j]);
									--print("i="..i..", j="..j.." = '"..parts[j].."'");

									--[[
										here we need to parse the part into [functionpointer] and {argumentarray} and then add both of them to the parsedLine array
										0 see if the part is parseable
										1 identify the function
										2 get the number of arguments for the function (throw error if its incorrect)
										3 split the arguments into a subarray
										4 take result from 1 and 3 and append to parsedLine
									]]--

									local isOR = self:isORStatement(parts[j]); --will return nil if no OR exists or the string without the 'OR' in it
									if (isOR ~= nil) then

										if (#parsedLine == 0) then
											self:ParseError("OR can not be the first statement on a line '"..parts[j].."'.", txtIndex, text, lines, i);
											skipLine = true;
											break;
										end

										--insert a placeholder function into the array
										local tmpOR = {function() return "OR" end, cache_emptyTable, "OR", "argument", false}; --result hardcoded
											--element 1 is function pointer
											--element 2 is argument table {}
											--element 3 is function name as string
											--element 4 is function type
											--element 5 is true/false whether dynamic variables are in the arguments
										--we insert the OR placeholder before the 2 statements that are to be OR'ed (prefix processing in other words)

										--got to do it this way or we just overwrite the element
										--first we save the N last elements and overwrite them with the OR placeholder
										local tmpPrev = {};
										for o=(#parsedLine - #tmpOR +1), (#parsedLine) do
											tinsert(tmpPrev, parsedLine[o]);
											local oo = o -(#parsedLine - #tmpOR +0);
											parsedLine[o] = tmpOR[oo];
										end--for o

										--then we append copies of those we just overwrote at the end
										for o=1, #tmpPrev do
											tinsert(parsedLine,tmpPrev[o]);
										end--for o

										--continue with parsing the rest of the part
										parts[j] = isOR; --contains the part without the 'OR' in it
									end--if

									local currPart = self:parseMethod(parts[j]);
										--	This method will print any errors if thats applicable
										--	if it returns nil then something caused it to fail and we should show an error message and skip the line

									if (currPart == nil) then
										self:ParseError("The statement '"..parts[j].."' is not a valid method.", txtIndex, text, lines, i);
										skipLine = true;
									else
										--this will always be 5 elements
										--	tinsert() can mis-understand nil values and think it means its a free spot to write to at the end of the array in the next iteration of the loop.
										--	We therefore use {} (empty array) so that we preserve the positional index of the whole system (each statement consists of 5 elements {function pointer, argument-array, lowercase name, resultvalue, dynamic variables present}.
										for k=1, #currPart do
											tinsert(parsedLine,currPart[k]);
										end --for k

									end --if

									--[[
									--only save the parts that are useful (IF, AND, THEN etc are useless)
									if (self:isMethod(parts[j])) then
										--tinsert(res2, strtrim(parts[j]);
										tinsert(parsedLine, strtrim(parts[j]);
									else
										--IfThen:msg_error("The statement '"..parts[j].."' is not a valid method. This segment was skipped.");
										IfThen:msg_error("The statement '"..parts[j].."' is not a valid method. The line was skipped.");
										skipLine = true;
									end]]--

								end --for j
							end --if skipLine == false
						end--if (parts ~=nil)

						--append line if it isnt empty (or bugged)
						if (skipLine == false and #parsedLine >0) then
							if (isEvent == nil) then
								--This is an IF statement so append it to the IF table
								local tmp = tabIf[macroBlock];
								if (tmp == nil) then tmp = {}; end
								tinsert(tmp, parsedLine);
								tabIf[macroBlock] = tmp;
								tabIfCount = tabIfCount +1;
							else
								--This is an OnEvent statement so append it to the OnEvent table's subarray for the given event
								for k=1, #tabEvent[isEvent[1]] do
									if (tabEvent[isEvent[1]][k][1] == isEvent[2]) then
										local newParsedLine = {}; --need to pre-pend the event filters to the beginning of the line, so we need to re-create the array of the parsedLine
										tinsert(newParsedLine, isEvent[3]);
										newParsedLine = self:appendItems(newParsedLine, parsedLine); --use we use appendItems() to simplfy the code of adding multiple elements into the array

										tinsert(tabEvent[isEvent[1]][k], newParsedLine);
										break;
									end--if
								end--for k
							end--if (isEvent)
						end --if (skipLine)

					end --if (comment)

				end --for (lines)
			end--if (lines ~= nil)

		end --if strlen(text)
	end --for arrText

	if (tabIfCount == 0) then tabIf = nil; end		--set to nil if empty
	tabEvent = self:TrimOnEventStruct(tabEvent);	--remove any empty entries

	--remove any variable's that is not used
	cache_parsed_if_varlist	   = self:TrimVarList(tabIf,     true, cache_getVarList_Dynamic);
	cache_parsed_event_varlist = self:TrimVarList(tabEvent, false, cache_getVarList_Dynamic);

	--shall we initalize OnEvent()'s at all?
	if (booOnEvent == false) then
		tabEvent = {};
		cache_parsed_event_varlist = nil;
	end

	--remember parsed structures
	Methods:ReInit(tabIf, tabEvent, cache_parsed_if_varlist, cache_parsed_event_varlist); --will reset the Methods class to a blank state again

	cache_parsed_if		= tabIf;
	cache_parsed_event	= tabEvent;

	--force a garbage collection
	IfThen:collectGarbage();

	return true;
end


--Logs parsing errors for later output
function Parsing:ParseError(message, page, rawText, arrLines, arrIndex)
	local errLine	 = self:getLineNumber(rawText, arrLines, arrIndex);
	local strLink	 = IfThen:HyperLink_Create("edit", "[Page: "..page.." Line: "..errLine.."]", page, errLine);
	local strMessage = strLink.." "..message.." This line was skipped.";

	if (cache_parsed_errors == nil) then cache_parsed_errors = {}; end
	cache_parsed_errors[#cache_parsed_errors+1] = strMessage;
	return strMessage;
end


--Prints out any parsing errors since the last parsing done.
function Parsing:ParseErrorPrint()
	if (cache_parsed_errors ~= nil) then
		local res = "";
		for i = 1, #cache_parsed_errors do --Output messages in the same order we logged them (first error found first, then second etc)
			res = res.."\n"..cache_parsed_errors[i];
		end--for i
		res = strtrim(res);
		return res;
	end--if
	cache_parsed_errors = nil; --reset table after use.
	return nil;
end


--Custom split function since we can not use StringParsing:split() when splitting lines from each other
function Parsing:split(str, item, ignore)
	if (str == nil or str == "")		then return nil end
	if (item == nil or item == "")		then return nil end
	if (ignore == nil or ignore == "")	then return nil end
	if (strlen(item) > strlen(str))		then return nil end
	if (strlen(ignore) > strlen(str))	then return nil end

	local strlen  = strlen; --local fpointer
	local strsub  = strsub;
	local tinsert = tinsert;

	--The difference between this function and StringParsing:split() is that we accept an ignore parameter that is supposed to contain a string that we are to ignore splitting on
	--For example when we split raw text into lines using ';' then we dont want it to split on '\;' since that symbolizes an escaped ;
	--This method will ignore \; and only split on ; itself

	local iOffset	= strlen(ignore)-strlen(item); --the difference in length between item and ignore (; and \; for example is 1)
	local sPos		= StringParsing:indexOf(str, item, 1); --find index of splitter
	local sPosI		= StringParsing:indexOf(str, ignore, 1); --find index of ignore
	if (sPos == nil) then	return nil; end					--exit condition if there are no more splitters
	if (sPosI ~= nil) then	sPosI = sPosI + (iOffset); end	--adjust offset for the different in length
	if (sPosI == nil) then	sPosI = 1; end					--if we dont find the ignore then set it to 1

	local res = {};
	local line = nil;
	while (sPos ~=nil) do
		if (sPos ~= sPosI) then
			line = strsub(str, 1, (sPos-1));		--extract the line from the string (except the item itself)
			tinsert(res, line);					--add the line into the array
			str   = strsub(str,(sPos+strlen(item)),-1);	--remove the part of the string that we just added to the array
			sPosI = (strlen(item)*-1)+1;				--reset index to 1
		end
		sPos  = StringParsing:indexOf(str, item, sPosI+strlen(item));		--find the next index of splitter
		sPosI = StringParsing:indexOf(str, ignore, sPosI+strlen(ignore));	--find the next index of ignore
		if (sPosI ~= nil) then sPosI = sPosI + (iOffset); end				--adjust offset for the different in length
		if (sPosI == nil) then sPosI = 1; end								--if we dont find the ignore then set it to 1
	end
	--Append the remainder of the string as the last item
	if (strlen(str) > 0) then tinsert(res, str) end

	return res;
end


--Helper function that we use to append multiple elements to an array
function Parsing:appendItems(objArray, items)
	if (items == nil) then return objArray end

	local tinsert = tinsert; --local fpointer
	for i=1, #items do
		tinsert(objArray, items[i]);
	end--for

	return objArray;
end


--Replace escaped characters with placeholders or convert them back into plaintext
function Parsing:doEscaping(text, escape)
	local SL = strchar(92); --CHR 92 == '\' (slash)

	if (escape == true) then
		--replace escaped characters with placeholders so we can differentiate between them (must use @ instead of %, since % has a special meaning for the string-replacement patterns in LUA)
		text = StringParsing:replace(text, SL.."%" , "@ESCAPE_PERCENT@");
		text = StringParsing:replace(text, SL..";" , "@ESCAPE_SEMICOLON@");
		text = StringParsing:replace(text, SL.."(" , "@ESCAPE_LEFTPARAN@");
		text = StringParsing:replace(text, SL..")" , "@ESCAPE_RIGHTPARAN@");
		text = StringParsing:replace(text, SL..'"' , "@ESCAPE_QUOTE@");
		text = StringParsing:replace(text, SL.."," , "@ESCAPE_COMMA@");
		text = StringParsing:replace(text, SL..SL , "@ESCAPE_SLASH@");	--must be the last replacement, since \ is used as the escape character itself (CHR 92 == '\' (slash))
	else
		--replace placeholders with plaintext characters again
		text = StringParsing:replace(text, "@ESCAPE_PERCENT@" , "%");
		text = StringParsing:replace(text, "@ESCAPE_SEMICOLON@" , ";");
		text = StringParsing:replace(text, "@ESCAPE_LEFTPARAN@" , "(");
		text = StringParsing:replace(text, "@ESCAPE_RIGHTPARAN@" , ")");
		text = StringParsing:replace(text, "@ESCAPE_QUOTE@" , '"');
		text = StringParsing:replace(text, "@ESCAPE_COMMA@" , ",");
		text = StringParsing:replace(text, "@ESCAPE_SLASH@" , SL);	--(CHR 92 == '\' (slash))
	end--if
	return text;
end


--Trim, tweak and parse a given line before its beign split into parts
function Parsing:trimLine(line)
	--We used to do all this in a Parsing:trimText() function so it was only done once for the whole text, but since the text most of the time is bigger than 4096 characters it would
	--fail and only the first 4096 characters of the text would be returned (LUA runs out of stackspace for the string i belive).
	--replace \a \b \f \n \r \t \v inside the string with nothing
	line = StringParsing:replace(line,"\a",""); --bell
	line = StringParsing:replace(line,"\b",""); --backspace
	line = StringParsing:replace(line,"\f",""); --form feed
	line = StringParsing:replace(line,"\n",""); --newline
	line = StringParsing:replace(line,"\r",""); --return
	line = StringParsing:replace(line,"\t"," ");--tab
	line = StringParsing:replace(line,"\v",""); --vertical tab

	--replace escaped characters with placeholders so we can differentiate between them
	line = self:doEscaping(line,true);
	----------------------------------------------------------------------------------

	--line = strtrim(line); --incase of newline at the beginning of the string
	line = StringParsing:removeAtStart(line, "IF ", true);   --Remove useless 'IF' or 'if'
	line = StringParsing:replace(line, ") THEN ", ") AND "); --Replace THEN with AND for later splitting done in Parsing:parseText()
	line = StringParsing:replace(line, ") then ", ") AND ");
	line = StringParsing:replace(line, ") Then ", ") AND ");
	line = StringParsing:replace(line, ") and ",  ") AND "); --Replace lowercase AND with uppercase one
	line = StringParsing:replace(line, ") And ",  ") AND ");
	line = StringParsing:replace(line, ") or ",   ") OR ");  --Replace lowercase OR with uppercase one
	line = StringParsing:replace(line, ") Or ",   ") OR ");

	local gsub		= gsub; --local fpointer
	local pattern1, new1, pattern2, new2 = "", "", "", "";

	--pattern we use to prevent multiple spaces
	pattern1	= '%)%s%s+THEN%s';	-- ')   THEN ' is replaced with ') AND ' (multiple spaces between ')' and 'THEN' )
	new1		= ") AND ";
	pattern2	= '%)%sTHEN%s%s+';	-- ') THEN   ' is replaced with ') AND ' (multiple spaces between 'THEN' and whatever that follows )
	new2		= ") AND ";
	line = gsub(line, pattern1, new1);
	line = gsub(line, pattern2, new2);

	--pattern we use to prevent multiple spaces
	pattern1	= '%)%s%s+then%s';	-- ')   THEN ' is replaced with ') AND ' (multiple spaces between ')' and 'THEN' )
	new1		= ") AND ";
	pattern2	= '%)%sthen%s%s+';	-- ') THEN   ' is replaced with ') AND ' (multiple spaces between 'THEN' and whatever that follows )
	new2		= ") AND ";
	line = gsub(line, pattern1, new1);
	line = gsub(line, pattern2, new2);

	--pattern we use to prevent multiple spaces
	pattern1	= '%)%s%s+Then%s';	-- ')   THEN ' is replaced with ') AND ' (multiple spaces between ')' and 'THEN' )
	new1		= ") AND ";
	pattern2	= '%)%sThen%s%s+';	-- ') THEN   ' is replaced with ') AND ' (multiple spaces between 'THEN' and whatever that follows )
	new2		= ") AND ";
	line = gsub(line, pattern1, new1);
	line = gsub(line, pattern2, new2);


	--pattern we use to prevent multiple spaces
	pattern1	= '%)%s%s+AND%s';	-- ')   AND ' is replaced with ') AND ' (multiple spaces between ')' and 'AND' )
	new1		= ") AND ";
	pattern2	= '%)%sAND%s%s+';	-- ') AND   ' is replaced with ') AND ' (multiple spaces between 'AND' and whatever that follows )
	new2		= ") AND ";
	line = gsub(line, pattern1, new1);
	line = gsub(line, pattern2, new2);

	--pattern we use to prevent multiple spaces
	pattern1	= '%)%s%s+and%s';	-- ')   AND ' is replaced with ') AND ' (multiple spaces between ')' and 'AND' )
	new1		= ") AND ";
	pattern2	= '%)%sand%s%s+';	-- ') AND   ' is replaced with ') AND ' (multiple spaces between 'AND' and whatever that follows )
	new2		= ") AND ";
	line = gsub(line, pattern1, new1);
	line = gsub(line, pattern2, new2);

	--pattern we use to prevent multiple spaces
	pattern1	= '%)%s%s+And%s';	-- ')   AND ' is replaced with ') AND ' (multiple spaces between ')' and 'AND' )
	new1		= ") AND ";
	pattern2	= '%)%sAnd%s%s+';	-- ') AND   ' is replaced with ') AND ' (multiple spaces between 'AND' and whatever that follows )
	new2		= ") AND ";
	line = gsub(line, pattern1, new1);
	line = gsub(line, pattern2, new2);


	--pattern we use to prevent multiple spaces
	pattern1	= '%s%s+NOT%s';	-- '   NOT ' is replaced with ' NOT ' (multiple spaces between whatever before and 'NOT' )
	new1		= " NOT ";
	pattern2	= '%sNOT%s%s+';	-- ' NOT   ' is replaced with ' NOT ' (multiple spaces between 'NOT' and whatever that follows )
	new2		= " NOT ";
	line = gsub(line, pattern1, new1);
	line = gsub(line, pattern2, new2);

	--pattern we use to prevent multiple spaces
	pattern1	= '%s%s+not%s';	-- '   NOT ' is replaced with ' NOT ' (multiple spaces between whatever before and 'NOT' )
	new1		= " NOT ";
	pattern2	= '%snot%s%s+';	-- ' NOT   ' is replaced with ' NOT ' (multiple spaces between 'NOT' and whatever that follows )
	new2		= " NOT ";
	line = gsub(line, pattern1, new1);
	line = gsub(line, pattern2, new2);

	--pattern we use to prevent multiple spaces
	pattern1	= '%s%s+Not%s';	-- '   NOT ' is replaced with ' NOT ' (multiple spaces between whatever before and 'NOT' )
	new1		= " NOT ";
	pattern2	= '%sNot%s%s+';	-- ' NOT   ' is replaced with ' NOT ' (multiple spaces between 'NOT' and whatever that follows )
	new2		= " NOT ";
	line = gsub(line, pattern1, new1);
	line = gsub(line, pattern2, new2);


	--pattern we use to prevent multiple spaces
	pattern1 = '%)%s%s+OR%s';	-- ')   OR ' is replaced with ') OR ' (multiple spaces between ')' and 'OR' )
	new1 = ") OR ";
	pattern2 = '%)%sOR%s%s+';	-- ') OR   ' is replaced with ') OR ' (multiple spaces between 'OR' and whatever that follows )
	new2 = ") OR ";
	line = gsub(line, pattern1, new1);
	line = gsub(line, pattern2, new2);

	--pattern we use to prevent multiple spaces
	pattern1 = '%)%s%s+or%s';	-- ')   OR ' is replaced with ') OR ' (multiple spaces between ')' and 'OR' )
	new1 = ") OR ";
	pattern2 = '%)%sor%s%s+';	-- ') OR   ' is replaced with ') OR ' (multiple spaces between 'OR' and whatever that follows )
	new2 = ") OR ";
	line = gsub(line, pattern1, new1);
	line = gsub(line, pattern2, new2);

	--pattern we use to prevent multiple spaces
	pattern1 = '%)%s%s+Or%s';	-- ')   OR ' is replaced with ') OR ' (multiple spaces between ')' and 'OR' )
	new1 = ") OR ";
	pattern2 = '%)%sOr%s%s+';	-- ') OR   ' is replaced with ') OR ' (multiple spaces between 'OR' and whatever that follows )
	new2 = ") OR ";
	line = gsub(line, pattern1, new1);
	line = gsub(line, pattern2, new2);

	line = StringParsing:replace(line, " OR ", " AND OR "); --replace OR with AND OR since splitting is later done with AND in Parsing:parseText()


	--pattern we use to prevent multiple spaces
	pattern1	= '%(%s+"';	-- '(   "' is replaced with '("' (multiple spaces between '(' and '"' )
	new1		= '("';
	pattern2	= '"%s+%)';	-- '"   )' is replaced with '")' (multiple spaces between '"' and ')' )
	new2		= '")';
	line = gsub(line, pattern1, new1);
	line = gsub(line, pattern2, new2);

	--pattern we use to prevent multiple spaces
	pattern1	= '%(%s+%)';	-- '(   )' is replaced with '()' (multiple spaces between '(' and ')' )
	new1		= '()';
	--local pattern2 = '%(%s+%)';	-- '(   )' is replaced with '()' (multiple spaces between '(' and ')' )
	--local new2 = '()';
	line = gsub(line, pattern1, new1);
	--line = gsub((line, pattern2, new2);

	--pattern we use to prevent multiple spaces
	pattern1	= '"%s+,"';	-- '"  ,"' is replaced with '","' (multiple spaces between '"' and ',"' )
	new1		= '","';
	pattern2	= '",%s+"';	-- '",  "' is replaced with '","' (multiple spaces between '",' and '"' )
	new2		= '","';
	line = gsub(line, pattern1, new1);
	line = gsub(line, pattern2, new2);

	--pattern we use to prevent multiple spaces
	pattern1	= '"%s+,%s+"';	-- '"  ,  "' is replaced with '","' (multiple spaces between '"' and ',' and '"' )
	new1		= '","';
	--pattern2 = '"%s+,%s+"';	-- '"  ,  "' is replaced with '","' (multiple spaces between '"' and ',' and '"' )
	--new2 = '","';
	line = gsub(line, pattern1, new1);
	--line = gsub(line, pattern2, new2);

	return strtrim(line);
end


--Traverses the string and replaces the %VARIABLE% with their value
function Parsing:doVarReplacement(strInput, arrVarList)
	if (self:haveVariables(strInput) == false) then return strInput end --no '%' found in string, return immediatly

	local strlower = strlower; --local fpointer
	local strlen   = strlen;
	local strfind  = strfind;

	local res = strInput;
	local start, finish, value = strfind(res, "%%(.-)%%", 1); --We look for '%string%'

	while (start ~= nil) do
		local tblValue = arrVarList[strlower(value)]; --value is just whats inside the % %
		if (tblValue ~= nil) then
			local newValue = Methods:VariableLookup(tblValue[VALARG], value);
			--newValue = StringParsing:escapeMagicalCharacters(newValue);
			res = StringParsing:replace(res, "%"..value.."%", newValue);
			finish = start + strlen(newValue) +2; -- +2 for the %'s
		end

		start, finish, value = strfind(res, "%%(.-)%%", finish);
	end--while

	return res;
end


--Returns True/False whether the string contains any '%' in it (a sign of variables)
function Parsing:haveVariables(strInput)
	local i = StringParsing:indexOf(strInput, "%", 1);
	if (i == nil) then return false end					--did not even find a single '%'
	if (strlen(strInput) == i) then return false end	--i is the lastmost character (i+1 would fuck up)

	local j = StringParsing:indexOf(strInput, "%", (i+1));
	if (j == nil) then return false end --only found a single '%', we need 2 of these to make a variable

	return true; --We found atleast 2 '%' that's a very strong indicator that there are variables in the string
end


--Returns True/False whether the whole string consists of a single variable and its datatype
function Parsing:haveSingleVariable(strInput, isStatic)
	if (StringParsing:startsWith(strInput, "%") == false and StringParsing:endsWith(strInput, "%") == false) then return false, nil; end --if the first and last char in the string isnt a '%' then its not a single variable by itself

	local arrVarList = self:getVarList(isStatic);
	local strVar = strtrim(StringParsing:replace(strlower(strInput),"%",""));

	local objVar = arrVarList[strVar];
	if (objVar ~= nil) then return true, objVar[ARG]; end --return true and the datatype of the variable
	return false, nil;
end


--Traverses the parsed array and it's arguments, looks at which variables that are referenced to and will return an array consisting only of the variables that are in use.
function Parsing:TrimVarList(objParsed, booIF, objVarList)
	--[[
		For each element in varlist
			for each row
				for each argument element
					if var is found in element then add it to new list
		next--varlist
		return newList
	]]--
	local objNew = {};
	if (objParsed == nil or objVarList == nil) then return objNew end --if objParsed happens to be nil then no variables are needed to be remembered, if objVarList is nil then there is nothing to look for.

	local strlower	= strlower; --local fpointer
	local pairs		= pairs;

	for varKey,varValue in pairs(objVarList) do
		local tmpKey = strlower("%"..varKey.."%");
		local booFound = false;

		if (booIF == true) then
			--IF Structure

			for hKey,hValue in pairs(objParsed) do
				local currTbl = hValue;
				for i=1, #currTbl do
					local line = currTbl[i];
					for j=1, #line, 5 do --iterate 5 elements at a time
						--local m_function	= line[j]; 		--function pointer
						local m_args		= line[j+1];	--argument table
						--local m_name		= line[j+2];	--plain string function name
						--local m_type		= line[j+3];	--plain string function type
						local m_var			= line[j+4];	--boolean. dynamic variables present (true, then we must parse and replace before calling function with arguments)

						if (m_var == true) then--if the arguments contain dynamic variables then we iterate though them all and expand them now
							for tmpI=1, #m_args do
								if (StringParsing:indexOf(strlower(m_args[tmpI]), tmpKey, 1) ~= nil) then
									booFound = true; --We found an occurrence of the variable, add it to the list and stop looping
									break;
								end--if
							end--for tmpI
						end--if m_var
						if (booFound) then break end
					end--for j
				end--for currTbl
			end--for hKey,kValue

		else
			--OnEvent Structure
			for evtKey,evtValue in pairs(objParsed) do
				local event = evtValue;
				for t=1, #event do
					local subEvent = event[t];
					if (subEvent ~= nil) then
						local event_handler		= subEvent[2];	--element 2 in line 1 contains the function-pointer to the eventhandler or its nil
						local startI = 3; --skip the eventhandler
						for i=startI, #subEvent do
							local line		= subEvent[i];
							local booFirstLineIteration = true;
							for j=2, #line, 5 do --first element contains subevent filters, we iterate 5 elements at a time
								if (booFirstLineIteration) then
									if (event_handler ~= nil) then
										local event_filter = line[(j-1)]; --we have already called the event handler with a coarse filter, we now use the specific filter for this line
										for tmpI=1, #event_filter do --expand any dynamic enviroment variables found in the filter
											if (StringParsing:indexOf(strlower(event_filter[tmpI]), tmpKey, 1) ~= nil) then
												booFound = true; --We found an occurrence of the variable, add it to the list and stop looping
												break;
											end--if
										end--for tmpI
										if (booFound) then break end
									end
								end --booFirstLineIteration
								booFirstLineIteration = false; --only do this first part once

								--local m_function	= line[j];		--function pointer
								local m_args		= line[j+1];	--argument table
								--local m_name		= line[j+2];	--plain string function name
								--local m_type		= line[j+3];	--plain string function type
								local m_var			= line[j+4];	--boolean. dynamic variables present (true, then we must parse and replace before calling function with arguments)
								--local m_result		= nil;			--will contain the result of the function call

								if (m_var == true) then--if the arguments contain dynamic variables then we iterate though them all and expand them now
									for tmpI=1, #m_args do
										if (StringParsing:indexOf(strlower(m_args[tmpI]), tmpKey, 1) ~= nil) then
											booFound = true; --We found an occurrence of the variable, add it to the list and stop looping
											break;
										end--if
									end--for tmpI
									if (booFound) then break end
								end--if m_var
							end--for j
							if (booFound) then break end
						end--for i
					end--if subEvent
					if (booFound) then break end
				end--for t
				if (booFound) then break end
			end--for objParsed

		end--booIF

		if (booFound) then objNew[varKey] = varValue; end --if found atleast 1 occurrence of the variable then add it to the list
	end--for objVarList

	return objNew;
end


--####################################################################################
--####################################################################################