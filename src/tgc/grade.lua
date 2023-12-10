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

-- TODO: to remove or rewrite (old description from Competency class)…
--
-- A grade is an uppercase letter (lowercase letter should also work):
-- * A means very good
-- * B mens good
-- * C means not good
-- * D means bad
-- TODO remove this star part
-- The grade may be followed by a star (*) which means that the associated
-- evaluation was optional (and more difficult).
--
-- A competence is a number (1, 2, 3.. 6) which represent a specific competence
-- description.
--
-- A result is a list of all the grades associated to their respective
-- competences.
-- Examples: 1AAB 2AC*D 5A 6DDA*


-- Score of each competences
-- ["competence number"] = {score_for_A, score_for_B, score_for_C, score_for_D}
-- TODO: move this in a config file!
--[[local COMP_SCORE = {
    ["1"] = {8, 5, 3, 0},
    ["2"] = {10, 7, 3, 0},
    ["3"] = {8, 5, 3, 0},
    ["4"] = {8, 5, 3, 0},
    ["5"] = {4, 3, 1, 0},
    ["6"] = {4, 3, 1, 0},
    default = {10, 7, 3, 0},
}
]]--

-- TODO this should go to `notes.lua`
--local COMPETENCIES = {
--    [1] = {id = "1.1", name = "Comprendre, s’exprimer en utilisant la langue française à l’oral et à l’écrit"},
--    [2] = {id = "1.2", name = "Comprendre, s’exprimer en utilisant une langue étrangère, et, le cas échéant, une langue régionale"},
--    [3] = {id = "1.3", name = "Comprendre, s’exprimer en utilisant les langages mathématiques, scientifiques et informatiques"},
--    [4] = {id = "1.4", name = "Comprendre, s’exprimer en utilisant les langages des arts et du corps"},
--    [5] = {id = "2",   name = "Les méthodes et outils pour apprendre"},
--    [6] = {id = "3",   name = "La formation de la personne et du citoyen"},
--    [7] = {id = "4",   name = "Les systèmes naturels et les systèmes techniques"},
--    [8] = {id = "5",   name = "Les représentations du monde et de l’activité humaine"},
--}


--------------------------------------------------------------------------------
--- Rounds a number.
--------------------------------------------------------------------------------
--[[local function round (num)
	if num >= 0 then return math.floor(num + 0.5)
	else return math.ceil(num - 0.5) end
end
]]--

--------------------------------------------------------------------------------
--- Gets the score corresponding to a grade.
--
-- @param grade (string)
--------------------------------------------------------------------------------
--[[local function grade_to_score (grade, comp)
    grade = grade:upper() -- make sure the grade is uppercase
    if not COMP_SCORE[comp] then
        comp = "default"
    end

	if grade == "A" then return COMP_SCORE[comp][1]
    elseif grade == "B" then return COMP_SCORE[comp][2]
    elseif grade == "C" then return COMP_SCORE[comp][3]
    elseif grade == "D" then return COMP_SCORE[comp][4]
	else return nil end
end
]]--

--------------------------------------------------------------------------------
-- Creates a list of competencies grades.
-- Competencies grades are a list of id and letter couples : for example {"1A", "1C", "3C", "12-"}.
--
--  TODO Doc
-- @param comp_list (string) - a list of competencies ids and corresponding grades
-- @return comp (table)
--------------------------------------------------------------------------------
local function create_comp_grades (comp_letters, comp_ids)
    local comp_grades = {}

    -- split the competencies
    repeat -- split the competencies
        comp_letters, n = string.gsub(comp_letters, "(%d+)([ABCDabcd-])([ABCDabcd-])", "%1%2 %1%3")
    until n == 0
    -- print("DEBUG : comp_letters = ", comp_letters)


    if not comp_letters or string.match(comp_letters, "^%d*$") then
        return nil
    -- There are no comp ids at all.
    elseif not string.match(comp_letters, "%d+") and not comp_ids then
        -- print("DEBUG ----------- 1 --------")
        return nil
    -- Comp letters and ids are separated.
    elseif not string.match(comp_letters, "%d+") then
        --print("DEBUG ----------- 2 --------")
        local ids_list, comp_letters_list = {}, {}

        for _, id in ipairs(comp_ids) do
            table.insert(ids_list, id)
        end
        for letter in string.gmatch(comp_letters, "[ABCDabcd-]") do
            table.insert(comp_letters_list, letter)
        end

        -- Associate
        for i, id in ipairs(ids_list) do
            if comp_letters_list[i] then
                table.insert(comp_grades, id .. string.upper(comp_letters_list[i]))
            else
                table.insert(comp_grades, id .. "-")
            end
        end
    -- Comp letters are already associated with ids and no ids model given.
    elseif string.match(comp_letters, "%d+") and not comp_ids then
        -- print("DEBUG ----------- 3 --------")
        for id, letters in string.gmatch(comp_letters, "(%d+)([ABCDabcd-]+)") do
            for letter in string.gmatch(letters, ".") do
                table.insert(comp_grades, id .. letter:upper())
            end
        end
    -- Comp letters are already associated with ids and ids model given.
    -- We must check the correspondance.
    elseif string.match(comp_letters, "%d+") and comp_ids then
        -- print("DEBUG ----------- 4 --------")
        local ids_list = {}
        local i = 1

        for _, id in ipairs(comp_ids) do
            -- print("DEBUG : id = ", id)
            local letter = string.match(comp_letters, "%D*" ..id .. "([ABCDabcd-])")
            -- print("DEBUG : letter = ", letter)
            if letter then
                table.insert(comp_grades, id .. letter:upper())
                -- Remove matching comp
                comp_letters = string.gsub(comp_letters, "%s*" .. id .. "[ABCDabcd-]%s*", " ", 1)
            end
            -- print("DEBUG : comp_letters = ", comp_letters)
        end
    else
        return nil
    end

    return comp_grades
