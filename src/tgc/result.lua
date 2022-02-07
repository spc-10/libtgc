--------------------------------------------------------------------------------
-- ## TgC eval module
--
-- @author Romain Diss
-- @copyright 2019
-- @license GNU/GPL (see COPYRIGHT file)
-- @module result

local Eval    = require "tgc.eval"
local utils   = require "tgc.utils"
local is_date_valid, is_quarter_valid = utils.is_date_valid, utils.is_quarter_valid


--- Result class
-- Sets default attributes and metatables.
local Result = {
    category = "standard", -- same as Eval's default TODO: use a common constant.
}

local Result_mt = {
    __index = Result,
}

--- Compare two Results like `comp` in `table.sort`.
-- Returns true if a < b considering the numerical order of `quarter`,
-- numerical order of `number` and then alphabetic order of `category`.
-- See also https://stackoverflow.com/questions/37092502/lua-table-sort-claims-invalid-order-function-for-sorting
function Result_mt.__lt (a, b)
    -- First compare class
    if a.quarter and b.quarter and a.quarter < b.quarter then
        return true
    elseif a.quarter and b.quarter and a.quarter > b.quarter then
        return false
    -- then compare number
    elseif a.number and b.number and a.number < b.number then
        return true
    elseif a.number and b.number and a.number > b.number then
        return false
    -- then compare category
    elseif a.category and b.category and a.category < b.category then
        return true
    else
        return false
    end
end

--- Creates a new evaluation result.
-- @param o (table) - table containing the evaluation result attributes.
--      o.date (string) - formatted date ("%Y/%m/%d")
--      o.quarter (number) - 1, 2 or 3
--      o.competencies - list of competencies result MUST be adapted to the
--                       eval competency_mask (no check here)
--      o.score (number) - score (no verification against `max_score`)
-- @return s (Result)
function Result.new (o)
    local s = setmetatable({}, Result_mt)

    -- Checks attributes validity
    if (not is_quarter_valid(o.quarter)) or (not tonumber(o.number)) then
        return nil
    end

    -- Assign attributes
    s.number                  = tonumber(o.number)
    s.category                = o.category
    s.date                    = is_date_valid(o.date) and o.date or os.date("%Y/%m/%d")
    s.quarter                 = o.quarter
    s.competencies            = o.competencies
    s.score                   = tonumber(o.score)

    return s
end

--- Update an existing evaluation result.
-- @param o (table) - table containing the evaluation attributes to modify.
-- See Result.new()
-- @return (bool) true if an update has been done, false otherwise.
----------------------------------------------------------------------------------
function Result.update (o)
    local update_done = false

    -- Update valid attributes
    if o.date and is_date_valid(o.date) then
        self.date = o.date
        update_done = true
    end
    if o.quarter and is_quarter_valid(o.quarter) then
        self.quarter = o.quarter
        update_done = true
    end
    if o.competencies
        and type(competencies) == "string"
        and string.match(competencies, "^%s*$") then
        self.competencies = tostring(o.competencies)
        update_done = true
    end
    if tonumber(o.score) then
        self.score = tonumber(o.score)
        update_done = true
    end

    return update_done
end

--- Write the evaluation result in a file.
-- @param f (file) - file (open for reading)
function Result:write (f)
    local format = string.format

    local number, category, quarter, date = self:get_infos()
    local score                           = self:get_score_infos()
    local competencies                    = self:get_competency_infos()

    -- Student attributes
    -- number is only used to find the corresponding eval when reading database
    f:write(format("\t\t{number = %q, ",  number))
    f:write(format("category = %q, ",     category))
    f:write(format("quarter = %q, ",      quarter))
    f:write(format("date = %q, ",         date))
    f:write(format("score = %q, ",        score))
    f:write(format("competencies = %q, ", competencies))

    -- Close
	f:write("},\n")
    f:flush()
end

--- Return the eval result attributes.
function Result:get_infos ()
    return self.number, self.category, self.quarter, self.date
end
function Result:get_score_infos ()
    return self.score
end
function Result:get_competency_infos ()
    return self.competencies
end

--------------------------------------------------------------------------------
--- Print a summary of the evaluation result
--------------------------------------------------------------------------------
function Result:plog (prompt_lvl)
    local prompt_lvl = prompt_lvl or 0
    local tab = "  "
    local prompt = string.rep(tab, prompt_lvl)

    local number, category, quarter, date = self:get_infos()
    local score                           = self:get_score_infos()
    local competencies                    = self:get_competency_infos()
    utils.plog("%s- eval %s [%s]\n", prompt, number, category)
    utils.plog("%s%s- date: %s - quarter %d\n", prompt, tab, date, quarter)
    utils.plog("%s%s- score: %.2f - competencies: %s\n", prompt, tab, score, competencies)
end


return setmetatable({new = Result.new}, nil)
