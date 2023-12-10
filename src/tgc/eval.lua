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
    e.id                      = tonumber(string.match(o.id, "%d-%.*(%d+)")) -- subeval id is store as X.Y
    e.title                   = o.title and tostring(o.title)
    e.subtitle                = o.subtitle and tostring(o.subtitle)
    e.category                = eval_type_exists(o.category) and o.category

    e.class_p                 = o.class_p and tostring(o.class_p)

    if o.competencies and type(o.competencies == "string") then
        e.competencies        = {}
        string.gsub(o.competencies, "%s*(%d+)%s*", function(c) table.insert(e.competencies, c) end)
    end
    e.comp_list_id            = o.comp_list_id -- FIXME checks

    e.max_score               = tonumber(o.max_score)
    e.real_max_score          = tonumber(o.real_max_score)
    e.over_max                = o.over_max and true or false

    e.allow_multi_attempts    = o.allow_multi_attempts and true or false
    e.success_score_pc        = tonumber(o.success_score_pc)

    -- Subevals stuff
    -- TODO: to remove?
    e.subevals                = {}
    if o.subevals and type(o.subevals == "table")  then
        for _, subeval in pairs(o.subevals) do
            local eid, subeid = split_fancy_eval_index(subeval.id)
            subeval.parent = e
            e.subevals[subeid] = Eval.new(subeval)
        end
    end

    -- Results stuff (dates and quarter for each class)
    e.quarter                 = tonumber(o.quarter)
    e.dates                   = {}
    if o.dates and type(o.dates == "table") then
        for class, dates in pairs(o.dates) do
            -- FIXME: check 'dates' is a table?
            e.dates[class] = dates
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
-- Add the date corresponding to when a class did the evaluation.
-- @param class (string)
-- @param date (string) a valid date
-- @return nothing ?
function Eval:add_result_date (class, date)
    self.dates        = self.dates or {}
    self.dates[class] = self.dates[class] or {}

    local date_found  = false
    -- Checks if the date already exists
    for _, d in ipairs(self.dates[class]) do
        if d == date then
            date_found = true
            break
        end
    end

    -- TODO: error handling (if date found)?
    if not date_found then
        table.insert(self.dates[class], date)
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
    -- TODO competencies is a table so this doesn't work
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
    local space = " "
    if self.max_score or self.over_max or self.competencies then
        fwrite("\n%s",                          tab)
        if self.max_score then
            fwrite("max_score = %d,",           self.max_score)
            space = " "
        end
        if self.real_max_score then
            fwrite("%sreal_max_score = %d,",    space, self.real_max_score)
            space = " "
        end
        if self.over_max then
            fwrite("%sover_max = %q,",          space, self.over_max)
            space = " "
        end
        if self.competencies then
            fwrite("%scompetencies = %q,",      space, table.concat(self.competencies, " "))
        end
        if self.comp_list_id then
            fwrite("%scomp_list_id = %q,",      space, self.comp_list_id)
        end
    end

    -- Multiple attempts
    space = ""
    if self.success_score_pc or self.allow_multi_attempts then
        fwrite("\n%s",                           tab)
        if self.allow_multi_attempts then
            fwrite("allow_multi_attempts = %q,", self.allow_multi_attempts)
            space = " "
        end
        if self.success_score_pc then
            fwrite("%ssuccess_score_pc = %d,",   space, self.success_score_pc)
        end
    end

    -- Results dates
    if self.quarter then
        fwrite("\n%squarter = %q,",              tab, self.quarter)
    end
    if next(self.dates) then
        fwrite("\n%sdates = {",                  tab)
        for class, dates in pairs(self.dates) do
            if dates and type(dates) == "table" then
                fwrite("\n%s     [%q] = {",      tab, class)
                for _, d in pairs(dates) do
                    fwrite("%q, ",               d)
                end
                fwrite("},")
            end
        end
        fwrite("\n%s},",                         tab)
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

-- Returns the number of attempts for a particular class.
function Eval:get_attempts_nb (class)
    return self.dates and self.dates[class] and #self.dates[class] or 0
end

-- Returns the quarter
function Eval:get_quarter ()
    return self.quarter
end

-- Returns the evaluation's score informations.
-- Subevals inherits from its parent eval
function Eval:get_score_infos ()
    if not self.parent then
        return self.max_score or DEFAULT_MAX_SCORE,
            self.real_max_score,
            self.over_max
    else
        local pmax, prealmax, pover = self.parent:get_score_infos()
        return self.max_score or pmax,
            self.real_max_score or prealmax,
            self.over_max or pover
    end
end
-- Returns the evaluation's informations about multiple attempts.
-- Subevals inherits from its parent eval
function Eval:get_multi_infos ()
    if not self.parent then
        return self.allow_multi_attempts,
            self.success_score_pc
    else
        local pallow, psuccess = self.parent:get_multi_infos()
        return self.allow_multi_attempts or pallow,
            self.success_score_pc or psucces
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
-- Returns the evaluation's competencies informations.
-- FIXME comp_list
function Eval:get_competencies_infos ()
    if not self.parent then
        if self.competencies then
            return self.competencies, #self.competencies, self.comp_list_id
        end
    else
        local pcomp = self.parent:get_competencies_infos()
        if self.competencies then
            return self.competencies, #self.competencies
        elseif pcomp then
            return pcomp, #pcomp
        end
    end
end




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
    local competencies                               = self:get_competencies_infos()
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
        if competencies then
            utils.plog(" - competencies: %s\n", table.concat(competencies, " "))
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
