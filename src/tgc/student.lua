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
--      o.increased_time (number) *optional* PAP
--      o.results (Result[]) -
--      o.reports (Report[]) -
-- @return s student class or nil if parameters are incorrect
function Student.new (o)
    local s = setmetatable({}, Student_mt)

    -- Make sure the student get non empty name, lastname and class!
    if not o.lastname or not o.name or not o.class
        or string.find(o.lastname, "^%s*$")
        or string.find(o.name, "^%s*$")
        or string.find(o.class, "^%s*$") then
        return nil
    end

    -- Main student attributes
    s.lastname       = o.lastname
    s.name           = o.name
    s.gender         = o.gender
    s.class          = o.class
    s.group          = o.group
    s.increased_time = o.increased_time
    s.place          = tonumber(o.place)

    -- Create the evaluation results
    s.results = {}
    if o.results and type(o.results) == "table" then
        for n = 1, #o.results do
            table.binsert(s.results, Result.new(o.results[n]))
        end
    end

    -- Creates the reports (after some checks)
    -- TODO
    s.reports = {}
    if o.reports and type(o.reports) == "table" then
        for n = 1, #o.reports do
            if type(o.reports[n]) == "table" then
                local already_exists = s:add_report(o.reports[n])
                msg = "Error: %s %s can not have two reports the same quarter.\n"
                assert(not already_exists, msg:format(s.lastname, s.name))
            end
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
    if tonumber(increased_time) then
        self.increased_time = tonumber(o.increased_time)
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
    f:write("student_entry{\n\t")

    -- Student attributes
    f:write(string.format("lastname = %q, ",           self.lastname))
    f:write(string.format("name = %q, ",               self.name))
    f:write(string.format("gender = %q, ",             self.gender))
    f:write(string.format("class = %q, ",              self.class))
    if self.group then
        f:write(string.format("group = %q, ",          self.group))
    end
    if self.place then
        f:write(string.format("place = %q, ",          self.place))
    end
    if self.increased_time then
        f:write("\n\t")
        f:write(string.format("increased_time = %q, ", self.increased_time))
    end
    f:write("\n")

    -- Only print non empty results
    if next(self.results) then
        f:write("\tresults = {\n")
        for _, result in pairs(self.results) do
            result:write(f)
        end
        f:write("\t},\n")
    end

    -- Reports
    -- TODO
    if next(self.reports) then
        f:write("\treports = {\n")
        for i, report in ipairs(self.reports) do
            f:write(string.format("\t\t{quarter = %q,\n", i))
            f:write(string.format("\t\t\tresult = %q, ", tostring(report.result)))
            f:write(string.format("score = %q},\n", report.score or nil))
        end
        f:write("\t},\n")
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
function Student:is_in_class (class_p, check_group)
    local class_p = class_p and tostring(class_p) or ".*"
    local group = group or true

    if string.match(self.class, class_p) then
        return true
    elseif self.group and string.match(self.group, class_p) then
        return true
    else
        return false
    end
end

--------------------------------------------------------------------------------
-- Get the formated name of a student.
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
function Student:get_name (style)
    local style = style or "no"
    local name, lastname = self.name, self.lastname

    -- FIXME: do not work with accentuated letters!
    local function first_upper_dot(space, s)
        return space .. string.upper(string.sub(s, 1, 1)) .. "."
    end

    -- TODO check style...
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

--------------------------------------------------------------------------------
-- Gets the students gender.
-- @return gender (female, male or other by default)
function Student:get_gender ()
    if string.match(self.gender, "[fF]") then
        return "female"
    elseif string.match(self.gender, "[mM]") then
        return "male"
    else
        return "other"
    end
end

---------------------------------------------------------------------------------
-- TODO: eval and reports getters...
--function Student:get_results ()        return self.results end
--function Student:get_reports ()        return self.reports end


--------------------------------------------------------------------------------
-- Results part
-- @section result
--------------------------------------------------------------------------------

---------------------------------------------------------------------------------
-- Add an evaluation result in the student's corresponding list.
-- @param o the evaluation result attributes table
-- @return result class or nil if no result is added
function Student:add_result (o)
    local new = Result.new(o)
    table.binsert(self.results, Result.new(o))
    return new
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
    utils.plog("%sName: %s - Lastname %s (%s)\n" , prompt, name, lastname, self:get_gender())
    utils.plog("%s%s- class: %s (%s)\n", tab, prompt, self.class, self.group or "no group")
    utils.plog("%s%s- place: %s\n", prompt, tab, self.place or "none")
    utils.plog("%s%s- increased time: × %.2f\n", prompt, tab, self.increased_time or 1)

    if self.results then
        utils.plog("%s%s- results:\n", prompt, tab)
    end
    for _, r in ipairs(self.results) do
        r:plog(prompt_lvl + 2)
    end
end


return setmetatable({new = Student.new}, nil)
