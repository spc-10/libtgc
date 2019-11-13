LUA_DIR = $(HOME)/lib/lua
TGC_DIR = $(LUA_DIR)/tgc

TGC_LUAS = src/init.lua \
		   src/database.lua \
		   src/student.lua \
		   src/eval.lua \
		   src/result.lua \
		   src/report.lua \
		   src/competency.lua \
		   src/utils.lua

build clean:

install:
	mkdir -p $(TGC_DIR)
	cp $(TGC_LUAS) $(TGC_DIR)
