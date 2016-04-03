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

helpers = require("helpers")
lpeg = require("lpeg")

Result = require("tgc.result")

local M = {}

-- Constantes
local MAX_COMP = 7 -- Nombre maximal de compétences
local GRADE_TO_SCORE = {A = 10, B = 7, C = 3, D = 0}

-- Quelques raccourcis.
local find, match, format, gsub = string.find, string.match, string.format, string.gsub
local stripaccents = helpers.stripAccents

local P, S, V, R = lpeg.P, lpeg.S, lpeg.V, lpeg.R
local C, Cb, Cc, Cg, Cs, Ct, Cmt = lpeg.C, lpeg.Cb, lpeg.Cc, lpeg.Cg, lpeg.Cs, lpeg.Ct, lpeg.Cmt



--------------------------------------------------------------------------------
-- Moyennes du trimestre
--------------------------------------------------------------------------------

local Report = {
    -- quarter = "1",
    -- result = Result,
    -- score = "12",
}
local Report_mt = {__index = Report}

--- Création d’une nouvelle moyenne trimestrielle.
-- @param o (table) - table contenant les attributs de la moyenne
-- @return s (Report) - nouvel objet moyenne
function M.new (o)
    local s = setmetatable({}, Report_mt)

    -- Vérification des attributs de la moyenne trimestrielle
    assert(o.quarter and o.quarter ~= "",
        "Impossible de créer la moyenne : trimestre obligatoire")
    s.quarter = o.quarter
    s.score = o.score or ""
    s.result = Result.new(o.result or "")

    return s
end

--- Écriture d’une moyenne dans la base de données.
-- @param f (file) - fichier ouvert en écriture
function Report:write (f)
    f:write("\t\t{")
    f:write(format("quarter = \"%s\", ", self.quarter or ""))
    f:write(format("result = \"%s\", ", self.result:tostring()))
    f:write(format("score = \"%s\", ", self.score or ""))
    f:write("},\n")
end


return M
