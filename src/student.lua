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

local Result = require("tgc.result")


--------------------------------------------------------------------------------
--- STUDENT CLASS
--
-- It contains all the information concerning the student.
--------------------------------------------------------------------------------

local Student = {
}
local Student_mt = {__index = Student}

--------------------------------------------------------------------------------
--- Iterates over the ordered evaluations (for __pairs metatable).
--------------------------------------------------------------------------------
local function _evalpairs (t)
    local a, b = {}, {}

    -- First we store the eval ids with associated date in a table
    for k, v in next, t do a[v.date] = k end
    -- Next we store the date in another table to sort them
    for k in next, a do b[#b + 1] = k end
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

local eval_mt = {__pairs = _evalpairs}

----------------------------------------------------------------------------------
--- Creates a new student.
--
-- @param o (table) - table containing the student attributes.
-- @return s (Student)
----------------------------------------------------------------------------------
function Student.new (o)
    local s = setmetatable({}, Student_mt)

    -- Makes sure the student get a name, a lastname and a class!
    -- TODO assert_*() function to check this
    assert(o.lastname and o.lastname ~= "",
        "Error: can not create a student without lastname.\n")
    assert(o.name and o.name ~= "",
        "Error: can not create a student without lastname.\n")
    assert(o.class and o.class ~= "",
        "Error: can not create a student without lastname.\n")
    s.lastname, s.name, s.class = o.lastname, o.name, o.class
    s.special = o.special or ""
    -- Also make sure the class can access the database (to add classes and
    -- evals to the lists).
    s.tgc = o.parent

    -- Add this class to the database list
    local tgc = s.tgc
    tgc:add_class(s.class)

    -- Creates the evaluations (after some checks)
    s.evaluations = setmetatable({}, eval_mt)
    if o.evaluations and type(o.evaluations) == "table" then
        for n = 1, #o.evaluations do
            if type(o.evaluations[n]) == "table" then
                local already_exists = s:add_eval(o.evaluations[n])
                msg = "Error: %s %s can not have two evals with the same ids.\n"
                assert(not already_exists, msg:format(s.lastname, s.name))
            end
        end
    end

    -- Creates the reports (after some checks)
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

    return s
end

--------------------------------------------------------------------------------
--- Writes the database in a file.
--
-- @param f (file) - file (open for reading)
--------------------------------------------------------------------------------
function Student:save (f)
    local fprintf = function (s, ...) f:write(s:format(...)) end

	fprintf("entry{\n")

    -- Student attributes
    fprintf("\tlastname = \"%s\", name = \"%s\",\n",
        self.lastname or "", self.name or "")
    fprintf("\tclass = \"%s\",\n", self.class or "")
    fprintf("\tspecial = \"%s\",\n", self.special or "")

	-- evaluations
	fprintf("\tevaluations = {\n")
    for _, eval in pairs(self.evaluations) do
        fprintf("\t\t{number = \"%s\", category = \"%s\", ",
            eval.number, eval.category)
        fprintf("quarter = \"%s\", date = \"%s\",\n",
            tostring(eval.quarter), eval.date)
        fprintf("\t\t\ttitle = \"%s\",\n", eval.title)
        fprintf("\t\t\tresult = \"%s\"},\n", tostring(eval.result))
    end
	fprintf("\t},\n")

	-- Moyennes
	fprintf("\treports = {\n")
    for i, report in ipairs(self.reports) do
        fprintf("\t\t{quarter = \"%s\",\n", tostring(i))
        fprintf("\t\t\tresult = \"%s\", score = \"%s\"},\n",
            tostring(report.result), report.score or "")
    end
	fprintf("\t},\n")

	fprintf("}\n")
end

--------------------------------------------------------------------------------
--- Returns the full name of a student.
--
-- @param option (string) - [optional] option to format the name.
-- @return fullname (string)
--------------------------------------------------------------------------------
function Student:fullname (option)
    option = option or "standard"
    local fullname
    local sep = " "

    if option == "reverse" then
        fullname = self.name .. sep .. self.lastname
    else
        fullname = self.lastname .. sep .. self.name
    end

    return fullname
end

--------------------------------------------------------------------------------
--
-- EVALUATIONS
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--- Add an evaluation the student eval list.
--
-- The function returns true if it writes the eval over an existing one.
--
-- @param o (table) - the evaluation attributes.
-- @return (bool)
--------------------------------------------------------------------------------
function Student:add_eval (o)
    local tgc = self.tgc

    -- Possible categories:
    -- wt (written test, default), hw (homework), xp (experiment), att (attitude)
    o.category = o.category or "wt"

    -- Some checks
    assert(o.number and o.number ~= "",
        "Error: an evaluation must have a number.\n")
    assert(o.date and o.date ~= "",
        "Error: an evaluation must be associated with a date.\n")
    assert(o.quarter and o.quarter ~= "",
        "Error: an evaluation must be associated with a quarter.\n")
    local id = tgc._create_eval_id(o.number, self.class) -- TODO get class with a getter
    assert(id,
        "Error: can't create a valid evaluation id.\n")

    local eval = {}
    eval.number = o.number
    eval.category = o.category
    eval.title = o.title
    eval.date = o.date
    eval.quarter = tonumber(o.quarter)
    eval.result = Result.new(o.result, o.mask)

    local already_exists = self:eval_exists(id) and true or false
    self.evaluations[id] = eval

    -- Add this eval to the database list
    tgc:addeval(id, eval)

    return already_exists
end

--------------------------------------------------------------------------------
--- Checks if an evaluation already exists in the student list.
--
-- @param id (string) - the evaluation id.
--------------------------------------------------------------------------------
function Student:eval_exists (id)
    return self.evaluations[id] and true or false
end

--------------------------------------------------------------------------------
--- Search for an eval id in the student list.
--
-- @param number (number) - the eval number
--------------------------------------------------------------------------------
function Student:search_eval_id (number)
    local tgc = self.tgc
    local id = tgc._create_eval_id (number, self.class)

    if self.evaluations[id] then
        return id
    else
        return nil
    end
end

--------------------------------------------------------------------------------
--- Returns the eval attributes.
--
-- @param id (string) - the evaluation id.
-- @return attribute (?)
--------------------------------------------------------------------------------
function Student:get_eval_att (id, attribute)
    if not self.evaluations[id] then return nil end

    local eval = self.evaluations[id]

    attribute = tostring(attribute)
    if attribute == "number" then return eval.number
    elseif attribute == "category" then return eval.category
    elseif attribute == "quarter" then return tonumber(eval.quarter)
    elseif attribute == "date" then return eval.date
    elseif attribute == "title" then return eval.title
    elseif attribute == "result" then return tostring(eval.result)
    else return nil
    end
end

----------------------------------------------------------------------------------
--- Return a result that combines the results of all the corresponding evals.
--
-- @param criteria (table) - a table of criteria to take into account:
--                           quarter = pattern
--                           category = pattern
-- @return result (string)
----------------------------------------------------------------------------------
function Student:combine_evals_result (criteria)
    criteria = criteria or {}
    local quarter = criteria.quarter or nil
    local category = criteria.category or nil

    local result = Result.new()
    for _, eval in pairs(self.evaluations) do -- __pairs should sort this
        if eval.quarter and string.match(eval.quarter, quarter) then
            result = result + eval.result
        end
    end

    result = tostring(result)
    return result ~= "" and result or nil
end


--------------------------------------------------------------------------------
--
-- REPORTS
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--- Add a report the student report list.
--
-- The function returns true if it writes the report over an existing one.
--
-- @param o (table) - the report attributes.
-- @return (bool)
--------------------------------------------------------------------------------
function Student:add_report (o)
    -- Some checks
    assert(o.quarter and o.quarter ~= "",
        "Error: a report must be associated with a quarter.\n")
    if self.reports[tonumber(quarter)] then -- The report already exists.
        local msg = "Error: A student (%s %s) can't have two reports the same quarter.\n"
        error(msg:format(self.lastname, self.name))
    end

    local report = {}
    report.score = tonumber(o.score)
    report.result = Result.new(o.result)
    local quarter = tonumber(o.quarter)

    local already_exists = self:report_exists(quarter) and true or false
    self.reports[quarter] = report

    return already_exists
end

--------------------------------------------------------------------------------
--- Checks if a report already exists in the student list.
--
-- @param quarter (number) - the report quarter.
--------------------------------------------------------------------------------
function Student:report_exists (quarter)
    return self.reports[tonumber(quarter)] and true or false
end

--------------------------------------------------------------------------------
--- Returns the result of the corresponding report.
--
-- @param quarter (number) - the report quarter.
--------------------------------------------------------------------------------
function Student:get_report_result (quarter)
    quarter = tonumber(quarter)
    local result

    if self.reports[quarter] and self.reports[quarter].result then
        result = tostring(self.reports[quarter].result)
    else return nil end

    return result ~= "" and result or nil
end

--------------------------------------------------------------------------------
--- Calculate the result of the corresponding report.
--
-- @param quarter (number) - the report quarter.
--------------------------------------------------------------------------------
function Student:calc_report_result (quarter)
    quarter = tonumber(quarter)

    local eval_results = self:combine_evals_result{quarter = quarter}

    -- Stores the eval results in a Result class to be able to average.
    local result = Result.new(eval_results)
    local calc_result = result:get_mean()

    return calc_result
end

--------------------------------------------------------------------------------
--- Returns the score corresponding to the result of the corresponding report.
--
-- @param quarter (number) - the report quarter.
--------------------------------------------------------------------------------
function Student:get_report_score (quarter)
    quarter = tonumber(quarter)

    if not self.reports[quarter] then return nil
    elseif self.reports[quarter].score then
        return tonumber(self.reports[quarter].score)
    else return nil end
end

--------------------------------------------------------------------------------
--- Calculate the score corresponding to the result of the corresponding report.
--
-- @param quarter (number) - the report quarter.
-- @return score (number)
--------------------------------------------------------------------------------
function Student:calc_report_score (quarter)
    quarter = tonumber(quarter)

    if self.reports[quarter] and self.reports[quarter].result then
        return self.reports[quarter].result:calc_score()
    else return nil end
end

--- DEBUG
-- TODO : à terminer
function Student:print ()
    print("Nom : ", self.lastname, "Prénom : ", self.name)
    print("Classe : ", self.class)
    print("Spécial : ", self.special)
   --  for n = 1, #self.evaluations do
   --      self.evaluations[n]:print()
   --  end
   --  for n = 1, #self.reports do
   --      self.reports[n]:print()
   --  end
end


return setmetatable({new = Student.new}, nil)
