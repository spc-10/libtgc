--------------------------------------------------------------------------------
-- ## TgC eval module
--
-- @author Romain Diss
-- @copyright 2019
-- @license GNU/GPL (see COPYRIGHT file)
-- @module eval

local utils    = require "tgc.utils"
local DEBUG    = utils.DEBUG
local is_date_valid, is_quarter_valid = utils.is_date_valid, utils.is_quarter_valid

--------------------------------------------------------------------------------
-- Default values
local DEFAULT_MAX_SCORE = 20


--------------------------------------------------------------------------------
-- Evaluation class
-- Sets default attributes and metatables.
local Eval = {
    -- category  = "standard",
    -- max_score = 20,
    over_max  = false,
}

local Eval_mt = {
    __index = Eval,
}

--------------------------------------------------------------------------------
-- Evaluation types stuff
-- @section eval_types
--------------------------------------------------------------------------------

local EVAL_TYPES = {
    "standard",
    "level",
    "homework",
    "work",
    "att"}

--------------------------------------------------------------------------------
-- Checks if an eval type exists
-- @param eval_type (string) the type to check
local function eval_type_exists (eval_type)
    for _, t in pairs(EVAL_TYPES) do
        if eval_type == t then return true end
    end

    return false
end

--------------------------------------------------------------------------------
-- Returns the default evaluation type.
-- FIXME to remove?
local function eval_type_default ()
    return EVAL_TYPES[1]
end

--------------------------------------------------------------------------------
-- Splits an eval index into the eval part and the subeval part.
-- @param fancy_eid a string in the format "eid[.subid]" where eid and subid are
-- integers
-- @return eid eval index
-- @return subid subeval index
local function split_fancy_eval_index (fancy_eid)
    local eid, subid = string.match(fancy_eid, "(%d+)%.*(%d*)")
    return tonumber(eid), tonumber(subid)
end

--------------------------------------------------------------------------------
-- Checks if an eval result has the right format.
-- The result should be a table with a valid date and a valid quarter.
-- @param result (table)
-- @return result (table) with date and quarter changed to `nil` if not valid
local function create_valid_result (result)
    local result = result or {}

    result.date = is_date_valid(result.date) and result.date or nil
    result.quarter = is_quarter_valid(result.quarter) and result.quarter or nil

    return result
end


--------------------------------------------------------------------------------
-- Creates a new evaluation.
-- TODO: update the param list
-- @param o (table) - table containing the evaluation attributes.
--      o.id (number) - evaluation id (mandatory)
--      o.class_p (string) - a class pattern corresponding to the classes which
--          did the evaluation
--      o.category (string)
--      o.title (string)
--      o.subtitle (string)
--      o.competency_mask (string)
--      o.competency_score_mask (string)
--      o.max_score (number)
--      o.over_max (bool) allow scores over the `max_score` if true
--      o.success_score_pc a percentage to reach to consider the score a success
-- @return e (Eval)
function Eval.new (o)
    local e = setmetatable({}, Eval_mt)

    -- Make sure the eval has an id and a title.
    local o = o or {}
    assert(tonumber(o.id), "invalid evaluation id")
    assert(o.parent or o.title and not string.find(o.title, "^%s*$"), "invalid evaluation title")

    -- Assign attributes
    e.parent                  = o.parent
    e.id                      = math.tointeger(string.match(o.id, "%d*%.*(%d+)")) -- subeval id is store as X.Y
    e.title                   = o.title and tostring(o.title)
    e.subtitle                = o.subtitle and tostring(o.subtitle)
    e.category                = eval_type_exists(o.category) and o.category

    e.class_p                 = o.class_p and tostring(o.class_p)

    e.competencies            = o.competencies
    -- e.competency_mask         = o.competency_mask
    -- e.competency_score_mask   = o.competency_score_mask
    e.max_score               = math.tointeger(o.max_score)
    e.real_max_score          = math.tointeger(o.real_max_score)
    e.over_max                = o.over_max and true or false
    e.success_score_pc        = math.tointeger(o.success_score_pc)

    e.allow_multi_attempts    = o.allow_multi_attempts and true or false

    -- Subevals stuff
    e.subevals = {}
    if o.subevals and type(o.subevals == "table")  then
        for _, subeval in pairs(o.subevals) do
            local eid, subeid = split_fancy_eval_index(subeval.id)
            subeval.parent = e
            e.subevals[subeid] = Eval.new(subeval)
        end
    end

    -- Results stuff (dates and quarter for each class)
    e.results = {}
    if o.results and type(o.results == "table") then
        for class, result in pairs(o.results) do
            e.results[class] = create_valid_result(result)
        end
    end

    return e
