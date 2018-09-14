--####################################################################################
--####################################################################################
--Syntax Coloring functions
--####################################################################################
--Dependencies: StringParsing.lua

local SyntaxColor	= {};
SyntaxColor.__index	= SyntaxColor;
IfThen_SyntaxColor	= SyntaxColor; --Global declaration

local StringParsing	= IfThen_StringParsing; --Local pointer
--local IfThen		= IfThen_IfThen;	 	--Local pointer


--Local variables that cache stuff so we dont have to recreate large objects
local cache_Functions	= nil; --Array with all function names in lowercase
local cache_FunctionsN	= nil; --Array with functions that can start on a line; OnEvent, MacroStart, MacroEnd
local cache_Variables	= nil; --Array with all enviroment variables in lowercase

--Local Constants
	--Colors used
local colBlue	= "|cFF0076B6"; --Same as used in function-scrolllist; functions
local colDBlue	= "|cFF0A56F5"; --Darker blue; used for cache_FunctionsN
local colGolden	= "|cFFE6CC80"; --Heirloom;	variables
local colGray	= "|cFF9D9D9D"; --Poor;		strings
local colGreen	= "|cff008000"; --Green;	comments
local colLime	= "|cFF00FF00"; --Lime;		highlighted text
local colRed	= "|cFFC30000"; --Red;		errors; keywords and statements
local colWhite	= "|cFFFFFFFF"; --Default color
--local colOrange	= "|cFFFF8040";
--local colPink		= "|cFFFF00FF";
--local colTeal		= "|cFF149494"; --Fixed values ; 'StartsWith', 'IndexOf' etc
--local colYellow	= "|cFFEBB81F"; --Required arguments
--local colPurple	= "|cFF806EC5"; --Optional arguments
	--Color types
local CONST_cDefault= colWhite;
local CONST_cError	= colRed;
local CONST_cComment= colGreen;
local CONST_cString	= colGray;
local CONST_cFunc1	= colDBlue;
local CONST_cFunc2	= colBlue;
local CONST_cVar	= colGolden;
--local CONST_cParan= colWhite;
--local CONST_cLnk	= colGolden;
local CONST_cNotHighlight	= colGray;
local CONST_cHighlight		= colLime;
local CONST_minHighlight	= 3; --Minimum number of characters for highlighting to work

	--Pattern for :Clear****Color() functions
local CONST_Empty						= "";
local CONST_StartString					= "\n";										--Newline used at the start of the string so that patterns work on the very first line aswell
local CONST_StartStringIndex			= strlen(CONST_StartString) +1;				--Length of CONST_StartString
local CONST_ClearColor_Pattern1			= "(|c)(........)";							--'|c00000000'
--local CONST_ClearColor_Pattern2		= "|r";										--'|r'
local CONST_ClearBlankColor_Pattern		= "(|c)(........)[%s%c]*(|c)(........)";	--'|c00000000<space/newline/etc>|cffffffff'
local CONST_ClearDoubleColor_Pattern	= "(|c)(........)(.-)(|c)(........)";		--'|c00000000<anything>|c00000000'
local CONST_ClearColor_Start1			= strlen("|cAARRGGBB"); --String representing the length of a colorstring (we calculate here once here and recycle the values in loops)
local CONST_ClearColor_Start2			= CONST_ClearColor_Start1 +1;
	--Cursor marker
local CONST_Cursor						= "@CURSOR_MARKER@";
	--Functions:
local CONST_FU_Pattern1	= '\n([%@%_%a%d%w]-)%(';	--Pattern for functions: '<newline>name('	>>We add %@ and %_ so that the string '@CURSOR_MARKER@' is accepted in the pattern too
local CONST_FU_Pattern2	= ' ([%@%_%a%d%w]-)%(';		--Pattern for functions: ' name('
local CONST_FU_PStart	= CONST_Empty;				--Start character in pattern
local CONST_FU_PEnd		= CONST_Empty;				--End character in pattern
local CONST_FU_Extra1	= false;					--Use Extra find() or not to get exact position of the value string
local CONST_FU_Extra2	= false;					--Use Extra find() or not
	--Comments:
