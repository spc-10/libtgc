#! /usr/bin/lua5.3

--[[
Copyright 2015 Diss Romain. All Rights Reserved.

TODO :
 - License
 - Gestion des élèves et des controles à part (entry avec type = ...)

Ce programme est une tentative de gestion des compétence.

@author Romain Diss
@copyright 2015
@license TODO

--]]

-- Variable "globales"
local students = {}
local filename

local MAX_COMP = 7

local grade_to_score = {A = 10, B = 7, C = 3, D = 0}

--- Affichage d’un élève
-- @param s table correspondant à un élève
local function log_entry (s)
  local name = s.name or "Inconnu"
  local lastname = s.lastname or "Inconnu"

  print(lastname .. " " .. name)
end

--- Critère de tri d’un élève
-- @param a élève a
-- @param b élève b
local function sort_students (a, b)
    return a.class .. a.lastname .. a.name < b.class .. b.lastname .. b.name
end

--- Ajout d’un élève à la base de données
-- TODO Vérifier si la table contient les données nécessaires
-- @param s table élève
local function add_student (s)
    table.insert(students, s)
end

--- Écriture de la table d’un élève
-- TODO Vérifier si la copie fonctionne avant d'enregistrer définitivement.
-- TODO Faire la copie une seule fois
-- @param s table élève
local function write_student (s)
    f:write("entry{\n")
    f:write("\tlastname = \"", s.lastname, "\", name = \"", s.name, "\",\n")
    if s.class then f:write("\tclass = \"", s.class, "\",\n") end
    if s.remark then f:write("\tremark = \"", s.remark, "\",\n") end
    f:write("\tevaluations = {\n")
    if s.evaluations then
        for n = 1, #s.evaluations do
            f:write("\t\t{name = \"", s.evaluations[n].name, "\", ")
            f:write("date = \"", s.evaluations[n].date, "\", ")
            f:write("quarter = \"", s.evaluations[n].quarter, "\", ")
            f:write("grades = \"", s.evaluations[n].grades, "\"},\n")
        end
    end
    f:write("\t},\n")
    f:write("\tmeans = {")
    for n = 1, 3 do
        if s.means[n] then
            f:write("[", n, "] = \"", s.means[n], "\", ")
        else
            f:write("[", n, "] = \"\", ")
        end
    end
    f:write("\t},\n")
    f:write("}\n")
end

--- Écriture de la base de données des élèves
local function write_students ()
    assert(os.rename(filename, filename .. os.time()))
    f = assert(io.open(filename, "w"))

    -- On trie d’abord les élèves
    table.sort(students, sort_students)

    for n = 1, #students do
        write_student(students[n])
    end

    assert(f:close())
end

--- Estime la note chiffrée moyenne du trimestre
-- @param grades les notes moyennes du trimestre (sous la forme "1A2B3C4D")
-- @param score_max
-- @return note moyenne
local function quarter_score (grades, score_max)
    local score_max = score_max or 20

    local total_score = 0
    local grades_nb = 0

    if not grades then return nil end

    for s in string.gmatch(grades, "[1234567][AaBbCcDd]") do
        total_score = total_score + grade_to_score[string.upper(s:sub(2))]
        grades_nb = grades_nb + 1
    end
    return math.ceil(total_score / grades_nb / 10 * score_max)
end

--- Estime les notes moyennes du trimestre.
-- @param quarter_grades table contenant les notes d'un trimestre par
-- compétence.
local function estimate_mean (quarter_grades)
    local estimation = ""
    if not quarter_grades then return "" end

    for n = 1, MAX_COMP do
        if quarter_grades[n] then
            local total_score = 0
            local mean_score
            local grades_nb = 0
            for s in string.gmatch(quarter_grades[n], "[AaBbCcDd]") do
                total_score = total_score + grade_to_score[s:upper()]
                grades_nb = grades_nb + 1
            end
            mean_score = total_score / grades_nb
            
            -- Conversion au fealing (AAB -> A, CDD -> C)
            if mean_score >= 9 then estimation = estimation .. n .. "A"
            elseif mean_score > 5 then estimation = estimation .. n .. "B"
            elseif mean_score >= 1 then estimation = estimation .. n .. "C"
            else estimation = estimation .. n .. "D"
            end
        end
    end
    return estimation
