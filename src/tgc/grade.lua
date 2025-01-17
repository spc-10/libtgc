--[[This module provides the Grade Class for TGC.

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


--------------------------------------------------------------------------------
-- TODO Naming scheme
-- score: a numeric value (ex: 12.5)
-- comp_grades: a table of comp_grade (ex: {"1A", "3-", "12D*"})
-- comp_grade: a string formed by a comp_id and a comp_letter and optionally a star (ex: "12D*")
-- comp_id: a number (ex: 12)
-- comp_letter: a string. Can be "A", "B", "C", "D" or "-" and can be followed by an optional star "*"
-- comp_string: a concatenated string of comp_grade (ex: "1A 3-BC 12D*CC")
--
-- FIXME Check if the syntax is respected…

--------------------------------------------------------------------------------
-- A grade is a couple of:
-- * a numbered grade (`score`)
-- * a table of competencies grades strings (`comp_grades`). Each competency grade (`comp_grade`) consists of a
--   competency number (`comp_id`) associated to a grade letter (`comp_letter`).
--
-- Competencies letters are:
-- * "A" for 'very good'
-- * "B" for 'good'
-- * "C" for 'not good'
-- * "D" for 'bad'
-- * "-" if not evaluated.
--
-- Exemple: grade = {42, {"1A", "1B", "4C", "12D", "2-"}}
-- with:
-- * score = 42
-- * comp_grades = {"1A", "1B", "4C", "12D", "2-"}
-- * first comp_grade = "1A"
-- * first comp_id = 1
-- * first comp_letter = A
-- …
--
-- The grade can be a single number or a single table of competencies grades.


--------------------------------------------------------------------------------
-- Creates a list of competencies grades.
-- Competencies grades are a list of id and letter couples : for example {"1A", "1C", "3C", "12-"}.
--
--  TODO Doc
-- @param comp (string) - a list of competencies ids and corresponding grades
-- @return comp (table)
--------------------------------------------------------------------------------
local function create_comp_grades (comp_letters, comp_ids_mask)
    local comp_grades = {}

    --print("DEBUG : create_comp_grades()")
    -- split the competencies
    repeat -- split the competencies
        comp_letters, n = string.gsub(comp_letters, "(%d+)([ABCDabcd-]%**)([ABCDabcd-]%**)", "%1%2 %1%3")
    until n == 0
    --print("DEBUG : comp_letters = ", comp_letters)
    --print("DEBUG : comp_ids_mask = ", comp_ids_mask)


    if not comp_letters or string.match(comp_letters, "^%s*$") then
         --print("DEBUG ----------- 0 --------")
        return nil
    -- There are no comp ids at all in both letters and mask.
    elseif not string.match(comp_letters, "%d+") and not comp_ids_mask then
         --print("DEBUG ----------- 1 --------")
        return nil
    -- Comp letters and ids are separated.
    elseif not string.match(comp_letters, "%d+") then
         --print("DEBUG ----------- 2 --------")
        local ids_list, comp_letters_list = {}, {}

        for _, id in ipairs(comp_ids_mask) do
            table.insert(ids_list, id)
        end
        for letter in string.gmatch(comp_letters, "[ABCDabcd-]%**") do
            table.insert(comp_letters_list, letter)
        end

        -- Associate
        for i, id in ipairs(ids_list) do
            -- Check if the comp grade is optional
            local optional = ""
            if string.match(id, "%*") then
                optional = "*"
                id = string.gsub(id, "%**", "")
            end

            if comp_letters_list[i] then
                -- Check if the comp grade is optional
                if string.match(comp_letters_list[i], "%*") then
                    optional = "*"
                    comp_letters_list[i] = string.gsub(comp_letters_list[i], "%**", "")
                end

                table.insert(comp_grades, id .. string.upper(comp_letters_list[i]) .. optional)
            else
                table.insert(comp_grades, id .. "-" .. optional)
            end
        end
    -- Comp letters are already associated with ids and no ids model given.
    elseif string.match(comp_letters, "%d+") and not comp_ids_mask then
        -- print("DEBUG ----------- 3 --------")
        for id, letters in string.gmatch(comp_letters, "(%d+)([ABCDabcd%*-]+)") do
            for letter in string.gmatch(letters, "[ABCDabcd-]%**") do
                local l = string.gsub(letter, "%*%**", "*")
                table.insert(comp_grades, id .. l:upper())
            end
        end
    -- Comp letters are already associated with ids and ids model given.
    -- We must check the correspondance.
    elseif string.match(comp_letters, "%d+") and comp_ids_mask then
        -- print("DEBUG ----------- 4 --------")
        local ids_list = {}
        local i = 1

        for _, id in ipairs(comp_ids_mask) do
            local optional = ""
            if string.match(id, "%*") then
                optional = "*"
                id = string.gsub(id, "%**", "")
            end

             --print("DEBUG : id = ", id)
            local letter = string.match(comp_letters, "%D*" ..id .. "([ABCDabcd-]%**)")
             --print("DEBUG : letter = ", letter)
            if letter then
                if string.match(letter, "%*") then
                    optional = "*"
                    letter = string.gsub(letter, "%**", "")
                end

                table.insert(comp_grades, id .. letter:upper() .. optional)
                -- Remove matching comp
                comp_letters = string.gsub(comp_letters, "%s*" .. id .. "[ABCDabcd-]%**%s*", " ", 1)
            else
                table.insert(comp_grades, id .. "-" .. optional)
            end
             --print("DEBUG : comp_letters = ", comp_letters)
        end
    else
        return nil
    end

    return comp_grades
end

--------------------------------------------------------------------------------
--- THE GRADE CLASS
--
-- TODO
--------------------------------------------------------------------------------
local Grade = {}
local Grade_mt = {
    __index = Grade,
    }

--------------------------------------------------------------------------------
-- Creates new Grade (see top of this file).
--
-- The grade contains two parts :
--  + an numbered grade (ex: 12.4)
--  + a list of competencies number with the corresponding letter grade (ex:
--  "1A 2B 3C").
--
-- A grade can contain the numbered part alone, the competencies part alone or
-- it can be a table containing both.
--
-- If the list of competencies only contains the grades (ex: A BC D DA…), it
-- can be combined with the associated competencies ids from the evaluation
-- information given in third parameters (this parameters is then a list of
-- corresponding competencies ids [1 2 2 3 4 4] in the same order).
--
-- @param grade1 or grade2 (number) - a numbered grade.
-- @param grade1 or grade2 (string) - a list of competencies with corresponding
-- @param grade1 (table) - a table with both grade1 and grade2
-- @param eval_comp - a list of competencies ids corresponding to the competencies grade.
-- @return g (Grade)
--------------------------------------------------------------------------------
function Grade.new (grade1, grade2, comp_ids_mask)
    local g = setmetatable({}, Grade_mt)

    --print("DEBUG: Grade.new()")
    --print("DEBUG: grade1 = ", grade1)
    --print("DEBUG: grade2 = ", grade2)
    --print("DEBUG: comp_ids_mask = ", comp_ids_mask)
    if type(grade1) == "number" then
        g.score           = grade1
        if type(grade2) == "string" then
            g.comp_grades = create_comp_grades(grade2, comp_ids_mask)
        end
    elseif type(grade1) == "string" then
        --print("DEBUG: type(grade1) == \"string\"")
        if type(grade2) == "number" then
            --print("DEBUG: type(grade2) == \"number\"")
            g.score       = grade2
            g.comp_grades = create_comp_grades(grade1, comp_ids_mask)
        elseif type(grade2) == "table" then
            --print("DEBUG: type(grade2) == \"table\"")
            -- grade2 should be comp_ids_mask
            g.comp_grades = create_comp_grades(grade1, grade2)
        else
            g.comp_grades = create_comp_grades(grade1, comp_ids_mask)
        end
    elseif not grade1 then
        --print("DEBUG: not grade1")
        if type(grade2) == "number" then
            --print("DEBUG: type(grade2) == \"number\"")
            g.score       = grade2
        elseif type(grade2) == "string" then
            --print("DEBUG: type(grade2) == \"string\"")
            g.comp_grades = create_comp_grades(grade2, comp_ids_mask)
        end
    elseif type (grade1) == "table" then
        --print("DEBUG: type(grade1) == \"table\"")
        -- grade2 should be comp_ids_mask
        return Grade.new(grade1[1], grade1[2], grade2)
    else
        return nil --, error msg
    end

    return g
end

--------------------------------------------------------------------------------
--- Get the score and competencies parts of a grade.
function Grade:get_score_and_comp ()
    local comp_grades

    if self.comp_grades and next(self.comp_grades) then
        comp_grades = table.concat(self.comp_grades, " ")
    end

    return self.score, comp_grades
end

--------------------------------------------------------------------------------
--- Get the competencies as a split string.
-- Ex: "1A 1B 2C 2D 4B"
function Grade:get_split_competencies ()
    return table.concat(self.comp_grades, " ")
end

--------------------------------------------------------------------------------
--- Get the competencies as a merged string.
-- Ex: "1AB 2CD 4B"
function Grade:get_merged_competencies ()
    local tmp_comp_grades = {}

    for _, comp_grade in ipairs(self.comp_grades) do
        id, letter = string.match(comp_grade, "(%d+)([ABCD-]%**)")
        i = tonumber(id)
        if not tmp_comp_grades[i] then
            tmp_comp_grades[i] = letter
        else
            tmp_comp_grades[i] = tmp_comp_grades[i] .. letter
        end
    end

    -- We then sort the index
    local sorted_comp_ids = {}
    for id, _ in pairs(tmp_comp_grades) do
        table.insert(sorted_comp_ids, id)
    end
    table.sort(sorted_comp_ids)

    local merged_comp_grades = {}
    for _, id in ipairs(sorted_comp_ids) do
        table.insert(merged_comp_grades, id .. tmp_comp_grades[id])
    end
    return table.concat(merged_comp_grades, " ")
end

--------------------------------------------------------------------------------
-- Convert a comp letter to the corresponding score.
--
-- @param letter (string)
-- @return score (number)
--------------------------------------------------------------------------------
local function comp_letter_to_score (letter)
    -- remove optional stars
    letter = string.gsub(letter, "%**", "")

    if letter == "A" then
        return 1
    elseif letter == "B" then
        return 0.66
    elseif letter == "C" then
        return 0.33
    elseif letter == "D" then
        return 0
    else -- letter == "-"
        return nil
    end
end

--------------------------------------------------------------------------------
--- Get the mean score and competencies parts of a grade.
function Grade:calc_mean ()
    if not self.comp_grades then
        return nil
    end

    -- Calculates competencies scores
    local mean_wo_opt, mean_w_opt = {}, {}
    local unsorted_mean_comp_grades = {}
    local n = 1
    repeat
        local sum, nval = {}, {}
        for _, comp_grade in pairs(self.comp_grades) do
            --print("DEBUG : letter_grades = ", comp_grade)
            local score

            local comp_id, comp_letter = string.match(comp_grade, "(%d+)([ABCD-]%**)")
            local id = tonumber(comp_id)

            if n == 1 then -- No optional (starred) grades
                if not string.match(comp_letter, "%*") then
                    score = comp_letter_to_score(comp_letter)
                else
                end
            elseif n == 2 then -- Only optional grades > mean w/o opt
                score = comp_letter_to_score(comp_letter)
                if string.match(comp_letter, "%*") then
                    if mean_wo_opt[id] and score and score < mean_wo_opt[id] then
                        score = nil -- remove optional score that lower the mean
                    end
                end
            else -- Only optional grades > mean w/ opt
                score = comp_letter_to_score(comp_letter)
                if string.match(comp_letter, "%*") then
                    if mean_w_opt[id] and score and score < mean_w_opt[id] then
                        score = nil -- remove optional score that lower the mean
                    end
                end
            end

            if score then
                sum[id]  = (sum[id]  or 0) + score
                nval[id] = (nval[id] or 0) + 1
            else
                sum[id]  = sum[id]  or 0
                nval[id] = nval[id] or 0
            end
        end

        -- Adapt the score to domains options
        total_score = 0
        for id, sum in pairs(sum) do
            local mean_score
            if nval[id] and nval[id] ~= 0 then
                mean_score = sum / nval[id]
            end

            if n == 3 then
                if nval[id] == 0 or not mean_score then
                    unsorted_mean_comp_grades[id] = "-"
                elseif mean_score > 0.85 then
                    unsorted_mean_comp_grades[id] = "A"
                elseif mean_score > 0.6 then
                    unsorted_mean_comp_grades[id] = "B"
                elseif mean_score > 0.3 then
                    unsorted_mean_comp_grades[id] = "C"
                else
                    unsorted_mean_comp_grades[id] = "D"
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

    -- We then sort the index
    local sorted_comp_ids = {}
    for id, _ in pairs(unsorted_mean_comp_grades) do
        table.insert(sorted_comp_ids, id)
    end
    table.sort(sorted_comp_ids)

    local mean_comp_grades = {}
    for _, id in ipairs(sorted_comp_ids) do
        table.insert(mean_comp_grades, id .. unsorted_mean_comp_grades[id])
    end

    return self.score, table.concat(mean_comp_grades, " ")
end

--------------------------------------------------------------------------------
-- Split a competencies string
-- Exemple : "1AB 7CD 4B" become "1A 1B 7C 7D 4B"
--
-- @param comp_string (string)
-- @return (string)
--------------------------------------------------------------------------------
local function comp_split (comp_string, comp_ids_mask)
    if not comp_string or string.match(comp_string, "^%s*$") then
        return nil
    end

    local g = Grade.new(comp_string, comp_ids_mask)

    return g:get_split_competencies()
end

--------------------------------------------------------------------------------
-- Merge a competencies string
-- Exemple : "1A 1B 7C 7D 4B" becomes "1AB 7CD 4B"
--
-- @param comp_string (string)
-- @return (string)
--------------------------------------------------------------------------------
local function comp_merge (comp_string)
    if not comp_string or string.match(comp_string, "^%s*$") then
        return nil
    end

    local g = Grade.new(comp_string)

    return g:get_merged_competencies()
end

--------------------------------------------------------------------------------
-- Mean a competencies string
-- Exemple : "1A 1B 7C 7D 4B" becomes "1B 7C 4B"
--
-- @param comp_string (string)
-- @return (string)
--------------------------------------------------------------------------------
local function comp_mean (comp_string)
    if not comp_string or string.match(comp_string, "^%s*$") then
        return nil
    end

    local g = Grade.new(comp_string)
    local _, mean_comp_grades = g:calc_mean()

    return mean_comp_grades
end

--------------------------------------------------------------------------------
-- Mean a competencies string list according to a mask
-- Exemple : TODO
--
-- @param comp_list (table)
-- @param comp_ids_mask (table)
-- @return (string)
--------------------------------------------------------------------------------
local function comp_list_mean (comp_list, comp_ids_mask)
    if not comp_list then
        return nil
    end

    -- if no mask, return the all mean
    if not comp_ids_mask then
        return comp_mean(table.concat(comp_list, " "))
    end

    local tmp_comp_sums = {}
    for _, comp_letters in ipairs(comp_list) do
        for i, id in ipairs(comp_ids_mask) do
            tmp_comp_sums[i] = tmp_comp_sums[i] or ""

            -- Check if grade is optional
            local optional = ""
            if string.match(id, "%*") then
                optional = "*"
                id = string.gsub(id, "%**", "")
            end

            local letter = string.match(comp_letters, "%D*" ..id .. "([ABCDabcd-]%**)")
            if letter then
                if string.match(letter, "%*") then
                    optional = "*"
                    letter = string.gsub(letter, "%**", "")
                end

                tmp_comp_sums[i] = tmp_comp_sums[i] .. letter:upper() .. optional
                -- Remove matching comp
                comp_letters = string.gsub(comp_letters, "%s*" .. id .. "[ABCDabcd-]%**%s*", " ", 1)
            else
                tmp_comp_sums[i] = tmp_comp_sums[i] .. "-" .. optional
            end
        end
    end

    local comp_sums = {}
    local comp_list_mean = ""
    for i, id in ipairs(comp_ids_mask) do
        if tmp_comp_sums[i] then
            comp_sums[i] = comp_mean(id .. tmp_comp_sums[i])
        else
            comp_sums[i] = id .. "-"
        end

        comp_list_mean = comp_list_mean .. comp_sums[i]
    end

    return comp_list_mean
end

--------------------------------------------------------------------------------
-- Switch from a competencies framework to another
-- Exemple : "1A 1B 7C 7D 4B" becomes "42A 42B 67C 67D 42B"
--
-- @param comp_string (string)
-- @param hashtable is table with the competencies association
-- @return (string)
--------------------------------------------------------------------------------
-- TODO
local function comp_switch (comp_string, hashtable)
    if not comp_string or string.match(comp_string, "^%s*$") then
        return nil
    end

    if not hashtable or not type(hashtable) == "table" or not next(hashtable) then
        return nil
    end

    return string.gsub(comp_string, "(%d+)", hashtable)
end

--------------------------------------------------------------------------------
-- Write the evaluation in a file.
-- @param f (file) - file (open for writing)
function Grade:write (f)
    local function fwrite (...) f:write(string.format(...)) end

    -- TODO Format %.2f ??
    if self.score and not self.comp_grades then
        fwrite("%.2f",     self.score)
    elseif self.comp_grades and not self.score then
        fwrite("%q",       comp_merge(table.concat(self.comp_grades)))
    elseif self.score and self.comp_grades then
        fwrite("{%.2f, %q}", self.score, comp_merge(table.concat(self.comp_grades)))
    end
end


--------------------------------------------------------------------------------

return setmetatable({new = Grade.new,
    comp_letter_to_score = comp_letter_to_score,
    comp_split     = comp_split,
    comp_merge     = comp_merge,
    comp_mean      = comp_mean,
    comp_list_mean = comp_list_mean,
    comp_switch    = comp_switch}, nil)
