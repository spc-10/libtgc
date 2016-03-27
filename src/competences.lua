--[[This module provides the Competences Class for TGC.

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

local _M = {}


--------------------------------------------------------------------------------
-- Round a number !
--------------------------------------------------------------------------------
local function round (num)
	if num >= 0 then return math.floor(num+.5)
	else return math.ceil(num-.5) end
end

--------------------------------------------------------------------------------
-- Gets the score corresponding to grade
--
-- @param grade (string)
--------------------------------------------------------------------------------
local function grade_to_score (grade)
	if grade == "A" then return "10"
    elseif grade == "B" then return "7"
    elseif grade == "C" then return "3"
    elseif grade == "D" then return "0"
	else return "0" end -- Should be nil?
end

--------------------------------------------------------------------------------
-- Return a list of competences made from a grades list and a competence numbers
-- list (the mask).
--
-- TODO Better do with examples.
--
-- @param s (string) - grades list.
-- @param mask (string) - competence numbers list.
-- @return competences (string) - the list of competences.
--------------------------------------------------------------------------------
local function unmask_competences (s, mask)
    local competences = ""
    local comp_t, grade_t = {}, {}

    for comp in string.gmatch(mask, "%d+%*?") do
        comp_t[#comp_t + 1] = comp
    end
    for grade in string.gmatch(s, "[ABCDabcd]%*?") do
        grade_t[#grade_t + 1] = grade
    end

    local m = 1
    for n = 1, #comp_t do
        if not grade_t[m] then break end
        local comp_number = string.match(comp_t[n], "%d+")
        -- ignore stared competences when no stared grade is given
        if string.match(comp_t[n], "%*")  and string.match(grade_t[m], "%*") then
                competences = competences .. comp_number .. grade_t[m]
            m = m + 1
        elseif not string.match(comp_t[n], "%*") then
            competences = competences .. comp_number .. grade_t[m]
            m = m + 1
        end
    end

    return competences
end


--------------------------------------------------------------------------------
-- THE COMPETENCE CLASS
--
-- It contains the grades of each number competences
--------------------------------------------------------------------------------
local Competences = {}
local Competences_mt = {
    __metatable = {},
    __index = Competences,
    __add = Competences.add}


--------------------------------------------------------------------------------
-- Creates new Competences
--
-- @param s (string) - a list of competences (a number) each one followed by
--                     grades (A, B, C or D). If the mask is given. this string
--                     only contains the list of grades corresponding to the
--                     competence numbers in the mask.
-- @param mask (string) - [optional] a list of competence numbers.
--------------------------------------------------------------------------------
function _M.new (s, mask)
    s = s or ""
    if mask then
        s = unmask_competences(s, mask)
    end
    local o = setmetatable({}, Competences_mt)

    -- convert the competences string into a table
    for comp, grades in string.gmatch(s, "(%d+)([ABCDabcd%*]+)") do
        for grade in string.gmatch(grades, "[ABCDabcd]%*?") do
            o[comp] = (o[comp] or "") .. string.upper(grade)
        end
    end

    return o
end

--------------------------------------------------------------------------------
-- Gets the grades of the specified competence.
--
-- @param comp (number) - the competence number!
-- @return (string) - the corresponding grades.
--------------------------------------------------------------------------------
function Competences:getcomp_grades (comp)
    return self[comp]
end

--------------------------------------------------------------------------------
-- Converts the competences table into a string.

-- @param sep (string) - [optional] separator to insert between each competence
--                       grades.
-- @return (string) - the competences string!
--------------------------------------------------------------------------------
function Competences:tostring (sep)
	sep = sep or ""
    local l, a = {}, {}

    -- sort the competence numbers
    for comp in pairs(self) do a[#a + 1] = comp end
    table.sort(a)

    for _, comp in ipairs(a) do
        l[#l + 1] = comp .. self[comp]
    end

    return table.concat(l, sep) or ""
end

--------------------------------------------------------------------------------
-- Means the grades of the competences.
--
-- @return res (Competences) - moyenne
--------------------------------------------------------------------------------
function Competences:getmean ()
    local estimation = ""

    for comp in pairs(self) do
        local comp_score, grades_nb = 0, 0
        for grade in string.gmatch(self[comp], "([ABCDabcd])%*?") do
            comp_score = comp_score + grade_to_score(grade)
            grades_nb = grades_nb + 1
        end
        local mean_comp_score = comp_score / grades_nb

        -- Empirical conversion (something like AAB -> A, CDD -> C)
        if mean_comp_score >= 9 then estimation = estimation .. comp .. "A"
        elseif mean_comp_score > 5 then estimation = estimation .. comp .. "B"
        elseif mean_comp_score >= 1 then estimation = estimation .. comp .. "C"
        else estimation = estimation .. comp .. "D"
        end

    end

	return _M.new(estimation)
end

--------------------------------------------------------------------------------
-- Gets the score corresponding to the competences grades
--
-- @param score_max (number) - [optional]
-- @return score (number)
--------------------------------------------------------------------------------
function Competences:getscore (score_max)
	score_max = score_max or 20
	local total_score, grades_nb = 0, 0
	local mean = self:getmean()

    for comp in pairs(mean) do
        total_score = total_score + grade_to_score(mean[comp])
        grades_nb = grades_nb + 1
    end
	
	if grades_nb > 0 then
		return round(total_score / grades_nb / grade_to_score("A") * score_max)
	else
		return nil
	end
end

--------------------------------------------------------------------------------
-- Add 2 Competences
--
-- @param a (Competences)
-- @param b (Competences)
-- @return (Competences) - the sum.
--------------------------------------------------------------------------------
function Competences.add (a, b)
    if not a and not b then return _M.new()
    elseif not a then return b
    elseif not b then return a
    else return _M.new(a:tostring() .. b:tostring())
    end
end
Competences_mt.__add = Competences.add

return _M
