--------------------------------------------------------------------------------
-- ## TgC, A try to handle evaluation by competency.
--
-- Use a Lua database to manipulate students, evaluations and competencies… So
-- this can easily be used inside ConTeXt or scripts.
--
-- @author Romain Diss
-- @copyright 2019
-- @license GNU/GPL (see COPYRIGHT file)
-- @module tgc

local Student       = require "tgc.student"
local Eval          = require "tgc.eval"
local Category_rule = require "tgc.catrule"
local utils         = require "tgc.utils"

table.binsert = utils.binsert

--- TgC main class.
-- Set the default attributes and metatable.
local Tgc = {
    -- Version informations.
    _AUTHOR           = "Romain Diss",
    _COPYRIGHT        = "Copyright (c) 2019 Romain Diss",
    _LICENSE          = "GNU/GPL",
    _DESCRIPTION      = "A try to handle evaluation by competency",
    _VERSION          = "TgC 0.2.0",

    -- Database tables.
    students          = {},
    classes           = {},
    evaluations       = {},
    categories_rules  = {},
}

local Tgc_mt = {
    __index           = Tgc,
}

--- Create a Tgc object.
function Tgc.init ()
    return setmetatable({}, Tgc_mt)
end

--- Loads the student database from a file.
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
    -- function entry (s) self:add_student(s) end -- for compatibility
    function student_entry (s) self:add_student(s) end
    function evaluation_entry (s) self:add_eval(s) end
    function category_rule_entry (s) self:add_category_rule(s) end

    -- Processes database file.
    dofile(filename)
    table.sort(self.students)
end

--- Writes the database in a file.
-- @string filename the database file.
function Tgc:write (filename)
    f, msg = io.open(filename, "w")
    if not f then return nil, msg end

    for _, c in ipairs(self.categories_rules) do
        c:write(f)
    end
    for _, e in ipairs(self.evaluations) do
        e:write(f)
    end
    for _, s in ipairs(self.students) do
        s:write(f)
    end
    f:flush()
end

--------------------------------------------------------------------------------
--- Students stuff.
-- This is an interface to the Student module. The user do not access to the
-- student class. She can only get an acces to the student index.
-- Warning: if one adds or removes a student, the indexes are changed!


--- Iterator that traverses students belonging to a class pattern.
-- One can iterates over all students with:
-- `for sid in tgc:next_student() do ... end`
function Tgc:next_student (class_p)
    class_p = (type(class_p) == "string") and class_p or ".*"

    local sid = 0
    return function ()
        repeat
            sid = sid + 1
            local s = self.students[sid]
            if not s then return nil end
            local _, _, class = s:get_infos()
        until string.match(class, class_p)
        return sid
    end
end

--- Adds a new student to the database.
-- Uses a binary insertion so the `students` table is always sorted.
-- Also increments the students number and insert the student's class to the
-- database.
-- @param o the student attributes (see Student class).
function Tgc:add_student (o)
    o = o or {}

    local s = Student.new(o)
    table.binsert(self.students, s) -- Binary insertion.

    -- Add class to the database list.
    if not self:is_class_exist(o.class) then
        table.binsert(self.classes, o.class)
    end
end

--- Removes a student from the database.
-- @number sid the index of the student to remove.
function Tgc:remove_student (sid)
    if self.students[sid] then
        table.remove(self.students, sid)
    end
end

--- Finds a student.
-- Warning: in case of multiple matchings, the function only returns the first
-- match.
-- One can use "*" as special pattern to match everything (shortcut for ".*").
-- @string lastname_p[opt=".*"] lastname pattern
-- @string name_p[opt=".*"] name pattern
-- @string class_p[opt=".*"] class pattern
-- @return the index of the student.
function Tgc:find_student(lastname_p, name_p, class_p)
    -- Check if arguments are valid
    if not lastname_p and not name_p and not class_p then
        return nil
    end
    -- Default patterns
    if not lastname_p or lastname_p == "*" then lastname_p = ".*" end
    if not name_p or name_p == "*" then name_p = ".*" end
    if not class_p or class_p == "*" then class_p = ".*" end

    for sid, s in ipairs(self.students) do
        local lastname, name, class = s:get_infos()
        if string.match(lastname,lastname_p)
            and string.match(name,name_p)
            and string.match(class,class_p) then
            return sid
        end
    end

    return nil -- not found.