end

--------------------------------------------------------------------------------
-- Creates a sub evaluation to an existing evaluation.
-- @param o (table) - same parameters as in new()
-- @return the index in the subevals list
function Eval:add_subeval (o)
    local o = o or {}
    o.parent = self
    return table.insert(self.subevals, Eval.new(o))
end

--------------------------------------------------------------------------------
-- Add the date and quarter corresponding to when a class did the evaluation.
-- @param class (string)
-- @param date (string) a valid date
-- @param quarter (string) a valid quarter
-- @return nothing ?
function Eval:add_result (class, date, quarter)
    self.results = self.results or {}

    if self.results[class] then
        -- TODO: Checks for inconsistency between current date/quarter and new
        -- one?
        return
    else
        self.results[class] = create_valid_result{date = date, quarter = quarter}
    end
end

--------------------------------------------------------------------------------
-- Update an existing evaluation.
-- FIXME: doesn't work yet!
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
        update_done = true
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

--------------------------------------------------------------------------------
-- Write the evaluation in a file.
-- @param f (file) - file (open for writing)
function Eval:write (f)
    local function fwrite (...) f:write(string.format(...)) end
    local tab = ""

    -- Open for eval (not subevals)
    local _, _, fancy_eid = self:get_ids()
    if self.parent then
        tab = "            "
        fwrite("        {id = %q,",             fancy_eid)
    else
        tab = "    "
        fwrite("evaluation_entry{\n    ")
        fwrite("id = %q,",                      fancy_eid)
    end

    -- Evaluation attributes
    if self.title or self.subtitle then
        fwrite("\n%s",                          tab)
        local space = ""
        if self.title then
            fwrite("title = %q,",               self.title)
            space = " "
        end
        if self.subtitle then
            fwrite("%ssubtitle = %q,",          space, self.subtitle)
        end
    end
    if self.class_p or self.category then
        fwrite("\n%s",                          tab)
        local space = ""
        if self.class_p then
            fwrite("class_p = %q,",             self.class_p)
            space = " "
        end
        if self.category then
            fwrite("%scategory = %q,",          space, self.category)
        end
    end
    -- Score part
    local written_score = false
    -- if competency_mask then
    --     fwrite("competency_mask = %q, ",       competency_mask))
    --     written_score = true
    -- end
    -- if competency_score_mask then
    --     fwrite("competency_score_mask = %q, ", competency_score_mask))
    --     written_score = true
    -- end
    -- FIXME: adapt to competencies format.
    local space = ""
    if self.max_score or self.over_max or self.success_score_pc or self.competencies then
        fwrite("\n%s",                          tab)
        if self.max_score then
            fwrite("max_score = %d,",           self.max_score)
            space = " "
        end
        if self.over_max then
            fwrite("%sover_max = %q,",          space, self.over_max)
            space = " "
        end
        if self.success_score_pc then
            fwrite("%ssuccess_score_pc = %d,",  space, self.success_score_pc)
            space = " "
        end
        if self.competencies then
            fwrite("%scompetencies = %q,",      space, self.competencies)
        end
    end

    if self.allow_multi_attempts then
        fwrite("\n%sallow_multi_attempts = %q,", tab, self.allow_multi_attempts)
    end

    -- Results
    if next(self.results) then
        fwrite("\n%sresults = {",            tab)
        for class, result in pairs(self.results) do
            if result and result.date or result.quarter then -- only prints if result contains infos
                fwrite("\n%s    [%q] = {",            tab, class)
                if result.date then
                    fwrite("date = %q",        result.date)
                end
                if result.date or result.quarter then
                    fwrite(", ")
                end
                if result.quarter then
                    fwrite("quarter = %q",     result.quarter)
                end
                fwrite("},")
            end
        end
        fwrite("},")
    end

    -- Only print non empty subevals
    -- TODO: Order the subevals
    if next(self.subevals) then
        fwrite("\n%ssubevals = {\n",            tab)
        for _, subeval in pairs(self.subevals) do
            subeval:write(f)
        end
        fwrite("    },\n")
    end

    -- Close for eval (not subevals)
    if self.parent then
        fwrite(" },\n")
    elseif next(self.subevals) then
        fwrite("}\n")
    else
        fwrite("\n}\n")
    end

    f:flush()
end

--------------------------------------------------------------------------------
-- Returns the last subevaluation index.
function Eval:get_last_subeval_index ()
    return #self.subevals
end

--------------------------------------------------------------------------------
-- Returns the evaluation's main informations.
function Eval:get_class_p ()
    return self.class_p