end

--------------------------------------------------------------------------------
-- Split a list of competencies (id plus grades) into a table
-- Exemple : "1AB 2CD 4B" returns {[1] = {"A", "B"}, [2] = {"C", "D"}, [4] = {"B"}}
--
-- @param comp_list (string) - a list of competencies ids and corresponding grades
-- @return comp (table)
--------------------------------------------------------------------------------
local function split_competencies (comp_list)
    if not comp_list or string.match(comp_list, "^%d*$") then
        return nil
    end

    -- convert the result string into a table
    local comp = {}
    for id, grades in string.gmatch(comp_list, "(%d+)([ABCDabcd-]+)") do
        local i = tonumber(id)
        comp[i] = comp[i] or {}
        for grade in string.gmatch(grades, "[ABCDabcd-]%*?") do
            table.insert(comp[i], grade:upper())
        end
    end

    return comp
end

--------------------------------------------------------------------------------
-- Convert a competencies table to string
-- Exemple : {[1] = "AB", [2] = "CD", [4] = "B"} returns "1AB 2CD 4B"
--
-- @param comp_list (string) - a list of competencies ids and corresponding grades
-- @return comp (table)
--------------------------------------------------------------------------------
local function competencies_concat (comp, split)
    local split = split or false
    local comp = comp or {}
    local comp_tmp = {}
    local sorted_comp_id = {}

    -- First we get the comp_id list to sort it
    for id, _ in pairs(comp) do
        table.insert(sorted_comp_id, id)
    end
    table.sort(sorted_comp_id)

    -- convert the result string into a table
    for _, id in ipairs(sorted_comp_id) do
        if split then
            for _, c in ipairs(comp[id]) do
                table.insert(comp_tmp, id .. c)
            end
        else
            table.insert(comp_tmp, id .. table.concat(comp[id]))
        end
    end

    return table.concat(comp_tmp, " ")
end

--------------------------------------------------------------------------------
-- Convert a competencies grades table to a string
-- Exemple : returns "1AB 2CD 4B"
-- Style: compact or split
-- @param comp_list (string) - a list of competencies ids and corresponding grades
-- @return comp (table)
--------------------------------------------------------------------------------
local function comp_grades_tostring (comp_grades, style)
    local style = style or "compact"
    local compact_comp_grades_list = {}

    if not comp_grades then
        return ""
    end

    if style == "split" then
        return table.concat(comp_grades, " ")
    else --elseif style == "compact" then
        for _, comp_grade in ipairs(comp_grades) do
            id, letter = string.match(comp_grade, "(%d+)([ABCD-])")
            i = tonumber(id)
            if not compact_comp_grades_list[i] then
                compact_comp_grades_list[i] = letter
            else
                compact_comp_grades_list[i] = compact_comp_grades_list[i] .. letter
            end
        end
        -- We then sort the index
        local sorted_comp_id = {}
        for id, _ in pairs(compact_comp_grades_list) do
            table.insert(sorted_comp_id, id)
        end
        table.sort(sorted_comp_id)
        local comp_tmp = {}
        for _, id in ipairs(sorted_comp_id) do
            table.insert(comp_tmp, id .. compact_comp_grades_list[id])
        end
        return table.concat(comp_tmp, " ")
    end
end

