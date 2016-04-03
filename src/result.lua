--[[This module provides the Result Class for TGC.

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


--------------------------------------------------------------------------------
--- Round a number !
--------------------------------------------------------------------------------
local function round (num)
	if num >= 0 then return math.floor(num+.5)
	else return math.ceil(num-.5) end
end

--------------------------------------------------------------------------------
--- Gets the score corresponding to a grade
--
-- @param grade (string)
--------------------------------------------------------------------------------
local function grade_to_score (grade)
    grade = grade:upper() -- make sure the grade is uppercase
	if grade == "A" then return "10"
    elseif grade == "B" then return "7"
    elseif grade == "C" then return "3"
    elseif grade == "D" then return "0"
	else return "0" end -- Should be nil?
end

--------------------------------------------------------------------------------
--- Associates each grade of a list to the correspondant competence of the
--- other list.
--
-- A stared competence is only took into account if the corresponding grade is
-- also stared.
--
-- @param grades (string) - a list of grades (numbers)
-- @param comps (string) - a list of competences (A, B, C, D)
-- @return result (string) - the list of competences.
--------------------------------------------------------------------------------
local function combine_comps_and_grades (grades, comps)
    local result = ""
    local ct, gt = {}, {} -- competences and grades table

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
        elseif not string.match(comps[n], "%*") then
            result = result .. comp .. gt[m]
            m = m + 1
        end
    end

    return result
end


--------------------------------------------------------------------------------
--- THE RESULT CLASS
--
-- It contains the grades of each numbered competences
--------------------------------------------------------------------------------
local Result = {}
local Result_mt = {
    __metatable = {},
    __index = Result,
    __tostring = function (self)
            local l, a = {}, {}
            -- sort the competence numbers
            for comp in pairs(self) do a[#a + 1] = comp end
            table.sort(a)

            for _, comp in ipairs(a) do l[#l + 1] = comp .. self[comp] end
            return table.concat(l, " ") or ""
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
        end
    }


--------------------------------------------------------------------------------
--- Creates new Result.
--
-- On can use one or two args. If one args, it is considered as a comp + grades
-- string. If two args, the first is considered as a grade list and the second
-- as a competence list and the both are combined.
--
-- @param grades (string) - a list of competences (a number) each one followed
--      by grades (A, B, C or D). If the second arg is given, this string only
--      contains the list of grades corresponding to the competence numbers in
--      the second arg.
-- @param comps (string) - [optional] a list of competence numbers.
--------------------------------------------------------------------------------
function Result.new (grades, comps)
    if not comps then -- if one arg only, then it's a result (comps + grades)
        result = grades or ""
    else
        result = combine_comps_and_grades(grades, comps)
    end

    local o = setmetatable({}, Result_mt)

    -- convert the result string into a table
    for comp, grades in string.gmatch(result, "(%d+)([ABCDabcd%*]+)") do
        for grade in string.gmatch(grades, "[ABCDabcd]%*?") do
            o[comp] = (o[comp] or "") .. grade:upper()
        end
    end

    return o
end

--------------------------------------------------------------------------------
--- Gets the grades of the specified competence.
--
-- @param comp (number) - the competence number!
-- @return (string)
--------------------------------------------------------------------------------
function Result:get_grades (comp)
    return self[comp]
end

--------------------------------------------------------------------------------
--- Means the grades of each competences.
--
-- @return res (Grade) - moyenne
--------------------------------------------------------------------------------
function Result:calcmean ()
    local mean = ""

    if self == nil then return end

    for comp in pairs(self) do
        local comp_score, grades_nb = 0, 0
        for grade in string.gmatch(self[comp], "([ABCDabcd])%*?") do
            comp_score = comp_score + grade_to_score(grade)
            grades_nb = grades_nb + 1
        end
        local mean_comp_score = comp_score / grades_nb

        -- Empirical conversion (something like AAB -> A, CDD -> C)
        if mean_comp_score >= 9 then mean = mean .. comp .. "A"
        elseif mean_comp_score > 5 then mean = mean .. comp .. "B"
        elseif mean_comp_score >= 1 then mean = mean .. comp .. "C"
        else mean = mean .. comp .. "D"
        end

    end

	return Result.new(mean)
end

--------------------------------------------------------------------------------
--- Returns the means of all the grades (by competences).
--
-- @return (string) - the calculated result
--------------------------------------------------------------------------------
function Result:getmean ()
    return self and self.calcmean() and tostring(self.calcmean()) or ""
end

--------------------------------------------------------------------------------
--- Gets the score corresponding to the Result
--
-- @param score_max (number) - [optional]
-- @return score (number)
--------------------------------------------------------------------------------
function Result:getscore (score_max)
	score_max = score_max or 20
	local total_score, grades_nb = 0, 0
	local mean = self:calcmean()

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

return setmetatable({new = Result.new}, nil)
