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
  
Student = require("tgc.student")
utils = require("tgc.utils")

local warning = utils.warning

--------------------------------------------------------------------------------
--- Comparison function to use with table.sort().
--
-- It sorts the students by class, then by lastname and finally by name.
-- Accentuated letters are replaced by their non-accentuated equivalent.
--------------------------------------------------------------------------------
local function sort_students_byclassname (a, b)
    local strip = utils.stripaccents
	return strip(a.class) .. strip(a.lastname) .. strip(a.name)
		< strip(b.class) .. strip(b.lastname) .. strip(b.name)
end

--------------------------------------------------------------------------------
--- Comparison function to use with table.sort().
--
-- It sorts the evals by dates.
--------------------------------------------------------------------------------
local function sort_evals_bydate (a, b)
	return a.date < b.date
end

--------------------------------------------------------------------------------
--- Comparison function to use with table.sort().
--
-- It sorts the reports by quarters.
--------------------------------------------------------------------------------
local function sort_reports_byquarter (a, b)
	return a.quarter < b.quarter
end



--------------------------------------------------------------------------------
--- TGC CLASS
--
-- Contains everything needed to read, write and access the student database.
--------------------------------------------------------------------------------

local Tgc = {}
local Tgc_mt = {__index = Tgc}

--------------------------------------------------------------------------------
--- Initializes a new student database.
--
-- @return o (Tgc)
--------------------------------------------------------------------------------
function Tgc.init (filename)
    local o = setmetatable({}, Tgc_mt)

    o.students = {}
    o.classes = {}
    o.evaluations = {}

    -- Loads the students from the database file
    if filename then
        if utils.file_exists(filename) then
            function entry (s) o:addstudent(s) end
            dofile(filename)
        else
            warning("File %s can't be opened or doesn't exist. No database read.\n", filename)
        end
    end

    return o
end

--------------------------------------------------------------------------------
--- Writes the database to the specified file.
--
-- @param filename (string) - the name of the file where one want to save the
--      database.
--------------------------------------------------------------------------------
function Tgc:save (filename)
    f, msg = io.open(filename, "w")

    if f then
        for n = 1, #self.students do
            self.students[n]:save(f)
        end
        f:flush()
    else
        return nil, msg
    end
end

--------------------------------------------------------------------------------
--- DEBUG function: print the database in a human readable way.
-- TODO
--------------------------------------------------------------------------------
function Tgc:print ()
end

--------------------------------------------------------------------------------
--- Add a student to the database.
--
-- @param o (object) - the student attributes (see Student class)
--------------------------------------------------------------------------------
function Tgc:addstudent (o)
    o = o or {}
    -- Add a link to the database. _addclass(), _addeval(), etc need it.
    o.parent = self -- keep a link to the 
    local student = Student.new(o)

    table.insert(self.students, student)
end

--------------------------------------------------------------------------------
--- Add a class to the list of all the class in the database.
--
-- @param class (string) - the class name to add
--------------------------------------------------------------------------------
function Tgc:_addclass (class)
    for n = 1, #self.classes do
        if not class or class == self.classes[n] then return
        else table.insert(self.classes, class) end
    end
end

--------------------------------------------------------------------------------
--- Check if a class is already in the database.
--
-- @param class (string)
-- @return (bool)
--------------------------------------------------------------------------------
function Tgc:classexists (class)
    for n = 1, #self.classes do
        if class == self.classes[n] then return true end
    end
    return false
end

--------------------------------------------------------------------------------
--- Add an evaluation to the list of all the evaluation in the database.
--
-- @param id (string) - the eval id
-- @param eval (Eval) - the eval object
--------------------------------------------------------------------------------
function Tgc:_addeval (id, eval)
    if self.evaluations[id] then return
    else
        self.evaluations[id].number = eval.number
        self.evaluations[id].category = eval.category
        self.evaluations[id].title = eval.title
    end
end

--------------------------------------------------------------------------------
--- Sorts the database by students, then sort the students evals and reports.
--------------------------------------------------------------------------------
function Tgc:sort ()
	table.sort(self.students, sort_students_byclassname)

    for n = 1, #self.students do
        table.sort(self.students[n].evaluations, sort_evals_bydate)
        table.sort(self.students[n].reports, sort_reports_byquarter)
    end
end

return Tgc
