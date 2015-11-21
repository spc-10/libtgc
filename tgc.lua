#! /usr/bin/lua5.3

--[[
Copyright 2015 Diss Romain. All Rights Reserved.

TODO : License

Ce programme est une tentative de gestion des compétence.

@author Romain Diss
@copyright 2015
@license TODO

--]]

--- Converti une une note en points
-- TODO Utiliser une table de correspondance
-- @param grade "A", "B", "C" ou "D"
-- return score 10, 7, 3 ou 0
function grade_to_score (grade)
  if (grade == "A") then
    return 10
  elseif (grade == "B") then
    return 7
  elseif (grade == "C") then
    return 3
  elseif (grade == "D") then
    return 0
  else
    return nil
  end
end

--- Lecture des entrées dans la base de donnée.
-- Chaque entrée correspond à un élève.
-- @param o table d’entrée à traiter
function entry_aff (o)
  local name = o.name or "Inconnu"
  local lastname = o.lastname or "Inconnu"

  local score = {0, 0, 0, 0, 0, 0, 0}
  local score_max = 0
  local score_tot = 0

  -- Lecture et affichage des notes
  score[1] = grade_to_score(o.grade1)
  score[2] = grade_to_score(o.grade2)
  score[3] = grade_to_score(o.grade3)
  score[4] = grade_to_score(o.grade4)
  score[5] = grade_to_score(o.grade5)
  score[6] = grade_to_score(o.grade6)
  score[7] = grade_to_score(o.grade7)

  -- Calcul du bareme et de la note
  for n = 1, 7 do
    if (score[n]) then
      score_max = score_max + 10
      score_tot = score_tot + score[n]
    end
  end

  -- Affichage
  print(lastname .. " " .. name)
  print("\tCompétences : 1 " .. o.grade1
     .. ", 2 " .. o.grade2
     .. ", 3 " .. o.grade3
     .. ", 4 " .. o.grade4
     .. ", 5 " .. o.grade5
     .. ", 6 " .. o.grade6
     .. ", 7 " .. o.grade7)
  --for n = 1, 7 do
  --  print("Compétence " .. n .. " : " .. (score[n] or "/"))
  --end
  --print("Total : " .. score_tot .. " / " .. score_max)
  print("\tTotal : " .. string.format("%2.0f / 20", math.ceil(score_tot / score_max * 20)))

  
      
end

-- Lecture du fichier de données
file_data = arg[1]
if (not file_data) then error ("Aucun fichier spécifié") end
entry = entry_aff
dofile(file_data)

  
