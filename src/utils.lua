local _M = {}

-- strip_accents
-- https://forums.coronalabs.com/topic/43048-remove-special-characters-from-string/
local table_accents = {
	["à"] = "a", ["á"] = "a", ["â"] = "a", ["ã"] = "a", ["ä"] = "a",
    ["ç"] = "c",
	["è"] = "e", ["é"] = "e", ["ê"] = "e", ["ë"] = "e",
	["ì"] = "i", ["í"] = "i", ["î"] = "i", ["ï"] = "i",
    ["ñ"] = "n",
	["ò"] = "o", ["ó"] = "o", ["ô"] = "o", ["õ"] = "o", ["ö"] = "o",
	["ù"] = "u", ["ú"] = "u", ["û"] = "u", ["ü"] = "u",
	["ý"] = "y", ["ÿ"] = "y",
	["À"] = "A", ["Á"] = "A", ["Â"] = "A", ["Ã"] = "A", ["Ä"] = "A",
    ["Ç"] = "C",
	["È"] = "E", ["É"] = "E", ["Ê"] = "E", ["Ë"] = "E",
	["Ì"] = "I", ["Í"] = "I", ["Î"] = "I", ["Ï"] = "I",
    ["Ñ"] = "N",
	["Ò"] = "O", ["Ó"] = "O", ["Ô"] = "O", ["Õ"] = "O", ["Ö"] = "O",
	["Ù"] = "U", ["Ú"] = "U", ["Û"] = "U", ["Ü"] = "U",
    ["Ý"] = "Y",}

--------------------------------------------------------------------------------
--- Strip accents from a string.
--------------------------------------------------------------------------------
function _M.strip_accents (str)
    local normalized_str = ""

    for char in string.gmatch(str, "([%z\1-\127\194-\244][\128-\191]*)") do
        normalized_str = normalized_str .. (table_accents[char] or char)
    end

    return normalized_str
end

--- Binary insertion.
-- Does a binary insertion of a given value into the table
-- See: http://lua-users.org/wiki/BinaryInsert
-- @param list
-- @param value to insert
-- @param comp[opt] comparison function (default < operator)
function _M.binsert(list, value, comp)
    -- Initialise compare function
    local comp = comp or function(a, b) return a < b end

    --  Initialise numbers
    local istart, iend, imid, istate = 1, #list, 1, 0

    -- Get insert position
    while istart <= iend do
        -- calculate middle
        imid = math.floor((istart + iend) / 2)
        -- compare
        if comp(value, list[imid]) then
            iend, istate = imid - 1, 0
        else
            istart, istate = imid + 1, 1
        end
    end

    table.insert(list, (imid + istate), value)
    return (imid + istate)
end

--------------------------------------------------------------------------------
--- Checks if a date is valid
--  @param date (string) - "%Y/%m/%d" see C strftime()
--  @return (bool)
--------------------------------------------------------------------------------
function _M.is_date_valid (date)
    if type(date) ~= "string" then return false end

    local year, month, day = string.match(date, "(%d%d%d%d)/(%d%d)/(%d%d)")
    if not year then return false end
    if tonumber(month) < 1 or tonumber(month) > 12 then return false end
    if tonumber(day) < 1 or tonumber(day) > 31 then return false end

    return true
end

--------------------------------------------------------------------------------
--- Checks if a quarter is valid
--  @param quarter (number) - 1, 2 or 3 are valid!
--  @return (bool)
--------------------------------------------------------------------------------
function _M.is_quarter_valid (quarter)
    if not tonumber(quarter) then return false end
    if quarter ~= 1 and quarter ~= 2 and quarter ~= 3 then return false end

    return true
end

--------------------------------------------------------------------------------
--- Checks if a file exists (or at least could be opened for reading.
--------------------------------------------------------------------------------
function _M.file_exists (name)
   local f = io.open(name, "r")
   if not f then
       io.close(f) ; return true
   else return false, string.format("File %s can not be opened.", name) end
end

--------------------------------------------------------------------------------
--- Prints a warning message on the stderr.
--------------------------------------------------------------------------------
function _M.warning (s, ...)
    s = "Warning: " .. s
    return io.stderr:write(s:format(...))
end

return _M