end

--- Gets the students parameters.
-- Returns `nil` if the index is not correct.
-- See Student:get_infos()
-- @number sid the student index.
-- @return lastname, name, class, increased_time, place
function Tgc:get_student_infos (sid)
    local s = self.students[sid]

    if s then return s:get_infos()
    else return nil end
end

--- Sets the students parameters.
-- @number sid the student index.
-- @param the parameter to set.
function Tgc:set_student_name (sid, name)
    local s = self.students[sid]
    if s then s:update({name = name}) end
end
function Tgc:set_student_lastname (sid, lastname)
    local s = self.students[sid]
    if s then s:update({lastname = lastname}) end
end
function Tgc:set_student_place (sid, place)
    local s = self.students[sid]
    if s then s:update({place = place}) end
end
function Tgc:set_student_increased_time (sid, increased_time)
    local s = self.students[sid]
    if s then s:update({increased_time = increased_time}) end
end

--- Returns the number of students.
function Tgc:get_students_number ()
    return #self.students
end


--------------------------------------------------------------------------------
-- Results stuff.

--- Iterator that traverses the student's results.
-- One can iterates over all results with:
-- `for number, category in tgc:next_student_result(sid) do ... end`
-- @number sid the student index in database.
-- @number q[opt] filter by quarter `q`
-- @return the result's number and category.
function Tgc:next_student_result (sid, q)
    q = tonumber(q) or nil

    local s = self.students[sid]
    if not s then return nil end

    local i = 0
    return function ()
        repeat
            i = i + 1
            local r = s.results[i]
            if not r then return nil end
            local _, _, class = s:get_infos()
        until string.match(class, class_p)
        return i
    end
end

--- Adds a new student's result.
-- @param o the result's attributes (see Result class).
function Tgc:add_student_result (sid, o)
    local s = self.students[sid]
    if not s then return nil end

    return s:add_result(o)
end

--- Removes a student result from the database.
-- @number sid the index of the student.
function Tgc:remove_student_result (sid, ...)
    local s = self.students[sid]
    if s then table.remove(self.students, sid) end
end

--- Returns informations concerning a student's result.
function Tgc:get_student_result_infos (sid, number, category)
    local s = self.students[sid]
    if not s then return nil end

    -- Finds the corresponding evaluation.
    local _, _, class = s:get_infos()
    local eval_idx = find_eval(number, class, category)
    local title, max_score, over_max = nil, nil, nil

    --TODO: local _, _, quarter, date = 

end


--------------------------------------------------------------------------------
-- Category rule stuff.

--- Adds a new category rule to the database.
-- @param o the category rule attributes (see Category_rule class).
function Tgc:add_category_rule (o)
    o = o or {}

    local c = Category_rule.new(o)
    table.insert(self.categories_rules, c)
end

--- Gets the category rule informations
-- @string catname the name of the category.
function Tgc:get_category_rule_infos (catname)
    for _, category in ipairs(self.categories_rules) do
        local name, coefficient, mandatory, category_mean = category:get_infos() 
        if catname == name then
            return coefficient, mandatory, category_mean
        end
    end
end



--------------------------------------------------------------------------------
-- Evals stuff.

--- Iterator that traverses evaluations of a class.
-- @string class_p acclass pattern.
-- Usage: `for eid in tgc:next_eval() do ... end`
function Tgc:next_eval (class_p)
    class_p = (type(class_p) == "string") and class_p or ".*"

    local i = 0
    return function ()
        repeat
            i = i + 1
            local e = self.evaluations[i]
            if not e then return nil end
            local _, _, class = e:get_infos()
        until string.match(class, class_p)
        return i
    end
end

--- Adds an evaluation to the list of all the evaluation in the database.
-- Uses a binary insertion so the `evaluations` table is always sorted.
-- @tab o the eval attributes.
-- @see Eval
function Tgc:add_eval (o)
    o = o or {}
    local e = Eval.new(o)

    table.binsert(self.evaluations, e) -- Binary insertion.
end

