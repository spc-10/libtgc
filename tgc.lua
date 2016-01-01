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

local nb_students = 0

local default_class
local default_date
local default_quarter = 1

local MAX_COMP = 7

local grade_to_score = {A = 10, B = 7, C = 3, D = 0}

local competence = {
    {name = "Langage scientifique"},
    {name = "Compréhension et application"},
    {name = "Raisonnement"},
    {name = "Outils scientifiques"},
    {name = "Aptitudes expérimentales"},
    {name = "Travail, Autonomie"},
    {name = "Respect des règles"},
}

--- Critère de tri d’un élève
-- @param a élève a
-- @param b élève b
local function sort_students (a, b)
    return a.class .. a.lastname .. a.name < b.class .. b.lastname .. b.name
end

--- Détermine le nom de la photo d’un élève.
-- @param lastname Le nom de l’élève
-- @param name Le prénom de l’élève
-- @param class La classe de l’élève
-- @param dir Le répertoire racine des photos
function picturename (name, lastname, class, dir)
    dir = dir or "/home/roms/boulot/college/eleves/2015-2016/trombines"
    name = string.gsub(name:lower(), "^%a", string.upper)
    return dir .. "/" .. class .. "/" .. lastname:upper() .. " " .. name -- .. ".jpg"
end

--- Ajout d’un élève à la base de données
-- TODO Vérifier si la table contient les données nécessaires
-- @param s table élève
local function add_student (s)
    table.insert(students, s)
    nb_students = nb_students + 1
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
        if s.means and s.means[n] then
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

    print("Fichier sauvegardé (" .. #students .. " élèves)")

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

--- Lit le nom d’une classe sur l’entrée standard.
-- @return class Le nom de la classe
local function read_class ()
    local class
    local default_string

    if default_class then default_string = " (défaut : " .. default_class .. ")" else default_string = "" end
    repeat
        print("Quel est le nom de la classe" .. default_string .. " ?")
        class = io.read() or ""
        if class == "" and default_class then class = default_class end
    until class ~= ""
    -- Enregistrer la classe comme valeur par défaut pour le prochain usage
    default_class = class

    return class
end

--- Lit une date sur l’entrée standard
-- @return date La date
local function read_date ()
    local date
    local default_string

    if default_date then default_string = " (défaut : " .. default_date .. ")" else default_string = "" end
    repeat
        print("Quel est la date de l’évaluation au format jj/mm/aaaa" .. default_string .. " ?")
        date = io.read() or ""
        -- TODO Vérifier si la date est correcte
        date = string.match(date, "(%d%d?/%d%d?/%d%d%d%d)")
        if not date and default_date then date = default_date end
    until date ~= ""
    -- Enregistrer la date comme valeur par défaut pour le prochain usage
    default_date = date

    return date
end

--- Lit un numéro de trimestre sur l’entrée standard
-- @return quarter Le numéro du trimestre
local function read_quarter ()
    local quarter
    local default_string

    if default_quarter then default_string = " (défaut : " .. default_quarter .. ")" else default_string = "" end
    repeat
        print("Quel est le trimestre" .. default_string .. " ?")
        quarter = io.read()
        quarter = tonumber(quarter)
        if not quarter and default_quarter then quarter = default_quarter end
    until quarter == 1 or quarter == 2 or quarter == 3
    -- Enregistrer le trimestre comme valeur par défaut pour le prochain usage
    default_quarter = quarter

    return quarter
end

--- Lit un ensemble de notes.
-- Le lecture concerne soit une éval (plusieurs notes possibles par
-- compétence), soit la moyenne (une seule note par compétence).
-- @param type Le type de lecture ("mean" pour la moyenne, sinon eval).
-- @return grades Note formatées correctement
local function read_grades (type)
    local tmpgrades
    local grades

    type = type or "eval"
    tmpgrades = io.read() or ""

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

--- Affichage des moyennes
-- @param class La classe à afficher
-- @param quarter Le trimestre souhaité
local function log_means (class, quarter)
    if quarter ~= 1 and quarter ~= 2 and quarter ~= 3 then print("q = ", quarter) return end

    for n = 1, #students do
        if students[n].class == class then
            io.write(students[n].lastname, " ", students[n].name, " ")
            if students[n].means[quarter] then
                io.write(quarter_score(students[n].means[quarter]), "/20 ")
                io.write(students[n].means[quarter])
            end
            io.write("\n")
        end
    end
end

--- Écriture de fiches récapitulatives des notes des élèves dans un fichier
-- ConTeXt.
-- @param class Limiter l’écriture à cette classe
-- @param quarter Limiter l’écriture à ce trimestre
-- TODO ce limiter à un élève
local function write_context_log (class, quarter)
    quarter = quarter or 1
    local o = assert(io.open(ctx_output, "w"))

    -- On trie d’abord les élèves
    table.sort(students, sort_students)

    o:write([==[
\usemodule[french]

\setuppapersize[A4,landscape]
\setupbodyfont[sans,24pt]

\definecolor[maincolor][h=31363b]
\definecolor[colorA][h=11d116]
\definecolor[colorB][colorA]
\definecolor[colorC][h=f67400]
\definecolor[colorD][h=c0392b]
\definecolor[colorT][h=bdc3c7]

\setuplayout
    [width=middle,
    height=middle,
    backspace=0.3cm,
    topspace=0.3cm,
    header=0cm,
    footer=0cm,]

\startdocument

]==])
    for n = 1, #students do
        if not class or students[n].class == class then
            local quarter_grades = get_quarter_grades(students[n].evaluations, quarter)
            local picture = picturename(students[n].name, students[n].lastname, students[n].class)
            local score
            if students[n].means[quarter] then score = quarter_score(students[n].means[quarter]) end
            o:write([==[
\startxtable
    [option=stretch,
    align={middle,lohi},
    frame=off]
    \startxrow[foregroundcolor=maincolor]]==])
            o:write("\n\t\t\\startxcell[loffset=0.7em] \\externalfigure[", picture, "][height=0.20\\textwidth] \\stopxcell\n")
            -- TODO Gérer le trimestre
            -- Afficher les longs noms sur deux lignes
            local sep
            if string.len(students[n].lastname .. students[n].name) > 15 then sep = "\\\\ " else sep = " " end
            o:write("\t\t\\startxcell {\\bfd ", students[n].lastname, sep, students[n].name, "}\\\\ 1\\ier~trimestre \\stopxcell\n")
            o:write("\t\t\\startxcell \\bfd ", string.gsub(students[n].class, "e", "\\ieme\\,"), " \\stopxcell\n")
            o:write("\t\\stopxrow\n\\stopxtable\n\n\\blank[big]\n\n")

            o:write([==[
\startxtable
    [option=stretch,
    align={middle,lohi},
    framecolor=white,
    height=3.25ex,
    toffset=.3ex]                                                                                                                ]==])
            -- Compétences
            for comp = 1, 7 do
                local mean
                if students[n].means[quarter] then
                    mean = string.match(students[n].means[quarter], comp .. "([ABCDabcd])")
                    if mean then mean = mean:upper() end
                end
                o:write("\t\\startxrow\n\t\t\\startxcell ", comp, " \\stopxcell\n")
                o:write("\t\t\\startxcell[align={right,lohi}] \\bold{", competence[comp].name, "} \\stopxcell\n")
                for m = 1, 6 do -- Affichage des 6 notes de la compétences
                    local note
                    if quarter_grades[comp] then
                        note = string.sub(quarter_grades[comp], m, m)
                        note = note:upper()
                    end
                    if note == "A" or note == "B" or note == "C" or note == "D" then
                        o:write("\t\t\\startxcell[foregroundcolor=color", note, "] ", note, " \\stopxcell\n")
                    else
                        o:write("\t\t\\startxcell \\stopxcell\n")
                    end
                end
                if mean then
                    o:write("\t\t\\startxcell[background=color,backgroundcolor=color", mean, "] ", mean, " \\stopxcell\n")
                else
                    o:write("\t\t\\startxcell[background=color,backgroundcolor=colorT] \\stopxcell\n")
                end
                o:write("\t\\stopxrow\n")
            end    
            o:write([==[
   \startxrow
        \startxcell[nx=9] \strut \stopxcell
    \stopxrow
    \startxrow
        \startxcell[nx=5] \stopxcell
        \startxcell[nx=3] Note \stopxcell
]==])
            o:write("\t\t\\startxcell[background=color,backgroundcolor=colorT] \\bfa ", score, " \\stopxcell\n")
            o:write("\t\\stopxrow\n\\stopxtable\n\n\\page\n\n")

        end
    end




    assert(o:close())
end

--- Menu ajout d’élèves.
-- Demande les informations nécessaire pour ajouter un ou plusieurs élèves
-- d’une classe à la base de données
-- TODO Vérifier si la table contient les données nécessaires
local function menu_add_student ()
    local class
    local lastname, name, remark

    local student = {}

    class = read_class()

    print("Entrez un élève par ligne en respectant la syntaxe suivante :")
    print("Nom, Prénom, Remarque sur la dyslexie ou un PAI")
    print("Pour finir l’enregistrement, entrez une ligne vide")
    repeat
        line = io.read() or ""

        lastname, name, remark = string.match(line, "^([^%s,]+)%s*,%s*([^%s,]+)%s*,*%s*(.*)$")
        if lastname and name then
            student = {
                lastname = lastname,
                name = name,
                class = class,
                remark = remark or ""
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

    class = read_class()
    print("Quel est le titre de l’évaluation ?")
    name = io.read() or ""

    date = read_date()
    quarter = read_quarter()

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
    class = read_class()
    quarter = read_quarter()

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
    local line

    repeat
        print([[Que voulez-vous faire ?
    (1) Ajouter des élèves d’une classe
    (2) Ajouter une évaluation
    (3) Ajouter le bilan des compétences
    (4) Afficher les moyennes
    (5) ConTeXt

    (9) Sauvegarde
    (q) Quitter]])
        repeat
            line = io.read()
            if not line then os.exit() end
        until line ~= ""

        if (line == "1") then
            menu_add_student()
        elseif (line == "2") then
            menu_add_eval()
        elseif (line == "3") then
            menu_add_mean()
        elseif (line == "4") then
            local class
            local quarter
            class = read_class()
            quarter = read_quarter()
            log_means(class, quarter)
        elseif (line == "5") then
            write_context_log()
        elseif (line == "9") then
            write_students()
        end
    until line == "q" or line == "Q"

    print("Voulez-vous sauvegarder avant de quitter (O/n) ?")
    line = io.read() or "n"
    if line == "O" or line == "o" or line == "" then write_students() end
end

-- Lecture du fichier de données
-- TODO Vérifier si le fichier existe
-- TODO Ajouter la possibilité de partir d’un fichier vide
filename = arg[1]
ctx_output = "tmp.tex"
if (not filename) then error ("Aucun fichier spécifié") end
entry = add_student
dofile(filename)
print("Fichier lu (" .. nb_students .. " élèves).")

-- Lancement de l’interface
main_menu()

