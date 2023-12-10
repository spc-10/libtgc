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
-- Helpers

--------------------------------------------------------------------------------
-- List the scores with a specified format.
-- @param score (table)
-- @format string like in string.format()
-- @sep string to use as separator
-- @return a string with concatenated scores
local function list_scores (score, fmt, sep)
    local fmt = fmt or "%.2f"
    local formated_score = {}
    local sep = sep or ","

    if type(score) == "table" then
        for i = 1, #score do
            formated_score[i] = string.format(fmt, score[i])
        end

        return table.concat(formated_score, sep)
    else
        return string.format(fmt, score)
    end
end

--------------------------------------------------------------------------------
-- Creates a grade or a list of grades.
-- @param val (number or string or table) @see Grade class
-- @param val (table of number or string or table) will be a table of Grades
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
    local a_eid, a_subeid = a:get_eval_ids()
    local b_eid, b_subeid = b:get_eval_ids()

    -- first compare eid
    if a_eid and b_eid and a_eid < b_eid then
        return true
    elseif a_eid and b_eid and a_eid > b_eid then
        return false
    -- then compare subeid
    elseif a_subeid and b_subeid and a_subeid < b_subeid then
        return true
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

    -- There must be a link to the corresponding evaluation
    -- We suppose that the format is correct!
    assert(type(o.eval) == "table",
        "result.eval should be a table containing the evaluation")
    if not o.eval then
        return nil -- TODO error msg
    end
    -- TODO: assert for grades ?

    -- Assign attributes
    r.eval                    = o.eval
    -- Grades can be a single object or a table of grades
    -- TODO: handle errors?
    r.grades                  = create_grades(o.grades, o.eval.competencies)

    -- Subresults (only one depth)
    r.subresults = {}
    if o.subresults and type(o.subresults) == "table" then
        for _, subresult in pairs(o.subresults) do
            --print("DEBUG : adding subresult = ", subresult)
            local eid, subeid = Eval.split_fancy_eval_index(subresult.eval_id)
            subresult.eval = o.eval.subevals[subeid]
            r.subresults[subeid] = Result.new(subresult)
        end
    end

    return r
end

--------------------------------------------------------------------------------
-- Add results to an existing one.
-- TODO To remove difinitively? -> It adds scores and competencies if allowed
-- (`allow_multi_attempts` is true).
-- @param o (table) - same as in new()
-- @return
function Result:add_grades (o)
    o = o or {}
    self.grades = self.grades or {}

    local competencies         = self.eval:get_competencies_infos()
    --local allow_multi_attempts = self.eval:get_multi_infos()

    --if not allow_multi_attempts then
    --    return nil --TODO err msg
    --else
        local new_grades = create_grades(o.grades, competencies)
        for _, g in ipairs(new_grades) do
            table.insert(self.grades, g)
        end
    --end
end

--------------------------------------------------------------------------------
-- Update an existing evaluation result.
-- @param o (table) - table containing the evaluation attributes to modify.
-- See Result.new()
-- @return (bool) true if an update has been done, false otherwise.
-- FIXME: not working.
--function Result:update (o)
--    local update_done = false
--
--    -- Update valid attributes
--    if o.competencies
--        and type(competencies) == "string"
--        and string.match(competencies, "^%s*$") then
--        self.competencies = tostring(o.competencies)
--        update_done = true
--    end
--    if tonumber(o.score) then
--        self.score = tonumber(o.score)
--        update_done = true
--    end
--
--    return update_done
--end

--------------------------------------------------------------------------------
-- Write the evaluation result in a file.
-- @param f (file) - file (open for reading)
function Result:write (f)
    local format = string.format
    local function fwrite (...) f:write(string.format(...)) end

    local eid, subeid = self:get_eval_ids()

    -- Result attributes
    if subeid then
        fwrite("            {eval_id = %q.%q, ", eid, subeid)
    else
        fwrite("        {eval_id = %q,",         eid)
    end

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

    -- Subresults (results for sub evaluations)
    if next(self.subresults) then
        fwrite(" subresults = {\n")
        for _, subresult in ipairs(self.subresults) do
            subresult:write(f)
        end
        fwrite("},\n         ")
    end

    -- Close
    fwrite("},\n")

    f:flush()
end

--------------------------------------------------------------------------------
-- Return a list of the result grades.
function Result:get_grades ()
    if not self.grades and not next(self.grades) then
        return nil
    else
        return self.grades
    end

end

--------------------------------------------------------------------------------
-- Return the last result grades.
function Result:get_grade ()
    if not self.grades and not next(self.grades) then
        return nil
    else
        return self.grades[#self.grades]
    end

end

--------------------------------------------------------------------------------
-- Return the eval quarter.
function Result:get_quarter ()
    return self.eval:get_quarter()
end

--------------------------------------------------------------------------------
-- Return the results grade score and competencies.
-- If the result contains several grades, only return the last one.
-- TODO check if it should return the last grade, the best one or something
-- else?
function Result:get_result (style)
    if not next(self.grades) then
        return nil
    else
        return self.grades[#self.grades]:get_score_and_comp(style)
    end

end

--------------------------------------------------------------------------------
-- Return a table of the results grades (table containing score and
-- competencies).
function Result:get_results (style)
    local grades = {}

    if not next(self.grades) then
        return nil
    else
        for _, grade in ipairs(self.grades) do
            table.insert(grades, {grade:get_score_and_comp(style)})
        end
    end

    return grades
end

--------------------------------------------------------------------------------
-- Return a mean grade with competencies following the evaluation model.
function Result:get_eval_mean_grade ()
    local competencies_sum = ""
    local score_sum = 0
    local score_nval = 0
    local eval_comp_grades_nb = #self.eval.competencies
    local eval_mean_comp_grades = {}


    if not next(self.grades) then
        return nil
    else
        for _, grade in ipairs(self.grades) do
            local score, comp = grade:get_score_and_comp("split")

            if score then
                score_sum = score_sum + score
                score_nval = score_nval + 1
            end
            if comp then
                competencies_sum = competencies_sum .. " " .. comp
            end
        end
    end

    local mean_score = score_nval > 0 and score_sum / score_nval
    local mean_grade = Grade.new(mean_score, competencies_sum)

    return mean_grade:get_score_and_mean_comp()
end

--------------------------------------------------------------------------------
-- Return a mean grade.
function Result:get_mean_grade ()
    local competencies_sum = ""
    local score_sum = 0
    local score_nval = 0

    if not self.grades then
        return nil
    else
        for _, grade in ipairs(self.grades) do
            local score, comp = grade:get_score_and_comp()
            if score then
                score_sum = score_sum + score
                score_nval = score_nval + 1
            end
            if comp then
                competencies_sum = competencies_sum .. " " .. comp
            end
        end
    end

    local mean_score = score_nval > 0 and score_sum / score_nval
    local mean_grade = Grade.new(mean_score, competencies_sum)

    return mean_grade:get_score_and_mean_comp()
end

--------------------------------------------------------------------------------
-- Return the eval result attributes.
function Result:get_eval_ids ()
    return self.eval:get_ids()
end
function Result:get_competencies_infos ()
    return self.eval:get_competencies_infos()
end
-- FIXME doesn't work?
function Result:get_score_infos ()
    local max_score, real_max_score, over_max = self.eval:get_score_infos()
    return self.score, max_score, real_max_score, over_max
end

--------------------------------------------------------------------------------
-- Print a summary of the evaluation result
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
            utils.plog("score: %s",         list_scores(score))
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
