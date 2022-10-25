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
--local Category_rule = require "tgc.catrule"
local utils         = require "tgc.utils"
local DEBUG         = utils.DEBUG

table.binsert = utils.binsert

--------------------------------------------------------------------------------
-- TgC main class.
-- Set the default attributes and metatable.
local Tgc = {
    -- Version informations.
    _AUTHOR           = "Romain Diss",
    _COPYRIGHT        = "Copyright (c) 2019 Romain Diss",
    _LICENSE          = "GNU/GPL",
    _DESCRIPTION      = "A try to handle evaluation by competency",
    _VERSION          = "TgC 0.3.0",
}

local Tgc_mt = {
    __index           = Tgc,
}

--------------------------------------------------------------------------------
-- Create a Tgc object.
function Tgc.init ()
    local t = setmetatable({}, Tgc_mt)

    -- Database tables.
    t.students          = {}
    t.classes           = {}
    t.groups            = {}
    t.evaluations       = {}

    return t
end

--------------------------------------------------------------------------------
-- Loads the student database from a file.
-- @param filename the name of the database to load
-- @return nothing in case of succes or `nil` and a message if the file cannot
-- be open
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

    -- Processes database file.
    dofile(filename)
    table.sort(self.students)
end

--------------------------------------------------------------------------------
-- Writes the database in a file.
-- @param filename the database filename
function Tgc:write (filename)
    f, msg = io.open(filename, "w")
    if not f then return nil, msg end

    f:write(string.format("-- %s\n", self._VERSION))
    f:write("\n-- Evaluations\n")
    for _, e in ipairs(self.evaluations) do
        e:write(f)
    end
    f:write("\n-- Students\n")
    for _, s in ipairs(self.students) do
        s:write(f)
    end
    f:flush()
end

--------------------------------------------------------------------------------
-- Students stuff.
-- This is an interface to the Student module. The user do not access to the
-- student class. She can only get an acces to the student index.
-- Warning: if one adds or removes a student, the indexes are changed!
-- @section students
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Iterator that traverses students belonging to a class pattern.
-- The pattern is also searched in 'groups'.
-- One can iterates over all students with:
-- `for sid in tgc:next_student() do ... end`
-- @param class_p the class pattern
function Tgc:next_student (class_p)
    local sid = 0
    return function ()
        repeat
            sid = sid + 1
            local s = self.students[sid]
            if not s then return nil end
            local class, group = s.class, s.group
        until s:is_in_class(class_p)
        return sid
    end
end

--------------------------------------------------------------------------------
-- Adds a new student to the database.
-- Uses a binary insertion so the `students` table is always sorted.
-- Also increments the students number and insert the student's class to the
-- database.
-- @param o the student attributes (see Student class)
function Tgc:add_student (o)
    o = o or {}

    -- Have to pass the evaluation table to create results
    o.evaluations = self.evaluations

    local s = Student.new(o)
    table.binsert(self.students, s) -- Binary insertion.

    -- Add class to the database list.
    if not self:is_class_exist(o.class) then
        table.insert(self.classes, o.class)
    end

    -- Same for groups
    if not self:is_group_exist(o.group) then
        table.insert(self.groups, o.group)
    end
end

--------------------------------------------------------------------------------
-- Removes a student from the database.
-- @param sid the index of the student to remove
-- FIXME: doesn't work yet
function Tgc:remove_student (sid)
    if self.students[sid] then
        table.remove(self.students, sid)
    end
end

--------------------------------------------------------------------------------
-- Finds students.
-- One can use "*" as special pattern to match everything (shortcut for ".*").
-- @param name_p[opt=".*"] fullname pattern
-- @param class_p[opt=".*"] class pattern
-- @return the list of indexs of the students
-- @fixme replace string.match by a method in student class
function Tgc:find_students(fullname_p, class_p)
    local sids = {}

    -- Default patterns
    if not fullname_p or fullname_p == "*" then fullname_p = ".*" end
    if not class_p or class_p == "*" then class_p = ".*" end

    for sid, s in ipairs(self.students) do
        if string.match(string.lower(s:get_fullname()), string.lower(fullname_p))
            and s:is_in_class(class_p) then
            table.insert(sids, sid)
        end
    end

    return next(sids) and sids or nil
end

--------------------------------------------------------------------------------
-- Gets the students parameters. XXX DEPRECATED
-- Returns `nil` if the index is not correct.
-- See Student
-- @param sid the student index
-- @return lastname, name, class, extra_time, place
-- FIXME: to remove?
function Tgc:get_student_infos (sid)
    local s = self.students[sid]

    if s then return s.lastname, s.name, s.class, s.extra_time, s.place
    else return nil end
