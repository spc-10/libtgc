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
local Comp_fw       = require "tgc.comp"
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
    _DESCRIPTION      = "A try to handle evaluation by competencies",
    _VERSION          = "TgC 0.4.0",
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
    t.comp_fw           = {}
    --t.default_cfwid   = nil

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
    function comp_fw_entry (s) self:add_compfw(s) end

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
    f:write("\n-- Competencies frameworks\n")
    for _, l in ipairs(self.comp_fw) do
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
        until s:is_in_class(class_p) or s:is_in_group(class_p)
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

    -- FIXME do not add empty "" class and group
    -- Add class to the database list.
    if not self:class_exists(o.class) then
        table.insert(self.classes, o.class)
    end

    -- Same for groups
    -- If no group, then consider the class is the group
    if not o.group and o.class then
        if not self:group_exists(o.class) then
            table.insert(self.groups, o.class)
        end
    elseif not self:group_exists(o.group) then
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
    local classes = {}

    -- Checks if class is a pattern (look for magic characters)
    if not class_p or class_p and string.match(class_p, "[%^%$%(%)%%%.%[%]%*%+%-%?]") then
        if class_p == "*" then class_p = ".*" end
        classes = self:get_classes_and_groups_list(class_p)
    else
        table.insert(classes, class_p)
    end
    if not classes then return end

    -- Default name = all
    if not fullname_p or fullname_p == "*" then fullname_p = ".*" end

    for sid, s in ipairs(self.students) do
        if string.match(string.lower(s:get_fullname()), string.lower(fullname_p)) then
            for _, class in ipairs(classes) do
                if s:is_in_class(class) or s:is_in_group(class) then -- No need to check s:is_in_class(class)
                    table.insert(sids, sid)
                    break
                end
            end
        end
    end

    return next(sids) and sids or nil
end

--------------------------------------------------------------------------------
-- Gets the students name.
-- @param sid the student index
-- @param style[opt] (string) the format style
-- @param nickname[opt] (bool) if true, returns the nickname instead of the name
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
-- Returns the length of the longest fullname of a a list of students
function Tgc:get_student_fullname_len (sids, style, nickname)
    local style = style or "no"

    sids = sids or self:find_students()
    if not sids or not next(sids) then return nil end

    local maxlen = 0
    for _, sid in ipairs(sids) do
        local s = self.students[sid]
        if s then
            local fullname = s:get_fullname(style, nickname)
            local len = utf8.len(fullname)
            maxlen = len > maxlen and len or maxlen
        else
            return nil
        end
    end

    return maxlen
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

    if s then return s.class, s.group or s.class
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
    if s then return s:update_name(name) end
end
function Tgc:set_student_lastname (sid, lastname)
    local s = self.students[sid]
    if s then return s:update_lastname(lastname) end
end
function Tgc:set_student_nickname (sid, nickname)
    local s = self.students[sid]
    if s then return s:update_nickname(nickname) end
end
function Tgc:set_student_place (sid, place)
    local s = self.students[sid]
    if s then return s:update_place(place) end
end
function Tgc:set_student_extra_time (sid, extra_time)
    local s = self.students[sid]
    if s then return s:update_extra_time(extra_time) end
end
function Tgc:set_student_dyslexia (sid, dyslexia)
    local s = self.students[sid]
    if s then return s:update_dyslexia(dyslexia) end
end
function Tgc:set_student_dyscalculia (sid, dyscalculia)
    local s = self.students[sid]
    if s then return s:update_dyscalculia(dyscalculia) end
end
function Tgc:set_student_enlarged_font (sid, enlarged_font)
    local s = self.students[sid]
    if s then return s:update_enlarged_font(enlarged_font) end
end

--------------------------------------------------------------------------------
-- Returns the number of students.
function Tgc:get_students_number ()
    return #self.students
end

--------------------------------------------------------------------------------
-- Prints the database informations about a student.
function Tgc:plog_student (sid)
    local s = self.students[sid]
    s:plog()
end



--------------------------------------------------------------------------------
-- Grades stuff.
-- @section grades
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Split a competencies string
function Tgc.comp_split(comp_string, comp_ids_mask)
    return Grade.comp_split(comp_string, comp_ids_mask)