end
-- Returns the evaluation's main informations.
-- @return id the eval index
-- @return subid the subeval index or `nil` if the eval doesn't belong to another eval
-- @return a full id string like "X.Y"
-- TODO
function Eval:get_ids ()
    if self.parent then
        local id, subid = self.parent:get_ids(), self.id
        local fancy_eid = id .. "." .. subid
        return id, subid, fancy_eid
    else
        return self.id, nil, self.id
    end
end
-- Returns the evaluation's main informations.
-- Subevals inherits from its parent eval
-- @return TODO
function Eval:get_infos ()
    if not self.parent then
        return self.category, self.class_p, self.title, self.subtitle
    else
        local pcat, pclass_p, ptitle, psubtitle = self.parent:get_infos()
        return self.category or pcat,
            self.class_p or pclass_p,
            self.title or ptitle,
            self.subtitle or psubtitle
    end
end

-- Returns the evaluation's titles.
-- Subevals inherits from its parent eval
-- @return title, subtitle
function Eval:get_title ()
    if not self.parent then
        return self.title, self.subtitle
    else
        local ptitle, psubtitle = self.parent:get_title()
        return self.title or ptitle,
            self.subtitle or psubtitle
    end
end

-- Returns the evaluation's full title (title + subtitle).
-- Subevals inherits from its parent eval
-- @return fulltitle
function Eval:get_fulltitle (sep)
    local sep = sep or " "

    local title, subtitle = self:get_title()
    assert(title, "Evaluation must have a title")

    if subtitle then
        return title .. sep .. subtitle
    else
        return title
    end
end

-- Returns the evaluation's score informations.
-- Subevals inherits from its parent eval
function Eval:get_score_infos ()
    if not self.parent then
        return self.max_score or DEFAULT_MAX_SCORE,
            self.real_max_score,
            self.over_max,
            self.allow_multi_attempts
    else
        local pmax, prealmax, pover, multi = self.parent:get_score_infos()
        return self.max_score or pmax,
            self.real_max_score or prealmax,
            self.over_max or pover,
            self.allow_multi_attempts or multi
    end
end
-- Checks if the eval allows multiple attempts.
function Eval:is_multi_attempts_allowed ()
    if not self.parent then
        return self.allow_multi_attempts
    else
        return self.parent:is_multi_attempts_allowed()
    end
end
-- Returns the evaluation's competency informations.
-- function Eval:get_competency_infos ()
--     return self.competency_mask, self.competency_score_mask
-- end




--------------------------------------------------------------------------------
-- Debug stuff

--------------------------------------------------------------------------------
-- Prints the database informations in a human readable way.
function Eval:plog (prompt_lvl, inline)
    local inline  = inline or false

    local prompt_lvl = prompt_lvl or 0
    local tab = "  "
    local prompt = string.rep(tab, prompt_lvl)

    local _, _, fancy_eid                            = self:get_ids()
    local category, class_p, title, subtitle         = self:get_infos()
    local class_p                                    = self:get_class_p()
    local max_score, real_max_score, over_max        = self:get_score_infos()
    -- local competency_mask, competency_score_mask = self:get_competency_infos()
    if inline then
        utils.plog("%s%s%s (id: %s) - cat: %s - score /%d%s (succ.%d%%)%s\n",
        prompt, title,
        subtitle and " - " .. subtitle or "",
        fancy_eid, category,
        max_score, over_max and " [+]" or "",
        self.success_score_pc or 50,
        competencies and " - comp. " .. competencies or "")
    else
        utils.plog("%s%s", prompt, title)
        utils.plog("%s", subtitle and " - " .. subtitle or "")
        utils.plog(" (id: %s)\n", fancy_eid)
        utils.plog("%s%s- category: %s - class: %s\n", prompt, tab, category, class_p)
        utils.plog("%s%s- score: /%d%s", prompt, tab, max_score, over_max and " [+]" or "")
        if self.success_score_pc then
            utils.plog(" (succ. %d%%)", self.success_score_pc)
        end
        if self.allow_multi_attempts then
            utils.plog(" (multiple attempts)")
        end
        if self.competencies then
            utils.plog(" - competencies: %s\n", self.competencies)
        end
        utils.plog("\n")
    end

    -- Only print non empty subevals
    if next(self.subevals) and not inline then
        utils.plog("%s%s- subevals :\n", prompt, tab)
        for _, subeval in pairs(self.subevals) do
            subeval:plog(prompt_lvl + 2, true)
        end
    end

end


return setmetatable({new = Eval.new,
    eval_types = EVAL_TYPES,
    split_fancy_eval_index = split_fancy_eval_index}, nil)