end

--------------------------------------------------------------------------------
-- Gets the students name.
-- @param sid the student index
-- @param style[opt] the format style
-- @return name, lastname or nil
function Tgc:get_student_name (sid, style)
    local s = self.students[sid]
    local style = style or "no"

    if s then return s:get_name(style)
    else return nil end
end

function Tgc:get_student_fullname (sid, style)
    local s = self.students[sid]
    local style = style or "no"

    if s then return s:get_fullname(style)
    else return nil end
end

--------------------------------------------------------------------------------
-- Gets the students gender.
-- @param sid the student index
-- @return gender, or nil
function Tgc:get_student_gender (sid)
    local s = self.students[sid]

    if s then
        return s:get_gender()
    else
        return nil
    end
end

--------------------------------------------------------------------------------
-- Gets the students class.
-- @param sid the student index
-- @return class, or nil
-- @return group
function Tgc:get_student_class (sid)
    local s = self.students[sid]

    if s then return s.class, s.group
    else return nil end
end

--------------------------------------------------------------------------------
-- Gets the students place.
-- @param sid the student index
-- @return place, or nil
function Tgc:get_student_place (sid)
    local s = self.students[sid]

    if s then return s.place
    else return nil end
end

--------------------------------------------------------------------------------
-- Gets the students adjustments.
-- @param sid the student index
-- @return extra_time, or nil
-- FIXME: change to extra_time
function Tgc:get_student_adjustments (sid)
    local s = self.students[sid]

    if s then return s.extra_time
    else return nil end
end

--------------------------------------------------------------------------------
-- Sets the students parameters.
-- @param sid the student index
-- @param * the parameter to set
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
function Tgc:set_student_extra_time (sid, extra_time)
    local s = self.students[sid]
    if s then s:update({extra_time = extra_time}) end
end

--------------------------------------------------------------------------------
-- Returns the number of students.
function Tgc:get_students_number ()
    return #self.students
end


--------------------------------------------------------------------------------
-- Results stuff.
-- @section results
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Iterator that traverses the student's results.
-- One can iterates over all results with:
-- `for number, category in tgc:next_student_result(sid) do ... end`
-- @param sid the student index in database
-- @param q[opt] filter by quarter `q`
-- @return the result's number and category
-- FIXME: quarter doesn't work
function Tgc:next_student_result (sid, q)
    local q = tonumber(q) or nil

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

--------------------------------------------------------------------------------
-- Adds a new student's result.
-- @param sid the student index
-- @param eid the eval index
-- @param[opt=nil] subeid the index of a subevaluation
-- @param o the result's attributes (see Result class)
function Tgc:add_student_result (sid, eid, subeid, o)
    local o = o or nil
    -- If the function only have 3 args (subeid optional)
    if o == nil and (type(subeid) == "table" or subeid == nil) then
        o, subeid = subeid or {}, nil
    end
    local s = self.students[sid]

    -- Check if student exists
    if not s then
        return nil -- TODO error msg
    end

    -- Check if eval exists
    local e
    if self.evaluations[eid] and subeid then
        e = self.evaluations[eid].subevals[subeid] or nil
    else
        e = self.evaluations[eid]
    end

    if not e then
        return nil -- TODO error msg
    end

    -- Add date and quarter infos for this class and evaluation.
    local class = s:get_class()
    e:add_result(class, o.date, o.quarter)

    -- Eventually, adds the result
    o.eval = e
    return s:add_result(o)
end

--------------------------------------------------------------------------------
-- Removes a student result from the database.
-- @param sid the index of the student
-- FIXME: Doesn't work
function Tgc:remove_student_result (sid, ...)
    local s = self.students[sid]
    if s then table.remove(self.students, sid) end
end

-- Returns informations concerning a student's result.
-- FIXME: used?
function Tgc:get_student_result_infos (sid, title_p, category)
    local s = self.students[sid]
    if not s then return nil end

    -- Finds the corresponding evaluation.
    local _, _, class = s:get_infos()
    local eval_idx = self:find_evals(title_p, class, category) -- FIXME: find_evals returns a table
    local title, max_score, over_max = nil, nil, nil

    --TODO: local _, _, quarter, date =
end

--------------------------------------------------------------------------------
-- Prints the database informations about a student.
function Tgc:plog_student (sid)
    local s = self.students[sid]
    s:plog()
end


--------------------------------------------------------------------------------
-- Category rule stuff.
-- @section category
-- FIXME: to remove
--------------------------------------------------------------------------------

