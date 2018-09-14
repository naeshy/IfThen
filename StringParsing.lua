--####################################################################################
--####################################################################################
--String parsing functions
--####################################################################################
--Dependencies: none

local StringParsing		= {};
StringParsing.__index	= StringParsing;
IfThen_StringParsing	= StringParsing; --Global declaration


--Local variables that cache stuff so we dont have to recreate large objects
local CONST_escapeMagicalCharacters	= {"(",")",".","%","+","-","*","?","[","]","^","$"}; --Hardcoded, these are the magical characters that have special meaning when it comes to LUA patterns, by adding % infront of them we escape them
local CONST_escapeMagicalPattern	= "[%(%)%.%%%+%-%*%?%[%]%^%$]+"; --Pattern used to determine if a magical char is in the string


--Local pointers to global functions
local type		= type;
local tonumber	= tonumber;
local tostring	= tostring;
--local pairs	= pairs;
--local ipairs	= ipairs;
local math_abs	= abs;		--math.abs
local math_floor= floor;	--math.floor
--local math_random=random;	--math.random
--local format	= format;
local strlen	= strlen;
local strfind	= strfind;
local strsub	= strsub;
local strlower	= strlower;
local strupper	= strupper;
local strrep	= strrep;
local gsub		= gsub;		--string.gsub
--local strtrim	= strtrim;	--string.trim
local strrev	= strrev;	--string.reverse
local tinsert	= tinsert;	--table.insert
--local sort	= sort;		--table.sort
--local select 	= select;


--Will attempt to unformat strings by removing any spaces and commas before casting.
function StringParsing:tonumber(e, base)
	if (type(e) == "string") then
		e = gsub(e, " ", "");  --Remove any spaces
		e = gsub(e, ",", "");  --Remove any commas (US formatting uses comma as thousand separator, EU uses comma as decimal marker tho so it might mess up)
	end
	return tonumber(e,base);
end


--Format a number by adding "K" or "M"
function StringParsing:numberFormatK(intNumber, numDecimals, booRound)
	if (intNumber == nil) then return nil; end
	if (type(intNumber) ~= "number" or intNumber < 0) then return intNumber; end
	if (booRound ~= true) then booRound = false; end

	local k = intNumber / 1000;		--12.57K
	local m = intNumber / 1000000;	--34.76M
	local p = "";	--Prefix to use

	if (k >= 1) then intNumber = k; p = "K"; end
	if (m >= 1) then intNumber = m; p = "M"; end
	if (booRound) then
		intNumber = math_floor(intNumber+0.5);	--round to nearest integer
		if (numDecimals  == nil) then numDecimals = 0; end --dont show any decimals if we round the number and its not specified
	end
	intNumber = self:format_num(intNumber, numDecimals, true);
	return intNumber..p, intNumber; --return stringformattet number, number without K/M string
end


--Format a number with spaces as thousand separator. Default is 0 decimals.
function StringParsing:numberFormat(intNumber, numDecimals)
	return self:format_num(intNumber, numDecimals, true);
end
	function StringParsing:format_num(amount, decimal, booSpace, prefix, neg_prefix)
		decimal		= decimal or 0;			-- Default 0 decimal places
		neg_prefix	= neg_prefix or "-";	-- Default negative sign

		local famount	= math_abs(self:round(amount, decimal));
		famount			= math_floor(famount);

		local remain	= self:round(math_abs(amount) - famount, decimal);
		local formatted	= self:comma_value(famount, booSpace);	--comma/space to separate the thousands

		--Attach the decimal portion
		if (decimal > 0) then
			remain		= strsub(tostring(remain), 3);
			formatted	= formatted .. "." .. remain .. strrep("0", decimal - strlen(remain));
		end--if

		--Attach prefix string e.g '$'
		formatted = (prefix or "") .. formatted;

		--If value is negative then format accordingly
		if (amount<0) then
			if (neg_prefix=="()") then
				formatted = "("..formatted ..")";
			else
				formatted = neg_prefix .. formatted;
			end--if
		end--if

		return formatted;
	end
	function StringParsing:round(val, decimal)
		if (decimal) then	return math_floor( (val * 10^decimal) + 0.5) / (10^decimal);
		else				return math_floor(val+0.5); end
	end
	function StringParsing:comma_value(amount, booSpace)
	local formatted						= amount;
	local strFormatString				= '%1,%2';		--comma as separator
	if (booSpace) then strFormatString	= '%1 %2'; end	--just space as separator
	local gsub = gsub; --local fpointer

	while true do
		formatted, k = gsub(formatted, "^(-?%d+)(%d%d%d)", strFormatString);
		if (k==0) then break; end
	end--while
	return formatted;