end

-- Merge a competencies string
function Tgc.comp_merge(comp_string)
    return Grade.comp_merge(comp_string)
end

-- Mean a competencies string
function Tgc.comp_mean(comp_string)
    return Grade.comp_mean(comp_string)
end

-- Mean a competencies string list
function Tgc.comp_list_mean(comp_list, comp_ids_mask)
    return Grade.comp_list_mean(comp_list, comp_ids_mask)
end

-- Switch from a competencies framework to another
function Tgc.comp_switch(comp_string, hashtable)
    return Grade.comp_switch(comp_string, hashtable)
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
-- FIXME: DEPRECATED
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
-- Adds a new student's grade.
-- @param sid the student index
-- @param eid the eval index
-- @param o the result's attributes (see Result class)
function Tgc:add_student_eval_grade (sid, eid, o)
    o = o or nil
    local s = self.students[sid]
    local e = self.evaluations[eid]

    -- Check if student exists
    if not s or not e then
        return nil
    end

    -- Add date infos for this class and evaluation.
    local _, group = s:get_class()
    e:add_result_date(group, o.date)

    -- Eventually, adds the result
    o.eval = e
    return s:add_grade(o)
end

--------------------------------------------------------------------------------
-- Update an existing student's grade.
-- @param sid the student index
-- @param eid the eval index
-- @param date the date of the evaluation
-- @param o the result's attributes (see Result class)
-- FIXME Doesn't work yet
function Tgc:update_student_eval_grade (sid, eid, date, o)
    o = o or nil
    local s = self.students[sid]
    local e = self.evaluations[eid]

    -- Check if student exists
    if not s or not e then
        return nil
    end

    -- Eventually, updates the result
    o.eval = e
    return s:update_grade(o, date)
end

--------------------------------------------------------------------------------
-- Removes a student result from the database.
-- @param sid the index of the student
-- FIXME: Doesn't work yet
function Tgc:remove_student_eval_grade (sid, ...)
    local s = self.students[sid]
    if s then table.remove(self.students, sid) end
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
-- Returns a list of the student results grades.
function Tgc:get_student_eval_grade_list (sid, eid)
    local s = self.students[sid]
    local e = self.evaluations[eid]

    if not s or not e then return nil end

    return s:get_grade_list(eid)
end

--------------------------------------------------------------------------------
-- Returns the student results grades.
function Tgc:get_student_eval_grade (sid, eid, date)
    local s = self.students[sid]
    local e = self.evaluations[eid]

    if not s or not e then return nil end

    return s:get_grade(eid, date)
end

--------------------------------------------------------------------------------
-- Returns the student results score.
function Tgc:get_student_eval_score (sid, eid)
    local s = self.students[sid]
    local e = self.evaluations[eid]

    if not s or not e then return nil end

    return s:get_score(eid)
end

--------------------------------------------------------------------------------
-- Returns a list of the student attempts infos if multiple attempts are allowed.
function Tgc:get_student_eval_attempts_infos (sid, eid)
    local s = self.students[sid]
    local e = self.evaluations[eid]

    if not s or not e or not e:is_multi_attempts_allowed() then
        return nil
    end

    local _, group = s:get_class()
    local max_attempts = e:get_attempts_nb(group)

    local student_attempts, success, one_shot, perfect, last_fails = 0, 0, 0, 0, 0
    local max_score           = e:get_score_infos()
    local _, success_score_pc = e:get_multi_infos()

    local last_is_success = true
    local r = s:get_grade_list(eid)
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
-- Returns the mean results of a student list for a specific evaluation.
-- If no list of students is given, all students are selected.
-- TODO : handle multiple attempts?
function Tgc:calc_eval_mean_grade (eid, sids)
    local e = self.evaluations[eid]

    if not e then return nil end
    local eval_comp = e:get_competencies_infos()

    sids = sids or self:find_students()
    if not sids or not next(sids) then return nil end

    -- Calculates the score and comp sum
    local score_sum, score_nval, score_mean = 0, 0, 0
    local comp_list = {}
    for _, sid in ipairs(sids) do
        local s = self.students[sid]
        local score, competencies = s:get_grade(eid)
        if score then
            score_sum = score_sum + score
            score_nval = score_nval + 1
        end
        if competencies then
            table.insert(comp_list, competencies)
        end
    end

    -- Calculates the mean score
    if score_nval > 0 then
        score_mean = score_sum / score_nval
    else
        score_mean = nil
    end

    -- Calculate the mean competencies
    local competencies_mean = self.comp_list_mean(comp_list, eval_comp)

    return score_mean, competencies_mean
