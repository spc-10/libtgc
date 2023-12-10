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
local Result        = require "tgc.result"
local Grade         = require "tgc.grade"
local Comp_list     = require "tgc.comp"
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
    t.comp_lists        = {}

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
    function comp_list_entry (s) self:add_comp_list(s) end

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
    f:write("\n-- Competencies lists\n")
    for _, l in ipairs(self.comp_lists) do
        l:write(f)
    end
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

    -- Have to pass the evaluation and competencies tables to create results
    -- and reports.
    o.evaluations = self.evaluations
    o.comp_list   = self.comp_list

    local s = Student.new(o)
    table.binsert(self.students, s) -- Binary insertion.

    -- FIXME do not add empty "" class eand group
    -- Add class to the database list.
    if not self:class_exists(o.class) then
        table.insert(self.classes, o.class)
    end

    -- Same for groups
    if not self:group_exists(o.group) then
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
-- TODO: nickname doc
-- @param sid the student index
-- @param style[opt] the format style
-- @return name, lastname or nil
function Tgc:get_student_name (sid, style, nickname)
    local s = self.students[sid]
    local style = style or "no"

    if s then return s:get_name(style, nickname)
    else return nil end
end

function Tgc:get_student_fullname (sid, style, nickname)
    local s = self.students[sid]
    local style = style or "no"

    if s then return s:get_fullname(style, nickname)
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
-- @return extra_time, dyslexia, dyscalculia, enlarged_font
function Tgc:get_student_adaptations (sid)
    local s = self.students[sid]

    if s then
        return s:get_adaptations ()
    else
        return nil
    end
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
function Tgc:set_student_nickname (sid, nickname)
    local s = self.students[sid]
    if s then s:update({nickname = nickname}) end
end
function Tgc:set_student_place (sid, place)
    local s = self.students[sid]
    if s then s:update({place = place}) end
end
function Tgc:set_student_adaptations (sid, extra_time, dyslexia, dyscalculia, enlarged_font)
    local s = self.students[sid]
    if s then
        s:update({
            extra_time    = extra_time,
            dyslexia      = dyslexia,
            dyscalculia   = dyscalculia,
            enlarged_font = enlarged_font,
        })
    end
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
function Tgc:add_student_result (sid, eid, o)
    o = o or nil
    local s = self.students[sid]
    local e = self.evaluations[eid]

    -- Check if student exists
    if not s or not e then
        return nil -- TODO error msg
    end

    -- Add date and quarter infos for this class and evaluation.
    local class = s:get_class()
    e:add_result_date(class, o.date)

    -- Eventually, adds the result
    o.eval = e
    return s:add_result(o)
end

--------------------------------------------------------------------------------
-- Get the list of dates of an evaluation for a particular class.
-- @param eid the index of the eval
-- @param class
function Tgc:get_eval_result_dates (eid, class)
    local e = self.evaluations[eid]

    return e and e.dates and e.dates[class]
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
-- Converts the competencies of a student for the base competencies.
-- FIXME A lot of code pasted here
-- TODO
function Tgc:get_student_competencies_base (sid, quarter, comp_list_id)
    local s = self.students[sid]
    local competencies_sum = ""

    -- first get all the competencies grades
    for _, r in pairs(s.results) do
        -- if no quarter specified, get all the results
        if not quarter or r:get_quarter() == tonumber(quarter) then
            local eid = r:get_eval_ids()

            -- FIXME: what to do if the evals have different competencies lists?
            local _, _, eval_comp_list_id = r:get_competencies_infos()
            assert(eval_comp_list_id == comp_list_id)

            local grade = s:get_grade(eid)
            if grade then
                competencies_sum = competencies_sum .. " " .. grade:get_formatted_competencies("split")
                --print("DEBUG comp_list_id = ", comp_list_id)

            end
        end
    end


    if string.match(competencies_sum, "^%s*$") then return nil end

    -- Then, we get the domain index for each competency grade
    -- FIXME: this suppose a score by domain. Maybe one prefer a score by
    -- competency.
    local comp_list = self.comp_lists[comp_list_id]
    local conv_to_base = comp_list:comp_to_base()
    local base_sum, n = string.gsub(competencies_sum, "(%d+)", conv_to_base)

    local g = Grade.new(base_sum)
    g = g:mean_competencies()

    local hack_convert_table = {["1"] = "1.1",
                                ["3"] = "1.3",
                                ["5"] = "2",
                                ["6"] = "3",
                                ["7"] = "4",
                                ["8"] = "5"}

    local tmp = g:get_formatted_competencies()
    local base_grade = string.gsub(tmp, "(%d+)", hack_convert_table)

    return base_grade

