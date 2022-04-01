#!/usr/bin/lua

package.path = "../src/?.lua;../src/?/init.lua;" -- use development version

local plog = require "tgc.utils".plog

--------------------------------------------------------------------------------
-- Load TGC
local tgc = require "tgc"
plog("\nInitialisation... ")
tgc = tgc.init()
plog("%s loaded\n", tgc._VERSION)

tgc:load("notes.lua")
print("\nNo error found!")
print("\nPlog !")
tgc:plog()