end

--------------------------------------------------------------------------------
-- Report stuff.
-- @section report
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Get the competencies grades of a student.
-- @param sid the index of the student
-- @param cfwid the index of the competencies framework
-- @param quarter
-- TODO: Allow calculation from domains *or competencies* scores
-- TODO: switch cfwid, quarter parameters order
function Tgc:calc_student_comp_report (sid, cfwid, quarter)
    local s = self.students[sid]
    if not s then
        return nil
    end

    -- first get all the competencies grades
    local comp_string_all
    for _, r in pairs(s.results) do
        -- if no quarter specified, get all the results
        if not quarter or r:get_quarter() == tonumber(quarter) then
            local eid = r:get_eval_id()

            -- Checks if competencies framework matches
            local _, _, eval_cfwid = r:get_competencies_infos()
            if eval_cfwid == cfwid then
                local _, comp_grade = s:get_grade(eid)
                if comp_grade then
                    comp_string_all = (comp_string_all or "") .. " " .. comp_grade
                end
            end
        end
    end

    if not comp_string_all then return nil end
    --print("DEBUG comp_string_all = ", comp_string_all)

    -- Competencies framework infos
    local comp_fw = self.comp_fw[cfwid]
    local domain_hashtable = comp_fw:get_domain_hashtable()
    local domain_comp_string_all = self.comp_switch(comp_string_all, domain_hashtable)
    --print("DEBUG domain_comp_string_all = ", domain_comp_string_all)

    -- Now we calculate a score for each domain competencies
    -- n = 1 Calculates the mean score without optional grades
    -- n = 2 Calculates the mean score with optional grades > mean w/o opt
    -- n = 3 Calculates the mean score with optional grades > mean w opt
    local total_score, max_score
    local mean_wo_opt, mean_w_opt = {}, {}
    local domain_comp_score       = {}
    local n = 1
    repeat
        local sum, nval = {}, {}
        for comp_id, comp_letter in string.gmatch(domain_comp_string_all, "(%d+)([ABCDabcd-]%**)") do
            local score

            local id = tonumber(comp_id)

            if n == 1 then -- No optional (starred) grades
                if not string.match(comp_letter, "%*") then
                    score = Grade.comp_letter_to_score(comp_letter)
                else
                end
            elseif n == 2 then -- Only optional grades > mean w/o opt
                score = Grade.comp_letter_to_score(comp_letter)
                if string.match(comp_letter, "%*") then
                    if mean_wo_opt[id] and score and score < mean_wo_opt[id] then
                        score = nil -- remove optional score that lower the mean
                    end
                end
            else -- Only optional grades > mean w/ opt
                score = Grade.comp_letter_to_score(comp_letter)
                if string.match(comp_letter, "%*") then
                    if mean_w_opt[id] and score and score < mean_w_opt[id] then
                        score = nil -- remove optional score that lower the mean
                    end
                end
            end

            if score then
                -- TODO better handle options
                local keep_best = comp_fw:get_domain_score_opt(id)
                if keep_best then
                    if score > (sum[id] or 0) then
                        sum[id]  = score
                        nval[id] = 1
                    end
                else
                    sum[id]  = (sum[id]  or 0) + score
                    nval[id] = (nval[id] or 0) + 1
                end
            end

        end

        -- Adapt the score to domains options
        total_score, max_score = 0, 0
        for id = 1, comp_fw:get_domain_nb() do
            local mean_score
            local domain_score = comp_fw:get_domain_score(id)
            local _, mandatory = comp_fw:get_domain_score_opt(id)

            -- Only consider scoring domains
            if domain_score then
                if nval[id] and nval[id] > 0 and sum[id] then
                    mean_score  = sum[id] / nval[id]
                    total_score = total_score  + domain_score * mean_score
                    max_score   = max_score    + domain_score
                -- Only count null score if the domain is mandatory
                elseif mandatory then
                    mean_score = 0
                    max_score = max_score + domain_score
                end

                if mean_score and n == 3 then
                    domain_comp_score[id] = domain_score * mean_score
                end
            end

            if n == 1 then
                mean_wo_opt[id] = mean_score
            elseif n == 2 then
                mean_w_opt[id]  = mean_score
            end
        end
        n = n + 1
    until n > 3

    -- return the score and the detail table
    return total_score, max_score, comp_string_all, domain_comp_score
