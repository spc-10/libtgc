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

local Student = require "tgc.student"
local Eval    = require "tgc.eval"
local utils   = require "tgc.utils"


--------------------------------------------------------------------------------
--- TGC CLASS
--
-- Contains everything needed to read, write and access the student database.
--------------------------------------------------------------------------------

local Tgc = {}
local Tgc_mt = {__index = Tgc}

--------------------------------------------------------------------------------
--- Initializes a new student database.
-- @return o (Tgc)
--------------------------------------------------------------------------------
function Tgc.init ()
    local o = setmetatable({}, Tgc_mt)
    o.students, o.classes, o.evaluations = {}, {}, {}
    o.student_nb, o.evaluation_nb = 0, 0
    return o
end

--------------------------------------------------------------------------------
--- Initializes a new student database.
--
-- @param filename (string) - the name of the database to load.
--                            Evaluations must be read first.
--------------------------------------------------------------------------------
function Tgc:load (filename)
    -- Loads the students from the database file
    local f = assert(io.open(filename, "r"))
    f:close()

    -- define constructors to read data
    function student (s) self:add_student(s) end
    function evaluation (s) self:add_eval(s) end
    dofile(filename)
end

--------------------------------------------------------------------------------
--- Writes the database to the specified file.
--
-- @param filename (string) - the database file.
--------------------------------------------------------------------------------
function Tgc:write (filename)
    f, msg = io.open(filename, "w")
    if not f then return nil, msg end

    -- Write evaluations first (needed to load student results)
    for _, eval in pairs(self.evaluations) do
        eval:write(f)
    end
    for student in self:next_student() do
        student:write(f)
    end
    f:flush()
end

--------------------------------------------------------------------------------
--- DEBUG function: print the database informations in a human readable way.
-- TODO
--------------------------------------------------------------------------------
function Tgc:plog ()
    local function plog (s, ...) print(string.format(s, ...)) end
    local prompt = "tgc>"

    plog("%s Number of students : %q.",    prompt, self.student_nb)
    plog("%s Number of evaluations : %q.", prompt, self.evaluation_nb)
end

--------------------------------------------------------------------------------
--- Add a student to the database.
--
-- @param o (object) - the student attributes (see Student class)
--------------------------------------------------------------------------------
function Tgc:add_student (o)
    o = o or {}
    -- Add a link to the database
    o.db = self

    local student = Student.new(o)
    table.insert(self.students, student)
    self.student_nb = self.student_nb + 1

    -- Add class to the database list
    if not self:find_classes(o.class) then
        table.insert(self.classes, o.class)
    end
end

--------------------------------------------------------------------------------
--- Add an evaluation to the list of all the evaluation in the database.
--
-- @param o (object) - the eval attributes (see Eval class)
--------------------------------------------------------------------------------
function Tgc:add_eval (o)
    o = o or {}
    local eval = Eval.new(o)

    table.insert(self.evaluations, eval)
    self.evaluation_nb = self.evaluation_nb + 1
end

--------------------------------------------------------------------------------
--- Iterates over the ordered students.
--
-- If a class pattern is given, the iterator only returns the students
-- belonging to this class.
--
-- @param class (string)
--------------------------------------------------------------------------------
function Tgc:next_student (pattern)
    local a, b = {}, {}
    pattern = tostring(pattern or ".*")

    -- First we store the student index with associated class-lastname-name in a
    for idx, student in next, self.students do
        local class    = student.class
        local lastname = utils.strip_accents(student.lastname)
        local name     = utils.strip_accents(student.name)
        if string.match(class, pattern) then
            a[class .. lastname .. name] = idx
        end
    end
    -- Next we store the date-lastname-name  in another table to sort them
    for k in next, a do
        b[#b + 1] = k
    end
    table.sort(b)

    -- Now we can return an iterator which iterates over the sorted
    -- date-lastname-name and return the corresponding id and the corresponding
    -- student.
    local i = 1
    return function ()
        local k = a[b[i]] -- this is the student id (sorted)
        i = i + 1

        return self.students[k]
    end
end

----------------------------------------------------------------------------------
--- Find the evaluation corresponding to a result.
-- Use the evaluation number and class pattern (from evaluation class) to find it.
--
-- @param number (number) -- evaluation number
-- @param class (string) -- class
-- @return (Eval) [, msg (string)] - Return nil and error message if arg ar not
--                                   valid.
----------------------------------------------------------------------------------
function Tgc:find_eval(number, class)
    local msg = nil

    -- Check if arguments are valid
    if not tonumber(number) or not class then
        msg = "cannot find an evaluation without valid number or class"
        return nil, msg
    end

    for _, eval in pairs(self.evaluations) do
        local pattern = eval:get_class()
        if eval:get_number() == number and string.find(class, pattern) then
            return eval, msg
        end
    end
end


--------------------------------------------------------------------------------
--- Return the list of the classes in the database.
--
-- The list is sorted in reverse alphabetic order.
--
-- @param pattern (string) - [optional] to filter classes. Default ".*"
-- @return classes[] (string) - the sorted table of matching classes (default: all).
--------------------------------------------------------------------------------
function Tgc:find_classes (pattern)
    local tmp, classes = {}, {}
    pattern = tostring(pattern or ".*")

    -- Sort ex
    for _, class in pairs(self.classes) do
        if string.match(class, pattern) then
            tmp[#tmp + 1] = class
        end
    end
    table.sort(tmp, function(a, b) return a < b end)

    for _, class in ipairs(tmp) do
        table.insert(classes, class)
    end

    return classes
end

--------------------------------------------------------------------------------
--- Return the number of students in a class
--
-- @param class (string)
-- @return nb_students (number)
--------------------------------------------------------------------------------
function Tgc:get_student_number (class)
    -- TODO
    local nb_students = 0

    for student in self:next_student(class) do
        nb_students = nb_students + 1
    end

    return nb_students
end

return Tgc
