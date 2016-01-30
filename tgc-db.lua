-- TGC
-- Module Database

DEFAULT_DB_FILE = "" -- TODO


Database = {
    students = {}
}
Database.__index = Database


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
function Database.create ()
    local self = setmetatable({}, Database)
    return self
end


--- Lecture de la base de données depuis un fichier.
-- Chaque entrée du fichier est sous la forme :
-- entry{...}
-- @param file - le nom du fichier de la base de données
function Database:read (file)
    file = file or DEFAULT_DB_FILE

    -- TODO tester l'existence du fichier
    
    function entry (o)
        local student = readstudent(o)
        table.insert(self.students, student)
    end
    dofile(file)

    print("Database : " .. #self.students .. " élèves lus.")
end

