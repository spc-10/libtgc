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
    s.dyslexia       = o.dyslexia
    s.dyscalculia    = o.dyscalculia
    s.enlarged_font  = o.enlarged_font
    s.extra_time     = o.extra_time
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
            result.eval = e
            s.results[eid] = Result.new(result)
        end
    end

    return s
end

---------------------------------------------------------------------------------
-- Update an existing student
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
        and string.match(o.gender, "^[fFmM]$") then
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
    if o.extra_time then
        self.extra_time = o.extra_time and true or nil
        update_done = true
    end
    if o.dyslexia then
        self.dyslexia = o.dyslexia and true or nil
        update_done = true
    end
    if o.dyscalculia then
        self.dyscalculia = o.dyscalculia and true or nil
        update_done = true
    end
    if o.enlarged_font then
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
    f:write(string.format("class = %q,",               self.class))
    if self.group then
        f:write(string.format(" group = %q,",          self.group))
    end
    if self.place then
        f:write(string.format(" place = %d,",          self.place))
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
-- Check if the student is in a specified class (or group).
-- @param class_p[opt=true] class pattern (default to all classes)
-- @param check_group[opt=true] also check in groups if true
-- @return true or false
-- @fixme change the defautl pattern?
-- FIXME check_group doesn't work
function Student:is_in_class (class_p, check_group)
    local class_p = class_p and tostring(class_p) or ".*"
    local group = group or true

    if not self.class then
        return false
    elseif string.match(self.class, class_p) then
        return true
    elseif self.group and string.match(self.group, class_p) then
        return true
    else
        return false
    end
end

--------------------------------------------------------------------------------
-- Get the class and group of a student.
-- @return class, group
function Student:get_class ()
    return self.class, self.group
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
-- @return the formated name and lastname
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
-- @return gender (female, male or other by default)
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
-- @return gender (female, male or other by default)
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
function Student:add_result (o)
    local o = o or {}
    local e = o.eval

    assert(e, "Cannot add a result with no associated evaluation to a student")

    -- Get the result correspond to the eval ids.
    local eid = e:get_id()
    local r = self.results[eid]

    -- If a result already exists, we add the new one to the existing one if
    -- the eval allows multiple attempts.
    if r then
        return r:add_grades(o)
    -- Otherwise, we create the new result.
    else
        self.results[eid] = Result.new(o)
        return -- return something?
    end
end

---------------------------------------------------------------------------------
-- Get the results grade list corresponding to an evaluation.
function Student:get_grade (eid)
    local r = self.results[eid]

    if not r then
        return nil
    else
        return r:get_grade()
    end
end

---------------------------------------------------------------------------------
-- Get the results grade corresponding to an evaluation id and subid.
-- @param eid the evaluation id
-- @param subeid the subevaluation id
-- @return the grade score and competencies
-- TODO: Check allow_multi_attempts to return a list of grades or a unique grade?
function Student:get_result (eid, style)
    local r = self.results[eid]

    if not r then
        return nil
    else
        return r:get_result(style)
    end
end

---------------------------------------------------------------------------------
-- Get the results mean grade corresponding to an evaluation id and subid.
-- @param eid the evaluation id
-- @return the grade score and competencies
-- TODO: Check allow_multi_attempts to return a list of grades or a unique grade?
function Student:get_mean_grade (eid, style)
    local r = self.results[eid]

    if not r then
        return nil
    else
        return r:get_mean_grade(style)
    end
end

---------------------------------------------------------------------------------
-- Get the results corresponding to an evaluation id and subid.
-- @param eid the evaluation id
-- @return a list of grades (score and competencies)
-- TODO: Check allow_multi_attempts to return a list of grades or a unique grade?
-- FIXME : Should be named get_grade()
function Student:get_results (eid, style)
    local r = self.results[eid]

    if not r then
        return nil
    else
        return r:get_results(style)
    end
end

--------------------------------------------------------------------------------
-- Debug stuff
-- @section debug
--------------------------------------------------------------------------------

---------------------------------------------------------------------------------
-- Prints the database informations in a human readable way.
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
