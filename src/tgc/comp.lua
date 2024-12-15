--------------------------------------------------------------------------------
-- ## TgC comp module
--
-- @author Romain Diss
-- @copyright 2023
-- @license GNU/GPL (see COPYRIGHT file)
-- @module comp

-- TODO
-- FIXME: better handling of alternate comp

--------------------------------------------------------------------------------
-- Competencies list class
-- Sets default attributes and metatables.
local Comp_fw = {
}

local Comp_fw_mt = {
    __index = Comp_fw,
}


--------------------------------------------------------------------------------
-- Creates a new competencies list.
-- TODO: documentation
-- @return f (Comp_fw)
function Comp_fw.new (o)
    local f = setmetatable({}, Comp_fw_mt)

    -- Make sure the comp list has an id and a title.
    local o = o or {}
    assert(tonumber(o.id), "invalid competencies list id")
    assert(o.title and not string.find(o.title, "^%s*$"), "invalid competencies list title")

    -- Assign attributes
    f.id                      = tonumber(o.id)
    f.title                   = o.title and tostring(o.title)
    f.altid                   = o.altid and tonumber(o.altid)
    f.default                 = o.default and true or nil

    f.coefficient             = o.coefficient and tonumber(o.coefficient)

    -- Add competencies domains
    f.domains                 = {}
    if o.domains and type(o.domains == "table")  then
        for _, domain in ipairs(o.domains) do
            assert(domain.id, "invalid domain id for competencies list")
            table.insert(f.domains, domain)
        end
    end

    -- Add competencies
    f.competencies            = {}
    if o.competencies and type(o.competencies == "table")  then
        for _, comp in ipairs(o.competencies) do
            assert(comp.title, "invalid domain id for competencies list")
            table.insert(f.competencies, comp)
        end
    end

    return f
end

--------------------------------------------------------------------------------
-- Update an existing competencies framework.
-- FIXME: doesn't work yet!
-- @param o (table) - table containing the evaluation attributes to modify.
function Comp_fw.update (o)
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
function Comp_fw:write (f)
    local function fwrite (...) f:write(string.format(...)) end
    local tab   = "   "
    local space = " "

    fwrite("comp_fw_entry{\n%s",                tab)
    fwrite("id = %q,",                          self.id)
    fwrite("%stitle = %q,",                     space, self.title)

    if self.default then
        fwrite("\n%sdefault = %q,",               tab, self.default)
    end

    -- Alternate framework
    if self.altid then
        fwrite("\n%saltid = %q,",               tab, self.altid)
    end

    -- Coefficient part
    if self.coefficient then
        fwrite("\n%s",                          tab)
        fwrite("coefficient = %.2f,",           self.coefficient)
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
            if domain.score_opt and next(domain.score_opt) then
                fwrite("%sscore_opt = {",       space, domain.score_opt)
                space = ""
                for _, opt in ipairs(domain.score_opt) do
                    fwrite("%s%q,",             space, opt)
                    space = " "
                end
                fwrite("},")
            end
            fwrite("},")
        end
        fwrite("\n%s},",                        tab)
    end

    -- Competencies
    if self.competencies then
        fwrite("\n%scompetencies = {",          tab)
        for _, comp in ipairs(self.competencies) do
            space = ""
            local tab = "      "
            fwrite("\n%s{",                     tab)
            if comp.id then
                fwrite("%sid = %q,",            space, comp.id)
                space = " "
            end
            fwrite("%stitle = %q,",             space, comp.title)
            space = " "
            if comp.domain then
                fwrite("%sdomain = %q,",        space, comp.domain)
            end
            if comp.alt then
                fwrite("%salt = %q,",           space, comp.alt)
            end
            if comp.score then
                fwrite("%sscore = %q,",         space, comp.score)
            end
            if comp.score_opt and next(comp.score_opt) then
                fwrite("%sscore_opt = {",       space, comp.score_opt)
                space = ""
                for _, opt in ipairs(comp.score_opt) do
                    fwrite("%s%q,",             space, opt)
                    space = " "
                end
                fwrite("},")
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
-- Returns the title
function Comp_fw:get_infos ()
    return self.title
