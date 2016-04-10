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

local Student = require("tgc.student")
local utils   = require("tgc.utils")

local warning = utils.warning



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

    o.students, o.classes, o.evaluations = {}, {}, {}

    -- Loads the students from the database file
    if filename then
        --if utils.file_exists(filename) then
            function entry (s) o:add_student(s) end
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
function Tgc:add_student (o)
    o = o or {}
    o.parent = self -- usefull to have an access to the database methods
    local student = Student.new(o)

    table.insert(self.students, student)
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

    -- Make sure the pattern is a string (TODO make some more checks?)
    if type(pattern) ~= "string" then
        pattern = nil
    end 

    -- First we store the student index with associated date-lastname-name in a
    for idx, student in next, self.students do
        local class    = student.class
        local lastname = utils.strip_accents(student.lastname)
        local name     = utils.strip_accents(student.name)
        if not pattern or (pattern and class:match(pattern)) then
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

--------------------------------------------------------------------------------
--- Add a class to the list of all the class in the database.
--
-- @param class (string) - the class name to add
--------------------------------------------------------------------------------
function Tgc:add_class (class)
    for n = 1, #self.classes do
        if not class or class == self.classes[n] then return end
    end
    table.insert(self.classes, class)
end

--------------------------------------------------------------------------------
--- Return the list of the classes in the database.
--
-- The list is sorted in reverse alphabetic order.
--
-- @param pattern (string) - [optional] to filter classes.
-- @return classes (table) - the sorted list of the class strings.
--------------------------------------------------------------------------------
function Tgc:get_class_list (pattern)
    local a, classes = {}, {}

    -- Make sure the pattern is a string (TODO make some more checks?)
    if type(pattern) ~= "string" then pattern = nil end 

    for _, class in pairs(self.classes) do
        if not pattern or (pattern and class:match(pattern)) then
            a[#a + 1] = class
        end
    end
    table.sort(a, function(a, b) return a > b end)

    for _, class in ipairs(a) do
        table.insert(classes, class)
    end

    return classes
end

--------------------------------------------------------------------------------
--- Check if a class is already in the database.
--
-- @param class (string)
-- @return (bool)
--------------------------------------------------------------------------------
function Tgc:classe_exists (class)
    for n = 1, #self.classes do
        if class == self.classes[n] then return true end
    end
    return false
end

--------------------------------------------------------------------------------
--- Creates an id for an evaluation.
--
-- @param num (string) - The eval number.
-- @param class (string)
--------------------------------------------------------------------------------
function Tgc._create_eval_id (num, class)
    if not num or not class then return nil end
    local sep = "-"

    return tostring(num) .. sep .. tostring(class)
end

--------------------------------------------------------------------------------
--- Add an evaluation to the list of all the evaluation in the database.
--
-- TODO: add a class level version of the evaluation.
--
-- @param id (string) - the eval id
-- @param eval (Eval) - the eval object
--------------------------------------------------------------------------------
function Tgc:addeval (id, eval)
    if self.evaluations[id] then
        -- No mask is created when the database is read, so we add it later.
        if eval.mask then
            self.evaluations[id].mask = self.evaluations[id].mask or eval.mask
        end
    else
        self.evaluations[id] = {}
        self.evaluations[id].number   = eval.number
        self.evaluations[id].category = eval.category
        self.evaluations[id].class    = eval.class
        self.evaluations[id].title    = eval.title
        self.evaluations[id].date     = eval.date
        self.evaluations[id].quarter  = eval.quarter
        self.evaluations[id].mask     = eval.mask
    end
end

--------------------------------------------------------------------------------
--- Returns an array of the eval ids.
--
-- @param class (string)
-- @param quarter (number)
-- @return (table) - a list of the eval ids
--------------------------------------------------------------------------------
function Tgc:get_eval_id_list (class, quarter)
    local eval_list = {}

    for id, eval in pairs(self.evaluations) do
        if (not quarter or eval.quarter == quarter)
            and (not class or eval.class == class) then
            table.insert(eval_list, id)
        end
    end
    table.sort(eval_list)

    return eval_list
    
end

--------------------------------------------------------------------------------
--- Checks if an evaluation already exists in the database list.
--
-- @param id (string) - the evaluation id.
--------------------------------------------------------------------------------
function Tgc:eval_exists (id)
    return self.evaluations[id] and true or false
end

--------------------------------------------------------------------------------
--- Gets the id of an eval in the database list.
--
-- If the evaluation doesn't exists, we search for the equivalent evaluation
-- for another class. We supposed the class are of the form
-- "[3456]e[0-9]+(g[0-9])*"
--
-- @param number (number) - the eval number
-- @param class (string)
-- @return id - the eval id
--------------------------------------------------------------------------------
function Tgc:get_eval_id (number, class)
    local id = self._create_eval_id (number, class)

    if self:eval_exists(id) then
        return id
    else
        local class_pattern = class:match("^([0-9]+e)")
        for _, c in pairs(self:get_class_list(class_pattern)) do
            id = self._create_eval_id (number, c)
            if self.evaluations[id] then
                return id
            end
        end
    end
    return nil
end

--------------------------------------------------------------------------------
--- Returns the eval attributes.
--
-- @param id (string) - the evaluation id.
-- @return number, category, quarter, date, title, mask
--------------------------------------------------------------------------------
function Tgc:get_eval_info (id, attribute)
    if not self:eval_exists(id) then return nil end

    local number   = self.evaluations[id].number
    local category = self.evaluations[id].category
    local quarter  = tonumber(self.evaluations[id].quarter)
    local date     = self.evaluations[id].date
    local title    = self.evaluations[id].title
    local mask     = self.evaluations[id].mask

    return number, category, quarter, date, title, mask
end

return Tgc
