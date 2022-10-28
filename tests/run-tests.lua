#!/usr/bin/lua

package.path = "../src/?.lua;../src/?/init.lua;" -- use development version

local plog = require "tgc.utils".plog

local function DEBUG (var, val)
    io.stderr:write(string.format("DEBUG - %s = %s\n", var, val))
end

math.randomseed(os.time())

--------------------------------------------------------------------------------
-- Load TGC
local tgc = require "tgc"
plog("\nInitialisation... ")
tgc = tgc.init()
plog("%s loaded\n", tgc._VERSION)

--------------------------------------------------------------------------------
-- Default variables
local LASTNAMES_FILE = "noms.txt"
local NAMES_FILE     = "prenoms.txt"
local N = 10 -- number of students
local C = 10 -- number of classes
local M = 10 -- number of evaluations

--------------------------------------------------------------------------------
-- Random generators
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Generates a random name.
local function random_name (filename)
    assert(io.open(filename))

    -- First read the names in the datafile
    local count = 1
    local name, sep
    local names = {}
    for line in io.lines(filename) do
        if not string.find(line, "^#") then
            names[count] = line
            count = count + 1
        end
    end

    -- Now generate a random name
    if math.random(5) == 1 then
        -- Sometimes generates compound names
        if math.random(2) == 1 then
            sep = " "
        else sep = "-"
        end
        name = string.gsub(names[math.random(#names)], "^%a", string.upper) ..
            sep ..
            string.gsub(names[math.random(#names)], "^%a", string.upper)
    else
        name = string.gsub(names[math.random(#names)], "^%a", string.upper)
    end

    return name
end

--------------------------------------------------------------------------------
-- Random gender F, M or other same frequency.
local function random_gender ()
    local genders = {"f", "m"}
    return genders[math.random(3)]
end

--------------------------------------------------------------------------------
-- Random gender F, M or other same frequency.
local function random_tuple ()
    local tuple = ""
    for i = 1, math.random(3, 5) do
        tuple = tuple .. string.char(math.random(97, 122))
    end
    return tuple
end

--------------------------------------------------------------------------------
-- Returns true or false.
local function true_or_false ()
    return math.random(2) > 1
end

--------------------------------------------------------------------------------
-- Generates a random class.
local classes = {}
for i = 1, C do
    local level, number = math.random(3, 6), math.random(5)
    classes[i] = level .. "e" .. number
end
local function random_class ()
    return classes[math.random(C)]
end

--------------------------------------------------------------------------------
-- Generates a random class level
local function random_class_level (group_freq)
    return math.random(3, 6) .. "e"
end

--------------------------------------------------------------------------------
-- Generates a random group.
-- @param freq add a group with an 1/freq frequency
local function random_group (freq)
    local level, number = math.random(3, 5), math.random(9)

    if math.random(freq) == freq then
        return "group" .. math.random(1, 9)
    else
        return nill
    end
end

--------------------------------------------------------------------------------
-- Generates a random evaluation category.
-- @param no_cat if present, generate an eval with no category with an 1/no_cat
-- frequency.
local function random_category (no_cat)
    local categories = tgc:get_eval_types_list()

    if no_cat and (math.random(no_cat) == no_cat) then
        return nil
    else
        return categories[math.random(#categories)]
    end
end

--------------------------------------------------------------------------------
-- Generates a random place.
-- @param no_place if present, return nil with an 1/no_place frequency.
local function random_place (no_place)
    if no_place and (math.random(no_place) == no_place) then
        return nil
    else
        return math.random(35)
    end
end

--------------------------------------------------------------------------------
-- Generates a random extra time.
local function random_extra_time ()
    local r = math.random(10)

    if r == 1 then
        return 25
    elseif r <= 4 then
        return 33
    else
        return nil
    end
end

--------------------------------------------------------------------------------
-- Generates a random competencies.
local function random_competencies ()
    local competencies = ""
    repeat
        for id = 1, 8 do
            -- A third chance to add this competency
            if math.random(3) == 1 then
                competencies = competencies .. id .. string.char(math.random(4) + 64)
                -- Sometimes add more competencies grades
                for n = 1, 3 do
                    if math.random(3) == 1 then
                        competencies = competencies .. string.char(math.random(4) + 64)
                    end
                end
                competencies = competencies .. " "
            end
        end
    until not string.match(competencies, "^%s*$")

    return competencies
end

--------------------------------------------------------------------------------
-- Generates a random grade.
local function random_grade (max_score, over_max)
    local max_score = max_score or 20
    local over_max = over_max
    local d3 = math.random(3)
    if d3 == 1 then -- no numbered grade
        local comp = random_competencies()
        return comp, nil, comp
    elseif d3 == 2 then -- no competencies
        local num = over_max and math.random() * max_score or math.random() * max_score * 1.1
        return num, num, nil
    else
        local num = over_max and math.random() * max_score or math.random() * max_score * 1.1
        local comp = random_competencies()
        return {num, comp}, num, comp
    end
end

--------------------------------------------------------------------------------
-- Here we start
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Add students.
plog("\nAdding %d new students...\n", N)
for i = 1, N do
    local name       = random_name(NAMES_FILE)
    local lastname   = random_name(LASTNAMES_FILE)
    local gender     = random_gender()
    local class      = random_class()
    local group      = random_group(3)
    local place      = random_place(3)
    local extra_time = random_extra_time()

    --print(lastname, name, class)
    tgc:add_student({
        lastname       = lastname,
        name           = name,
        gender         = gender,
        class          = class,
        group          = group,
        place          = place,
        extra_time = extra_time})

    -- print the student infos
        plog("- %s, %s" , name, lastname)
        gender = tostring(gender)
        if string.match(gender, "[fF]") then
            plog(" (%s)", "♀")
        elseif string.match(gender, "[mM]") then
            plog(" (%s)", "♂")
        else
            plog(" (%s)", "n")
        end
        plog(", %s", class)
        if group then
            plog(" (%s)", group)
        end
        plog(", place: %s", place or "no")
        if extra_time then
            plog(" [time + %d/100]", extra_time)
        end
        plog("\n")
end

--------------------------------------------------------------------------------
-- Add evaluations.
print(string.format("\nAdding %d new evaluations...", M))
for i = 1, M do
    local class_p          = random_class_level()
    local category         = random_category(5)
    local title            = "Evaluation n° " .. i
    local max_score        = math.random(4) * 5
    local over_max         = true_or_false()
    local multi            = true --_or_false()
    local success_score_pc = math.random(100)
    if success_score_pc < 50 then success_score_pc = nil end

    local eid                = tgc:add_eval({
        class_p              = class_p,
        category             = category,
        title                = title,
        max_score            = max_score,
        over_max             = over_max,
        allow_multi_attempts = multi,
        success_score_pc     = success_score_pc})

    -- print the eval infos
    plog("- %s", title)
    plog(" [%s])", multi and "m" or "u")
    plog(" for class %s\n", class_p)

    -- add subevals for a third of the evals
    if i%3 ~= 0 then
        plog("  - subevaluations:\n")
        for j = 1, math.random(10) do
            -- Some times, let the subeval inherits from its parent
            local title, max_score, over_max = nil, nil, nil
            if math.random(2) == 1 then
                title     = "Sub-evaluation n° " .. i .. "." .. j
                max_score = math.random(4) * 5
                over_max  = true_or_false()
            end

            tgc:add_subeval(eid, {
                title     = title,
                max_score = max_score,
                over_max  = over_max})

            -- print the subeval infos
            plog("     o %s\n", title)
        end
    end
end

--------------------------------------------------------------------------------
-- Add some results.
plog("\nAdding results for students...\n")
for sid in tgc:next_student() do
    local name, lastname = tgc:get_student_name(sid)
    local class = tgc:get_student_class(sid)

    plog("- %s %s, %s\n", name, lastname, class)

    -- Now search all the evaluations for this class
    for eid in tgc:next_eval(class) do
        -- Random date
        local year    = math.random(1900, 2100)
        local month   = math.random(1, 12)
        local day     = math.random(1, 31)
        local date    = os.date("%Y/%m/%d", os.time({year = year, month = month, day = day}))
        local quarter = math.random(1, 3)

        local max_score, over_max = tgc:get_eval_score_infos(eid)
        local category, _, _, _ = tgc:get_eval_infos(eid)

        -- add subresults
        if tgc:has_subevals(eid) then
            plog("  o eval %d, %s (%s) :\n", eid, date, quarter)
            for j = 1, tgc:get_last_eval_subid(eid) do
                -- print the subeval infos
                plog("     - %d.%d %s (%s) : ", eid, j, date, quarter)
                -- Add multiple scores for a same eval
                for k = 1, math.random(3) do
                    local subeid = j
                    local grade, score, competencies = random_grade(max_score, over_max)

                    -- print the scores
                    if score then
                        plog("%.2f", score)
                    else
                        plog("-")
                    end
                    plog("/%.0f [%s], ", max_score, competencies or "")
                    tgc:add_student_result(sid, eid, {
                        date    = date,
                        quarter = quarter,
                        grades  = grade})

                end
                plog("\n")
            end
        else
            local grade, score, competencies = random_grade(max_score, over_max)
            tgc:add_student_result(sid, eid, {
                date    = date,
                quarter = quarter,
                grades  = grade,
            })
            plog("  o eval %s, %s (%s) - ", eid, date, quarter)
            if score then
                plog("%.2f", score)
            else
                plog("-")
            end
            plog("/%.0f [%s]", max_score, competencies or "")
        end
    end
end

    --
-- score = over_max and math.random() * max_score or math.random() * max_score * 1.1
io.write(string.format("\n"))

--print("\nAdding categories rules...")
--for category in pairs(categories) do
--    tgc:add_category_rule({
--        name          = category,
--        coefficient   = math.random() * 5,
--        mandatory     = true_or_false(),
--        category_mean = true_or_false(),
--    })
--end

--------------------------------------------------------------------------------

--local function find_student()
--    repeat
--        plog("Un prénom d’élève à chercher ? ")
--        local name_p = io.read()
--
--        if name_p and not string.find(name_p, "$%s*$") then
--            local sid = tgc:find_student(name_p)
--            if sid then
--                local lastname, name = tgc:get_student_name(sid)
--                local gender = tgc:get_student_gender(sid)
--                plog("Found: %s %s, %s (id: %d) \n", lastname, name, gender, sid)
--            else
--                plog("%s not found.\n", name_p)
--            end
--        end
--    until name_p == nil or string.find(name_p, "^%s*$")
--end
--
--find_student()

print("\nFinding students by Names...")
local students_found = 0
while students_found < 10 do
    local name_p = random_tuple()
    -- io.write(lastname_p .. " ")
    local sids = tgc:find_students("*", name_p)
    if sids then
        for _, sid in ipairs(sids) do
            local lastname, name = tgc:get_student_name(sid)
            local gender = tgc:get_student_gender(sid)
            local class, group = tgc:get_student_class(sid)
            io.write(string.format("Found: %d - %s %s (%s), %s g: %s for pattern \"%s\"\n", sid, lastname, name, gender, class, group, name_p))
            students_found = students_found + 1
        end
    end
end

print("\nFinding students by Class...")
students_found = 0
while students_found < 10 do
    local class_p = random_class()
    -- io.write(lastname_p .. " ")
    local sids = tgc:find_students("*", "*", class_p)
    if sids then
        for _, sid in ipairs(sids) do
            local lastname, name = tgc:get_student_name(sid)
            local gender = tgc:get_student_gender(sid)
            local class, group = tgc:get_student_class(sid)
            io.write(string.format("Found: %d - %s %s (%s), %s g: %s for pattern \"%s\"\n", sid, lastname, name, gender, class, group, class_p))
            students_found = students_found + 1
        end
    end
end

print("\nFinding students by Group...")
students_found = 0
while students_found < 10 do
    local group_p = random_group(3)
    -- io.write(lastname_p .. " ")
    local sids = tgc:find_students("*", "*", group_p)
    if sids then
        for _, sid in ipairs(sids) do
            local lastname, name = tgc:get_student_name(sid)
            local gender = tgc:get_student_gender(sid)
            local class, group = tgc:get_student_class(sid)
            io.write(string.format("Found: %d - %s %s (%s), %s, g: %s for pattern \"%s\"\n", sid, lastname, name, gender, class, group, group_p))
            students_found = students_found + 1
        end
    end
end

--------------------------------------------------------------------------------

print("\n\nFinding evaluations...")
print("--------------------------------------------------------------------------------\n")

local categories = tgc:get_eval_types_list()
print("Categories: ", table.concat(categories, ", "))

print("Search by categories, number and class...")
title_p = "val"

for N = 3, 5 do
    local class = N .. "e.*"
    for n = 1, 10 do
        local title_p = n .. ".*"
        local eids = tgc:find_evals(title_p, class)
        if eids then
            io.write(string.format("Searching for \"%s\" title pattern, \"%s\" class pattern…\n",
                title_p, class))
            for _, eid in ipairs(eids) do
                local _, class, title, subtitle = tgc:get_eval_infos(eid)
                io.write(string.format("  - found: %s (%s) for class %s.\n",
                title, subtitle, class))
            end
        end
    end
end

--------------------------------------------------------------------------------

print("\nPlog !")
tgc:plog()

--------------------------------------------------------------------------------

-- print("\nPlog (by hand)")
-- print("Evaluations:")
-- for eid in tgc:next_eval() do
--     local number, category, class, title         = tgc:get_eval_infos(eid)
--     local max_score, over_max                    = tgc:get_eval_score_infos(eid)
--     -- local competency_mask, competency_score_mask = tgc:get_eval_competency_infos(eid)
--
--     print(string.format("%s> Eval. n. %2d (%s), cat. %s %q (%s) [%s] /%d%s",
--         "By hand", number, class, category, title,
--         "-", "-",
--         -- competency_mask, competency_score_mask,
--         max_score, over_max and "[+]" or ""))
-- end
--
-- print("Students:")
-- for sid in tgc:next_student() do
--     local lastname, name = tgc:get_student_name(sid, "no")
--     local lastname_s, name_s = tgc:get_student_name(sid, "all")
--     local lastname_h, name_h = tgc:get_student_name(sid, "hard")
--     local _, _, class, extra_time, place = tgc:get_student_infos(sid)
--     print(string.format("%s> Name: %s %s (%s %s [%s %s]), %s (place: %2s, time+: %s)",
--         "By hand",
--         lastname, name, lastname_s, name_s, lastname_h, name_h,
--         class, place, extra_time and "yes" or "no"))
-- end

print("\nWriting database...")
tgc:write("notes.lua")
print("\nNo error found!")

-- TODO clean exit of the database
print("\n\n\n-------------------------------------------------------------\n\n\n")
print("\nReading database...")
tgc = nil
tgc = require "tgc"
tgc = tgc.init()
tgc:load("notes.lua")
print("\nNo error found!")
print("\nPlog !")
tgc:plog()
print("\nWriting database...")
tgc:write("notes-02.lua")
print("\nNo error found!")