----------------------------------------------------------------------------------
---- Adds a new category rule to the database.
---- @param o the category rule attributes (see Category_rule class)
--function Tgc:add_category_rule (o)
--    o = o or {}
--
--    local c = Category_rule.new(o)
--    table.insert(self.categories_rules, c)
--end
--
---- Gets the category rule informations
---- @param catname the name of the category
--function Tgc:get_category_rule_infos (catname)
--    for _, category in ipairs(self.categories_rules) do
--        local name, coefficient, mandatory, category_mean = category:get_infos()
--        if catname == name then
--            return coefficient, mandatory, category_mean
--        end
--    end
--end



--------------------------------------------------------------------------------
-- Evals stuff.
-- @section evals
--------------------------------------------------------------------------------


-- Iterator that traverses evaluations of a class.
-- @param class class
-- @usage for eid in tgc:next_eval() do ... end
function Tgc:next_eval (class)
    local i = 0
    return function ()
        repeat
            i = i + 1
            local e = self.evaluations[i]
            if not e then
                return nil
            end
            local class_p = e:get_class_p()
        until string.match(class, class_p)
        return i
    end
end

--------------------------------------------------------------------------------
-- Checks if an evaluation exists.
-- @param eid the evaluation index
-- @return the evaluation index
function Tgc:is_eval_exist(eid, subeid)
    -- TODO
end

--------------------------------------------------------------------------------
-- Checks if an evaluation have subevals.
-- TODO: handle subsubevals?
-- @param eid the evaluation index
-- @return true or false
function Tgc:has_subevals(eid)
    local e = self.evaluations[eid]
    if e then
        return e:get_last_subeval_index() > 0 and true or false
    else
        return false
    end
end

--------------------------------------------------------------------------------
-- Get a unused id for a new evaluation.
-- @return an unused index
function Tgc:get_unused_eval_id ()
    local i = 1
    while true do
        if not self.evaluations[i] then
            return i
        end
        i = i + 1
    end
end

--------------------------------------------------------------------------------
-- Get the last subeval id
-- @param eid the eval index
-- @return an unused index or nul if the eval has no sub eval
function Tgc:get_last_eval_subid (eid)
    local e = self.evaluations[eid]

    if e then
        return e:get_last_subeval_index()
    else
        return nil
    end
end

--------------------------------------------------------------------------------
-- Adds an evaluation to the list of all the evaluations in the database.
-- The index is the evaluation id (and should be unique).
-- @param o the eval attributes
-- @see Eval
-- FIXME return id or something else?
function Tgc:add_eval (o)
    local o = o or {}

    -- Make sure the eval has an id
    o.id = o.id or self:get_unused_eval_id()

    local e = Eval.new(o)
    self.evaluations[e.id] = e

    return e.id
end

--------------------------------------------------------------------------------
-- Adds a sub part for an evaluation.
-- The index must be the one of an existing evaluation
-- @param eid the parent evaluation id
-- @param o the subeval attributes
-- @see Eval
function Tgc:add_subeval (eid, o)
    local o = o or {}
    local e = self.evaluations[eid]

    if e then
        o.id = e:get_last_subeval_index() + 1
        o.parent = e
        return e:add_subeval(o)
    else
        return nil -- TODO error msg
    end
end

--------------------------------------------------------------------------------
-- Find evaluations.
-- @param title_p a title pattern
-- @param class a class which made the evaluation
-- @param eval_type[opt="parent"] only search in parent, subeval or both evaluations
-- @return a list of indexes of the evaluations.
-- TODO: search in subevals too...
function Tgc:find_evals(title_p, class_p)
    local eids = {}

    -- Default patterns
    if not title_p or title_p == "*" then title_p = ".*" end
    if not class_p or class_p == "*" then class_p = ".*" end

    for eid, e in pairs(self.evaluations) do
        local fulltitle = e:get_fulltitle()
        if string.match(string.lower(fulltitle), string.lower(title_p))
            and string.match(e.class_p, class_p) then
            table.insert(eids, eid)
        end
    end

    return next(eids) and eids or nil
end

--------------------------------------------------------------------------------
-- Gets the list of the evaluation types
-- FIXME deprecated?
function Tgc:get_eval_types_list ()
    return Eval.eval_types
end

--------------------------------------------------------------------------------
-- Gets an evaluation's main informations
function Tgc:get_eval_infos (eid)
    local e = self.evaluations[eid]

    if e then
        return e:get_infos()
    else
        return nil
    end
end

