[[  This module provides functions to handle evaluations by competences.

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
]]

-- TODO:
-- [] classes : ajout des classes à la liste
-- [] évaluations : ajout des évaluations à la liste

local libdir = os.getenv("HOME") .. "/lib/lua"
package.path = package.path .. ";" .. libdir .. "/?"
package.path = package.path .. ";" .. libdir .. "/?.lua"

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

--- Fonction de tri des élèves par classe puis par nom.
-- Les lettres accentuées sont remplacées par leur équivalent non accentué
local function sort_students_byclassname (a, b)
	return stripaccents(a.class) .. stripaccents(a.lastname) .. stripaccents(a.name)
		< stripaccents(b.class) .. stripaccents(b.lastname) .. stripaccents(b.name)
end

--- Fonction de tri des évals par date.
local function sort_evals_bydate (a, b)
	return a.date < b.date
end

--- Fonction de tri des moyennes trimestrielles par trimestre
local function sort_reports_byquarter (a, b)
	return a.quarter < b.quarter
end

--- Itérateur des élèves d’une classe
function M.students_in_class (students, class)
    local n = 0
    return function ()
        while true do
            n = n + 1
            if not students[n] then return nil end
            if students[n].class and students[n].class == class then
                return n
            end
        end
    end
end
local students_in_class = M.students_in_class

--- Itérateur des evals d’un trimestre
function M.evals_in_quarter (evals, quarter)
    local n = 0
    return function ()
        while true do
            n = n + 1
            if not evals[n] then return nil end
            if evals[n].quarter and evals[n].quarter == quarter then
                return n
            end
        end
    end
end
local evals_in_quarter = M.evals_in_quarter

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
function Grades:new (s)
    s = s or ""
    local o = {}
    setmetatable(o, self)
    self.__index = self
    self.__add = self.add

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

--------------------------------------------------------------------------------
-- Moyennes du trimestre
--------------------------------------------------------------------------------

local Report = {
    -- quarter = "1",
    -- grades = Grades,
    -- score = "12",
}

--- Création d’une nouvelle moyenne trimestrielle.
-- @param o (table) - table contenant les attributs de la moyenne
-- @return s (Report) - nouvel objet moyenne
function Report:new (o)
    local s = {}
    setmetatable(s, self)
    self.__index = self

    -- Vérification des attributs de la moyenne trimestrielle
    assert(o.quarter and o.quarter ~= "",
        "Impossible de créer la moyenne : trimestre obligatoire")
    s.quarter = o.quarter
    s.score = o.score or ""
    s.grades = Grades:new(o.grades or "")

    return s
end

--- Écriture d’une moyenne dans la base de données.
-- @param f (file) - fichier ouvert en écriture
function Report:write (f)
    f:write("\t\t{")
    f:write(format("quarter = \"%s\", ", self.quarter or ""))
    f:write(format("grades = \"%s\", ", self.grades:tostring()))
    f:write(format("score = \"%s\", ", self.score or ""))
    f:write("},\n")
end

--------------------------------------------------------------------------------
-- Évaluations
--------------------------------------------------------------------------------

local Eval = {
    -- id = "identifiant",
    -- title = "Évaluation n° 3",
    -- number = "3",
    -- date = "01/01/2001",
    -- quarter = "1",
    -- grades = Grades,
}

--- Création d’une nouvelle évaluation.
-- @param o (table) - table contenant les attributs de l’évaluation
-- @return s (Eval) - nouvel objet évaluation
function Eval:new (o)
    local s = {}
    setmetatable(s, self)
    self.__index = self

    -- Vérification des attributs de l’évaluation
    assert(o.id and o.id ~= ""
        and o.date and o.date ~= ""
        and o.quarter and o.quarter ~= "",
        "Impossible de créer l’évaluation : identifiant, date et trimestre obligatoires")
    s.id, s.date, s.quarter = o.id, o.date, o.quarter
    s.title, s.number = o.title or "", o.number
    s.grades = Grades:new(o.grades or "")

    return s
end

--- Écriture d’une évaluation dans la base de données.
-- @param f (file) - fichier ouvert en écriture
function Eval:write (f)
    f:write("\t\t{")
    f:write(format("id = \"%s\", ", self.id or ""))
    f:write(format("title = \"%s\", ", self.title or ""))
    f:write(format("number = \"%s\", ", self.number or ""))
    f:write(format("quarter = \"%s\", ", self.quarter or ""))
    f:write(format("date = \"%s\", ", self.date or ""))
    f:write(format("grades = \"%s\", ", self.grades:tostring()))
    f:write("},\n")
end

