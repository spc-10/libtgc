--------------------------------------------------------------------------------
-- ## TgC student module
--
-- @author Romain Diss
-- @copyright 2019
-- @license GNU/GPL (see COPYRIGHT file)
-- @module student

local Result   = require "tgc.result"
local Eval     = require "tgc.eval"
local utils    = require "tgc.utils"
local DEBUG    = utils.DEBUG

local strip_accents = utils.strip_accents
table.binsert = utils.binsert

---------------------------------------------------------------------------------
-- Student class
-- Sets metatables.

local Student    = {}
local Student_mt = {
    __index = Student,
}

---------------------------------------------------------------------------------
-- Compare two Students like `comp` in `table.sort`.
-- @return true if a < b considering the alphabetic order of
-- `lastname` and then `name`.
-- @see also https://stackoverflow.com/questions/37092502/lua-table-sort-claims-invalid-order-function-for-sorting
function Student_mt.__lt (a, b)
    -- first compare lastnames (whithout accents)
    if a.lastname and b.lastname
        and strip_accents(a.lastname) < strip_accents(b.lastname) then
        return true
    elseif a.lastname and b.lastname
        and strip_accents(a.lastname) > strip_accents(b.lastname) then
        return false
    -- then compare names (whithout accents)
    elseif a.name and b.name
        and strip_accents(a.name) < strip_accents(b.name) then
        return true
    else
        return false
    end
end

---------------------------------------------------------------------------------
-- Creates a new student.
-- @param o (table) - table containing the student attributes
--      o.lastname (string)
--      o.name (string)
--      o.class (string)
--      o.place (number) *optional*
--      o.extra_time (number) *optional* PAP
--      o.results (Result[]) -
--      o.reports (Report[]) -
-- @return s student class or nil if parameters are incorrect
function Student.new (o)
    local s = setmetatable({}, Student_mt)

    -- Make sure the student get non empty name and lastname!
    assert(o.lastname and o.name
        and not string.find(o.lastname, "^%s*$")
        and not string.find(o.name, "^%s*$"),
        "student must have name lastname")

    -- Main student attributes
    s.lastname       = o.lastname
    s.name           = o.name
    s.nickname       = o.nickname
    s.gender         = o.gender
    s.class          = o.class
    s.group          = o.group
    s.email          = o.email
    s.dyslexia       = o.dyslexia and true or nil
    s.dyscalculia    = o.dyscalculia and true or nil
    s.enlarged_font  = o.enlarged_font and true or nil
    s.extra_time     = o.extra_time and true or nil
    s.place          = tonumber(o.place)

    -- Create the evaluation results
    s.results = {}
    if o.results and type(o.results) == "table" then
        for _, result in ipairs(o.results) do
            -- Have to find the associated eval...
            local eid = result.eval_id
            local e = o.evaluations[eid]
            if not e then
                break
                -- return nil -- TODO error msg/assert
            end
            result.eval    = e
            result.student = s
            s.results[eid] = Result.new(result)
        end
    end

    return s
end

---------------------------------------------------------------------------------
-- Update an existing student
-- DEPRECATED
-- @param o (table) - table containing the student attributes.
-- @see Student.new()
-- @return true if an attribute has been updated
function Student:update (o)
    o = o or {}
    local update_done = false

    -- Update valid non empty attributes
    if type(o.lastname) == "string"
        and not string.match(o.lastname, "^%s*$") then
        self.lastname = o.lastname
        update_done = true
    end
    if type(o.name) == "string"
        and not string.match(o.name, "^%s*$") then
        self.name = o.name
        update_done = true
    end
    if type(o.nickname) == "string"
        and not string.match(o.nickname, "^%s*$") then
        self.nickname = o.nickname
        update_done = true
    end
    if type (o.gender) == "string"
        and string.match(o.gender, "^[fFmMoO]$") then
        self.gender = o.gender
        update_done = true
    end
    if type(o.class) == "string"
        and not string.match(o.class, "^%s*$") then
        self.class = o.class
        update_done = true
    end
    if type(o.group) == "string"
        and not string.match(o.group, "^%s*$") then
        self.group = o.group
        update_done = true
    end
    if o.extra_time ~= nil then
        self.extra_time = o.extra_time and true or nil
        update_done = true
    end
    if o.dyslexia ~= nil then
        self.dyslexia = o.dyslexia and true or nil
        update_done = true
    end
    if o.dyscalculia ~= nil then
        self.dyscalculia = o.dyscalculia and true or nil
        update_done = true
    end
    if o.enlarged_font ~= nil then
        self.enlarged_font = o.enlarged_font and true or nil
        update_done = true
    end
    if tonumber(o.place) then
        self.place = tonumber(o.place)
        update_done = true
    end

    return update_done