end

--------------------------------------------------------------------------------
-- Returns the report of all the student grade for a particular quarter (or for
-- all quarter if none is given). If a competencies framework id is given, the
-- corresponding competencies are converted to a score (considering the
-- max_score given or 20 by default) and this score is considered for the
-- report.
-- Warning: return a score included in [0;1]
-- @param sid the index of student
-- @param quarter [opt] the quarter (all quarters if nil)
-- @param cfwid [opt] the index of the competencies framework
-- @param comp_real_max_score [opt]
function Tgc:calc_student_evals_report (sid, quarter, cfwid, comp_real_max_score)
    local comp_real_max_score = comp_real_max_score or 20
    local quarter = tonumber(quarter)

    local s = self.students[sid]
    if not s then return nil end

    local score_sum, max_score_sum
    -- We start with the evaluation with scores
    for _, r in pairs(s.results) do
        -- Only count results for the requested quarter
        local eval_quarter = r:get_quarter()
        if not quarter or eval_quarter and eval_quarter == quarter then
            local eid                          = r:get_eval_id()
            local max_score, real_max_score, _ = r:get_eval_score_infos()
            local coef                         = r:get_eval_coefficient()
            local score, _                     = s:get_grade(eid)

            -- We can add a score to the sum only if we have all the score
            -- informations
            -- $$m = \frac{\sum p_i Y_i \frac{x_i}{X_i}}{\sum p_i Y_i}$$
            -- where
            -- * $m$ is the mean
            -- * $xi$ are the scores
            -- * $X_i$ are the maximal scores
            -- * $Y_i$ are the true maximal score into which the score have to be converted
            -- * $p_i$ are the coefficients
            if score and max_score and real_max_score and coef then
                score_sum     = score_sum or 0
                max_score_sum = max_score_sum or 0
                score_sum     = score_sum + (coef * real_max_score * score / max_score)
                max_score_sum = max_score_sum + (coef * real_max_score)
            end
        end
    end

    -- We now convert competencies to a score and add it to the mean
    if cfwid then
        local comp_coef = self:get_compfw_coefficient(cfwid)
        local comp_score, comp_max_score
            = self:calc_student_comp_report (sid, cfwid, quarter)

        if comp_score and comp_max_score and comp_real_max_score and comp_coef then
            score_sum     = score_sum or 0
            max_score_sum = max_score_sum or 0
            score_sum     = score_sum + (comp_coef * comp_real_max_score * comp_score / comp_max_score)
            max_score_sum = max_score_sum + (comp_coef * comp_real_max_score)
        end
    end

    if not score_sum or not max_score_sum then
        return nil
    else
        return score_sum / max_score_sum
    end
end

