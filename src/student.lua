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

-- TODO:
-- [] classes : ajout des classes à la liste
-- [] évaluations : ajout des évaluations à la liste

helpers = require("helpers")
lpeg = require("lpeg")
Competences = require("tgc.competences")
Eval = require("tgc.evaluation")
Report = require("tgc.report")

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
local Student_mt = {__index = Student}

--- Création d’un nouvel élève.
-- @param o (table) - table contenant les attributs de l’élève
-- @return s (Student) - nouvel objet élève
function M.new (o)
    local s = setmetatable({}, Student_mt)

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
            table.insert(s.evaluations, Eval.new(o.evaluations[n]))
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
            table.insert(s.reports, Report.new(o.reports[n]))
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
    table.insert(self.evaluations, Eval.new(o))
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
    table.insert(self.reports, Report.new(o))
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
    local grades = Competences.new(grades_string)
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
    local q_grades = Competences.new()
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


return M