end


--Split a string into an array using 'item' as a separator
function StringParsing:split(str, item)
	if (str == nil or str == "" or item == nil or item == "") then return nil end
	if (strlen(item) > strlen(str)) then return nil end

	local sPos		= self:indexOf(str, item, 1); --find index of splitter
	if (sPos == nil) then return nil end --exit condition if there are no more splitters
	local tinsert	= tinsert; --local fpointer
	local strsub	= strsub;
	local strlen	= strlen;

	local res = {};
	while (sPos ~=nil) do
		local line = strsub(str, 1, (sPos-1)); --extract the line from the string (except the item itself)
		tinsert(res,line); --add the line into the array

		str  = strsub(str,(sPos+strlen(item)),-1); --remove the part of the string that we just added to the array
		sPos = self:indexOf(str, item, 1); --find the next index of splitter
	end
	--Append the remainder of the string as the last item
	if (strlen(str) > 0) then tinsert(res, str) end

	return res;
end


--Returns the index of the first found occurence of a string (left to right), will return nil if not found
function StringParsing:indexOf(str, item, startPos)
	if (str == nil or str == "" or item == nil or item == "") then return nil end
	if (strlen(item) > strlen(str) or startPos > strlen(str)) then return nil end
	if (startPos < 1) then startPos = 1 end
	return strfind(str, item, startPos, true); --Plain find, Will return nil if not found
end


--Returns the index of the first found occurence of a string (left to right), will recursivly call itself reducing the searchstring
function StringParsing:partialIndexOf(str, item, startPos, minimal, reverse)
	--This function will recursivly call itself to search for 'item' inside the 'str' provided.
	--For each call it will reduce the 'item' string's length with 1 character.
	--The idea is to search inside a large text for where the beginning of a string is, but the ending might be fuzzy
	--	str:		Body of text to search within
	--	item:		The line to search for
	--	startPos:	Start index position for the search
	--	minimal:	Optional; Default is 1. Used to determine the minimum length of 'item' before it returns nil.
	--	reverse:	Optional; substring at the beginning or at the end of the string

	if (str == nil or str == "" or item == nil or item == "") then return nil end
	if (strlen(item) > strlen(str)) then return nil end
	if (startPos < 1) then startPos = 1 end

	minimal = tonumber(minimal);
	if (minimal == nil)			then minimal = 1 end	--default value; first call
	if (minimal < 1)			then minimal = 1 end	--lower bound
	if (minimal > strlen(item)) then return nil end		--upper bound; fail here and we return immediatly
	if (reverse ~= true) then reverse = false end		--boolean

	local start	= strfind(str, item, startPos, true); --search for it

	if (start ~= nil) then
		return start; --match was found, return the index
	else
		--Match not found. Need to do a recursive call but with 1 less character in the string
		local last = strlen(item) -1; --Reduce with 1
		if (last < minimal) then return nil; end --exit condition; string was not found

		if (reverse == true) then
			item = strsub(item, 2); --remove 1 character from the beginning of the string
		else
			item = strsub(item, 1, last); --remove 1 character from the end of the string
		end
		return self:partialIndexOf(str, item, startPos, minimal, reverse); --Recursive call
	end
end


--Remove the string without the item at its beginning (if anything errors then the original string will be returned)
function StringParsing:removeAtStart(str, item, ignoreCase)
	if (str == nil or str == "" or item == nil or item == "") then return str end
	if (ignoreCase ~= true) then
		if (strlen(item) > strlen(str) or not self:startsWith(str,item)) then return str end
	else
		if (strlen(item) > strlen(str) or self:startsWith(strlower(str),strlower(item)) ~= true) then return str end
	end--
	local Pos1 = strlen(item) + 1;
	return strsub(str,Pos1,-1);
end


