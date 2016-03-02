#! /usr/bin/lua5.3

-- TODO : Programmation du menu en OO et en module, voir :
-- http://lua-users.org/wiki/AsciiMenu

local libdir = os.getenv("HOME") .. "/lib/lua"
package.path = package.path .. ";" .. libdir .. "/?"
package.path = package.path .. ";" .. libdir .. "/?.lua"

tgc = require("tgc")
helpers = require("helpers")

local ask = helpers.ask

local find, gsub, format, match = string.find, string.gsub, string.format, string.match
local lower, upper = string.lower, string.upper

-- Code couleur du terminal
local term_color = {black = 0, red = 1, green = 2, yellow = 3, blue = 4,
    magenta = 5, cyan = 6, white = 7}

--- Ajoute les caractères d’échappement nécessaires à la colorisation d’une
-- chaîne de caractère.
-- @param s (string) - chaîne à coloriser
-- @return (string) - chaîne avec échappement adaptés à la couleur souhaitée
local function color (s, foreground, background, bold)
    local fg = term_color[foreground] or 9
    local bg = term_color[background] or 9
    if bold then bold = ";1" else bold = "" end

    -- https://en.wikipedia.org/wiki/ANSI_escape_code
    return "\027[" .. 30 + fg .. ";" .. 40 + bg .. bold .. "m" .. s .. "\027[0m"
end

--- Colore les notes (A en vert, B aussi, C en jaune et D en rouge).
-- @param s (string) - notes à coloriser
-- @return s (string) - les notes avec échappements pour les couleurs
local function grades_color (s)
    s = s or ""

    s = gsub(s, "A", color("A", "green"))
    s = gsub(s, "B", color("B", "green"))
    s = gsub(s, "C", color("C", "yellow"))
    s = gsub(s, "D", color("D", "red"))

    return s
end

--- Ajout d’un élève à la base de données.
-- Récupère les informations entrées au clavier par l’utilisateur pour créer un
-- nouvel élève dans la base de données.
local function add_student_menu ()
    local class_list = database:getclass_list()
    local class = ask("Quelle est la classe de l’élève ?", nil, class_list)

    io.write("Entrez un élève par ligne (CTRL-D ou vide pour arrêter)\n")
    while true do
        local answer = ask("Nom, Prénom :")
        if answer == "" then return
        else
			lastname, name = string.match(answer, "^%s*([^,]+)%s*,%s*([^,]+)%s*$")
			if lastname and name then
				database:addstudent{lastname = lastname, name = name, class = class}
                database_changed = true
			else
				io.write("Erreur de syntaxe -> ")
			end
        end
    end
end

--- Ajout d’une évaluation à la base de données.
-- Récupère les informations entrées au clavier par l’utilisateur pour créer
-- une nouvelle évaluation pour une classe dans la base de données.
-- TODO
local function add_eval_menu ()
    local class = ask("Quelle est la classe de l’élève ?", nil, database:getclass_list())
    local quarter = ask("Quel est le trimestre ?", nil, {"1", "2", "3"}, true)
    local id = ask("Quel est l’identifiant de l’évaluation ?")
    -- On cherche des propositions de titre et numéro dans la liste des évals
    eval_list = database:geteval_list()
    number = eval_list[id] and eval_list[id].number or nil
    title = eval_list[id] and eval_list[id].title or nil
    local number = ask("Quel est le numéro de l’évaluation ?", number)
    local title = ask("Quel est le titre de l’évaluation ?", title)
    local date
    repeat -- TODO vérifier le format de la date plus précisément ?
        date = ask("Quel est la date de l’évaluation (format AAAA-MM-JJ) ?") or ""
    until match(date, "%d%d%d%d%-%d%d%-%d%d")
    -- TODO vérifier le format ?
    local mask = ask("Compétences évaluées (laisser vide pour entrer les notes complètes) ?")

    -- Parcours des élèves
    for n =1, #database.students do
        if database.students[n].class == class then
            local student = database.students[n]
            io.write(format("%s %s\n", student.lastname, student.name))

            -- On vérifie si l’éval existe déjà
            eval = student:geteval(id)
            local actual_grades = eval and eval.grades

            -- Modification/ajout de la note
            local question = "Notes de l’évaluations"
            if mask ~= "" then question = question .. " (" .. mask .. ") ?"
            else question = question .. " ?"
            end
            local grades_s = ask(question, actual_grades and actual_grades:tostring() or nil)
            -- TODO Gestion d’un masque
            if grades_s ~= "" then -- la note a été modifiée
                -- Application du masque
                if mask ~= "" then grades_s = tgc.grades_unmask(grades_s, mask) end

                if eval then -- l’éval existe déjà
                   eval:setgrades(grades_s)
                else -- création de l’éval
                    student:addeval{id = id, number = number, title = title,
                        quarter = quarter, date = date, grades = grades_s}
                end
                io.write(format("DEBUG - Nouvelle note : %s\n", grades_s))
                database_changed = true
            end
        end
    end