end

---------------------------------------------------------------------------------
-- Update an existing student name
-- @param new name
-- @return true if update worked
function Student:update_name (name)
    if type(name) == "string" and not string.match(name, "^%s*$") then
        self.name = name
    else
        return false -- on can not remove the student name
    end

    return true
end

---------------------------------------------------------------------------------
-- Update an existing student lastname
-- @param new lastname
-- @return true if update worked
function Student:update_lastname (lastname)
    if type(lastname) == "string" and not string.match(lastname, "^%s*$") then
        self.lastname = lastname
    else
        return false -- on can not remove the student lastname
    end

    return true
end

---------------------------------------------------------------------------------
-- Update an existing student nickname
-- @param new nickname
-- @return true if update worked
function Student:update_nickname (nickname)
    if not nickname then -- removes the nickname
        self.nickname = nil
    elseif type(nickname) == "string" and not string.match(nickname, "^%s*$") then
        self.nickname = nickname
    else
        return false -- error
    end

    return true
end

---------------------------------------------------------------------------------
-- Update an existing student class
-- @param new name
-- @return true if update worked
function Student:update_class (class)
    if not class then
        self.class = nil
    elseif type(class) == "string" and not string.match(class, "^%s*$") then
        self.class = class
    else
        return false -- error
    end

    return true
end

---------------------------------------------------------------------------------
-- Update an existing student group
-- @param new name
-- @return true if update worked
function Student:update_group (group)
    if not group then
        self.group = nil
    elseif type(group) == "string" and not string.match(group, "^%s*$") then
        self.group = group
    else
        return false -- error
    end

    return true
end

---------------------------------------------------------------------------------
-- Update an existing student place
-- @param new place
-- @return true if update worked
function Student:update_place (place)
    if not place then -- removes the place
        self.place = nil
    else
        place = tonumber(place)
        if place then
            self.place = place
        else
            return false -- error
        end
    end

    return true
end

---------------------------------------------------------------------------------
-- Update an existing student email
-- @param new extra_time
-- @return true if update worked
function Student:update_email (email)
    if not email then -- removes the extra_time
        self.email = nil
    else
        self.email = tostring(email)
    end

    return true
end

---------------------------------------------------------------------------------
-- Update an existing student extra_time
-- @param new extra_time
-- @return true if update worked
function Student:update_extra_time (extra_time)
    if not extra_time or extra_time == false then -- removes the extra_time
        self.extra_time = nil
    elseif extra_time == true then
        self.extra_time = true
    else
        return false -- error
    end

    return true
end

---------------------------------------------------------------------------------
-- Update an existing student dyslexia
-- @param new dyslexia
-- @return true if update worked
function Student:update_dyslexia (dyslexia)
    if not dyslexia or dyslexia == false then -- removes the dyslexia
        self.dyslexia = nil
    elseif dyslexia == true then
        self.dyslexia = true
    else
        return false -- error
    end

    return true
end

---------------------------------------------------------------------------------
-- Update an existing student dyscalculia
-- @param new dyscalculia
-- @return true if update worked
function Student:update_dyscalculia (dyscalculia)
    if not dyscalculia or dyscalculia == false then -- removes the dyscalculia
        self.dyscalculia = nil
    elseif dyscalculia == true then
        self.dyscalculia = true
    else
        return false -- error
    end

    return true
end

---------------------------------------------------------------------------------
-- Update an existing student enlarged_font
-- @param new enlarged_font
-- @return true if update worked
function Student:update_enlarged_font (enlarged_font)
    if not enlarged_font or enlarged_font == false then -- removes the enlarged_font
        self.enlarged_font = nil
    elseif enlarged_font == true then
        self.enlarged_font = true
    else
        return false -- error
    end

    return true
end