--- Find an evaluation.
-- @int number
-- @string class
-- @return the index of the evaluation.
function Tgc:find_eval(number, class_p, category)
    -- Check if arguments are valid.
    category = category or Eval.category
    if not tonumber(number) or not class_p then
        return nil
    end

    for eid, e in ipairs(self.evaluations) do
        local nb, cat, class = e:get_infos()
        if nb == number and cat == category and string.match(class, class_p) then
            return eid
        end
    end

    return nil -- not found
end

--- Gets an evaluation's main informations
function Tgc:get_eval_infos (eid)
    local e = self.evaluations[eid]

    if e then return e:get_infos()
    else return nil end
end
--- Gets an evaluation's score informations.
function Tgc:get_eval_score_infos (eid)
    local e = self.evaluations[eid]

    if e then return e:get_score_infos()
    else return nil end
end
--- Gets an evaluation's competency informations.
function Tgc:get_eval_competency_infos (eid)
    local e = self.evaluations[eid]

    if e then return e:get_competency_infos()
    else return nil end
end

--- Sets the evaluation parameters.
-- @number eid the evaluation index.
-- @param the parameter to set.
function Tgc:set_eval_category (eid, category)
    local e = self.evaluations[eid]
    if e then e:update({category = category}) end
end
function Tgc:set_eval_title (eid, title)
    local e = self.evaluations[eid]
    if e then e:update({title = title}) end
end
function Tgc:set_eval_max_score (eid, max_score)
    local e = self.evaluations[eid]
    if e then e:update({max_score = max_score}) end
end
function Tgc:set_eval_over_max (eid, over_max)
    local e = self.evaluations[eid]
    if e then e:update({over_max = over_max}) end
end

--- Returns the number of evaluations.
function Tgc:get_evaluations_number ()
    return #self.evaluations
end

--- Returns the list of the evaluations categories.
-- TODO: Optimize this.
function Tgc:get_eval_categories_list ()
    local categories = {}

    -- Collects all the categories.
    for _, e in pairs(self.evaluations) do
        local _, category = e:get_infos()
        local category_found = false
        -- Checks if the category is already in the list.
        for _, c in pairs(categories) do
            if category == c then
                category_found = true
                break
            end
        end
        if not category_found then
            table.binsert(categories, category)
        end
    end

    return categories
end

--------------------------------------------------------------------------------
-- Classes stuff.

--- Returns the list of the classes in the database.
-- The list is not sorted.
-- @string[opt=".*"] pattern to filter classes.
-- @return a table of the matching classes (default: all) or `nil` if no
-- class is found.
function Tgc:get_classes_list (pattern)
    pattern = tostring(pattern or ".*")

    local classes = {}
    for _, class in pairs(self.classes) do
        if string.match(class, pattern) then
            table.binsert(classes, class)
        end
    end

    -- Return nil if no class is found.
    if next(classes) then
        return classes
    else
        return nil
    end
end

--- Checks if the class exists.
-- @string class
-- @return `true` if the class exists, `false` otherwise.
function Tgc:is_class_exist(class)
    if type(class) ~= "string" then
        return false
    else
        for _, c in pairs(self.classes) do
            if c == class then return true end
        end
    end

    return false
end


--------------------------------------------------------------------------------
-- Report stuff.


--------------------------------------------------------------------------------
-- Debug stuff.

--- Prints the database informations in a human readable way.
function Tgc:plog (prompt)
    local function plog (s, ...) print(string.format(s, ...)) end
    prompt = prompt and prompt .. ".tgc" or "tgc"

    plog("\n%s> Category rule:", prompt)
    for _, c in ipairs(self.categories_rules) do
        c:plog(prompt)
    end
    plog("\n%s> Evaluations:", prompt)
    for _, e in ipairs(self.evaluations) do
        e:plog(prompt)
    end
    plog("\n%s> Students:", prompt)
    for _, s in ipairs(self.students) do
        s:plog(prompt)
    end

    plog("\n%s> Number of students : %q.",  prompt, self:get_students_number())
    plog("%s> Number of evaluations : %q.", prompt, self:get_evaluations_number())
end

return setmetatable({init = Tgc.init}, nil)