local CONST_CO_Pattern1	= '\n[%s]*#(.-);';					--Pattern for comments: '<newline>#<string>;'
local CONST_CO_Pattern2	= '\n'..CONST_Cursor..'[%s]*#(.-);';--Pattern for comments: '<newline>@CURSOR@#<string>;'
local CONST_CO_PStart	= '#';								--Start character in pattern
local CONST_CO_PEnd		= ';';								--End character in pattern
local CONST_CO_Extra1	= true;								--Use Extra find() or not
local CONST_CO_Extra2	= true;								--Use Extra find() or not
	--Paranthesis Left:
--local CONST_PL_Pattern= "%(";
--local CONST_PL_Result	= CONST_cParan.."%("..CONST_cDefault;
	--Paranthesis Right:
--local CONST_PR_Pattern= "%)";
--local CONST_PR_Result	= CONST_cParan.."%)"..CONST_cDefault;
	--Strings:
local CONST_ST_Pattern	= '"(.-)"';			--Pattern for strings: '"<string>"'
local CONST_ST_PStart	= '"';				--Start character in pattern
local CONST_ST_PEnd		= CONST_ST_PStart;	--End character in pattern
local CONST_ST_Extra	= false;			--Use Extra find() or not
	--Variables:
--local CONST_VA_Pattern	= '%%(.-)%%';		--Pattern for variables: '%<string>%'
--local CONST_VA_PStart	= '%';				--Start character in pattern
--local CONST_VA_PEnd		= CONST_VA_PStart;	--End character in pattern
--local CONST_VA_Extra	= false;			--Use Extra find() or not
	--Links:
--local CONST_LI_Pattern	= '%[(.-)%]';		--Pattern for hyperlinks: '[<string>]"'
--local CONST_LI_PStart	= '[';				--Start character in pattern
--local CONST_LI_PEnd		= "]";	--End character in pattern
--local CONST_LI_Extra	= false;			--Use Extra find() or not


--Local pointers to global functions
--local type	= type;
local strlen	= strlen;
local strfind	= strfind;
local strsub	= strsub;
local strlower	= strlower;
local gsub		= gsub;		--string.gsub


--####################################################################################
--####################################################################################
--Public
--####################################################################################


--Set tables that defined Functions and Enviroment variables
function SyntaxColor:SetTables(arrFunctions, arrFunctionsN, arrVariables)
	cache_Functions	= arrFunctions; --Assume arrays (not tables)
	cache_FunctionsN= arrFunctionsN;
	cache_Variables	= arrVariables;
end


--Clear all existing colors from the string
function SyntaxColor:ClearColor(rawText, currPos)
	--Insert a marker where the cursor currently is standing
	if (currPos ~= nil) then rawText = self:PlaceCursorMarker(rawText, currPos); end

	--Clear any colorstrings from the text
	rawText = gsub(rawText, CONST_ClearColor_Pattern1, CONST_Empty);

	--Remove cursor marker and get the new position returned
	local newPos = nil;
	if (currPos ~= nil) then rawText, newPos = self:GetNewCursorPosition(rawText); end

	return rawText, newPos;
end


