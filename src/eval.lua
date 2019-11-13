--[[This module provides functions to handle evaluations.

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

--------------------------------------------------------------------------------
--- EVALUATION CLASS
--
-- It contains all the information concerning the evaluations.
--------------------------------------------------------------------------------

local Eval = {}

local Eval_mt = {
    __index = Eval,
    __pairs = _evalpairs}

----------------------------------------------------------------------------------
--- Creates a new evaluation.
--
-- @param o (table) - table containing the evaluation attributes.
--      o.number (number) - evaluation number
--      o.class (string) - a class name or a class pattern
--      o.category (string)
--      o.title (string)
--      o.competency_mask (string)
--      o.competency_score_mask (string)
--      o.max_score (number)
-- @return s (Eval)
----------------------------------------------------------------------------------
function Eval.new (o)
    local s = setmetatable({}, Eval_mt)
    local msg = nil

    -- Make sure number and class are non empty fields
    if not tonumber(o.number) or not o.class or string.match(o.class, "^%s*$") then
        msg = "cannot create an eval without valid number or class"
        return ni, msg
    end

    -- Checks other attributes validity
    -- TODO category, masks

    -- Assign attributes
    s.number                  = tonumber(o.number)
    s.class                   = tostring(o.class)
    s.category                = o.category
    s.title                   = o.title
    s.competency_mask         = o.competency_mask
    s.competency_score_mask   = o.competency_score_mask
    s.max_score               = tonumber(o.max_score)

    return s
end

----------------------------------------------------------------------------------
--- Update an existing evaluation.
--
-- @param o (table) - table containing the evaluation attributes to modify.
--      o.category (string)
--      o.title (string)
--      o.competency_mask (string)
--      o.competency_score_mask (string)
--      o.max_score (number)
-- @return (bool) true if an update has been done, false otherwise.
----------------------------------------------------------------------------------
function Eval.update (o)
    local update_done = false

    -- Update valid non empty attributes
    if o.category
        and type(o.category) == "string"
        and not string.match(o.category, "^%s*") then
        self.category = o.category
        update_done = true
    end
    if o.title
        and type(o.title) == "string"
        and not string.match(o.title, "^%s*") then
        self.title = o.title
        update_done = true
    end
    if o.competency_mask
        and type(o.competency_mask) == "string"
        and not string.match(o.competency_mask, "^%s*") then
        self.competency_mask = o.competency_mask
        update_done = true
    end
    if o.competency_score_mask
        and type(o.competency_score_mask) == "string"
        and not string.match(o.competency_score_mask, "^%s*") then
        self.competency_score_mask = o.competency_score_mask
        update_done = true
    end
    if tonumber(o.max_score) then
        self.max_score = tonumber(o.max_score)
        update_done = true
    end

    return update_done
end

--------------------------------------------------------------------------------
--- Write the evaluation in a file.
--
-- @param f (file) - file (open for reading)
--------------------------------------------------------------------------------
function Eval:write (f)
    local format = string.format

    local number, class         = self:get_number(), self:get_class()
    local category, title       = self:get_category(), self:get_title()
    local competency_mask       = self:get_competency_mask()
    local competency_score_mask = self:get_competency_score_mask()
    local max_score             = self:get_max_score()

    -- Open
	f:write("evaluation_entry{\n\t")

    -- Student attributes
    f:write(format("number = %q, ",                    number))
    f:write(format("class = %q, ",                     class))
    if category then
        f:write(format("category = %q, ",              category))
    end
	f:write("\n\t")
    if title then
        f:write(format("title = %q, ",                 title))
        f:write("\n\t")
    end
    local written_score = false
    if competency_mask then
        f:write(format("competency_mask = %q, ",       competency_mask))
        written_score = true
    end
    if competency_score_mask then
        f:write(format("competency_score_mask = %q, ", competency_score_mask))
        written_score = true
    end
    if max_score then
        f:write(format("max_score = %q, ",             max_score))
        written_score = true
    end
    if written_score then
        f:write("\n")
    end

    -- Close
	f:write("}\n")
    f:flush()
end

--------------------------------------------------------------------------------
--- Return the eval attributes.
--------------------------------------------------------------------------------
function Eval:get_number ()                return self.number end
function Eval:get_class ()                 return self.class end
function Eval:get_category ()              return self.category end
function Eval:get_title ()                 return self.title end
function Eval:get_competency_mask ()       return self.competency_mask end
function Eval:get_competency_score_mask () return self.competency_score_mask end
function Eval:get_max_score ()             return self.max_score end


--------------------------------------------------------------------------------
--- Print a summary of the evaluation
--------------------------------------------------------------------------------
function Eval:plog ()
    local function plog (s, ...) print(string.format(s, ...)) end
    local prompt = "tgc.eval>"

    plog("%s number: %q.",                prompt, self:get_number())
    plog("%s class: %q.",                 prompt, self:get_class())
    plog("%s category: %q.",              prompt, self:get_category())
    plog("%s title: %q.",                 prompt, self:get_title())
    plog("%s competency_mask: %q.",       prompt, self:get_competency_mask())
    plog("%s competency_score_mask: %q.", prompt, self:get_competency_mask())
    plog("%s max_score: %q.",             prompt, self:get_max_score())
end


return setmetatable({new = Eval.new}, nil)