---------------------------------------------------------------------------------
-- Write the database in a file.
-- @param f file (open for writing)
function Student:write (f)
    -- Opening
    f:write("student_entry{\n    ")

    -- Student attributes
    f:write(string.format("lastname = %q,",            self.lastname))
    f:write(string.format(" name = %q,",               self.name))
    if self.nickname then
        f:write(string.format(" nickname = %q,",       self.nickname))
    end
    if self.gender then
        f:write(string.format(" gender = %q,",         self.gender))
    end
    f:write("\n    ")
    if self.class then
        f:write(string.format("class = %q,",           self.class))
    end
    if self.group then
        f:write(string.format(" group = %q,",          self.group))
    end
    if self.place then
        f:write(string.format(" place = %d,",          self.place))
    end
    f:write("\n    ")
    if self.email then
        f:write(string.format("email = %q,",           self.email))
    end

    -- Adaptations
    local space = ""
    if self.extra_time or self.dyslexia or self.dyscalculia or self.enlarged_font then
        f:write("\n    ")
        if self.extra_time then
            f:write(string.format("extra_time = %q,",  self.extra_time))
            space = " "
        end
        if self.dyslexia then
            f:write(string.format("%sdyslexia = %q,",  space, self.dyslexia))
            space = " "
        end
        if self.dyscalculia then
            f:write(string.format("%sdyscalculia = %q,", space, self.dyscalculia))
            space = " "
        end
        if self.enlarged_font then
            f:write(string.format("%senlarged_font = %q,", space, self.enlarged_font))
            space = " "
        end
    end
    f:write("\n")

    -- Adaptations
    local space = ""
    if self.extra_time or self.dyslexia or self.dyscalculia or self.enlarged_font then
        f:write("\n    ")
        if self.extra_time then
            f:write(string.format("extra_time = %q,",  self.extra_time))
            space = " "
        end
        if self.dyslexia then
            f:write(string.format("%sdyslexia = %q,",  space, self.dyslexia))
            space = " "
        end
        if self.dyscalculia then
            f:write(string.format("%sdyscalculia = %q,", space, self.dyscalculia))
            space = " "
        end
        if self.enlarged_font then
            f:write(string.format("%senlarged_font = %q,", space, self.enlarged_font))
            space = " "
        end
    end
    f:write("\n")

    -- Only print non empty results
    if next(self.results) then
        f:write("    results = {\n")
        for _, result in pairs(self.results) do
            result:write(f)
        end
        f:write("    },\n")
    end

    -- Close
    f:write("}\n")
    f:flush()
end

--------------------------------------------------------------------------------
-- Check if the student is in a specified class.
-- @param class_p[opt=true] class
-- @return true or false
function Student:is_in_class (class)
    if not class or not self.class then
        return false
    elseif self.class == class then
        return true
    else
        return false
    end
end

--------------------------------------------------------------------------------
-- Check if the student is in a specified group.
-- @param group_p[opt=true] group
-- @return true or false
function Student:is_in_group (group)
    if not group or not self.group then
        return false
    elseif self.group == group then
        return true
    else
        return false
    end
end

--------------------------------------------------------------------------------
-- Get the class and group of a student.
-- @return class, group
function Student:get_class ()
    return self.class, self.group or self.class
end

--------------------------------------------------------------------------------
-- Get the formated name of a student.
-- TODO: nickname doc
-- The names are in lowercase except the first letter.
-- The names can also be shorten (first part not changed and other parts
-- replaced by initials) using following styles:
--  - "no": return full name and lastname
--  - "name": return shorten name and full lastname
--  - "lastname": return shorten lastname anf full name
--  - "all": return shorten name and lastname
--  - "hard": return shorten name and lastname in full initials
-- @param style[opt="no"] format style
-- @return name
function Student:get_name (style, nickname)
    style = style or "no"
    local name, lastname = self.name, self.lastname
    if nickname and self.nickname then
        name = self.nickname
    end

    -- FIXME: do not work with accentuated letters!
    local function first_upper_dot(space, s)
        return space .. string.upper(string.sub(s, 1, 1)) .. "."
    end

    -- Format names according to the style
    if style == "name" or style == "all" then
        name = string.gsub(name, "([%-%s])([^%-%s%.][^%-%s%.]*)", first_upper_dot)
    end
    if style == "lastname" or style == "all" then
        lastname = string.gsub(lastname, "([%-%s])([^%-%s%.][^%-%s%.]*)", first_upper_dot)
    end
    if style == "hard" then
        name = string.gsub(name, "([%-%s]*)([^%-%s%.][^%-%s%.]*)", first_upper_dot)
        lastname = string.gsub(lastname, "([%-%s]*)([^%-%s%.][^%-%s%.]*)", first_upper_dot)
    end

    return name, lastname
end

function Student:get_fullname (style, nickname)
    local style = style or "no"
    local name, lastname = self:get_name(style, nickname)

    return name .. " " .. lastname
end

--------------------------------------------------------------------------------
-- Gets the students gender.
-- @return "female" or "male" or "other" (default)
function Student:get_gender ()
    local gender = tostring(self.gender)

    if string.match(gender, "[fF]") then
        return "female"
    elseif string.match(gender, "[mM]") then
        return "male"
    else
        return "other"
    end
end

--------------------------------------------------------------------------------
-- Gets the students adaptations.
-- @return extra_time, dyslexia, dyscalculia, enlarged_font
function Student:get_adaptations ()
    return self.extra_time, self.dyslexia, self.dyscalculia, self.enlarged_font
end


--------------------------------------------------------------------------------
-- Results part
-- @section result
--------------------------------------------------------------------------------

