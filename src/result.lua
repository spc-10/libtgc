--[[This module provides functions to handle evaluation result.

    Copyright (C) 2016 by Romain Diss

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
--]]

local utils   = require("tgc.utils")
local is_date_valid, is_quarter_valid = utils.is_date_valid, utils.is_quarter_valid


--------------------------------------------------------------------------------
--- Iterates over the ordered evaluations (for __pairs metatable).
--------------------------------------------------------------------------------
local function _evalpairs (t)
    local a, b = {}, {}

    -- First we store the eval ids with associated date in a table
    for k, v in next, t do
        a[v.date] = k
    end
    -- Next we store the date in another table to sort them
    for k in next, a do
        b[#b + 1] = k
    end
    table.sort(b)

    -- Now we can return an iterator which iterates over the sorted dates and
    -- return the corresponding id and the corresponding eval.
    local i = 1
    return function ()
        local k = a[b[i]] -- this is the eval id (sorted by date)
        i = i + 1

        return k, t[k]
    end
end

local Result = {}

local Result_mt = {
    __index = Result,
    __pairs = _evalpairs}

----------------------------------------------------------------------------------
--- Creates a new evaluation result.
--
-- @param o (table) - table containing the evaluation result attributes.
--      o.eval (Eval) - link to the corresponding evaluation
--      o.date (string) - formatted date ("%Y/%m/%d")
--      o.quarter (number) - 1, 2 or 3
--      o.competencies - list of competencies result MUST be adapted to the
--                       eval competency_mask (no check here)
--      o.score (number) - score MUST correspond to the eval max_score (no
--                         check done here)
-- @return s (Result)
----------------------------------------------------------------------------------
function Result.new (o)
    local s = setmetatable({}, Result_mt)
    local msg = nil

    -- Make sure the result have an associated quarter
    if not is_quarter_valid(o.quarter) then
        msg = "cannot create an eval result without a valid quarter"
        return nil, msg
    end                                                                                                                                  
    -- Make sure the link to the database is ok
    if not o.eval or type(o.eval ~= "table") then
        msg = "cannot create an eval result without a valid link to evaluations"
    end

    -- Checks other attributes validity
    if not is_date_valid(o.date) then
        o.date = nil
    end
    --if competencies then
    --    -- TODO Check if competencies correspond to the mask
    --end
    --if score then
    --    -- TODO Check if the score do not exceed the max_score
    --end

    -- Assign attributes
    s.eval                    = o.eval
    s.date                    = o.date
    s.quarter                 = o.quarter
    s.competencies            = o.competencies
    s.score                   = tonumber(o.score)

    return s
end

----------------------------------------------------------------------------------
--- Update an existing evaluation result.
--
-- @param o (table) - table containing the evaluation attributes to modify.
--      o.category (string)
--      o.title (string)
--      o.competencies_list (string)
--      o.competency_mask (string)
--      o.max_score (number)
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

--------------------------------------------------------------------------------
--- Write the evaluation result in a file.
--
-- @param f (file) - file (open for reading)
--------------------------------------------------------------------------------
function Result:write (f)
    local format = string.format

    -- Open is done ont the Student:write() method

    -- Student attributes
    -- number is only used to find the corresponding eval when reading database
    print("get_eval =  ", self:get_eval())
    print("eval =  ", self.eval)
    f:write(format("\t\t{number = %q, ",  self:get_eval():get_number()))
    f:write(format("date = %q, ",         self:get_date()))
    f:write(format("quarter = %q, ",      self:get_quarter()))
    f:write(format("competencies = %q, ", self:get_competencies()))
    f:write(format("score = %q, ",        self:get_score()))

    -- Close
	f:write("},\n")
    f:flush()
end

--------------------------------------------------------------------------------
--- Return the eval result attributes.
--------------------------------------------------------------------------------
function Result:get_eval ()         return self.eval end
function Result:get_date ()         return self.date end
function Result:get_quarter ()      return self.quarter end
function Result:get_competencies () return self.competencies end
function Result:get_score ()        return self.score end

--------------------------------------------------------------------------------
--- Print a summary of the evaluation result
--------------------------------------------------------------------------------
function Result:plog ()
    local function plog (s, ...) print(string.format(s, ...)) end
    local prompt = "tgc.result>"

    plog("%s date: %q.",                  prompt, self:get_date())
    plog("%s quarter: %q.",               prompt, self:get_quarter())
    plog("%s competencies: %q.",          prompt, self:get_competencies())
    plog("%s score: %q.",                 prompt, self:get_score())
    self:get_eval():plog()
end


return setmetatable({new = Result.new}, nil)
