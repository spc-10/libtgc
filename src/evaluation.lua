--[[This module provides the Evaluation Class for TGC.

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

local Result = require("tgc.result")

local M = {}

--------------------------------------------------------------------------------
-- Évaluations
--------------------------------------------------------------------------------

local Eval = {
    -- id = "identifiant",
    -- title = "Évaluation n° 3",
    -- number = "3",
    -- date = "01/01/2001",
    -- quarter = "1",
    -- result = Result,
}
local Eval_mt = {__index = Eval}

--- Création d’une nouvelle évaluation.
-- @param o (table) - table contenant les attributs de l’évaluation
-- @return s (Eval) - nouvel objet évaluation
function M.new (o)
    local s = setmetatable({}, Eval_mt)

    -- Vérification des attributs de l’évaluation
    assert(o.id and o.id ~= ""
        and o.date and o.date ~= ""
        and o.quarter and o.quarter ~= "",
        "Impossible de créer l’évaluation : identifiant, date et trimestre obligatoires")

    s.id, s.date, s.quarter = o.id, o.date, o.quarter
    s.title, s.number = o.title or "", o.number
    s.result = Result.new(o.result or "")

    return s
end

--- Écriture d’une évaluation dans la base de données.
-- @param f (file) - fichier ouvert en écriture
function Eval:write (f)
    f:write("\t\t{")
    f:write(string.format("id = \"%s\", ", self.id or ""))
    f:write(string.format("title = \"%s\", ", self.title or ""))
    f:write(string.format("number = \"%s\", ", self.number or ""))
    f:write(string.format("quarter = \"%s\", ", self.quarter or ""))
    f:write(string.format("date = \"%s\", ", self.date or ""))
    f:write(string.format("result = \"%s\", ", self.result:tostring()))
    f:write("},\n")
end

--------------------------------------------------------------------------------
--- Sets the esulthe evaluation.
--
-- @param s (string) - the result string (
-- @param mask (string) - [optional] a list of competence numbers
--------------------------------------------------------------------------------
function Eval:setresult (s, mask)
    self.result = Result.new(s, mask)
end

return M
