--------------------------------------------------------------------------------
-- ## TgC results module
--
-- @author Romain Diss
-- @copyright 2019
-- @license GNU/GPL (see COPYRIGHT file)
-- @module result

local Eval    = require "tgc.eval"
local Grade   = require "tgc.grade"
local utils   = require "tgc.utils"
local DEBUG   = utils.DEBUG
local is_date_valid, is_quarter_valid = utils.is_date_valid, utils.is_quarter_valid

--------------------------------------------------------------------------------
-- Structure
-- Result = {
--      eval    = Eval,       -- The Eval object corresponding to the result
--      student = Student,    -- The Student object corresponding to the result
--      grades = {Grade1, …}, -- A table of Grade objects
-- }


--------------------------------------------------------------------------------
-- Helpers

--------------------------------------------------------------------------------
-- Creates a grade or a list of grades.
-- @param val (number or string or table) @see Grade class
-- @param eval_comp (table of number or string or table) will be a table of Grades
-- @return Grade or a table of Grades
local function create_grades (val, eval_comp)
    local grades = {}

    if type(val) == "number" or type(val) == "string" then
        table.insert(grades, Grade.new(val, nil, eval_comp))
    elseif type(val) == "table" then
        -- We must check if the table is a grade or a table of grade
        if #val == 1 then -- we only have one grade
            table.insert(grades, Grade.new(val[1], nil, eval_comp))
        elseif #val == 2 and (type(val[1]) == "number" or type(val[2]) == "string") then
            -- again only one grade
            table.insert(grades, Grade.new(val[1], val[2], eval_comp))
        else
            for _, grade in ipairs(val) do
                table.insert(grades, Grade.new(grade, nil, eval_comp))
            end
        end
    else
        return nil
    end
    return grades
end

--------------------------------------------------------------------------------
-- Result class
-- Sets default attributes and metatables.
local Result = {
}

local Result_mt = {
    __index = Result,
}

---------------------------------------------------------------------------------
-- Compare two Results like `comp` in `table.sort`.
-- @return true if a < b considering the numerical order of the eval id and
-- subid.
-- @see also https://stackoverflow.com/questions/37092502/lua-table-sort-claims-invalid-order-function-for-sorting
function Result_mt.__lt (a, b)
    -- name of th id field depend on the result or subresult level.
    -- FIXME: -1 or error?
    local a_eid = a:get_eval_id()
    local b_eid = b:get_eval_id()

    -- first compare eid
    if a_eid and b_eid and a_eid < b_eid then
        return true
    elseif a_eid and b_eid and a_eid > b_eid then
        return false
    else
        return false
    end
end

--------------------------------------------------------------------------------
-- Creates a new evaluation result.
-- @param o (table) - table containing the evaluation result attributes.
--      o.competencies - list of competencies result MUST be adapted to the
--          eval competency_mask (no check here)
--      o.grade (number or string or table of number and string) - see Grade
--          class
-- @return s (Result)
function Result.new (o)
    local o = o or {}
    local r = setmetatable({}, Result_mt)

    -- There must be a link to the corresponding evaluation and student
    -- We suppose that the format is correct!
    assert(type(o.eval) == "table",
        "result.eval should be a table containing the evaluation")
    assert(type(o.student) == "table",
        "result.student should be a table containing the student")
    --if not o.eval then
    --    return nil -- TODO error msg
    --end
    -- TODO: assert for grades ?

    -- Assign attributes
    r.eval                    = o.eval    -- Eval object
    r.student                 = o.student -- Student object
    -- Grades can be a single object or a table of grades
    -- TODO: handle errors?
    r.grades                  = create_grades(o.grades, o.eval.competencies)

    return r
end

--------------------------------------------------------------------------------
-- Add results to an existing one.
-- @param o (table) - same as in new()
-- @return
function Result:add_grade (o)
    o = o or {}
    self.grades = self.grades or {}
    local e = self.eval

    local allow_multi_attempts = e:get_multi_infos()
    local eval_comp            = e:get_competencies_infos()

    if not allow_multi_attempts and next(self.grades) then
        return nil
    else
        local new_grades = create_grades(o.grades, eval_comp)
        for _, g in ipairs(new_grades) do
            table.insert(self.grades, g)
        end
        return new_grades
    end
end

--------------------------------------------------------------------------------
-- Update an existing evaluation result.
-- @param o (table) - table containing the evaluation attributes to modify.
-- See Result.new()
-- @return (bool) true if an update has been done, false otherwise.
function Result:update_grade (o, date)
    local e = self.eval
    local s = self.student

    -- Find the index of the result grades
    local gid = 1 -- default to first result grades
    local allow_multi_attempts = e:get_multi_infos()
    if allow_multi_attempts then
        local class, group = s:get_class()
        gid = e:get_result_id(date, class, group)
        if not gid then
            return nil
        end
    end

    -- Update the result grades
    if self.grades[gid] then
        local eval_comp = e:get_competencies_infos()
        local new_grade = create_grades(o.grades, eval_comp)
        self.grades[gid] = table.unpack(new_grade)
    end
end