---------------------------------------------------------------------------------
-- Add an evaluation result in the student's corresponding list.
-- @param o the evaluation result attributes table
function Student:add_grade (o)
    local o = o or {}
    local e = o.eval
    o.student = self

    assert(e, "Cannot add a result with no associated evaluation to a student")

    -- Get the result correspond to the eval ids.
    local eid = e:get_id()
    local r = self.results[eid]

    -- If a result already exists, we add the new one to the existing one if
    -- the eval allows multiple attempts.
    if r then
        return r:add_grade(o)
    -- Otherwise, we create the new result.
    else
        self.results[eid] = Result.new(o)
        return -- return something?
    end
end

---------------------------------------------------------------------------------
-- Update a grade
-- @param o the evaluation result attributes table
-- @param date
function Student:update_grade (o, date)
    local o = o or {}
    local e = o.eval

    assert(e, "Cannot add a result with no associated evaluation to a student")

    -- Update the result
    local eid = e:get_id()
    local r = self.results[eid]

    if r then
        r:update_grade(o, date)
    else
        return nil
    end
end

---------------------------------------------------------------------------------
-- Remove a grade
-- @param o the evaluation result attributes table
-- Rem: o must contain the date of the evaluation (o.date)
function Student:remove_grade (e, date)
    assert(e, "Cannot add a result with no associated evaluation to a student")

    -- Update the result
    local eid = e:get_id()
    local r = self.results[eid]

    if r then
        r:remove_grade(date)
        if not r:get_grade() then -- remove empty result
            self.results[eid] = nil
        end
        return true
    else
        return nil
    end
end

---------------------------------------------------------------------------------
-- Get the results grade list corresponding to an evaluation.
-- @return {{score_1, comp_grades_1}, {score_2, comp_grades_2}, ...}
-- FIXME: to remove or to change by a loop with get_grade ()
function Student:get_grade_list (eid)
    local r = self.results[eid]

    if not r then
        return nil
    else
        return r:get_grade_list()
    end
end

---------------------------------------------------------------------------------
-- Get the results grade corresponding to an evaluation eid
-- If multiple attempts allowed, return the last result
-- @param eid the evaluation id
-- @return score, comp_grades
function Student:get_grade (eid, date)
    local r = self.results[eid]

    if not r then
        return nil
    else
        return r:get_grade(date)
    end
end

---------------------------------------------------------------------------------
-- Get the results score corresponding to an evaluation eid
-- If the result grades contains no score, calculates one from competencies.
-- @param eid the evaluation id
-- @return score
function Student:get_score (eid)
    local r = self.results[eid]

    if not r then
        return nil
    else
        return r:get_score()
    end
end

---------------------------------------------------------------------------------
-- Get the list of the evaluation id of all the student results corresponding
-- to a quarter (or all quarters if none given).
-- WARNING: not tested and actually not used
-- @parma quarter [opt]
-- @return {eid_1, eid_2, ...} or nil
function Student:get_results_eval_ids (quarter)
    local eids = {}

    for eid, r in pairs(self.results) do
        local eval_quarter = r:get_quarter()
        if not quarter or eval_quarter and quarter == eval_quarter then
            table.insert(eids, eid)
        end
    end

    return next(eids) and eids or nil
end

--------------------------------------------------------------------------------
-- Debug stuff
-- @section debug
--------------------------------------------------------------------------------

---------------------------------------------------------------------------------
-- Prints the database informations in a human readable way.
-- FIXME: rewrite this
function Student:plog (prompt_lvl)
    local prompt_lvl = prompt_lvl or 0
    local tab = "  "
    local prompt = string.rep(tab, prompt_lvl)

    local name, lastname = self:get_name()
    utils.plog("%s%s %s (%s)\n" , prompt, name, lastname, self:get_gender())
    utils.plog("%s%s- class: %s (%s)\n", tab, prompt, self.class, self.group or "no group")
    utils.plog("%s%s- place: %s\n", prompt, tab, self.place or "none")
    if self.extra_time or self.dyslexia or self.dyscalculia or self.enlarged_font then
        utils.plog("%s%s- adaptations: ", prompt, tab)
        local adaptations = {}
        if self.extra_time then table.insert(adaptations, "extra time") end
        if self.dyslexia then table.insert(adaptations, "dyslexia") end
        if self.dyscalculia then table.insert(adaptations, "dyscalculia") end
        if self.enlarged_font then table.insert(adaptations, "enlarged font") end
        utils.plog("%s.\n", table.concat(adaptations, ", "))
    end

    if self.results then
        utils.plog("%s%s- results:\n", prompt, tab)
    end
    for _, r in pairs(self.results) do
        r:plog(prompt_lvl + 2)
    end
end


return setmetatable({new = Student.new}, nil)