--Color the text according to the IfThen-Syntax. Returns Colored Text, New cursor position, Length of plain rawText, Time in ms to run the function.
function SyntaxColor:ColorText(rawText, currPos)
	if (rawText == nil or rawText == "") then return nil; end
	local objStartTime = debugprofilestop(); --Start recording the time it takes for this function to finish
	local strlen = strlen; --local fpointer
	--local booDebug = true;
	--if (booDebug) then print("\n---------------------------------------------"); end

	--Insert a marker where the cursor currently is standing
	if (currPos ~= nil) then rawText = self:PlaceCursorMarker(rawText, currPos); end

	--Clear all existing colors from the string
	rawText = self:ClearColor(rawText);
	local rawLen = strlen(rawText) - strlen(CONST_Cursor); --Length of the raw text without coloring or escapesequences
	--if (booDebug) then print("BLANK Length: "..rawLen); end

	--Put a newline at the start (this is so that the patterns work with the very first line too)
	rawText = CONST_StartString..rawText;

	--ESCAPING		Replace special characters with escapesequences
	rawText = StringParsing:replace(rawText, CONST_CO_PStart..CONST_CO_PEnd, "@ESC_CO_SP@"); --Special case: '#;' (no chars between ; and #) is replaced manually. The pattern can't be modified to work properly and it will be alot of overhead in doReplacement() for this specific case. This is simpler.
	rawText = self:doEscapingWithinComments(rawText, true, CONST_CO_Pattern1, CONST_CO_PStart, CONST_CO_PEnd, true);
	rawText = self:doEscapingWithinComments(rawText, true, CONST_CO_Pattern2, CONST_CO_PStart, CONST_CO_PEnd, true);
	rawText = self:doEscapingWithinComments(rawText, true, CONST_ST_Pattern, CONST_ST_PStart, CONST_ST_PEnd, false); --Replace any special characters inside quotes "". Otherwise things like "/run IFT()" would not be colored as a string
	rawText = self:doEscaping(rawText, true);
	--if (booDebug) then print("ESCAPED Length: "..strlen(rawText)); end

	--COMMENT		Find next # ; and put color around it
	rawText = self:doReplacement(rawText, nil, CONST_CO_Pattern1, CONST_CO_PStart, CONST_CO_PEnd, CONST_Empty, CONST_cComment, CONST_cDefault, CONST_CO_Extra1);
	rawText = self:doReplacement(rawText, nil, CONST_CO_Pattern2, CONST_CO_PStart, CONST_CO_PEnd, CONST_Empty, CONST_cComment, CONST_cDefault, CONST_CO_Extra2);
	--if (booDebug) then print("COMMENTS Length: "..strlen(rawText)); end

	--FUNCTION		Find next ' <function>(' and put a color around it
	rawText = self:doReplacement(rawText, cache_FunctionsN, CONST_FU_Pattern1, CONST_FU_PStart, CONST_FU_PEnd, CONST_cFunc1, CONST_cError, CONST_cDefault, CONST_FU_Extra1);	--'<newline>func('
	rawText = self:doReplacement(rawText, cache_Functions, CONST_FU_Pattern2, CONST_FU_PStart, CONST_FU_PEnd, CONST_cFunc2, CONST_cError, CONST_cDefault, CONST_FU_Extra2);	--' func('
	--if (booDebug) then print("FUNCTIONS Length: "..strlen(rawText)); end

	--PARAN			Find '(' and ')' and color them
	--rawText = gsub(rawText, CONST_PL_Pattern, CONST_PL_Result); --Patanthesis Left
	--rawText = gsub(rawText, CONST_PR_Pattern, CONST_PR_Result); --Patanthesis Right
	--if (booDebug) then print("PARAN Length: "..strlen(rawText)); end

	--QUOTE		Find next " " and put color around it
	rawText = self:doReplacement(rawText, nil, CONST_ST_Pattern, CONST_ST_PStart, CONST_ST_PEnd, CONST_Empty, CONST_cString, CONST_cDefault, CONST_ST_Extra);
	--if (booDebug) then print("STRINGS Length: "..strlen(rawText)); end

	--VARIABLE	Find next % % and put a color around it
	--rawText = self:doReplacement(rawText, cache_Variables, CONST_VA_Pattern, CONST_VA_PStart, CONST_VA_PEnd, CONST_cVar, CONST_cError, CONST_cString, CONST_VA_Extra); --NOT IN USE
	--if (booDebug) then print("VARIABLES Length: "..strlen(rawText)); end

	--LINK Find next [ ] and put a color around it
	--rawText = self:doReplacement(rawText, nil, CONST_LI_Pattern, CONST_LI_PStart, CONST_LI_PEnd, CONST_Empty, CONST_cLnk, CONST_cString, CONST_LI_Extra);
	--if (booDebug) then print("LINK Length: "..strlen(rawText)); end

	--Replace escapesequences back again with special characters
	rawText = self:doCommentEscaping(rawText, false);
	rawText = self:doEscaping(rawText, false);
	rawText = StringParsing:replace(rawText, "@ESC_CO_SP@", CONST_cComment..CONST_CO_PStart..CONST_CO_PEnd..CONST_cDefault); --Special case; replace '#;' with default color wrapped around it
	--if (booDebug) then print("UNESCAPED Length: "..strlen(rawText)); end

	--Remove that newline we added to the start earlier and put default color at the start
	rawText = CONST_cDefault..strsub(rawText, CONST_StartStringIndex);

	--Remove any colors that won't be seen
	rawText = self:ClearBlankColors(rawText);
	--if (booDebug) then print("BLANK Length: "..strlen(rawText)); end

	--Remove double entries of color to reduce size
	--rawText = self:ClearDoubleColors(rawText);
	--if (booDebug) then print("DOUBLE Length: "..strlen(rawText)); end

	--Remove cursor marker and get the new position returned
	local newPos = nil;
	if (currPos ~= nil) then rawText, newPos = self:GetNewCursorPosition(rawText); end

	--rawText = gsub(rawText, "|c", "§c");
	--rawText = gsub(rawText, CONST_ClearColor_Pattern1, "§c");

	--if (booDebug) then print("Final Length: "..strlen(rawText)); end
	local objRuntime = debugprofilestop() - objStartTime; --Remember the time to took to run this function (in milliseconds, with sub-millisecond precision)
	return rawText, newPos, rawLen, objRuntime;
end


--Color the text so that only the filterText is Highlighted. Returns Colored Text, New cursor position, Length of plain rawText, Number of matches found, Time in ms to run the function.
function SyntaxColor:HighlightText(rawText, currPos, filterText)
	if (rawText == nil or rawText == "") then return nil; end
	if (filterText == nil or filterText == "" or strlen(filterText) < CONST_minHighlight) then return nil; end --Must be atleast N characters
	local objStartTime = debugprofilestop(); --Start recording the time it takes for this function to finish
	local strlen = strlen; --local fpointer
	--local booDebug = true;
	--if (booDebug) then print("\n---------------------------------------------"); end

	--Insert a marker where the cursor currently is standing
	if (currPos ~= nil) then rawText = self:PlaceCursorMarker(rawText, currPos); end

	--Clear all existing colors from the string
	rawText = self:ClearColor(rawText);
	local rawLen = strlen(rawText); --Length of the raw text without coloring or escapesequences
	--if (booDebug) then print("BLANK Length: "..rawLen); end

	--Add color from the start of the string
	rawText = CONST_cNotHighlight..rawText;

	--Do the higlighting of the filtered text;
	local intMatches = 0; --Number of replacements done, i.e the number of matches found in the text
	rawText, intMatches = self:doSimpleReplacement(rawText, filterText, CONST_cHighlight, CONST_cNotHighlight); --Add colors infront and behind the filterstring

	--Remove any colors that won't be seen
	rawText = self:ClearBlankColors(rawText);
	--if (booDebug) then print("BLANK Length: "..strlen(rawText)); end

	--Remove cursor marker and get the new position returned
	local newPos = nil;
	if (currPos ~= nil) then rawText, newPos = self:GetNewCursorPosition(rawText); end

	--if (booDebug) then print("Final Length: "..strlen(rawText)); end
	local objRuntime = debugprofilestop() - objStartTime; --Remember the time to took to run this function (in milliseconds, with sub-millisecond precision)
	return rawText, newPos, rawLen, intMatches, objRuntime;
end


--[[Not in use
function SyntaxColor:SetColors(Default, Error, Comment, String, Func, FuncN, Variable, NotHighlight, Highlight, Paran, Link)
	CONST_cDefault	= self:isColorString(Default)	or CONST_cDefault;
	CONST_cError	= self:isColorString(Error)		or CONST_cError;
	CONST_cComment	= self:isColorString(Comment)	or CONST_cComment;
	CONST_cString	= self:isColorString(String)	or CONST_cString;
	CONST_cFunc		= self:isColorString(Func)		or CONST_cFunc;
	CONST_cFuncN	= self:isColorString(FuncN)		or CONST_cFuncN;
	CONST_cVar		= self:isColorString(Variable)	or CONST_cVar;
	CONST_cNotHighlight = self:isColorString(NotHighlight) or CONST_cNotHighlight;
	CONST_cHighlight = self:isColorString(Highlight) or CONST_cHighlight;
	--CONST_cParan	= self:isColorString(Paran)		or CONST_cParan;
	--CONST_cLnk	= self:isColorString(Link)		or CONST_cLnk;
	return nil;
end]]--

--Return a table with all colorvalues used
function SyntaxColor:GetColors()
	return {["DEFAULT"]=CONST_cDefault, ["ERROR"]=CONST_cError, ["COMMENT"]=CONST_cComment, ["STRING"]=CONST_cString, ["FUNC"]=CONST_cFunc2, ["FUNCN"]=CONST_cFunc1, ["VAR"]=CONST_cVar, ["NOTHIGHLIGHT"]=CONST_cNotHighlight, ["HIGHLIGHT"]=CONST_cHighlight}; --, ["PARAN"]=CONST_cParan, ["LINK"]=CONST_cLnk
end


--####################################################################################
--####################################################################################
--Support functions
--####################################################################################
	--Links about patterns
	--http://www.wowpedia.org/Pattern_matching | http://lua-users.org/wiki/StringLibraryTutorial | http://lua-users.org/wiki/PatternsTutorial | http://lua-users.org/wiki/StringRecipes


--Put cursor marker in the current position
function SyntaxColor:PlaceCursorMarker(rawText, currPos)
	local strsub	= strsub; --local fpointer
	local before	= strsub(rawText, 1, currPos);
	local after		= strsub(rawText, currPos+1, nil);
	rawText = before..CONST_Cursor..after;
	return rawText;
end


--Clear cursor marker and return it's position
function SyntaxColor:GetNewCursorPosition(rawText)
	local start, finish = strfind(rawText, CONST_Cursor, 1);
	if (start==nil) then return rawText, nil; end

	rawText = StringParsing:replace(rawText, CONST_Cursor, "");
	return rawText, (start-1);
end


--[[Not in use
--Clear any colors that are identical after one another (remove the latter one).
function SyntaxColor:ClearDoubleColors(rawText)
	--Removes any double colorstring entries where the same color is repeated after itself
	--'yellow <some text> yellow again'	==> remove the last yellow
	local strfind	= strfind; --local fpointer
	local strsub	= strsub;
	local strlen	= strlen;

	local strPattern	= CONST_ClearDoubleColor_Pattern;
	local intChar1		= CONST_ClearColor_Start1;		--Calculate once here and recycle in loop
	local intChar2		= CONST_ClearColor_Start2;
	local intValue 		= 0;

	local start, finish, value = strfind(rawText, strPattern, 1); --We look for the pattern

	--local m=0;
	while (start ~= nil) do
		value	= strsub(rawText,start,finish); --Get the whole matched string
		intValue= strlen(value);
		local firstCol  = strsub(value, 1, intChar1);			--Color from the beginning of the string
		local lastCol	= strsub(value, intValue-intChar2);		--Color from the end of the string

		if (firstCol == lastCol) then --no need for strlower since all colors use the same format
			newValue = strsub(value, 1, intValue-intChar1);
			rawText =  StringParsing:replace(rawText, value, newValue);
			finish = 1; --Start from the beginning again since the string has changed
		else
			finish = finish - intChar2; --Include the last of the 2 colors in the search for the next one...
		end

		start, finish, value = strfind(rawText, strPattern, finish); --Do another search
		--m=m+1;
		--if (m>1000) then print("FAIL DOUBLE"); return rawText; end
	end--while

	return rawText;
end]]--


--Clear any colors that only got spaces or control chars in between them (remove the first of the two)
function SyntaxColor:ClearBlankColors(rawText)
	--Removes any colorstrings that are not visible
	--'blue <newline/space> yellow' ==> remove the blue since its not seen.
	local strfind	= strfind; --local fpointer
	local strsub	= strsub;

	local strPattern	= CONST_ClearBlankColor_Pattern;
	local intChar2		= CONST_ClearColor_Start2;	--Calculate once here and recycle in loop

	local start, finish, value = strfind(rawText, strPattern, 1); --We look for the pattern

	--local m=0;
	while (start ~= nil) do
		value			= strsub(rawText,start,finish);	--get the whole matched string
		local newValue	= strsub(value, intChar2);		--get the whole string except the first color (spaces etc we must preserve)

		rawText = StringParsing:replace(rawText, value, newValue);
		start, finish, value = strfind(rawText, strPattern, 1); --Search from the beginning again

		--m=m+1;
		--if (m>1000) then print("FAIL BLANK"); return rawText; end
	end--while

	return rawText;
end


--Traverses the string and put colors around the patterns
function SyntaxColor:doReplacement(rawText, arrList, strPattern, strChar1, strChar2, strStart1, strStart2, strEnd, booExtraFind)
	--If the value is found in arrList then we use strStart1 color otherwise we use strStart2
	if (booExtraFind ~= true) then booExtraFind = false; end

	local strlower	= strlower; --local fpointer
	local strlen	= strlen;
	local strfind	= strfind;
	local strsub	= strsub;

	local intChar1	= strlen(strChar1); --Calculate once here and recycle in loop
	local intChar2	= strlen(strChar2);
	if (booExtraFind == true) then
		intChar1 = intChar1 +1;
		intChar2 = intChar2 +1;
	end

	local strStarting1	= strStart1..strChar1;
	local strStarting2	= strStart2..strChar1;
	local strEnding		= strChar2..strEnd;

	local start, finish, value = strfind(rawText, strPattern, 1); --We look for '%string%'
	if (booExtraFind == true and start ~= nil) then start, finish = strfind(rawText, value, start, true); end --Plain find, Will return nil if not found
	--if start ~= nil then print("list start '"..tostring(start).."' finish '"..tostring(finish).."' value '"..tostring(value).."'"); end

	--local m=0;
	while (start ~= nil) do
		local booTable = false;
		if (arrList ~= nil) then
			local tmpValue = strlower(StringParsing:replace(value, CONST_Cursor, "")); --remove cursor marker if its inside the value before we lookup anything in the table
			--if (value ~= tmpValue) then print("value '"..value.."' tmpValue '"..tmpValue.."'"); end
			for i=1, #arrList do --both tmpValue and the table entries are in lowercase
				if (tmpValue==arrList[i]) then booTable = true; break; end
			end--for i
		end
		--print("value '"..tostring(value).."' booTable '"..tostring(booTable).."'");

		local newValue = "";
		--[[if (strfind(newValue, "|c", 1, true) ~=nil) then
			newValue = self:ClearColor(value, strColors); --clear all existing colors from inside the current value
			print("cleaned colors inside '"..value.."' to '"..newValue.."'");
		end]]--

		if (booTable == true) then
			newValue = strStarting1..value..strEnding;
		else
			newValue = strStarting2..value..strEnding;
		end--if

		local before= strsub(rawText,	1,					start-intChar1);
		local after	= strsub(rawText,	finish+intChar2,	nil);
		rawText = before..newValue..after;

		--print("old '"..value.."' new '"..newValue.."' rawText '"..rawText.."'");
		if (booExtraFind == true) then
			finish = finish + intChar2;
		else
			finish = start + strlen(newValue);
		end

		start, finish, value = strfind(rawText, strPattern, finish);
		if (booExtraFind == true and start ~= nil) then start, finish = strfind(rawText, value, start, true); end --Plain find, Will return nil if not found
		--if start ~= nil then print("start '"..tostring(start).."' finish '"..tostring(finish).."' value '"..tostring(value).."'"); end
		--m=m+1;
		--if (m>1000) then print("FAIL REPLACEMENT"); return rawText; end
	end--while

	return rawText;
end


--Replace special characters inside comments so that they wont be recognised as variables, functions etc
function SyntaxColor:doEscapingWithinComments(rawText, escape, strPattern, strChar1, strChar2, booExtraFind)
	if (booExtraFind ~= true) then booExtraFind = false; end

	local strfind	= strfind; --local fpointer
	local strsub	= strsub;
	local strlen	= strlen;

	local intChar1 = strlen(strChar1);	--Calculate once here and recycle in loop
	local intChar2 = strlen(strChar2);
	if booExtraFind then
		intChar1 = intChar1 +1;
		intChar2 = intChar2 +1;
	end

	local start, finish, value = strfind(rawText, strPattern, 1); --We look for '%string%'
	if (booExtraFind and start ~= nil) then start, finish = strfind(rawText, value, start, true); end --Plain find, Will return nil if not found
	--if start ~= nil then print("list start '"..tostring(start).."' finish '"..tostring(finish).."' value '"..tostring(value).."'"); end
	--local m=0;
	while (start ~= nil) do
		--print("value '"..tostring(value).."' tblValue '"..tostring(tblValue).."'");
		local newValue = self:doCommentEscaping(value, escape);
		newValue = strChar1..newValue..strChar2;

		local before= strsub(rawText,	1,					start-intChar1);
		local after	= strsub(rawText,	finish+intChar1,	nil);
		rawText = before..newValue..after;

		--print("old '"..value.."' new '"..newValue.."' rawText '"..rawText.."'");
		if booExtraFind then
			finish = finish + intChar2;
		else
			finish = start + strlen(newValue);
		end

		start, finish, value = strfind(rawText, strPattern, finish);
		if (booExtraFind and start ~= nil) then start, finish = strfind(rawText, value, start, true); end --Plain find, Will return nil if not found
		--if start ~= nil then print("start '"..tostring(start).."' finish '"..tostring(finish).."' value '"..tostring(value).."'"); end
		--m=m+1;
		--if (m>1000) then print("FAIL ESCAPING"); return rawText; end
	end--while

	return rawText;
end


--Traverses the string and put colors around the pattern
function SyntaxColor:doSimpleReplacement(rawText, strPattern, strStart, strEnd)
	local strlower	= strlower; --local fpointer
	local strlen	= strlen;
	local strfind	= strfind;
	local strsub	= strsub;

	strPattern = strlower(strPattern);
	local start, finish = strfind(strlower(rawText), strPattern, 1, true); --Plain find, Will return nil if not found
	--if start ~= nil then print("list start '"..tostring(start).."' finish '"..tostring(finish).."); end

	local intMatches = 0; --Number of replacements done, translates into how many matches we got in the text

	--local m=0;
	while (start ~= nil) do
		local newValue = strStart..strsub(rawText,start,finish)..strEnd;

		local before= strsub(rawText,	1,				start-1);
		local after	= strsub(rawText,	finish+1,	nil);
		rawText	= before..newValue..after;
		intMatches = intMatches +1;

		--print("new '"..newValue.."' rawText '"..rawText.."'");
		finish = start + strlen(newValue);

		start, finish = strfind(strlower(rawText), strPattern, finish, true); --Plain find, Will return nil if not found
		--m=m+1;
		--if (m>1000) then print("FAIL SIMPLE REPLACEMENT"); return rawText; end
	end--while

	return rawText, intMatches;
end


--Replace escaped characters with placeholders or convert them back into escapesequences after
function SyntaxColor:doCommentEscaping(text, escape)
	local SL = strchar(92); --CHR 92 == '\' (slash)

	if (escape == true) then
		--replace escaped characters with placeholders so we can differentiate between them (must use @ instead of %, since % has a special meaning for the string-replacement patterns in LUA)
		text = StringParsing:replace(text, "%",	"@CESC_P@");
		text = StringParsing:replace(text, ";",	"@CESC_SE@");
		text = StringParsing:replace(text, "(",	"@CESC_L@");
		text = StringParsing:replace(text, ")",	"@CESC_R@");
		text = StringParsing:replace(text, '"',	"@CESC_Q@");
		text = StringParsing:replace(text, ",",	"@CESC_C@");
		text = StringParsing:replace(text, SL,	"@CESC_S@");	--must be the last replacement, since \ is used as the escape character itself (CHR 92 == '\' (slash))
	else
		--replace placeholders with plaintext characters again
		text = StringParsing:replace(text, "@CESC_P@",	"%%");
		text = StringParsing:replace(text, "@CESC_SE@",	";");
		text = StringParsing:replace(text, "@CESC_L@",	"(");
		text = StringParsing:replace(text, "@CESC_R@",	")");
		text = StringParsing:replace(text, "@CESC_Q@",	'"');
		text = StringParsing:replace(text, "@CESC_C@",	",");
		text = StringParsing:replace(text, "@CESC_S@",	SL);	--(CHR 92 == '\' (slash))
	end--if
	return text;
end


--Replace escaped characters with placeholders or convert them back into escapesequences after
function SyntaxColor:doEscaping(text, escape)
	local SL = strchar(92); --CHR 92 == '\' (slash)

	if (escape == true) then
		--replace escaped characters with placeholders so we can differentiate between them (must use @ instead of %, since % has a special meaning for the string-replacement patterns in LUA)
		text = StringParsing:replace(text, SL.."%",	"@ESC_P@");
		text = StringParsing:replace(text, SL..";",	"@ESC_SE@");
		text = StringParsing:replace(text, SL.."(",	"@ESC_L@");
		text = StringParsing:replace(text, SL..")",	"@ESC_R@");
		text = StringParsing:replace(text, SL..'"',	"@ESC_Q@");
		text = StringParsing:replace(text, SL..",",	"@ESC_C@");
		text = StringParsing:replace(text, SL..SL,	"@ESC_S@");	--must be the last replacement, since \ is used as the escape character itself (CHR 92 == '\' (slash))
	else
		--replace placeholders with plaintext characters again
		text = StringParsing:replace(text, "@ESC_P@",	SL.."%");
		text = StringParsing:replace(text, "@ESC_SE@",	SL..";");
		text = StringParsing:replace(text, "@ESC_L@",	SL.."(");
		text = StringParsing:replace(text, "@ESC_R@",	SL..")");
		text = StringParsing:replace(text, "@ESC_Q@",	SL..'"');
		text = StringParsing:replace(text, "@ESC_C@",	SL..",");
		text = StringParsing:replace(text, "@ESC_S@",	SL..SL);	--(CHR 92 == '\' (slash))
	end--if
	return text;
end


--[[Not in use
function SyntaxColor:isColorString(value)
	if (type(value) ~= "string")							then return nil; end
	if (strlen(value) ~= CONST_ClearColor_Start1)			then return nil; end --not N characters long, it cant be a colorstring
	if (StringParsing:startsWith(value, "|cFF") == false)	then return nil; end
	return value;
end]]--


--####################################################################################
--####################################################################################