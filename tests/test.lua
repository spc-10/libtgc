local tgc = require "tgc"

local names, lastnames = {}, {}
local categories = {"test", "qcm", "final", "homework", "experimental"}
local genders   = {"f", "m"}

-- Reads a database line by line.
local function read_lines (filename)
    local count = 1
    local table = {}
    for line in io.lines(filename) do
        if not string.find(line, "^#") then
            table[count] = line
            count = count + 1
        end
    end
    return table
end

-- Returns true or false
local function true_or_false ()
    return math.random(2) > 1
end

-- Generates a random class.
-- @param group_freq add a group with an 1/group_freq frequency
local function random_class (group_freq)
    local level, number = math.random(3, 5), math.random(9)
    return level .. "e" .. number
end

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

-- Generates a random evaluation category.
-- @param no_cat if present, generate an eval with no category with an 1/no_cat
-- frequency.
local function random_category (no_cat)
    if no_cat and (math.random(no_cat) == no_cat) then
        return nil
    else
        return categories[math.random(#categories)]
    end
end

-- Generates a random place.
-- @param no_place if present, return nil with an 1/no_place frequency.
local function random_place (no_place)
    if no_place and (math.random(no_place) == no_place) then
        return nil
    else
        return math.random(35)
    end
end

-- Read names
local lastnames = read_lines ("noms.txt")
local names     = read_lines ("prenoms.txt")

-- Here we start ---------------------------------------------------------------

print "\nInitialisation..."
tgc = tgc.init()
-- print("\nReading database...")
-- tgc:load("notes.lua")
print(tgc._VERSION)

local N = 20
print(string.format("\nAdding %d new students...", N))
for i = 1, N do
    local name     = string.gsub(names[math.random(#names)], "^%a", string.upper)
    local lastname = string.gsub(lastnames[math.random(#lastnames)], "^%a", string.upper)
    local gender   = genders[math.random(1,2)]
    local class    = random_class()
    local group    = random_group(3)
    local place    = random_place(3)
    local increased_time = math.random() + 1

    --print(lastname, name, class)
    tgc:add_student({
        lastname       = lastname,
        name           = name,
        gender         = gender,
        class          = class,
        group          = group,
        place          = place,
        increased_time = increased_time})

    -- print the student infos
         io.write(string.format("%12s %12s" , lastname, name))
         if string.match(gender, "[fF]") then
             io.write(string.format(" (%s)", "♀"))
         else
             io.write(string.format(" (%s)", "♂"))
         end
         io.write(string.format("\tclass: %6s", class))
         io.write(string.format(" (group: %10s)", group))
         io.write(string.format("\tplace: %s", place))
         if increased_time then
             io.write(string.format("\t[time × %.1f]\n", increased_time))
         end
end

local M = 20
print(string.format("\nAdding %d new evaluations...", M))
for i = 1, M do
    local number    = i
    local class     = random_class()
    local category  = random_category(5)
    local title     = "Evaluation n° " .. i
    local max_score = math.random(4) * 5
    local over_max  = true_or_false()

    -- For results
    local year    = math.random(1900, 2100)
    local month   = math.random(1, 12)
    local day     = math.random(1, 31)
    local quarter = math.random(1, 3)

    tgc:add_eval({
        number = number,
        class = class,
        category = category,
        title = title,
        max_score = max_score,
        over_max = over_max})

    print(string.format("\nAdding results for students belonging to %s", class))
    for sid in tgc:next_student(class) do
        tgc:add_student_result(sid, {
            number = number,
            category = category,
            date = os.date("%Y/%m/%d", os.time({year = year, month = month, day = day})),
            quarter = quarter,
            score = over_max and math.random() * max_score or math.random() * max_score * 1.1,
        })
    end
end

print("\nAdding categories rules...")
local categories = tgc:get_eval_categories_list()
for _, category in ipairs(categories) do
    tgc:add_category_rule({
        name          = category,
        coefficient   = math.random() * 5,
        mandatory     = true_or_false(),
        category_mean = true_or_false(),
    })
end

--------------------------------------------------------------------------------

print("\nFinding students by lastnames...")
for i = 1, #lastnames do
    local lastname_p = string.gsub(lastnames[i], "^%a", string.upper)
    -- io.write(lastname_p .. " ")
    local sid = tgc:find_student(lastname_p)
    if sid then
        local lastname, name = tgc:get_student_name(sid)
        local gender = tgc:get_student_gender(sid)
        io.write(string.format("Found: %d - %s %s (%s) for pattern \"%s\"\n", sid, lastname, name, gender, lastname_p))
    end
end

print("\nFinding students by Names...")
for i = 1, #names do
    local name_p = string.gsub(names[i], "^%a", string.upper)
    -- io.write(lastname_p .. " ")
    local sid = tgc:find_student("*", name_p)
    if sid then
        local lastname, name = tgc:get_student_name(sid)
        local gender = tgc:get_student_gender(sid)
        local class, group = tgc:get_student_class(sid)
        io.write(string.format("Found: %d - %s %s (%s), %s g: %s for pattern \"%s\"\n", sid, lastname, name, gender, class, group, name_p))
    end
end

print("\nFinding students by Class...")
for level = 3, 5 do
    local class_p = level .. "e.*"
    -- io.write(lastname_p .. " ")
    local sid = tgc:find_student("*", "*", class_p)
    if sid then
        local lastname, name = tgc:get_student_name(sid)
        local gender = tgc:get_student_gender(sid)
        local class, group = tgc:get_student_class(sid)
        io.write(string.format("Found: %d - %s %s (%s), %s g: %s for pattern \"%s\"\n", sid, lastname, name, gender, class, group, class_p))
    end
end

print("\nFinding students by Group...")
for i = 1, 20 do
    local group_p = random_group(1)
    -- io.write(lastname_p .. " ")
    local sid = tgc:find_student("*", "*", group_p)
    if sid then
        local lastname, name = tgc:get_student_name(sid)
        local gender = tgc:get_student_gender(sid)
        local class, group = tgc:get_student_class(sid)
        io.write(string.format("Found: %d - %s %s (%s), %s, g: %s for pattern \"%s\"\n", sid, lastname, name, gender, class, group, group_p))
    end
end

--------------------------------------------------------------------------------

print("\nFinding evaluations...")

local categories = tgc:get_eval_categories_list()
print("Categories: ", table.concat(categories, ", "))

print("Search by categories, number and class...")
for i = 1, #categories do
    for m = 1, M do
        for level = 3, 5 do
            for n = 1, 9 do
                local class = level .. "e" .. n
                local eid = tgc:find_eval(m, class, categories[i])
                if eid then
                    local number, category, class = tgc:get_eval_infos(eid)
                    io.write(string.format("Found: %d - %d %s %s\n", eid, number, category, class))
                end
            end
        end
    end
end


--------------------------------------------------------------------------------

print("\nPlog !")
tgc:plog()

--------------------------------------------------------------------------------

print("\nPlog (by hand)")
print("Evaluations:")
for eid in tgc:next_eval() do
    local number, category, class, title         = tgc:get_eval_infos(eid)
    local max_score, over_max                    = tgc:get_eval_score_infos(eid)
    local competency_mask, competency_score_mask = tgc:get_eval_competency_infos(eid)

    print(string.format("%s> Eval. n. %2d (%s), cat. %s %q (%s) [%s] /%d%s",
        "By hand", number, class, category, title,
        competency_mask, competency_score_mask,
        max_score, over_max and "[+]" or ""))
end
print("Students:")
for sid in tgc:next_student() do
    local lastname, name, class, increased_time, place = tgc:get_student_infos(sid)
    print(string.format("%s> Name: %s %s, %s (place: %2s, time+: %s)",
        "By hand", lastname, name, class, place, increased_time and "yes" or "no"))
end


print("\nWriting database...")
tgc:write("notes.lua")
print("\nNo error found!")
