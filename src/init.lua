--------------------------------------------------------------------------------
-- ## TgC, A try to handle evaluation by competency.
--
-- Use a Lua database to manipulate students, evaluations and competencies… So
-- this can easily be used inside ConTeXt or scripts.
--
-- Documentation uses [LDoc style](https://stevedonovan.github.io/ldoc/manual/doc.md.html).
--
-- @author Romain Diss
-- @copyright 2019
-- @license GNU/GPL
-- @module tgc

-- local database = require "tgc.database"
local student  = require "tgc.student"
local eval     = require "tgc.eval"
local utils    = require "tgc.utils"

--- TgC main class.
-- Set the default attributes and metatable.
local Tgc = {
    -- Version informations.
    _AUTHOR           = "Romain Diss",
    _COPYRIGHT        = "Copyright (c) 2019 Romain Diss",
    _LICENSE          = "GNU/GPL",
    _DESCRIPTION      = "A try to handle evaluation by competency",
    _VERSION          = "TgC 0.0.2",

    -- Database tables.
    students          = {},
    classes           = {},
    evaluations       = {},

    -- Other variables.
    student_nb        = 0,
    classes_nb        = 0,
    evaluation_nb     = 0,
}

local Tgc_mt = {
    __index           = Tgc,
}

--- Create a Tgc object.
-- Used to store the databases and associated methods.
-- @return a Tgc object.
function Tgc.init ()
    return setmetatable({}, Tgc_mt)
end

--- Loads the student database from a file.
-- `evaluations` must be read first, then `students`.
-- @string filename the name of the database to load.
-- @return nothing in case of succes or `nil` and a message if the file cannot
-- be open.
function Tgc:load (filename)
    -- Checks if the file can be open for reading.
    f, msg = io.open(filename, "r")
    if not f then
        return f, msg
    end
    f:close()

    -- Define constructors to read data.
    function entry (s) self:add_student(s) end -- for compatibility
    function student_entry (s) self:add_student(s) end
    function evaluation_entry (s) self:add_eval(s) end

    -- Processes database file.
    dofile(filename)
end

--- Writes the database in a file.
-- @string filename the database file.
function Tgc:write (filename)
    f, msg = io.open(filename, "w")
    if not f then return nil, msg end

    -- Write evaluations first (needed to load student results).
    for _, e in pairs(self.evaluations) do
        e:write(f)
    end
    for s in self:next_student() do
        s:write(f)
    end
    f:flush()
end

--- Add a student to the database.
-- @tab o the student attributes.
-- @see Student
function Tgc:add_student (o)
    o = o or {}
    -- Add a link to the database.
    o.db = self

    local s = student.new(o)
    table.insert(self.students, s)
    self.student_nb = self.student_nb + 1

    -- Add class to the database list.
    if not self:find_classes(o.class) then
        table.insert(self.classes, o.class)
    end
end

--- Add an evaluation to the list of all the evaluation in the database.
-- @tab o the eval attributes.
-- @see Eval
function Tgc:add_eval (o)
    o = o or {}
    local e = eval.new(o)

    table.insert(self.evaluations, e)
    self.evaluation_nb = self.evaluation_nb + 1
end

--- Iterates over the ordered students.
-- If a class pattern is given, the iterator only returns the students
-- of this class.
-- @string pattern a class pattern.
function Tgc:next_student (pattern)
    local a, b = {}, {}
    pattern = tostring(pattern or ".*")

    -- First we store the student index with associated class-lastname-name in a
    for idx, s in next, self.students do
        local class    = s.class
        local lastname = utils.strip_accents(s.lastname)
        local name     = utils.strip_accents(s.name)
        if string.match(class, pattern) then
            a[class .. lastname .. name] = idx
        end
    end
    -- Next we store the date-lastname-name in another table to sort them later.
    for k in next, a do
        b[#b + 1] = k
    end
    table.sort(b)

    -- Now we can return an iterator which iterates over the sorted
    -- date-lastname-name and return the corresponding id and the corresponding
    -- student.
    local i = 1
    return function ()
        local k = a[b[i]] -- this is the student id (sorted).
        i = i + 1

        return self.students[k]
    end
end

--- Find the evaluation corresponding to a result.
-- Use the evaluation number and class pattern (from evaluation class) to find
-- it.
-- @int number evaluation number.
-- @string class
-- @treturn Eval
-- @return an Eval or `nil` and a message error if no Eval found.
function Tgc:find_eval(number, class)
    local msg = nil

    -- Check if arguments are valid
    if not tonumber(number) or not class then
        msg = "cannot find an evaluation without valid number or class"
        return nil, msg
    end

    for _, e in pairs(self.evaluations) do
        local pattern = e:get_class()
        if e:get_number() == number and string.find(class, pattern) then
            return e
        end
    end
end

--- Return the list of the classes in the database.
-- The list is sorted in reverse alphabetic order.
-- @string[opt=".*"] pattern to filter classes.
-- @return a table of the mathing classes (sorted). Default: all.
function Tgc:find_classes (pattern)
    local tmp, classes = {}, {}
    pattern = tostring(pattern or ".*")

    -- Sort ex.
    for _, class in pairs(self.classes) do
        if string.match(class, pattern) then
            tmp[#tmp + 1] = class
        end
    end
    table.sort(tmp, function(a, b) return a < b end)

    for _, class in ipairs(tmp) do
        table.insert(classes, class)
    end

    -- Return nil if no class found.
    if next(classes) then
        return classes
    else
        return nil
    end
end

--- Return the number of students in a class.
-- @string class
-- @return the number of students.
function Tgc:get_student_number (class)
    local nb_students = 0

    for _ in self:next_student(class) do
        nb_students = nb_students + 1
    end

    return nb_students
end

-- DEBUG function: print the database informations in a human readable way.
-- TODO
function Tgc:plog ()
    local function plog (s, ...) print(string.format(s, ...)) end
    local prompt = "tgc>"

    for _, e in pairs(self.evaluations) do
        e:plog()
    end
    for s in self:next_student() do
        s:plog()
    end

    plog("%s Number of students : %q.",    prompt, self.student_nb)
    plog("%s Number of evaluations : %q.", prompt, self.evaluation_nb)
end

return setmetatable({init = Tgc.init}, nil)