--- Change ou ajoute les notes d’une évaluation
-- @param grades_s (string) - notes à ajouter
function Eval:setgrades (grades_s)
    local grades = Grades:new(grades_s)
    self.grades = grades
end


--------------------------------------------------------------------------------
-- Élèves
--------------------------------------------------------------------------------

local Student = {
    -- lastname = "Doe",
    -- name = "John",
    -- class = "5e1",
    special = "", -- dys, pai, aménagements...
    evaluations = {}, -- Eval table
    reports = {}, -- Report table
}

--- Création d’un nouvel élève.
-- @param o (table) - table contenant les attributs de l’élève
-- @return s (Student) - nouvel objet élève
function Student:new (o)
    local s = {}
    setmetatable(s, self)
    self.__index = self

    -- Vérifications des attributs de l’élève
    assert(o.lastname and o.lastname ~= ""
        and o.name and o.name ~= ""
        and o.class and o.class ~= "",
        "Impossible de créer l’élève : nom, prénom et classe obligatoires")
    s.lastname, s.name, s.class = o.lastname, o.name, o.class
    s.special = o.special or ""

    -- Création des évaluations
    s.evaluations = {}
    if o.evaluations then
        assert(type(o.evaluations) == "table",
            format("Impossible de créer l’élève %s %s : erreur de syntaxe de la table des évaluations",
                s.lastname, s.name))
        for n = 1, #o.evaluations do
            assert(type(o.evaluations[n]) == "table",
                format("Impossible de créer l’élève %s %s : erreur de syntaxe des évaluations",
                    s.lastname, s.name))
            table.insert(s.evaluations, Eval:new(o.evaluations[n]))
        end
    end

    -- Création des moyennes trimestrielles
    s.reports = {}
    if o.reports then
        assert(type(o.reports) == "table",
            format("Impossible de créer l’élève %s %s : erreur de syntaxe de la table des moyennes trimestrielles",
                s.lastname, s.name))
        for n = 1, #o.reports do
            assert(type(o.reports[n]) == "table",
                format("Impossible de créer l’élève %s %s : erreur de syntaxe des moyennes trimestrielles",
                    s.lastname, s.name))
            table.insert(s.reports, Report:new(o.reports[n]))
        end
    end

    return s
end

--- Écriture d’un élève dans la base de données.
-- @param f (file) - fichier ouvert en écriture
function Student:write (f)
	f:write("entry{\n")

    f:write(format("\tlastname = \"%s\", name = \"%s\",\n", self.lastname or "", self.name or ""))
    f:write(format("\tclass = \"%s\",\n", self.class or ""))
    f:write(format("\tspecial = \"%s\",\n", self.special or ""))

	-- Évaluations
	f:write("\tevaluations = {\n")
	if self.evaluations then
		for n = 1, #self.evaluations do
			self.evaluations[n]:write(f)
		end
	end
	f:write("\t},\n")

	-- Moyennes
	f:write("\treports = {\n")
	if self.reports then
		for n = 1, #self.reports do
			self.reports[n]:write(f)
		end
	end
	f:write("\t},\n")

	f:write("}\n")
end

--- Ajout d’une évaluation d’un élève
-- @param o (table) - les paramètres de l’évaluation
function Student:addeval (o)
    table.insert(self.evaluations, Eval:new(o))
end

--- Récupère l’évaluation ayant l’identifiant donné
-- @param id (string) - identifiant de l’évaluation a récupérer
-- @return eval (Eval) - l’évaluation trouvée
function Student:geteval (id)
    local eval = nil
    for n = 1, #self.evaluations do
        if self.evaluations[n].id and self.evaluations[n].id == id then
            eval = self.evaluations[n]
        end
    end
    return eval
end

--- Ajout d’une moyenne trimestrielle à la liste des moyennes de l’élève
-- @param o (table) - les paramètres de la moyenne trimestrielle à ajouter
function Student:addreport (o)
    table.insert(self.reports, Report:new(o))
end

--- Vérifie si l’élève est dans la classe demandée.
-- @param class
function Student:isinclass (class)
    return self.class == class
end

--- Modifie la note moyenne du trimestre demandé
-- @param quarter (string) - trimestre
-- @param grades (string) - notes (de la forme "1AA2BBC...")
function Student:setquarter_mean (quarter, grades_string)
    local report_found = nil
    local grades = Grades:new(grades_string)
    grades = grades:getmean() -- la moyenne trimestrielle doit être une moyenne !

    for n = 1, #self.reports do
        if self.reports[n].quarter and self.reports[n].quarter == quarter then
            report_found = true
            self.reports[n].grades = grades
        end
    end

    -- Le bilan trimestriel n’existe pas encore
    if not report_found then
        self:addreport{quarter = quarter, grades = grades:tostring()}
    end