--Replaces any occurences of 'old' with 'new'
function StringParsing:replace(str, old, new)
	old = self:escapeMagicalCharacters(old); --escape any magical characters so that they are seen as literal strings
	return gsub(str, old, new);
end


--[[Replaces any occurences of 'old' with 'new', case-insensitive
function StringParsing:replaceNoCase(str, old, new)
	local strlower	= strlower; --local fpointer

	old = strlower(old);
	if (old == strlower(new)) then return str; end--if we didnt have this then we would get into an infinite loop

	local strfind	= strfind; --local fpointer
	local strsub	= strsub;
	local gsub		= gsub;

	while true do
		local start, finish = strfind(strlower(str), old, 1, true); --plain string search with lowercase version to get start and finish location
		if (start == nil) then break; end
		local value	= strsub(str, start, finish);			--pull out exact string as it is written
		value		= self:escapeMagicalCharacters(value);	--escape any magical characters so that they are seen as literal strings
		str = gsub(str, value, new);						--replace exact string with new value
	end--while

	return str;
end]]--


--Replaces any occurences of ( ) . % + - * ? [ ] ^ $ by adding a % ahead of it
function StringParsing:escapeMagicalCharacters(str)
	local start = strfind(str, CONST_escapeMagicalPattern, 1); --We look for any of the magical characters, if none are in there then skip the loop
	if (start == nil) then
		return str;
	else
		local strlen = strlen; --local fpointer
		local strsub = strsub;
		local res = "";
		local esc = CONST_escapeMagicalCharacters;
		for i = 1, strlen(str) do
			local char = strsub(str,i,i);
			for j = 1, #esc do
				if (char == esc[j]) then
					char = "%"..char;
					break;
				end--if
			end--for j
			res = res..char;
		end--for i
		return res;
	end
end


--Returns true/false whether a string starts with the given item
function StringParsing:startsWith(str, item)
	if (str == nil or str == "" or item == nil or item == "") then return false end
	if (strlen(item) > strlen(str)) then return false end

	local sPos1 = strfind(str, item, 1, true); --plain find starting at pos 1 in the string
	if (sPos1 == 1) then return true end --if the string starts at the first position in the string then we accept it
	return false;
end


--Returns true/false whether a string ends with the given item
function StringParsing:endsWith(str, item)
	if (str == nil or str == "" or item == nil or item == "") then return false end
	if (strlen(item) > strlen(str)) then return false end
	local strR, itemR  = strrev(str), strrev(item); --reverse the strings

	local sPos1 = strfind(strR, itemR, 1, true); --plain find starting at pos 1 in the string
	if (sPos1 == 1) then return true end --if the string starts at the first position in the string then we accept it
	return false;
end


