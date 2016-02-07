#! /usr/bin/lua5.3

-- TODO: 
-- [] classes : ajout des classes à la liste
-- [] évaluations : ajout des évaluations à la liste

M = {}

-- local function main()
--     filename = arg[1]
--     if (not filename) then error ("Aucun fichier spécifié") end
-- 
--     database = Database.create()
--     database:read(filename)
-- end

--------------------------------------------------------------------------------

local find, match = string.find, string.match

local DEFAULT_DB_FILE = "" -- TODO

--------------------------------------------------------------------------------
-- Moyennes
--------------------------------------------------------------------------------

M.Mean = {
    -- quarter = 1,
    -- grades = Grades,
    -- score = 12,
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

--------------------------------------------------------------------------------
-- Évaluations
--------------------------------------------------------------------------------

M.EvalResult = {
    -- name = "Évaluation n° 3",
    -- date = "01/01/2001",
    -- quarter = 1,
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


--------------------------------------------------------------------------------
-- Élèves
--------------------------------------------------------------------------------

M.Student = {
    -- lastname = "Doe",
    -- name = "John",
    -- class = "5e1",
    -- dys = "Dysorthographique",
    -- pai = "En fauteuil-roulant",
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
-- @param o - entrée dans la base de donnée correspondant à un élève
-- @return student - (Student) élève lu
local function readstudent (o)
    -- Attributs de l’élève
    if not (o.lastname and o.name and o.class) then -- Nom, classe obligatoires
        print("Database : Élève incomplet ignoré.")
        return -- TODO Gestion d'erreur
    end
    local student = Student:create{lastname = o.lastname, name = o.name, class = o.class}
    if o.pai then student.pai = o.pai end
    if o.dys then student.dys = o.dys end

    -- Ajout des évals
    if type(o.evaluations) == "table" then
        student.evaluations = student.evaluations or {}
        for i = 1, #o.evaluations do
            local eval
            if type(o.evaluations[i]) == "table" then
                eval = EvalResult:create{name = o.evaluations[i].name or ""}
                if o.evaluations[i].date then eval.date = o.evaluations[i].date end
                if o.evaluations[i].quarter then eval.quarter = o.evaluations[i].quarter end
                if o.evaluations[i].grades then eval.grades = o.evaluations[i].grades end
            else
                print("Database : évaluation erronée (" .. o.lastname .. ", " .. o.name .. ").")
            end
            table.insert(student.evaluations, eval)
        end
    end

    -- Ajout des moyennes
    if type(o.means) == "table" then
        student.means = student.means or {}
        for i = 1, #o.means do
            local mean
            if type(o.means[i]) == "table" then
                if o.means[i].quarter then -- Moyenne ignorée si pas de trimestre
                    mean = Mean:create{name = o.means[i].name or "",
                        grades = o.means[i].grades or ""}
                    if o.means[i].score then mean.score = o.means[i].score end
                else
                    print("Database : moyenne sans trimestre ignorée (" .. o.lastname .. ", " .. o.name .. ").")
                end
            else
                print("Database : moyenne erronée (" .. o.lastname .. ", " .. o.name .. ").")
            end
            table.insert(student.means, mean)
        end
    end

    return student
end


--- Création d’une nouvelle Database
function M.Database.create ()
    local self = setmetatable({}, Database)
    return self
end


--- Lecture de la base de données depuis un fichier.
-- Chaque entrée du fichier est sous la forme :
-- entry{...}
-- @param file - le nom du fichier de la base de données
function M.Database:read (file)
    file = file or DEFAULT_DB_FILE

    -- TODO tester l'existence du fichier

    function entry (o)
        local student = readstudent(o)
        table.insert(self.students, student)
        self:addclass(student.class)
    end

    dofile(file)

    print("Database : " .. #self.students .. " élèves lus.")
end

--- Ajout d’une classe à la liste des classes en cours d’utilisation.
-- Chaque fois qu’un élève est ajouté à la base de données, on stocke la classe
-- concernée dans une liste
-- @param class (string) - le nom de la classe
function M.Database:addclass (class)
    local found = nil
    for n = 1, #self.classes do
        if (class == self.classes[n]) then
            found = true
            break
        end
    end
    if not found then table.insert(self.classes, class) end
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

return M