end

--------------------------------------------------------------------------------
-- Converts the competencies of a student to a score.
-- TODO
function Tgc:get_student_competencies_score (sid, quarter, comp_list_id)
    local s = self.students[sid]
    local competencies_sum = ""

    -- first get all the competencies grades
    for _, r in pairs(s.results) do
        -- if no quarter specified, get all the results
        if not quarter or r:get_quarter() == tonumber(quarter) then
            local eid = r:get_eval_ids()

            -- FIXME: what to do if the evals have different competencies lists?
            local _, _, eval_comp_list_id = r:get_competencies_infos()
            assert(eval_comp_list_id == comp_list_id)

            local grade = s:get_grade(eid)
            if grade then
                competencies_sum = competencies_sum .. " " .. grade:get_formatted_competencies("split")
                --print("DEBUG comp_list_id = ", comp_list_id)

            end
        end
    end

    if string.match(competencies_sum, "^%s*$") then return nil end

    -- Then, we get the domain index for each competency grade
    -- FIXME: this suppose a score by domain. Maybe one prefer a score by
    -- competency.
    local comp_list = self.comp_lists[comp_list_id]
    local conv_to_domain = comp_list:comp_to_domain()
    local domain_sum, n = string.gsub(competencies_sum, "(%d+)", conv_to_domain)

    -- Now we calculate the score
    -- FIXME this is some code from grade.lua - factorise it!
    local comp_grade_score = {}
    local comp_grade_score_sum = {}
    local comp_grade_nval = {}
    local total_score = 0
    local max_score = 0

    local score = {}
    for id, letter in string.gmatch(domain_sum, "(%d+)([ABCDabcd-])") do
        local score, nval

        local i = tonumber(id)
        comp_grade_score_sum[i] = comp_grade_score_sum[i] or 0
        comp_grade_nval[i]      = comp_grade_nval[i] or 0

        -- TODO get letter_grades score from configuration file
        if letter == "A" then
            score, nval = 1, 1
        elseif letter == "B" then
            score, nval = 0.66, 1
        elseif letter == "C" then
            score, nval = 0.33, 1
        elseif letter == "D" then
            score, nval = 0, 1
        else -- letter == "-"
            score, nval = 0, 0
            --print("DEBUG : score, nval = 0, 0")
        end
        --print("DEBUG : comp_grade_score_sum[i] = ", comp_grade_score_sum[i], i)
        comp_grade_score_sum[i] = comp_grade_score_sum[i] + score
        --print("DEBUG : comp_grade_score_sum[i] + score = ", comp_grade_score_sum[i], i)
        comp_grade_nval[i] = comp_grade_nval[i] + nval
    end

    for id = 1, comp_list:get_domain_nb() do
        local _, _, points = comp_list:get_domain_infos(id)

        local score_sum  = comp_grade_score_sum[id] or 0
        local grade_nval = comp_grade_nval[id] or 0

        -- we only count evaluated domains
        -- FIXME or (id == 7) is a hack to consider this domain as a bonus.
        -- Must be handle correctly in the future!
        if (grade_nval > 0) or (id == 7) then

            if grade_nval == 0 then
                max_score = max_score + points
            else
                comp_grade_score[id] = points * score_sum / grade_nval
                total_score = total_score + comp_grade_score[id]
                max_score   = max_score + points
            end
        end
    end

    -- return the score (20 scaled, 100 scaled and the detail table
    return total_score / max_score * 20, total_score, max_score, comp_grade_score
end

--------------------------------------------------------------------------------
-- Returns the mean results of a student list for a specific evaluation.
-- TODO
function Tgc:get_eval_grade (eid, sids)
    local e = self.evaluations[eid]
    local tmp_eval_grades, eval_grades, mean_grades = {}, {}, {}
    local final_comp_grades = ""
    local score_sum, score_nval, score_mean = 0, 0

    if not e then return nil end
    local eval_comp, eval_comp_nb = e:get_competencies_infos()

    if not sids or not next(sids) then return nil end
    for _, sid in ipairs(sids) do
        local s = self.students[sid]
        local grade = s:get_grade(eid)
        if grade then
            local score, competencies = grade:get_score_and_competencies()

            if score then
                score_sum = score_sum + score
                score_nval = score_nval + 1
            end
            if competencies then
                for i = 1, eval_comp_nb do
                    tmp_eval_grades[i] = tmp_eval_grades[i] or {}
                    table.insert(tmp_eval_grades[i], competencies[i])
                end
            end
        end
    end

    -- Calculate the mean competencies
    for i = 1, eval_comp_nb do
        eval_grades[i] = Grade.new(table.concat(tmp_eval_grades[i] or {}, " ")) -- FIXME crash if not comp
        mean_grades[i] = eval_grades[i]:mean_competencies()
        final_comp_grades = final_comp_grades .. " " .. mean_grades[i]:get_formatted_competencies("compact")
    end

    -- Calculate the mean score
    if score_nval > 0 then
        score_mean = score_sum / score_nval
    else
        score_mean = nil
    end

    return score_mean, Grade.new(nil, final_comp_grades, competencies):get_formatted_competencies("split")
end

--------------------------------------------------------------------------------
-- TODO rename that
-- Returns a list of the student results grades.
function Tgc:get_student_results (sid, eid, style)
    local s = self.students[sid]
    local e = self.evaluations[eid]

    if not s or not e then return nil end

    return s:get_results(eid, nil, style)
end

--------------------------------------------------------------------------------
-- TODO rename that
-- Returns the student results grades.
function Tgc:get_student_result (sid, eid, style)
    local s = self.students[sid]
    local e = self.evaluations[eid]

    if not s or not e then return nil end

    return s:get_result(eid, style)
end

--------------------------------------------------------------------------------
-- Returns a list of the student results infos if multiple attempts are allowed.
function Tgc:get_student_results_success_infos (sid, eid)
    local s = self.students[sid]
    local e = self.evaluations[eid]

    if not s or not e or not e:is_multi_attempts_allowed() then
        return nil
    end

    -- TODO handle groups
    local class = s:get_class()
    local max_attempts = e:get_attempts_nb(class)

    local student_attempts, success, one_shot, perfect, last_fails = 0, 0, 0, 0, 0
    local max_score           = e:get_score_infos()
    local _, success_score_pc = e:get_multi_infos()

    local last_is_success = true
    local r = s:get_results(eid)
    if r then
        for _, grade in ipairs(r) do
            student_attempts = student_attempts + 1
            if grade[1] and (grade[1] >= success_score_pc * max_score / 100) then
                success = success + 1
                if last_is_success then
                    if grade[1] == max_score then
                        perfect = perfect + 1
                    end
                    one_shot = one_shot + 1
                end
                last_is_success = true
                last_fails = 0
            else
                last_is_success = false
                last_fails = last_fails + 1
            end
        end
    end

    return max_attempts, student_attempts, success, one_shot, perfect, last_fails
end

--------------------------------------------------------------------------------
-- Prints the database informations about a student.
function Tgc:plog_student (sid)
    local s = self.students[sid]
    s:plog()
end


--------------------------------------------------------------------------------
-- Competencies list stuff.
-- @section competencies list
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Get a unused id for a new competencies list.
-- @return an unused index
function Tgc:get_unused_comp_list_id ()
    local i = 1
    while true do
        if not self.evaluations[i] then
            return i
        end
        i = i + 1
    end
end

----------------------------------------------------------------------------------
---- Adds a new competencies list to the database.
---- @param o the competencies list attributes (see Comp_list class)
function Tgc:add_comp_list (o)
    local o = o or {}

    -- Make sure the comp_list has an id
    o.id = o.id or self:get_unused_comp_list_id()

    local l = Comp_list.new(o)
    self.comp_lists[l.id] = l

    return l.id
end



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
function Tgc:eval_exists(eid, subeid)
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
-- Gets evaluations title informations.
function Tgc:get_eval_fulltitle (eid, sep)
    local e = self.evaluations[eid]

    if e then return e:get_fulltitle(sep) end
end
function Tgc:get_eval_title (eid)
    local e = self.evaluations[eid]

    if e then return e:get_title(sep) end
end

--------------------------------------------------------------------------------
-- Gets an evaluation's score informations.
function Tgc:get_eval_score_infos (eid)
    local e = self.evaluations[eid]

    if e then return e:get_score_infos() end
end

--------------------------------------------------------------------------------
-- Gets an evaluation's multiple attempts informations.
function Tgc:get_eval_multi_infos (eid)
    local e = self.evaluations[eid]

    if e then return e:get_multi_infos() end
end

--------------------------------------------------------------------------------
-- Gets an evaluation's competency informations.
function Tgc:get_eval_competencies_infos (eid)
    local e = self.evaluations[eid]

    if e then return e:get_competencies_infos() end
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
function Tgc:class_exists(class)
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
function Tgc:group_exists(group)
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
