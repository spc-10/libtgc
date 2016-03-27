--[[This module provides functions to handle evaluations by competences.

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

helpers = require("helpers")
lpeg = require("lpeg")

local M = {}

-- Constantes
local MAX_COMP = 7 -- Nombre maximal de compétences
local GRADE_TO_SCORE = {A = 10, B = 7, C = 3, D = 0}

-- Quelques raccourcis.
local find, match, format, gsub = string.find, string.match, string.format, string.gsub
local stripaccents = helpers.stripAccents

local P, S, V, R = lpeg.P, lpeg.S, lpeg.V, lpeg.R
local C, Cb, Cc, Cg, Cs, Ct, Cmt = lpeg.C, lpeg.Cb, lpeg.Cc, lpeg.Cg, lpeg.Cs, lpeg.Ct, lpeg.Cmt



--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function round (num)
	if num >= 0 then return math.floor(num+.5)
	else return math.ceil(num-.5) end
end

--------------------------------------------------------------------------------
-- Notes
--------------------------------------------------------------------------------

local Grades = {
    -- 1 = "ABCDA*",
    -- 2 = "ABCDA*",
    -- 3 = "ABCDA*",
    -- ...
}
for n = 1, MAX_COMP do Grades[n] = "" end -- Initialisation des compétences
local Grades_mt = {__index = Grades, __add = Grades.add}

-- Patterns lpeg
local digit =  R("19")
local lower_grade_letter = S("abcd")
local upper_grade_letter = S("ABCD")
local grade_letter = upper_grade_letter + lower_grade_letter
local star = P("*")
local starsomewhere = (1 - star)^0 * star
local sep = S(" -/") -- séparateur pour préciser l’absence d’une note (avec masque)
local grade = grade_letter * star^0
local cgradeorsep = C(grade + sep)
local cgradewostar = C(grade_letter) * star^0

local comp_grades = grade^1
local comp_number = digit -- 9 compétences max pour le moment
local comp_number_mask = comp_number * star^0
local not_comp = 1 - comp_number * comp_grades

local comp_pattern = (not_comp)^0 * C(comp_number) * C(comp_grades) * (not_comp)^0


--- Création d’une nouvelle note.
-- TODO meilleure doc
-- @param s (string) - la liste des notes sous la forme "1AA2B3A*C1D.."
function M.new (s)
    s = s or ""
    local o = setmetatable({}, Grades_mt)

    -- convertit la note texte en table
    -- chaque élément de type 1ABB de la chaîne de caractère initiale est
    -- converti en élément [1] = "ABB" de la table des notes
    local comp_pattern_s =
        (comp_pattern / function(a,b) o[tonumber(a)] = (o[tonumber(a)] or "") .. string.upper(b) end)^1
    lpeg.match(comp_pattern_s, s)

    return o
end

--- Gets the grades of the specified competence
-- @param comp (number) - the competence number!
-- @return (string)
function Grades:getcomp_grades (comp)
    if type(comp) == "number" and comp > 0 and comp <= MAX_COMP then
        return self[comp]
    else
        return nil
    end
end

--- Convertion de la note en chaîne de caractère de type "1AA2B3A*C".
-- @param sep (string) - séparateur à ajouter entre les notes des différentes
-- compétences
-- @return (string)
function Grades:tostring (sep)
	sep = sep or ""
    local l = {}
    for n = 1, MAX_COMP do
        if self[n] ~= "" then l[#l + 1] = tostring(n) .. tostring(self[n]) end
    end

    return table.concat(l, sep) or ""
end

--- Calcul de la moyenne de la note
-- @return res (Grades) - moyenne
function Grades:getmean ()
    local estimation = ""

    for n = 1, MAX_COMP do
		if self[n] ~= "" then
			local total_score, grades_nb = 0, 0
			local grade_pattern_s =
				(cgradewostar / function(a) total_score = total_score + GRADE_TO_SCORE[a]
					grades_nb = grades_nb + 1
					return nil
				end)^1
			lpeg.match(grade_pattern_s, self[n])

			local mean_score = total_score / grades_nb

			-- Conversion à la louche (AAB -> A, CDD -> C)
			if mean_score >= 9 then estimation = estimation .. n .. "A"
			elseif mean_score > 5 then estimation = estimation .. n .. "B"
			elseif mean_score >= 1 then estimation = estimation .. n .. "C"
			else estimation = estimation .. n .. "D"
			end
		end
    end
	return Grades:new(estimation)
end

--- Calcul de la note chiffrée correspondant à la note
-- @param score_max (number) - la note maximale
-- @return score (number) - note chiffrée
function Grades:getscore (score_max)
	score_max = score_max or 20
	local total_score, grades_nb = 0, 0
	local mean_grades = self:getmean() -- On ne calcule une note chiffrée que sur une moyenne

    for n = 1, MAX_COMP do
		if mean_grades[n] ~= "" then
			total_score = total_score + GRADE_TO_SCORE[mean_grades[n]]
			grades_nb = grades_nb + 1
		end
    end
	
	if grades_nb > 0 then
		return round(total_score / grades_nb / GRADE_TO_SCORE["A"] * score_max)
	else
		return nil
	end
end

--- Addition de deux notes (métaméthode)
-- @param a (Grades) - première note à additionner
-- @param b (Grades) - seconde note à additionner
-- @return (Grades) - somme des deux notes
function Grades.add (a, b)
    if a == nil and b == nil then
        return Grades:new()
    elseif a == nil then
        return b
    elseif b == nil then
        return a
    else
        return Grades:new(a:tostring() .. b:tostring())
    end
end

--- Crée une note à partir des valeurs des notes et d’un masque des compétences
--correspondant.
-- TODO Gestion des erreurs ?
-- @param grades_values (string) - notes (sans numéro des compétences)
-- @param mask (string) - numéro des compétences
-- @return grades_s (string) - notes complètes
function M.grades_unmask(grades_values, mask)
    local grades_s = ""

    -- TODO check syntaxe
    -- On récupère les notes dans un tableau et les compétences correspondantes
    -- dans un autre tableau
    local t_comp = lpeg.match(Ct(C(comp_number_mask)^1), mask)
    local t_grades = lpeg.match(Ct(cgradeorsep^1), grades_values)
    if not t_comp then return "" end -- le masque n’est pas valide

    -- Si les notes contiennent déjà les numéros des compétences, on n’utilise
    -- pas le masque
    if lpeg.match(comp_pattern^1, grades_values) then
        return grades_values
    end

    for n = 1, #t_comp do
        -- Si la compétence est facultative, on vérifie si la note facultative
        -- (étoilée) est renseignée, sinon on insère un séparateur (= pas de note)
        t_grades[n] = t_grades[n] or " " -- pas de note si vide
        if lpeg.match(starsomewhere, t_comp[n]) and not lpeg.match(starsomewhere, t_grades[n]) then
            -- TODO ne fonctionne pas si deux notes facultatives se suivent
            table.insert(t_grades, n, " ")
        end
        -- Si la note n’est pas facultative et qu’elle est renseignée, on la rajoute.
        if not lpeg.match(sep,t_grades[n]) then -- ne pas tenir compte des notes non renseignées
            grades_s = grades_s .. gsub(t_comp[n], "%*", "") .. t_grades[n]
        end
    end

    return grades_s
end

return M
