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
local Eval   = require("tgc.eval")


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
--      o.students (Student[]) - 
--      o.evaluations (Eval[]) - 
--      o.classes (table) - 
--      o.results (Result[]) - 
--      o.reports (Report[]) - 
-- @return s (Student)
----------------------------------------------------------------------------------
function Student.new (o)
    local s = setmetatable({}, Student_mt)

    -- Makes sure the student get a name, a lastname and a class!
    -- TODO assert_*() function to check this
    assert(tostring(o.lastname) and o.lastname ~= "", "cannot create a student without lastname")
    assert(tostring(o.name) and o.name ~= "",         "cannot create a student without lastname")
    assert(tostring(o.class) and o.class ~= "",       "cannot create a student without class")
    assert(type(o.db) == "table",                     "cannot create a student without a valid database link")

    -- Links to the student and evaluations lists in the database
    s.db          = o.db

    -- Main student attributes
    s.lastname    = o.lastname
    s.name        = o.name
    s.class       = o.class
    s.place       = tonumber(o.place)
    --s.special     = tostring(o.special)

    -- Creates the evaluation results
    s.results = {}
    if o.results then
        assert(type(o.results) == "table",        "cannot create student: invalid results")
        for n = 1, #o.results do
            assert(type(o.results[n]) == "table", "cannot create student: invalid result")
            -- TODO: Replace by a add_result() method
            local eval = o.db:find_eval(o.results[n].number, o.class)
            assert(eval,                          "cannot create student: eval not found")
            -- add the eval link to the result
            o.results[n].eval = eval
            -- create the result
            s.results[n] = Result.new(o.results[n])
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
--- Write the database in a file.
--
-- @param f (file) - file (open for reading)
--------------------------------------------------------------------------------
function Student:write (f)
    local format = string.format

    -- Open
	f:write("student{\n\t")

    -- Student attributes
    f:write(format("lastname = %q, ", self.lastname))
    f:write(format("name = %q, ",     self.name))
    f:write(format("class = %q, ",    self.class))
    f:write(format("place = %q, ",    self.place))
    --f:write("\n\t"))
    --f:write(format("special = %q, ",  self.special))
    f:write("\n")

	-- Results
	f:write("\tresults = {\n")
    for _, result in pairs(self:get_results()) do
        result:write(f)
    end
	f:write("\t},\n")

	-- Reports
	f:write("\treports = {\n")
    for i, report in ipairs(self.reports) do
        f:write(format("\t\t{quarter = %q,\n", i))
        f:write(format("\t\t\tresult = %q, ", tostring(report.result)))
        f:write(format("score = %q},\n", report.score or nil))
    end
	f:write("\t},\n")

	f:write("}\n")
    f:flush()
end

--------------------------------------------------------------------------------
--- Return the student attributes
--------------------------------------------------------------------------------
function Student:get_lastname () return self.lastname end
function Student:get_name () return self.name end
function Student:get_class () return self.class end
function Student:get_place () return self.place end
function Student:get_results () return self.results end
function Student:get_reports () return self.reports end

--------------------------------------------------------------------------------
--- Returns the full name of a student.
--
-- @param option (string) - [optional] option to format the name.
-- @return fullname (string)
--------------------------------------------------------------------------------
function Student:fullname (option)
    option = option or "standard"
    local sep = " "

    if option == "reverse" then
        return self.name .. sep .. self.lastname
    else
        return self.lastname .. sep .. self.name
    end

    return fullname
end

--------------------------------------------------------------------------------
--- Update an existing student 
--
-- @param place (number)
--------------------------------------------------------------------------------
function Student:set_place (place)
    self.place = place or nil
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
--------------------------------------------------------------------------------
function Student:add_result (o)
    local class = self:get_class()
    local eval  = self.db:find_eval(o.number, class)

    assert(eval, "cannot add result for inexisting eval")

    -- add the eval link to the result
    o.eval = eval
    -- create the result
    table.insert(self.results, Result.new(o))
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
function Student:get_eval_id (number)
    local tgc = self.tgc
    local id = tgc._create_eval_id (number, self.class)

    if self.evaluations[id] then
        return id
    else
        return nil
    end