--------------------------------------------------------------------------------
--- Associates each grade of a list to the corresponding competency id of the
--- other list.
--
-- @param comp_grades (string) - a list of comp_grades (A, B, C, D)
-- @param ids (string) - a list of competencies ids (number)
-- @return result (string) - the list of competencies.
--------------------------------------------------------------------------------
local function associate_comp_ids_and_letters (comp_letters, comp_ids)
    local result = ""
    local ids_list, comp_grades_list = {}, {}

    -- First check if the comp_letters already contains competences ids. In this
    -- case, no need to merge.
    if string.match(comp_letters, "%d+") or not comp_ids then
        return comp_letters
    end

    -- Get the lists of comp_letters and comp_ids
    for id in string.gmatch(comp_ids, "%d+") do
        table.insert(ids_list, id)
    end
    for grade in string.gmatch(comp_letters, "[ABCDabcd-]") do
        table.insert(comp_grades_list, grade)
    end

    -- Merge
    for i, id in ipairs(ids_list) do
        if not comp_grades_list[i] then
            break
        else
            result = result .. id .. comp_grades_list[i]
        end
    end

    return result ~= "" and result or nil
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
--[[    __metatable = {},
    __tostring = function (self)
            local l, a = {}, {}
            -- sort the competence numbers
            for comp in pairs(self) do a[#a + 1] = comp end
            table.sort(a)

            for _, comp in ipairs(a) do l[#l + 1] = comp .. self[comp] end
            return table.concat(l, " ")
        end,
    __add = function (a, b)
            if not a and not b then return Result.new()
            elseif not a then return b
            elseif not b then return a
            else return Result.new(tostring(a) .. tostring(b))
            end
        end,
    __eq = function (a, b)
            local isequal = true
            if not a and not b then return true
            elseif not a then return false
            elseif not b then return false
            else
                for comp in pairs(a) do
                    isequal = isequal and b[comp] and a[comp] == b[comp]
                    if not isequal then return false end
                end
                for comp in pairs(b) do -- TODO optimize this!
                    isequal = isequal and a[comp] and a[comp] == b[comp]
                    if not isequal then return false end
                end
            end
            return true
        end]]--


--------------------------------------------------------------------------------
-- Creates new Grade
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
function Grade.new (grade1, grade2, eval_comp_ids)
    local g = setmetatable({}, Grade_mt)

    if type(grade1) == "number" then
        g.num  = grade1
        if type(grade2) == "string" then
            g.comp = create_comp_grades(grade2, eval_comp_ids)
        end
    elseif type(grade1) == "string" then
        g.comp = create_comp_grades(grade1, eval_comp_ids)
        if type(grade2) == "number" then
            g.num = grade2
        end
    elseif not grade1 then
        if type(grade2) == "number" then
            g.num = grade2
        elseif type(grade2) == "string" then
            g.comp = create_comp_grades(grade2, eval_comp_ids)
        end
    elseif type (grade1) == "table" then
        return Grade.new(grade1[1], grade1[2])
    else
        return nil --, error msg
    end

    return g
end

--------------------------------------------------------------------------------
-- Write the evaluation in a file.
-- @param f (file) - file (open for writing)
function Grade:write (f)
    local function fwrite (...) f:write(string.format(...)) end

    -- TODO Format %.2f ??
    if self.num and not self.comp then
        fwrite("%.2f",     self.num)
    elseif self.comp and not self.num then
        fwrite("%q",       comp_grades_tostring(self.comp))
    elseif self.num and self.comp then
        fwrite("{%.2f, %q}", self.num, comp_grades_tostring(self.comp))
    end
end

--------------------------------------------------------------------------------
--- Get the score and competencies parts of a grade.
function Grade:get_score_and_competencies ()
    return self.num, self.comp
end

--------------------------------------------------------------------------------
--- Get the score and competencies parts of a grade.
function Grade:get_formatted_competencies (style)
    return comp_grades_tostring(self.comp, style)
end

--------------------------------------------------------------------------------
--- Get the score and competencies parts of a grade.
function Grade:get_score_and_comp (style)
    return self.num, comp_grades_tostring(self.comp, style)
end

--------------------------------------------------------------------------------
--- Get the mean score and competencies parts of a grade.
function Grade:mean_competencies ()
    local comp_grade_mean = ""
    local comp_grade_score_sum = {}
    local comp_grade_nval = {}

    if not self.comp then
        return nil
    end

    -- Competencies mean
    for _, comp_grade in pairs(self.comp) do
        --print("DEBUG : letter_grades = ", comp_grade)
        local score, nval

        id, letter = string.match(comp_grade, "(%d+)([ABCD-])")
        local i = tonumber(id)
        comp_grade_score_sum[i] = comp_grade_score_sum[i] or 0
        comp_grade_nval[i]      = comp_grade_nval[i] or 0

        -- TODO get letter_grades score from configuration file
        if letter == "A" then
            score, nval = 1, 1
            --print("DEBUG : score, nval = 1, 1")
        elseif letter == "B" then
            score, nval = 0.66, 1
            --print("DEBUG : score, nval = 0.66, 1")
        elseif letter == "C" then
            score, nval = 0.33, 1
            --print("DEBUG : score, nval = 0.33, 1")
        elseif letter == "D" then
            score, nval = 0, 1
            --print("DEBUG : score, nval = 0, 1")
        else -- letter == "-"
            score, nval = 0, 0
            --print("DEBUG : score, nval = 0, 0")
        end
        --print("DEBUG : comp_grade_score_sum[i] = ", comp_grade_score_sum[i], i)
        comp_grade_score_sum[i] = comp_grade_score_sum[i] + score
        --print("DEBUG : comp_grade_score_sum[i] + score = ", comp_grade_score_sum[i], i)
        comp_grade_nval[i] = comp_grade_nval[i] + nval
    end

    for id, score_sum in pairs(comp_grade_score_sum) do
        local mean_comp_score = score_sum / comp_grade_nval[id]
        if mean_comp_score > 0.85 then
            comp_grade_mean = comp_grade_mean .. id .."A "
        elseif mean_comp_score > 0.6 then
            comp_grade_mean = comp_grade_mean .. id .."B "
        elseif mean_comp_score > 0.3 then
            comp_grade_mean = comp_grade_mean .. id .."C "
        elseif mean_comp_score == 0 then
            comp_grade_mean = comp_grade_mean .. id .."- "
        else
            comp_grade_mean = comp_grade_mean .. id .."D "
        end
    end

    --print("DEBUG : comp_grade_mean = ", comp_grade_mean)

    return Grade.new(self.num, comp_grade_mean)
end


--------------------------------------------------------------------------------
--- Means the grades of each competences.
--
-- @return res (Grade) - moyenne
--------------------------------------------------------------------------------
--[[function Grade:calc_mean ()
    local mean = ""

    if self == nil then return end

    for comp in pairs(self) do
        local comp_score, grades_nb = 0, 0
        for grade in string.gmatch(self[comp], "([ABCDabcd])%*?") do
            comp_score = comp_score + (grade_to_score(grade, comp) or 0)
            grades_nb = grades_nb + 1
        end
        local mean_comp_score = comp_score / grades_nb

        -- Empirical conversion (something like AAB -> A, CDD -> C)
        if mean_comp_score >= 0.9 * grade_to_score("A", comp) then
            mean = mean .. comp .. "A"
        elseif mean_comp_score >= 0.5 * grade_to_score("A", comp) then
            mean = mean .. comp .. "B"
        elseif mean_comp_score >= 0.1 * grade_to_score("A", comp) then
            mean = mean .. comp .. "C"
        else
            mean = mean .. comp .. "D"
        end

    end

	return Grade.new(mean)
end
]]--

--------------------------------------------------------------------------------
--- Returns the means of all the grades (by competences).
--
-- @return (string) - the calculated Grade
--------------------------------------------------------------------------------
--[[function Grade:get_mean ()
    local result = self:calc_mean()
    return tostring(result)
end
]]--

--------------------------------------------------------------------------------
--- Gets the score corresponding to a result competence.
--
-- @param comp (number)
-- @return score (number), max_score (number)
--------------------------------------------------------------------------------
--[[function Grade:calc_comp_score (comp)
    -- result must first be meaned.
	local mean = self:calc_mean()
    if not mean or not mean[comp] then return nil end

    local score = grade_to_score(mean[comp], comp)
    local max_score = grade_to_score("A", comp)

    return score, max_score
end
]]--

--------------------------------------------------------------------------------
--- Gets the score corresponding to the Result.
--
-- @param score_max (number) - [optional]
-- @return score (number)
--------------------------------------------------------------------------------
--[[function Grade:calc_score (score_max)
	score_max = score_max or 20
	local total_score, total_coef = 0, 0

    for comp in pairs(self) do
        local score, coef = self:calc_comp_score(comp)

        total_score = total_score + (score or 0)
        total_coef = total_coef + (coef or 0)
    end

	if total_coef > 0 then
		return round(total_score * 10 / total_coef * score_max) / 10, score_max
	else
		return nil
	end
end
]]--

return setmetatable({new = Grade.new}, nil)
