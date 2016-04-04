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

local Student = require("tgc.student")
local utils = require("tgc.utils")

local warning = utils.warning



--------------------------------------------------------------------------------
--- TGC CLASS
--
-- Contains everything needed to read, write and access the student database.
--------------------------------------------------------------------------------

local Tgc = {}
local Tgc_mt = {__index = Tgc}

--------------------------------------------------------------------------------
--- Iterates over the ordered students (for __pairs metatable).
--------------------------------------------------------------------------------
local function _studentpairs (t)
    local a, b = {}, {}

    -- First we store the student index with associated date-lastname-name in a
    for idx, student in next, t do
        local class = student.class
        local lastname = utils.strip_accents(student.lastname)
        local name = utils.strip_accents(student.name)
        a[class .. lastname .. class] = idx
    end
    -- Next we store the date-lastname-name  in another table to sort them
    for k in next, a do b[#b + 1] = k end
    table.sort(b)

    -- Now we can return an iterator which iterates over the sorted
    -- date-lastname-name and return the corresponding id and the corresponding
    -- student.
    local i = 1
    return function ()
        local k = a[b[i]] -- this is the srudent id (sorted)
        i = i + 1

        return k, t[k]
    end
end

local student_mt = {__pairs = _studentpairs}

--------------------------------------------------------------------------------
--- Initializes a new student database.
--
-- @return o (Tgc)
--------------------------------------------------------------------------------
function Tgc.init (filename)
    local o = setmetatable({}, Tgc_mt)

    o.students = setmetatable({}, student_mt)
    o.classes = {}
    o.evaluations = {}

    -- Loads the students from the database file
    if filename then
        --if utils.file_exists(filename) then
            function entry (s) o:addstudent(s) end
            dofile(filename)
        --else
        --    warning("File %s can't be opened or doesn't exist. No database read.\n", filename)
        --end
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
        for _, student in pairs(self.students) do
            student:save(f)
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
    -- Add a link to the database. addclass(), addeval(), etc need it.
    o.parent = self -- keep a link to the
    local student = Student.new(o)

    table.insert(self.students, student)
end

--------------------------------------------------------------------------------
--- Add a class to the list of all the class in the database.
--
-- @param class (string) - the class name to add
--------------------------------------------------------------------------------
function Tgc:addclass (class)
    for n = 1, #self.classes do
        if not class or class == self.classes[n] then return end
    end
    table.insert(self.classes, class)

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
function Tgc:addeval (id, eval)
    if self.evaluations[id] then return
    else
        self.evaluations[id] = {}
        self.evaluations[id].number = eval.number
        self.evaluations[id].category = eval.category
        self.evaluations[id].title = eval.title
    end
end

return Tgc
