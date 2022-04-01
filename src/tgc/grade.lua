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
local COMPETENCIES = {
    [1] = {id = "1.1", name = "Comprendre, s’exprimer en utilisant la langue française à l’oral et à l’écrit"},
    [2] = {id = "1.2", name = "Comprendre, s’exprimer en utilisant une langue étrangère, et, le cas échéant, une langue régionale"},
    [3] = {id = "1.3", name = "Comprendre, s’exprimer en utilisant les langages mathématiques, scientifiques et informatiques"},
    [4] = {id = "1.4", name = "Comprendre, s’exprimer en utilisant les langages des arts et du corps"},
    [5] = {id = "2",   name = "Les méthodes et outils pour apprendre"},
    [6] = {id = "3",   name = "La formation de la personne et du citoyen"},
    [7] = {id = "4",   name = "Les systèmes naturels et les systèmes techniques"},
    [8] = {id = "5",   name = "Les représentations du monde et de l’activité humaine"},
}


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
-- Split a list of competencies (id plus grades) into a table
-- Exemple : "1AB 2CD 4B" returns {[1] = "AB", [2] = "CD", [4] = "B"}
--
-- @param comp_list (string) - a list of competencies ids and corresponding grades
-- @return comp (table)
--------------------------------------------------------------------------------
local function split_competencies (comp_list)
    local comp = {}

    if not comp_list then
        return nil
    end

    -- convert the result string into a table
    for id, grades in string.gmatch(comp_list, "(%d+)([ABCDabcd%*]+)") do
        for grade in string.gmatch(grades, "[ABCDabcd]%*?") do
            comp[id] = (comp[id] or "") .. grade:upper()
        end
    end

    return comp
end

--------------------------------------------------------------------------------
-- Merge a competencies table to string
-- Exemple : {[1] = "AB", [2] = "CD", [4] = "B"} returns "1AB 2CD 4B"
--
-- @param comp_list (string) - a list of competencies ids and corresponding grades
-- @return comp (table)
--------------------------------------------------------------------------------
local function merge_competencies (comp)
    local comp = comp or {}
    local comp_tmp = {}

    -- convert the result string into a table
    for id, grades in pairs(comp) do
        table.insert(comp_tmp, id .. grades)
    end

    table.sort(comp_tmp)

    return table.concat(comp_tmp, " ")
end

--------------------------------------------------------------------------------
--- Associates each grade of a list to the corresponding competence of the
--- other list.
--
-- A stared competence is only took into account if the corresponding grade is
-- also stared. If the grade already contains competences, then the list of
-- competences is discarded.
--
-- @param grades (string) - a list of grades (A, B, C, D)
-- @param comps (string) - a list of competences (number)
-- @return result (string) - the list of competences.
--------------------------------------------------------------------------------
--[[local function combine_comps_and_grades (grades, comps)
    local result = ""
    local ct, gt = {}, {} -- competences and grades table

    -- First check if the grades contains competences. In this case, no need to
    -- combine.
    if grades:match("%d+") then return grades end

    for comp in string.gmatch(comps, "%d+%*?") do
        ct[#ct + 1] = comp
    end
    for grade in string.gmatch(grades, "[ABCDabcd]%*?") do
        gt[#gt + 1] = grade
    end

    local m = 1
    for n = 1, #ct do
        if not gt[m] then break end
        local comp = string.match(ct[n], "%d+")
        -- ignore stared competences when no stared grade is given
        if string.match(ct[n], "%*")  and string.match(gt[m], "%*") then
            result = result .. comp .. gt[m]
            m = m + 1
        elseif not string.match(ct[n], "%*") then
            result = result .. comp .. gt[m]
            m = m + 1
        end
    end

    return result
end
]]--

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
--  "1A 2B 3C")
--
-- A grade can contain the numbered part alone, the competencies part alone or
-- it can be a table containing both.
--
-- @param grade1 or grade2 (number) - a numbered grade.
-- @param grade1 or grade2 (string) - a list of competencies with corresponding
-- grades (see above).
-- @param grade1 (table) - a table with both grade1 and grade2
-- @return g (Grade)
--------------------------------------------------------------------------------
function Grade.new (grade1, grade2)
    local g = setmetatable({}, Grade_mt)

    if type(grade1) == "number" then
        g.num  = grade1
        if type(grade2) == "string" then
            g.comp = split_competencies(grade2)
        end
    elseif type(grade1) == "string" then
        g.comp = split_competencies(grade1)
        if type(grade2) == "number" then
            g.num = grade2
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
        fwrite("%q",       merge_competencies(self.comp))
    elseif self.num and self.comp then
        fwrite("{%.2f, %q}", self.num, merge_competencies(self.comp))
    end
end

--------------------------------------------------------------------------------
--- Gets the grades of the specified competence.
--
-- @param comp (number) - the competence number!
-- @return (string)
--------------------------------------------------------------------------------
--[[function Grade:get_grades (comp)
    return self[comp]
end
]]--

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
