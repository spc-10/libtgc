-- TGC
-- Module Evals


EvalResult = {
    -- name = "Évaluation n° 3",
    -- date = "01/01/2001",
    -- quarter = 1,
    -- grades = Grades,
}

--- Création d’une nouvelle évaluation.
-- @param o - table contenant les attributs de l’évaluation
function EvalResult:create (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