--[[Trims the string for leading and trailing spaces function StringParsing:trim(str) return strtrim(str, nil); --Source: http://wowprogramming.com/docs/api/strtrim end]]--
--Left Trim the string
function StringParsing:ltrim(str)
	--Based on pattern from: http://lua-users.org/wiki/StringTrim
	local res = (gsub(str, "^%s*(.-)$", "%1")); --spaces
	res       = (gsub(res, "^%c*(.-)$", "%1")); --control characters
	return res;
end


--Right Trim the string
function StringParsing:rtrim(str)
	--Based on pattern from: http://lua-users.org/wiki/StringTrim
	local res = (gsub(str, "(.-)%s*$", "%1")); --spaces
	res       = (gsub(res, "(.-)%c*$", "%1")); --control characters
	return res;
end


--Format the number according to the format string.
function StringParsing:stringFormatNumber(intValue, strFormat)
	if (strFormat == nil or strFormat == "") then return intValue; end
	--[[strFormat:
			'PLAYERTITLE' == Uppercase									(no formatting	+ with 0 decimals)
			'playertitle' == Lowercase									(formatting		+ with 0 decimals)
			'Playertitle' == Capitalize first letter of the string		(no formatting	+ with 2 decimals)
			'PlayerTitle' == Capitalize first letter of every word		(formatting		+ with 2 decimals)
			'playerTitle' == Return string as it came in 				(return raw number)		--(default capitalization for the string)
	]]--

	local str_Org	= tostring(strFormat);
	local str_Upper	= strupper(tostring(strFormat));
	local str_Lower	= strlower(tostring(strFormat));

	if (str_Org == str_Upper) then return self:round(intValue, nil); end		---Return 'no formatting + with 0 decimals'
	if (str_Org == str_Lower) then return self:numberFormat(intValue, 0); end	--Return 'formatting + with 0 decimals'

	local booFirst	= false;	--True if first char is uppercase
	local booMiddle = false;	--True if a char inside the string is uppercase

	local strsub = strsub; --local fpointer
	local tmpO = strsub(str_Org, 1,1);			--Get first char
	local tmpU = strsub(str_Upper, 1,1);
	if (tmpO == tmpU) then booFirst = true; end --if

	for i=2, strlen(str_Org) do --For each char (skip the first char)
		local tmpO = strsub(str_Org,   i,i);
		local tmpU = strsub(str_Upper, i,i);
		if (tmpO == tmpU) then
			booMiddle = true;
			break;
		end--if
	end--for i

	if (booFirst and booMiddle) then
		return self:numberFormat(intValue, 2); --Return 'formatting + with 2 decimals'

	elseif (booFirst and not booMiddle) then
		return self:round(intValue, 2); --Return 'no formatting + with 2 decimals'

	else --elseif (not booFirst and booMiddle) then
		return intValue; --Return raw number
	end--if
end


--Capitalize all of the words in the inputted string according to the format string.
function StringParsing:capitalizeWords(strValue, strFormat)
	if (strValue == nil or strValue == "" or strFormat == nil or strFormat == "") then return strValue; end
	--[[strFormat:
			'PLAYERTITLE' == Uppercase									(all uppercase characters)
			'playertitle' == Lowercase									(all lowercase characters)
			'Playertitle' == Capitalize first letter of the string		(first char is uppercase + rest is lowercase)
			'PlayerTitle' == Capitalize first letter of every word		(first char is uppercase + one other char in the string is uppercase)
			'playerTitle' == Return string as it came in 				(first char is lowercase + one other char in the string is uppercase)		--(default capitalization for the string)
	]]--

	local str_Org	= tostring(strFormat);
	local str_Upper	= strupper(tostring(strFormat));
	local str_Lower	= strlower(tostring(strFormat));

	if (str_Org == str_Upper) then return strupper(strValue) end --Return all uppercase letters
	if (str_Org == str_Lower) then return strlower(strValue) end --Return all lowercase letters

	local booFirst	= false;	--True if first char is uppercase
	local booMiddle = false;	--True if a char inside the string is uppercase

	local strsub = strsub; --local fpointer
	local tmpO = strsub(str_Org, 1,1);			--Get first char
	local tmpU = strsub(str_Upper, 1,1);
	if (tmpO == tmpU) then booFirst = true; end --if

	for i=2, strlen(str_Org) do --For each char (skip the first char)
		local tmpO = strsub(str_Org,   i,i);
		local tmpU = strsub(str_Upper, i,i);
		if (tmpO == tmpU) then
			booMiddle = true;
			break;
		end--if
	end--for i

	if (booFirst and booMiddle) then
		--Capitalize the first character in each word
		local tmpSplit = self:split(strValue, " ");
		if (tmpSplit == nil) then return self:capitalizeString(strValue); end --String is only 1 word so we just capitalize it

		local tmpV = self:capitalizeString(tmpSplit[1]); --First word in the string
		for i=2, #tmpSplit do --For each word...
			tmpV = tmpV.." "..self:capitalizeString(tmpSplit[i]); --Add words to string again and a space
		end--for i
		return tmpV;

	elseif (booFirst and not booMiddle) then
		--Capitalize only the first letter of the whole string
		return self:capitalizeString(strValue);

	else --elseif (not booFirst and booMiddle) then
		--Do nothing with the string
		return strValue;
	end--if
	--return strValue; --Should not happen
end


--Capitalize the first character of the string
function StringParsing:capitalizeString(strValue)
	if (strValue == nil or strValue == "") then return strValue; end
	if (strlen(strValue) <= 1) then return strupper(strValue); end	--Just 1 char long so we uppercase it

	local firstChar = strupper(strsub(strValue, 1,1));	--Uppercase first char in string
	local restChars = strlower(strsub(strValue, 2));	--Lowercase the rest
	return (firstChar..restChars);
end


--####################################################################################
--####################################################################################