--------------------------------------------------------------------------------
-- Remove an existing evaluation result.
-- @param o (table) - table containing the evaluation attributes to modify.
-- See Result.new()
-- @return (bool) true if an update has been done, false otherwise.
function Result:remove_grade (date)
    local e = self.eval
    local s = self.student

    -- Find the index of the result grades
    local gid = 1 -- default to first result grades
    local allow_multi_attempts = e:get_multi_infos()
    if allow_multi_attempts then
        local class, group = s:get_class()
        gid = e:get_result_id(date, class, group)
        if not gid then
            return nil
        end
    end

    -- Remove the result grades
    return table.remove(self.grades, gid)
end

--------------------------------------------------------------------------------
-- Write the evaluation result in a file.
-- @param f (file) - file (open for reading)
function Result:write (f)
    local format = string.format
    local function fwrite (...) f:write(string.format(...)) end

    local eid = self:get_eval_id()

    -- Result attributes
    fwrite("        {eval_id = %q,",         eid)

    if self.grades then
        fwrite(" grades = {")
        local first = true
        for _, grade in ipairs(self.grades) do
            if not first then fwrite(", ") end
            grade:write(f)
            first = false
        end
        fwrite("},")
    end

    -- Close
    fwrite("},\n")

    f:flush()
end

--------------------------------------------------------------------------------
-- Return a list of the result grades.
-- TODO Should only works with multiple attempts evaluations. Add checker?
-- FIXME: loop with Result:get_grade
function Result:get_grade_list ()
    local grade_list = {}
    if not self.grades or not next(self.grades) then
        return nil
    else
        for _, grade in ipairs(self.grades) do
            table.insert(grade_list, {grade:get_score_and_comp()})
        end
        return grade_list
    end
end

--------------------------------------------------------------------------------
-- Return the result grades.
-- If multiple grades, returns the one corresponding to the date or returns
-- the last one if no date.
-- @param date[opt]
function Result:get_grade (date)
    local s, e = self.student, self.eval

    if not self.grades or not next(self.grades) then
        return nil
    end

    if not date then
        local grade = self.grades[1]
        return grade:get_score_and_comp()
    end

    -- Find the index of the result grades
    local gid = 1 -- default to first result grades
    local allow_multi_attempts = e:get_multi_infos()
    if allow_multi_attempts then
        local class, group = s:get_class()
        gid = e:get_result_id(date, class, group)
        if not gid then
            return nil
        end
    end

    -- Return the result grades
    if self.grades[gid] then
        return self.grades[gid]:get_score_and_comp()
    else
        return nil
    end
end

--------------------------------------------------------------------------------
-- Return the result score.
-- If multiple grades, returns the last one.
-- If the grades contains no score, calculate ones from competencies.
function Result:get_score ()
    if not self.grades or not next(self.grades) then
        return nil
    end

    local g = self.grades[#self.grades]

    local score, comp_grades = g:get_score_and_comp()

    if score then
        return score
    else
        return g:calc_mean()
    end
end

--------------------------------------------------------------------------------
-- Return the eval quarter.
-- @return quarter
function Result:get_quarter ()
    return self.eval:get_quarter()
end

--------------------------------------------------------------------------------
-- Return the eval result attributes.
-- @return eid
function Result:get_eval_id ()
    return self.eval:get_id()
end

-- Returns infos about multiple attempts
-- @return allow_multi_attempts, success_score_pc
function Result:get_multi_infos ()
    return self.eval:get_multi_infos()
end

-- @return competencies, nb_competencies, comp_fw_id
function Result:get_competencies_infos ()
    return self.eval:get_competencies_infos()
end

-- Returns the score informations of the result evaluation
-- @return max_score, real_max_score, over_max
function Result:get_eval_score_infos ()
    return self.eval:get_score_infos()
end

-- Returns the coefficient of the result evaluation
-- @return coefficient
function Result:get_eval_coefficient ()
    return self.eval:get_coefficient()
end

--------------------------------------------------------------------------------
-- Print a summary of the evaluation result
-- FIXME rewrite all of this
function Result:plog (prompt_lvl)
    local prompt_lvl = prompt_lvl or 0
    local tab = "  "
    local prompt = string.rep(tab, prompt_lvl)

    local score, max_score, real_max_score, over_max = self:get_score_infos()

    -- Eval infos
    self.eval:plog(prompt_lvl, true)

    -- Result
    if date or quarter then
        utils.plog("%s%s- ",                prompt, tab)
        if self.date then
            utils.plog("%s ",               table.concat(self.date))
        end
        if self.quarter then
            utils.plog("[Q%d] ",            table.concat(self.quarter))
        end
        utils.plog("\n")
    end
    if score or self.competencies then
        utils.plog("%s%s- ",                prompt, tab)
        if score then
            --utils.plog("score: %s",         list_scores(score))
            if maxscore then
                utils.plog("/%d ",          max_score)
            end
            utils.plog(" ")
        end
        if self.competencies then
            utils.plog("competencies: %s ", table.concat(self.competencies))
        end
        utils.plog("\n")
    end

    -- Subresults
    if next(self.subresults) then
        utils.plog("%s%s- subresults:\n",   prompt, tab)
        for _, subresult in pairs(self.subresults) do
            subresult:plog(prompt_lvl + 2, true)
        end
    end
end


return setmetatable({new = Result.new}, nil)
