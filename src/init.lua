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
  

Student = require("tgc.student")
utils = require("tgc.utils")

local M = {}

--------------------------------------------------------------------------------
--- Comparison function to use with table.sort().
--
-- It sorts the students by class, then by lastname and finally by name.
-- Accentuated letters are replaced by their non-accentuated equivalent.
--------------------------------------------------------------------------------
local function sort_students_byclassname (a, b)
    local strip = utils.stripaccents
	return strip(a.class) .. strip(a.lastname) .. strip(a.name)
		< strip(b.class) .. strip(b.lastname) .. strip(b.name)
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
