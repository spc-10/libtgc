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

return _M
