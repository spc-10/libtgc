#! /usr/bin/lua5.3

-- TODO:
-- [] classes : ajout des classes à la liste
-- [] évaluations : ajout des évaluations à la liste

local libdir = os.getenv("HOME") .. "/lib/lua"
package.path = package.path .. ";" .. libdir .. "/?"
package.path = package.path .. ";" .. libdir .. "/?.lua"

helpers = require("helpers")
lpeg = require("lpeg")

M = {}

-- Constantes
local MAX_COMP = 7 -- Nombre maximal de compétences
local GRADE_TO_SCORE = {A = 10, B = 7, C = 3, D = 0}

-- Quelques raccourcis.
local find, match, format = string.find, string.match, string.format
local stripaccents = helpers.stripAccents

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

M.Grades = {
    -- 1 = "ABCDA*",
    -- 2 = "ABCDA*",
    -- 3 = "ABCDA*",
    -- ...
}
for n = 1, MAX_COMP do M.Grades[n] = "" end -- Initialisation des compétences
--M.Grades.__add = M.Grades.add

local Grades = M.Grades

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
function M.Grades:new (s)
    s = s or ""
    local o = {}
    setmetatable(o, self)
    self.__index = self
    self.__add = self.add

    -- convertit la note texte en table
    local comp_pattern_s =
        (comp_pattern / function(a,b) o[tonumber(a)] = (o[tonumber(a)] or "") .. string.upper(b) end)^1
    lpeg.match(comp_pattern_s, s)

    return o
end

