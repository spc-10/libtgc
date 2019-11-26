--[[This module provides functions to handle evaluations by competences.

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

local Result    = require "tgc.result"
local Eval      = require "tgc.eval"
--local find_eval = require "tgc".find_eval()


--------------------------------------------------------------------------------
--- STUDENT CLASS
--
-- It contains all the information concerning the student.
--------------------------------------------------------------------------------

local Student    = {}
local Student_mt = {__index = Student}


----------------------------------------------------------------------------------
--- Creates a new student.
--
-- @param o (table) - table containing the student attributes.
--      o.lastname (string)                                                                                                              
--      o.name (string)
--      o.class (string)
--      o.place (number) *optional*
--      o.increased_time (bool) *optional* PAP
--      o.students (Student[]) - 
--      o.evaluations (Eval[]) - 
--      o.classes (table) - 
--      o.results (Result[]) - 
--      o.reports (Report[]) - 
-- @return s (Student), [msg (string)] - Return nil, msg if invalid attributes.
----------------------------------------------------------------------------------
function Student.new (o)
    local s = setmetatable({}, Student_mt)
    local msg = nil

    -- Make sure the student get non empty name, lastname and class!
    if not o.lastname or not o.name or not o.class 
        or string.find(o.lastname, "^%s*$")
        or string.find(o.name, "^%s*$")
        or string.find(o.class, "^%s*$") then
        msg = "cannot create a student without lastname, name or class"
        return nil, msg
    end
    -- Make sure the link to the database is ok
    if not o.db or type(o.db ~= "table") then
        msg = "cannot create a student without a valid database link"
    end

    -- Links to the student and evaluations lists in the database
    s.db             = o.db

    -- Main student attributes
    s.lastname       = o.lastname
    s.name           = o.name
    s.class          = o.class
    s.increased_time = o.increased_time and true or false
    s.place          = tonumber(o.place)

    -- Create the evaluation results
    s.results = {}
    if o.results and type(o.results) == "table" then
        for n = 1, #o.results do
            local eval = nil
            local result = o.results[n]
            if result and type(result) == "table" then
                eval = s.db:find_eval(result.number, s.class)
            end
            -- Add the eval link to the result
            result.eval = eval
            -- Insert the new result
            table.insert(s.results, Result.new(result))
        end
    end

    -- Creates the reports (after some checks)
    -- TODO
    s.reports = {}
    if o.reports and type(o.reports) == "table" then
        for n = 1, #o.reports do
            if type(o.reports[n]) == "table" then
                local already_exists = s:add_report(o.reports[n])
                msg = "Error: %s %s can not have two reports the same quarter.\n"
                assert(not already_exists, msg:format(s.lastname, s.name))
            end
        end
    end

    return s, msg
end

--------------------------------------------------------------------------------
--- Update an existing student 
--
-- @param o (table) - table containing the student attributes.
--      o.lastname (string)                                                                                                              
--      o.name (string)
--      o.class (string)
--      o.place (number) *optional*
--      o.increased_time (number) *optional* PAP
--      o.students (Student[]) - 
--      o.evaluations (Eval[]) - 
--      o.classes (table) - 
-- @return (bool) - true if an attribute has been updated
--------------------------------------------------------------------------------
function Student:update (o)
    o = o or {}
    local update_done = false

    -- Update valid non empty attributes
    if type(o.lastname) == "string"
        and string.match(o.lastname, "^%s*$") then
        self.lastname = tostring(o.lastname)
        update_done = true
    end
    if type(o.name) == "string"
        and string.match(o.name, "^%s*$") then
        self.name = tostring(o.name)
        update_done = true
    end
    if type(o.class) == "string"
        and string.match(o.class, "^%s*$") then
        self.class = tostring(o.class)
        update_done = true
    end
    if type(o.increased_time) == "boolean" then
        self.increased_time = tostring(o.increased_time)
        update_done = true
    end
    if tonumber(o.place) then
        self.place = tonumber(o.place)
        update_done = true
    end

    return update_done
end

--------------------------------------------------------------------------------
--- Write the database in a file.
--
-- @param f (file) - file (open for reading)
--------------------------------------------------------------------------------
function Student:write (f)
    local place          = self:get_place()
    local increased_time = self:get_increased_time()
    local results        = self:get_results()
    local reports        = self:get_reports()

    -- Open
	f:write("student_entry{\n\t")

    -- Student attributes
    f:write(string.format("lastname = %q, ",           self:get_lastname()))
    f:write(string.format("name = %q, ",               self:get_name()))
    f:write(string.format("class = %q, ",              self:get_class()))
    if place then
        f:write(string.format("place = %q, ",          place))
    end
    if increased_time then
        f:write("\n\t")
        f:write(string.format("increased_time = %q, ", increased_time))
    end
    --f:write("\n\t"))
    --f:write(string.format("special = %q, ",  self.special))
    f:write("\n")

	-- Only print non empty results
    if type(results) == "table" and next(results) then
        f:write("\tresults = {\n")
        for _, result in pairs(self:get_results()) do
            result:write(f)
        end
        f:write("\t},\n")
    end

	-- Reports
    -- TODO
    if type(reports) == "table" and next(reports) then
        f:write("\treports = {\n")
        for i, report in ipairs(reports) do
            f:write(string.format("\t\t{quarter = %q,\n", i))
            f:write(string.format("\t\t\tresult = %q, ", tostring(report.result)))
            f:write(string.format("score = %q},\n", report.score or nil))
        end
        f:write("\t},\n")
    end

    -- Close
	f:write("}\n")
    f:flush()
end

--------------------------------------------------------------------------------
--- Return the student attributes
--------------------------------------------------------------------------------
function Student:get_lastname ()       return self.lastname end
function Student:get_name ()           return self.name end
function Student:get_class ()          return self.class end
function Student:get_place ()          return self.place end
function Student:get_increased_time () return self.increased_time end
function Student:get_results ()        return self.results end
function Student:get_reports ()        return self.reports end

--------------------------------------------------------------------------------
--- Returns the full name of a student.
--
-- @param options (table) - [optional] options to format the name.
--      - options.reverse (bool)
-- @return fullname (string)
--------------------------------------------------------------------------------
function Student:get_fullname (options)
    options = options or {}
    local reverse = options.reverse or false
    local sep = " "

    if reverse then
        return self.name .. sep .. self.lastname
    else
        return self.lastname .. sep .. self.name
    end
end

--------------------------------------------------------------------------------
--
-- EVALUATIONS
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--- Add an evaluation result in the student corresponding list.
--
-- @param o (table) - the evaluation result attributes.
-- @return nil, msg if no result is added.
--------------------------------------------------------------------------------
function Student:add_result (o)
    local class = self:get_class()
    local eval  = self.db:find_eval(o.number, class)

    if not eval then return nil, "cannot add result: eval not found" end

    -- add the eval link to the result
    o.eval = eval
    -- create the result
    local new = Result.new(o)
    table.insert(self.results, new)
    return new
end

--------------------------------------------------------------------------------
--- Iterates over the eval ids of the student.
--
-- @param quarter (number) - [optional] the quarter (all if nil)
--------------------------------------------------------------------------------
function Student:next_result (quarter)
    quarter = tonumber(quarter) or nil
    local a, b = {}, {}

    -- First we store the eval ids with associated date in a table
    for id, eval in next, self.evaluations do
        if not quarter or eval.quarter == quarter then
            a[eval.date] = id
        end
    end 
    -- Next we store the date in another table to sort them
    for date in next, a do
        b[#b + 1] = date
    end
    table.sort(b)

    -- Now we can return an iterator which iterates over the sorted dates and
    -- return the corresponding id and the corresponding eval.
    local i = 1
    return function ()
        local k = a[b[i]] -- this is the eval id (sorted by date)
        i = i + 1

        return k, self.evaluations[k]
    end
end

----------------------------------------------------------------------------------
--- Return a result that sums the results of all the corresponding evals.
--
-- @param quarter (number)
-- @return result (string)
-- TODO
----------------------------------------------------------------------------------
function Student:sum_eval_results (quarter, comp)
    quarter = quarter and tonumber(quarter)
    local result = Result.new()
    for _, eval in pairs(self.evaluations) do -- __pairs should sort this
        if not quarter or eval.quarter == quarter then
            result = result + eval.result
        end
    end

    if comp and result:get_grades(comp) then
        return comp .. result:get_grades(comp)
    else
        return tostring(result)
    end
end

--- DEBUG
-- TODO : à terminer
function Student:plog ()
    local function plog (s, ...) print(string.format(s, ...)) end
    local prompt = "tgc.student>"

    plog("%s %q (%q)", prompt, self:get_fullname(), self:get_class())
end


return setmetatable({new = Student.new}, nil)
