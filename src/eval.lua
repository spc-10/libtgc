--------------------------------------------------------------------------------
-- ## TgC eval module
--
-- @author Romain Diss
-- @copyright 2019
-- @license GNU/GPL (see COPYRIGHT file)
-- @module eval

--- Evaluation class
-- Sets default attributes and metatables.
local Eval = {
    category  = "standard",
    max_score = 10,
    over_max  = false,
}

local Eval_mt = {
    __index = Eval,
}

--- Compare two Evals like `comp` in `table.sort`.
-- Returns true if a < b considering the alphabetic order of `class`,
-- numerical order of `number` and then alphabetic order of `category`.
-- See also https://stackoverflow.com/questions/37092502/lua-table-sort-claims-invalid-order-function-for-sorting
function Eval_mt.__lt (a, b)
    -- First compare class
    if a.class and b.class and a.class < b.class then
        return true
    elseif a.class and b.class and a.class > b.class then
        return false
    -- then compare number
    elseif a.number and b.number and a.number < b.number then
        return true
    elseif a.number and b.number and a.number > b.number then
        return false
    -- then compare category
    elseif a.category and b.category and a.category < b.category then
        return true
    else
        return false
    end
end

--- Creates a new evaluation.
-- @param o (table) - table containing the evaluation attributes.
--      o.number (number) - evaluation number
--      o.class (string) - a class name or a class pattern
--      o.category (string)
--      o.title (string)
--      o.competency_mask (string)
--      o.competency_score_mask (string)
--      o.max_score (number)
--      o.over_max (bool) - allow scores over the `max_score` if true.
-- @return s (Eval)
function Eval.new (o)
    local s = setmetatable({}, Eval_mt)

    -- Make sure number and class are non empty fields
    if not tonumber(o.number) or not o.class or string.match(o.class, "^%s*$") then
        return nil
    end

    -- Assign attributes
    s.number                  = tonumber(o.number)
    s.class                   = tostring(o.class)
    s.category                = o.category
    s.title                   = o.title
    s.competency_mask         = o.competency_mask
    s.competency_score_mask   = o.competency_score_mask
    s.max_score               = tonumber(o.max_score)
    s.over_max                = o.over_max and true or false

    return s
end

--- Update an existing evaluation.
-- @param o (table) - table containing the evaluation attributes to modify.
-- See Eval.new() for attributes.
-- @return (bool) true if an update has been done, false otherwise.
function Eval.update (o)
    o = o or {}
    local update_done = false

    -- Update valid non empty attributes
    if type(o.category) == "string"
        and not string.match(o.category, "^%s*") then
        self.category = o.category
        update_done = true
    end
    if type(o.title) == "string"
        and not string.match(o.title, "^%s*") then
        self.title = o.title
        update_done = true
    end
    if type(o.competency_mask) == "string"
        and not string.match(o.competency_mask, "^%s*") then
        self.competency_mask = o.competency_mask
        update_done = true
    end
    if type(o.competency_score_mask) == "string"
        and not string.match(o.competency_score_mask, "^%s*") then
        self.competency_score_mask = o.competency_score_mask
        update_done = true
    end
    if tonumber(o.max_score) then
        self.max_score = tonumber(o.max_score)
        update_done = true
    end
    if o.over_max then
        self.over_max = o.over_max and true or false
        update_done = true
    end

    return update_done
end

--- Write the evaluation in a file.
-- @param f (file) - file (open for writing)
function Eval:write (f)
    local format = string.format

    local number, category, class, title         = self:get_infos()
    local max_score, over_max                    = self:get_score_infos()
    local competency_mask, competency_score_mask = self:get_competency_infos()

    -- Open
	f:write("evaluation_entry{\n\t")

    -- Student attributes
    f:write(format("number = %q, ",                    number))
    f:write(format("class = %q, ",                     class))
    if category then
        f:write(format("category = %q, ",              category))
    end
	f:write("\n\t")
    if title then
        f:write(format("title = %q, ",                 title))
        f:write("\n\t")
    end
    local written_score = false
    if competency_mask then
        f:write(format("competency_mask = %q, ",       competency_mask))
        written_score = true
    end
    if competency_score_mask then
        f:write(format("competency_score_mask = %q, ", competency_score_mask))
        written_score = true
    end
    if max_score then
        f:write(format("max_score = %q, ",             max_score))
        written_score = true
    end
    if over_max then
        f:write(format("over_max = %q, ",              over_max))
        written_score = true
    end
    if written_score then
        f:write("\n")
    end

    -- Close
	f:write("}\n")
    f:flush()
end

--- Returns the evaluation's main informations.
function Eval:get_infos ()
    return self.number, self.category, self.class, self.title
end
--- Returns the evaluation's score informations.
function Eval:get_score_infos ()
    return self.max_score, self.over_max
end
--- Returns the evaluation's competency informations.
function Eval:get_competency_infos ()
    return self.competency_mask, self.competency_score_mask
end

--------------------------------------------------------------------------------
-- Debug stuff

--- Prints the database informations in a human readable way.
function Eval:plog (prompt)
    local function plog (s, ...) print(string.format(s, ...)) end
    prompt = prompt and prompt .. ".eval" or "eval"

    local number, category, class, title         = self:get_infos()
    local max_score, over_max                    = self:get_score_infos()
    local competency_mask, competency_score_mask = self:get_competency_infos()
    plog("%s> Eval. n. %2d (%s), cat. %s %q (%s) [%s] /%d%s",
        prompt,
        number, class, category, title,
        competency_mask, competency_score_mask,
        max_score, over_max and "[+]" or "")
end


return setmetatable({new = Eval.new}, nil)