--- Convertion de la note en chaîne de caractère de la "1AA2B3A*C".
-- @param sep (string) - séparateur à ajouter entre les notes des différentes
-- compétences
-- @return (string)
function M.Grades:tostring (sep)
	sep = sep or ""
    local l = {}
    for n = 1, MAX_COMP do
        if self[n] ~= "" then l[#l + 1] = tostring(n) .. tostring(self[n]) end
    end

    return table.concat(l, sep) or ""
end

--- Calcul de la moyenne de la note
-- @return res (Grades) - moyenne
function M.Grades:getmean ()
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
function M.Grades:getscore (score_max)
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
function M.Grades.add (a, b)
    return Grades:new(a:tostring() .. b:tostring())
end

--------------------------------------------------------------------------------
-- Moyennes du trimestre
--------------------------------------------------------------------------------

M.Report = {
    -- quarter = "1",
    -- grades = Grades,
    -- score = "12",
}

local Report = M.Report

--- Création d’une nouvelle moyenne.
-- @param o - table contenant les attributs de la moyenne
function M.Report:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

--- Écriture d’une moyenne dans la base de données.
-- @param f (file) - fichier ouvert en écriture
function M.Report:write (f)
    f:write("\t\t{")
    f:write(format("quarter = \"%s\", ", self.quarter or ""))
    f:write(format("grades = \"%s\", ", self.grades:tostring()))
    f:write(format("score = \"%s\", ", self.score or ""))
    f:write("},\n")
end

--------------------------------------------------------------------------------
-- Évaluations
--------------------------------------------------------------------------------

M.Eval = {
    -- name = "Évaluation n° 3",
    -- date = "01/01/2001",
    -- quarter = "1",
    -- grades = Grades,
}

local Eval = M.Eval

--- Création d’une nouvelle évaluation.
-- @param o - table contenant les attributs de l’évaluation
function M.Eval:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

--- Écriture d’une évaluation dans la base de données.
-- @param f (file) - fichier ouvert en écriture
function M.Eval:write (f)
    f:write("\t\t{")
    f:write(format("name = \"%s\", ", self.name or ""))
    f:write(format("date = \"%s\", ", self.date or ""))
    f:write(format("quarter = \"%s\", ", self.quarter or ""))
    f:write(format("grades = \"%s\", ", self.grades:tostring()))
    f:write("},\n")
end


--------------------------------------------------------------------------------
-- Élèves
--------------------------------------------------------------------------------

M.Student = {
    -- lastname = "Doe",
    -- name = "John",
    -- class = "5e1",
    -- special = "dys, pai, aménagements",
    -- evaluations = {Eval, ...},
    -- reports = {Report, ...}
}

local Student = M.Student

--- Création d’un nouvel élève.
-- @param o - table contenant les attributs de l’élève
function M.Student:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

--- Écriture d’un élève dans la base de données.
-- @param f (file) - fichier ouvert en écriture
function M.Student:write (f)
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
-- @param eval (Eval) - l’évaluation à ajouter
function M.Student:addeval (eval)
    self.evaluations = self.evaluations or {}

    table.insert(self.evaluations, eval)
end

--- Ajout d’une moyenne trimestrielle à la liste des moyennes de l’élève
-- @param report (Report) - la moyenne à ajouter
function M.Student:addreport (report)
    self.reports = self.reports or {}

    table.insert(self.reports, report)
end

--- Vérifie si l’élève est dans la classe demandée.
-- @param class
function M.Student:isinclass (class)
    return self.class == class
end

--- Renvoie la moyenne du trimestre demandé
-- @param quarter (string) - trimestre
-- @return report (Report)
function M.Student:getreport (quarter)
    if not self.reports then return nil end

    for n = 1, #self.reports do
        if self.reports[n].quarter == quarter then return self.reports[n] end
    end

    return nil -- Non trouvé

end

--------------------------------------------------------------------------------
-- Base de données
--------------------------------------------------------------------------------

M.Database = {
    students = {}, -- liste des élèves
    classes = {}, -- liste des classes
}

local Database = M.Database

--- Lecture d’un élève dans la base de donnée.
-- @param o (table) - entrée dans la base de donnée correspondant à un élève
-- @return student (Student) - objet élève lu
local function readstudent (o)
    -- Attributs de l’élève
    if not (o.lastname and o.name and o.class) then -- Nom, classe obligatoires
        io.write(format("Erreur de lecture : élève sans nom, prénom ou classe [%s %s %s].\n",
            o.lastname or "", o.name or "", o.class or ""))
        return nil -- L’élève ne sera pas ajouté
    end
    local student = Student:new{lastname = o.lastname,
        name = o.name,
        class = o.class,
        special = o.special or ""}

    -- Ajout des évals
    if type(o.evaluations) == "table" then
        for i = 1, #o.evaluations do
            local eval
            if type(o.evaluations[i]) == "table" then
                if o.evaluations[i].date and o.evaluations[i].quarter then -- date, trimestre obligatoires
                    eval = Eval:new{name = o.evaluations[i].name or "",
                        date = o.evaluations[i].date,
                        quarter = o.evaluations[i].quarter,
                        grades = Grades:new(o.evaluations[i].grades or "")}
                else
                    io.write(format("Erreur de lecture : évaluation sans date ou trimestre [%s %s %s]\n",
                        student.name, student.lastname, student.class))
                end
            else
                io.write(format("Erreur de lecture : l’évaluation doit être une table [%s %s %s]\n",
                    student.name, student.lastname, student.class))
            end
            student:addeval(eval)
        end
    else
        io.write(format("Erreur de lecture : la liste des évaluations doit être une table [%s %s %s]\n",
            student.name, student.lastname, student.class))
    end

    -- Ajout des moyennes
    if type(o.reports) == "table" then
        for i = 1, #o.reports do
            local report
            if type(o.reports[i]) == "table" then
                if o.reports[i].quarter then -- trimestre obligatoire
                    report = Report:new{quarter = o.reports[i].quarter,
                        grades = Grades:new(o.reports[i].grades or ""),
                        score = o.reports[i].score or ""}
                else
                    io.write(format("Erreur de lecture : moyenne sans trimestre [%s %s %s]\n",
                        student.name, student.lastname, student.class))
                end
            else
                io.write(format("Erreur de lecture : la moyenne doit être une table [%s %s %s]\n",
                    student.name, student.lastname, student.class))
            end
            student:addreport(report)
        end
    else
        io.write(format("Erreur de lecture : la liste des moyennes doit être une table [%s %s %s]\n",
            student.name, student.lastname, student.class))
    end

    return student
end


--- Création d’une nouvelle Database.
function M.Database:new ()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

--- Lecture de la base de données depuis un fichier.
-- Chaque entrée du fichier est sous la forme :
-- entry{...}
-- @param filename (string) - le nom du fichier de la base de données
function M.Database:read (filename)
    -- TODO tester l'existence du fichier (avec lua filesystem)

    function entry (o)
        local student = readstudent(o)
        self:addstudent(student)
    end

    dofile(filename)

    print("Database : " .. #self.students .. " élèves lus.") -- DEBUG
end

--- Écriture de la base de données vers un fichier.
-- @param filename (string) - le nom du fichier de la base de données
function M.Database:write (filename)
    -- TODO tester l'existence du fichier (avec lua filesystem)
    f = assert(io.open(filename, "w"))

    for n = 1, #self.students do
        self.students[n]:write(f)
    end
end

--- Ajout d’un élève à la base de données.
-- Chaque fois qu’un élève est ajouté à la base de données, on stocke la classe
-- concernée dans une liste
-- @param student (Student) - l’objet élève
function M.Database:addstudent (student)
    if not student then return end
    table.insert(self.students, student)
    self:addclass(student.class)
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

--- Renvoie la liste des classes correspondant aux motifs.
-- La recherche s’effectue dans la liste des classes des élèves de la base de
-- données
-- @param ... (string) - le ou les motifs de recherche du nom de la classe
-- @return classes (table) - liste des classes correspondant au motif
function M.Database:getclasses (...)
    local classes = {}

    for _i, pattern in ipairs {...} do
        if type(pattern) == "string" then
            if not find(pattern, "^%^") then pattern = "^" .. pattern end
            if not find(pattern, "%$$") then pattern = pattern .. "$" end

            for n = 1, #self.classes do
                local class = match(self.classes[n], pattern)
                if class then table.insert(classes, class) end
            end
        end -- TODO else print erreur
    end

    return classes
end

--- Tri de la base de données.
function M.Database:sort ()
	table.sort(self.students, sort_students_byclassname)

	-- TODO tri des évals et des moyennes
end

return M
