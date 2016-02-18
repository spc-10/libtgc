#! /usr/bin/lua5.3

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
local find, match, format = string.find, string.match, string.format
local stripaccents = helpers.stripAccents
table.unique = helpers.unique

local P, S, V, R = lpeg.P, lpeg.S, lpeg.V, lpeg.R
local C, Cb, Cc, Cg, Cs, Cmt = lpeg.C, lpeg.Cb, lpeg.Cc, lpeg.Cg, lpeg.Cs, lpeg.Cmt



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

--- Fonction de tri des évaluations par date.
local function sort_evals_bydate (a, b)
	return a.quarter .. a.date < b.quarter .. b.date
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
local grade = grade_letter * star^0
local cgrade = C(grade_letter) * star^0

local comp_grades = grade^1
local comp_number = digit -- 9 compétences max pour le moment
local not_comp = 1 - comp_number * comp_grades

local comp_pattern = (not_comp)^0 * C(comp_number) * C(comp_grades) * (not_comp)^0

--- Création d’une nouvelle note.
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
				(cgrade / function(a) total_score = total_score + GRADE_TO_SCORE[a]
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

--- Ajout d’une évaluation à la liste des évaluations de l’élève
-- TODO Modifier
-- @param eval (Eval) - l’évaluation à ajouter
function Student:addeval (eval)
    self.evaluations = self.evaluations or {}

    table.insert(self.evaluations, eval)
end

--- Ajout d’une moyenne trimestrielle à la liste des moyennes de l’élève
-- @param report (Report) - la moyenne à ajouter
function Student:addreport (report)
    table.insert(self.reports, report)
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
    grades = grades:getmean()

    for n = 1, #self.reports do
        if self.reports[n].quarter and self.reports[n].quarter == quarter then
            report_found = true
            self.reports[n].grades = grades
        end
    end

    -- Le bilan trimestriel n’existe pas encore
    if not report_found then
        self:addreport(Report:new{quarter = quarter, grades = grades_string})
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

    print("Database : " .. #self.students .. " élèves lus.") -- DEBUG
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
end

--- DEBUG
function M.Database:print ()

    for n = 1, #self.students do
        print(self.students[n].name, self.students[n].lastname, self.students[n].class)
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
-- @return classes (table) - liste des classes correspondant au motif
function M.Database:getclass_list ()
    local classes = {}

    for n = 1, #self.students do
        assert(self.students[n].class, "getclass_list () : élève sans classe")
        table.insert(classes, self.students[n].class)
    end

    return table.unique(classes)
end

--- Tri de la base de données.
function M.Database:sort ()
	table.sort(self.students, sort_students_byclassname)

	-- TODO tri des évals et des moyennes
end

return M
