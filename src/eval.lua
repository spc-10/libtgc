--------------------------------------------------------------------------------
-- ## TgC eval module
--
-- @author Romain Diss
-- @copyright 2019
-- @license GNU/GPL (see COPYRIGHT file)
-- @module eval

local utils    = require "tgc.utils"

--- Evaluation class
-- Sets default attributes and metatables.
local Eval = {
    category  = "standard",
    max_score = 20,
    over_max  = false,
}

local Eval_mt = {
    __index = Eval,
}

--- Compare two Evals like `comp` in `table.sort`.
-- Returns true if a < b considering the alphabetic order of `class_p`,
-- numerical order of `number` and then alphabetic order of `category`.
-- See also https://stackoverflow.com/questions/37092502/lua-table-sort-claims-invalid-order-function-for-sorting
function Eval_mt.__lt (a, b)
    -- First compare class_p
    if a.class_p and b.class_p and a.class_p < b.class_p then
        return true
    elseif a.class_p and b.class_p and a.class_p > b.class_p then
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
--      o.class_p (string) - a class pattern corresponding to the classes which
--          did the evaluation
--      o.category (string)
--      o.title (string)
--      o.competency_mask (string)
--      o.competency_score_mask (string)
--      o.max_score (number)
--      o.over_max (bool) - allow scores over the `max_score` if true.
-- @return s (Eval)
function Eval.new (o)
    local s = setmetatable({}, Eval_mt)

    -- Make sure number and class_p are non empty fields
    if not tonumber(o.number) or not o.class_p or string.match(o.class_p, "^%s*$") then
        return nil
    end

    -- Assign attributes
    s.category                = o.category
    s.number                  = tonumber(o.number)
    s.title                   = o.title

    s.class_p                 = tostring(o.class_p)

    s.competencies            = o.competencies
    -- s.competency_mask         = o.competency_mask
    -- s.competency_score_mask   = o.competency_score_mask
    s.max_score               = tonumber(o.max_score)
    s.score_to_report         = tonumber(o.score_to_report)
    s.over_max                = o.over_max and true or false

    s.mandatory               = tostring(o.mandatory)

    s.subeval= {}
    if o.subeval and type(o.subeval == "table")  then
        for n = 1, #o.subeval do
            table.binsert(s.subeval, Eval.new(o.subeval[n]))
        end
    end

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
    if type(o.competencies) == "string"
        and not string.match(o.competencies, "^%s*") then
        self.competencies = o.competencies
        update_done = truies
    end
    -- if type(o.competency_mask) == "string"
    --     and not string.match(o.competency_mask, "^%s*") then
    --     self.competency_mask = o.competency_mask
    --     update_done = true
    -- end
    -- if type(o.competency_score_mask) == "string"
    --     and not string.match(o.competency_score_mask, "^%s*") then
    --     self.competency_score_mask = o.competency_score_mask
    --     update_done = true
    -- end
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

    -- Open
	f:write("evaluation_entry{\n\t")

    -- Student attributes
    f:write(format("number = %q, ",                    self.number))
    f:write(format("class_p = %q, ",                   self.class_p))
    if self.category then
        f:write(format("category = %q, ",              self.category))
    end
	f:write("\n\t")
    if self.title then
        f:write(format("title = %q, ",                 self.title))
        f:write("\n\t")
    end
    local written_score = false
    -- if competency_mask then
    --     f:write(format("competency_mask = %q, ",       competency_mask))
    --     written_score = true
    -- end
    -- if competency_score_mask then
    --     f:write(format("competency_score_mask = %q, ", competency_score_mask))
    --     written_score = true
    -- end
    -- FIXME: adapt to competencies format.
    if self.competencies then
        f:write(format("competencies = %q, ",          self.competencies))
        written_score = true
    end
    if self.max_score then
        f:write(format("max_score = %q, ",             self.max_score))
        written_score = true
    end
    if self.over_max then
        f:write(format("over_max = %q, ",              self.over_max))
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
    return self.number, self.category, self.class_p, self.title
end
--- Returns the evaluation's score informations.
function Eval:get_score_infos ()
    return self.max_score, self.over_max
end
--- Returns the evaluation's competency informations.
-- function Eval:get_competency_infos ()
--     return self.competency_mask, self.competency_score_mask
-- end

--------------------------------------------------------------------------------
-- Category stuff

local categories = {
    "standard",
    "level",
    "sublevel",
    "homework",
    "work",
    "att"}







--------------------------------------------------------------------------------
-- Debug stuff

--- Prints the database informations in a human readable way.
function Eval:plog (prompt_lvl)
    local prompt_lvl = prompt_lvl or 0
    local tab = "  "
    local prompt = string.rep(tab, prompt_lvl)

    local number, category, class_p, title         = self:get_infos()
    local max_score, over_max                    = self:get_score_infos()
    -- local competency_mask, competency_score_mask = self:get_competency_infos()
    utils.plog("%sEval. n° %2d: %s\n", prompt, number, title)
    utils.plog("%s%s- category: %s\n", prompt, tab, category)
    utils.plog("%s%s- class: %s\n", prompt, tab, class_p)
    utils.plog("%s%s- score: /%d%s\n", prompt, tab, max_score, over_max and " (can be overscored)" or "")
    utils.plog("%s%s- competencies: /%s\n", prompt, tab, competencies)
end


return setmetatable({new = Eval.new}, nil)
