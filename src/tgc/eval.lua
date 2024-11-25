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
    e.id                      = tonumber(o.id)
    e.title                   = o.title and tostring(o.title)
    e.subtitle                = o.subtitle and tostring(o.subtitle)
    e.category                = eval_type_exists(o.category) and o.category

    e.class_p                 = o.class_p and tostring(o.class_p)

    if o.competencies and type(o.competencies == "string") then
        e.competencies        = {}
        string.gsub(o.competencies, "%s*(%d+)%s*", function(c) table.insert(e.competencies, c) end)
    end
    e.comp_fw_id              = o.comp_fw_id -- FIXME checks

    e.max_score               = tonumber(o.max_score)
    e.real_max_score          = tonumber(o.real_max_score)
    e.over_max                = o.over_max and true or false

    e.coefficient             = tonumber(o.coefficient)

    e.allow_multi_attempts    = o.allow_multi_attempts and true or false
    e.success_score_pc        = tonumber(o.success_score_pc)

    e.optional               = o.optional and true

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
-- Add the date corresponding to when a class did the evaluation.
-- @param class (string)
-- @param date (string) a valid date
-- @return nothing ?
function Eval:add_result_date (class, date)
    self.dates        = self.dates or {}
    self.dates[class] = self.dates[class] or {}

    assert(is_date_valid(date), "Impossible to create an evaluation with an invalid date!")

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

    -- Opening
    local eid = self:get_id()
    tab = "    "
    fwrite("evaluation_entry{\n    ")
    fwrite("id = %q,",                          eid)

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

    -- Coefficient part
    if self.coefficient then
        fwrite("\n%s",                          tab)
        fwrite("coefficient = %.2f,",           self.coefficient)
    end

    -- Score part
    local space = ""
    if self.max_score or self.over_max then
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
    end

    -- Competencies part
    local space = ""
    if self.competencies then
        fwrite("\n%s",                          tab)
        fwrite("%scompetencies = %q,",          space, table.concat(self.competencies, " "))
        space = " "
        if self.comp_fw_id then
            fwrite("%scomp_fw_id = %q,",        space, self.comp_fw_id)
            space = " "
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

    -- Optional
    if self.optional then
        fwrite("\n%s",                           tab)
        fwrite("optional = %q,",                 self.optional)
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

    fwrite("\n}\n")

    f:flush()
end

--------------------------------------------------------------------------------
-- Returns the evaluation's main informations.
function Eval:get_class_p ()
    return self.class_p
end

-- Returns the evaluation's main informations.
-- @return id the eval index
function Eval:get_id ()
    return self.id
end

-- Returns the evaluation's main informations.
function Eval:get_infos ()
    return self.category, self.class_p, self.title, self.subtitle
end

-- Returns the evaluation's titles.
function Eval:get_title ()
    return self.title, self.subtitle
end

-- Returns the evaluation's full title (title + subtitle).
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
-- @return quarter
function Eval:get_quarter ()
    return self.quarter
end

-- Returns the evaluation's score informations.
-- @return max_score, real_max_score, over_max
function Eval:get_score_infos ()
    return self.max_score,
        self.real_max_score or self.max_score,
        self.over_max or false
end

-- Returns the evaluation's score informations.
-- @return coefficient
function Eval:get_coefficient ()
    return self.coefficient or 1.0
end

-- Returns the evaluation's informations about multiple attempts.
function Eval:get_multi_infos ()
    return self.allow_multi_attempts, self.success_score_pc
end

-- Checks if the eval allows multiple attempts.
function Eval:is_multi_attempts_allowed ()
    return self.allow_multi_attempts
end

-- Returns the evaluation's competencies informations.
function Eval:get_competencies_infos ()
    if self.competencies then
        return self.competencies, #self.competencies, self.comp_fw_id
    end
end

-- Returns the result ids corresponding to given dates
function Eval:get_result_ids (dates_list, class, group)
    -- dates_list should be a date (string) array or a date (string)
    --print("DEBUG DEBUG Eval:get_result_ids() | type(dates_list) = ", type(dates_list))
    dates_list = dates_list or {}
    if type(dates_list) == "string" then
        dates_list = {dates_list}
    elseif type(dates_list) ~= "table" then
        return
    end
    --print("DEBUG DEBUG Eval:get_result_ids() | type(dates_list) = ", type(dates_list))
    --print("DEBUG DEBUG Eval:get_result_ids() | self.dates = ", self.dates)

    local rids = {}
    local result_dates = self.dates[group] or self.dates[class] or {}
    --print("DEBUG DEBUG Eval:get_result_ids() | result_dates = ", result_dates)
    --print("DEBUG DEBUG Eval:get_result_ids() | result_dates[1] = ", result_dates[1])

    for _, date in ipairs(dates_list) do
        assert(is_date_valid(date), "Impossible to get a result with an invalid date!")
        --print("DEBUG DEBUG Eval:get_result_ids() | date = ", date)
        for rid, result_date in ipairs(result_dates) do
            --print("DEBUG Eval:get_result_ids() | date, result_date = ", date, result_date)
            if date == result_date then
                table.insert(rids, rid)
            end
        end
    end

    --print("DEBUG DEBUG Eval:get_result_ids() | rids = ", table.concat(rids, ", "))
    return rids
end

-- Is the eval optional?
function Eval:is_optional ()
    return self.optional and true or false
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

    local eid                                        = self:get_id()
    local category, class_p, title, subtitle         = self:get_infos()
    local class_p                                    = self:get_class_p()
    local max_score, real_max_score, over_max        = self:get_score_infos()
    local competencies                               = self:get_competencies_infos()
    -- local competency_mask, competency_score_mask = self:get_competency_infos()
    if inline then
        utils.plog("%s%s%s (id: %s) - cat: %s - score /%d%s (succ.%d%%)%s\n",
        prompt, title,
        subtitle and " - " .. subtitle or "",
        eid, category,
        max_score, over_max and " [+]" or "",
        self.success_score_pc or 50,
        competencies and " - comp. " .. table.concat(competencies, " "))
    else
        utils.plog("%s%s", prompt, title)
        utils.plog("%s", subtitle and " - " .. subtitle or "")
        utils.plog(" (id: %s)\n", eid)
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
end


return setmetatable({new = Eval.new,
    eval_types = EVAL_TYPES,
    split_fancy_eval_index = split_fancy_eval_index}, nil)