--------------------------------------------------------------------------------
-- Gets an evaluation's full title (title + subtitle)
function Tgc:get_eval_fulltitle (eid, sep)
    local e = self.evaluations[eid]

    if e then
        return e:get_fulltitle(sep)
    else
        return nil
    end
end

--------------------------------------------------------------------------------
-- Gets an evaluation's score informations.
function Tgc:get_eval_score_infos (eid)
    local e = self.evaluations[eid]

    if e then
        return e:get_score_infos()
    else
        return nil
    end
end

--------------------------------------------------------------------------------
-- Gets an evaluation's competency informations.
function Tgc:get_eval_competency_infos (eid)
    local e = self.evaluations[eid]

    if e then return e:get_competency_infos()
    else return nil end
end

--------------------------------------------------------------------------------
-- Sets the evaluation parameters.
-- @param eid the evaluation index
-- @param * the parameter to set
-- FIXME: category is deprecated
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

--------------------------------------------------------------------------------
-- Returns the number of evaluations.
function Tgc:get_evaluations_number ()
    local n = 0
    for _, _ in pairs(self.evaluations) do
        n = n + 1
    end
    return n
end

--------------------------------------------------------------------------------
-- Prints the database informations about an evaluation.
function Tgc:plog_eval (eid)
    local e = self.evaluations[eid]
    e:plog()
end


--------------------------------------------------------------------------------
-- Classes stuff.
-- @section class
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Returns the list of the classes in the database.
-- The list is not sorted.
-- @param[opt=".*"] pattern to filter classes
-- @return a table of the matching classes (default: all) or `nil` if no
-- class is found
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

--------------------------------------------------------------------------------
-- Returns the list of the groups in the database.
-- The list is not sorted.
-- @param[opt=".*"] pattern to filter groups
-- @return a table of the matching groups (default: all) or `nil` if no
-- class is found
function Tgc:get_groups_list (pattern)
    pattern = tostring(pattern or ".*")

    local groups = {}
    for _, group in pairs(self.groups) do
        if string.match(group, pattern) then
            table.binsert(groups, group)
        end
    end

    -- Return nil if no class is found.
    if next(groups) then
        return groups
    else
        return nil
    end
end

--------------------------------------------------------------------------------
-- Returns the list of the  classes groups in the database.
-- The list is not sorted.
-- @param[opt=".*"] pattern to filter classes and groups
-- @return a table of the matching classes and groups (default: all) or `nil`
-- if none is found
function Tgc:get_classes_and_groups_list (pattern)
    pattern = tostring(pattern or ".*")

    local c_and_g = {}
    for _, group in pairs(self.groups) do
        if string.match(group, pattern) then
            table.binsert(c_and_g, group)
        end
    end
    for _, class in pairs(self.classes) do
        if string.match(class, pattern) then
            table.binsert(c_and_g, class)
        end
    end

    -- Return nil if no class is found.
    if next(c_and_g) then
        return c_and_g
    else
        return nil
    end
end

--------------------------------------------------------------------------------
-- Checks if the class exists.
-- @param class
-- @return `true` if the class exists, `false` otherwise
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
-- Checks if the group exists.
-- @param class
-- @return `true` if the group exists, `false` otherwise
function Tgc:is_group_exist(group)
    if type(group) ~= "string" then
        return false
    else
        for _, g in pairs(self.groups) do
            if g == group then return true end
        end
    end

    return false
end

--------------------------------------------------------------------------------
-- Returns the size of a class.
-- @param class class pattern
-- @return the size of the class
function Tgc:get_class_size(class)
    local size = 0

    for sid in self:next_student(class) do
        size = size + 1
    end

    return size
end


--------------------------------------------------------------------------------
-- Report stuff.
-- @section report
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Debug stuff.
-- @section stuff
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Prints the database informations in a human readable way.
function Tgc:plog ()
    local prompt_lvl = prompt_lvl or 0
    local tab = "  "
    local prompt = string.rep(tab, prompt_lvl)

    -- utils.plog("%sCategory rule:\n", prompt)
    -- for _, c in ipairs(self.categories_rules) do
    --     c:plog(prompt_lvl + 1)
    -- end
    utils.plog("%sEvaluations:\n", prompt)
    for _, e in ipairs(self.evaluations) do
        e:plog(prompt_lvl + 1)
    end
    utils.plog("%sStudents:\n", prompt)
    for _, s in ipairs(self.students) do
        s:plog(prompt_lvl + 1)
    end

    utils.plog("%s> Number of students : %q.\n",  prompt, self:get_students_number())
    utils.plog("%s> Number of evaluations : %q.\n", prompt, self:get_evaluations_number())
end

return setmetatable({init = Tgc.init}, nil)