end

--- Affiche l’estimation de la moyenne des notes pour le trimestre.
-- @param quarter_grades table contenant les notes d'un trimestre par
-- compétence.
local function print_estimated_mean (quarter_grades)
    if not quarter_grades then return end

    estimation = estimate_mean(quarter_grades)
    print ("Bilan suggéré : " .. estimation .. "\t(" .. quarter_score(estimation) .. "/20)")
end

--- Affiche les notes du trimestre à partir d’une table de notes du trimestre
--!.
-- @param quarter_grades table contenant les notes d'un trimestre par
-- compétence.
local function print_quarter_grades (quarter_grades)
    if not quarter_grades then print("Pas de notes ce trimestre") return end

    for n = 1, MAX_COMP do
        if quarter_grades[n] then
            print (n .. " : " .. quarter_grades[n])
        else
            print (n .. " : -")
        end
    end
end

--- Crée une table des notes du trimestre pour chaque compétence à partir des
--- notes de chaque éval.
-- @param evals la table des évaluations de l’élève
-- @param q le numéro du trimestre
-- @return quarter_grades table des notes du trimestre
local function get_quarter_grades (evals, q)
    local quarter_grades = {}
    if not evals then return nil end

    for n = 1, #evals do
        if evals[n].quarter == tostring(q) then
            for g in string.gmatch(evals[n].grades, "[1234567][AaBbCcDd]+%**") do
                local comp_nb, comp_grades
                comp_nb = tonumber(g:sub(1,1))
                comp_grades = g:sub(2)
                if quarter_grades[comp_nb] then
                    quarter_grades[comp_nb] = quarter_grades[comp_nb] .. comp_grades
                else
                    quarter_grades[comp_nb] = comp_grades
                end
            end
        end
    end
    return quarter_grades
end

--- Lecture d’une série de notes sur l’entrée standard.
-- Les notes sont de la forme 1a2b3c4d.
-- @param type "eval" ou "mean" selon qu’on souhaite entrer une note
--   d’évaluation ou la moyenne du trimestre. Défaut : eval
-- @return grades
local function read_grades (type)
    local tmpgrades
    local grades

    type = type or "eval"
    tmpgrades = io.read()

    if type == "mean" then
        for g in string.gmatch(tmpgrades, "[1234567][AaBbCcDd]") do
            if not grades then grades = g:upper() else grades = grades .. g:upper() end
        end
    else
        for g in string.gmatch(tmpgrades, "[1234567][AaBbCcDd]+%**") do
            if not grades then grades = g:upper() else grades = grades .. g:upper() end
        end
    end

    return grades or ""
end

--- Menu ajout d’élèves.
-- Demande les informations nécessaire pour ajouter un ou plusieurs élèves
-- d’une classe à la base de données
-- TODO Vérifier si la table contient les données nécessaires
local function menu_add_student ()
    local class
    local lastname, name, remark
    local n = 1

    local student = {}

    print("Quel est le nom de la classe (exemple : 4e3) ?")

    class = io.read()

    print("Entrez un élève par ligne en respectant la syntaxe suivante :")
    print("Nom, Prénom, Remarque sur la dyslexie ou un PAI")
    print("Pour finir l’enregistrement, entrez une ligne vide")
    repeat
        line = io.read()
        n = n + 1
        lastname, name, remark = string.match(line, "^(%a+-*%a+)%s*,%s*(%a+-*%a+)%s*,*%s*(.*)$")
        remark = remark or ""
        if lastname and name then
            student = {
                lastname = lastname,
                name = name,
                class = class,
                remark = remark
            }
            add_student(student)
            -- print("Nom : " .. lastname .. "\t Prénom : " .. name .. "\t Remarque : " .. remark)
        end
    until line == ""
end