end

--------------------------------------------------------------------------------
--- Iterates over the eval ids of the student.
--
-- @param quarter (number) - [optional] the quarter (all if nil)
--------------------------------------------------------------------------------
function Student:next_eval_ids (quarter)
    quarter = quarter and tonumber(quarter) or nil
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

--------------------------------------------------------------------------------
--- Returns the eval attributes.
--
-- @param id (string) - the evaluation id.
-- @return number, category, quarter, date, title, result
--------------------------------------------------------------------------------
function Student:get_eval_info (id)
    if not self:eval_exists(id) then return nil end

    local number   = self.evaluations[id].number
    local category = self.evaluations[id].category
    local quarter  = tonumber(self.evaluations[id].quarter)
    local date     = self.evaluations[id].date
    local title    = self.evaluations[id].title
    local result   = tostring(self.evaluations[id].result)

    return number, category, quarter, date, title, result
end

----------------------------------------------------------------------------------
--- Return a result that sums the results of all the corresponding evals.
--
-- @param quarter (number)
-- @return result (string)
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
    assert(o.quarter and o.quarter ~= "", "Error: a report must be associated with a quarter.\n")

    local already_exists = self:report_exists(quarter)
    local quarter = tonumber(o.quarter)
    local report = {}

    report.score  = tonumber(o.score)
    report.result = Result.new(o.result)

    self.reports[quarter] = report

    return already_exists
end

--------------------------------------------------------------------------------
--- Checks if a report already exists in the student list.
--
-- @param quarter (number) - the report quarter.
--------------------------------------------------------------------------------
function Student:report_exists (quarter)
    quarter = quarter and tonumber(quarter)
    return self.reports[quarter] and true or false
end

--------------------------------------------------------------------------------
--- Returns informations on the report.
--
-- @param quarter (number) - the report quarter.
-- @param comp (number) [optional] - only returns infos concerning the
--      specified competence. If omitted, returns infos for all competences.
-- @return result, score
--------------------------------------------------------------------------------
function Student:get_report_info (quarter, comp)
    quarter = quarter and tonumber(quarter)
    if not self:report_exists(quarter) then return nil end
    local result, score

    if not comp then
        result = tostring(self.reports[quarter].result)
        score  = self.reports[quarter].score
    else
        result = self.reports[quarter].result:get_grades(comp)
        score = nil
    end

    return result, score, 20 -- 20 = max_score
end

--------------------------------------------------------------------------------
--- Calculate the result of the corresponding report.
--
-- @param quarter (number) - the report quarter.
--------------------------------------------------------------------------------
function Student:calc_report_result (quarter, comp)
    quarter = quarter and tonumber(quarter)
    local eval_results = self:sum_eval_results(quarter)

    -- Stores the eval results in a Result class to be able to average.
    local result = Result.new(eval_results)
    local calc_result = result:calc_mean()

    if not comp then
        return tostring(calc_result)
    else
        return calc_result:get_grades(comp) or ""
    end
end

--------------------------------------------------------------------------------
--- Calculate the score corresponding to the result of the corresponding report.
--
-- If the report does not exist, try to calculate a score from the quarter
-- evaluations.
--
-- @param quarter (number) - the report quarter.
-- @return score (number)
--------------------------------------------------------------------------------
function Student:calc_report_score (quarter, comp)
    quarter = quarter and tonumber(quarter)
    local result

    if not self:report_exists(quarter) or not self.reports[quarter].result then
        -- We must calculate the results first/
        result = Result.new(self:calc_report_result(quarter))
    else
        result = self.reports[quarter].result
    end

    if comp then 
        return result:calc_comp_score(comp)
    else
        return result:calc_score()
    end
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