end

--- Ajout d’une moyenne à la base de données.
-- Récupère les informations entrées au clavier par l’utilisateur pour créer
-- une nouvelle moyenne des élèves d’une classe dans la base de données.
-- Plusieurs informations sont calculées et affichées pour aider la saisie.
local function add_report_menu ()
    local class = ask("Quelle est la classe de l’élève ?", nil, database:getclass_list(), true)
    local quarter = ask("Quel est le trimestre ?", nil, {"1", "2", "3"}, true)

    -- Parcours des élèves
    for n =1, #database.students do
        if database.students[n].class == class then
            local student = database.students[n]

            -- Affichage des infos nécessaires pour déterminer la moyenne de l’élève
            local actual_q_mean = student:getquarter_mean(quarter) -- Moyenne actuelle
            local quarter_grades = student:getquarter_grades(quarter) -- Toutes les notes du trimestre
            local suggested_q_mean = quarter_grades:getmean() -- Moyenne suggérée

            io.write(format("%s %s\n", student.lastname, student.name))
            io.write(format(" - toutes les notes du trimestre : %s\n", grades_color(quarter_grades:tostring("  "))))
            io.write(format(" - bilan calculé : %s → [%s/20]\n",
                grades_color(suggested_q_mean:tostring("  ")), suggested_q_mean:getscore()))
            if actual_q_mean then
                io.write(format(" - bilan actuel : %s → [%s/20]\n",
                grades_color(actual_q_mean:tostring("  ")), actual_q_mean:getscore()))
            else
                io.write(" - pas encore de moyenne\n")
            end

            -- Modification de la moyenne trimestrielle
            local grades_s = ask("Nouvelle moyenne du trimestre :",
                actual_q_mean and actual_q_mean:tostring() or suggested_q_mean:tostring() or nil)
            if not actual_q_mean or grades_s ~= actual_q_mean:tostring() then -- La note a été changée
                database_changed = true
                student:setquarter_mean(quarter, grades_s)
            end
        end
    end
end

--- Ajout d’une note chiffrée à la base de données.
-- TODO
local function add_score_menu ()
    print("TODO")
end

--- Sauvegarde de la base de données
local function save_database ()
    --database_changed = true --DEBUG
    if database_changed then
        -- On trie d’abord la base de données
        io.write("Tri de la base de données...")
        database:sort()
        io.write(" OK\n")

        database:write(svg_filename)
        database_changed = false
        io.write(format("Base de données sauvegardée dans : %s\n", svg_filename))
    else
        io.write("Aucun changement depuis la dernière sauvegarde.\n")
    end

end

--- Arrêt du programme
local function quit ()
    -- Sauvegarde de la base de données si elle a été modifiée
    if database_changed then
        answer = ask("La base de données a été modifiée. Voulez-vous l’enregistrer ?", "o", {"o", "n"}, true)
        if answer == "o" then
            save_database()
        end
    end

    os.exit()
end

-- Entrées du menu principal
local MAIN_MENU = {
    -- "touche du clavier", "Menu à afficher", fonction à lancer}
    {title = "Ajouter un élève", f = add_student_menu},
    {title = "Ajouter une évaluation", f = add_eval_menu},
    {title = "Ajouter une moyenne", f = add_report_menu},
    {title = "Ajouter une note chiffrée", f = add_score_menu},
    {title = "Sauvegarder la base de données", f = save_database},
}

--- Menu principal
local function menu ()
    local selection = nil

    while true do
        -- Affichage du menu
        local menu_options = {}
        io.write("\n")
        for i = 1, #MAIN_MENU do
            io.write("  ", i, ". ", MAIN_MENU[i].title, "\n")
            menu_options[#menu_options + 1] = tostring(i) -- Ajout des choix de menu
        end
        io.write("\n  Q. Quitter\n")
        menu_options[#menu_options + 1] = "q" -- Ajout des choix de menu

        -- Lecture de la selection
        selection = ask("Votre choix : ", nil, menu_options, true)

        -- Application de la sélection
        if not selection or selection == menu_options[#menu_options] then -- dernière option = quitter
            quit()
        end
        selection = tonumber(selection)
        if selection and MAIN_MENU[selection] then
            MAIN_MENU[selection].f()
        else
            io.write("Selection non valide\n")
        end
    end
end

--- Fonction principale.
local function main ()
    local filename = arg[1]
    assert(filename, "Aucun fichier spécifié")
    svg_filename = filename .. os.time()

    database = tgc.Database:new()
    database:read(filename)
    database_changed = false

    -- On démarre ici...
    menu()
end

-- Démarrage
main()
