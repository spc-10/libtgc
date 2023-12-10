--------------------------------------------------------------------------------
-- ## TgC comp module
--
-- @author Romain Diss
-- @copyright 2023
-- @license GNU/GPL (see COPYRIGHT file)
-- @module comp


--------------------------------------------------------------------------------
-- Competencies list class
-- Sets default attributes and metatables.
local Comp_list = {
}

local Comp_list_mt = {
    __index = Comp_list,
}


--------------------------------------------------------------------------------
-- Creates a new competencies list.
-- TODO: documentation
-- @return l (Comp_list)
function Comp_list.new (o)
    local l = setmetatable({}, Comp_list_mt)

    -- Make sure the comp list has an id and a title.
    local o = o or {}
    assert(tonumber(o.id), "invalid competencies list id")
    assert(o.title and not string.find(o.title, "^%s*$"), "invalid competencies list title")

    -- Assign attributes
    l.id                      = tonumber(o.id)
    l.title                   = o.title and tostring(o.title)
    l.link                    = o.link and tonumber(o.link)

    -- Add competencies domains
    l.domains                 = {}
    if o.domains and type(o.domains == "table")  then
        for _, domain in ipairs(o.domains) do
            assert(domain.id, "invalid domain id for competencies list")
            table.insert(l.domains, domain)
        end
    end

    -- Add competencies
    l.competencies            = {}
    if o.competencies and type(o.competencies == "table")  then
        for _, comp in ipairs(o.competencies) do
            assert(comp.title, "invalid domain id for competencies list")
            table.insert(l.competencies, comp)
        end
    end

    return l
end

--------------------------------------------------------------------------------
-- Update an existing evaluation.
-- FIXME: doesn't work yet!
-- @param o (table) - table containing the evaluation attributes to modify.
-- See Eval.new() for attributes.
-- @return (bool) true if an update has been done, false otherwise.
function Comp_list.update (o)
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
-- Write the competencies list in a file.
-- @param f (file) - file (open for writing)
function Comp_list:write (f)
    local function fwrite (...) f:write(string.format(...)) end
    local tab   = "   "
    local space = " "

    fwrite("comp_list_entry{\n%s",              tab)
    fwrite("id = %q,",                          self.id)
    fwrite("%stitle = %q,",                     space, self.title)

    if self.link then
        fwrite("\n%slink = %q,",                tab, self.link)
    end

    -- Domains
    if self.domains then
        fwrite("\n%sdomains = {",               tab)
        for _, domain in ipairs(self.domains) do
            local tab = "      "
            fwrite("\n%s{id = %q,",             tab, domain.id)
            if domain.title then
                fwrite("%stitle = %q,",         space, domain.title)
            end
            if domain.score then
                fwrite("%sscore = %q,",         space, domain.score)
            end
            fwrite("},")
        end
        fwrite("\n%s},",                        tab)
    end

    -- Competencies
    if self.competencies then
        fwrite("\n%scompetencies = {",          tab)
        for _, comp in ipairs(self.competencies) do
            local tab = "      "
            fwrite("\n%s{title = %q,",          tab, comp.title)
            if comp.domain then
                fwrite("%sdomain = %q,",        space, comp.domain)
            end
            --if comp.score then
            --    fwrite("%sscore = %q,",         space, comp.score)
            --end
            if comp.link then
                fwrite("%slink = %q,",          space, comp.link)
            end
            if comp.base then
                fwrite("%sbase = %q,",          space, comp.base)
            end
            fwrite("},")
        end
        fwrite("\n%s},",                        tab)
    end

    -- Close
    fwrite("\n}\n")

    f:flush()
end

--------------------------------------------------------------------------------
-- Returns a competencies to domain conversion table.
function Comp_list:comp_to_domain ()
    local conv_table = {}

    for c, comp in ipairs(self.competencies) do
        conv_table[tostring(c)] = self.competencies[c].domain
    end

    return conv_table
end

--------------------------------------------------------------------------------
-- Returns a competencies to domain conversion table.
function Comp_list:comp_to_base ()
    local conv_table = {}

    for c, comp in ipairs(self.competencies) do
        conv_table[tostring(c)] = self.competencies[c].base
    end

    return conv_table
end

--------------------------------------------------------------------------------
-- Returns the number of domains
function Comp_list:get_domain_infos (index)
    if not self.domains[index] then return nil end

    return self.domains[index].id, self.domains[index].title, self.domains[index].score
end


--------------------------------------------------------------------------------
-- Returns the number of domains
function Comp_list:get_domain_nb ()
    return #self.domains
end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Prints the database informations in a human readable way.
function Comp_list:plog (prompt_lvl, inline)
    --local inline  = inline or false

    --local prompt_lvl = prompt_lvl or 0
    --local tab = "  "
    --local prompt = string.rep(tab, prompt_lvl)

    --local _, _, fancy_eid                            = self:get_ids()
    --local category, class_p, title, subtitle         = self:get_infos()
    --local class_p                                    = self:get_class_p()
    --local max_score, real_max_score, over_max        = self:get_score_infos()
    ---- local competency_mask, competency_score_mask = self:get_competency_infos()
    --if inline then
    --    utils.plog("%s%s%s (id: %s) - cat: %s - score /%d%s (succ.%d%%)%s\n",
    --    prompt, title,
    --    subtitle and " - " .. subtitle or "",
    --    fancy_eid, category,
    --    max_score, over_max and " [+]" or "",
    --    self.success_score_pc or 50,
    --    competencies and " - comp. " .. competencies or "")
    --else
    --    utils.plog("%s%s", prompt, title)
    --    utils.plog("%s", subtitle and " - " .. subtitle or "")
    --    utils.plog(" (id: %s)\n", fancy_eid)
    --    utils.plog("%s%s- category: %s - class: %s\n", prompt, tab, category, class_p)
    --    utils.plog("%s%s- score: /%d%s", prompt, tab, max_score, over_max and " [+]" or "")
    --    if self.success_score_pc then
    --        utils.plog(" (succ. %d%%)", self.success_score_pc)
    --    end
    --    if self.allow_multi_attempts then
    --        utils.plog(" (multiple attempts)")
    --    end
    --    if self.competencies then
    --        utils.plog(" - competencies: %s\n", self.competencies)
    --    end
    --    utils.plog("\n")
    --end

    ---- Only print non empty subevals
    --if next(self.subevals) and not inline then
    --    utils.plog("%s%s- subevals :\n", prompt, tab)
    --    for _, subeval in pairs(self.subevals) do
    --        subeval:plog(prompt_lvl + 2, true)
    --    end
    --end

end


return setmetatable({new = Comp_list.new}, nil)
