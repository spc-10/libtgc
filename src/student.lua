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

--- Student class
-- Sets metatables.

local Student    = {}
local Student_mt = {
    __index = Student,
}

--- Compare two Students like `comp` in `table.sort`.
-- Returns true if a < b considering the alphabetic order of `class`,
-- `lastname` and then `name`.
-- See also https://stackoverflow.com/questions/37092502/lua-table-sort-claims-invalid-order-function-for-sorting
function Student_mt.__lt (a, b)
    -- First compare class
    if a.class and b.class and a.class < b.class then
        return true
    elseif a.class and b.class and a.class > b.class then
        return false
    -- then compare lastnames (whithout accents)
    elseif a.lastname and b.lastname
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

--- Creates a new student.
-- @param o (table) - table containing the student attributes.
--      o.lastname (string)
--      o.name (string)
--      o.class (string)
--      o.place (number) *optional*
--      o.increased_time (bool) *optional* PAP
--      o.results (Result[]) -
--      o.reports (Report[]) -
-- @return s (Student) or nil if parameters are incorrect.
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
    s.class          = o.class
    s.increased_time = o.increased_time and true or false
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

--- Update an existing student
-- @param o (table) - table containing the student attributes.
-- See Student.new()
-- @return (bool) - true if an attribute has been updated
function Student:update (o)
    o = o or {}
    local update_done = false

    -- Update valid non empty attributes
    if type(o.lastname) == "string"
        and string.match(o.lastname, "^%s*$") then
        self.lastname = tostring(o.lastname)
        update_done = true
    end
    if type(o.name) == "string"
        and string.match(o.name, "^%s*$") then
        self.name = tostring(o.name)
        update_done = true
    end
    if type(o.class) == "string"
        and string.match(o.class, "^%s*$") then
        self.class = tostring(o.class)
        update_done = true
    end
    if type(o.increased_time) == "boolean" then
        self.increased_time = tostring(o.increased_time)
        update_done = true
    end
    if tonumber(o.place) then
        self.place = tonumber(o.place)
        update_done = true
    end

    return update_done
end

--- Write the database in a file.
-- @param f (file) - file (open for writing)
function Student:write (f)
    local lastname, name, class, increased_time, place = self:get_infos()
    local results        = self.results or {}
    local reports        = self.reports or {}

    -- Opening
	f:write("student_entry{\n\t")

    -- Student attributes
    f:write(string.format("lastname = %q, ",           lastname))
    f:write(string.format("name = %q, ",               name))
    f:write(string.format("class = %q, ",              class))
    if place then
        f:write(string.format("place = %q, ",          place))
    end
    if increased_time then
        f:write("\n\t")
        f:write(string.format("increased_time = %q, ", increased_time))
    end
    f:write("\n")

	-- Only print non empty results
    if next(results) then
        f:write("\tresults = {\n")
        for _, result in pairs(self.results) do
            result:write(f)
        end
        f:write("\t},\n")
    end

	-- Reports
    -- TODO
    if next(reports) then
        f:write("\treports = {\n")
        for i, report in ipairs(reports) do
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

--- Returns the student informations.
function Student:get_infos ()
    return self.lastname, self.name, self.class, self.increased_time, self.place
end

--- TODO: eval and reports getters...
--function Student:get_results ()        return self.results end
--function Student:get_reports ()        return self.reports end


--------------------------------------------------------------------------------
-- Results part

--- Add an evaluation result in the student's corresponding list.
-- @param o (table) - the evaluation result attributes.
-- @return Result (or nil if no result is added).
function Student:add_result (o)
    local new = Result.new(o)
    table.binsert(self.results, Result.new(o))
    return new
end

--------------------------------------------------------------------------------
-- Debug stuff

--- Prints the database informations in a human readable way.
function Student:plog (prompt)
    local function plog (s, ...) print(string.format(s, ...)) end
    prompt = prompt and prompt .. ".student" or "student"

    local lastname, name, class, increased_time, place = self:get_infos()
    plog("%s> Name: %s %s, %s (place: %2s, time+: %s)",
        prompt,
        lastname, name, class, place, increased_time and "yes" or "no")

    for _, r in ipairs(self.results) do
        r:plog(prompt)
    end
end


return setmetatable({new = Student.new}, nil)