--------------------------------------------------------------------------------
-- Returns the ranking of the students.
-- The scope of the ranking is calculated depending on the parameters given:
--  - an evaluation if `eid` is given (don't check if quarter correspond)
--  - competencies if `cfwid` is given
--  - all the evaluations and competencies if `cfwid` and `comp_real_max_score`
--    given (see calc_student_evals_report())
-- @param sids a list of students index
-- @param quarter [opt] the quarter (all quarters if nil)
-- @param eid [opt] the evaluation index
-- @param cfwid [opt] the index of the competencies framework
-- @param comp_real_max_score [opt]
function Tgc:get_students_ranking (sids, quarter, eid, cfwid, comp_real_max_score)
    local quarter = tonumber(quarter)

    -- Nothing to calculate ranking
    if not eid and not cfwid and not comp_real_max_score then return end
    if not sids then return end

    local ranking = {}

    for _, sid in pairs(sids) do
        local score

        -- Evaluation plus competencies case
        if cfwid and comp_real_max_score then
            score = self:calc_student_evals_report(sid, quarter, cfwid, comp_real_max_score)
        -- Competencies case
        elseif cfwid then
            local total_score, max_score = self:calc_student_comp_report(sid, cfwid, quarter)
            if total_score then
                score = total_score / max_score
            end
        -- Evaluation case
        elseif eid then
            score = self:get_student_eval_score(sid, eid)
        end

        if score then
            table.insert(ranking, {sid = sid, score = score})
        end
    end

    -- We now sort the students list by scores
    table.sort(ranking, function(a, b) return a.score > b.score end)

    return ranking
end


--------------------------------------------------------------------------------
-- Competencies framework stuff.
-- @section competencies framework
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Get a unused id for a new competencies framework.
-- @return an unused index
function Tgc:get_unused_compfw_id ()
    local i = 1
    while true do
        if not self.comp_fw[i] then
            return i
        end
        i = i + 1
    end
end

--------------------------------------------------------------------------------
-- Adds a new competencies framework to the database.
-- @param o the competencies framework attributes (see Comp_fw class)
function Tgc:add_compfw (o)
    local o = o or {}

    -- Make sure the comp_fw has an id
    o.id = o.id or self:get_unused_compfw_id()

    -- Check if this is the default comp_fw
    if o.default then
        self.default_cfwid = o.id

        -- Remove the default tag to the other frameworks (there can be only
        -- one).
        for _, f in ipairs(self.comp_fw) do
            f.default = nil
        end
    end

    local f = Comp_fw.new(o)
    self.comp_fw[o.id] = f

    return o.id
end

--------------------------------------------------------------------------------
-- Get the default framework id
-- @return cfwid
function Tgc:get_default_cfwid ()
    return self.default_cfwid
end

--------------------------------------------------------------------------------
-- Get the competencies framework infos
-- @param cfwid the competencies framework index.
-- @return title
function Tgc:get_compfw_infos (cfwid)
    local f = self.comp_fw[cfwid]

    return f and f:get_infos()
end

--------------------------------------------------------------------------------
-- Get the competencies framework Alternate id
-- @param cfwid the competencies framework index.
-- @return altid
function Tgc:get_compfw_altid (cfwid)
    local f = self.comp_fw[cfwid]

    return f and f:get_altid()
end

--------------------------------------------------------------------------------
-- Get the competencies framework ids list
-- @param cfwid the competencies framework index.
-- @return {cfwid_1, cfwid_2, ...}
function Tgc:get_compfw_list ()
    local cfwids = {}
    for cfwid, _ in pairs(self.comp_fw) do
        table.insert(cfwids, cfwid)
    end

    return cfwids
end

--------------------------------------------------------------------------------
-- Get the number of domains in the competencies framework.
-- @param cfwid the competencies framework index.
function Tgc:get_compfw_domain_nb (cfwid)
    local f = self.comp_fw[cfwid]

    return f and f:get_domain_nb()
end

--------------------------------------------------------------------------------
-- Get the list of competencies indexes of a comp domain.
-- @param cfwid the competencies framework index.
function Tgc:get_compfw_domain_comp_list(cfwid, domain)
    local f = self.comp_fw[cfwid]

    return f and f:get_domain_comp_list(domain)
end

--------------------------------------------------------------------------------
-- Get the competencies domain infos.
-- @param cfwid the competencies framework index.
-- @param doamin the domain index.
-- return id, title
function Tgc:get_compfw_domain_infos(cfwid, domain)
    local f = self.comp_fw[cfwid]

    if not f then
        return nil
    else
        return f:get_domain_infos(domain)
    end
end

--------------------------------------------------------------------------------
-- Get the competencies domain score.
-- @param cfwid the competencies framework index.
function Tgc:get_compfw_domain_score(cfwid, domain)
    local f = self.comp_fw[cfwid]

    if not f then
        return nil
    else
        return f:get_domain_score(domain)
    end
end

--------------------------------------------------------------------------------
-- Get the coefficient for the conversion of competencies to a score.
-- @param cfwid the competencies framework index.
-- @return coefficient
function Tgc:get_compfw_coefficient (cfwid)
    local f = self.comp_fw[cfwid]

    return f and f:get_coefficient()
end

--------------------------------------------------------------------------------
-- Get the competencies infos.
-- @param cfwid the competencies framework index.
function Tgc:get_compfw_comp_infos(cfwid, comp)
    local f = self.comp_fw[cfwid]

    if not f then
        return nil
    else
        return f:get_comp_infos(comp)
    end
end

--------------------------------------------------------------------------------
-- Get the domain hashtable
-- @param cfwid the competencies framework index.
function Tgc:get_compfw_domain_hashtable(cfwid)
    local f = self.comp_fw[cfwid]

    if not f then
        return nil
    else
        return f:get_domain_hashtable()
    end
end

--------------------------------------------------------------------------------
-- Get the alternate hashtable
-- @param cfwid the competencies framework index.
function Tgc:get_compfw_alt_hashtable(cfwid)
    local f = self.comp_fw[cfwid]

    if not f then
        return nil
    else
        return f:get_alt_hashtable()
    end
end

--------------------------------------------------------------------------------
-- Get the fancy id hashtable
-- @param cfwid the competencies framework index.
function Tgc:get_compfw_fancy_id_hashtable(cfwid)
    local f = self.comp_fw[cfwid]

    if not f then
        return nil
    else
        return f:get_fancy_id_hashtable()
    end
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
function Tgc:eval_exists(eid)
    -- TODO
end

--------------------------------------------------------------------------------
-- Checks if an evaluation exists.
-- @param eid the evaluation index
-- @return the evaluation index
function Tgc:is_eval_optional(eid)
    local e = self.evaluations[eid]
    if e then
        return e:is_optional()
    else
        return nil
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
-- Find evaluations.
-- @param title_p a title pattern
-- @param class a class which made the evaluation
-- @return a list of indexes of the evaluations.
function Tgc:find_evals(title_p, class_p)
    local eids = {}

    -- Default patterns
    if not title_p or title_p == "*" then title_p = ".*" end
    if not class_p or class_p == "*" then class_p = ".*" end

    for eid, e in pairs(self.evaluations) do
        local fulltitle = e:get_fulltitle()
        if string.match(string.lower(fulltitle), string.lower(title_p)) then
            -- First try the class pattern
            -- FIXME: Should look at the dates first
            if string.match(e.class_p, class_p) then
                table.insert(eids, eid)
            -- Then look at the results dates
            else
                for class, _ in pairs(e.dates) do
                    if class == class_p then
                        table.insert(eids, eid)
                    end
                end
            end
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
-- Gets an evaluation's main informations
function Tgc:get_eval_coefficient (eid)
    local e = self.evaluations[eid]

    if e then
        return e:get_coefficient()
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
-- Gets an evaluation's main informations
function Tgc:get_eval_quarter (eid)
    local e = self.evaluations[eid]

    if e then
        return e:get_quarter()
    else
        return nil
    end
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
-- TODO: factorize the 3 functions below.
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
    end

    for _, c in pairs(self.classes) do
        if c == class then return true end
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
    end

    for _, g in pairs(self.groups) do
        if g == group then return true end
    end

    return false
end

--------------------------------------------------------------------------------
-- Checks if the class or groups exists.
-- @param class
-- @return `true` if the class exists, `false` otherwise
function Tgc:class_or_group_exists(class)
    if type(class) ~= "string" then
        return false
    end

    return self:class_exists(class) or self:group_exists(class)
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
    local sids = self:find_students(".*", class)

    if sids then
        return #sids
    else
        return 0
    end
end


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

--------------------------------------------------------------------------------
-- Utility stuff.
-- @section utility
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Check if a date is valid.
Tgc.is_date_valid = utils.is_date_valid

return setmetatable({init = Tgc.init}, nil)
