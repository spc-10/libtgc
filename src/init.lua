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
Competences = require("tgc.competences")
Student = require("tgc.student")

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
-- Base de données
--------------------------------------------------------------------------------

local Database = {
    students = {}, -- liste des élèves
    classes = {}, -- liste des classes
}
local Database_mt = {__index = Database}

--- Création d’une nouvelle Database.
-- @return o (Database) - la nouvelle base de donnée
function M.new ()
    local o = setmetatable({}, Database_mt)
    return o
end

--- Lecture de la base de données depuis un fichier.
-- Chaque entrée du fichier est sous la forme :
-- entry{...}
-- et correspond à un élève.
-- @param filename (string) - le nom du fichier de la base de données
function Database:read (filename)
    -- TODO tester l'existence du fichier (avec lua filesystem)

    function entry (o)
        self:addstudent(o)
    end

    dofile(filename)
end

--- Écriture de la base de données vers un fichier.
-- @param filename (string) - le nom du fichier de la base de données
function Database:write (filename)
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
function Database:print ()

    for n = 1, #self.students do
        self.students[n]:print()
    end
end

--- Ajout d’un élève à la base de données.
-- @param o (table) - table contenant les attributs de l’élève
function Database:addstudent (o)
    table.insert(self.students, Student.new(o))
end

--- Ajout d’une classe à la liste des classes en cours d’utilisation.
-- @param class (string) - le nom de la classe
function Database:addclass (class)
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
function Database:classexists (class)
    for n = 1, #self.classes do
        if (class == self.classes[n]) then
            return true
        end
    end
    return false
end

--- Renvoie la liste des classes de la base de données
-- @return classes (table) - liste des classes
function Database:getclass_list ()
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
function Database:geteval_list ()
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
function Database:sort ()
	table.sort(self.students, sort_students_byclassname)

    for n = 1, #self.students do
        table.sort(self.students[n].evaluations, sort_evals_bydate)
        table.sort(self.students[n].reports, sort_reports_byquarter)
    end
end

return M
