-- TGC
-- Module Student


Student = {
    -- lastname = "Doe",
    -- name = "John",
    -- class = "5e1",
    -- dys = "Dysorthographique",
    -- pai = "En fauteuil-roulant",
    -- evaluations = {EvalResult, ...},
    -- means = {Mean, ...}
}

--- Création d’un nouvel élève.
-- @param o - table contenant les attributs de l’élève
function Student:create (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

--- Vérifie si l’élève est dans la classe demandée.
-- @param class
function Student:isinclass (class)
    return self.class == class
end

