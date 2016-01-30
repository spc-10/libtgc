#! /usr/bin/lua5.3

require("tgc-eval")
require("tgc-student")
require("tgc-db")

local function main()
    filename = arg[1]
    if (not filename) then error ("Aucun fichier spécifié") end

    database = Database.create()
    database:read(filename)
end

main()

