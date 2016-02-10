#! /usr/bin/lua5.3

-- TODO: 
-- [] classes : ajout des classes à la liste
-- [] évaluations : ajout des évaluations à la liste

local libdir = os.getenv("HOME") .. "/lib/lua"
package.path = package.path .. ";" .. libdir .. "/?"
package.path = package.path .. ";" .. libdir .. "/?.lua"                                                                             

helpers = require("helpers")

M = {}

-- Quelques raccourcis.
local find, match, format = string.find, string.match, string.format
local stripaccents = helpers.stripAccents

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

--- Fonction de tri des élèves par classe puis par nom.
-- Les lettres accentuées sont remplacées par leur équivalent non accentué
local function sort_students_byclassname (a, b)
	return stripaccents(a.class) .. stripaccents(a.lastname) .. stripaccents(a.name)
		< stripaccents(b.class) .. stripaccents(b.lastname) .. stripaccents(b.name)
end

--- Fonction de tri des évaluations par date.
local function sort_evals_bydate (a, b)
	return a.date < b.date
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
            if evals[n].quarter and evalss[n].quarter == quarter then
                return n
            end
        end
    end
end
local evals_in_quarter = M.evals_in_quarter

--------------------------------------------------------------------------------
-- Moyennes
--------------------------------------------------------------------------------

M.Mean = {
    -- quarter = "1",
    -- grades = Grades,
    -- score = "12",
}

local Mean = M.Mean

--- Création d’une nouvelle moyenne.
-- @param o - table contenant les attributs de la moyenne
function M.Mean:create (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

--- Écriture d’une moyenne dans la base de données.
-- @param f (file) - fichier ouvert en écriture
function M.Mean:write (f)
    f:write("\t\t{")
    f:write(format("quarter = \"%s\", ", self.quarter or ""))
    f:write(format("grades = \"%s\", ", self.grades or ""))
    f:write(format("score = \"%s\", ", self.score or ""))
    f:write("},\n")
end

--------------------------------------------------------------------------------
-- Évaluations
--------------------------------------------------------------------------------

M.EvalResult = {
    -- name = "Évaluation n° 3",
    -- date = "01/01/2001",
    -- quarter = "1",
    -- grades = Grades,
}

local EvalResult = M.EvalResult

--- Création d’une nouvelle évaluation.
-- @param o - table contenant les attributs de l’évaluation
function M.EvalResult:create (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

--- Écriture d’une évaluation dans la base de données.
-- @param f (file) - fichier ouvert en écriture
function M.EvalResult:write (f)
    f:write("\t\t{")
    f:write(format("name = \"%s\", ", self.name or ""))
    f:write(format("date = \"%s\", ", self.date or ""))
    f:write(format("quarter = \"%s\", ", self.quarter or ""))
    f:write(format("grades = \"%s\", ", self.grades or ""))
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
    -- evaluations = {EvalResult, ...},
    -- means = {Mean, ...}
}

local Student = M.Student

--- Création d’un nouvel élève.
-- @param o - table contenant les attributs de l’élève
function M.Student:create (o)
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
	f:write("\tmeans = {\n")
	if self.means then
		for n = 1, #self.means do
			self.means[n]:write(f)
		end
	end
	f:write("\t},\n")

	f:write("}\n")
end

--- Vérifie si l’élève est dans la classe demandée.
-- @param class
function M.Student:isinclass (class)
    return self.class == class
end

--------------------------------------------------------------------------------
-- Base de données
--------------------------------------------------------------------------------

M.Database = {
    students = {}, -- liste des élèves
    classes = {}, -- liste des classes
}
M.Database.__index = M.Database

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
    local student = Student:create{lastname = o.lastname,
        name = o.name,
        class = o.class,
        special = o.special or ""}

    -- Ajout des évals
    if type(o.evaluations) == "table" then
        student.evaluations = student.evaluations or {}
        for i = 1, #o.evaluations do
            local eval
            if type(o.evaluations[i]) == "table" then
                if o.evaluations[i].date and o.evaluations[i].quarter then -- date, trimestre obligatoires
                    eval = EvalResult:create{name = o.evaluations[i].name or "",
                        date = o.evaluations[i].date,
                        quarter = o.evaluations[i].quarter,
                        grades = o.evaluations[i].grades or ""}
                else
                    io.write(format("Erreur de lecture : évaluation sans date ou trimestre [%s %s %s]\n",
                        student.name, student.lastname, student.class))
                end
            else
                io.write(format("Erreur de lecture : l’évaluation doit être une table [%s %s %s]\n",
                    student.name, student.lastname, student.class))
            end
            table.insert(student.evaluations, eval)
        end
    else
        io.write(format("Erreur de lecture : la liste des évaluations doit être une table [%s %s %s]\n",
            student.name, student.lastname, student.class))
    end

    -- Ajout des moyennes
    if type(o.means) == "table" then
        student.means = student.means or {}
        for i = 1, #o.means do
            local mean
            if type(o.means[i]) == "table" then
                if o.means[i].quarter then -- trimestre obligatoire
                    mean = Mean:create{quarter = o.means[i].quarter,
                        grades = o.means[i].grades or "",
                        score = o.means[i].score or ""}
                else
                    io.write(format("Erreur de lecture : moyenne sans trimestre [%s %s %s]\n",
                        student.name, student.lastname, student.class))
                end
            else
                io.write(format("Erreur de lecture : la moyenne doit être une table [%s %s %s]\n",
                    student.name, student.lastname, student.class))
            end
            table.insert(student.means, mean)
        end
    else
        io.write(format("Erreur de lecture : la liste des moyennes doit être une table [%s %s %s]\n",
            student.name, student.lastname, student.class))
    end

    return student
end


--- Création d’une nouvelle Database.
function M.Database.create ()
    local self = setmetatable({}, Database)
    return self
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
