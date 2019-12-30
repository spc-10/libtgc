--------------------------------------------------------------------------------
-- ## TgC category rule module
--
-- @author Romain Diss
-- @copyright 2019
-- @license GNU/GPL (see COPYRIGHT file)
-- @module catrule


--- Category_rule class
-- Sets default attributes and metatables.
local Category_rule = {
    coefficient   = 1,
    mandatory     = false, -- do not consider this category for the report.
    category_mean = false, -- only consider the category mean for the report.
}

local Category_rule_mt = {
    __index = Category_rule,
}

--- Creates a new report.
-- @param o (table) - table containing the report attributes.
--      o.quarter (number) - report's quarter
-- @return s (Report)
function Category_rule.new (o)
    local s = setmetatable({}, Category_rule_mt)

    -- Makes sure catagory name attribute exists.
    if not o.name or string.match(o.name, "^%s$") then
        return nil
    end

    -- Assigns attributes.
    s.name          = o.name
    s.coefficient   = tonumber(o.coefficient)
    s.mandatory     = o.mandatory and true or false
    s.category_mean = o.category_mean and true or false

    return s
end

--- Update an existing category rule.
-- @param o (table) - table containing the rules attributes to modify.
-- See Category_rule.new() for attributes.
-- @return (bool) true if an update has been done, false otherwise.
function Category_rule.update (o)
    o = o or {}
    local update_done = false

    -- Update valid non empty attributes
    if type(o.coefficient) == "number" then
        self.coefficient = o.coefficient
        update_done = true
    end
    if o.mandatory then
        self.mandatory = o.mandatory and true or false
        update_done = true
    end
    if o.category_mean then
        self.category_mean = o.category_mean and true or false
        update_done = true
    end

    return update_done
end

--- Write the category rule in a file.
-- @param f (file) - file (open for writing)
function Category_rule:write (f)
    local format = string.format

    local name, coefficient, mandatory, category_mean = self:get_infos()

    -- Open
	f:write("category_rule_entry{\n\t")

    -- Student attributes
    f:write(format("name = %q, ",          name))
    f:write(format("coefficient = %q, ",   coefficient))
    f:write(format("mandatory = %q, ",     mandatory))
    f:write(format("category_mean = %q, ", category_mean))
    f:write("\n")

    -- Close
	f:write("}\n")
    f:flush()
end

--- Returns the category's rule informations.
function Category_rule:get_infos ()
    return self.name, self.coefficient, self.mandatory, self.category_mean
end

--------------------------------------------------------------------------------
-- Debug stuff

--- Prints the database informations in a human readable way.
function Category_rule:plog (prompt)
    local function plog (s, ...) print(string.format(s, ...)) end
    prompt = prompt and prompt .. ".catrule" or "catrule"

    local name, coefficient, mandatory, category_mean = self:get_infos()
    plog("%s> Rule for %s: coeff %.2f, %s, %s",
        prompt, name, coefficient,
        mandatory and "mandatory" or "not mandatory",
        category_mean and "cat. mean" or "")
end


return setmetatable({new = Category_rule.new}, nil)
