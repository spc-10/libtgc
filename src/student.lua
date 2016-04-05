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
]]--

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
    tgc:addclass(s.class)

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
            tostring(report.result), tostring(report.score))
    end
	fprintf("\t},\n")

	fprintf("}\n")
end

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
    local id = Student._create_eval_id(o.category, o.number, self.class) -- TODO get class with a getter
    assert(id,
        "Error: can't create a valid evaluation id.\n")

    local eval = {}
    eval.number = o.number
    eval.category = o.category
    eval.title = o.title
    eval.date = o.date
    eval.quarter = tonumber(o.quarter)
    eval.result = Result.new(o.result)

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

--- Récupère l’évaluation ayant l’identifiant donné
-- @param id (string) - identifiant de l’évaluation a récupérer
-- @return eval (Eval) - l’évaluation trouvée
function Student:geteval (id)
    local eval = nil
    for n = 1, #self.evaluations do
        if self.evaluations[n].id and self.evaluations[n].id == id then
            eval = self.evaluations[n]
        end
    end
    return eval
end

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
    report.score = o.score
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

--- Vérifie si l’élève est dans la classe demandée.
-- @param class
function Student:isinclass (class)
    return self.class == class
end

--- Modifie la note moyenne du trimestre demandé
-- @param quarter (string) - trimestre
-- @param s (string) - a result
function Student:setquarter_mean (quarter, s)
    local report_found = nil
    local result = Result.new(s)
    result = result:getmean() -- la moyenne trimestrielle doit être une moyenne !

    for n = 1, #self.reports do
        if self.reports[n].quarter and self.reports[n].quarter == quarter then
            report_found = true
            self.reports[n].result = result
        end
    end

    -- Le bilan trimestriel n’existe pas encore
    if not report_found then
        self:addreport{quarter = quarter, result = result:tostring()}
    end
end

--- Renvoie toutes les notes du trimestre demandé
-- @param quarter (string) - trimestre
-- @return result (Result)
function Student:getquarter_result (quarter)
    local result = Result.new()
    for k in pairs(self.evaluations) do
        local eval = self.evaluations[k]
        if eval.quarter and eval.quarter == quarter then
            result = result + eval.result
        end
    end

    return result
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

--------------------------------------------------------------------------------
--- Creates an id for an evaluation.
--
-- @param cat (string) - The eval category.
-- @param num (string) - The eval number.
-- @param class (string)
--------------------------------------------------------------------------------
function Student._create_eval_id (cat, num, class)
    if not cat or not num or not class then return nil end

    return tostring(cat) .. tostring(num) .. tostring(class)
end


return setmetatable({new = Student.new}, nil)