--- Menu pour ajouter une évaluation
local function menu_add_eval ()
    local nb_eval_added = 0
    local class, name, date, quarter
    
    -- On trie d’abord les élèves
    -- TODO vérifier si c’est nécessaire pour optimiser
    table.sort(students, sort_students)

    -- TODO Gérer les valeurs par défaut
    print("Quel est le nom de la classe (exemple : 4e3) ?")
    class = io.read()
    print("Quel est le titre de l’évaluation (défaut : Évaluation) ?")
    name = io.read()
    if name == "" then name = "Évaluation" end
    print("Quel est la date de l’évaluation ?")
    date = io.read()
    print("Trimestre concerné (défaut : 1) ?")
    quarter = io.read()
    if not (quarter == 1 or quarter == 2 or quarter == 3) then quarter = 1 end

    print("Entrez les notes de l’élève sous la forme : 1a2b3ca4ba*")
    print("où le nombre indique le numéro de la compétence et la lettre la note")

    for n = 1, #students do
        -- On n’ajoute l’éval que dans la classe concernée
        if students[n].class == class then
            local grades
            local eval = {}
            print(students[n].lastname, students[n].name)

            grades = read_grades("eval")

            eval = {
                name = name,
                date = date,
                quarter = quarter,
                grades = grades
            }
            -- On ajoute l’éval à la table de l’élève
            students[n].evaluations = students[n].evaluations or {}
            table.insert(students[n].evaluations, eval)
            --print(students[n].evaluations[1].grades)

            nb_eval_added = nb_eval_added + 1
        end
    end

    if nb_eval_added == 0 then
        print("Aucun élève trouvé dans la classe ", class, ".")
    else
        print("Ajout de ", nb_eval_added, " notes.")
    end
end

--- Menu pour remplir le bilan des compétences
local function menu_add_mean ()
    local nb_mean_added = 0
    local class, quarter
    
    -- On trie d’abord les élèves
    -- TODO vérifier si c’est nécessaire pour optimiser
    table.sort(students, sort_students)

    -- TODO Gérer les valeurs par défaut
    print("Quel est le nom de la classe (exemple : 4e3) ?")
    class = io.read()
    print("Trimestre concerné ?")
    quarter = io.read()
    if not (quarter == 1 or quarter == 2 or quarter == 3) then quarter = 1 end

    print("Entrez les notes de l’élève sous la forme : 1a2b3a4b...")
    print("où le nombre indique le numéro de la compétence et la lettre la note")

    for n = 1, #students do
        -- On n’ajoute la compétence que dans la classe concernée
        if students[n].class == class then
            local mean = {}
            local grades, quarter_grades
            print(students[n].lastname, students[n].name)
            -- Afficher toutes les notes pour pouvoir déterminer la moyenne
            quarter_grades = get_quarter_grades(students[n].evaluations, quarter)
            print_quarter_grades(quarter_grades)
            -- Afficher les moyennes si elles existent déjà
            if students[n].means[quarter] ~= "" then
                print("Laisser vide pour garder la moyenne actuelle : " .. students[n].means[quarter]
                    .. "\t(" .. quarter_score(students[n].means[quarter]) .. "/20)")
            end
            -- Afficher une suggestion pour la moyenne
            print_estimated_mean(quarter_grades)

            grades = read_grades("mean")

            -- On ajoute les moyennes à la table de l’élève
            -- Si l’utilisateur a laissé la ligne vide, on ne change rien
            students[n].means = students[n].means or {}
            if grades ~= "" then
                students[n].means[quarter] = grades
            end
        end
    end

end

--- Menu principal.
-- Demande à l’utilisateur les actions souhaitées
local function main_menu()
    repeat
        print([[Que voulez-vous faire ?
    (1) Ajouter des élèves d’une classe
    (2) Ajouter une évaluation
    (3) Bilan des compétences
    (q) Quitter]])
        line = io.read()

        if (line == "1") then
            menu_add_student()
        elseif (line == "2") then
            menu_add_eval()
        elseif (line == "3") then
            menu_add_mean()
        end
    until line == "q" or line == "Q"
end

-- Lecture du fichier de données
-- TODO Vérifier si le fichier existe
-- TODO Ajouter la possibilité de partir d’un fichier vide
filename = arg[1]
if (not filename) then error ("Aucun fichier spécifié") end
entry = add_student
dofile(filename)

main_menu()

write_students()

--for n = 1, #students do
--  log_entry(students[n])
--end