end

--- Renvoie la note moyenne du trimestre demandé
-- @param quarter (string) - trimestre
-- @return q_grades (Grades) - somme de toutes les notes
function Student:getquarter_mean (quarter)
    for n = 1, #self.reports do
        if self.reports[n].quarter and self.reports[n].quarter == quarter then
            return self.reports[n].grades
        end
    end
    return nil -- Pas trouvé
end

--- Renvoie la somme de toutes les notes du trimestre demandé
-- @param quarter (string) - trimestre
-- @return q_grades (Grades) - somme de toutes les notes
function Student:getquarter_grades (quarter)
    local q_grades = Grades:new()
    for n = 1, #self.evaluations do
        if self.evaluations[n].quarter and self.evaluations[n].quarter == quarter then
            q_grades = q_grades + self.evaluations[n].grades
        end
    end

    return q_grades
end

--- DEBUG
-- TODO : à terminer
function Student:print ()
    print("Nom : ", self.lastname, "Prénom : ", self.name)
    print("Classe : ", self.class)
    print("Spécial : ", self.special)
   --  for n = 1, #self.evaluations do
   --      self.evaluations[n]:print()
   --  end
   --  for n = 1, #self.reports do
   --      self.reports[n]:print()
   --  end
end

--------------------------------------------------------------------------------
-- Base de données
--------------------------------------------------------------------------------

M.Database = {
    students = {}, -- liste des élèves
    classes = {}, -- liste des classes
}

--- Création d’une nouvelle Database.
-- @return o (Database) - la nouvelle base de donnée
function M.Database:new ()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

--- Lecture de la base de données depuis un fichier.
-- Chaque entrée du fichier est sous la forme :
-- entry{...}
-- et correspond à un élève.
-- @param filename (string) - le nom du fichier de la base de données
function M.Database:read (filename)
    -- TODO tester l'existence du fichier (avec lua filesystem)

    function entry (o)
        self:addstudent(o)
    end

    dofile(filename)
end

--- Écriture de la base de données vers un fichier.
-- @param filename (string) - le nom du fichier de la base de données
function M.Database:write (filename)
    -- TODO tester l'existence du fichier (avec lua filesystem)
    -- et renvoyer une erreur ?
    f = assert(io.open(filename, "w"))

    for n = 1, #self.students do
        self.students[n]:write(f)
    end
    f:flush()
end

--- DEBUG
-- TODO : à terminer
function M.Database:print ()

    for n = 1, #self.students do
        self.students[n]:print()
    end
end

--- Ajout d’un élève à la base de données.
-- @param o (table) - table contenant les attributs de l’élève
function M.Database:addstudent (o)
    table.insert(self.students, Student:new(o))
end

--- Ajout d’une classe à la liste des classes en cours d’utilisation.
-- @param class (string) - le nom de la classe
function M.Database:addclass (class)
    if not class then return end
    local found = nil
    for n = 1, #self.classes do
        if (class == self.classes[n]) then
            found = true
            break
        end
    end
    if not found then table.insert(self.classes, class) end
end

--- Test si une classe existe déjà dans la base de données.
-- @param class (string) - le nom de la classe
-- @return (bool)
function M.Database:classexists (class)
    for n = 1, #self.classes do
        if (class == self.classes[n]) then
            return true
        end
    end
    return false
end

--- Renvoie la liste des classes de la base de données
-- @return classes (table) - liste des classes
function M.Database:getclass_list ()
    local classes = {}
    local hash = {}

    for n = 1, #self.students do
        local class = self.students[n].class
        if not hash[class] then
            table.insert(classes, class)
            hash[class] = true
        end
    end

    return classes
end

--- Renvoie la liste des évaluation de la base de données
-- @return evals (table) - liste des évaluations
-- TODO paramètres class et quarter pour se limiter aux evals correspondantes
function M.Database:geteval_list ()
    local evals = {}

    for n = 1, #self.students do
        assert(self.students[n].evaluations, "geteval_list () : élève sans liste d’évaluations")
        for k = 1, #self.students[n].evaluations do
            local eval = self.students[n].evaluations[k]
            assert(eval.id, "geteval_list () : évaluation sans identifiant")
            local id = eval.id
            if not evals[id] then
                evals[id] = {number = eval.number, title = eval.title, quarter = eval.quarter}
            end
        end
    end

    return evals
end

--- Tri de la base de données.
function M.Database:sort ()
	table.sort(self.students, sort_students_byclassname)

    for n = 1, #self.students do
        table.sort(self.students[n].evaluations, sort_evals_bydate)
        table.sort(self.students[n].reports, sort_reports_byquarter)
    end
end

return M