end

--------------------------------------------------------------------------------
-- Returns the id of the alternate framework
function Comp_fw:get_altid ()
    return self.altid
end

--------------------------------------------------------------------------------
-- TODO
function Comp_fw:get_compid_altid (id)
    return self.competencies[id] and self.competencies[id].alt
end

--------------------------------------------------------------------------------
-- TODO
function Comp_fw:get_compid_domid (id)
    return self.competencies[id] and self.competencies[id].domain
end

--------------------------------------------------------------------------------
-- Returns the coefficient
function Comp_fw:get_coefficient ()
    return self.coefficient or 1.0
end

--------------------------------------------------------------------------------
-- Returns the number of domains
function Comp_fw:get_domain_nb ()
    return #self.domains
end

--------------------------------------------------------------------------------
-- Returns the number of domains
function Comp_fw:get_domain_id_list ()
    return #self.domains
end

--------------------------------------------------------------------------------
-- Returns the domain infos
-- @return id, title
function Comp_fw:get_domain_infos (dom_id)
    if not self.domains[dom_id] then return nil end

    return self.domains[dom_id].id, self.domains[dom_id].title
end

--------------------------------------------------------------------------------
-- Returns the domain score
function Comp_fw:get_domain_score (dom_id)
    if not self.domains[dom_id] then return nil end

    return self.domains[dom_id].score
end

--------------------------------------------------------------------------------
-- Returns the coefficient
function Comp_fw:get_domain_score_opt (dom_id)
    local domain = self.domains[dom_id]
    if not domain or not domain.score_opt or not next(domain.score_opt) then
        return nil
    end

    local keep_best, mandatory
    for _, opt in pairs(domain.score_opt) do
        if opt == "keep_best" then
            keep_best = true
        elseif opt == "mandatory" then
            mandatory = true
        end
    end

    return keep_best or false,
        mandatory or false
end

--------------------------------------------------------------------------------
-- Returns a competencies to domain conversion table.
function Comp_fw:get_domain_hashtable ()
    local hashtable = {}

    for c, comp in ipairs(self.competencies) do
        hashtable[tostring(c)] = self.competencies[c].domain
    end

    return hashtable
end

--------------------------------------------------------------------------------
-- Returns a competencies to alternate competencies conversion table.
function Comp_fw:get_alt_hashtable ()
    local hashtable = {}

    for c, comp in ipairs(self.competencies) do
        hashtable[tostring(c)] = tostring(comp.alt)
    end

    return hashtable
end

--------------------------------------------------------------------------------
-- Returns a competencies to fancy id competencies conversion table.
function Comp_fw:get_fancy_id_hashtable ()
    local hashtable = {}

    for c, comp in ipairs(self.competencies) do
        hashtable[tostring(c)] = comp.id
    end

    return hashtable
end

--------------------------------------------------------------------------------
-- Returns the competencies infos
function Comp_fw:get_comp_infos (comp_id)
    if not self.competencies[comp_id] then return nil end

    return self.competencies[comp_id].id, self.competencies[comp_id].title,
           self.competencies[comp_id].domain, self.competencies[comp_id].alt
end

--------------------------------------------------------------------------------
-- Returns a list of the domain competencies indexes.
-- if no index, returns all the competencies indexes.
function Comp_fw:get_domain_comp_list (dom_id)
    local comp_list = {}

    if not dom_id then
        if not self.competencies then
            return nil
        else
            for c, _ in ipairs(self.competencies) do
                table.insert(comp_list, c)
            end
        end
    elseif not self.domains[dom_id] then
        return nil
    else
        for c, comp in ipairs(self.competencies) do
            if comp.domain == dom_id then
                table.insert(comp_list, c)
            end
        end
    end

    return comp_list
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Prints the database informations in a human readable way.
function Comp_fw:plog (prompt_lvl, inline)
    --local inline  = inline or false

    --local prompt_lvl = prompt_lvl or 0
    --local tab = "  "
    --local prompt = string.rep(tab, prompt_lvl)
end


return setmetatable({new = Comp_fw.new}, nil)
